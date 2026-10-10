import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/hrms_tracking_api.dart';

/// Keeps the mandatory field-waiting comment prompt active while an employee
/// moves between pages. A prompt is only shown for a currently active field
/// session; office/home sessions and old alerts are ignored.
class FieldWaitingPromptHost extends StatefulWidget {
  const FieldWaitingPromptHost({
    super.key,
    required this.child,
    required this.navigatorKey,
  });
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<FieldWaitingPromptHost> createState() => _FieldWaitingPromptHostState();
}

class _FieldWaitingPromptHostState extends State<FieldWaitingPromptHost> {
  Timer? _timer;
  Timer? _soundTimer;
  final AudioPlayer _soundPlayer = AudioPlayer();
  bool _checking = false;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopPromptSound();
    _soundPlayer.dispose();
    super.dispose();
  }

  void _startPromptSound() {
    _stopPromptSound();
    Future<void> play() async {
      try {
        await _soundPlayer.play(
          AssetSource('sounds/notification.mp3'),
          volume: 0.8,
        );
      } catch (_) {
        // The mandatory prompt remains usable if a device cannot play audio.
      }
    }

    play();
    _soundTimer = Timer.periodic(const Duration(seconds: 5), (_) => play());
  }

  void _stopPromptSound() {
    _soundTimer?.cancel();
    _soundTimer = null;
    _soundPlayer.stop();
  }

  Future<void> _check() async {
    if (_checking || _dialogOpen || !mounted) return;
    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated || auth.userType?.toLowerCase() != 'employee') {
      return;
    }

    _checking = true;
    try {
      final session = await HrmsTrackingApi.fieldSession();
      final active = session['is_active'] == 1 ||
          session['is_active'] == true ||
          session['isActive'] == true;
      if (!active || !mounted) return;

      final alert = await HrmsTrackingApi.waitingAlert();
      if (alert == null || !mounted || _dialogOpen) return;
      final reasonId = int.tryParse('${alert['id']}');
      if (reasonId == null) return;

      _dialogOpen = true;
      try {
        await _showDialog(
          reasonId: reasonId,
          waitingMinutes: alert['waiting_minutes'] ?? 0,
        );
      } finally {
        _dialogOpen = false;
      }
    } catch (_) {
      // A tracking/network failure must not interrupt the employee's page.
    } finally {
      _checking = false;
    }
  }

  Future<void> _showDialog({
    required int reasonId,
    required dynamic waitingMinutes,
  }) async {
    final rootContext = widget.navigatorKey.currentContext;
    if (rootContext == null) return;
    final controller = TextEditingController();
    var submitting = false;
    String? errorMessage;
    _startPromptSound();
    try {
      await showDialog<void>(
        context: rootContext,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Field waiting reason'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'You have been at this location for $waitingMinutes minutes. '
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
                if (errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(errorMessage!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: submitting
                    ? null
                    : () async {
                        final reason = controller.text.trim();
                        if (reason.isEmpty) {
                          setDialogState(
                            () => errorMessage = 'Please enter a reason.',
                          );
                          return;
                        }
                        setDialogState(() {
                          submitting = true;
                          errorMessage = null;
                        });
                        try {
                          await HrmsTrackingApi.submitWaitingReason(
                            reasonId: reasonId,
                            reason: reason,
                          );
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext, rootNavigator: true).pop();
                          }
                        } catch (_) {
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              submitting = false;
                              errorMessage = 'Could not submit the reason. Please try again.';
                            });
                          }
                        }
                      },
                child: Text(submitting ? 'Submitting…' : 'Submit'),
              ),
            ],
          ),
        ),
      );
    } finally {
      _stopPromptSound();
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
