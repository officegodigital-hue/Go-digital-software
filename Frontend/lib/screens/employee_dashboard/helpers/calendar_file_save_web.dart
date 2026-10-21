// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

/// Browser download → the PC's Downloads folder.
Future<String?> saveCalendarFile(
  List<int> bytes,
  String fileName, {
  String mimeType = 'application/octet-stream',
}) async {
  // Blob parts must be Uint8List (raw bytes), not List<int>, or the browser
  // writes "60,104,116,…" instead of the file.
  final blob = html.Blob([Uint8List.fromList(bytes)], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  // Give the browser a moment to start the download before freeing it.
  Future.delayed(const Duration(seconds: 2), () => html.Url.revokeObjectUrl(url));
  return 'Downloads';
}
