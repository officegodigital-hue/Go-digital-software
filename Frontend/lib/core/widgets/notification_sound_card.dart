// lib/core/widgets/notification_sound_card.dart
//
// Settings → Notification sound.
// Choose the GoDigital tone or your phone's own notification sound (any
// ringtone / tone on the phone) for chat and task notifications — also when
// the app is closed.
//
// Self-contained: works with any version of push_notification_service.dart.
import 'dart:convert';

import 'package:android_intent_plus/android_intent.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:godigital_portal/services/authenticated_http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:godigital_portal/services/api_config.dart';
import 'package:godigital_portal/services/app_notification_center.dart';
import 'package:godigital_portal/services/auth_service.dart';

/// Sound choice for this phone: 'app' (GoDigital tone) or 'phone'.
/// Channel ids must match CHANNELS in backend lib/pushNotifications.js.
class NotificationSoundPrefs {
  NotificationSoundPrefs._();

  static const String prefKey = 'push_sound_mode';
  static final ValueNotifier<String> mode = ValueNotifier<String>('app');

  static const AndroidNotificationChannel appChannel = AndroidNotificationChannel(
    'godigital_alerts',
    'GoDigital alerts',
    description: 'Chat messages and task notifications (GoDigital tone)',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('notification'),
  );

  static const AndroidNotificationChannel phoneChannel = AndroidNotificationChannel(
    'godigital_alerts_phone',
    'GoDigital alerts (phone sound)',
    description: 'Chat messages and task notifications (your phone sound)',
    importance: Importance.max,
    playSound: true,
  );

  static final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  static bool _localReady = false;

