import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/api_constants.dart';

class RepositoryService {
  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      throw Exception('Login token missing. Please login again.');
    }

    return token;
  }

  Future<List<dynamic>> getRepository() async {
    final token = await _getToken();

    final response = await http.get(
      Uri.parse(ApiConstants.repository),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return List<dynamic>.from(data['data']);
    }

    throw Exception(data['message'] ?? 'Failed to load repository');
  }

  Future<List<dynamic>> getClients() async {
    final token = await _getToken();

    final response = await http.get(
      Uri.parse('${ApiConstants.assets}/clients'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return List<dynamic>.from(data['data']);
    }

    throw Exception(data['message'] ?? 'Failed to load repository clients');
  }

  Future<Map<String, dynamic>> getClientAssetDetails(int clientId) async {
    final token = await _getToken();

    final response = await http.get(
      Uri.parse('${ApiConstants.assets}/clients/$clientId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return Map<String, dynamic>.from(data['data']);
    }

    throw Exception(data['message'] ?? 'Failed to load client details');
  }

  Future<Map<String, dynamic>> getClientDetails(int clientId) async {
    return getClientAssetDetails(clientId);
  }

  Future<void> updateClientDetails({
    required int clientId,
    required String clientName,
    required String shortName,
    required List<Map<String, dynamic>> deliverables,
    List<int> deletedDeliverableIds = const [],
  }) async {
    final token = await _getToken();

    final request = http.MultipartRequest(
      'PUT',
      Uri.parse('${ApiConstants.assets}/clients/$clientId'),
    );

    request.headers['Authorization'] = 'Bearer $token';

    request.fields['client_name'] = clientName;
    request.fields['short_name'] = shortName;
    request.fields['category_slug'] = 'digital-marketing';
    request.fields['deleted_deliverable_ids'] = jsonEncode(deletedDeliverableIds);

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

    request.fields['deliverables'] = jsonEncode(jsonDeliverables);

    for (final item in deliverables) {
      final id = _clean(item['id']);
      final type = _normalizeType(
        _clean(
          item['deliverable_type'] ??
              item['type'] ??
              item['deliverableType'] ??
              item['key'],
        ),
      );

      if (type.isEmpty) continue;

      final link = _clean(
        item['google_drive_link'] ??
            item['link'] ??
            item['googleDriveLink'] ??
            item['url'],
      );

      final description = _clean(
        item['description'] ??
            item['desc'] ??
            item['details'],
      );

      request.fields['${type}_id'] = id;
      request.fields['${type}_link'] = link;
      request.fields['${type}_description'] = description;

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

      if (type == 'mobile_application' || type == 'website_application') {
        request.fields['${type}_admin_url'] = adminPanelUrl;
        request.fields['${type}_user_email'] = userEmail;
        request.fields['${type}_password'] = password;
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
            '${type}_file',
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

    throw Exception(data['message'] ?? 'Failed to update client details');
  }

  Future<void> deleteClientAssetDetails(int clientId) async {
    final token = await _getToken();

    final response = await http.delete(
      Uri.parse('${ApiConstants.assets}/clients/$clientId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return;
    }

    throw Exception(data['message'] ?? 'Failed to delete client');
  }

  Future<void> deleteClient(int clientId) async {
    return deleteClientAssetDetails(clientId);
  }

  Future<void> deleteDeliverable(int deliverableId) async {
    final token = await _getToken();

    final response = await http.delete(
      Uri.parse('${ApiConstants.assets}/deliverables/$deliverableId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return;
    }

    throw Exception(data['message'] ?? 'Failed to delete deliverable');
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
