import 'package:dio/dio.dart';
import 'package:employee_mobile/core/network/api_client.dart';
import 'package:employee_mobile/features/leave/data/models/leave_dashboard_response.dart';
import 'package:employee_mobile/features/leave/presentation/controllers/leave_controller.dart';
import 'package:employee_mobile/features/leave/presentation/screens/apply_leave_screen.dart';
import 'package:employee_mobile/features/leave/presentation/screens/leave_history_screen.dart';
import 'package:employee_mobile/features/leave/presentation/widgets/leave_balance_card.dart';
import 'package:employee_mobile/features/leave/presentation/widgets/leave_summary_card.dart';
import 'package:flutter/material.dart';

class LeaveDashboardScreen extends StatefulWidget {
  const LeaveDashboardScreen({required this.controller, super.key});

  final LeaveController controller;

  @override
  State<LeaveDashboardScreen> createState() {
    return _LeaveDashboardScreenState();
  }
}

class _LeaveDashboardScreenState extends State<LeaveDashboardScreen> {
  String? _lastDisplayedError;
  String? _lastDisplayedSuccess;

  @override
  void initState() {
    super.initState();

    widget.controller.addListener(_handleControllerMessages);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.clearMessages();

      if (!widget.controller.hasDashboardData) {
        widget.controller.initialize();
      }
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerMessages);

