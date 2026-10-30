// lib/services/push_notification_service.dart
//
// Mobile push notifications (Firebase Cloud Messaging).
// Chat messages, group / client-group messages and task notifications reach
// the phone with sound even when the app is closed or swiped away from
// recent apps. Android shows them from the system tray; the app does not need
// to be running.
//
// Web / desktop: this service does nothing (in-app sounds keep working there).

import 'dart:async';
import 'dart:convert';

import 'package:android_intent_plus/android_intent.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:godigital_portal/services/authenticated_http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';

/// Runs in a separate isolate when a message arrives and the app is in the
/// background or closed. Messages with a `notification` block (what our
/// server sends) are shown by Android itself, so nothing else is needed here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) await Firebase.initializeApp();
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  /// Two Android channels — must match CHANNELS in backend
  /// lib/pushNotifications.js. The user picks one in Settings.
  ///
  /// GoDigital tone: android/app/src/main/res/raw/notification.mp3
  static const AndroidNotificationChannel appSoundChannel = AndroidNotificationChannel(
    'godigital_alerts',
    'GoDigital alerts',
    description: 'Chat messages and task notifications (GoDigital tone)',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('notification'),
  );

  /// Phone's own notification sound. The user can pick any ringtone for it
  /// in the phone's settings (Settings → Notification sound → Choose).
  static const AndroidNotificationChannel phoneSoundChannel = AndroidNotificationChannel(
    'godigital_alerts_phone',
    'GoDigital alerts (phone sound)',
    description: 'Chat messages and task notifications (your phone sound)',
    importance: Importance.max,
    playSound: true,
  );

  static const String _soundPrefKey = 'push_sound_mode';

  /// 'app' = GoDigital tone, 'phone' = the phone's own sound.
  final ValueNotifier<String> soundMode = ValueNotifier<String>('app');

  AndroidNotificationChannel get channel =>
      soundMode.value == 'phone' ? phoneSoundChannel : appSoundChannel;

  bool get isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// The chat page sets this while it is open — it already plays its own
  /// sound and shows the message, so no extra pop-up then.
  static bool chatScreenOpen = false;

  /// True while AppNotificationCenter is running: it already plays the sound
  /// and shows the top banner inside the open app, so no second pop-up.
  static bool inAppAlertsActive = false;

  /// Called when the user taps a notification (app opens). `data['type']` is
  /// chat | group | client_group | notification | test.
  static void Function(Map<String, dynamic> data)? onOpen;

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  Future<void>? _initFuture;
  String? _token;
  String? _employee;
  Map<String, dynamic>? _pendingOpen;

  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Safe to call many times.
  Future<void> init() {
    if (!supported) return Future.value();
    return _initFuture ??= _init();
  }

  Future<void> _init() async {
    await _loadSoundMode();
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      await _local.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload == null || payload.isEmpty) return;
          try {
            _open(Map<String, dynamic>.from(jsonDecode(payload) as Map));
          } catch (_) {}
        },
      );
      final android = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(appSoundChannel);
      await android?.createNotificationChannel(phoneSoundChannel);

      final messaging = FirebaseMessaging.instance;
      // Android 13+ and iOS ask the user once.
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      await messaging.setForegroundNotificationPresentationOptions(
        alert: false, // we decide below (avoids double pop-ups)
        badge: true,
        sound: false,
      );

      FirebaseMessaging.onMessage.listen(_showWhileOpen);
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _open(m.data));
      final initial = await messaging.getInitialMessage();
      if (initial != null) _pendingOpen = Map<String, dynamic>.from(initial.data);

      messaging.onTokenRefresh.listen((token) {
        _token = token;
        _sendToken();
      });
      _ready = true;
    } catch (e) {
      // Missing google-services.json etc. — the app keeps working without push.
      debugPrint('Push init failed: $e');
    }
  }

  /// Call after login (the layouts do this). Links this phone to the employee.
  Future<void> registerUser(String? employee) async {
    final name = employee?.trim() ?? '';
    if (!supported || name.isEmpty) return;
    await init();
    if (!_ready) return;
    _employee = name;
    try {
      _token ??= await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('Push token error: $e');
    }
    await _sendToken();

    // Notification tapped while the app was closed → hand it over now.
    final pending = _pendingOpen;
    if (pending != null && onOpen != null) {
      _pendingOpen = null;
      onOpen!(pending);
    }
  }

  /// Call on logout so this phone stops receiving that person's messages.
  Future<void> unregister() async {
    final token = _token;
    _employee = null;
    if (!supported || token == null) return;
    try {
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/push/unregister'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token}),
      );
    } catch (e) {
      debugPrint('Push unregister error: $e');
    }
  }

  Future<void> _sendToken() async {
    final token = _token;
    final employee = _employee;
    if (token == null || employee == null) return;
    await _loadSoundMode(); // the Settings card may have changed it
    try {
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/push/register'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'employee': employee,
          'token': token,
          'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
          'soundMode': soundMode.value,
        }),
      );
    } catch (e) {
      debugPrint('Push register error: $e');
    }
  }

  // ── Notification sound (Settings page) ──────────────────────────────────
  Future<void> _loadSoundMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      soundMode.value = prefs.getString(_soundPrefKey) == 'phone' ? 'phone' : 'app';
    } catch (_) {}
  }

  /// Switch between the GoDigital tone and the phone's own sound.
  /// Saved on this phone and sent to the server, so notifications that
  /// arrive while the app is closed use the same choice.
  Future<void> setSoundMode(String mode) async {
    final value = mode == 'phone' ? 'phone' : 'app';
    soundMode.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_soundPrefKey, value);
    } catch (_) {}
    await init();
    await _sendToken();
  }

  /// Opens Android's sound settings for our phone-sound channel, where the
  /// user can choose any ringtone / notification tone on the phone.
  Future<bool> openPhoneSoundSettings() async {
    if (!isAndroid) return false;
    await init();
    try {
      final info = await PackageInfo.fromPlatform();
      await AndroidIntent(
        action: 'android.settings.CHANNEL_NOTIFICATION_SETTINGS',
        arguments: <String, dynamic>{
          'android.provider.extra.APP_PACKAGE': info.packageName,
          'android.provider.extra.CHANNEL_ID': phoneSoundChannel.id,
        },
      ).launch();
      return true;
    } catch (_) {
      // Older phones: open the app's notification page instead.
      try {
        final info = await PackageInfo.fromPlatform();
        await AndroidIntent(
          action: 'android.settings.APP_NOTIFICATION_SETTINGS',
          arguments: <String, dynamic>{
            'android.provider.extra.APP_PACKAGE': info.packageName,
          },
        ).launch();
        return true;
      } catch (e) {
        debugPrint('Open sound settings failed: $e');
        return false;
      }
    }
  }

  /// Plays a short preview of the current choice as a phone notification.
  Future<void> previewSound() async {
    if (!isAndroid) return;
    await init();
    final ch = channel;
    await _local.show(
      99001,
      'GoDigital',
      soundMode.value == 'phone'
          ? 'This is your phone notification sound'
          : 'This is the GoDigital notification sound',
      NotificationDetails(
        android: AndroidNotificationDetails(
          ch.id,
          ch.name,
          channelDescription: ch.description,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: ch.sound,
          icon: '@mipmap/ic_launcher',
          timeoutAfter: 4000,
        ),
      ),
    );
  }

  void _open(Map<String, dynamic> data) {
    if (onOpen != null) {
      onOpen!(data);
    } else {
      _pendingOpen = data;
    }
  }

  /// App is open (foreground). Task notifications already show the in-app
  /// pop-up + sound from the top bar, so only chat messages are shown here,
  /// and only when the chat page is not open.
  Future<void> _showWhileOpen(RemoteMessage message) async {
    final type = message.data['type']?.toString() ?? '';
    final isChat = type == 'chat' || type == 'group' || type == 'client_group' || type == 'test';
    if (type != 'test' && (inAppAlertsActive || !isChat || chatScreenOpen)) return;

    final title = message.notification?.title ?? message.data['title']?.toString() ?? 'GoDigital';
    final body = message.notification?.body ?? message.data['body']?.toString() ?? '';
    final channel = this.channel;
    await _local.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: channel.sound,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      payload: jsonEncode(message.data),
    );
  }
}
