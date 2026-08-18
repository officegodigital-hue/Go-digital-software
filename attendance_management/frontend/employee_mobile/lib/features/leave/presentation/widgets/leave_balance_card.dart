import 'package:employee_mobile/features/leave/data/models/leave_dashboard_response.dart';
import 'package:flutter/material.dart';

class LeaveBalanceCard extends StatelessWidget {
  const LeaveBalanceCard({
    required this.balance,
    this.onApply,
    super.key,
  });

  final LeaveBalance balance;
  final VoidCallback? onApply;

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    final accentColor =
        _getAccentColor(balance.code);

    return Container(
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
                  _getIcon(balance.code),
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
                      balance.name,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
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
                    const SizedBox(height: 4),
                    Text(
                      '${balance.code} • '
                      '${balance.paymentLabel}',
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
              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    _formatDays(
                      balance.availableDays,
                    ),
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                          color: accentColor,
                          fontWeight:
                              FontWeight.w900,
                          height: 1,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Available',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(
                          color: colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Leave usage',
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
              ),
              Text(
                '${_formatDays(balance.consumedDays)} / '
                '${_formatDays(balance.totalAllocated)} days',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(
                      color:
                          colorScheme.onSurface,
                      fontWeight:
                          FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius:
                BorderRadius.circular(30),
            child: LinearProgressIndicator(
              value: balance.usageProgress,
              minHeight: 8,
              backgroundColor:
                  accentColor.withValues(
                alpha: 0.12,
              ),
              valueColor:
                  AlwaysStoppedAnimation<Color>(
                accentColor,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: _BalanceDetail(
                  label: 'Allocated',
                  value: _formatDays(
                    balance.totalAllocated,
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 34,
                color:
                    colorScheme.outlineVariant,
              ),
              Expanded(
                child: _BalanceDetail(
                  label: 'Used',
                  value: _formatDays(
                    balance.usedDays,
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 34,
                color:
                    colorScheme.outlineVariant,
              ),
              Expanded(
                child: _BalanceDetail(
                  label: 'Pending',
                  value: _formatDays(
                    balance.pendingDays,
                  ),
                ),
              ),
            ],
          ),
          if (balance.requiresAttachment) ...<Widget>[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: colorScheme
                    .surfaceContainerHighest,
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.attach_file_rounded,
                    size: 18,
                    color: colorScheme
                        .onSurfaceVariant,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Attachment required',
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
            ),
          ],
          if (balance.maxConsecutiveDays !=
              null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              'Maximum ${balance.maxConsecutiveDays} '
              'consecutive days',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                    color: colorScheme
                        .onSurfaceVariant,
                  ),
            ),
          ],
          if (onApply != null) ...<Widget>[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onApply,
                icon: const Icon(
                  Icons.add_rounded,
                  size: 20,
                ),
                label: const Text(
                  'Apply Leave',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDays(
    double value,
  ) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(1);
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

  IconData _getIcon(
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

class _BalanceDetail extends StatelessWidget {
  const _BalanceDetail({
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
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(
                color: colorScheme
                    .onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}