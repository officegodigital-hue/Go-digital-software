import 'package:flutter/material.dart';

enum AdminSection {
  dashboard,
  employees,
  attendance,
  calendar,
  locationTracking,
  permissions,
  payroll,
  notifications,
  reports,
  settings,
}

extension AdminSectionDetails on AdminSection {
  String get label {
    switch (this) {
      case AdminSection.dashboard:
        return 'Dashboard';
      case AdminSection.employees:
        return 'Employees';
      case AdminSection.attendance:
        return 'Attendance';
      case AdminSection.calendar:
        return 'Calendar';
      case AdminSection.locationTracking:
        return 'Location Tracking';
      case AdminSection.permissions:
        return 'Permissions';
      case AdminSection.payroll:
        return 'Payroll';
      case AdminSection.notifications:
        return 'Notifications';
      case AdminSection.reports:
        return 'Reports';
      case AdminSection.settings:
        return 'Settings';
    }
  }

  IconData get icon {
    switch (this) {
      case AdminSection.dashboard:
        return Icons.dashboard_outlined;
      case AdminSection.employees:
        return Icons.groups_outlined;
      case AdminSection.attendance:
        return Icons.fact_check_outlined;
      case AdminSection.calendar:
        return Icons.calendar_month_outlined;
      case AdminSection.locationTracking:
        return Icons.location_on_outlined;
      case AdminSection.permissions:
        return Icons.lock_person_outlined;
      case AdminSection.payroll:
        return Icons.payments_outlined;
      case AdminSection.notifications:
        return Icons.notifications_none_rounded;
      case AdminSection.reports:
        return Icons.insert_chart_outlined_rounded;
      case AdminSection.settings:
        return Icons.settings_outlined;
    }
  }

  IconData get activeIcon {
    switch (this) {
      case AdminSection.dashboard:
        return Icons.dashboard_rounded;
      case AdminSection.employees:
        return Icons.groups_rounded;
      case AdminSection.attendance:
        return Icons.fact_check_rounded;
      case AdminSection.calendar:
        return Icons.calendar_month_rounded;
      case AdminSection.locationTracking:
        return Icons.location_on_rounded;
      case AdminSection.permissions:
        return Icons.lock_person_rounded;
      case AdminSection.payroll:
        return Icons.payments_rounded;
      case AdminSection.notifications:
        return Icons.notifications_rounded;
      case AdminSection.reports:
        return Icons.insert_chart_rounded;
      case AdminSection.settings:
        return Icons.settings_rounded;
    }
  }
}

class AdminSidebar extends StatelessWidget {
  const AdminSidebar({
    required this.activeSection,
    required this.onSectionSelected,
    required this.onLogout,
    this.width = 160,
    this.isCollapsed = false,
    super.key,
  });

  final AdminSection activeSection;
  final ValueChanged<AdminSection> onSectionSelected;
  final VoidCallback onLogout;
  final double width;
  final bool isCollapsed;

  static const Color _sidebarColor = Color(0xFF03233D);
  static const Color _activeColor = Color(0xFF1919EC);
  static const Color _hoverColor = Color(0xFF0B3553);
  static const Color _primaryTextColor = Colors.white;
  static const Color _secondaryTextColor = Color(0xFFD2DCE5);

  static const List<AdminSection> _visibleSections = <AdminSection>[
    AdminSection.dashboard,
    AdminSection.employees,
    AdminSection.attendance,
    AdminSection.calendar,
    AdminSection.locationTracking,
    AdminSection.permissions,
    AdminSection.payroll,
    AdminSection.notifications,
    AdminSection.reports,
    AdminSection.settings,
  ];

  @override
  Widget build(BuildContext context) {
    final double sidebarWidth = isCollapsed ? 72 : width;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: sidebarWidth,
      color: _sidebarColor,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: <Widget>[
            _SidebarBrand(isCollapsed: isCollapsed),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 8 : 7),
                child: ListView.separated(
                  padding: const EdgeInsets.only(top: 4),
                  itemCount: _visibleSections.length,
                  separatorBuilder: (BuildContext context, int index) {
                    return const SizedBox(height: 3);
                  },
                  itemBuilder: (BuildContext context, int index) {
                    final AdminSection section = _visibleSections[index];

                    return _SidebarItem(
                      section: section,
                      isActive: activeSection == section,
                      isCollapsed: isCollapsed,
                      onPressed: () {
                        onSectionSelected(section);
                      },
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                isCollapsed ? 8 : 10,
                8,
                isCollapsed ? 8 : 10,
                12,
              ),
              child: _LogoutButton(
                isCollapsed: isCollapsed,
                onPressed: onLogout,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarBrand extends StatelessWidget {
  const _SidebarBrand({required this.isCollapsed});

  final bool isCollapsed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 67,
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 8 : 15),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF0D3856), width: 1)),
      ),
      child: isCollapsed
          ? const Center(child: _BrandMark())
          : const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Attendance',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AdminSidebar._primaryTextColor,
                    fontSize: 13,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '@GoDigital Admin',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AdminSidebar._secondaryTextColor,
                    fontSize: 7.5,
                    height: 1.1,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AdminSidebar._activeColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: const Text(
        'A',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.section,
    required this.isActive,
    required this.isCollapsed,
    required this.onPressed,
  });

  final AdminSection section;
  final bool isActive;
  final bool isCollapsed;
  final VoidCallback onPressed;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor;

    if (widget.isActive) {
      backgroundColor = AdminSidebar._activeColor;
    } else if (_isHovered) {
      backgroundColor = AdminSidebar._hoverColor;
    } else {
      backgroundColor = Colors.transparent;
    }

    final Widget item = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          _isHovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _isHovered = false;
        });
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(3),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: 31,
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: widget.isCollapsed ? 0 : 10,
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(3),
            ),
            child: widget.isCollapsed
                ? Center(
                    child: Icon(
                      widget.isActive
                          ? widget.section.activeIcon
                          : widget.section.icon,
                      color: Colors.white,
                      size: 17,
                    ),
                  )
                : Row(
                    children: <Widget>[
                      SizedBox(
                        width: 18,
                        child: Icon(
                          widget.isActive
                              ? widget.section.activeIcon
                              : widget.section.icon,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.section.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            height: 1.15,
                            fontWeight: widget.isActive
                                ? FontWeight.w700
                                : FontWeight.w500,
                            letterSpacing: -0.05,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );

    if (!widget.isCollapsed) {
      return item;
    }

    return Tooltip(
      message: widget.section.label,
      waitDuration: const Duration(milliseconds: 250),
      child: item,
    );
  }
}

class _LogoutButton extends StatefulWidget {
  const _LogoutButton({required this.isCollapsed, required this.onPressed});

  final bool isCollapsed;
  final VoidCallback onPressed;

  @override
  State<_LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<_LogoutButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final Widget button = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          _isHovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _isHovered = false;
        });
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(3),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: 30,
            width: double.infinity,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _isHovered
                  ? const Color(0xFF2929F2)
                  : AdminSidebar._activeColor,
              borderRadius: BorderRadius.circular(3),
            ),
            child: widget.isCollapsed
                ? const Icon(
                    Icons.logout_rounded,
                    size: 15,
                    color: Colors.white,
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(Icons.logout_rounded, size: 13, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Log Out',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          height: 1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );

    if (!widget.isCollapsed) {
      return button;
    }

    return Tooltip(message: 'Log Out', child: button);
  }
}
