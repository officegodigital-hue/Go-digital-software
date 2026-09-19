import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class AdminSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final VoidCallback onLogout;

  const AdminSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.white,
      child: Column(
        children: [
          _buildLogo(),

          const SizedBox(height: 20),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
              ),
              child: Column(
                children: [
                  _buildMenuItem(
                    icon: Icons.dashboard_outlined,
                    selectedIcon: Icons.dashboard_rounded,
                    title: 'Dashboard',
                    index: 0,
                    onTap: () {
                      onItemSelected(0);
                    },
                  ),

                  _buildMenuItem(
                    icon: Icons.folder_outlined,
                    selectedIcon: Icons.folder_rounded,
                    title: 'Asset Manager',
                    index: 1,
                    onTap: () {
                      onItemSelected(1);
                    },
                  ),

                  _buildMenuItem(
                    icon: Icons.people_outline,
                    selectedIcon: Icons.people_rounded,
                    title: 'Users',
                    index: 2,
                    onTap: () {
                      onItemSelected(2);
                    },
                  ),

                  _buildMenuItem(
                    icon: Icons.admin_panel_settings_outlined,
                    selectedIcon:
                        Icons.admin_panel_settings_rounded,
                    title: 'Permissions',
                    index: 3,
                    onTap: () {
                      onItemSelected(3);
                    },
                  ),

                  // ==================================================
                  // DOWNLOAD HISTORY
                  // ==================================================

                  _buildMenuItem(
                    icon: Icons.download_outlined,
                    selectedIcon: Icons.download_rounded,
                    title: 'Downloads',
                    index: 4,
                    onTap: () {
                      onItemSelected(4);
                    },
                  ),
                ],
              ),
            ),
          ),

          const Divider(
            height: 1,
            color: AppColors.border,
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: _buildLogoutButton(context),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ADMIN LOGO
  // ============================================================

  Widget _buildLogo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        24,
        20,
        8,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/client_work_repository/client_logo.png',
              width: 48,
              height: 48,
              fit: BoxFit.contain,
            ),
          ),

          const SizedBox(width: 12),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Go Digital',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),

                SizedBox(height: 2),

                Text(
                  'Admin Portal',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MENU ITEM
  // ============================================================

  Widget _buildMenuItem({
    required IconData icon,
    required IconData selectedIcon,
    required String title,
    required int index,
    required VoidCallback onTap,
  }) {
    final selected = selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 5,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.09)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? selectedIcon : icon,
                  size: 21,
                  color: selected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),

                const SizedBox(width: 13),

                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // LOGOUT BUTTON
  // ============================================================

  Widget _buildLogoutButton(
    BuildContext context,
  ) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: () {
          _showLogoutConfirmation(context);
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          child: const Row(
            children: [
              Icon(
                Icons.logout_outlined,
                size: 21,
                color: AppColors.danger,
              ),

              SizedBox(width: 13),

              Text(
                'Logout',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // LOGOUT CONFIRMATION
  // ============================================================

  Future<void> _showLogoutConfirmation(
    BuildContext context,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Logout',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            'Are you sure you want to logout?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text(
                'Logout',
              ),
            ),
          ],
        );
      },
    );

    if (result == true) {
      onLogout();
    }
  }
}
