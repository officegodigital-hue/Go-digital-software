import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/api_config.dart';
import '../../../services/auth_storage.dart';

class ApiService {
  ApiService._();

  // ============================================================
  // API BASE URL
  // ============================================================

  // Web / Desktop
  // Use the existing GoDigital API and its existing auth_token.
  static String get baseUrl => '${ApiConfig.baseUrl}/client-repository';

  // Android Emulator:
  //
  // static const String baseUrl =
  //     'http://10.0.2.2:5000/api';

  // Physical Android phone:
  //
  // Replace localhost with your computer LAN IP.
  //
  // Example:
  //
  // static const String baseUrl =
  //     'http://192.168.1.100:5000/api';

  // ============================================================
  // TOKEN
  // ============================================================

  static Future<void> saveToken(
    String token,
  ) => AuthStorage.setString('auth_token', token);

  static Future<String?> getToken() => AuthStorage.getString('auth_token');

  static Future<void> clearToken() async {
    await AuthStorage.remove('auth_token');
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(
      'logged_in_user_name',
    );

    await prefs.remove(
      'logged_in_user_email',
    );

    await prefs.remove(
      'logged_in_user_role',
    );
  }

  // ============================================================
  // LOGGED-IN USER
  // ============================================================

  static Future<String?>
      getLoggedInUserName() async {
    final user = await _storedUser();
    if (user != null) {
      return user['fullName']?.toString() ?? user['name']?.toString();
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('logged_in_user_name');
  }

  static Future<String?>
      getLoggedInUserEmail() async {
    final user = await _storedUser();
    if (user != null) return user['email']?.toString();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('logged_in_user_email');
  }

  static Future<String?>
      getLoggedInUserRole() async {
    final user = await _storedUser();
    if (user != null) return user['role']?.toString();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('logged_in_user_role');
  }

  static Future<Map<String, dynamic>?> _storedUser() async {
    final raw = await AuthStorage.getString('user_data');
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final value = jsonDecode(raw);
      return value is Map ? Map<String, dynamic>.from(value) : null;
    } catch (_) {
      return null;
    }
  }

  /// Returns the current authenticated employee from the database.
  static Future<Map<String, dynamic>> getMyProfile() async {
    final token = await _requiredToken();
    final response = await http.get(
      Uri.parse('$baseUrl/profile/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = await _jsonResponse(response);
    return Map<String, dynamic>.from(data['data'] ?? {});
  }

  static Future<Map<String, dynamic>> updateMyProfile({
    required String name,
    required String email,
    required String mobile,
  }) async {
    final token = await _requiredToken();
    final response = await http.put(
      Uri.parse('$baseUrl/profile/me'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'name': name, 'email': email, 'mobile': mobile}),
    );
    final data = await _jsonResponse(response);
    return Map<String, dynamic>.from(data['data'] ?? {});
  }

  // ============================================================
  // PROFILE PHOTO
  // ============================================================

  // Uploads the profile photo for the currently logged-in user.
  //
  // Backend endpoint:
  // POST /api/users/me/photo
  //
  // Multipart field:
  // photo
  //
  // The backend identifies the user from the authentication token,
  // so the Flutter app never sends a user ID for this operation.

  static Future<Map<String, dynamic>>
      uploadProfilePhoto({
    required Uint8List photoBytes,
    required String fileName,
  }) async {
    final token =
        await _requiredToken();

    if (photoBytes.isEmpty) {
      throw Exception(
        'Please select a profile photo.',
      );
    }

    if (fileName.trim().isEmpty) {
      throw Exception(
        'Profile photo file name is required.',
      );
    }

    final request =
        http.MultipartRequest(
      'POST',
      Uri.parse(
        '$baseUrl/users/me/photo',
      ),
    );

    request.headers[
            'Authorization'] =
        'Bearer $token';

    request.files.add(
      http.MultipartFile.fromBytes(
        'photo',
        photoBytes,
        filename: fileName.trim(),
      ),
    );

    final streamedResponse =
        await request.send();

    final response =
        await http.Response.fromStream(
      streamedResponse,
    );

    final data =
        await _jsonResponse(
      response,
    );

    return Map<String, dynamic>.from(
      data['data'] ?? {},
    );
  }

  static Future<void> removeProfilePhoto() async {
    final token = await _requiredToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/users/me/photo'),
      headers: {'Authorization': 'Bearer $token'},
    );
    await _jsonResponse(response);
  }

