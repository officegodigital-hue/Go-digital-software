import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import 'attendance_location.dart';
import 'auth_service.dart';
import 'hrms_tracking_api.dart';

/// Lives above the app's routes, so route replacement cannot stop Hybrid alerts.
class WaitingAlertHost extends StatefulWidget {
  const WaitingAlertHost({
    super.key,
    required this.navigatorKey,
    required this.child,
  });
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  @override
  State<WaitingAlertHost> createState() => _WaitingAlertHostState();
}

class _WaitingAlertHostState extends State<WaitingAlertHost>
    with WidgetsBindingObserver {
  late final WaitingAlertService service;
  String? employee;
  @override
  void initState() {
    super.initState();
    service = WaitingAlertService(navigatorKey: widget.navigatorKey);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthService>();
    final next =
        auth.isAuthenticated && auth.userType?.toLowerCase() == 'employee'
        ? auth.userId
        : null;
    if (next == employee) return;
    service.stop();
    employee = next;
    if (next != null) service.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && employee != null)
      service.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    service.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Provider<WaitingAlertService>.value(value: service, child: widget.child);
}

class WaitingAlertService {
  WaitingAlertService({
    required this.navigatorKey,
    Future<Position> Function()? currentPosition,
    DateTime Function()? now,
    this.startSignal,
    this.stopSignal,
  }) : _position = currentPosition ?? AttendanceLocation.currentPosition,
       _now = now ?? DateTime.now;
  final GlobalKey<NavigatorState> navigatorKey;
  final Future<Position> Function() _position;
  final DateTime Function() _now;
  final Future<void> Function()? startSignal;
  final Future<void> Function()? stopSignal;
  Timer? _timer;
  StreamSubscription<Position>? _gps;
  int? _sessionId;
  int? _streamMinutes;
  int? _pollMinutes;
  DateTime? _lastPing;
  bool _running = false, _checking = false, _sending = false;
  int _generation = 0;
  DialogRoute<void>? _dialog;
  AudioPlayer? _player;

  void start() {
    if (_running) return;
    _running = true;
    _generation++;
    refresh();
  }

  void stop() {
    _running = false;
    _generation++;
    _timer?.cancel();
    _timer = null;
    _pollMinutes = null;
    _stopGps();
    final route = _dialog;
    _dialog = null;
    if (route != null) {
      void remove() {
        route.navigator?.removeRoute(route);
      }

      if (SchedulerBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks) {
        WidgetsBinding.instance.addPostFrameCallback((_) => remove());
      } else {
        remove();
      }
    }
    unawaited(_stopSignal());
  }

  void _stopGps() {
    _gps?.cancel();
    _gps = null;
    _sessionId = null;
    _streamMinutes = null;
    _lastPing = null;
  }

  bool _valid(int generation) => _running && generation == _generation;

  Future<void> refresh() async {
    if (!_running || _checking) return;
    _checking = true;
    final generation = _generation;
    try {
      final session = await HrmsTrackingApi.hybridSession();
      if (!_valid(generation)) return;
      if (session['isHybrid'] != true) {
        _stopGps();
        return;
      }
      final settings = await HrmsTrackingApi.trackingSettings();
      if (!_valid(generation)) return;
      final minutes = int.tryParse(
        '${settings['field_ping_interval_minutes']}',
      );
      if (minutes == null || minutes < 1) {
        throw StateError(
          'Admin must configure a valid Hybrid GPS update interval.',
        );
      }
      _pollMinutes = minutes;
      final active =
          session['isActive'] == true ||
          session['is_active'] == 1 ||
          session['is_active'] == true;
      if (active) {
        final id = int.tryParse('${session['id'] ?? session['sessionId']}');
        if (id != _sessionId) {
          _stopGps();
          _sessionId = id;
        }
        {
          try {
            if (!kIsWeb &&
                defaultTargetPlatform == TargetPlatform.android &&
                _streamMinutes != minutes) {
              _streamMinutes = minutes;
              await _gps?.cancel();
              _gps = null;
              var permission = await Geolocator.checkPermission();
              if (permission != LocationPermission.always)
                permission = await Geolocator.requestPermission();
              if (!_valid(generation)) return;
              if (permission == LocationPermission.always) {
                _gps =
                    Geolocator.getPositionStream(
                      locationSettings: AndroidSettings(
                        accuracy: LocationAccuracy.high,
                        distanceFilter: 0,
                        intervalDuration: Duration(minutes: minutes),
                        foregroundNotificationConfig:
                            const ForegroundNotificationConfig(
                              notificationTitle:
                                  'Go Digital HRMS tracking is active',
                              notificationText:
                                  'Your Hybrid work location is being updated.',
                              enableWakeLock: true,
                              setOngoing: true,
                            ),
                      ),
                    ).listen(
                      (position) {
                        unawaited(_sendPosition(position, generation));
                      },
                      onError: (Object error) {
                        debugPrint('Hybrid GPS stream failed: $error');
                      },
                    );
              }
            }
            if (_lastPing == null ||
                _now().difference(_lastPing!) >= Duration(minutes: minutes)) {
              await _sendPosition(await _position(), generation);
            }
          } catch (error) {
            debugPrint('Hybrid location update failed: $error');
          }
        }
      } else {
        _stopGps();
      }
      if (!_valid(generation) || _dialog != null) return;
      final alert = await HrmsTrackingApi.waitingAlert();
      if (!_valid(generation) || _dialog != null || alert == null) return;
      final id = int.tryParse('${alert['id']}');
      final nav = navigatorKey.currentState;
      if (id == null || nav == null) return;
      unawaited(
        _showDialog(nav, id, alert['waiting_minutes'] ?? 0, generation),
      );
    } catch (error) {
      debugPrint('Hybrid waiting check failed: $error');
    } finally {
      _checking = false;
      if (_valid(generation) && _pollMinutes != null) {
        _timer?.cancel();
        _timer = Timer(Duration(minutes: _pollMinutes!), () => refresh());
      }
    }
  }

