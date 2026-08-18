import 'package:employee_mobile/features/leave/data/models/leave_history_response.dart';
import 'package:employee_mobile/features/leave/presentation/controllers/leave_controller.dart';
import 'package:employee_mobile/features/leave/presentation/widgets/leave_status_chip.dart';
import 'package:flutter/material.dart';

class LeaveRequestDetailsScreen extends StatefulWidget {
  const LeaveRequestDetailsScreen({
    required this.controller,
    required this.request,
    super.key,
  });

  final LeaveController controller;
  final LeaveRequestRecord request;

  @override
  State<LeaveRequestDetailsScreen> createState() {
    return _LeaveRequestDetailsScreenState();
  }
}

class _LeaveRequestDetailsScreenState
    extends State<LeaveRequestDetailsScreen> {
  LeaveRequestRecord get _currentRequest {
    return widget.controller.findRequestById(
          widget.request.leaveRequestId,
        ) ??
        widget.request;
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        widget.controller.clearMessages();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        final request = _currentRequest;

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Leave Details',
            ),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                16,
                16,
                16,
                32,
              ),
              children: <Widget>[
                _buildHeader(
                  context,
                  request,
                ),
                const SizedBox(height: 18),
                _buildLeaveInformation(
                  context,
                  request,
                ),
                const SizedBox(height: 16),
                _buildReasonSection(
                  context,
                  request,
                ),
                if (request.reviewComment != null &&
                    request.reviewComment!
                        .trim()
                        .isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  _buildMessageSection(
                    context: context,
                    icon: Icons.comment_outlined,
                    title: 'Review Comment',
                    message: request.reviewComment!,
                  ),
                ],
                if (request.cancellationReason != null &&
                    request.cancellationReason!
                        .trim()
                        .isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  _buildMessageSection(
                    context: context,
                    icon: Icons.cancel_outlined,
                    title: 'Cancellation Reason',
                    message:
                        request.cancellationReason!,
                  ),
                ],
                if (request.attachmentUrl != null &&
                    request.attachmentUrl!
                        .trim()
                        .isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  _buildAttachmentSection(
                    context,
                    request.attachmentUrl!,
                  ),
                ],
                const SizedBox(height: 16),
                _buildTimelineSection(
                  context,
                  request,
                ),
                if (widget.controller.errorMessage !=
                    null) ...<Widget>[
                  const SizedBox(height: 16),
                  _buildErrorMessage(context),
                ],
                if (request.canCancel) ...<Widget>[
                  const SizedBox(height: 24),
                  _buildCancelButton(
                    context,
                    request,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    LeaveRequestRecord request,
  ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    final accentColor = _getAccentColor(
      request.leaveType.code,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.04,
            ),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accentColor.withValues(
                    alpha: 0.12,
                  ),
                  borderRadius:
                      BorderRadius.circular(16),
                ),
                child: Icon(
                  _getLeaveIcon(
                    request.leaveType.code,
                  ),
                  color: accentColor,
                  size: 27,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      request.leaveType.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                            color:
                                colorScheme.onSurface,
                            fontWeight:
                                FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${request.leaveType.code} • '
                      '${request.leaveType.paymentLabel}',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                            color: colorScheme
                                .onSurfaceVariant,
                            fontWeight:
                                FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              LeaveStatusChip(
                status: request.status,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: colorScheme
                  .surfaceContainerHighest,
              borderRadius:
                  BorderRadius.circular(14),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.calendar_month_outlined,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    request.dateRangeLabel,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          color:
                              colorScheme.onSurface,
                          fontWeight:
                              FontWeight.w800,
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

  Widget _buildLeaveInformation(
    BuildContext context,
    LeaveRequestRecord request,
  ) {
    return _SectionCard(
      title: 'Leave Information',
      child: Column(
        children: <Widget>[
          _DetailRow(
            icon: Icons.schedule_rounded,
            label: 'Duration',
            value: request.totalDaysLabel,
          ),
          const Divider(height: 24),
          _DetailRow(
            icon: Icons.access_time_rounded,
            label: 'Day Type',
            value: request.dayTypeLabel,
          ),
          const Divider(height: 24),
          _DetailRow(
            icon: Icons.payments_outlined,
            label: 'Payment Type',
            value:
                request.leaveType.paymentLabel,
          ),
          const Divider(height: 24),
          _DetailRow(
            icon: Icons.tag_rounded,
            label: 'Request ID',
            value:
                '#${request.leaveRequestId}',
          ),
        ],
      ),
    );
  }

  Widget _buildReasonSection(
    BuildContext context,
    LeaveRequestRecord request,
  ) {
    return _SectionCard(
      title: 'Reason',
      child: Text(
        request.reason.trim().isEmpty
            ? 'No reason provided.'
            : request.reason,
        style: Theme.of(context)
            .textTheme
            .bodyLarge
            ?.copyWith(
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }

  Widget _buildMessageSection({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String message,
  }) {
    return _SectionCard(
      title: title,
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            icon,
            size: 21,
            color: Theme.of(context)
                .colorScheme
                .primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(
                    height: 1.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentSection(
    BuildContext context,
    String attachmentUrl,
  ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return _SectionCard(
      title: 'Attachment',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme
              .surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.attach_file_rounded,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: SelectableText(
                attachmentUrl,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                      color: colorScheme.primary,
                      fontWeight:
                          FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineSection(
    BuildContext context,
    LeaveRequestRecord request,
  ) {
    return _SectionCard(
      title: 'Request Timeline',
      child: Column(
        children: <Widget>[
          _TimelineItem(
            icon: Icons.send_outlined,
            title: 'Request submitted',
            dateLabel: _formatDateTime(
              request.createdAt,
            ),
            isCompleted: true,
          ),
          if (request.status == 'approved')
            _TimelineItem(
              icon:
                  Icons.check_circle_outline_rounded,
              title: 'Request approved',
              dateLabel: _formatDateTime(
                request.reviewedAt,
              ),
              isCompleted: true,
            ),
          if (request.status == 'rejected')
            _TimelineItem(
              icon: Icons.cancel_outlined,
              title: 'Request rejected',
              dateLabel: _formatDateTime(
                request.reviewedAt,
              ),
              isCompleted: true,
            ),
          if (request.status == 'cancelled')
            _TimelineItem(
              icon:
                  Icons.remove_circle_outline_rounded,
              title: 'Request cancelled',
              dateLabel: _formatDateTime(
                request.cancelledAt,
              ),
              isCompleted: true,
            ),
          if (request.status == 'pending')
            const _TimelineItem(
              icon:
                  Icons.hourglass_top_rounded,
              title: 'Awaiting approval',
              dateLabel: 'Pending',
              isCompleted: false,
              isLast: true,
            ),
        ],
      ),
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
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.error_outline_rounded,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              widget.controller.errorMessage!,
              style: TextStyle(
                color:
                    colorScheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelButton(
    BuildContext context,
    LeaveRequestRecord request,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed:
            widget.controller.isCancelling
                ? null
                : () => _showCancelDialog(
                      request,
                    ),
        icon: widget.controller.isCancelling
            ? const SizedBox(
                width: 19,
                height: 19,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
            : const Icon(
                Icons.close_rounded,
              ),
        label: Text(
          widget.controller.isCancelling
              ? 'Cancelling...'
              : 'Cancel Leave Request',
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor:
              Theme.of(context).colorScheme.error,
          side: BorderSide(
            color:
                Theme.of(context).colorScheme.error,
          ),
        ),
      ),
    );
  }

  Future<void> _showCancelDialog(
    LeaveRequestRecord request,
  ) async {
    final reasonController =
        TextEditingController();

    final formKey =
        GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Cancel Leave Request',
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: reasonController,
              autofocus: true,
              minLines: 3,
              maxLines: 5,
              maxLength: 300,
              textCapitalization:
                  TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText:
                    'Cancellation reason',
                hintText:
                    'Enter why you want to cancel',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final reason =
                    value?.trim() ?? '';

                if (reason.isEmpty) {
                  return 'Enter a cancellation reason.';
                }

                if (reason.length < 3) {
                  return 'Reason must contain at least 3 characters.';
                }

                return null;
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop(false);
              },
              child: const Text(
                'Keep Request',
              ),
            ),
            FilledButton(
              onPressed: () {
                final isValid =
                    formKey.currentState
                            ?.validate() ??
                        false;

                if (!isValid) {
                  return;
                }

                Navigator.of(dialogContext)
                    .pop(true);
              },
              child: const Text(
                'Confirm Cancellation',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      reasonController.dispose();
      return;
    }

    final cancellationReason =
        reasonController.text.trim();

    reasonController.dispose();

    final result =
        await widget.controller.cancelLeave(
      leaveRequestId:
          request.leaveRequestId,
      cancellationReason:
          cancellationReason,
    );

    if (!mounted || result == null) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          widget.controller.successMessage ??
              'Leave request cancelled successfully.',
        ),
      ),
    );

    Navigator.of(context).pop(true);
  }

  Color _getAccentColor(
    String code,
  ) {
    switch (code.toUpperCase()) {
      case 'CL':
        return const Color(0xFF5C6BC0);

      case 'SL':
        return const Color(0xFFE53935);

      case 'EL':
        return const Color(0xFF00897B);

      case 'UL':
        return const Color(0xFF6D4C41);

      default:
        return const Color(0xFF1565C0);
    }
  }

  IconData _getLeaveIcon(
    String code,
  ) {
    switch (code.toUpperCase()) {
      case 'CL':
        return Icons.person_outline_rounded;

      case 'SL':
        return Icons.medical_services_outlined;

      case 'EL':
        return Icons.beach_access_outlined;

      case 'UL':
        return Icons.money_off_csred_outlined;

      default:
        return Icons.event_available_outlined;
    }
  }

  String _formatDateTime(
    DateTime? value,
  ) {
    if (value == null) {
      return '--';
    }

    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final localDate = value.toLocal();

    final hour = localDate.hour % 12 == 0
        ? 12
        : localDate.hour % 12;

    final minute = localDate.minute
        .toString()
        .padLeft(2, '0');

    final period =
        localDate.hour >= 12
            ? 'PM'
            : 'AM';

    return '${localDate.day} '
        '${months[localDate.month - 1]} '
        '${localDate.year}, '
        '$hour:$minute $period';
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Row(
      children: <Widget>[
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer
                .withValues(
              alpha: 0.55,
            ),
            borderRadius:
                BorderRadius.circular(11),
          ),
          child: Icon(
            icon,
            size: 20,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(
                      color: colorScheme
                          .onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(
                      color:
                          colorScheme.onSurface,
                      fontWeight:
                          FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.icon,
    required this.title,
    required this.dateLabel,
    required this.isCompleted,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final String dateLabel;
  final bool isCompleted;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    final itemColor = isCompleted
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: <Widget>[
        Column(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: itemColor.withValues(
                  alpha: 0.12,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 19,
                color: itemColor,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 34,
                color: colorScheme
                    .outlineVariant,
              ),
          ],
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(
              top: 3,
              bottom: 18,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(
                        fontWeight:
                            FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  dateLabel,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: colorScheme
                            .onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}