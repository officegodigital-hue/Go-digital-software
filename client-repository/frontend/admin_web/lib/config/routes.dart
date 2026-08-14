import 'package:flutter/material.dart';

import '../features/auth/login_page.dart';
import '../features/asset_upload/asset_upload_page.dart';
import '../features/repository/repository_page.dart';
import '../features/settings/settings_page.dart';

class AppRoutes {
  static const String login = '/login';
  static const String assetUpload = '/asset-upload';
  static const String repository = '/repository';
  static const String settings = '/settings';

  static Map<String, WidgetBuilder> routes = {
    login: (context) => const LoginPage(),
    assetUpload: (context) => const AssetUploadPage(),
    repository: (context) => const RepositoryPage(),
    settings: (context) => const SettingsPage(),
  };
}