import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../services/api_config.dart';
import '../services/auth_service.dart';
import 'assets_module/features/admin/asset_manager/asset_manager_page.dart';
import 'assets_module/features/admin/dashboard/dashboard_page.dart';
import 'assets_module/features/admin/downloads/downloads_page.dart';
import 'assets_module/features/admin/permissions/permissions_page.dart';
import 'assets_module/features/admin/users/users_page.dart';
import 'assets_module/layouts/admin_layout.dart';
import 'assets_module/layouts/user_layout.dart';

/// Opens the original Assets source page based on the signed GoDigital token.
/// Admins get Asset Manager; employees get Asset Library only.
class ClientWorkRepositoryPage extends StatefulWidget {
  const ClientWorkRepositoryPage({super.key});

  @override
  State<ClientWorkRepositoryPage> createState() =>
      _ClientWorkRepositoryPageState();
}

class _ClientWorkRepositoryPageState extends State<ClientWorkRepositoryPage> {
  Future<bool>? _isAdmin;
  String? _roleToken;

  bool _hasAdminAccess(Map<String, dynamic>? user) {
    if (user == null) return false;

    final userType = user['userType']?.toString().trim().toLowerCase() ?? '';
    final role = user['role']?.toString().trim().toLowerCase() ?? '';
    final mainAdmin = user['is_main_admin'];
    final isMainAdmin = mainAdmin == true || mainAdmin == 1 || mainAdmin == '1';

    if (userType == 'admin' || role == 'admin' || isMainAdmin) return true;

    final rawAccess = user['application_access'];
    if (rawAccess is! Map) return false;

    final repositoryAccess = rawAccess['client_repository'];
    if (repositoryAccess is Map) {
      return repositoryAccess['access_type']?.toString().toLowerCase() ==
          'admin';
    }

    return false;
  }

  Future<bool> _loadUserType({
    required String token,
    required bool hasCachedAdminAccess,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/auth/me'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return false;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      final userType = data?['userType']?.toString().trim().toLowerCase() ?? '';
      final role = data?['role']?.toString().trim().toLowerCase() ?? '';
      // Accept either userType=='admin' or role=='admin' (covers older JWT tokens
      // that may not carry userType in their payload).
      if (userType == 'admin' || role == 'admin') return true;
      // If API returned 200 but neither field says admin, trust the response.
      if (userType.isNotEmpty || role.isNotEmpty) return hasCachedAdminAccess;
      // Fields were both empty — fall back to cached value.
      return hasCachedAdminAccess;
    } catch (_) {
      // Use the existing cached login only if the local server is unavailable.
      return hasCachedAdminAccess;
    }
  }

  @override
  Widget build(BuildContext context) => Consumer<AuthService>(
    builder: (context, auth, _) {
      if (!auth.isInitialized) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }

      final token = auth.token;
      if (token == null || token.isEmpty) {
        return _buildUserLayout(context);
      }

      if (_roleToken != token || _isAdmin == null) {
        _roleToken = token;
        _isAdmin = _loadUserType(
          token: token,
          hasCachedAdminAccess: _hasAdminAccess(auth.user),
        );
      }

      return FutureBuilder<bool>(
        future: _isAdmin,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.data == true) {
            return AdminLayout(
              onLogout: () async {
                await context.read<AuthService>().logout();
                if (context.mounted) {
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/', (route) => false);
                }
              },
              childBuilder: (index, onNavigate) {
                switch (index) {
                  case 0:
                    return const AssetManagerPage();
                  case 1:
                    return const UsersPage();
                  case 2:
                    return const PermissionsPage();
                  case 3:
                    return const AdminDownloadsPage();
                  default:
                    return const AssetManagerPage();
                }
              },
            );
          }
          return _buildUserLayout(context);
        },
      );
    },
  );

  Widget _buildUserLayout(BuildContext context) => UserLayout(
    onLogout: () async {
      await context.read<AuthService>().logout();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    },
  );
}
