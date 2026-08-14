import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/api_constants.dart';

class AssetUploadService {
  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      throw Exception('Login token missing. Please login again.');
    }

    return token;
  }

  Future<void> uploadAssets({
    required String clientName,
    required String shortName,
    required List<Map<String, dynamic>> deliverables,
  }) async {
    final token = await _getToken();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse(ApiConstants.assets),
    );

    request.headers['Authorization'] = 'Bearer $token';

    request.fields['client_name'] = clientName;
    request.fields['short_name'] = shortName;
    request.fields['category_slug'] = 'digital-marketing';

    final jsonDeliverables = deliverables.map((item) {
      final cleanItem = Map<String, dynamic>.from(item);

      final files = _extractFiles(item);
      cleanItem['file_count'] = files.length;

      cleanItem.remove('file');
      cleanItem.remove('files');
      cleanItem.remove('bytes');
      cleanItem.remove('fileBytes');
      cleanItem.remove('data');
      return cleanItem;
    }).toList();

    // Important for extra sections like Other Link 2, Mobile App 2, Photos 2.
    request.fields['deliverables'] = jsonEncode(jsonDeliverables);

    for (final item in deliverables) {
      final rawType = _clean(
        item['type'] ??
            item['deliverable_type'] ??
            item['deliverableType'] ??
            item['key'],
      );

      if (rawType.isEmpty) continue;

      final normalizedType = _normalizeType(rawType);

      final link = _clean(
        item['link'] ??
            item['google_drive_link'] ??
            item['googleDriveLink'] ??
            item['url'],
      );

      final description = _clean(
        item['description'] ??
            item['desc'] ??
            item['details'],
      );

      // Old backend field support.
      request.fields['${normalizedType}_link'] = link;
      request.fields['${normalizedType}_description'] = description;

      final adminPanelUrl = _clean(
        item['admin_panel_url'] ??
            item['adminPanelUrl'] ??
            item['admin_url'] ??
            item['adminUrl'],
      );

      final userEmail = _clean(
        item['user_email'] ??
            item['userEmail'] ??
            item['email'],
      );

      final password = _clean(
        item['password_text'] ??
            item['passwordText'] ??
            item['password'],
      );

      if (normalizedType == 'mobile_application' ||
          normalizedType == 'website_application') {
        request.fields['${normalizedType}_admin_url'] = adminPanelUrl;
        request.fields['${normalizedType}_user_email'] = userEmail;
        request.fields['${normalizedType}_password'] = password;
      }

      final files = _extractFiles(item);

      for (final file in files) {
        final fileName = _clean(
          file['name'] ??
              file['file_name'] ??
              file['fileName'] ??
              file['filename'] ??
              'uploaded-file',
        );

        final bytes = _extractBytes(file);

        if (bytes == null || bytes.isEmpty) continue;

        request.files.add(
          http.MultipartFile.fromBytes(
            '${normalizedType}_file',
            bytes,
            filename: fileName,
          ),
        );
      }
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    final data = jsonDecode(response.body);

    if ((response.statusCode == 200 || response.statusCode == 201) &&
        data['success'] == true) {
      return;
    }

    throw Exception(data['message'] ?? 'Failed to upload assets');
  }

  String _clean(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  String _normalizeType(String value) {
    final type = value.trim().toLowerCase();

    switch (type) {
      case 'poster':
      case 'poster design':
      case 'poster_design':
      case 'poster-design':
        return 'poster_design';

      case 'video':
      case 'videos':
        return 'video';

      case 'landing page':
      case 'landing_page':
      case 'landing-page':
        return 'landing_page';

      case 'website':
      case 'websites':
        return 'website';

      case 'other link':
      case 'other_link':
      case 'other-link':
        return 'other_link';

      case 'photo':
      case 'photos':
      case 'image':
      case 'images':
        return 'photos';

      case 'portfolio':
        return 'portfolio';

      case 'package':
      case 'packages':
        return 'packages';

      case 'mobile application':
      case 'mobile_application':
      case 'mobile-application':
      case 'mobile app':
      case 'mobile_app':
      case 'mobile-app':
        return 'mobile_application';

      case 'website application':
      case 'website_application':
      case 'website-application':
      case 'web application':
      case 'web_application':
      case 'web-application':
      case 'web app':
      case 'web_app':
      case 'web-app':
        return 'website_application';

      default:
        return type.replaceAll('-', '_').replaceAll(' ', '_');
    }
  }

  List<Map<String, dynamic>> _extractFiles(Map<String, dynamic> item) {
    final List<Map<String, dynamic>> files = [];

    final possibleList =
        item['files'] ?? item['selectedFiles'] ?? item['uploadedFiles'];

    if (possibleList is List) {
      for (final file in possibleList) {
        if (file is Map<String, dynamic>) {
          files.add(file);
        } else if (file is Map) {
          files.add(Map<String, dynamic>.from(file));
        }
      }
    }

    final singleFile =
        item['file'] ?? item['selectedFile'] ?? item['uploadedFile'];

    if (singleFile is Map<String, dynamic>) {
      files.add(singleFile);
    } else if (singleFile is Map) {
      files.add(Map<String, dynamic>.from(singleFile));
    }

    if (item.containsKey('bytes') ||
        item.containsKey('fileBytes') ||
        item.containsKey('data')) {
      files.add(item);
    }

    return files;
  }

  Uint8List? _extractBytes(Map<String, dynamic> file) {
    final dynamic rawBytes =
        file['bytes'] ?? file['fileBytes'] ?? file['data'] ?? file['uint8list'];

    if (rawBytes == null) return null;

    if (rawBytes is Uint8List) {
      return rawBytes;
    }

    if (rawBytes is List<int>) {
      return Uint8List.fromList(rawBytes);
    }

    return null;
  }
}
