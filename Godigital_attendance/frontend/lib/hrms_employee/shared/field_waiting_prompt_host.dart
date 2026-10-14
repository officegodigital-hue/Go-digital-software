import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';

import '../../services/auth_service.dart';
import '../../services/hrms_tracking_api.dart';
import '../../services/hrms_notifications_api.dart';
import '../../services/api_config.dart';
import 'live_tracking_coordinator.dart';

/// Keeps the mandatory field-waiting comment prompt active while an employee
/// moves between pages. A prompt is only shown for a currently active field
/// session; office/home sessions and old alerts are ignored.
class FieldWaitingPromptHost extends StatefulWidget {
  const FieldWaitingPromptHost({
    super.key,
    required this.child,
    required this.navigatorKey,
    required this.routeRevision,
  });
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  final ValueListenable<int> routeRevision;

  @override
  State<FieldWaitingPromptHost> createState() => _FieldWaitingPromptHostState();
}

class _FieldWaitingPromptHostState extends State<FieldWaitingPromptHost> with WidgetsBindingObserver {
  Timer? _timer;
  Timer? _soundTimer;
  Timer? _feedbackSessionTimer;
  final AudioPlayer _soundPlayer = AudioPlayer();
  String? _customSoundUrl;
  bool _checking = false;
  bool _dialogOpen = false;
  AuthService? _auth;
  LiveTrackingCoordinator? _coordinator;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LiveTrackingCoordinator>().restore();
      _loadNotificationSound();
      _check();
      _coordinator = context.read<LiveTrackingCoordinator>()..addListener(_onCoordinatorChanged);
    });
    WidgetsBinding.instance.addObserver(this);
    widget.routeRevision.addListener(_onRouteChanged);
    _auth = context.read<AuthService>()..addListener(_onAuthChanged);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.routeRevision.removeListener(_onRouteChanged);
    _auth?.removeListener(_onAuthChanged);
    _coordinator?.removeListener(_onCoordinatorChanged);
    _timer?.cancel();
    _stopPromptFeedback();
    _soundPlayer.dispose();
    super.dispose();
  }

  void _onAuthChanged() {
    final auth = _auth;
    if (auth?.isAuthenticated == true && auth?.userType?.toLowerCase() == 'employee') {
      context.read<LiveTrackingCoordinator>().restore();
      _onRouteChanged();
    }
  }

  void _onRouteChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _onCoordinatorChanged() {
    final warning = _coordinator?.autoClockoutWarning;
    if (warning == null || _dialogOpen || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_dialogOpen) _showAutoClockoutDialog(warning);
    });
  }

  Future<void> _showAutoClockoutDialog(Map<String, dynamic> warning) async {
    final rootContext = widget.navigatorKey.currentContext;
    if (rootContext == null || _dialogOpen) return;
    _dialogOpen = true;
    SystemSound.play(SystemSoundType.alert);
    try {
      if (await Vibration.hasVibrator() == true) {
        await Vibration.vibrate(pattern: [0, 120, 80, 120]);
      }
    } catch (_) {}
    try {
      await showDialog<void>(
        context: rootContext,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('You appear to be outside your work location.'),
          content: Text(
            'If you are still working, confirm now. Auto clock-out will occur after ${warning['warningSeconds'] ?? 60} seconds if there is no response.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                try {
                  await _coordinator?.respondToAutoClockoutWarning();
                } finally {
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Still working'),
            ),
          ],
        ),
      );
    } finally {
      _dialogOpen = false;
      _coordinator?.dismissAutoClockoutWarning();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _onRouteChanged();
  }

  void _startPromptFeedback(Duration repeatInterval) {
    _stopPromptFeedback();
    Future<void> play() async {
      try {
        final source = _customSoundUrl == null
            ? AssetSource('sounds/notification.mp3')
            : UrlSource(ApiConfig.mediaUrl(_customSoundUrl!));
        await _soundPlayer.play(source, volume: 0.8);
      } catch (_) {
        // The mandatory prompt remains usable if a device cannot play audio.
      }
    }

    Future<void> vibrateContinuously() async {
      try {
        if (await Vibration.hasVibrator() == true) {
          // Repeat the vibration pattern natively until the dialog is
          // submitted/dismissed. _stopPromptFeedback() calls cancel().
          await Vibration.vibrate(pattern: [0, 450, 180, 450], repeat: 0);
        }
      } catch (_) {
        // Unsupported platforms and blocked browser/device vibration are safe.
      }
    }

    void notify() {
      play();
    }

    notify();
    vibrateContinuously();
    _soundTimer = Timer.periodic(repeatInterval, (_) => notify());
    _feedbackSessionTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _stopFeedbackForInactiveSession(),
    );
  }

  Future<void> _loadNotificationSound() async {
    try {
      final settings = await HrmsNotificationsApi.settings();
      final url = settings['customSoundUrl']?.toString();
      if (mounted) setState(() => _customSoundUrl = url?.isNotEmpty == true ? url : null);
    } catch (_) {
      // Keep the bundled sound when notification settings are unavailable.
    }
  }

  Future<void> _stopFeedbackForInactiveSession() async {
    try {
      final session = await HrmsTrackingApi.fieldSession();
      final active =
          session['is_active'] == 1 ||
          session['is_active'] == true ||
          session['isActive'] == true;
      if (!active) {
        _stopPromptFeedback();
      }
    } catch (_) {
      // A temporary network failure must not stop a mandatory local prompt.
    }
  }

  void _stopPromptFeedback() {
    _soundTimer?.cancel();
    _soundTimer = null;
    _feedbackSessionTimer?.cancel();
    _feedbackSessionTimer = null;
    _soundPlayer.stop();
    Vibration.cancel().catchError((_) {});
  }

  Future<Duration> _popupAlertRepeatInterval() async {
    try {
      final settings = await HrmsTrackingApi.trackingSettings();
      final seconds =
          int.tryParse('${settings['popup_alert_repeat_seconds'] ?? 5}') ?? 5;
      return Duration(seconds: seconds.clamp(1, 30).toInt());
    } catch (_) {
      return const Duration(seconds: 5);
    }
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
      final active =
          session['is_active'] == 1 ||
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
    final repeatInterval = await _popupAlertRepeatInterval();
    if (!mounted || !rootContext.mounted) {
      controller.dispose();
      return;
    }
    _startPromptFeedback(repeatInterval);
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
                  Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
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
                            Navigator.of(
                              dialogContext,
                              rootNavigator: true,
                            ).pop();
                          }
                        } catch (_) {
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              submitting = false;
                              errorMessage =
                                  'Could not submit the reason. Please try again.';
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
      _stopPromptFeedback();
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
