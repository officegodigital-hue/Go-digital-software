import 'dart:convert';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../services/api_config.dart';
import '../../services/auth_service.dart';
import '../shared/employee_ui.dart';

List<String> _attendanceBaseUrls() {
  return ['${ApiConfig.baseUrl}/attendance'];
}

double _leaveDays(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

String _formatLeaveDays(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);

bool _isUsageOnly(dynamic balance) =>
    balance is Map &&
    (balance['display_mode'] == 'USAGE_ONLY' ||
        balance['usage_only'] == true ||
        balance['usage_only'] == 1);

class EmployeeLeavePage extends StatefulWidget {
  const EmployeeLeavePage({super.key});

  @override
  State<EmployeeLeavePage> createState() => _EmployeeLeavePageState();
}

class _EmployeeLeavePageState extends State<EmployeeLeavePage> {
  bool _loading = true;
  List<dynamic> _balances = [];
  List<dynamic> _requests = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchLeaveData());
  }

  List<String> _getBaseUrls() {
    return _attendanceBaseUrls();
  }

  Future<void> _fetchLeaveData() async {
    final token = context.read<AuthService>().token;
    if (token == null || token.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Your session is unavailable. Please sign in again.';
        });
      }
      return;
    }

    setState(() => _loading = true);

    for (final base in _getBaseUrls()) {
      try {
        final url = Uri.parse('$base/leave/dashboard');
        final res = await http
            .get(
              url,
              headers: {
                'Authorization': 'Bearer $token',
                'Accept': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 5));

        if (res.statusCode == 200) {
          final body = jsonDecode(res.body);
          if (body['success'] == true && body['data'] != null) {
            if (mounted) {
              setState(() {
                _balances = body['data']['balances'] ?? [];
                _requests = body['data']['requests'] ?? [];
                _loading = false;
                _error = null;
              });
            }
            return;
          }
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _loading = false;
        _error = 'Unable to reach leave server.';
      });
    }
  }

  Future<void> _cancelLeave(dynamic leaveId) async {
    final token = context.read<AuthService>().token;
    if (token == null) return;

    for (final base in _getBaseUrls()) {
      try {
        final url = Uri.parse('$base/leave/cancel');
        final res = await http.post(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'leave_id': leaveId}),
        );
        if (res.statusCode == 200) {
          _fetchLeaveData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Leave request cancelled.')),
            );
          }
          return;
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode =
        ModalRoute.of(context)?.settings.arguments as String? ?? 'apply';

    return EmployeeScaffold(
      route: '/employee/leave',
      title: 'Leave',
      subtitle: '',
      desktopHeaderAction: mode == 'requests'
          ? null
          : GestureDetector(
              onTap: () => _showLeaveHistoryDialog(context, _requests),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F5FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFD0E1FF)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 13,
                      color: Color(0xFF0B72F5),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'View History',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF0B72F5),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      desktop: _DesktopLeave(
        mode: mode,
        loading: _loading,
        error: _error,
        balances: _balances,
        requests: _requests,
        onRefresh: _fetchLeaveData,
        onCancel: _cancelLeave,
      ),
      mobile: _MobileLeave(
        mode: mode,
        loading: _loading,
        error: _error,
        balances: _balances,
        requests: _requests,
        onRefresh: _fetchLeaveData,
        onCancel: _cancelLeave,
      ),
    );
  }
}

class _DesktopLeave extends StatelessWidget {
  const _DesktopLeave({
    required this.mode,
    required this.loading,
    required this.error,
    required this.balances,
    required this.requests,
    required this.onRefresh,
    required this.onCancel,
  });

  final String mode;
  final bool loading;
  final String? error;
  final List<dynamic> balances;
  final List<dynamic> requests;
  final VoidCallback onRefresh;
  final ValueChanged<dynamic> onCancel;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return _LeaveLoadError(message: error!, onRetry: onRefresh);
    }

    if (mode == 'requests') {
      return _RequestList(requests: requests, onCancel: onCancel);
    }

    return Column(
      children: [
        _LeaveBalance(balances: balances),
        const SizedBox(height: 20),
        _LeaveForm(desktop: true, onSuccess: onRefresh),
      ],
    );
  }
}

