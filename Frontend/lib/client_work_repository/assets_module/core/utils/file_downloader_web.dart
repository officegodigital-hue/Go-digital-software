// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;

Future<bool> downloadFileFromUrl(
  String fileUrl,
  String fileName,
) async {
  try {
    final cleanUrl = fileUrl.trim();

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

    // ------------------------------------------------------------
    // Fetch the actual file.
    // This does NOT navigate the browser to the URL.
    // ------------------------------------------------------------

    final request = await html.HttpRequest.request(
      cleanUrl,
      method: 'GET',
      responseType: 'blob',
      requestHeaders: const {},
    );

    final blob = request.response;

    if (blob is! html.Blob) {
      return false;
    }

    // ------------------------------------------------------------
    // Create a temporary local browser URL for the downloaded blob.
    // ------------------------------------------------------------

    final blobUrl =
        html.Url.createObjectUrlFromBlob(blob);

    // ------------------------------------------------------------
    // Create hidden download link.
    // ------------------------------------------------------------

    final anchor = html.AnchorElement(
      href: blobUrl,
    )
      ..download = fileName
      ..style.display = 'none';

    html.document.body?.append(anchor);

    // ------------------------------------------------------------
    // Trigger browser download.
    // No website redirect.
    // ------------------------------------------------------------

    anchor.click();

    // ------------------------------------------------------------
    // Clean up temporary elements/URL.
    // ------------------------------------------------------------

    anchor.remove();

    html.Url.revokeObjectUrl(blobUrl);

    return true;
  } catch (_) {
    return false;
  }
}