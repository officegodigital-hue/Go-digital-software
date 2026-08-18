import 'dart:ui';

import 'package:flutter/material.dart';

import 'admin_sidebar.dart';
import 'admin_top_bar.dart';

class AdminLayout extends StatefulWidget {
  const AdminLayout({
    required this.activeSection,
    required this.onSectionSelected,
    required this.onLogout,
    required this.child,
    this.adminName = 'John Wilson',
    this.adminRole = 'System Admin',
    this.profileImageUrl,
    this.notificationCount = 0,
    this.searchController,
    this.onSearchChanged,
    this.onNotificationsPressed,
    this.onHelpPressed,
    this.onProfilePressed,
    this.contentPadding = const EdgeInsets.fromLTRB(16, 14, 16, 18),
    this.maxContentWidth = 1600,
    this.confirmBeforeLogout = true,
    super.key,
  });

  final AdminSection activeSection;
  final ValueChanged<AdminSection> onSectionSelected;
  final VoidCallback onLogout;

  final Widget child;

  final String adminName;
  final String adminRole;
  final String? profileImageUrl;

  final int notificationCount;

  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;

  final VoidCallback? onNotificationsPressed;
  final VoidCallback? onHelpPressed;
  final VoidCallback? onProfilePressed;

  final EdgeInsetsGeometry contentPadding;
  final double maxContentWidth;

  final bool confirmBeforeLogout;

  @override
  State<AdminLayout> createState() {
    return _AdminLayoutState();
  }
}

class _AdminLayoutState extends State<AdminLayout> {
  static const double _mobileBreakpoint = 820;
  static const double _collapsedBreakpoint = 1050;

  static const double _sidebarWidth = 160;
  static const double _mobileDrawerWidth = 220;
  static const double _topBarHeight = 67;

  static const Color _pageBackground = Color(0xFFFFFFFF);

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Future<void> _handleLogout() async {
    if (!widget.confirmBeforeLogout) {
      widget.onLogout();
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          actionsPadding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
          title: const Row(
            children: <Widget>[
              CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFFFE7E8),
                child: Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFCF2028),
                  size: 18,
                ),
              ),
              SizedBox(width: 11),
              Expanded(
                child: Text(
                  'Log Out',
                  style: TextStyle(
                    color: Color(0xFF20232A),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to log out of the admin portal?',
            style: TextStyle(
              color: Color(0xFF626774),
              fontSize: 11,
              height: 1.45,
              fontWeight: FontWeight.w400,
            ),
          ),
          actions: <Widget>[
            OutlinedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFCF2028),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.logout_rounded, size: 15),
              label: const Text('Log Out'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      widget.onLogout();
    }
  }

  void _handleSectionSelected(
    AdminSection section, {
    bool closeDrawer = false,
  }) {
    if (closeDrawer) {
      Navigator.of(context).pop();
    }

    if (section == widget.activeSection) {
      return;
    }

    widget.onSectionSelected(section);
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _handleNotifications() {
    final VoidCallback? callback = widget.onNotificationsPressed;

    if (callback != null) {
      callback();
      return;
    }

    if (widget.activeSection != AdminSection.notifications) {
      widget.onSectionSelected(AdminSection.notifications);
    }
  }

  void _handleHelp() {
    final VoidCallback? callback = widget.onHelpPressed;

    if (callback != null) {
      callback();
      return;
    }

    _showMessage('Help and support will be connected next.');
  }

  void _handleProfile() {
    final VoidCallback? callback = widget.onProfilePressed;

    if (callback != null) {
      callback();
      return;
    }

    _showMessage('Admin profile will be connected next.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(14),
          content: Text(message),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;

        final bool isMobile = width < _mobileBreakpoint;

        final bool isSidebarCollapsed =
            !isMobile && width < _collapsedBreakpoint;

        if (isMobile) {
          return _buildMobileLayout();
        }

        return _buildDesktopLayout(isSidebarCollapsed: isSidebarCollapsed);
      },
    );
  }

  Widget _buildDesktopLayout({required bool isSidebarCollapsed}) {
    return Scaffold(
      backgroundColor: _pageBackground,
      body: Row(
        children: <Widget>[
          AdminSidebar(
            activeSection: widget.activeSection,
            onSectionSelected: (AdminSection section) {
              _handleSectionSelected(section);
            },
            onLogout: _handleLogout,
            width: _sidebarWidth,
            isCollapsed: isSidebarCollapsed,
          ),
          Expanded(
            child: Column(
              children: <Widget>[
                AdminTopBar(
                  height: _topBarHeight,
                  adminName: widget.adminName,
                  adminRole: widget.adminRole,
                  profileImageUrl: widget.profileImageUrl,
                  notificationCount: widget.notificationCount,
                  searchController: widget.searchController,
                  onSearchChanged: widget.onSearchChanged,
                  onNotificationsPressed: _handleNotifications,
                  onHelpPressed: _handleHelp,
                  onProfilePressed: _handleProfile,
                ),
                Expanded(child: _buildPageContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _pageBackground,
      drawerScrimColor: Colors.black.withValues(alpha: 0.45),
      drawer: SizedBox(
        width: _mobileDrawerWidth,
        child: Drawer(
          elevation: 8,
          backgroundColor: const Color(0xFF03233D),
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(),
          child: AdminSidebar(
            activeSection: widget.activeSection,
            onSectionSelected: (AdminSection section) {
              _handleSectionSelected(section, closeDrawer: true);
            },
            onLogout: () {
              Navigator.of(context).pop();
              _handleLogout();
            },
            width: _mobileDrawerWidth,
          ),
        ),
      ),
      body: Column(
        children: <Widget>[
          AdminTopBar(
            height: _topBarHeight,
            adminName: widget.adminName,
            adminRole: widget.adminRole,
            profileImageUrl: widget.profileImageUrl,
            notificationCount: widget.notificationCount,
            searchController: widget.searchController,
            onSearchChanged: widget.onSearchChanged,
            onNotificationsPressed: _handleNotifications,
            onHelpPressed: _handleHelp,
            onProfilePressed: _handleProfile,
            showMenuButton: true,
            onMenuPressed: _openDrawer,
          ),
          Expanded(child: _buildPageContent()),
        ],
      ),
    );
  }

  Widget _buildPageContent() {
    return ColoredBox(
      color: _pageBackground,
      child: ScrollConfiguration(
        behavior: const _AdminScrollBehavior(),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.maxContentWidth),
            child: Padding(
              padding: widget.contentPadding,
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminScrollBehavior extends MaterialScrollBehavior {
  const _AdminScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices {
    return <PointerDeviceKind>{
      PointerDeviceKind.touch,
      PointerDeviceKind.mouse,
      PointerDeviceKind.trackpad,
      PointerDeviceKind.stylus,
    };
  }

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return Scrollbar(
      controller: details.controller,
      thumbVisibility: false,
      thickness: 5,
      radius: const Radius.circular(3),
      child: child,
    );
  }
}