void _showLeaveHistoryDialog(BuildContext context, List<dynamic> requests) {
  String statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return 'Approved';
      case 'DENIED':
      case 'CANCELLED':
        return 'Rejected';
      default:
        return 'Pending';
    }
  }

  Color statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return employeeGreen;
      case 'DENIED':
      case 'CANCELLED':
        return const Color(0xFFF12B46);
      default:
        return employeeOrange;
    }
  }

  String fmtDate(String? v) {
    final dt = DateTime.tryParse(v ?? '');
    return dt == null ? (v ?? '--') : DateFormat('dd/MM/yyyy').format(dt);
  }

  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.history_rounded,
                    color: employeePurple,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Leave History',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF4F6FB),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Past and pending leave requests',
                style: TextStyle(fontSize: 12, color: employeeMuted),
              ),
              const SizedBox(height: 16),
              if (requests.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No leave requests found.',
                      style: TextStyle(color: employeeMuted),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: requests.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final r = requests[i];
                      final status = r['status']?.toString() ?? 'Pending';
                      final color = statusColor(status);
                      final dateStr = fmtDate(r['from_date']?.toString());
                      final leaveType = r['leave_type']?.toString() ?? '';
                      final durationType =
                          r['duration_type']?.toString() ?? 'Full Day';
                      String dateRange = '--';
                      try {
                        final from = DateTime.parse(r['from_date'].toString());
                        final to = DateTime.parse(r['to_date'].toString());
                        dateRange = from == to
                            ? DateFormat('d MMM yyyy').format(from)
                            : '${DateFormat('d MMM').format(from)} – ${DateFormat('d MMM yyyy').format(to)}';
                      } catch (_) {}
                      final reason = r['reason']?.toString() ?? '';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.shield_outlined,
                              color: employeePurple,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dateStr,
                                    style: const TextStyle(
                                      color: employeeNavy,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '$leaveType · $durationType · $dateRange',
                                    style: const TextStyle(
                                      color: employeeMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                  if (reason.isNotEmpty)
                                    Text(
                                      reason,
                                      style: const TextStyle(
                                        color: employeeMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: .10),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                statusLabel(status),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: color,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _LeaveBalance extends StatelessWidget {
  const _LeaveBalance({required this.balances});
  final List<dynamic> balances;

  static const _palette = [
    employeeGreen,
    employeePurple,
    employeeBlue,
    employeeOrange,
  ];

  static final _typeColorCache = <String, Color>{};
  static int _nextIndex = 0;

  Color _colorFor(String type) {
    if (_typeColorCache.containsKey(type)) return _typeColorCache[type]!;
    switch (type) {
      case 'Casual Leave':
        return _typeColorCache[type] = employeeGreen;
      case 'Sick Leave':
        return _typeColorCache[type] = employeePurple;
      case 'Earned Leave':
        return _typeColorCache[type] = employeeBlue;
      case 'Annual Leave':
        return _typeColorCache[type] = employeeBlue;
      case 'Maternity Leave':
        return _typeColorCache[type] = employeeOrange;
      case 'Paternity Leave':
        return _typeColorCache[type] = employeeOrange;
      default:
        final c = _palette[_nextIndex % _palette.length];
        _nextIndex++;
        return _typeColorCache[type] = c;
    }
  }

  @override
  Widget build(BuildContext context) => EmployeeCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (balances.isEmpty)
          const Text(
            'No balance data available',
            style: TextStyle(color: employeeMuted),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final visible = balances
                  .where((b) => b['show_balance_card'] == true)
                  .take(4)
                  .toList();
              final count = visible.length;
              if (count == 0) {
                return const Text(
                  'No balance data available',
                  style: TextStyle(color: employeeMuted),
                );
              }
              final w = constraints.maxWidth;
              // columns: match visible card count, collapse on small screens
              final cols = w < 400
                  ? 1
                  : w < 600
                  ? (count == 1 ? 1 : 2)
                  : count.clamp(1, 4);
              final spacing = 14.0 * (cols - 1);
              final boxWidth = (w - spacing) / cols;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: visible.map((b) {
                  final total = _leaveDays(b['total']);
                  final used = _leaveDays(b['used']);
                  final type = b['type']?.toString() ?? 'Leave';
                  return SizedBox(
                    width: boxWidth,
                    child: _BalanceBox(
                      label: type,
                      remaining: (total - used).clamp(0, total).toDouble(),
                      total: total,
                      used: used,
                      usageOnly: _isUsageOnly(b),
                      color: _colorFor(type),
                    ),
                  );
                }).toList(),
              );
            },
          ),
      ],
    ),
  );
}

class _LeaveLoadError extends StatelessWidget {
  const _LeaveLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => EmployeeCard(
    child: Row(
      children: [
        const Icon(Icons.cloud_off_outlined, color: employeeOrange),
        const SizedBox(width: 12),
        Expanded(
          child: Text(message, style: const TextStyle(color: employeeMuted)),
        ),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
        ),
      ],
    ),
  );
}

