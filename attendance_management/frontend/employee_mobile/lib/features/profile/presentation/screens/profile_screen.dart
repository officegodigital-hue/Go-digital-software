import 'package:employee_mobile/features/attendance/presentation/screens/attendance_history_screen.dart';
import 'package:employee_mobile/features/authentication/data/repositories/auth_repository.dart';
import 'package:employee_mobile/features/authentication/presentation/screens/login_screen.dart';
import 'package:employee_mobile/features/leave/presentation/controllers/leave_controller.dart';
import 'package:employee_mobile/features/leave/presentation/screens/leave_dashboard_screen.dart';
import 'package:employee_mobile/features/notifications/presentation/screens/notification_screen.dart';
import 'package:employee_mobile/features/profile/presentation/controllers/profile_controller.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() {
    return _ProfileScreenState();
  }
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _primaryBlue = Color(0xFF0867DB);
  static const Color _darkText = Color(0xFF102A4C);
  static const Color _mutedText = Color(0xFF667085);
  static const Color _borderColor = Color(0xFFDCE3EE);
  static const Color _backgroundColor = Color(0xFFF8FAFD);
  static const Color _dangerColor = Color(0xFFD92D20);

  late final ProfileController _profileController;
  late final LeaveController _leaveController;
  late final AuthRepository _authRepository;

  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();

    _profileController = ProfileController();
    _leaveController = LeaveController();
    _authRepository = AuthRepository();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _profileController.initialize();
    });
  }

  @override
  void dispose() {
    _profileController.dispose();
    _leaveController.dispose();

    super.dispose();
  }
  Future<void> _openProfile() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return const ProfileScreen();
        },
      ),
    );
  }
  Future<void> _refreshProfile() async {
    final success = await _profileController.refreshProfile();

    if (!mounted) {
      return;
    }

    if (!success) {
      _showMessage(
        _profileController.errorMessage ?? 'Unable to refresh profile.',
        isError: true,
      );

      _profileController.clearMessages();

      return;
    }

    _showMessage(
      _profileController.successMessage ?? 'Profile refreshed successfully.',
    );

    _profileController.clearMessages();
  }

  Future<void> _openAttendance() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return const AttendanceHistoryScreen();
        },
      ),
    );
  }

  Future<void> _openLeave() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return LeaveDashboardScreen(controller: _leaveController);
        },
      ),
    );
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return const NotificationScreen();
        },
      ),
    );
  }

  Future<void> _handleBottomNavigation(int index) async {
    switch (index) {
      case 0:
        Navigator.of(context).popUntil((Route<dynamic> route) {
          return route.isFirst;
        });
        break;

      case 1:
        await _openAttendance();
        break;

      case 2:
        await _openLeave();
        break;

      case 3:
        await _openNotifications();
        break;

      case 4:
       await _openProfile();
        break;
    }
  }

  Future<void> _confirmLogout() async {
    if (_isLoggingOut) {
      return;
    }

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Row(
            children: <Widget>[
              CircleAvatar(
                backgroundColor: Color(0xFFFFE8E8),
                child: Icon(Icons.logout_rounded, color: _dangerColor),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Logout',
                  style: TextStyle(
                    color: _darkText,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to log out of your employee account?',
            style: TextStyle(
              color: Color(0xFF475467),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _dangerColor),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true || !mounted) {
      return;
    }

    await _logout();
  }

  Future<void> _logout() async {
    if (_isLoggingOut) {
      return;
    }

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await _authRepository.logout();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (BuildContext context) {
            return const LoginScreen();
          },
        ),
        (Route<dynamic> route) {
          return false;
        },
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoggingOut = false;
      });

      _showMessage('Unable to logout: $error', isError: true);
    }
  }

  void _showPlaceholder(String feature) {
    _showMessage('$feature will be connected next.');
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _profileController,
      builder: (BuildContext context, Widget? child) {
        return Scaffold(
          backgroundColor: _backgroundColor,
          appBar: _buildAppBar(),
          body: RefreshIndicator(
            onRefresh: _refreshProfile,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
              children: <Widget>[
                if (_profileController.isLoading)
                  _buildLoadingState()
                else if (_profileController.hasError &&
                    !_profileController.hasProfile)
                  _buildErrorState()
                else ...<Widget>[
                  _buildProfileHeader(),
                  const SizedBox(height: 16),
                  _buildEmployeeInformation(),
                  const SizedBox(height: 16),
                  _buildAccountSettings(),
                  const SizedBox(height: 16),
                  _buildSupportSection(),
                  const SizedBox(height: 18),
                  _buildLogoutButton(),
                  const SizedBox(height: 18),
                  const Center(
                    child: Text(
                      'TimeTrack Pro Employee App',
                      style: TextStyle(
                        color: _mutedText,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Center(
                    child: Text(
                      'Version 1.0.0',
                      style: TextStyle(color: Color(0xFF98A2B3), fontSize: 9),
                    ),
                  ),
                ],
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomNavigationBar(),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: const Text(
        'Profile',
        style: TextStyle(
          color: Color(0xFF0757B8),
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      actions: <Widget>[
        IconButton(
          tooltip: 'Refresh profile',
          onPressed: _profileController.isBusy ? null : _refreshProfile,
          icon: const Icon(Icons.refresh_rounded, color: _primaryBlue),
        ),
        const SizedBox(width: 6),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFFE4E8EF)),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 150),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildErrorState() {
    return Container(
      margin: const EdgeInsets.only(top: 30),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFCCCC)),
      ),
      child: Column(
        children: <Widget>[
          const Icon(
            Icons.error_outline_rounded,
            color: _dangerColor,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            _profileController.errorMessage ??
                'Unable to load employee profile.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF8A1C17),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              _profileController.loadProfile();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF075BCF), Color(0xFF0A70E6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _primaryBlue.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          _buildProfileAvatar(),
          const SizedBox(height: 12),
          Text(
            _profileController.displayName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _profileController.designation,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: Text(
              'Employee ID: '
              '${_profileController.employeeCode}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar() {
    final imageUrl = _profileController.profileImageUrl;

    return Container(
      width: 88,
      height: 88,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: imageUrl.isEmpty
            ? _buildInitialsAvatar()
            : Image.network(
                imageUrl,
                width: 82,
                height: 82,
                fit: BoxFit.cover,
                errorBuilder:
                    (
                      BuildContext context,
                      Object error,
                      StackTrace? stackTrace,
                    ) {
                      return _buildInitialsAvatar();
                    },
              ),
      ),
    );
  }

  Widget _buildInitialsAvatar() {
    return Container(
      color: const Color(0xFFEAF2FF),
      alignment: Alignment.center,
      child: Text(
        _profileController.initials,
        style: const TextStyle(
          color: _primaryBlue,
          fontSize: 25,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildEmployeeInformation() {
    return _ProfileSection(
      title: 'Employee Information',
      children: <Widget>[
        _ProfileInformationRow(
          icon: Icons.email_outlined,
          label: 'Email Address',
          value: _profileController.email,
        ),
        const Divider(height: 1, color: _borderColor),
        _ProfileInformationRow(
          icon: Icons.phone_outlined,
          label: 'Mobile Number',
          value: _profileController.phone,
        ),
        const Divider(height: 1, color: _borderColor),
        _ProfileInformationRow(
          icon: Icons.badge_outlined,
          label: 'Role',
          value: _profileController.role,
        ),
        const Divider(height: 1, color: _borderColor),
        _ProfileInformationRow(
          icon: Icons.business_outlined,
          label: 'Company',
          value: _profileController.company,
        ),
        const Divider(height: 1, color: _borderColor),
        _ProfileInformationRow(
          icon: Icons.groups_outlined,
          label: 'Department',
          value: _profileController.department,
        ),
        const Divider(height: 1, color: _borderColor),
        _ProfileInformationRow(
          icon: Icons.location_city_outlined,
          label: 'Branch',
          value: _profileController.branch,
        ),
        const Divider(height: 1, color: _borderColor),
        _ProfileInformationRow(
          icon: Icons.calendar_today_outlined,
          label: 'Date of Joining',
          value: _profileController.joiningDate,
        ),
      ],
    );
  }

  Widget _buildAccountSettings() {
    return _ProfileSection(
      title: 'Account Settings',
      children: <Widget>[
        _ProfileActionRow(
          icon: Icons.edit_outlined,
          title: 'Edit Profile',
          subtitle: 'Update your personal information',
          onTap: () {
            _showPlaceholder('Edit Profile');
          },
        ),
        const Divider(height: 1, color: _borderColor),
        _ProfileActionRow(
          icon: Icons.lock_outline_rounded,
          title: 'Change Password',
          subtitle: 'Update your account password',
          onTap: () {
            _showPlaceholder('Change Password');
          },
        ),
        const Divider(height: 1, color: _borderColor),
        _ProfileActionRow(
          icon: Icons.notifications_none_rounded,
          title: 'Notification Settings',
          subtitle: 'Manage notification preferences',
          onTap: () {
            _showPlaceholder('Notification Settings');
          },
        ),
      ],
    );
  }

  Widget _buildSupportSection() {
    return _ProfileSection(
      title: 'Support',
      children: <Widget>[
        _ProfileActionRow(
          icon: Icons.help_outline_rounded,
          title: 'Help & Support',
          subtitle: 'Get assistance with the app',
          onTap: () {
            _showPlaceholder('Help & Support');
          },
        ),
        const Divider(height: 1, color: _borderColor),
        _ProfileActionRow(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy Policy',
          subtitle: 'Read our privacy policy',
          onTap: () {
            _showPlaceholder('Privacy Policy');
          },
        ),
        const Divider(height: 1, color: _borderColor),
        _ProfileActionRow(
          icon: Icons.info_outline_rounded,
          title: 'About App',
          subtitle: 'Application information',
          onTap: () {
            _showAboutDialog();
          },
        ),
      ],
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'TimeTrack Pro',
      applicationVersion: '1.0.0',
      applicationIcon: const CircleAvatar(
        backgroundColor: Color(0xFFEAF2FF),
        child: Icon(Icons.access_time_filled_rounded, color: _primaryBlue),
      ),
      children: const <Widget>[
        Text(
          'Employee attendance, leave and '
          'notification management application.',
        ),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: _isLoggingOut ? null : _confirmLogout,
        style: OutlinedButton.styleFrom(
          foregroundColor: _dangerColor,
          side: const BorderSide(color: Color(0xFFF4A8A8)),
          backgroundColor: const Color(0xFFFFF7F7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: _isLoggingOut
            ? const SizedBox(
                width: 19,
                height: 19,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _dangerColor,
                ),
              )
            : const Icon(Icons.logout_rounded, size: 20),
        label: Text(
          _isLoggingOut ? 'Logging out...' : 'Logout',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: 4,
      onTap: (int index) {
        _handleBottomNavigation(index);
      },
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      elevation: 12,
      selectedItemColor: _primaryBlue,
      unselectedItemColor: const Color(0xFF5D6678),
      selectedFontSize: 10,
      unselectedFontSize: 10,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_month_outlined),
          activeIcon: Icon(Icons.calendar_month_rounded),
          label: 'Attendance',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.event_note_outlined),
          activeIcon: Icon(Icons.event_note_rounded),
          label: 'Leave',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.notifications_none_rounded),
          activeIcon: Icon(Icons.notifications_rounded),
          label: 'Alerts',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline_rounded),
          activeIcon: Icon(Icons.person_rounded),
          label: 'Profile',
        ),
      ],
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 3, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF102A4C),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: const Color(0xFFDCE3EE)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _ProfileInformationRow extends StatelessWidget {
  const _ProfileInformationRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF0867DB), size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF102A4C),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileActionRow extends StatelessWidget {
  const _ProfileActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF0867DB), size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF102A4C),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF98A2B3),
              size: 21,
            ),
          ],
        ),
      ),
    );
  }
}
