// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

Future<bool> downloadFileFromUrl(
  String url,
  String fileName,
) async {
  try {
    final cleanUrl = url.trim();

    if (cleanUrl.isEmpty) {
      return false;
    }

    if (!cleanUrl.startsWith('http://') &&
        !cleanUrl.startsWith('https://')) {
      return false;
    }

    final uri = Uri.tryParse(cleanUrl);

    if (uri == null ||
        (uri.scheme != 'http' &&
            uri.scheme != 'https')) {
      return false;
    }

    final anchor = html.AnchorElement(
      href: cleanUrl,
    )
      ..download = fileName
      ..style.display = 'none';

    html.document.body?.append(anchor);

    anchor.click();

    anchor.remove();

    return true;
  } catch (_) {
    return false;
  }
}