class _BalanceBox extends StatelessWidget {
  const _BalanceBox({
    required this.label,
    required this.remaining,
    required this.total,
    required this.used,
    required this.usageOnly,
    required this.color,
  });

  final String label;
  final double remaining;
  final double total;
  final double used;
  final bool usageOnly;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      border: Border.all(color: color.withValues(alpha: 0.22)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(height: 14),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: employeeMuted),
        ),
        const SizedBox(height: 4),
        Text(
          usageOnly
              ? '${_formatLeaveDays(used)} days used'
              : '${_formatLeaveDays(remaining)} / ${_formatLeaveDays(total)} days',
          style: TextStyle(
            color: color,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _RequestList extends StatelessWidget {
  const _RequestList({required this.requests, required this.onCancel});
  final List<dynamic> requests;
  final ValueChanged<dynamic> onCancel;

  @override
  Widget build(BuildContext context) => EmployeeCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(
          'Leave History',
          subtitle: 'Past and pending leave requests',
        ),
        const SizedBox(height: 14),
        if (requests.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'No leave requests found.',
                style: TextStyle(color: employeeMuted),
              ),
            ),
          )
        else
          ...requests.map((r) => _LeaveHistoryRow(r: r, onCancel: onCancel)),
      ],
    ),
  );
}

class _LeaveHistoryRow extends StatelessWidget {
  const _LeaveHistoryRow({required this.r, required this.onCancel});
  final dynamic r;
  final ValueChanged<dynamic> onCancel;

  Color _statusColor(String status) {
    switch (status) {
      case 'APPROVED':
        return const Color(0xFF14863C);
      case 'DENIED':
      case 'CANCELLED':
        return const Color(0xFFF12B46);
      default:
        return employeeOrange;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'APPROVED':
        return 'Approved';
      case 'DENIED':
        return 'Rejected';
      case 'CANCELLED':
        return 'Cancelled';
      default:
        return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    DateTime? fromDt;
    DateTime? toDt;
    try {
      fromDt = DateTime.parse(r['from_date'].toString());
      toDt = DateTime.parse(r['to_date'].toString());
    } catch (_) {}

    final dateStr = fromDt != null
        ? DateFormat('dd/MM/yyyy').format(fromDt)
        : '--';
    final dateRange = fromDt != null && toDt != null
        ? (fromDt == toDt
              ? DateFormat('d MMM yyyy').format(fromDt)
              : '${DateFormat('d MMM').format(fromDt)} – ${DateFormat('d MMM yyyy').format(toDt)}')
        : '--';
    final status = r['status']?.toString() ?? 'PENDING';
    final color = _statusColor(status);
    final leaveType = r['leave_type']?.toString() ?? '';
    final durationType = r['duration_type']?.toString() ?? 'Full Day';
    final reason = r['reason']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: employeeLine)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: employeePurple.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shield_outlined, size: 16, color: employeePurple),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateStr,
                  style: const TextStyle(
                    color: employeeNavy,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$leaveType · $durationType · $dateRange',
                  style: const TextStyle(color: employeeMuted, fontSize: 12),
                ),
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    reason,
                    style: const TextStyle(color: employeeMuted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (status == 'PENDING') ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => onCancel(r['id']),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFFF12B46),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _LeaveForm extends StatefulWidget {
  const _LeaveForm({required this.desktop, required this.onSuccess});
  final bool desktop;
  final VoidCallback onSuccess;

  @override
  State<_LeaveForm> createState() => _LeaveFormState();
}

// Holds the full leave type record returned by the admin API.
class _LeaveTypeOption {
  final int id;
  final String name;
  final String? abbreviation;
  final bool allowHalfDay;
  const _LeaveTypeOption({
    required this.id,
    required this.name,
    this.abbreviation,
    required this.allowHalfDay,
  });
  String get label => (abbreviation != null && abbreviation!.isNotEmpty)
      ? '${abbreviation!} · $name'
      : name;
}

class _LeaveFormState extends State<_LeaveForm> {
  _LeaveTypeOption? _selectedType;
  String duration = 'Full Day';
  List<_LeaveTypeOption> _types = [];
  bool _loadingTypes = true;
  DateTime fromDate = DateTime.now();
  DateTime toDate = DateTime.now();
  final _reasonCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadTypes();
  }

