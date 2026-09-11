import 'dart:html' as html;
import 'dart:typed_data';

/// Triggers a browser download of [bytes] as [fileName]. Browsers save
/// downloads to the user's default Downloads folder automatically — this is
/// the correct (and only) way to "save to Downloads" from Flutter Web, since
/// path_provider/dart:io have no meaning in a browser sandbox.
Future<void> saveAndShareCsv(List<int> bytes, String fileName) async {
  // ✅ IMPORTANT: Blob parts must be a typed-data view (Uint8List), not a
  // plain Dart/JS List<int>. A plain list gets coerced via JS's
  // Array.prototype.toString() — i.e. joined as comma-separated decimal
  // numbers — which is exactly what corrupted the previous export
  // ("239,187,191,83,46,78,111,...") instead of writing real bytes.
  final bytesData = Uint8List.fromList(bytes);
  final blob = html.Blob([bytesData], 'text/csv');
  final url = html.Url.createObjectUrlFromBlob(blob);

  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();

  html.Url.revokeObjectUrl(url);
}