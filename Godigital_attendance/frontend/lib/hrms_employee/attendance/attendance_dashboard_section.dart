import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../services/api_config.dart';
import '../../services/attendance_location.dart';
import '../../services/auth_service.dart';
import '../../services/auth_storage.dart';
import '../shared/employee_ui.dart';

/// Attendance on the employee home screen. Other modules retain their own state.
class AttendanceDashboardSection extends StatefulWidget {
  const AttendanceDashboardSection({super.key, this.client});
  final http.Client? client;

  @override
  State<AttendanceDashboardSection> createState() =>
      _AttendanceDashboardSectionState();
}

class _AttendanceDashboardSectionState extends State<AttendanceDashboardSection>
    with WidgetsBindingObserver {
  late final http.Client _client;
  final _elapsed = Stopwatch();
  Timer? _timer;
  String? _token;
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;
  bool _punching = false;
  bool _breakCommentDialogOpen = false;
  int _request = 0;
  int _ticks = 0;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? http.Client();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      if (_data?['status'] == 'checked_in') setState(() {});
      if (++_ticks % 60 == 0 && !_loading && !_punching) {
        final token = _token;
        if (_data?['status'] == 'checked_in' && token != null) {
          try {
            await _call('heartbeat', token, post: true);
          } catch (_) {
            // The live display still runs; the next dashboard refresh retries.
          }
        }
        if (mounted) _load();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthService>();
    // Wait for the persisted session to finish loading. Without this guard,
    // the first attendance render could mistake a still-loading session for a
    // logged-out employee.
    if (!auth.isInitialized) return;

    final token = auth.token;
    if (_token != token || (_loading && _request == 0)) {
      _token = token;
      _data = null;
      _punching = false;
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_punching) _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _client.close();
    super.dispose();
  }

  Future<Map<String, dynamic>> _call(
    String endpoint,
    String token, {
    bool post = false,
    Map<String, dynamic>? payload,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/attendance/$endpoint');
    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      if (post) 'Content-Type': 'application/json',
    };
    final response =
        await (post
                ? _client.post(
                    url,
                    headers: headers,
                    body: jsonEncode(payload ?? {}),
                  )
                : _client.get(url, headers: headers))
            .timeout(const Duration(seconds: 15));
    if (response.statusCode == 401) {
      throw const _AttendanceError(
        'Your session expired. Please sign in again.',
      );
    }
    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const _AttendanceError('Attendance is unavailable. Please retry.');
    }
    if (response.statusCode != 200 || body['success'] != true) {
      throw _AttendanceError(
        body['message']?.toString() ?? 'Attendance is unavailable.',
      );
    }
    return Map<String, dynamic>.from(body['data'] as Map);
  }

  String _message(Object error) => error is _AttendanceError
      ? error.message
      : error is AttendanceLocationError
      ? error.message
      : 'Could not reach attendance. Check your connection and retry.';

  String _durationLabel(int minutes) =>
      '${minutes ~/ 60}h ${(minutes % 60).toString().padLeft(2, '0')}m';

  Future<void> _load() async {
    var token = _token;
    final request = ++_request;
    if (token == null || token.isEmpty) {
      // The session token is written during login. Read the persisted value
      // once as a fallback before showing a sign-in error.
      token = await AuthStorage.getString('auth_token');
      if (token != null && token.isNotEmpty) {
        _token = token;
      }
    }
    if (token == null || token.isEmpty) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _data = null;
        _error = 'Please sign in to view attendance.';
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final data = await _call('dashboard', token);
      if (!mounted || request != _request || token != _token) return;
      setState(() {
        _data = data;
        _error = null;
        _elapsed
          ..reset()
          ..start();
      });
      final activeBreak = data['active_break'];
      if (activeBreak is Map && activeBreak['comment_required'] == true) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _showBreakCommentDialog());
      }
    } catch (error) {
      if (!mounted || request != _request || token != _token) return;
      setState(() => _error = _message(error));
    } finally {
      if (mounted && request == _request && token == _token) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _punch() async {
    final token = _token;
    if (token == null || _loading || _punching || _error != null) return;
    final clockOut = _data?['status'] == 'checked_in';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(clockOut ? 'Clock out?' : 'Clock in?'),
        content: Text(clockOut
            ? 'Confirm that you want to end your work session.'
            : 'Confirm that you want to start your work session.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(clockOut ? 'Clock Out' : 'Clock In'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _punching = true);
    String message;
    try {
      final payload = clockOut
          ? <String, dynamic>{}
          : await AttendanceLocation.checkInPayload(
              client: _client,
              token: token,
            );
      if (!mounted || token != _token) return;
      await _call(
        clockOut ? 'clock-out' : 'clock-in',
        token,
        post: true,
        payload: payload,
      );
      message = clockOut
          ? 'You have been clocked out.'
          : 'You are now checked in.';
    } catch (error) {
      message = '${_message(error)} Refresh attendance before trying again.';
    }
    // Also reconcile after a timeout: the server may have saved the punch.
    if (!mounted || token != _token) return;
    await _load();
    if (!mounted || token != _token) return;
    setState(() => _punching = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _requestAnotherClockIn({
    required String date,
    required String clockIn,
    required String clockOut,
  }) async {
    final token = _token;
    if (token == null || _loading || _punching || _error != null) return;
    final controller = TextEditingController();
    var submitting = false;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Clock In request'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Send Admin a request to reopen today\'s attendance. After approval, Clock In will be available again.'),
                const SizedBox(height: 14),
                Text('Date: $date'),
                Text('Original Clock In: $clockIn'),
                Text('Original Clock Out: $clockOut'),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  enabled: !submitting,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 350,
                  decoration: const InputDecoration(
                    labelText: 'Reason for requesting another Clock In',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      final reason = controller.text.trim();
                      if (reason.length < 3) {
                        setDialogState(() => error = 'Enter at least 3 characters.');
                        return;
                      }
                      setDialogState(() {
                        submitting = true;
                        error = null;
                      });
                      try {
                        await _call(
                          'reclock-in-request',
                          token,
                          post: true,
                          payload: {'reason': reason},
                        );
                        if (!mounted) return;
                        Navigator.of(dialogContext).pop();
                        await _load();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Clock In request sent to Admin.')),
                        );
                      } catch (e) {
                        setDialogState(() {
                          submitting = false;
                          error = _message(e);
                        });
                      }
                    },
              child: Text(submitting ? 'Sending…' : 'Send request'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  Future<void> _toggleBreak() async {
    final token = _token;
    if (token == null || _loading || _punching || _error != null) return;
    final activeBreak = _data?['active_break'] != null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(activeBreak ? 'Resume work?' : 'Start break?'),
        content: Text(activeBreak
            ? 'Confirm that you want to end your break and resume your work session.'
            : 'Confirm that you want to start your lunch break.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(activeBreak ? 'Resume' : 'Start Break'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _punching = true);
    String message;
    try {
      await _call(activeBreak ? 'break-out' : 'break-in', token, post: true);
      message = activeBreak ? 'Break ended. You are back at work.' : 'Break started. You remain checked in.';
    } catch (error) {
      message = _message(error);
    }
    if (!mounted || token != _token) return;
    await _load();
    if (!mounted || token != _token) return;
    setState(() => _punching = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showBreakCommentDialog() async {
    if (!mounted || _breakCommentDialogOpen) return;
    final token = _token;
    if (token == null) return;
    _breakCommentDialogOpen = true;
    final controller = TextEditingController();
    var submitting = false;
    String? error;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Lunch break limit exceeded'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter the reason for exceeding the allowed lunch-break time. This will be sent to Admin.'),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                enabled: !submitting,
                maxLength: 1000,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  border: OutlineInputBorder(),
                ),
              ),
              if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: submitting ? null : () async {
                final comment = controller.text.trim();
                if (comment.length < 3) {
                  setDialogState(() => error = 'Enter at least 3 characters.');
                  return;
                }
                setDialogState(() { submitting = true; error = null; });
                try {
                  await _call('break-exceeded-comment', token, post: true, payload: {'comment': comment});
                  if (!mounted) return;
                  Navigator.of(dialogContext).pop();
                  await _load();
                } catch (e) {
                  setDialogState(() { submitting = false; error = _message(e); });
                }
              },
              child: Text(submitting ? 'Sending…' : 'Send to Admin'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    _breakCommentDialogOpen = false;
  }

  String _formatPunchTime(dynamic rawTimestamp) {
    if (rawTimestamp == null || rawTimestamp.toString().trim().isEmpty) {
      return '--:--';
    }
    try {
      final str = rawTimestamp.toString();
      DateTime dt;
      if (str.contains('T') || str.contains('-')) {
        dt = DateTime.parse(str).toLocal();
      } else {
        return str; // Return as-is if already formatted like "09:30 AM"
      }
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {
      return rawTimestamp.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null) {
      return EmployeeCard(
        child: Column(
          children: [
            if (_loading)
              const CircularProgressIndicator()
            else ...[
              Text(_error ?? 'Attendance is unavailable.'),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          ],
        ),
      );
    }
    final employee = data['employee'] as Map;
    final session = data['session'] as Map?;
    final overview = data['month_overview'] as Map;
    final workTime = overview['work_time'] as Map? ?? const {};
    final actualMinutes = (workTime['actual_minutes'] as num?)?.toInt() ?? 0;
    final targetMinutes = (workTime['target_minutes'] as num?)?.toInt() ?? 0;
    final overtimeMinutes = (workTime['overtime_minutes'] as num?)?.toInt() ?? 0;
    final progress = targetMinutes == 0
        ? 0.0
        : (actualMinutes / targetMinutes).clamp(0.0, 1.0);
    final actions = data['actions'] as Map;
    final checkedIn = data['status'] == 'checked_in';
    final onBreak = data['active_break'] != null;
    final breakCompleted = data['break_completed'] == true;
    final activeBreak = data['active_break'] as Map?;
    var breakTimeLeftLabel = '';
    var breakStartedLabel = '';
    if (onBreak && activeBreak != null) {
      try {
        final started = DateTime.parse(
          activeBreak['started_at'].toString().replaceFirst(' ', 'T'),
        ).toLocal();
        breakStartedLabel = 'Break started: ${DateFormat('hh:mm a').format(started)}';
        final limitSeconds =
            ((activeBreak['limit_minutes'] as num?)?.toInt() ?? 70) * 60;
        final remainingSeconds = limitSeconds -
            DateTime.now().difference(started).inSeconds;
        final safeSeconds = remainingSeconds < 0 ? 0 : remainingSeconds;
        final minutes = safeSeconds ~/ 60;
        final seconds = safeSeconds % 60;
        breakTimeLeftLabel =
            'Break time left: ${minutes ~/ 60}h ${(minutes % 60).toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s';
      } catch (_) {
        breakTimeLeftLabel = 'Break is active';
      }
    }
    final checkedOut = data['status'] == 'checked_out';
    final reclockRequest = data['reclock_in_request'] as Map?;
    final seconds = (session?['worked_seconds'] as num?)?.toInt() ?? 0;
    final worked = seconds + (checkedIn ? _elapsed.elapsed.inSeconds : 0);
    final today = DateTime.parse(data['date'] as String);
    final overnight = session != null && session['work_date'] != data['date'];

    final punchInDisplay = _formatPunchTime(
      session?['punch_in'] ?? session?['clock_in'] ?? session?['check_in'],
    );
    final punchOutDisplay = _formatPunchTime(
      session?['punch_out'] ?? session?['clock_out'] ?? session?['check_out'],
    );

    final workday = EmployeeCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            overnight ? 'Current Work Session' : "Today's Workday",
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: 130,
            height: 130,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Decorative ring indicator
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: employeeBlue, width: 8),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${worked ~/ 3600}h ${(worked % 3600) ~/ 60}m',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'Worked',
                      style: TextStyle(color: employeeMuted, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Divider(color: employeeLine),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  const Text(
                    'Check In',
                    style: TextStyle(color: employeeMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    punchInDisplay,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: employeeNavy,
                    ),
                  ),
                ],
              ),
              Container(height: 26, width: 1, color: employeeLine),
              Column(
                children: [
                  const Text(
                    'Check Out',
                    style: TextStyle(color: employeeMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    punchOutDisplay,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: employeeNavy,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    final month = EmployeeCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${DateFormat('MMMM').format(DateTime.parse('${overview['month']}-01'))} Overview',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 13),
          const Text('Monthly Work Time',
              style: TextStyle(color: employeeMuted, fontSize: 12)),
          const SizedBox(height: 4),
          Text(_durationLabel(actualMinutes),
              style: const TextStyle(
                  color: employeeNavy, fontSize: 27, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            tween: Tween(begin: 0, end: progress),
            builder: (context, value, child) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 7,
                backgroundColor: employeeLine,
                valueColor: AlwaysStoppedAnimation<Color>(
                    overtimeMinutes > 0 ? const Color(0xFF11A55B) : employeeBlue),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            targetMinutes > 0
                ? 'Target ${_durationLabel(targetMinutes)}${overtimeMinutes > 0 ? '  +${_durationLabel(overtimeMinutes)} extra' : ''}'
                : 'Attendance target is not configured',
            style: const TextStyle(color: employeeMuted, fontSize: 12),
          ),
          const SizedBox(height: 13),
          _count('Present', overview['present_days'], const Color(0xFF11A55B)),
          const Divider(color: employeeLine),
          _count('Absent', overview['absent_days'], const Color(0xFFE34646)),
          const Divider(color: employeeLine),
          _count('Late', overview['late_days'], const Color(0xFFFF8B17)),
          if (overview['absent_days'] == null ||
              overview['late_days'] == null) ...[
            const SizedBox(height: 10),
            const Text(
              'Late and absent totals will appear once working hours and days are set.',
              style: TextStyle(color: employeeMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Hello, '),
              TextSpan(
                text: employee['name']?.toString() ?? '',
                style: const TextStyle(color: employeeBlue),
              ),
            ],
          ),
          style: const TextStyle(
            color: employeeNavy,
            fontSize: 27,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${employee['staff_id']}  •  ${DateFormat('EEEE, d MMM yyyy').format(today)}',
          style: const TextStyle(color: employeeMuted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          Text('Attendance may be out of date. $_error'),
          TextButton(
            onPressed: _loading || _punching ? null : _load,
            child: const Text('Retry'),
          ),
        ],
        if (_loading) const LinearProgressIndicator(),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFF0B72F5), Color(0xFF073B9D)],
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      checkedIn
                          ? 'Checked In'
                          : checkedOut
                          ? 'Checked Out'
                          : 'Not Checked In',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    if (checkedIn && punchInDisplay != '--:--') ...[
                      const SizedBox(height: 3),
                      Text(
                        'Since $punchInDisplay',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (onBreak) ...[
                        const SizedBox(height: 3),
                        Text(
                          breakTimeLeftLabel,
                          style: const TextStyle(
                            color: Color(0xFFFFE08A),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          breakStartedLabel,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.82),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (checkedIn)
                OutlinedButton.icon(
                  onPressed: _loading || _punching || _error != null || breakCompleted
                      ? null
                      : _toggleBreak,
                  icon: Icon(
                    onBreak ? Icons.play_arrow : (breakCompleted ? Icons.check : Icons.pause),
                    size: 18,
                  ),
                  label: Text(onBreak ? 'Resume' : (breakCompleted ? 'Break Over' : 'Break')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white),
                  ),
                ),
              if (checkedIn) const SizedBox(width: 10),
              OutlinedButton(
                onPressed:
                    _loading ||
                        _punching ||
                        _error != null ||
                        !(actions['can_clock_in'] == true ||
                            actions['can_clock_out'] == true)
                    ? null
                    : _punch,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white),
                ),
                child: Text(
                  _punching
                      ? 'Saving…'
                      : checkedIn
                      ? 'Clock Out'
                      : checkedOut && actions['can_clock_in'] == true
                      ? 'Clock In'
                      : checkedOut
                      ? 'Completed'
                      : 'Clock In',
                ),
              ),
              if (checkedOut) const SizedBox(width: 10),
              if (checkedOut)
                OutlinedButton(
                  onPressed: _loading || _punching || _error != null ||
                          actions['can_reclock_in_request'] != true
                      ? null
                      : () => _requestAnotherClockIn(
                            date: DateFormat('d MMM yyyy').format(today),
                            clockIn: punchInDisplay,
                            clockOut: punchOutDisplay,
                          ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white),
                  ),
                  child: Text(
                    reclockRequest?['status'] == 'Approved' &&
                            reclockRequest?['reclocked_at'] == null
                        ? 'Request Approved'
                        : reclockRequest?['status'] == 'Pending'
                            ? 'Request Pending'
                            : 'Clock In Request',
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth < 520
              ? Column(children: [workday, const SizedBox(height: 14), month])
              : SizedBox(
                  height: 340,
                  child: Row(
                    children: [
                      Expanded(child: workday),
                      const SizedBox(width: 18),
                      Expanded(child: month),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _count(String label, dynamic value, Color color) => Row(
    children: [
      Expanded(child: Text(label)),
      Text(
        value?.toString() ?? '—',
        style: TextStyle(
          color: color,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

class _AttendanceError implements Exception {
  const _AttendanceError(this.message);
  final String message;
}
