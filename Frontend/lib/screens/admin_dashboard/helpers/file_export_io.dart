import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Writes [bytes] to a temporary file named [fileName] and opens the native
/// share/save sheet (Android/iOS/macOS/Windows/Linux) so the person can save
/// it to Downloads, send it via WhatsApp/Mail, etc. [mimeType] is accepted
/// for API symmetry with the web implementation but isn't needed here.
Future<void> saveAndShareFile(
  List<int> bytes,
  String fileName, {
  String mimeType = 'application/octet-stream',
}) async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsBytes(bytes);

  await Share.shareXFiles(
    [XFile(file.path)],
    subject: fileName,
    text: fileName,
  );
}