  Future<void> _sendPosition(Position position, int generation) async {
    if (!_valid(generation) ||
        _sessionId == null ||
        _sending ||
        !position.accuracy.isFinite ||
        position.accuracy > 200)
      return;
    _sending = true;
    try {
      await HrmsTrackingApi.ping(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        capturedAt: position.timestamp.toUtc().toIso8601String(),
      );
      if (_valid(generation)) _lastPing = _now();
    } catch (error) {
      debugPrint('Hybrid GPS ping failed: $error');
    } finally {
      _sending = false;
    }
  }

  Future<void> _startSignal() async {
    if (startSignal != null) {
      await startSignal!();
      return;
    }
    final player = AudioPlayer();
    _player = player;
    try {
      await player.setReleaseMode(ReleaseMode.loop);
      if (_player != player) return;
      await player.play(AssetSource('sounds/notification.mp3'));
    } catch (_) {}
    if (_player != player) return;
    try {
      if (await Vibration.hasVibrator() == true && _player == player)
        await Vibration.vibrate(pattern: [0, 500, 1000], repeat: 0);
    } catch (_) {}
  }

  Future<void> _stopSignal() async {
    if (stopSignal != null) {
      await stopSignal!();
      return;
    }
    final player = _player;
    _player = null;
    try {
      await player?.stop();
    } catch (_) {}
    try {
      await player?.dispose();
    } catch (_) {}
    try {
      await Vibration.cancel();
    } catch (_) {}
  }

  Future<void> _showDialog(
    NavigatorState nav,
    int id,
    dynamic minutes,
    int generation,
  ) async {
    final reason = TextEditingController();
    String? error;
    bool submitting = false;
    final route = DialogRoute<void>(
      context: nav.context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: const Text("You've been waiting — please explain"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You have been stationary at this location for $minutes minute(s).\nPlease enter the reason for waiting.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reason,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Reason for waiting',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: submitting
                    ? null
                    : () async {
                        if (reason.text.trim().isEmpty) {
                          update(() => error = 'Enter a reason for waiting.');
                          return;
                        }
                        update(() {
                          submitting = true;
                          error = null;
                        });
                        try {
                          await HrmsTrackingApi.submitWaitingReason(
                            reasonId: id,
                            reason: reason.text.trim(),
                          );
                          if (!_valid(generation)) return;
                          await _stopSignal();
                          if (context.mounted) Navigator.of(context).pop();
                        } catch (e) {
                          if (context.mounted)
                            update(() {
                              error = '$e';
                              submitting = false;
                            });
                        }
                      },
                child: const Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
    _dialog = route;
    unawaited(_startSignal());
    try {
      await nav.push(route);
    } finally {
      if (_dialog == route) {
        _dialog = null;
        await _stopSignal();
      }
      // The dialog may still be in its dismissal transition.
      await route.completed;
      reason.dispose();
    }
  }
}
