// lib/shared/utils/download_web.dart
//
// Web implementation of [downloadFile]. Only compiled into the web build via
// the conditional import in `download.dart`.
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:typed_data';
import 'dart:html' as html;

void downloadFilePlatform(Uint8List bytes, String fileName, String mimeType) {
  final blob = html.Blob(<dynamic>[bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}