    super.dispose();
  }

  void _handleControllerMessages() {
    if (!mounted) {
      return;
    }

    final errorMessage = widget.controller.errorMessage;

    final successMessage = widget.controller.successMessage;

    if (errorMessage != null &&
        errorMessage.isNotEmpty &&
        errorMessage != _lastDisplayedError) {
      _lastDisplayedError = errorMessage;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
      });
    }

    if (successMessage != null &&
        successMessage.isNotEmpty &&
        successMessage != _lastDisplayedSuccess) {
      _lastDisplayedSuccess = successMessage;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(successMessage)));
      });
    }

    if (errorMessage == null) {
      _lastDisplayedError = null;
    }

    if (successMessage == null) {
      _lastDisplayedSuccess = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Leave Management'),
            actions: <Widget>[
              IconButton(
                tooltip: 'Leave history',
                onPressed: _openLeaveHistory,
                icon: const Icon(Icons.history_rounded),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: widget.controller.isBusy
                    ? null
                    : widget.controller.refreshAll,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          floatingActionButton: widget.controller.hasDashboardData
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    FloatingActionButton.extended(
                      heroTag: 'apply_permission_fab',
                      onPressed: widget.controller.isBusy
                          ? null
                          : _openApplyPermission,
                      icon: const Icon(Icons.schedule_send_rounded),
                      label: const Text('Apply Permission'),
                    ),
                    const SizedBox(height: 12),
                    FloatingActionButton.extended(
                      heroTag: 'apply_leave_fab',
                      onPressed: widget.controller.isBusy
                          ? null
                          : _openApplyLeave,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Apply Leave'),
                    ),
                  ],
                )
              : null,
          body: SafeArea(child: _buildBody(context)),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    final controller = widget.controller;

    if (controller.isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!controller.hasDashboardData && controller.errorMessage != null) {
      return _DashboardMessageState(
        icon: Icons.error_outline_rounded,
        title: 'Unable to load leave details',
        message: controller.errorMessage!,
        buttonLabel: 'Try Again',
        onPressed: controller.initialize,
      );
    }

    final dashboard = controller.dashboardData;

    if (dashboard == null) {
      return _DashboardMessageState(
        icon: Icons.event_busy_rounded,
        title: 'No leave information',
        message: 'Leave information is currently unavailable.',
        buttonLabel: 'Refresh',
        onPressed: controller.initialize,
      );
    }

    return Stack(
      children: <Widget>[
        RefreshIndicator(
          onRefresh: widget.controller.refreshAll,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            children: <Widget>[
              _buildWelcomeSection(context, dashboard),
              const SizedBox(height: 18),
              _buildYearSelector(context),
              const SizedBox(height: 22),
              _buildSummarySection(context, dashboard.requestSummary),
              const SizedBox(height: 24),
              _buildBalanceHeading(context),
              const SizedBox(height: 12),
              if (dashboard.balances.isEmpty)
                _buildNoBalances(context)
              else
                ...dashboard.balances.map((balance) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: LeaveBalanceCard(
                      balance: balance,
                      onApply: () {
                        _openApplyLeave(leaveTypeId: balance.leaveTypeId);
                      },
                    ),
                  );
                }),
            ],
          ),
        ),
        if (controller.isDashboardLoading)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              minHeight: 3,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
      ],
    );
  }

  Widget _buildWelcomeSection(
    BuildContext context,
    LeaveDashboardData dashboard,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            colorScheme.primary,
            colorScheme.primary.withValues(alpha: 0.78),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.event_available_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Hello, ${dashboard.employee.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  dashboard.employee.employeeCode.isEmpty
                      ? dashboard.employee.branchName
                      : '${dashboard.employee.employeeCode} • '
                            '${dashboard.employee.branchName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  'Review your balances and submit leave requests.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearSelector(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final currentYear = DateTime.now().year;

    final availableYears = <int>[currentYear - 1, currentYear, currentYear + 1];

    if (!availableYears.contains(widget.controller.selectedYear)) {
      availableYears.add(widget.controller.selectedYear);

      availableYears.sort();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.calendar_today_outlined,
              color: colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Balance year',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.controller.selectedYear.toString(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: widget.controller.selectedYear,
              borderRadius: BorderRadius.circular(14),
              items: availableYears.map((year) {
                return DropdownMenuItem<int>(
                  value: year,
                  child: Text(year.toString()),
                );
              }).toList(),
              onChanged: widget.controller.isBusy
                  ? null
                  : (year) {
                      if (year == null) {
                        return;
                      }

                      widget.controller.changeYear(year);
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(
    BuildContext context,
    LeaveRequestSummary summary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Request Summary',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.75,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: <Widget>[
            LeaveSummaryCard(
              label: 'Total Requests',
              value: summary.totalRequests,
              icon: Icons.description_outlined,
              accentColor: const Color(0xFF1565C0),
              onTap: () {
                _openLeaveHistory();
              },
            ),
            LeaveSummaryCard(
              label: 'Pending',
              value: summary.pendingRequests,
              icon: Icons.hourglass_top_rounded,
              accentColor: const Color(0xFFEF6C00),
              onTap: () {
                _openLeaveHistory(status: 'pending');
              },
            ),
            LeaveSummaryCard(
              label: 'Approved',
              value: summary.approvedRequests,
              icon: Icons.check_circle_outline_rounded,
              accentColor: const Color(0xFF2E7D32),
              onTap: () {
                _openLeaveHistory(status: 'approved');
              },
            ),
            LeaveSummaryCard(
              label: 'Rejected',
              value: summary.rejectedRequests,
              icon: Icons.cancel_outlined,
              accentColor: const Color(0xFFC62828),
              onTap: () {
                _openLeaveHistory(status: 'rejected');
              },
            ),
          ],
        ),
        if (summary.cancelledRequests > 0) ...<Widget>[
          const SizedBox(height: 12),
          LeaveSummaryCard(
            label: 'Cancelled',
            value: summary.cancelledRequests,
            icon: Icons.remove_circle_outline_rounded,
            accentColor: const Color(0xFF546E7A),
            onTap: () {
              _openLeaveHistory(status: 'cancelled');
            },
          ),
        ],
      ],
    );
  }

  Widget _buildBalanceHeading(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            'Leave Balances',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        TextButton.icon(
          onPressed: _openLeaveHistory,
          icon: const Icon(Icons.history_rounded, size: 19),
          label: const Text('History'),
        ),
      ],
    );
  }

  Widget _buildNoBalances(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.event_busy_rounded,
            size: 42,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'No leave balances found',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Leave balances have not been allocated for this year.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openApplyPermission() async {
    final wasSubmitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) {
          return const _ApplyPermissionScreen();
        },
      ),
    );

    if (!mounted) {
      return;
    }

    if (wasSubmitted == true) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Permission request submitted successfully.'),
          ),
        );
    }
  }

  Future<void> _openApplyLeave({int? leaveTypeId}) async {
    widget.controller.clearMessages();

    final wasSubmitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) {
          return ApplyLeaveScreen(
            controller: widget.controller,
            initialLeaveTypeId: leaveTypeId,
          );
        },
      ),
    );

    if (!mounted) {
      return;
    }

    if (wasSubmitted == true) {
      await widget.controller.refreshAll();
    }
  }

  Future<void> _openLeaveHistory({String? status}) async {
    widget.controller.clearMessages();

    if (status == null) {
      await widget.controller.changeStatus(null);
    } else {
      await widget.controller.changeStatus(status);
    }

    if (!mounted) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) {
          return LeaveHistoryScreen(controller: widget.controller);
        },
      ),
    );
  }
}

class _ApplyPermissionScreen extends StatefulWidget {
  const _ApplyPermissionScreen();

  @override
  State<_ApplyPermissionScreen> createState() {
    return _ApplyPermissionScreenState();
  }
}

class _ApplyPermissionScreenState extends State<_ApplyPermissionScreen> {
  final TextEditingController _reasonController = TextEditingController();

  String _requestType = 'late_login';

  DateTime _requestDate = DateTime.now();

  TimeOfDay _requestedTime = TimeOfDay.now();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  String get _requestTypeLabel {
    switch (_requestType) {
      case 'early_logout':
        return 'Early Logout';
      case 'late_login':
      default:
        return 'Late Login';
    }
  }

