// lib/services/mimi_voice.dart
//
// MIMI's voice. Instead of a beep, the notification robot (MIMI) now speaks
// the message out loud. For a chat it also says who it is from
// ("Vijay says, are you free now?").
//
// One shared instance speaks for every source (the robot in the employee and
// admin top bars, and the app-wide notification banner). A short de-dupe window
// makes sure the same message is not spoken twice when two of those fire for
// the same notification.

import 'package:flutter_tts/flutter_tts.dart';

class MimiVoice {
  MimiVoice._();
  static final MimiVoice instance = MimiVoice._();

  final FlutterTts _tts = FlutterTts();
  bool _initStarted = false;

  /// Turn MIMI's voice on/off (e.g. from a settings switch later).
  bool enabled = true;

  String _lastSpoken = '';
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _ensureInit() async {
    if (_initStarted) return;
    _initStarted = true;
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.48); // a little slower, clearer
      await _tts.setPitch(1.12); // slightly higher — friendly robot
      await _tts.setVolume(1.0);
    } catch (_) {
      // TTS may be unavailable on some platforms; stay silent rather than crash.
    }
  }

  /// Speak a notification. When [sender] is given (a chat), MIMI names them.
  Future<void> announce({String? sender, required String message}) {
    final who = (sender ?? '').trim();
    final msg = _clean(message);
    if (msg.isEmpty) return Future.value();
    final text = who.isEmpty ? msg : '$who says. $msg';
    return speak(text);
  }

  Future<void> speak(String text) async {
    if (!enabled) return;
    final clean = _clean(text);
    if (clean.isEmpty) return;

    final now = DateTime.now();
    if (clean == _lastSpoken && now.difference(_lastAt).inSeconds < 6) {
      return; // same message just spoken — don't repeat it
    }
    _lastSpoken = clean;
    _lastAt = now;

    await _ensureInit();
    try {
      await _tts.stop(); // interrupt the previous line so the newest is heard
      await _tts.speak(clean);
    } catch (_) {}
  }

  void stop() {
    try {
      _tts.stop();
    } catch (_) {}
  }

  /// Remove emojis, links and markdown so the spoken line sounds natural.
  String _clean(String s) {
    var out = s
        .replaceAll(RegExp(r'https?:\/\/\S+'), ' a link ')
        .replaceAll(RegExp(r'[*_`#>~|•·]'), ' ');
    out = out.replaceAll(
      RegExp(
        r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2190}-\u{21FF}\u{2B00}-\u{2BFF}️]',
        unicode: true,
      ),
      ' ',
    );
    out = out.replaceAll(RegExp(r'\s+'), ' ').trim();
    return out;
  }
}
