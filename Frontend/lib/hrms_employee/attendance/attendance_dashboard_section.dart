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
  int _request = 0;
  int _ticks = 0;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? http.Client();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_data?['status'] == 'checked_in') setState(() {});
      if (++_ticks % 60 == 0 && !_loading && !_punching) _load();
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
    final actions = data['actions'] as Map;
    final checkedIn = data['status'] == 'checked_in';
    final checkedOut = data['status'] == 'checked_out';
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${DateFormat('MMMM').format(DateTime.parse('${overview['month']}-01'))} Overview',
            style: const TextStyle(fontWeight: FontWeight.w800),
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
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
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
                      : checkedOut
                      ? 'Completed'
                      : 'Clock In',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth < 520
              ? Column(children: [workday, const SizedBox(height: 14), month])
              : Row(
                  children: [
                    Expanded(child: workday),
                    const SizedBox(width: 18),
                    Expanded(child: month),
                  ],
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
