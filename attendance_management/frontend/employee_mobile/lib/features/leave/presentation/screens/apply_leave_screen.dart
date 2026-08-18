import 'package:employee_mobile/features/leave/data/models/leave_dashboard_response.dart';
import 'package:employee_mobile/features/leave/presentation/controllers/leave_controller.dart';
import 'package:flutter/material.dart';

class ApplyLeaveScreen extends StatefulWidget {
  const ApplyLeaveScreen({
    required this.controller,
    this.initialLeaveTypeId,
    super.key,
  });

  final LeaveController controller;
  final int? initialLeaveTypeId;

  @override
  State<ApplyLeaveScreen> createState() {
    return _ApplyLeaveScreenState();
  }
}

class _ApplyLeaveScreenState
    extends State<ApplyLeaveScreen> {
  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController _reasonController =
      TextEditingController();

  final TextEditingController
      _attachmentController =
      TextEditingController();

  int? _selectedLeaveTypeId;

  DateTime _startDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  DateTime _endDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  String _selectedDayType = 'full_day';

  @override
  void initState() {
    super.initState();

    _setInitialLeaveType();

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        widget.controller.clearMessages();
      },
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _attachmentController.dispose();

    super.dispose();
  }

  LeaveBalance? get _selectedBalance {
    final leaveTypeId =
        _selectedLeaveTypeId;

    if (leaveTypeId == null) {
      return null;
    }

    return widget.controller
        .findBalanceByLeaveTypeId(
      leaveTypeId,
    );
  }

  double get _requestedDays {
    if (_selectedDayType != 'full_day') {
      return 0.5;
    }

    final start = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
    );

    final end = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
    );

    if (end.isBefore(start)) {
      return 0;
    }

    return end.difference(start).inDays + 1;
  }

  void _setInitialLeaveType() {
    final balances =
        widget.controller.balances;

    if (balances.isEmpty) {
      _selectedLeaveTypeId = null;
      return;
    }

    final requestedId =
        widget.initialLeaveTypeId;

    if (requestedId != null) {
      for (final balance in balances) {
        if (balance.leaveTypeId ==
            requestedId) {
          _selectedLeaveTypeId =
              requestedId;

          return;
        }
      }
    }

    _selectedLeaveTypeId =
        balances.first.leaveTypeId;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Apply Leave',
            ),
          ),
          body: SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                padding:
                    const EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  32,
                ),
                children: <Widget>[
                  _buildHeading(context),
                  const SizedBox(height: 20),
                  _buildLeaveTypeField(),
                  const SizedBox(height: 14),
                  if (_selectedBalance !=
                      null) ...<Widget>[
                    _buildBalanceInformation(
                      context,
                      _selectedBalance!,
                    ),
                    const SizedBox(height: 18),
                  ],
                  _buildDateFields(),
                  const SizedBox(height: 16),
                  _buildDayTypeField(),
                  const SizedBox(height: 16),
                  _buildRequestedDaysCard(
                    context,
                  ),
                  const SizedBox(height: 16),
                  _buildReasonField(),
                  const SizedBox(height: 16),
                  _buildAttachmentField(),
                  if (widget.controller
                          .errorMessage !=
                      null) ...<Widget>[
                    const SizedBox(height: 16),
                    _buildErrorMessage(
                      context,
                    ),
                  ],
                  const SizedBox(height: 24),
                  _buildSubmitButton(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeading(
    BuildContext context,
  ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Submit a leave request',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(
                color:
                    colorScheme.onSurface,
                fontWeight:
                    FontWeight.w900,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Choose your leave type, dates and provide a reason.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(
                color: colorScheme
                    .onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildLeaveTypeField() {
    final balances =
        widget.controller.balances;

    return DropdownButtonFormField<int>(
      initialValue:
          _selectedLeaveTypeId,
      decoration: const InputDecoration(
        labelText: 'Leave type',
        prefixIcon: Icon(
          Icons.event_available_outlined,
        ),
        border: OutlineInputBorder(),
      ),
      isExpanded: true,
      items: balances.map(
        (balance) {
          return DropdownMenuItem<int>(
            value: balance.leaveTypeId,
            child: Text(
              '${balance.name} '
              '(${_formatDays(balance.availableDays)} available)',
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
            ),
          );
        },
      ).toList(),
      onChanged:
          widget.controller.isSubmitting
              ? null
              : (value) {
                  setState(() {
                    _selectedLeaveTypeId =
                        value;
                  });
                },
      validator: (value) {
        if (value == null) {
          return 'Please select a leave type.';
        }

        return null;
      },
    );
  }

  Widget _buildBalanceInformation(
    BuildContext context,
    LeaveBalance balance,
  ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer
            .withValues(
          alpha: 0.45,
        ),
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.primary
              .withValues(
            alpha: 0.18,
          ),
        ),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _BalanceItem(
                  label: 'Available',
                  value:
                      '${_formatDays(balance.availableDays)} days',
                ),
              ),
              Expanded(
                child: _BalanceItem(
                  label: 'Used',
                  value:
                      '${_formatDays(balance.usedDays)} days',
                ),
              ),
              Expanded(
                child: _BalanceItem(
                  label: 'Pending',
                  value:
                      '${_formatDays(balance.pendingDays)} days',
                ),
              ),
            ],
          ),
          if (balance.requiresAttachment ||
              balance.maxConsecutiveDays !=
                  null) ...<Widget>[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            if (balance
                .requiresAttachment)
              Row(
                children: <Widget>[
                  Icon(
                    Icons.attach_file_rounded,
                    size: 18,
                    color: colorScheme
                        .onPrimaryContainer,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Attachment is required for this leave type.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: colorScheme
                                .onPrimaryContainer,
                            fontWeight:
                                FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            if (balance
                    .maxConsecutiveDays !=
                null) ...<Widget>[
              if (balance
                  .requiresAttachment)
                const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: colorScheme
                        .onPrimaryContainer,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Maximum '
                      '${balance.maxConsecutiveDays} '
                      'consecutive days allowed.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: colorScheme
                                .onPrimaryContainer,
                            fontWeight:
                                FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildDateFields() {
    return Row(
      children: <Widget>[
        Expanded(
          child: _LeaveDateField(
            label: 'Start date',
            date: _startDate,
            onTap: _selectStartDate,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _LeaveDateField(
            label: 'End date',
            date: _endDate,
            onTap: _selectEndDate,
          ),
        ),
      ],
    );
  }

  Widget _buildDayTypeField() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedDayType,
      decoration: const InputDecoration(
        labelText: 'Day type',
        prefixIcon: Icon(
          Icons.schedule_rounded,
        ),
        border: OutlineInputBorder(),
      ),
      items:
          const <DropdownMenuItem<String>>[
        DropdownMenuItem<String>(
          value: 'full_day',
          child: Text('Full Day'),
        ),
        DropdownMenuItem<String>(
          value: 'first_half',
          child: Text('First Half'),
        ),
        DropdownMenuItem<String>(
          value: 'second_half',
          child: Text('Second Half'),
        ),
      ],
      onChanged:
          widget.controller.isSubmitting
              ? null
              : (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _selectedDayType =
                        value;

                    if (value !=
                        'full_day') {
                      _endDate =
                          _startDate;
                    }
                  });
                },
    );
  }

  Widget _buildRequestedDaysCard(
    BuildContext context,
  ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    final balance =
        _selectedBalance;

    final insufficientBalance =
        balance != null &&
            balance.isPaid &&
            _requestedDays >
                balance.availableDays;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: insufficientBalance
            ? colorScheme.errorContainer
            : colorScheme
                .surfaceContainerHighest,
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            insufficientBalance
                ? Icons
                    .warning_amber_rounded
                : Icons
                    .calendar_today_outlined,
            color: insufficientBalance
                ? colorScheme
                    .onErrorContainer
                : colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              insufficientBalance
                  ? 'Insufficient leave balance'
                  : 'Requested duration',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    color: insufficientBalance
                        ? colorScheme
                            .onErrorContainer
                        : colorScheme
                            .onSurfaceVariant,
                    fontWeight:
                        FontWeight.w600,
                  ),
            ),
          ),
          Text(
            '${_formatDays(_requestedDays)} '
            '${_requestedDays == 1 ? 'day' : 'days'}',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(
                  color: insufficientBalance
                      ? colorScheme
                          .onErrorContainer
                      : colorScheme
                          .onSurface,
                  fontWeight:
                      FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonField() {
    return TextFormField(
      controller: _reasonController,
      enabled:
          !widget.controller.isSubmitting,
      minLines: 3,
      maxLines: 5,
      maxLength: 500,
      textCapitalization:
          TextCapitalization.sentences,
      decoration: const InputDecoration(
        labelText: 'Reason',
        hintText:
            'Enter the reason for your leave',
        alignLabelWithHint: true,
        prefixIcon: Padding(
          padding: EdgeInsets.only(
            bottom: 68,
          ),
          child: Icon(
            Icons.notes_rounded,
          ),
        ),
        border: OutlineInputBorder(),
      ),
      validator: (value) {
        final reason =
            value?.trim() ?? '';

        if (reason.isEmpty) {
          return 'Please enter a leave reason.';
        }

        if (reason.length < 3) {
          return 'Reason must contain at least 3 characters.';
        }

        return null;
      },
    );
  }

  Widget _buildAttachmentField() {
    final requiresAttachment =
        _selectedBalance
                ?.requiresAttachment ??
            false;

    return TextFormField(
      controller:
          _attachmentController,
      enabled:
          !widget.controller.isSubmitting,
      keyboardType: TextInputType.url,
      decoration: InputDecoration(
        labelText: requiresAttachment
            ? 'Attachment URL'
            : 'Attachment URL (optional)',
        hintText:
            'https://example.com/document.pdf',
        prefixIcon: const Icon(
          Icons.attach_file_rounded,
        ),
        border:
            const OutlineInputBorder(),
      ),
      validator: (value) {
        final attachment =
            value?.trim() ?? '';

        if (requiresAttachment &&
            attachment.isEmpty) {
          return 'Attachment is required for this leave type.';
        }

        if (attachment.isNotEmpty) {
          final uri =
              Uri.tryParse(attachment);

          if (uri == null ||
              !uri.hasScheme ||
              !uri.hasAuthority) {
            return 'Enter a valid attachment URL.';
          }
        }

        return null;
      },
    );
  }

  Widget _buildErrorMessage(
    BuildContext context,
  ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius:
            BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.error_outline_rounded,
            color:
                colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              widget.controller
                  .errorMessage!,
              style: TextStyle(
                color: colorScheme
                    .onErrorContainer,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final isSubmitting =
        widget.controller.isSubmitting;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed:
            isSubmitting ? null : _submit,
        icon: isSubmitting
            ? const SizedBox(
                width: 19,
                height: 19,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
            : const Icon(
                Icons.send_rounded,
              ),
        label: Text(
          isSubmitting
              ? 'Submitting...'
              : 'Submit Leave Request',
        ),
      ),
    );
  }

  Future<void> _selectStartDate() async {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    final selectedDate =
        await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: today,
      lastDate: DateTime(
        today.year + 2,
        12,
        31,
      ),
      helpText: 'Select start date',
    );

    if (selectedDate == null ||
        !mounted) {
      return;
    }

    setState(() {
      _startDate = selectedDate;

      if (_endDate
              .isBefore(_startDate) ||
          _selectedDayType !=
              'full_day') {
        _endDate = selectedDate;
      }
    });
  }

  Future<void> _selectEndDate() async {
    final selectedDate =
        await showDatePicker(
      context: context,
      initialDate:
          _endDate.isBefore(_startDate)
              ? _startDate
              : _endDate,
      firstDate: _startDate,
      lastDate: DateTime(
        _startDate.year + 2,
        12,
        31,
      ),
      helpText: 'Select end date',
    );

    if (selectedDate == null ||
        !mounted) {
      return;
    }

    setState(() {
      _endDate = selectedDate;
    });
  }

  Future<void> _submit() async {
    widget.controller.clearMessages();

    final isFormValid =
        _formKey.currentState?.validate() ??
            false;

    if (!isFormValid) {
      return;
    }

    final leaveTypeId =
        _selectedLeaveTypeId;

    if (leaveTypeId == null) {
      return;
    }

    final balance =
        _selectedBalance;

    if (balance != null) {
      if (balance.isPaid &&
          _requestedDays >
              balance.availableDays) {
        _showMessage(
          'You do not have enough leave balance.',
        );

        return;
      }

      final maximumDays =
          balance.maxConsecutiveDays;

      if (maximumDays != null &&
          _requestedDays >
              maximumDays) {
        _showMessage(
          'Maximum $maximumDays consecutive days are allowed.',
        );

        return;
      }
    }

    final result =
        await widget.controller.submitLeave(
      leaveTypeId: leaveTypeId,
      startDate: _startDate,
      endDate: _endDate,
      dayType: _selectedDayType,
      reason: _reasonController.text,
      attachmentUrl:
          _attachmentController.text,
    );

    if (!mounted || result == null) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          widget.controller
                  .successMessage ??
              'Leave request submitted successfully.',
        ),
      ),
    );

    Navigator.of(context).pop(true);
  }

  void _showMessage(
    String message,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  static String _formatDays(
    double value,
  ) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(1);
  }
}

class _LeaveDateField
    extends StatelessWidget {
  const _LeaveDateField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(
            Icons.calendar_month_rounded,
          ),
          border:
              const OutlineInputBorder(),
        ),
        child: Text(
          _formatDate(date),
          maxLines: 1,
          overflow:
              TextOverflow.ellipsis,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(
                fontWeight:
                    FontWeight.w700,
              ),
        ),
      ),
    );
  }

  String _formatDate(
    DateTime value,
  ) {
    final day = value.day
        .toString()
        .padLeft(2, '0');

    final month = value.month
        .toString()
        .padLeft(2, '0');

    return '$day/$month/${value.year}';
  }
}

class _BalanceItem extends StatelessWidget {
  const _BalanceItem({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Column(
      children: <Widget>[
        Text(
          value,
          maxLines: 1,
          overflow:
              TextOverflow.ellipsis,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(
                color: colorScheme
                    .onPrimaryContainer,
                fontWeight:
                    FontWeight.w900,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow:
              TextOverflow.ellipsis,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(
                color: colorScheme
                    .onPrimaryContainer
                    .withValues(
                  alpha: 0.75,
                ),
              ),
        ),
      ],
    );
  }
}