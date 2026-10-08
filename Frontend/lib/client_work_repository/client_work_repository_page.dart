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
  late final Future<bool> _isAdmin = _loadUserType();

  Future<bool> _loadUserType() async {
    final token = context.read<AuthService>().token;
    if (token == null || token.isEmpty) return false;

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/auth/me'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return false;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      final userType = data?['userType']?.toString().trim().toLowerCase() ?? '';
      final role = data?['role']?.toString().trim().toLowerCase() ?? '';
      // Accept either userType=='admin' or role=='admin' (covers older JWT tokens
      // that may not carry userType in their payload).
      if (userType == 'admin' || role == 'admin') return true;
      // If API returned 200 but neither field says admin, trust the response.
      if (userType.isNotEmpty || role.isNotEmpty) return false;
      // Fields were both empty — fall back to cached value.
      return context.read<AuthService>().userType?.trim().toLowerCase() ==
          'admin';
    } catch (_) {
      // Use the existing cached login only if the local server is unavailable.
      return context.read<AuthService>().userType?.trim().toLowerCase() ==
          'admin';
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
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
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil('/', (route) => false);
                }
              },
              childBuilder: (index, onNavigate) {
                switch (index) {
                  case 0:
                    return AdminDashboardPage(
                      onOpenAssets: () => onNavigate(1),
                    );
                  case 1:
                    return const AssetManagerPage();
                  case 2:
                    return const UsersPage();
                  case 3:
                    return const PermissionsPage();
                  case 4:
                    return const AdminDownloadsPage();
                  default:
                    return const AssetManagerPage();
                }
              },
            );
          }
          return UserLayout(
            onLogout: () async {
              await context.read<AuthService>().logout();
              if (context.mounted) {
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
          );
        },
      );
}
