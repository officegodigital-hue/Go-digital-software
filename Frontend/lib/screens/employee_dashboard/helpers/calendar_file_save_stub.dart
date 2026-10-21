/// Returns where the file went (a path / message), or null.
Future<String?> saveCalendarFile(
  List<int> bytes,
  String fileName, {
  String mimeType = 'application/octet-stream',
}) async {
  throw UnsupportedError('File export is not supported on this platform');
}