  Future<void> _loadTypes() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/attendance/leave/types'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final list = (body['data'] as List)
            .map(
              (item) => _LeaveTypeOption(
                id: int.tryParse('${item['id']}') ?? 0,
                name: item['name'].toString(),
                abbreviation: item['abbreviation']?.toString(),
                // A legacy server may omit this newly-added field; preserve the
                // previous behaviour until the policy migration is available.
                allowHalfDay:
                    item['allow_half_day'] != false &&
                    item['allow_half_day'] != 0,
              ),
            )
            .toList();
        if (mounted)
          setState(() {
            _types = list;
            _selectedType = list.isEmpty ? null : list.first;
            _loadingTypes = false;
          });
      } else {
        if (mounted) setState(() => _loadingTypes = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTypes = false);
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? fromDate : toDate).isBefore(today)
          ? today
          : (isFrom ? fromDate : toDate),
      firstDate: today,
      lastDate: DateTime(today.year + 10),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          fromDate = picked;
          if (toDate.isBefore(fromDate)) toDate = fromDate;
        } else {
          toDate = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;

    if (_selectedType == null || _reasonCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a leave type and provide a reason.'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    final payload = {
      'leave_type': _selectedType!.name,
      'leave_type_id': _selectedType!.id,
      'duration_type': duration,
      'from_date': DateFormat('yyyy-MM-dd').format(fromDate),
      'to_date': DateFormat('yyyy-MM-dd').format(toDate),
      'reason': _reasonCtrl.text.trim(),
    };

    final candidateUrls = _attendanceBaseUrls()
        .map((base) => '$base/leave/apply')
        .toList();

    bool ok = false;
    String? errorMessage;
    for (final base in candidateUrls) {
      try {
        final res = await http.post(
          Uri.parse(base),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(payload),
        );
        final body = jsonDecode(res.body);
        if (res.statusCode == 200 && body['success'] == true) {
          ok = true;
          break;
        }
        errorMessage = body is Map ? body['message']?.toString() : null;
      } catch (_) {}
    }

    if (mounted) {
      setState(() => _submitting = false);
      if (ok) {
        _reasonCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leave application submitted successfully!'),
          ),
        );
        widget.onSuccess();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage ?? 'Failed to submit leave. Check connection.',
            ),
          ),
        );
      }
    }
  }

  Widget _durationField(String label) {
    final allowHalfDay = _selectedType?.allowHalfDay ?? false;
    final options = allowHalfDay
        ? const ['Full Day', 'Half Day']
        : const ['Full Day'];
    return _DropdownField(
      label,
      duration,
      options,
      (v) => setState(() => duration = v!),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingTypes) return const Center(child: CircularProgressIndicator());
    if (_types.isEmpty)
      return const EmployeeCard(
        child: Text('No active leave types are configured by Admin.'),
      );
    final fromStr = DateFormat('dd/MM/yyyy').format(fromDate);
    final toStr = DateFormat('dd/MM/yyyy').format(toDate);

    return EmployeeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            'Apply for Leave',
            subtitle: 'Submit a new leave request for manager approval',
          ),
          const SizedBox(height: 18),
          if (widget.desktop)
            Row(
              children: [
                Expanded(
                  child: _LeaveTypeDropdown(
                    label: 'LEAVE TYPE',
                    value: _selectedType,
                    items: _types,
                    onChanged: (v) => setState(() {
                      _selectedType = v;
                      if (v != null && !v.allowHalfDay) duration = 'Full Day';
                    }),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(child: _durationField('DURATION')),
              ],
            )
          else ...[
            _LeaveTypeDropdown(
              label: 'Leave Type',
              value: _selectedType,
              items: _types,
              onChanged: (v) => setState(() {
                _selectedType = v;
                if (v != null && !v.allowHalfDay) duration = 'Full Day';
              }),
            ),
            const SizedBox(height: 14),
            _durationField('Duration'),
          ],
          const SizedBox(height: 14),
          if (widget.desktop)
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(true),
                    child: _DateFieldShell('FROM DATE', fromStr),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(false),
                    child: _DateFieldShell('TO DATE', toStr),
                  ),
                ),
              ],
            )
          else ...[
            InkWell(
              onTap: () => _pickDate(true),
              child: _DateFieldShell('From Date', fromStr),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: () => _pickDate(false),
              child: _DateFieldShell('To Date', toStr),
            ),
          ],
          const SizedBox(height: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'REASON',
                style: TextStyle(
                  color: employeeNavy,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _reasonCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Briefly describe the reason for leave...',
                  filled: true,
                  fillColor: const Color(0xFFFBFCFE),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderSide: const BorderSide(color: employeeLine),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: employeeLine),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  onPressed: () => setState(() {
                    _reasonCtrl.clear();
                    fromDate = DateTime.now();
                    toDate = DateTime.now();
                  }),
                  child: const Text('Clear'),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_outlined, size: 16),
                  label: Text(_submitting ? 'Submitting…' : 'Submit Request'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B72F5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DateFieldShell extends StatelessWidget {
  const _DateFieldShell(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: employeeNavy,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFBFCFE),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: employeeLine),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: employeeMuted,
            ),
            const SizedBox(width: 10),
            Text(
              value,
              style: const TextStyle(
                color: employeeNavy,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _LeaveTypeDropdown extends StatelessWidget {
  const _LeaveTypeDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label;
  final _LeaveTypeOption? value;
  final List<_LeaveTypeOption> items;
  final ValueChanged<_LeaveTypeOption?> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: employeeNavy,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 6),
      DropdownButtonFormField<_LeaveTypeOption>(
        value: value,
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFFFBFCFE),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          border: OutlineInputBorder(
            borderSide: const BorderSide(color: employeeLine),
            borderRadius: BorderRadius.circular(8),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: employeeLine),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        items: items
            .map(
              (opt) => DropdownMenuItem(
                value: opt,
                child: Row(
                  children: [
                    if (opt.abbreviation != null &&
                        opt.abbreviation!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F0FF),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          opt.abbreviation!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0B72F5),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(opt.name),
                  ],
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    ],
  );
}

class _DropdownField extends StatelessWidget {
  const _DropdownField(this.label, this.value, this.items, this.onChanged);
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: employeeNavy,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 6),
      DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFFFBFCFE),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          border: OutlineInputBorder(
            borderSide: const BorderSide(color: employeeLine),
            borderRadius: BorderRadius.circular(8),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: employeeLine),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        items: items
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: onChanged,
      ),
    ],
  );
}

