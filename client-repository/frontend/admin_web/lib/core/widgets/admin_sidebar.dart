import 'package:flutter/material.dart';

import '../../config/routes.dart';
import '../constants/app_colors.dart';

class AdminSidebar extends StatelessWidget {
  final String selectedMenu;

  const AdminSidebar({
    super.key,
    required this.selectedMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 224,
      color: AppColors.navy,
      child: Column(
        children: [
          const SizedBox(height: 38),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: const Icon(
                    Icons.cloud_upload,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Go Digital',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Admin CWR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 52),

          _menuItem(
            context,
            icon: Icons.cloud_upload_outlined,
            title: 'Asset Upload',
            keyName: 'asset',
            route: AppRoutes.assetUpload,
          ),

          _menuItem(
            context,
            icon: Icons.folder_copy_outlined,
            title: 'Repository',
            keyName: 'repository',
            route: AppRoutes.repository,
          ),

          _menuItem(
            context,
            icon: Icons.settings_outlined,
            title: 'Settings',
            keyName: 'settings',
            route: AppRoutes.settings,
          ),

          const Spacer(),

          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.35),
          ),

          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 22),
            leading: const Icon(
              Icons.logout,
              color: Colors.white,
              size: 20,
            ),
            title: const Text(
              'LogOut',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            onTap: () {
              Navigator.pushReplacementNamed(context, AppRoutes.login);
            },
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _menuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String keyName,
    required String route,
  }) {
    final bool active = selectedMenu == keyName;

    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
      child: InkWell(
        onTap: () {
          if (!active) {
            Navigator.pushReplacementNamed(context, route);
          }
        },
        child: Container(
          height: 36,
          color: active ? Colors.white : Colors.transparent,
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(
                icon,
                size: 18,
                color: active ? AppColors.primary : Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: active ? AppColors.primary : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (active)
                Container(
                  width: 10,
                  height: 36,
                  color: AppColors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}