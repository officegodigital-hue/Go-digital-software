import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/auth/admin_auth_session.dart';
import '../models/admin_permission_model.dart';

class AdminPermissionRepository {
  AdminPermissionRepository({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const String _baseUrl =
      'http://localhost:3000/api/v1/admin/permissions';

  Future<Map<String, String>> _headers() async {
    final String? token = await AdminAuthSession.getAccessToken();

    if (token == null || token.trim().isEmpty) {
      throw Exception('Admin authentication token is missing.');
    }

    return <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<AdminPermissionListResult> getPermissionRequests({
    int page = 1,
    int limit = 5,
    String search = '',
    String type = '',
    String status = 'pending',
    int? branchId,
  }) async {
    final Map<String, String> queryParameters = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      'status': status,
    };

    if (search.trim().isNotEmpty) {
      queryParameters['search'] = search.trim();
    }

    if (type.trim().isNotEmpty) {
      queryParameters['type'] = type.trim();
    }

    if (branchId != null) {
      queryParameters['branchId'] = branchId.toString();
    }

    final Uri uri = Uri.parse(
      _baseUrl,
    ).replace(queryParameters: queryParameters);

    final http.Response response = await _client.get(
      uri,
      headers: await _headers(),
    );

    final Map<String, dynamic> body = _decodeResponse(response);

    final List<dynamic> rawList = body['data'] is List
        ? body['data'] as List<dynamic>
        : <dynamic>[];

    final List<AdminPermissionModel> permissions = rawList
        .whereType<Map<String, dynamic>>()
        .map(AdminPermissionModel.fromJson)
        .toList();

    final Map<String, dynamic> paginationJson =
        body['pagination'] is Map<String, dynamic>
        ? body['pagination'] as Map<String, dynamic>
        : <String, dynamic>{};

    return AdminPermissionListResult(
      permissions: permissions,
      pagination: AdminPermissionPagination.fromJson(paginationJson),
    );
  }

  Future<AdminPermissionSummary> getPermissionSummary({int? branchId}) async {
    final Map<String, String> queryParameters = <String, String>{};

    if (branchId != null) {
      queryParameters['branchId'] = branchId.toString();
    }

    final Uri uri = Uri.parse(
      '$_baseUrl/summary',
    ).replace(queryParameters: queryParameters);

    final http.Response response = await _client.get(
      uri,
      headers: await _headers(),
    );

    final Map<String, dynamic> body = _decodeResponse(response);

    final Map<String, dynamic> data = body['data'] is Map<String, dynamic>
        ? body['data'] as Map<String, dynamic>
        : <String, dynamic>{};

    return AdminPermissionSummary.fromJson(data);
  }

  Future<AdminPermissionModel> getPermissionById(int permissionId) async {
    final Uri uri = Uri.parse('$_baseUrl/$permissionId');

    final http.Response response = await _client.get(
      uri,
      headers: await _headers(),
    );

    final Map<String, dynamic> body = _decodeResponse(response);

    final Map<String, dynamic> data = body['data'] is Map<String, dynamic>
        ? body['data'] as Map<String, dynamic>
        : <String, dynamic>{};

    return AdminPermissionModel.fromJson(data);
  }

  Future<AdminPermissionModel> updatePermissionStatus({
    required int permissionId,
    required String status,
    String adminRemarks = '',
  }) async {
    final Uri uri = Uri.parse('$_baseUrl/$permissionId/status');

    final http.Response response = await _client.patch(
      uri,
      headers: await _headers(),
      body: jsonEncode(<String, dynamic>{
        'status': status,
        'adminRemarks': adminRemarks.trim(),
      }),
    );

    final Map<String, dynamic> body = _decodeResponse(response);

    final Map<String, dynamic> data = body['data'] is Map<String, dynamic>
        ? body['data'] as Map<String, dynamic>
        : <String, dynamic>{};

    return AdminPermissionModel.fromJson(data);
  }

  Future<AdminPermissionModel> approvePermission({
    required int permissionId,
    String adminRemarks = '',
  }) {
    return updatePermissionStatus(
      permissionId: permissionId,
      status: 'approved',
      adminRemarks: adminRemarks,
    );
  }

  Future<AdminPermissionModel> rejectPermission({
    required int permissionId,
    required String adminRemarks,
  }) {
    return updatePermissionStatus(
      permissionId: permissionId,
      status: 'rejected',
      adminRemarks: adminRemarks,
    );
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    Map<String, dynamic> body;

    try {
      final dynamic decoded = jsonDecode(response.body);

      body = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      body = <String, dynamic>{};
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    final String message = body['message']?.toString().trim() ?? '';

    throw Exception(
      message.isNotEmpty
          ? message
          : 'Permission API request failed '
                'with status ${response.statusCode}.',
    );
  }

  void dispose() {
    _client.close();
  }
}
