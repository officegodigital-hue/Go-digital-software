import 'dart:html' as html;
import 'dart:typed_data';

/// Triggers a browser download of [bytes] as [fileName] with the given
/// [mimeType]. Browsers save downloads to the user's default Downloads
/// folder automatically — this is the correct (and only) way to "save to
/// Downloads" from Flutter Web, since path_provider/dart:io have no meaning
/// in a browser sandbox.
Future<void> saveAndShareFile(
  List<int> bytes,
  String fileName, {
  String mimeType = 'application/octet-stream',
}) async {
  // ✅ IMPORTANT: Blob parts must be a typed-data view (Uint8List), not a
  // plain Dart/JS List<int> — otherwise the browser coerces it via
  // Array.prototype.toString(), corrupting the file into comma-separated
  // decimal numbers instead of real bytes.
  final bytesData = Uint8List.fromList(bytes);
  final blob = html.Blob([bytesData], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);

  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();

  html.Url.revokeObjectUrl(url);
}
