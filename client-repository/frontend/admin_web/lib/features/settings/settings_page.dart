import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../services/settings_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SettingsService settingsService = SettingsService();

  final TextEditingController adminNameController = TextEditingController();
  final TextEditingController adminEmailController = TextEditingController();
  final TextEditingController adminPasswordController = TextEditingController();

  final TextEditingController mobileUsernameController =
      TextEditingController();
  final TextEditingController mobilePasswordController =
      TextEditingController();

  bool isLoading = true;
  bool isSavingAdmin = false;
  bool isSavingMobile = false;
  bool isRemovingDevice = false;

  List<Map<String, dynamic>> mobileSessions = [];

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  @override
  void dispose() {
    adminNameController.dispose();
    adminEmailController.dispose();
    adminPasswordController.dispose();
    mobileUsernameController.dispose();
    mobilePasswordController.dispose();
    super.dispose();
  }

  Future<void> loadSettings() async {
    try {
      final data = await settingsService.getSettings();

      final admin = Map<String, dynamic>.from(data['admin'] ?? {});
      final mobileApp = Map<String, dynamic>.from(data['mobile_app'] ?? {});
      final sessions = List<dynamic>.from(data['mobile_sessions'] ?? []);

      adminNameController.text = admin['name']?.toString() ?? 'Admin User';
      adminEmailController.text =
          admin['email']?.toString() ?? 'admin@godigital.com';

      mobileUsernameController.text =
          mobileApp['app_username']?.toString() ?? 'client@godigital.com';

      mobileSessions = sessions
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (error) {
      showMessage(error.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> refreshMobileDevices() async {
    try {
      final sessions = await settingsService.getMobileSessions();

      if (mounted) {
        setState(() {
          mobileSessions = sessions
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        });
      }
    } catch (error) {
      showMessage(error.toString(), isError: true);
    }
  }

  Future<void> saveAdminProfile() async {
    setState(() {
      isSavingAdmin = true;
    });

    try {
      await settingsService.updateAdminProfile(
        name: adminNameController.text.trim(),
        email: adminEmailController.text.trim(),
        password: adminPasswordController.text.trim(),
      );

      adminPasswordController.clear();

      showMessage('Admin login updated successfully');
    } catch (error) {
      showMessage(error.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isSavingAdmin = false;
        });
      }
    }
  }

  Future<void> saveMobileCredentials() async {
    setState(() {
      isSavingMobile = true;
    });

    try {
      await settingsService.updateMobileCredentials(
        username: mobileUsernameController.text.trim(),
        password: mobilePasswordController.text.trim(),
      );

      mobilePasswordController.clear();

      showMessage('Mobile app login updated successfully');
    } catch (error) {
      showMessage(error.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isSavingMobile = false;
        });
      }
    }
  }

  Future<void> removeSingleDevice(int id) async {
    setState(() {
      isRemovingDevice = true;
    });

    try {
      await settingsService.removeMobileSession(id);
      await refreshMobileDevices();
      showMessage('Mobile device removed successfully');
    } catch (error) {
      showMessage(error.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isRemovingDevice = false;
        });
      }
    }
  }

  Future<void> removeAllDevices() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove all devices?'),
          content: const Text(
            'This will remove all active mobile app devices from the admin panel.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text(
                'Remove All',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      isRemovingDevice = true;
    });

    try {
      await settingsService.removeAllMobileSessions();
      await refreshMobileDevices();
      showMessage('All mobile devices removed successfully');
    } catch (error) {
      showMessage(error.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isRemovingDevice = false;
        });
      }
    }
  }

  void showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void goTo(String route) {
    Navigator.pushReplacementNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          sidebar(),
          Expanded(
            child: Column(
              children: [
                topBar(),
                Expanded(
                  child: isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      : settingsContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget sidebar() {
    return Container(
      width: 212,
      color: AppColors.navy,
      child: Column(
        children: [
          const SizedBox(height: 34),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.cloud_upload_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Go Digital',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Admin CWR',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 56),
          sidebarItem(
            icon: Icons.cloud_upload_outlined,
            title: 'Asset Upload',
            selected: false,
            onTap: () => goTo('/asset-upload'),
          ),
          sidebarItem(
            icon: Icons.folder_outlined,
            title: 'Repository',
            selected: false,
            onTap: () => goTo('/repository'),
          ),
          sidebarItem(
            icon: Icons.settings_outlined,
            title: 'Setting',
            selected: true,
            onTap: () {},
          ),
          const Spacer(),
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.18),
          ),
          sidebarItem(
            icon: Icons.logout,
            title: 'LogOut',
            selected: false,
            onTap: () => goTo('/login'),
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  Widget sidebarItem({
    required IconData icon,
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        color: selected ? Colors.white : Colors.transparent,
        child: Row(
          children: [
            Icon(
              icon,
              size: 19,
              color: selected ? AppColors.primary : Colors.white,
            ),
            const SizedBox(width: 14),
            Text(
              title,
              style: TextStyle(
                color: selected ? AppColors.primary : Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget topBar() {
    return Container(
      height: 88,
      color: AppColors.navy,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        children: [
          SizedBox(
            width: 340,
            height: 36,
            child: TextField(
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(
                  Icons.search,
                  size: 18,
                  color: AppColors.textGrey,
                ),
                hintText: 'Search assets, clients, or projects...',
                hintStyle: const TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 12,
                ),
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          const Spacer(),
          const Icon(
            Icons.notifications_none,
            color: Colors.white,
            size: 22,
          ),
          const SizedBox(width: 24),
          const Icon(
            Icons.help_outline,
            color: Colors.white,
            size: 22,
          ),
          const SizedBox(width: 22),
          Container(
            width: 1,
            height: 28,
            color: Colors.white.withValues(alpha: 0.25),
          ),
          const SizedBox(width: 22),
          const CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.person,
              color: AppColors.navy,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Admin User',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget settingsContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(40, 30, 40, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Settings',
            style: TextStyle(
              color: AppColors.textDark,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Manage admin login, mobile app login, and connected mobile devices.',
            style: TextStyle(
              color: AppColors.textGrey,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: adminLoginCard()),
              const SizedBox(width: 20),
              Expanded(child: mobileAppLoginCard()),
            ],
          ),
          const SizedBox(height: 20),
          mobileDevicesCard(),
        ],
      ),
    );
  }

  Widget adminLoginCard() {
    return card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle(
            icon: Icons.admin_panel_settings_outlined,
            title: 'Admin Login Details',
          ),
          const SizedBox(height: 24),
          inputField(
            label: 'ADMIN NAME',
            controller: adminNameController,
          ),
          const SizedBox(height: 14),
          inputField(
            label: 'ADMIN EMAIL / USERNAME',
            controller: adminEmailController,
          ),
          const SizedBox(height: 14),
          inputField(
            label: 'NEW PASSWORD',
            controller: adminPasswordController,
            obscureText: true,
            hintText: 'Leave empty to keep old password',
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: primaryButton(
              title: isSavingAdmin ? 'Saving...' : 'Save Admin Login',
              onPressed: isSavingAdmin ? null : saveAdminProfile,
            ),
          ),
        ],
      ),
    );
  }

  Widget mobileAppLoginCard() {
    return card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle(
            icon: Icons.phone_android,
            title: 'Mobile App Login',
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FB),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.qr_code_2,
                  color: AppColors.primary,
                  size: 78,
                ),
              ),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  children: [
                    inputField(
                      label: 'MOBILE APP USERNAME',
                      controller: mobileUsernameController,
                    ),
                    const SizedBox(height: 14),
                    inputField(
                      label: 'MOBILE APP PASSWORD',
                      controller: mobilePasswordController,
                      obscureText: true,
                      hintText: 'Leave empty to keep old password',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: primaryButton(
              title: isSavingMobile ? 'Saving...' : 'Save Mobile Login',
              onPressed: isSavingMobile ? null : saveMobileCredentials,
            ),
          ),
        ],
      ),
    );
  }

  Widget mobileDevicesCard() {
    return card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              sectionTitle(
                icon: Icons.devices,
                title: 'Mobile App Devices',
              ),
              const Spacer(),
              countBadge('${mobileSessions.length} Active Device(s)'),
              const SizedBox(width: 12),
              secondaryButton(
                title: 'Refresh',
                icon: Icons.refresh,
                onPressed: isRemovingDevice ? null : refreshMobileDevices,
              ),
              const SizedBox(width: 12),
              dangerButton(
                title: 'Remove All',
                onPressed: mobileSessions.isEmpty || isRemovingDevice
                    ? null
                    : removeAllDevices,
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (mobileSessions.isEmpty)
            emptyDevices()
          else
            Column(
              children: mobileSessions.map(deviceTile).toList(),
            ),
        ],
      ),
    );
  }

  Widget deviceTile(Map<String, dynamic> device) {
    final id = int.tryParse(device['id'].toString()) ?? 0;
    final deviceName = device['device_name']?.toString() ?? 'Unknown Device';
    final deviceType = device['device_type']?.toString() ?? 'Mobile App';
    final deviceId = device['device_id']?.toString() ?? '-';
    final lastActive = device['last_active']?.toString() ?? '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(
              Icons.phone_android,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deviceName,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$deviceType  •  Last active: $lastActive',
                  style: const TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Device ID: $deviceId',
                  style: const TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: isRemovingDevice || id == 0
                ? null
                : () => removeSingleDevice(id),
            icon: const Icon(
              Icons.delete_outline,
              size: 17,
              color: Colors.red,
            ),
            label: const Text(
              'Remove',
              style: TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget emptyDevices() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.phone_android,
            color: AppColors.textGrey,
            size: 36,
          ),
          SizedBox(height: 10),
          Text(
            'No active mobile devices found',
            style: TextStyle(
              color: AppColors.textGrey,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: child,
    );
  }

  Widget sectionTitle({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppColors.primary,
          size: 18,
        ),
        const SizedBox(width: 14),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textDark,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget inputField({
    required String label,
    required TextEditingController controller,
    bool obscureText = false,
    String? hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textGrey,
            fontSize: 11,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        SizedBox(
          height: 36,
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 12,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(
                color: AppColors.textGrey,
                fontSize: 11,
              ),
              filled: true,
              fillColor: AppColors.inputFill,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              border: OutlineInputBorder(
                borderSide: const BorderSide(color: AppColors.border),
                borderRadius: BorderRadius.circular(0),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: AppColors.border),
                borderRadius: BorderRadius.circular(0),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: AppColors.primary),
                borderRadius: BorderRadius.circular(0),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget primaryButton({
    required String title,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 36,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(0),
          ),
        ),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget secondaryButton({
    required String title,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 34,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(title),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          textStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget dangerButton({
    required String title,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 34,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          disabledBackgroundColor: Colors.red.withValues(alpha: 0.25),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget countBadge(String title) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}