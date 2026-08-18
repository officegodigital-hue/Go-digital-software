import 'package:employee_mobile/features/leave/data/models/leave_history_response.dart';
import 'package:employee_mobile/features/leave/presentation/controllers/leave_controller.dart';
import 'package:employee_mobile/features/leave/presentation/screens/leave_request_details_screen.dart';
import 'package:employee_mobile/features/leave/presentation/widgets/leave_request_card.dart';
import 'package:flutter/material.dart';


class LeaveHistoryScreen extends StatefulWidget {
  const LeaveHistoryScreen({
    required this.controller,
    super.key,
  });

  final LeaveController controller;

  @override
  State<LeaveHistoryScreen> createState() {
    return _LeaveHistoryScreenState();
  }
}

class _LeaveHistoryScreenState
    extends State<LeaveHistoryScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        widget.controller.clearMessages();

        if (widget.controller.historyData == null) {
          widget.controller.loadHistory();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Leave History',
            ),
            actions: <Widget>[
              IconButton(
                tooltip: 'Refresh',
                onPressed:
                    widget.controller.isHistoryLoading
                        ? null
                        : widget.controller.loadHistory,
                icon: const Icon(
                  Icons.refresh_rounded,
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: <Widget>[
                _buildFilters(context),
                Expanded(
                  child: _buildBody(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilters(
    BuildContext context,
  ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    final currentYear = DateTime.now().year;

    final availableYears = <int>[
      currentYear - 1,
      currentYear,
      currentYear + 1,
    ];

    if (!availableYears.contains(
      widget.controller.selectedYear,
    )) {
      availableYears.add(
        widget.controller.selectedYear,
      );

      availableYears.sort();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        16,
        14,
        16,
        14,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue:
                  widget.controller.selectedYear,
              decoration: const InputDecoration(
                labelText: 'Year',
                prefixIcon: Icon(
                  Icons.calendar_today_outlined,
                ),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: availableYears.map(
                (year) {
                  return DropdownMenuItem<int>(
                    value: year,
                    child: Text(
                      year.toString(),
                    ),
                  );
                },
              ).toList(),
              onChanged:
                  widget.controller.isHistoryLoading
                      ? null
                      : (year) {
                          if (year == null) {
                            return;
                          }

                          widget.controller.changeYear(
                            year,
                          );
                        },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                DropdownButtonFormField<String>(
              initialValue:
                  widget.controller.selectedStatus ??
                      'all',
              decoration: const InputDecoration(
                labelText: 'Status',
                prefixIcon: Icon(
                  Icons.filter_alt_outlined,
                ),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const <
                  DropdownMenuItem<String>>[
                DropdownMenuItem<String>(
                  value: 'all',
                  child: Text('All'),
                ),
                DropdownMenuItem<String>(
                  value: 'pending',
                  child: Text('Pending'),
                ),
                DropdownMenuItem<String>(
                  value: 'approved',
                  child: Text('Approved'),
                ),
                DropdownMenuItem<String>(
                  value: 'rejected',
                  child: Text('Rejected'),
                ),
                DropdownMenuItem<String>(
                  value: 'cancelled',
                  child: Text('Cancelled'),
                ),
              ],
              onChanged:
                  widget.controller.isHistoryLoading
                      ? null
                      : (status) {
                          widget.controller.changeStatus(
                            status == 'all'
                                ? null
                                : status,
                          );
                        },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
  ) {
    final controller = widget.controller;

    if (controller.isHistoryLoading &&
        controller.historyData == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (controller.errorMessage != null &&
        controller.requests.isEmpty) {
      return _HistoryMessageState(
        icon: Icons.error_outline_rounded,
        title: 'Unable to load history',
        message: controller.errorMessage!,
        buttonLabel: 'Try Again',
        onPressed: controller.loadHistory,
      );
    }

    if (controller.requests.isEmpty) {
      return _HistoryMessageState(
        icon: Icons.event_busy_rounded,
        title: 'No leave requests',
        message:
            'No ${controller.selectedStatusLabel.toLowerCase()} '
            'leave requests were found for '
            '${controller.selectedYear}.',
        buttonLabel:
            controller.selectedStatus == null
                ? null
                : 'Show All',
        onPressed:
            controller.selectedStatus == null
                ? null
                : () {
                    controller.changeStatus(null);
                  },
      );
    }

    return Stack(
      children: <Widget>[
        RefreshIndicator(
          onRefresh:
              widget.controller.loadHistory,
          child: ListView.separated(
            physics:
                const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              32,
            ),
            itemCount:
                controller.requests.length,
            separatorBuilder:
                (context, index) {
              return const SizedBox(
                height: 14,
              );
            },
            itemBuilder:
                (context, index) {
              final request =
                  controller.requests[index];

              return LeaveRequestCard(
                request: request,
                onTap: () {
                  _openRequestDetails(
                    request,
                  );
                },
                onCancel: request.canCancel
                    ? () {
                        _showCancelDialog(
                          request,
                        );
                      }
                    : null,
              );
            },
          ),
        ),
        if (controller.isHistoryLoading)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              minHeight: 3,
              color: Theme.of(context)
                  .colorScheme
                  .primary,
            ),
          ),
      ],
    );
  }

  Future<void> _openRequestDetails(
    LeaveRequestRecord request,
  ) async {
    final wasUpdated =
        await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) {
          return LeaveRequestDetailsScreen(
            controller: widget.controller,
            request: request,
          );
        },
      ),
    );

    if (!mounted) {
      return;
    }

    if (wasUpdated == true) {
      await widget.controller.loadHistory();
    }
  }

  Future<void> _showCancelDialog(
    LeaveRequestRecord request,
  ) async {
    widget.controller.clearMessages();

    final reasonController =
        TextEditingController();

    final formKey =
        GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Cancel Leave Request',
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Cancel ${request.leaveType.name} '
                  'for ${request.dateRangeLabel}?',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller:
                      reasonController,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 300,
                  textCapitalization:
                      TextCapitalization.sentences,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Cancellation reason',
                    hintText:
                        'Enter why you want to cancel',
                    alignLabelWithHint: true,
                    border:
                        OutlineInputBorder(),
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
              ],
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

    if (confirmed != true) {
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

    if (!mounted) {
      return;
    }

    if (result == null) {
      final message =
          widget.controller.errorMessage ??
              'Unable to cancel leave request.';

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor:
                Theme.of(context)
                    .colorScheme
                    .error,
          ),
        );

      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            widget.controller.successMessage ??
                'Leave request cancelled successfully.',
          ),
        ),
      );
  }
}

class _HistoryMessageState
    extends StatelessWidget {
  const _HistoryMessageState({
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
    final colorScheme =
        Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: colorScheme
                    .primaryContainer
                    .withValues(
                  alpha: 0.55,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 38,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
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
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    color: colorScheme
                        .onSurfaceVariant,
                    height: 1.45,
                  ),
            ),
            if (buttonLabel != null &&
                onPressed != null) ...<Widget>[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onPressed,
                icon: const Icon(
                  Icons.refresh_rounded,
                ),
                label: Text(
                  buttonLabel!,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}