  // ============================================================
  // JSON RESPONSE
  // ============================================================

  static Future<Map<String, dynamic>>
      _jsonResponse(
    http.Response response,
  ) async {
    dynamic data;

    try {
      data = jsonDecode(
        response.body,
      );
    } catch (_) {
      throw Exception(
        'Server returned an invalid response.',
      );
    }

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      if (data is Map<String, dynamic>) {
        return data;
      }

      return <String, dynamic>{};
    }

    throw Exception(
      data is Map
          ? (data['message'] ??
                  'Request failed')
              .toString()
          : 'Request failed',
    );
  }

  // ============================================================
  // REQUIRED TOKEN
  // ============================================================

  static Future<String>
      _requiredToken() async {
    final token =
        await getToken();

    if (token == null ||
        token.isEmpty) {
      throw Exception(
        'Authentication token not found. Please login again.',
      );
    }

    return token;
  }

  // ============================================================
  // LOGIN
  // ============================================================

  static Future<Map<String, dynamic>>
      login({
    required String email,
    required String password,
  }) async {
    final response =
        await http.post(
      Uri.parse(
        '$baseUrl/auth/login',
      ),
      headers: {
        'Content-Type':
            'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    final data =
        await _jsonResponse(
      response,
    );

    final userData =
        data['data'];

    if (userData is! Map) {
      throw Exception(
        'Login response does not contain user data.',
      );
    }

    final token =
        userData['token'];

    if (token == null ||
        token
            .toString()
            .trim()
            .isEmpty) {
      throw Exception(
        'Login response does not contain an authentication token.',
      );
    }

    // ----------------------------------------------------------
    // SAVE TOKEN
    // ----------------------------------------------------------

    await saveToken(
      token.toString(),
    );

    // ----------------------------------------------------------
    // SAVE USER INFORMATION
    // ----------------------------------------------------------

    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setString(
      'logged_in_user_name',
      userData['name']
              ?.toString() ??
          '',
    );

    await prefs.setString(
      'logged_in_user_email',
      userData['email']
              ?.toString() ??
          '',
    );

    await prefs.setString(
      'logged_in_user_role',
      userData['role']
              ?.toString() ??
          '',
    );

    return data;
  }

  // ============================================================
  // ADMIN DASHBOARD
  // ============================================================

  static Future<Map<String, dynamic>> getDashboard() async {
    final token = await _requiredToken();

    final response = await http.get(
      Uri.parse('$baseUrl/dashboard'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = await _jsonResponse(response);
    return Map<String, dynamic>.from(data['data'] ?? {});
  }

  // ============================================================
  // COMPANIES
  // ============================================================

  static Future<List<dynamic>>
      getCompanies() async {
    final token =
        await _requiredToken();

    final response =
        await http.get(
      Uri.parse(
        '$baseUrl/companies',
      ),
      headers: {
        'Authorization':
            'Bearer $token',
      },
    );

    final data =
        await _jsonResponse(
      response,
    );

    return List<dynamic>.from(
      data['data'] ?? [],
    );
  }

  // ============================================================
  // CREATE COMPANY
  // ============================================================
  //
  // Sends:
  // - Company name
  // - Section
  // - Optional company logo
  //
  // Backend endpoint:
  // POST /api/companies
  //
  // Multipart field names:
  // name
  // section
  // logo
  // ============================================================

  static Future<Map<String, dynamic>>
      createCompany(
    String name, {
    String? section,
    List<String>? sections,
    String? logoFileName,
    Uint8List? logoBytes,
  }) async {
    final token =
        await _requiredToken();

    final request =
        http.MultipartRequest(
      'POST',
      Uri.parse(
        '$baseUrl/companies',
      ),
    );

    request.headers[
            'Authorization'] =
        'Bearer $token';

    request.fields[
            'name'] =
        name.trim();

    final effectiveSections =
        sections != null && sections.isNotEmpty
            ? sections
            : (section != null && section.trim().isNotEmpty
                ? [section.trim()]
                : null);

    if (effectiveSections != null &&
        effectiveSections.isNotEmpty) {
      request.fields['section'] =
          effectiveSections.join('|');
    }

    if (logoBytes != null &&
        logoBytes.isNotEmpty &&
        logoFileName != null &&
        logoFileName.trim().isNotEmpty) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'logo',
          logoBytes,
          filename: logoFileName.trim(),
        ),
      );
    }

    final streamedResponse =
        await request.send();

    final response =
        await http.Response.fromStream(
      streamedResponse,
    );

    final data =
        await _jsonResponse(
      response,
    );

    return Map<String, dynamic>.from(
      data['data'] ?? {},
    );
  }

  // ============================================================
  // UPDATE COMPANY
  // ============================================================

  static Future<Map<String, dynamic>>
      updateCompany({
    required String companyId,
    required String name,
    List<String>? sections,
  }) async {
    final token =
        await _requiredToken();

    final body = <String, dynamic>{
      'name': name,
    };

    if (sections != null && sections.isNotEmpty) {
      body['section'] = sections.join('|');
    }

    final response =
        await http.put(
      Uri.parse(
        '$baseUrl/companies/$companyId',
      ),
      headers: {
        'Content-Type':
            'application/json',
        'Authorization':
            'Bearer $token',
      },
      body: jsonEncode(body),
    );

    final data =
        await _jsonResponse(
      response,
    );

    return Map<String, dynamic>.from(
      data['data'] ?? {},
    );
  }

  // ============================================================
  // DELETE COMPANY
  // ============================================================

  static Future<void>
      deleteCompany(
    String companyId,
  ) async {
    final token =
        await _requiredToken();

    final response =
        await http.delete(
      Uri.parse(
        '$baseUrl/companies/$companyId',
      ),
      headers: {
        'Authorization':
            'Bearer $token',
      },
    );

    await _jsonResponse(
      response,
    );
  }

  // ============================================================
  // ASSETS
  // ============================================================

  static Future<List<dynamic>>
      getAssets() async {
    final token =
        await _requiredToken();

    final response =
        await http.get(
      Uri.parse(
        '$baseUrl/assets',
      ),
      headers: {
        'Authorization':
            'Bearer $token',
      },
    );

    final data =
        await _jsonResponse(
      response,
    );

    return List<dynamic>.from(
      data['data'] ?? [],
    );
  }

  // ============================================================
  // CREATE ASSET
  // ============================================================

  static Future<Map<String, dynamic>>
      createAsset({
    required String companyId,
    required String companyName,
    required String section,
    required String type,
    required String name,
    String? description,
    String? link,
    String? username,
    String? password,
    String? fileName,
    Uint8List? fileBytes,
  }) async {
    final token =
        await _requiredToken();

    final request =
        http.MultipartRequest(
      'POST',
      Uri.parse(
        '$baseUrl/assets',
      ),
    );

    request.headers[
            'Authorization'] =
        'Bearer $token';

    request.fields[
            'company_id'] =
        companyId;

    request.fields[
            'company_name'] =
        companyName;

    request.fields[
            'section'] =
        section;

    request.fields[
            'type'] =
        type;

    request.fields[
            'name'] =
        name;

    if (description != null &&
        description
            .trim()
            .isNotEmpty) {
      request.fields[
              'description'] =
          description.trim();
    }

    if (link != null &&
        link.trim().isNotEmpty) {
      request.fields['link'] =
          link.trim();
    }

    if (username != null &&
        username
            .trim()
            .isNotEmpty) {
      request.fields[
              'username'] =
          username.trim();
    }

    if (password != null &&
        password
            .trim()
            .isNotEmpty) {
      request.fields[
              'password'] =
          password.trim();
    }

    if (fileBytes != null &&
        fileBytes.isNotEmpty &&
        fileName != null &&
        fileName.isNotEmpty) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
        ),
      );
    }

    final streamed =
        await request.send();

    final response =
        await http.Response
            .fromStream(
      streamed,
    );

    final data =
        await _jsonResponse(
      response,
    );

    return Map<String, dynamic>.from(
      data['data'] ?? {},
    );
  }

  // ============================================================
  // UPDATE ASSET
  // ============================================================

  static Future<Map<String, dynamic>>
      updateAsset({
    required String assetId,
    required String companyId,
    required String companyName,
    required String section,
    required String type,
    required String name,
    String? description,
    String? link,
    String? username,
    String? password,
    String? fileName,
    Uint8List? fileBytes,
  }) async {
    final token =
        await _requiredToken();

    final request =
        http.MultipartRequest(
      'PUT',
      Uri.parse(
        '$baseUrl/assets/$assetId',
      ),
    );

    request.headers[
        'Authorization'] = 'Bearer $token';

    request.fields['company_id'] =
        companyId;
    request.fields['company_name'] =
        companyName;
    request.fields['section'] =
        section;
    request.fields['type'] =
        type;
    request.fields['name'] =
        name;

    if (description != null) {
      request.fields['description'] =
          description;
    }

    if (link != null &&
        link.trim().isNotEmpty) {
      request.fields['link'] =
          link.trim();
    }

    if (username != null &&
        username.trim().isNotEmpty) {
      request.fields['username'] =
          username.trim();
    }

    if (password != null &&
        password.trim().isNotEmpty) {
      request.fields['password'] =
          password.trim();
    }

    if (fileBytes != null &&
        fileBytes.isNotEmpty &&
        fileName != null &&
        fileName.isNotEmpty) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
        ),
      );
    }

    final streamed =
        await request.send();

    final response =
        await http.Response.fromStream(
      streamed,
    );

    final data =
        await _jsonResponse(response);

    return Map<String, dynamic>.from(
      data['data'] ?? {},
    );
  }

  // ============================================================
  // DELETE ASSET
  // ============================================================

  static Future<void>
      deleteAsset(
    String assetId,
  ) async {
    final token =
        await _requiredToken();

    final response =
        await http.delete(
      Uri.parse(
        '$baseUrl/assets/$assetId',
      ),
      headers: {
        'Authorization':
            'Bearer $token',
      },
    );

    await _jsonResponse(
      response,
    );
  }

  // ============================================================
  // DOWNLOAD ASSET
  // ============================================================

  static Future<Uint8List>
      downloadAsset(
    String assetId,
  ) async {
    final token =
        await _requiredToken();

    final response =
        await http.get(
      Uri.parse(
        '$baseUrl/assets/$assetId/file',
      ),
      headers: {
        'Authorization':
            'Bearer $token',
      },
    );

    if (response.statusCode ==
        200) {
      return response.bodyBytes;
    }

    dynamic data;

    try {
      data = jsonDecode(
        response.body,
      );
    } catch (_) {
      throw Exception(
        'Failed to download asset.',
      );
    }

    throw Exception(
      data is Map
          ? (data['message'] ??
                  'Failed to download asset')
              .toString()
          : 'Failed to download asset',
    );
  }

  // ============================================================
  // ADMIN DOWNLOAD HISTORY
  // ============================================================

  static Future<List<dynamic>> getDownloadLogs() async {
    final token = await _requiredToken();

    final response = await http.get(
      Uri.parse(
        '$baseUrl/downloads',
      ),
      headers: {
        'Authorization':
            'Bearer $token',
      },
    );

    final data = await _jsonResponse(
      response,
    );

    return List<dynamic>.from(
      data['data'] ?? [],
    );
  }

  // ============================================================
  // USERS
  // ============================================================

  static Future<List<dynamic>>
      getUsers() async {
    final token =
        await _requiredToken();

    final response =
        await http.get(
      Uri.parse(
        '$baseUrl/users',
      ),
      headers: {
        'Authorization':
            'Bearer $token',
      },
    );

    final data =
        await _jsonResponse(
      response,
    );

    return List<dynamic>.from(
      data['data'] ?? [],
    );
  }

  // ============================================================
  // CREATE USER / ADMIN
  // ============================================================

  static Future<Map<String, dynamic>>
      createUser({
    required String name,
    required String email,
    String? mobile,
    required String password,
    required String role,
  }) async {
    final token =
        await _requiredToken();

    final response =
        await http.post(
      Uri.parse(
        '$baseUrl/users',
      ),
      headers: {
        'Content-Type':
            'application/json',
        'Authorization':
            'Bearer $token',
      },
      body: jsonEncode({
        'name': name,
        'email': email,
        'mobile': mobile,
        'password': password,
        'role': role,
      }),
    );

    final data =
        await _jsonResponse(
      response,
    );

    return Map<String, dynamic>.from(
      data['data'] ?? {},
    );
  }

  // ============================================================
  // UPDATE USER
  // ============================================================

  static Future<Map<String, dynamic>>
      updateUser({
    required String userId,
    required String name,
    required String email,
    String? mobile,
    required String role,
    String? password,
  }) async {
    final token =
        await _requiredToken();

    final body =
        <String, dynamic>{
      'name': name,
      'email': email,
      'mobile': mobile,
      'role': role,
    };

    if (password != null &&
        password
            .trim()
            .isNotEmpty) {
      body['password'] =
          password;
    }

    final response =
        await http.put(
      Uri.parse(
        '$baseUrl/users/$userId',
      ),
      headers: {
        'Content-Type':
            'application/json',
        'Authorization':
            'Bearer $token',
      },
      body: jsonEncode(body),
    );

    final data =
        await _jsonResponse(
      response,
    );

    return Map<String, dynamic>.from(
      data['data'] ?? {},
    );
  }

  // ============================================================
  // CHANGE USER STATUS
  // ============================================================

  static Future<Map<String, dynamic>>
      updateUserStatus({
    required String userId,
    required bool isActive,
  }) async {
    final token =
        await _requiredToken();

    final response =
        await http.put(
      Uri.parse(
        '$baseUrl/users/$userId/status',
      ),
      headers: {
        'Content-Type':
            'application/json',
        'Authorization':
            'Bearer $token',
      },
      body: jsonEncode({
        'is_active':
            isActive,
      }),
    );

    final data =
        await _jsonResponse(
      response,
    );

    return Map<String, dynamic>.from(
      data['data'] ?? {},
    );
  }

  // ============================================================
  // DELETE USER
  // ============================================================

  static Future<void>
      deleteUser(
    String userId,
  ) async {
    final token =
        await _requiredToken();

    final response =
        await http.delete(
      Uri.parse(
        '$baseUrl/users/$userId',
      ),
      headers: {
        'Authorization':
            'Bearer $token',
      },
    );

    await _jsonResponse(
      response,
    );
  }

  // ============================================================
  // USER-WISE PERMISSIONS
  // ============================================================

  // IMPORTANT:
  //
  // Permissions are USER-WISE.
  //
  // There is NO company selection.
  //
  // Every active User gets one permission configuration.
  //
  // Permissions:
  //
  // View              -> can_view
  // Download          -> can_download
  // Add Asset         -> can_create
  // Edit              -> can_edit
  // Delete            -> can_delete
  // Add Company       -> can_create_company
  //
  // The backend applies the selected user's permissions
  // to all companies.

  // ============================================================
  // GET MY PERMISSIONS
  // ============================================================
  //
  // GET /api/permissions/me
  //
  // Returns permissions for the currently logged-in user.
  //
  // Admin:
  //   All permissions are TRUE.
  //
  // User:
  //   Returns permissions configured by Admin.
  //
  // ============================================================

  static Future<Map<String, dynamic>>
      getMyPermissions() async {
    final token =
        await _requiredToken();

    final response =
        await http.get(
      Uri.parse(
        '$baseUrl/permissions/me',
      ),
      headers: {
        'Authorization':
            'Bearer $token',
      },
    );

    final data =
        await _jsonResponse(
      response,
    );

    return Map<String, dynamic>.from(
      data['data'] ?? {},
    );
  }

  // ============================================================
  // GET ALL USER PERMISSIONS
  // ============================================================
  //
  // GET /api/permissions
  //
  // Returns one row per active User.

  static Future<List<dynamic>>
      getPermissions() async {
    final token =
        await _requiredToken();

    final response =
        await http.get(
      Uri.parse(
        '$baseUrl/permissions',
      ),
      headers: {
        'Authorization':
            'Bearer $token',
      },
    );

    final data =
        await _jsonResponse(
      response,
    );

    return List<dynamic>.from(
      data['data'] ?? [],
    );
  }

  // ============================================================
  // GET ONE USER'S PERMISSIONS
  // ============================================================

  // GET /api/permissions/user/:userId

  static Future<Map<String, dynamic>>
      getUserPermissions(
    String userId,
  ) async {
    final token =
        await _requiredToken();

    final response =
        await http.get(
      Uri.parse(
        '$baseUrl/permissions/user/$userId',
      ),
      headers: {
        'Authorization':
            'Bearer $token',
      },
    );

    final data =
        await _jsonResponse(
      response,
    );

    return Map<String, dynamic>.from(
      data['data'] ?? {},
    );
  }

  // ============================================================
  // UPDATE USER-WISE PERMISSIONS
  // ============================================================

  // PUT /api/permissions/user/:userId
  //
  // NO companyId.
  //
  // The selected user's permissions are applied to
  // all companies.

  static Future<Map<String, dynamic>>
      updateUserPermissions({
    required String userId,
    required bool canView,
    required bool canCreate,
    required bool canEdit,
    required bool canDelete,
    required bool canDownload,
    required bool canCreateCompany,
  }) async {
    final token =
        await _requiredToken();

    final response =
        await http.put(
      Uri.parse(
        '$baseUrl/permissions/user/$userId',
      ),
      headers: {
        'Content-Type':
            'application/json',
        'Authorization':
            'Bearer $token',
      },
      body: jsonEncode({
        'can_view':
            canView,
        'can_create':
            canCreate,
        'can_edit':
            canEdit,
        'can_delete':
            canDelete,
        'can_download':
            canDownload,
        'can_create_company':
            canCreateCompany,
      }),
    );

    final data =
        await _jsonResponse(
      response,
    );

    return Map<String, dynamic>.from(
      data['data'] ?? {},
    );
  }

  // ============================================================
  // COMPATIBILITY METHOD
  // ============================================================

  // Kept so older Flutter screens that still call
  // updatePermission() do not produce a compile error.
  //
  // companyId is intentionally ignored.
  //
  // canCreateCompany is optional here for compatibility.
  //
  // Older screens that do not yet provide Add Company
  // permission will keep it OFF.

  static Future<Map<String, dynamic>>
      updatePermission({
    required String userId,
    required String companyId,
    required bool canView,
    required bool canCreate,
    required bool canEdit,
    required bool canDelete,
    required bool canDownload,
    bool canCreateCompany = false,
  }) async {
    return updateUserPermissions(
      userId: userId,
      canView: canView,
      canCreate: canCreate,
      canEdit: canEdit,
      canDelete: canDelete,
      canDownload: canDownload,
      canCreateCompany:
          canCreateCompany,
    );
  }

  // ============================================================
  // DELETE PERMISSION
  // ============================================================

  // Permissions are not deleted.
  //
  // Turn the required permission OFF instead.

  static Future<void>
      deletePermission({
    required String userId,
    required String companyId,
  }) async {
    throw Exception(
      'Permission deletion is not used. Turn the required permission OFF instead.',
    );
  }
  // ============================================================
  // FORGOT PASSWORD
  // ============================================================

  static Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/forgot-password'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
      }),
    );

    return _jsonResponse(response);
  }

  // ============================================================
  // VERIFY RESET OTP
  // ============================================================

  static Future<Map<String, dynamic>> verifyResetOtp({
    required String email,
    required String otp,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/verify-reset-otp'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'otp': otp,
      }),
    );

    return _jsonResponse(response);
  }

  // ============================================================
  // RESET PASSWORD
  // ============================================================

  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/reset-password'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'otp': otp,
        'newPassword': newPassword,
      }),
    );

    return _jsonResponse(response);
  }

  // ============================================================
  // ADMIN NOTIFICATIONS
  // ============================================================

  static Future<List<dynamic>> getNotifications({
    int limit = 20,
  }) async {
    final token = await _requiredToken();

    final safeLimit = limit.clamp(1, 100);

    final response = await http.get(
      Uri.parse(
        '$baseUrl/notifications?limit=$safeLimit',
      ),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    final data = await _jsonResponse(response);

    return List<dynamic>.from(
      data['data'] ?? [],
    );
  }

  static Future<int> getUnreadNotificationCount() async {
    final token = await _requiredToken();

    final response = await http.get(
      Uri.parse(
        '$baseUrl/notifications/unread-count',
      ),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    final data = await _jsonResponse(response);
    final result = data['data'];

    if (result is Map) {
      return int.tryParse(
            result['unread_count']?.toString() ?? '0',
          ) ??
          0;
    }

    return 0;
  }

  static Future<void> markNotificationAsRead(
    String notificationId,
  ) async {
    final token = await _requiredToken();

    final response = await http.put(
      Uri.parse(
        '$baseUrl/notifications/$notificationId/read',
      ),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    await _jsonResponse(response);
  }

  static Future<void> markAllNotificationsAsRead() async {
    final token = await _requiredToken();

    final response = await http.put(
      Uri.parse(
        '$baseUrl/notifications/read-all',
      ),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    await _jsonResponse(response);
  }

}
