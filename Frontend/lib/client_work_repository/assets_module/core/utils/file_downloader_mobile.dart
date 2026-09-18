import 'package:url_launcher/url_launcher.dart';

Future<bool> downloadFileFromUrl(
  String url,
  String fileName,
) async {
  try {
    final cleanUrl = url.trim();

    if (cleanUrl.isEmpty) {
      return false;
    }

    var downloadUrl = cleanUrl;

    if (!downloadUrl.startsWith('http://') &&
        !downloadUrl.startsWith('https://')) {
      downloadUrl = 'https://$downloadUrl';
    }

    final uri = Uri.tryParse(downloadUrl);

    if (uri == null) {
      return false;
    }

    if (uri.scheme != 'http' &&
        uri.scheme != 'https') {
      return false;
    }

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    return opened;
  } catch (_) {
    return false;
  }
}