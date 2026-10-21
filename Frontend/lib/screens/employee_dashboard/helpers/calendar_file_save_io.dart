import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Windows / macOS / Linux: saves straight into the Downloads folder and
/// returns the full path. Android / iOS: writes the file and opens the share /
/// save sheet (Save to Files, Drive, WhatsApp, Mail …).
Future<String?> saveCalendarFile(
  List<int> bytes,
  String fileName, {
  String mimeType = 'application/octet-stream',
}) async {
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    var file = File('${dir.path}${Platform.pathSeparator}$fileName');
    // Don't overwrite an older export: name (1).xls, name (2).xls …
    var n = 1;
    final dot = fileName.lastIndexOf('.');
    final base = dot > 0 ? fileName.substring(0, dot) : fileName;
    final ext = dot > 0 ? fileName.substring(dot) : '';
    while (await file.exists()) {
      file = File('${dir.path}${Platform.pathSeparator}$base ($n)$ext');
      n += 1;
    }
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  await Share.shareXFiles(
    [XFile(file.path, mimeType: mimeType)],
    subject: fileName,
    text: fileName,
  );
  return null;
}