  static bool get isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      mode.value = prefs.getString(prefKey) == 'phone' ? 'phone' : 'app';
    } catch (_) {}
  }

  static Future<void> _ensureLocal() async {
    if (_localReady || !isAndroid) return;
    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notification'),
      ),
    );
    final android = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(appChannel);
    await android?.createNotificationChannel(phoneChannel);
    _localReady = true;
  }

  /// Save the choice on the phone and tell the server (for closed-app pushes).
  static Future<void> setMode(String value, String? employee) async {
    final m = value == 'phone' ? 'phone' : 'app';
    mode.value = m;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefKey, m);
    } catch (_) {}
    if (!isAndroid) return;
    try {
      await _ensureLocal();
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      final token = await FirebaseMessaging.instance.getToken();
      final name = employee?.trim() ?? '';
      if (token == null || name.isEmpty) return;
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/push/register'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'employee': name,
          'token': token,
          'platform': 'android',
          'soundMode': m,
        }),
      );
    } catch (e) {
      debugPrint('Sound mode sync failed: $e');
    }
  }

  /// Phone settings for the phone-sound channel → user picks any tone.
  static Future<bool> openPhoneSoundSettings() async {
    if (!isAndroid) return false;
    try {
      await _ensureLocal();
      final info = await PackageInfo.fromPlatform();
      await AndroidIntent(
        action: 'android.settings.CHANNEL_NOTIFICATION_SETTINGS',
        arguments: <String, dynamic>{
          'android.provider.extra.APP_PACKAGE': info.packageName,
          'android.provider.extra.CHANNEL_ID': phoneChannel.id,
        },
      ).launch();
      return true;
    } catch (_) {
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

  /// Plays the current choice once (short notification).
  static Future<void> preview() async {
    if (!isAndroid) return;
    try {
      await _ensureLocal();
      final ch = mode.value == 'phone' ? phoneChannel : appChannel;
      await _local.show(
        99001,
        'GoDigital',
        mode.value == 'phone'
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
            icon: '@drawable/ic_notification',
            timeoutAfter: 4000,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Sound preview failed: $e');
    }
  }
}

class NotificationSoundCard extends StatefulWidget {
  const NotificationSoundCard({super.key});

  @override
  State<NotificationSoundCard> createState() => _NotificationSoundCardState();
}

class _NotificationSoundCardState extends State<NotificationSoundCard> {
  static const _primary = Color(0xFF0757D5);
  static const _text = Color(0xFF14213D);
  static const _muted = Color(0xFF718096);
  static const _border = Color(0xFFE4EAF3);
  static const _accent = Color(0xFF7C3AED);

  bool _busy = false;

  bool get _mobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    NotificationSoundPrefs.load();
  }

  Future<void> _choose(String mode) async {
    if (_busy || NotificationSoundPrefs.mode.value == mode) return;
    final employee = context.read<AuthService>().user?['fullName']?.toString();
    setState(() => _busy = true);
    await NotificationSoundPrefs.setMode(mode, employee);
    if (!mounted) return;
    setState(() => _busy = false);
    if (mode == 'phone' && NotificationSoundPrefs.isAndroid) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Choose your phone sound',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          content: const Text(
            'Phone settings will open.\nTap "Sound" and pick any tone from your phone, then come back.',
            style: TextStyle(fontSize: 13, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Open settings'),
            ),
          ],
        ),
      );
      if (go == true) await _openPhoneSettings();
    } else {
      _snack(mode == 'phone'
          ? 'Notifications will use your phone sound.'
          : 'Notifications will use the GoDigital sound.');
    }
  }

  Future<void> _openPhoneSettings() async {
    final ok = await NotificationSoundPrefs.openPhoneSoundSettings();
    if (!ok) _snack('Open phone Settings → Apps → GoDigital → Notifications to change the sound.');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .025),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ValueListenableBuilder<String>(
        valueListenable: NotificationSoundPrefs.mode,
        builder: (context, mode, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.notifications_active_outlined, color: _accent, size: 21),
                ),
                const SizedBox(width: 13),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Notification sound',
                          style: TextStyle(color: _text, fontSize: 16, fontWeight: FontWeight.w900)),
                      SizedBox(height: 3),
                      Text('Sound for chat and task notifications on this phone, even when the app is closed.',
                          style: TextStyle(color: _muted, fontSize: 11.5)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (!_mobile)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFD),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Open GoDigital on your phone to choose the notification sound.\n'
                      'In this browser, allow notifications to get alerts while GoDigital is in another tab or minimised.',
                      style: TextStyle(color: _muted, fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.45),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final result = await AppNotificationCenter.instance.enableBrowserNotifications();
                        _snack(result == 'granted'
                            ? 'Browser notifications are on.'
                            : result == 'denied'
                                ? 'Blocked in the browser. Click the lock icon in the address bar → Notifications → Allow.'
                                : 'This browser does not support notifications.');
                      },
                      icon: const Icon(Icons.notifications_on_outlined, size: 17),
                      label: const Text('Allow browser notifications'),
                      style: _outlined(),
                    ),
                  ],
                ),
              )
            else ...[
              LayoutBuilder(
                builder: (context, box) {
                  final wide = box.maxWidth > 560;
                  final a = _option(
                    selected: mode == 'app',
                    icon: Icons.music_note_rounded,
                    title: 'GoDigital sound',
                    subtitle: 'The app\'s own tone',
                    onTap: () => _choose('app'),
                  );
                  final b = _option(
                    selected: mode == 'phone',
                    icon: Icons.phone_android_rounded,
                    title: 'My phone sound',
                    subtitle: 'Pick any tone from your phone',
                    onTap: () => _choose('phone'),
                  );
                  return wide
                      ? Row(children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)])
                      : Column(children: [a, const SizedBox(height: 10), b]);
                },
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  if (mode == 'phone' && NotificationSoundPrefs.isAndroid)
                    OutlinedButton.icon(
                      onPressed: _openPhoneSettings,
                      icon: const Icon(Icons.library_music_outlined, size: 17),
                      label: const Text('Choose phone sound'),
                      style: _outlined(),
                    ),
                  if (NotificationSoundPrefs.isAndroid)
                    TextButton.icon(
                      onPressed: NotificationSoundPrefs.preview,
                      icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
                      label: const Text('Test sound'),
                      style: TextButton.styleFrom(foregroundColor: _primary),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  ButtonStyle _outlined() => OutlinedButton.styleFrom(
        foregroundColor: _primary,
        side: const BorderSide(color: Color(0xFFCAD8F0)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );

  Widget _option({
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? const Color(0xFFEFF5FF) : const Color(0xFFFBFCFE),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: _busy ? null : onTap,
        borderRadius: BorderRadius.circular(15),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: selected ? _primary : _border, width: selected ? 1.6 : 1),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? _primary : _muted, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: selected ? _primary : _text, fontSize: 13.5, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: _muted, fontSize: 11)),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? _primary : const Color(0xFFB3BCC9),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
