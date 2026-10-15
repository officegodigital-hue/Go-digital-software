// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

import 'hrms_tracking_api.dart';

/// Global waiting-alert service.
///
/// Start it once from a long-lived widget (e.g. EmployeeDashboardPage) that
/// stays alive for the employee's whole session. It polls every minute for a
/// pending waiting-reason alert and shows a non-dismissible dialog with
/// looping sound + repeating vibration. Both stop the moment the employee
/// submits their reason.
class WaitingAlertService {
  WaitingAlertService({required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;

  Timer? _timer;
  bool _dialogOpen = false;

  void start() {
    _timer?.cancel();
    // Check immediately on start, then every minute
    _check();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _check());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _check() async {
    if (_dialogOpen) return;
    try {
      final alert = await HrmsTrackingApi.waitingAlert();
      if (alert == null) return;
      final reasonId = int.tryParse('${alert['id']}');
      if (reasonId == null) return;
      final ctx = navigatorKey.currentContext;
      if (ctx == null) return;
      _dialogOpen = true;
      await _showDialog(ctx, reasonId: reasonId, waitingMinutes: alert['waiting_minutes'] ?? 0);
    } catch (_) {
      // Silent — never crash the background poll
    } finally {
      _dialogOpen = false;
    }
  }

  Future<void> _showDialog(
    BuildContext context, {
    required int reasonId,
    required dynamic waitingMinutes,
  }) async {
    final controller = TextEditingController();
    final player = AudioPlayer();
    String? submitError;

    // Start looping sound
    try {
      await player.setReleaseMode(ReleaseMode.loop);
      await player.play(AssetSource('sounds/notification.mp3'));
    } catch (_) {}

    // Start repeating vibration (500 ms on, 1000 ms off, repeat)
    try {
      final hasVibrator = (await Vibration.hasVibrator()) == true;
      if (hasVibrator) {
        Vibration.vibrate(pattern: [0, 500, 1000], repeat: 0);
      }
    } catch (_) {}

    Future<void> stopAlert() async {
      try { await player.stop(); } catch (_) {}
      try { await player.dispose(); } catch (_) {}
      try { Vibration.cancel(); } catch (_) {}
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('You\'ve been waiting — please explain'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You have been stationary at this location for $waitingMinutes minute(s).\n'
                    'Please enter the reason for waiting.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Reason for waiting',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (submitError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      submitError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                ],
              ),
              actions: [
                FilledButton(
                  onPressed: () async {
                    final reason = controller.text.trim();
                    if (reason.isEmpty) return;
                    try {
                      await HrmsTrackingApi.submitWaitingReason(
                        reasonId: reasonId,
                        reason: reason,
                      );
                      await stopAlert();
                      if (Navigator.of(dialogContext, rootNavigator: true).canPop()) {
                        Navigator.of(dialogContext, rootNavigator: true).pop();
                      }
                    } catch (e) {
                      setDialogState(() => submitError = e.toString().replaceFirst('Exception: ', ''));
                    }
                  },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );

    // Safety net: ensure sound/vibration stop if dialog closes for any reason
    await stopAlert();
    controller.dispose();
  }
}
