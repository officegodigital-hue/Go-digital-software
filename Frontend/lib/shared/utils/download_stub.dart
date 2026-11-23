// lib/shared/utils/download_stub.dart
//
// Non-web fallback for [downloadFile]. Used on Android, iOS and desktop where
// dart:html is unavailable. Browser-style downloads are a no-op here; mobile
// flows save/share files through their own code paths.
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

void downloadFilePlatform(Uint8List bytes, String fileName, String mimeType) {
  debugPrint('File download triggered: $fileName (${bytes.length} bytes)');
}
