// lib/core/utils/download.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void downloadFile(Uint8List bytes, String fileName, String mimeType) {
  if (kIsWeb) {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  } else {
    debugPrint('File download triggered: $fileName (${bytes.length} bytes)');
  }
}