// lib/shared/utils/download.dart
//
// Cross-platform file download facade. The real implementation is selected at
// compile time: the web build pulls in `download_web.dart` (which uses
// dart:html), while every other platform (Android, iOS, desktop) uses the
// `download_stub.dart` fallback. This keeps dart:html out of the mobile build.
import 'dart:typed_data';

import 'download_stub.dart' if (dart.library.html) 'download_web.dart';

void downloadFile(Uint8List bytes, String fileName, String mimeType) =>
    downloadFilePlatform(bytes, fileName, mimeType);
