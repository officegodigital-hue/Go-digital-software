import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Native Android notification used when the tracking service detects a field
/// waiting alert while the Flutter UI is backgrounded.
class MobileWaitingNotification {
  MobileWaitingNotification._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static int? _lastAlertId;
  static String? _lastClockoutReminder;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'field_waiting_alerts',
    'Field waiting alerts',
    description: 'Alerts asking employees to provide a reason for waiting.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static Future<void> initialize() async {
    if (_initialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings);
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_channel);
    await android?.requestNotificationsPermission();
    _initialized = true;
  }

  static Future<void> showWaitingAlert(Map<String, dynamic> alert) async {
    await initialize();
    final id = int.tryParse('${alert['id']}');
    if (id == null || id == _lastAlertId) return;
    _lastAlertId = id;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'field_waiting_alerts',
        'Field waiting alerts',
        channelDescription:
            'Alerts asking employees to provide a reason for waiting.',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        category: AndroidNotificationCategory.reminder,
        ticker: 'Field waiting reason required',
      ),
    );
    await _plugin.show(
      71403,
      'Field waiting reason',
      'You have stayed at this location for ${alert['waiting_minutes'] ?? 0} minutes. Tap to provide a reason.',
      details,
      payload: 'field-waiting:$id',
    );
  }

  static Future<void> showClockoutReminder(Map<String, dynamic> reminder) async {
    await initialize();
    final attendanceId = int.tryParse('${reminder['attendanceId']}');
    if (attendanceId == null) return;
    final slot = int.tryParse('${reminder['reminderSlot'] ?? 0}') ?? 0;
    final key = '$attendanceId:$slot';
    if (_lastClockoutReminder == key) return;
    _lastClockoutReminder = key;
    final notificationId = 72000 + (attendanceId % 1000);
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'clockout_reminders',
        'Clock-out reminders',
        channelDescription: 'Reminders to clock out after the scheduled work duration.',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        category: AndroidNotificationCategory.reminder,
      ),
    );
    await _plugin.show(notificationId, 'Please clock out', 'Your work session has reached the reminder time. Tap to clock out.', details, payload: 'clock-out:$attendanceId:$slot');
  }
}
