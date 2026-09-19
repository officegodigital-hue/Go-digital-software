import 'dart:typed_data';

// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

Future<bool> downloadFileBytesPlatform(
  Uint8List bytes,
  String fileName,
  String mimeType,
) async {
  if (bytes.isEmpty) return false;
  final blob = html.Blob(<dynamic>[bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final link = html.AnchorElement(href: url)..download = fileName;
  link.click();
  html.Url.revokeObjectUrl(url);
  return true;
}
