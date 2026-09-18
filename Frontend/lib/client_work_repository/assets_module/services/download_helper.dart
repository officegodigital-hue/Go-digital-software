import 'dart:typed_data';

import 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart';

Future<bool> downloadFileBytes(
  Uint8List bytes,
  String fileName,
  String mimeType,
) => downloadFileBytesPlatform(bytes, fileName, mimeType);