class _MobileLeaveBalance extends StatelessWidget {
  const _MobileLeaveBalance({required this.balances});

  final List<dynamic> balances;

  Color _colorFor(String type) {
    final value = type.toLowerCase();
    if (value.contains('sick')) return const Color(0xFF7C2BEF);
    if (value.contains('earned')) return const Color(0xFF126DF3);
    if (value.contains('optional')) return const Color(0xFFFF6A00);
    return const Color(0xFF00AE7B);
  }

  @override
  Widget build(BuildContext context) {
    final displayBalances = balances
        .where((balance) => balance['show_balance_card'] == true)
        .take(4)
        .toList();
    return EmployeeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Leave Balance',
                  style: TextStyle(
                    color: employeeNavy,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/employee/leave',
                  arguments: 'requests',
                ),
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                label: const Text('View Details'),
                style: TextButton.styleFrom(
                  foregroundColor: employeeBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (displayBalances.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('Leave balances are not available yet.'),
              ),
            )
          else
            Row(
              children: List.generate(displayBalances.length, (index) {
                final balance = displayBalances[index];
                final type = (balance['type'] ?? 'Leave').toString();
                final total = _leaveDays(balance['total']);
                final used = _leaveDays(balance['used']);
                final remaining = (total - used).clamp(0, total).toDouble();
                final usageOnly = _isUsageOnly(balance);
                final color = _colorFor(type);
                return Expanded(
                  child: Container(
                    height: 112,
                    margin: EdgeInsets.only(
                      right: index == displayBalances.length - 1 ? 0 : 8,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.045),
                      border: Border.all(
                        color: color.withValues(alpha: 0.26),
                        width: 1.2,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: employeeMuted,
                            fontSize: 11,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatLeaveDays(usageOnly ? used : remaining),
                          style: TextStyle(
                            color: color,
                            fontSize: 29,
                            height: 1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          usageOnly
                              ? 'days used'
                              : 'of ${_formatLeaveDays(total)}',
                          style: const TextStyle(
                            color: employeeMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}

class _MobileLeave extends StatelessWidget {
  const _MobileLeave({
    required this.mode,
    required this.loading,
    required this.error,
    required this.balances,
    required this.requests,
    required this.onRefresh,
    required this.onCancel,
  });

  final String mode;
  final bool loading;
  final String? error;
  final List<dynamic> balances;
  final List<dynamic> requests;
  final VoidCallback onRefresh;
  final ValueChanged<dynamic> onCancel;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MobileEmployeeHeader(),
          const SizedBox(height: 20),
          _LeaveLoadError(message: error!, onRetry: onRefresh),
        ],
      );
    }

    if (mode == 'requests') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MobileEmployeeHeader(),
          const SizedBox(height: 14),
          const EmployeePageTitle(title: 'My Requests'),
          const SizedBox(height: 20),
          _RequestList(requests: requests, onCancel: onCancel),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MobileEmployeeHeader(),
        const SizedBox(height: 18),
        _MobileLeaveBalance(balances: balances),
        const SizedBox(height: 18),
        _LeaveForm(desktop: false, onSuccess: onRefresh),
      ],
    );
  }
}
