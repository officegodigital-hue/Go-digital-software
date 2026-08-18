import 'package:employee_mobile/features/leave/data/models/leave_history_response.dart';
import 'package:employee_mobile/features/leave/presentation/widgets/leave_status_chip.dart';
import 'package:flutter/material.dart';

class LeaveRequestCard extends StatelessWidget {
  const LeaveRequestCard({
    required this.request,
    this.onTap,
    this.onCancel,
    super.key,
  });

  final LeaveRequestRecord request;
  final VoidCallback? onTap;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    final accentColor =
        _getAccentColor(request.leaveType.code);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colorScheme.outlineVariant,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: 0.04,
                ),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(
                        alpha: 0.12,
                      ),
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _getLeaveIcon(
                        request.leaveType.code,
                      ),
                      color: accentColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          request.leaveType.name,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color: colorScheme
                                    .onSurface,
                                fontWeight:
                                    FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${request.leaveType.code} • '
                          '${request.leaveType.paymentLabel}',
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
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
              const SizedBox(height: 16),
              _InformationRow(
                icon: Icons.calendar_month_outlined,
                label: 'Date',
                value: request.dateRangeLabel,
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _InformationRow(
                      icon: Icons.schedule_rounded,
                      label: 'Duration',
                      value:
                          request.totalDaysLabel,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InformationRow(
                      icon: Icons.access_time_rounded,
                      label: 'Type',
                      value:
                          request.dayTypeLabel,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme
                      .surfaceContainerHighest
                      .withValues(
                    alpha: 0.55,
                  ),
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Reason',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                            color: colorScheme
                                .onSurfaceVariant,
                            fontWeight:
                                FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      request.reason.isEmpty
                          ? 'No reason provided'
                          : request.reason,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                            color:
                                colorScheme.onSurface,
                            fontWeight:
                                FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
              if (request.reviewComment != null &&
                  request.reviewComment!
                      .trim()
                      .isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                _MessageBox(
                  icon: Icons.comment_outlined,
                  title: 'Review comment',
                  message:
                      request.reviewComment!,
                ),
              ],
              if (request.cancellationReason != null &&
                  request.cancellationReason!
                      .trim()
                      .isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                _MessageBox(
                  icon:
                      Icons.cancel_outlined,
                  title:
                      'Cancellation reason',
                  message: request
                      .cancellationReason!,
                ),
              ],
              if (request.attachmentUrl != null &&
                  request.attachmentUrl!
                      .trim()
                      .isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.attach_file_rounded,
                      size: 18,
                      color: colorScheme
                          .onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Attachment available',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: colorScheme
                                  .onSurfaceVariant,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
              if (request.canCancel &&
                  onCancel != null) ...<Widget>[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Request is awaiting approval',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                      ),
                      label: const Text(
                        'Cancel',
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor:
                            colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ] else if (onTap != null) ...<Widget>[
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'View details',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(
                              color:
                                  colorScheme.primary,
                              fontWeight:
                                  FontWeight.w700,
                            ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
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
}

class _InformationRow extends StatelessWidget {
  const _InformationRow({
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
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: colorScheme
                .primaryContainer
                .withValues(
              alpha: 0.55,
            ),
            borderRadius:
                BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 9),
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
                maxLines: 2,
                overflow:
                    TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
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

class _MessageBox extends StatelessWidget {
  const _MessageBox({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            icon,
            size: 19,
            color: colorScheme
                .onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(
                        color: colorScheme
                            .onSurfaceVariant,
                        fontWeight:
                            FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                        color:
                            colorScheme.onSurface,
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