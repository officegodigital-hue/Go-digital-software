import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/hrms_tracking_api.dart';
import 'mobile_waiting_notification.dart';

/// Android's visible foreground service. It owns scheduled GPS updates while
/// the app is backgrounded, and is stopped explicitly with the session.
class AndroidLiveTrackingService {
  static final FlutterBackgroundService _service = FlutterBackgroundService();
  static bool _configured = false;

  static Future<void> configure() async {
    if (kIsWeb || _configured) return;
    _configured = true;
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        initialNotificationTitle: 'Live tracking active',
        initialNotificationContent: 'Location updates are being saved',
        foregroundServiceNotificationId: 71402,
      ),
      iosConfiguration: IosConfiguration(onForeground: _onStart),
    );
  }

  static Future<void> start({required String employeeName, required int pingMinutes}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await configure();
    final running = await _service.isRunning();
    if (!running) await _service.startService();
    _service.invoke('start-live-tracking', {'employeeName': employeeName, 'pingMinutes': pingMinutes});
  }

  static Future<void> stop() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    _service.invoke('stop-live-tracking');
  }

  @pragma('vm:entry-point')
  static void _onStart(ServiceInstance service) {
    DartPluginRegistrant.ensureInitialized();
    MobileWaitingNotification.initialize();
    Timer? pingTimer;
    Future<void> ping() async {
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        await HrmsTrackingApi.ping(latitude: position.latitude, longitude: position.longitude, accuracy: position.accuracy);
        final alert = await HrmsTrackingApi.waitingAlert();
        if (alert != null) {
          await MobileWaitingNotification.showWaitingAlert(alert);
        }
      } catch (_) {
        // The next foreground-service interval retries automatically.
      }
    }
    service.on('start-live-tracking').listen((event) async {
      final minutes = (event?['pingMinutes'] as num?)?.toInt().clamp(1, 1440) ?? 15;
      final name = '${event?['employeeName'] ?? 'Employee'}'.trim();
      if (service is AndroidServiceInstance) {
        await service.setAsForegroundService();
        await service.setForegroundNotificationInfo(
          title: '$name — Live tracking active',
          content: 'Location updates are being saved',
        );
      }
      // Send a fresh point immediately after the foreground service starts;
      // otherwise the first background update would wait for the interval.
      await ping();
      pingTimer?.cancel();
      pingTimer = Timer.periodic(Duration(minutes: minutes), (_) => ping());
    });
    service.on('stop-live-tracking').listen((_) {
      pingTimer?.cancel();
      service.stopSelf();
    });
  }
}
