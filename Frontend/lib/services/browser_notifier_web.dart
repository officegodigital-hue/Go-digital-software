// Chrome / Edge / Firefox desktop notifications (shown even when the GoDigital
// tab is in the background or the browser is minimised).
import 'dart:js_interop';

import 'package:web/web.dart' as web;

bool get pageHidden => web.document.hidden;

String get permission {
  try {
    return web.Notification.permission;
  } catch (_) {
    return 'unsupported';
  }
}

Future<String> requestPermission() async {
  try {
    if (web.Notification.permission == 'default') {
      final result = await web.Notification.requestPermission().toDart;
      return result.toDart;
    }
    return web.Notification.permission;
  } catch (_) {
    return 'unsupported';
  }
}

void show(String title, String body, {String? tag}) {
  try {
    if (web.Notification.permission != 'granted') return;
    final n = web.Notification(
      title,
      web.NotificationOptions(
        body: body,
        icon: 'icons/Icon-192.png',
        tag: tag ?? '',
      ),
    );
    n.onclick = ((web.Event _) {
      web.window.focus();
      n.close();
    }).toJS;
  } catch (_) {}
}