  String get _requestDateLabel {
    final day = _requestDate.day.toString().padLeft(2, '0');

    final month = _requestDate.month.toString().padLeft(2, '0');

    return '$day/$month/${_requestDate.year}';
  }

  String get _requestedTimeLabel {
    final hour = _requestedTime.hourOfPeriod == 0
        ? 12
        : _requestedTime.hourOfPeriod;

    final minute = _requestedTime.minute.toString().padLeft(2, '0');

    final period = _requestedTime.period == DayPeriod.am ? 'AM' : 'PM';

    return '$hour:$minute $period';
  }

  String get _requestDateApiValue {
    final year = _requestDate.year.toString().padLeft(4, '0');

    final month = _requestDate.month.toString().padLeft(2, '0');

    final day = _requestDate.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  String get _requestedTimeApiValue {
    final hour = _requestedTime.hour.toString().padLeft(2, '0');

    final minute = _requestedTime.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  Future<void> _pickDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _requestDate,
      firstDate: DateTime(DateTime.now().year - 1, 1, 1),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    setState(() {
      _requestDate = selectedDate;
    });
  }

  Future<void> _pickTime() async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: _requestedTime,
    );

    if (selectedTime == null || !mounted) {
      return;
    }

    setState(() {
      _requestedTime = selectedTime;
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    final reason = _reasonController.text.trim();

    if (reason.length < 3) {
      _showMessage('Please enter a valid reason.', isError: true);
      return;
    }

    if (reason.length > 500) {
      _showMessage('Reason must not exceed 500 characters.', isError: true);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final response = await ApiClient.instance.dio.post<dynamic>(
        '/permissions',
        data: <String, dynamic>{
          'request_type': _requestType,
          'request_date': _requestDateApiValue,
          'requested_time': _requestedTimeApiValue,
          'reason': reason,
        },
      );

      final data = response.data;

      if (data is Map && data['success'] == false) {
        final message = data['message']?.toString().trim();

        throw Exception(
          message == null || message.isEmpty
              ? 'Unable to submit permission request.'
              : message,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } on DioException catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(_dioMessage(error), isError: true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = error.toString().replaceFirst('Exception: ', '');

      _showMessage(
        message.isEmpty ? 'Unable to submit permission request.' : message,
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _dioMessage(DioException error) {
    final data = error.response?.data;

    if (data is Map) {
      final message = data['message']?.toString().trim();

      if (message != null && message.isNotEmpty) {
        return message;
      }
    }

    if (error.type == DioExceptionType.connectionTimeout) {
      return 'Connection timed out. Please try again.';
    }

    if (error.type == DioExceptionType.connectionError) {
      return 'Unable to connect to the server.';
    }

    return error.message?.trim().isNotEmpty == true
        ? error.message!.trim()
        : 'Unable to submit permission request.';
  }

  void _showMessage(String message, {required bool isError}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Apply Permission')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Submit a permission request',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Request permission for a late login or early logout.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              DropdownButtonFormField<String>(
                initialValue: _requestType,
                decoration: const InputDecoration(
                  labelText: 'Permission type',
                  prefixIcon: Icon(Icons.fact_check_outlined),
                  border: OutlineInputBorder(),
                ),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(
                    value: 'late_login',
                    child: Text('Late Login'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'early_logout',
                    child: Text('Early Logout'),
                  ),
                ],
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          _requestType = value;
                        });
                      },
              ),
              const SizedBox(height: 16),

              _PermissionFieldCard(
                label: 'Request date',
                value: _requestDateLabel,
                icon: Icons.calendar_month_rounded,
                onTap: _isSubmitting ? null : _pickDate,
              ),
              const SizedBox(height: 16),

              _PermissionFieldCard(
                label: _requestType == 'late_login'
                    ? 'Expected login time'
                    : 'Expected logout time',
                value: _requestedTimeLabel,
                icon: Icons.access_time_rounded,
                onTap: _isSubmitting ? null : _pickTime,
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _reasonController,
                enabled: !_isSubmitting,
                minLines: 5,
                maxLines: 8,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: 'Reason',
                  hintText: _requestType == 'late_login'
                      ? 'Why will you be late?'
                      : 'Why do you need to leave early?',
                  alignLabelWithHint: true,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 86),
                    child: Icon(Icons.notes_rounded),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.info_outline_rounded,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your $_requestTypeLabel request will be sent to the admin for approval.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _isSubmitting
                        ? 'Submitting...'
                        : 'Submit Permission Request',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionFieldCard extends StatelessWidget {
  const _PermissionFieldCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outline),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardMessageState extends StatelessWidget {
  const _DashboardMessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.buttonLabel,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 39, color: colorScheme.primary),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            if (buttonLabel != null && onPressed != null) ...<Widget>[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(buttonLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
