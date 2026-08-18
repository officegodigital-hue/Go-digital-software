import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../notifications/presentation/screens/admin_notification_screen.dart';

import '../../../../core/auth/admin_auth_controller.dart';
import '../../../../core/layout/admin_layout.dart';
import '../../../../core/layout/admin_sidebar.dart';

import '../../../attendance/data/models/admin_attendance_models.dart';
import '../../../attendance/presentation/screens/admin_daily_attendance_screen.dart';
import '../../../calendar/presentation/screens/admin_calendar_screen.dart';
import '../../../employees/presentation/screens/company_employee_management_screen.dart';
import '../../../permissions/data/models/admin_permission_model.dart';
import '../../../permissions/presentation/screens/admin_permission_screen.dart';
import '../../../payroll/presentation/screens/payroll_details_screen.dart';

import '../controllers/admin_dashboard_controller.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({required this.authController, super.key});

  final AdminAuthController authController;

  @override
  State<AdminDashboardScreen> createState() {
    return _AdminDashboardScreenState();
  }
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();

  late final AdminDashboardController _dashboardController;

  AdminSection _activeSection = AdminSection.dashboard;

  String _activityFilter = 'All';
  String _searchQuery = '';

  bool _isExporting = false;

  AdminAuthController get _authController => widget.authController;

  String get _adminName {
    final value = _authController.userName.trim();
    return value.isEmpty ? 'Admin' : value;
  }

  String get _adminRole {
    final value = _authController.userRole.trim();
    return value.isEmpty ? 'Admin' : value;
  }

  String get _adminEmail => _authController.userEmail.trim();

  String get _adminProfileImageUrl {
    return _authController.profileImageUrl.trim();
  }

  String get _adminCompany {
    return _authController.companyName.trim();
  }

  String get _adminBranch {
    return _authController.branchName.trim();
  }

  String get _adminInitials {
    final words = _adminName
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .toList();

    if (words.isEmpty) {
      return 'AD';
    }

    if (words.length == 1) {
      final word = words.first;
      return word.substring(0, word.length >= 2 ? 2 : 1).toUpperCase();
    }

    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }

  @override
  void initState() {
    super.initState();

    _dashboardController = AdminDashboardController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _dashboardController.initialize();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _dashboardController.dispose();
    super.dispose();
  }

  void _selectSection(AdminSection section) {
    setState(() {
      _activeSection = section;
    });

    if (section == AdminSection.dashboard) {
      _dashboardController.refresh();
    }
  }

  void _handleSearchChanged(String value) {
    setState(() {
      _searchQuery = value.trim().toLowerCase();
    });
  }

  Future<void> _pickDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _dashboardController.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'Select Dashboard Date',
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    await _dashboardController.changeDate(selectedDate);
  }

  Future<void> _exportReport() async {
    if (_isExporting) {
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      final report = <String>[
        'ATTENDANCE DASHBOARD REPORT',
        'Date: ${_longDate(_dashboardController.selectedDate)}',
        '',
        'Total Employees: ${_dashboardController.totalEmployees}',
        'Present: ${_dashboardController.presentToday}',
        'Late Logins: ${_dashboardController.lateLogins}',
        'Absent: ${_dashboardController.absentToday}',
        'Work From Home: ${_dashboardController.workFromHome}',
        'Permission Pending: ${_dashboardController.permissionPending}',
        'Active Sessions: ${_dashboardController.activeSessions}',
        'Completed Sessions: ${_dashboardController.completedSessions}',
      ].join('\n');

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Dashboard Report'),
            content: SizedBox(width: 460, child: SelectableText(report)),
            actions: <Widget>[
              OutlinedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Close'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: report));

                  if (!dialogContext.mounted) {
                    return;
                  }

                  Navigator.of(dialogContext).pop();
                  _showMessage('Dashboard report copied.');
                },
                icon: const Icon(Icons.copy_rounded, size: 15),
                label: const Text('Copy Report'),
              ),
            ],
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _approvePermission(AdminPermissionModel permission) async {
    final remarksController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Approve Permission'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Approve ${_permissionTitle(permission)} for '
                  '${permission.employeeName}?',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: remarksController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Admin remarks (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Approve'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      remarksController.dispose();
      return;
    }

    final remarks = remarksController.text.trim();
    remarksController.dispose();

    final success = await _dashboardController.approvePermission(
      permissionId: permission.id,
      adminRemarks: remarks,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      _showMessage(
        _dashboardController.successMessage ??
            'Permission request approved successfully.',
      );
    } else {
      _showMessage(
        _dashboardController.errorMessage ??
            'Unable to approve permission request.',
        isError: true,
      );
    }
  }

  Future<void> _rejectPermission(AdminPermissionModel permission) async {
    final remarksController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reject Permission'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Reject ${_permissionTitle(permission)} for '
                  '${permission.employeeName}?',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: remarksController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Rejection reason',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _Ui.red),
              onPressed: () {
                if (remarksController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogContext)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a rejection reason.'),
                      ),
                    );
                  return;
                }

                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      remarksController.dispose();
      return;
    }

    final remarks = remarksController.text.trim();
    remarksController.dispose();

    final success = await _dashboardController.rejectPermission(
      permissionId: permission.id,
      adminRemarks: remarks,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      _showMessage(
        _dashboardController.successMessage ??
            'Permission request rejected successfully.',
      );
    } else {
      _showMessage(
        _dashboardController.errorMessage ??
            'Unable to reject permission request.',
        isError: true,
      );
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? _Ui.red : _Ui.navy,
          content: Text(message),
        ),
      );
  }

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Admin Help'),
          content: const Text(
            'Use the sidebar to access employees, attendance, calendar, '
            'permissions, payroll, notifications, reports and settings.',
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showProfile() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Admin Profile'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _AdminProfileAvatar(
                  imageUrl: _adminProfileImageUrl,
                  initials: _adminInitials,
                ),
                const SizedBox(height: 14),
                Text(
                  _adminName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _adminRole,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _Ui.textMuted, fontSize: 11.5),
                ),
                if (_adminEmail.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  _ProfileDetailRow(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: _adminEmail,
                  ),
                ],
                const SizedBox(height: 9),
                _ProfileDetailRow(
                  icon: Icons.business_outlined,
                  label: 'Company',
                  value: _adminCompany,
                ),
                const SizedBox(height: 9),
                _ProfileDetailRow(
                  icon: Icons.location_on_outlined,
                  label: 'Branch',
                  value: _adminBranch,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Log Out'),
          content: Text(
            'Log out from the Attendance Admin account for $_adminName?',
          ),
          actions: <Widget>[
            OutlinedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.logout_rounded, size: 17),
              label: const Text('Log Out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await _authController.signOut();
  }

  List<_ActivityData> get _filteredActivities {
    final activities = _buildLiveActivities();

    return activities.where((activity) {
      final categoryMatches =
          _activityFilter == 'All' || activity.category == _activityFilter;

      if (!categoryMatches) {
        return false;
      }

      if (_searchQuery.isEmpty) {
        return true;
      }

      final searchable =
          '${activity.employeeName} ${activity.action} ${activity.status} '
                  '${activity.category}'
              .toLowerCase();

      return searchable.contains(_searchQuery);
    }).toList();
  }

  List<AdminPermissionModel> get _filteredPermissions {
    return _dashboardController.pendingPermissions.where((permission) {
      if (_searchQuery.isEmpty) {
        return true;
      }

      final searchable =
          '${permission.employeeName} '
                  '${permission.employeeRole ?? ''} '
                  '${permission.designationName ?? ''} '
                  '${permission.requestTitle} '
                  '${permission.requestType} '
                  '${permission.reason} '
                  '${permission.status}'
              .toLowerCase();

      return searchable.contains(_searchQuery);
    }).toList();
  }

  List<_ActivityData> _buildLiveActivities() {
    final activities = <_ActivityData>[];

    for (final record in _dashboardController.attendanceRecords) {
      final DateTime? eventTime =
          record.checkOutAt ?? record.checkInAt ?? record.attendanceDate;

      String action;
      String status;
      Color accentColor;
      Color avatarColor;

      if (record.isLate) {
        action = 'logged in late';
        status = 'Late';
        accentColor = _Ui.brown;
        avatarColor = const Color(0xFFFFE7C7);
      } else if (record.checkOutAt != null) {
        action = 'checked out';
        status = 'Log-Out';
        accentColor = const Color(0xFFB06A1B);
        avatarColor = const Color(0xFFFFEBD1);
      } else if (record.checkInAt != null) {
        action = 'checked in';
        status = 'Log-In';
        accentColor = _Ui.green;
        avatarColor = const Color(0xFFC9F2DF);
      } else if (record.isAbsent) {
        action = 'marked absent';
        status = 'Absent';
        accentColor = _Ui.red;
        avatarColor = const Color(0xFFFFD9CF);
      } else {
        action = record.attendanceStatus.isEmpty
            ? 'attendance updated'
            : 'attendance ${record.attendanceStatus}';
        status = _titleCase(record.attendanceStatus);
        accentColor = _Ui.blue;
        avatarColor = const Color(0xFFDCE5FF);
      }

      activities.add(
        _ActivityData(
          initials: _initials(record.employeeName),
          employeeName: record.employeeName,
          action: action,
          time: _clockTime(eventTime),
          status: status,
          category: 'Attendance',
          avatarColor: avatarColor,
          accentColor: accentColor,
          sortAt: eventTime,
        ),
      );
    }

    for (final permission in _dashboardController.pendingPermissions) {
      final category = permission.isLeaveRequest ? 'Leave' : 'Permission';

      final accentColor = permission.isLeaveRequest
          ? _Ui.red
          : permission.isLateLogin
          ? _Ui.brown
          : const Color(0xFF5B5FC7);

      activities.add(
        _ActivityData(
          initials: _initials(permission.employeeName),
          employeeName: permission.employeeName,
          action: 'requested ${_permissionTitle(permission)}',
          time: _permissionActivityTime(permission),
          status: 'Pending',
          category: category,
          avatarColor: accentColor.withValues(alpha: 0.12),
          accentColor: accentColor,
          sortAt: permission.createdAt,
        ),
      );
    }

    activities.sort((first, second) {
      final firstDate = first.sortAt;
      final secondDate = second.sortAt;

      if (firstDate == null && secondDate == null) {
        return 0;
      }

      if (firstDate == null) {
        return 1;
      }

      if (secondDate == null) {
        return -1;
      }

      return secondDate.compareTo(firstDate);
    });

    return activities;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _dashboardController,
      builder: (context, child) {
        return AdminLayout(
          activeSection: _activeSection,
          onSectionSelected: _selectSection,
          onLogout: _handleLogout,
          adminName: _adminName,
          adminRole: _adminRole,

          // Until a dedicated Admin Notification API is connected,
          // use the real pending permission count instead of a fake number.
          notificationCount: _dashboardController.permissionPending,

          searchController: _searchController,
          onSearchChanged: _handleSearchChanged,
          onNotificationsPressed: () {
            _selectSection(AdminSection.notifications);
          },
          onHelpPressed: _showHelp,
          onProfilePressed: _showProfile,
          child: _buildSelectedPage(),
        );
      },
    );
  }

  Widget _buildSelectedPage() {
    switch (_activeSection) {
      case AdminSection.dashboard:
        return _DashboardPage(
          controller: _dashboardController,
          activities: _filteredActivities,
          permissions: _filteredPermissions,
          isExporting: _isExporting,
          activityFilter: _activityFilter,
          onDatePressed: _pickDate,
          onRefreshPressed: _dashboardController.refresh,
          onExportPressed: _exportReport,
          onActivityFilterChanged: (value) {
            setState(() {
              _activityFilter = value;
            });
          },
          onViewAllPermissions: () {
            _selectSection(AdminSection.permissions);
          },
          onApprovePermission: _approvePermission,
          onRejectPermission: _rejectPermission,
        );

      case AdminSection.permissions:
        return const AdminPermissionScreen();

      case AdminSection.employees:
        return const CompanyEmployeeManagementScreen();

      case AdminSection.attendance:
        return const AdminDailyAttendanceScreen();

      case AdminSection.calendar:
        return const AdminCalendarScreen();

      case AdminSection.notifications:
        return const AdminNotificationScreen();

      case AdminSection.reports:
        return const _PlaceholderPage(
          title: 'Reports',
          subtitle: 'Generate attendance and payroll reports.',
          icon: Icons.analytics_outlined,
        );

      case AdminSection.locationTracking:
        return const _PlaceholderPage(
          title: 'Location Tracking',
          subtitle: 'Manage employee attendance location and geofence rules.',
          icon: Icons.location_on_rounded,
        );

      case AdminSection.settings:
        return const _PlaceholderPage(
          title: 'Settings',
          subtitle: 'Manage admin settings and preferences.',
          icon: Icons.settings_outlined,
        );

      case AdminSection.payroll:
        return PayrollDetailsScreen(
          token: _authController.token,
          payroll: <String, dynamic>{
            'id': 1,
            'payroll_month': DateTime.now().month,
            'payroll_year': DateTime.now().year,
            'employees': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 1,
                'employee_name': 'Krishnaraj B',
                'employee_code': '90046034',
                'department': 'Sales',
                'designation': 'BDM',
                'basic_salary': 20000,
                'hra': 5000,
                'allowance': 10000,
                'deduction': 0,
                'net_salary': 35000,
              },
              <String, dynamic>{
                'id': 2,
                'employee_name': 'Ravi Kumar',
                'employee_code': '90046035',
                'department': 'HR',
                'designation': 'Manager',
                'basic_salary': 30000,
                'hra': 7000,
                'allowance': 5000,
                'deduction': 2000,
                'net_salary': 40000,
              },
            ],
          },
        );
    }
  }

  static String _longDate(DateTime date) {
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  static String _permissionTitle(AdminPermissionModel permission) {
    final title = permission.requestTitle.trim();

    if (title.isNotEmpty) {
      return title;
    }

    return permission.requestTypeLabel;
  }

  static String _permissionActivityTime(AdminPermissionModel permission) {
    final requested = permission.requestedTime?.trim();

    if (requested != null && requested.isNotEmpty) {
      return _formatApiTime(requested);
    }

    final date = permission.requestDate;

    if (date != null) {
      return _shortDate(date);
    }

    return '';
  }

  static String _permissionDateLabel(AdminPermissionModel permission) {
    if (permission.isLeaveRequest) {
      final start = permission.startDate;
      final end = permission.endDate;

      if (start != null && end != null) {
        if (_sameDay(start, end)) {
          return _shortDate(start);
        }

        return '${_shortDate(start)} - ${_shortDate(end)}';
      }

      if (start != null) {
        return _shortDate(start);
      }
    }

    final date = permission.requestDate;
    final time = permission.requestedTime;

    final parts = <String>[];

    if (date != null) {
      parts.add(_shortDate(date));
    }

    if (time != null && time.trim().isNotEmpty) {
      parts.add(_formatApiTime(time));
    }

    return parts.isEmpty ? '-' : parts.join(' · ');
  }

  static String _permissionEmployeeRole(AdminPermissionModel permission) {
    final role = permission.employeeRole?.trim();

    if (role != null && role.isNotEmpty) {
      return role;
    }

    final designation = permission.designationName?.trim();

    if (designation != null && designation.isNotEmpty) {
      return designation;
    }

    return 'Employee';
  }

  static String _initials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    if (words.isEmpty) {
      return 'E';
    }

    return words.take(2).map((word) => word[0].toUpperCase()).join();
  }

  static String _clockTime(DateTime? date) {
    if (date == null) {
      return '';
    }

    final local = date.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  static String _formatApiTime(String value) {
    final parts = value.trim().split(':');

    if (parts.length < 2) {
      return value;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) {
      return value;
    }

    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final period = hour >= 12 ? 'PM' : 'AM';

    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  static String _shortDate(DateTime date) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  static bool _sameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  static String _titleCase(String value) {
    final normalized = value.trim().replaceAll('_', ' ');

    if (normalized.isEmpty) {
      return 'Updated';
    }

    return normalized
        .split(RegExp(r'\s+'))
        .map(
          (word) => word.isEmpty
              ? ''
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }
}

class _DashboardPage extends StatelessWidget {
  const _DashboardPage({
    required this.controller,
    required this.activities,
    required this.permissions,
    required this.isExporting,
    required this.activityFilter,
    required this.onDatePressed,
    required this.onRefreshPressed,
    required this.onExportPressed,
    required this.onActivityFilterChanged,
    required this.onViewAllPermissions,
    required this.onApprovePermission,
    required this.onRejectPermission,
  });

  final AdminDashboardController controller;
  final List<_ActivityData> activities;
  final List<AdminPermissionModel> permissions;

  final bool isExporting;
  final String activityFilter;

  final VoidCallback onDatePressed;
  final VoidCallback onRefreshPressed;
  final VoidCallback onExportPressed;
  final ValueChanged<String> onActivityFilterChanged;
  final VoidCallback onViewAllPermissions;
  final ValueChanged<AdminPermissionModel> onApprovePermission;
  final ValueChanged<AdminPermissionModel> onRejectPermission;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: <Widget>[
              _DashboardHeader(
                selectedDate: controller.selectedDate,
                isExporting: isExporting,
                isLoading: controller.isLoading,
                onDatePressed: onDatePressed,
                onRefreshPressed: onRefreshPressed,
                onExportPressed: onExportPressed,
              ),
              if (controller.isLoading) ...<Widget>[
                const SizedBox(height: 10),
                const LinearProgressIndicator(minHeight: 2),
              ],
              if (controller.errorMessage != null) ...<Widget>[
                const SizedBox(height: 10),
                _DashboardMessage(
                  message: controller.errorMessage!,
                  isError: true,
                ),
              ],
              const SizedBox(height: 13),
              _MetricGrid(
                availableWidth: constraints.maxWidth,
                controller: controller,
              ),
              const SizedBox(height: 14),
              _DashboardPanels(
                availableWidth: constraints.maxWidth,
                controller: controller,
                activityFilter: activityFilter,
                activities: activities,
                onActivityFilterChanged: onActivityFilterChanged,
              ),
              const SizedBox(height: 14),
              _PermissionPanel(
                permissions: permissions,
                isUpdating: controller.isPermissionUpdating,
                onViewAll: onViewAllPermissions,
                onApprove: onApprovePermission,
                onReject: onRejectPermission,
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.selectedDate,
    required this.isExporting,
    required this.isLoading,
    required this.onDatePressed,
    required this.onRefreshPressed,
    required this.onExportPressed,
  });

  final DateTime selectedDate;
  final bool isExporting;
  final bool isLoading;

  final VoidCallback onDatePressed;
  final VoidCallback onRefreshPressed;
  final VoidCallback onExportPressed;

  @override
  Widget build(BuildContext context) {
    const title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Dashboard Overview', style: _Ui.pageTitle),
        SizedBox(height: 3),
        Text(
          'Real-time enterprise attendance monitoring and analytics.',
          style: _Ui.pageSubtitle,
        ),
      ],
    );

    final actions = Wrap(
      spacing: 7,
      runSpacing: 7,
      children: <Widget>[
        SizedBox(
          height: 28,
          child: OutlinedButton.icon(
            onPressed: isLoading ? null : onRefreshPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: _Ui.blue,
              side: const BorderSide(color: _Ui.border),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 12),
            label: const Text('Refresh', style: TextStyle(fontSize: 9)),
          ),
        ),
        SizedBox(
          height: 28,
          child: OutlinedButton.icon(
            onPressed: isLoading ? null : onDatePressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: _Ui.textPrimary,
              side: const BorderSide(color: _Ui.border),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            icon: const Icon(Icons.calendar_today_outlined, size: 11),
            label: Text(
              _shortDate(selectedDate),
              style: const TextStyle(fontSize: 9),
            ),
          ),
        ),
        SizedBox(
          height: 28,
          child: FilledButton.icon(
            onPressed: isExporting || isLoading ? null : onExportPressed,
            style: FilledButton.styleFrom(
              backgroundColor: _Ui.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            icon: isExporting
                ? const SizedBox(
                    width: 11,
                    height: 11,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download_rounded, size: 12),
            label: Text(
              isExporting ? 'Preparing' : 'Export Report',
              style: const TextStyle(fontSize: 9),
            ),
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 650) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[title, const SizedBox(height: 10), actions],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Expanded(child: title),
            actions,
          ],
        );
      },
    );
  }

  static String _shortDate(DateTime date) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _DashboardMessage extends StatelessWidget {
  const _DashboardMessage({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFEEEE) : const Color(0xFFEAF7EE),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isError ? const Color(0xFFF5B6B6) : const Color(0xFFB8DFC3),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: isError ? _Ui.red : _Ui.green,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isError ? _Ui.red : _Ui.green,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.availableWidth, required this.controller});

  final double availableWidth;
  final AdminDashboardController controller;

  @override
  Widget build(BuildContext context) {
    final int columns;

    if (availableWidth >= 1050) {
      columns = 6;
    } else if (availableWidth >= 700) {
      columns = 3;
    } else if (availableWidth >= 430) {
      columns = 2;
    } else {
      columns = 1;
    }

    const gap = 10.0;
    final width = (availableWidth - ((columns - 1) * gap)) / columns;

    final isToday = _sameDay(controller.selectedDate, DateTime.now());

    final metrics = <_MetricData>[
      _MetricData(
        label: 'TOTAL EMPLOYEES',
        value: '${controller.totalEmployees}',
        icon: Icons.groups_rounded,
        color: const Color(0xFF1616E8),
      ),
      _MetricData(
        label: isToday ? 'PRESENT TODAY' : 'PRESENT',
        value: '${controller.presentToday}',
        icon: Icons.check_circle_outline,
        color: const Color(0xFF3D9B51),
      ),
      _MetricData(
        label: 'LATE LOGINS',
        value: '${controller.lateLogins}',
        icon: Icons.schedule_rounded,
        color: const Color(0xFF9D611F),
      ),
      _MetricData(
        label: 'ABSENT',
        value: '${controller.absentToday}',
        icon: Icons.person_off_outlined,
        color: const Color(0xFFC52931),
      ),
      _MetricData(
        label: 'WFH',
        value: '${controller.workFromHome}',
        icon: Icons.home_work_outlined,
        color: const Color(0xFF3546C5),
      ),
      _MetricData(
        label: 'PERMISSION PENDING',
        value: '${controller.permissionPending}',
        icon: Icons.pending_actions_outlined,
        color: const Color(0xFF71717A),
      ),
    ];

    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: metrics.map((metric) {
        return SizedBox(
          width: width,
          child: _MetricCard(metric: metric),
        );
      }).toList(),
    );
  }

  static bool _sameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _MetricData metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 86,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: _Ui.border, width: 0.7),
      ),
      child: Column(
        children: <Widget>[
          Container(
            height: 29,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            decoration: BoxDecoration(
              color: metric.color,
              borderRadius: BorderRadius.circular(2),
            ),
            child: Row(
              children: <Widget>[
                Icon(metric.icon, color: Colors.white, size: 13),
                const SizedBox(width: 7),
                Container(
                  width: 0.6,
                  height: 15,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    metric.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            metric.value,
            style: TextStyle(
              color: metric.color,
              fontSize: 21,
              height: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
        ],
      ),
    );
  }
}

class _DashboardPanels extends StatelessWidget {
  const _DashboardPanels({
    required this.availableWidth,
    required this.controller,
    required this.activityFilter,
    required this.activities,
    required this.onActivityFilterChanged,
  });

  final double availableWidth;
  final AdminDashboardController controller;
  final String activityFilter;
  final List<_ActivityData> activities;
  final ValueChanged<String> onActivityFilterChanged;

  @override
  Widget build(BuildContext context) {
    final attendance = _AttendancePanel(summary: controller.attendanceSummary);

    final roleStatus = _RoleStatusPanel(records: controller.attendanceRecords);

    final activity = _ActivityPanel(
      activities: activities,
      activeFilter: activityFilter,
      onFilterChanged: onActivityFilterChanged,
    );

    if (availableWidth >= 950) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(flex: 46, child: attendance),
          const SizedBox(width: 10),
          Expanded(flex: 32, child: roleStatus),
          const SizedBox(width: 10),
          Expanded(flex: 32, child: activity),
        ],
      );
    }

    if (availableWidth >= 620) {
      return Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: attendance),
              const SizedBox(width: 10),
              Expanded(child: roleStatus),
            ],
          ),
          const SizedBox(height: 10),
          activity,
        ],
      );
    }

    return Column(
      children: <Widget>[
        attendance,
        const SizedBox(height: 10),
        roleStatus,
        const SizedBox(height: 10),
        activity,
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.child,
    this.subtitle = '',
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 278,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: _Ui.border, width: 0.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: _Ui.panelTitle),
                    if (subtitle.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 3),
                      Text(subtitle, style: _Ui.panelSubtitle),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 13),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _AttendancePanel extends StatelessWidget {
  const _AttendancePanel({required this.summary});

  final AdminAttendanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final values = <_AttendanceBarData>[
      _AttendanceBarData(
        label: 'Present',
        value: summary.presentRecords,
        color: _Ui.chartBlue,
      ),
      _AttendanceBarData(
        label: 'Late',
        value: summary.lateRecords,
        color: _Ui.brown,
      ),
      _AttendanceBarData(
        label: 'Absent',
        value: summary.absentRecords,
        color: _Ui.red,
      ),
      _AttendanceBarData(
        label: 'Active',
        value: summary.activeSessions,
        color: _Ui.green,
      ),
      _AttendanceBarData(
        label: 'Done',
        value: summary.completedSessions,
        color: const Color(0xFF5B5FC7),
      ),
    ];

    return _Panel(
      title: 'Attendance Status Overview',
      subtitle: 'Live values for the selected dashboard date.',
      child: _AttendanceChart(values: values),
    );
  }
}

class _AttendanceChart extends StatelessWidget {
  const _AttendanceChart({required this.values});

  final List<_AttendanceBarData> values;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<int>(
      0,
      (current, item) => item.value > current ? item.value : current,
    );

    final safeMax = maxValue <= 0 ? 1 : maxValue;

    return Column(
      children: <Widget>[
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxHeight = (constraints.maxHeight - 35)
                  .clamp(20.0, double.infinity)
                  .toDouble();

              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: values.map((item) {
                  final ratio = item.value <= 0 ? 0.06 : item.value / safeMax;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          Text(
                            '${item.value}',
                            style: const TextStyle(
                              color: _Ui.textPrimary,
                              fontSize: 7,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            height: maxHeight * ratio,
                            decoration: BoxDecoration(
                              color: item.color,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: values.map((item) {
            return Expanded(
              child: Text(
                item.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _Ui.textMuted,
                  fontSize: 7.2,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _RoleStatusPanel extends StatelessWidget {
  const _RoleStatusPanel({required this.records});

  final List<AdminAttendanceRecord> records;

  @override
  Widget build(BuildContext context) {
    final items = _buildRoleStatus(records);

    return _Panel(
      title: 'Department / Role Status',
      subtitle: 'Attendance rate grouped by employee role.',
      child: items.isEmpty
          ? const Center(
              child: Text(
                'No attendance role data for this date.',
                style: TextStyle(color: _Ui.textMuted, fontSize: 9),
              ),
            )
          : ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) {
                return const SizedBox(height: 12);
              },
              itemBuilder: (context, index) {
                final item = items[index];

                return Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _Ui.textPrimary,
                              fontSize: 8.5,
                            ),
                          ),
                        ),
                        Text(
                          '${item.percentage}%',
                          style: TextStyle(
                            color: item.color,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: item.percentage / 100,
                        minHeight: 4,
                        backgroundColor: const Color(0xFFE8E8EC),
                        valueColor: AlwaysStoppedAnimation<Color>(item.color),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  static List<_RoleStatusData> _buildRoleStatus(
    List<AdminAttendanceRecord> records,
  ) {
    final grouped = <String, List<AdminAttendanceRecord>>{};

    for (final record in records) {
      final name = record.roleName.trim().isEmpty
          ? 'Employee'
          : record.roleName.trim();

      grouped.putIfAbsent(name, () => <AdminAttendanceRecord>[]);

      grouped[name]!.add(record);
    }

    final entries = grouped.entries.toList()
      ..sort((first, second) {
        return second.value.length.compareTo(first.value.length);
      });

    return entries.take(5).map((entry) {
      final total = entry.value.length;

      final attended = entry.value.where((record) {
        return record.isPresent || record.isLate || record.checkInAt != null;
      }).length;

      final percentage = total == 0
          ? 0
          : ((attended / total) * 100).round().clamp(0, 100).toInt();

      final color = percentage >= 90
          ? _Ui.green
          : percentage >= 75
          ? _Ui.brown
          : _Ui.red;

      return _RoleStatusData(
        name: entry.key,
        percentage: percentage,
        color: color,
      );
    }).toList();
  }
}

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel({
    required this.activities,
    required this.activeFilter,
    required this.onFilterChanged,
  });

  final List<_ActivityData> activities;
  final String activeFilter;
  final ValueChanged<String> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Real-time Activity',
      trailing: PopupMenuButton<String>(
        tooltip: 'Filter activity',
        initialValue: activeFilter,
        onSelected: onFilterChanged,
        position: PopupMenuPosition.under,
        itemBuilder: (context) {
          return const <PopupMenuEntry<String>>[
            PopupMenuItem<String>(value: 'All', child: Text('All Activity')),
            PopupMenuItem<String>(
              value: 'Attendance',
              child: Text('Attendance'),
            ),
            PopupMenuItem<String>(
              value: 'Leave',
              child: Text('Leave Requests'),
            ),
            PopupMenuItem<String>(
              value: 'Permission',
              child: Text('Permissions'),
            ),
          ];
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.filter_alt_outlined,
              color: _Ui.textMuted,
              size: 11,
            ),
            const SizedBox(width: 3),
            Text(
              activeFilter == 'All' ? 'Filter' : activeFilter,
              style: const TextStyle(color: _Ui.textMuted, fontSize: 8),
            ),
          ],
        ),
      ),
      child: activities.isEmpty
          ? const Center(
              child: Text(
                'No matching activity.',
                style: TextStyle(color: _Ui.textMuted, fontSize: 10),
              ),
            )
          : ListView.separated(
              itemCount: activities.length > 7 ? 7 : activities.length,
              separatorBuilder: (_, __) {
                return const Divider(height: 1, color: _Ui.divider);
              },
              itemBuilder: (context, index) {
                return _ActivityRow(activity: activities[index]);
              },
            ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity});

  final _ActivityData activity;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Container(
            width: 25,
            height: 25,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: activity.avatarColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              activity.initials,
              style: TextStyle(
                color: activity.accentColor,
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  activity.employeeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _Ui.textPrimary,
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  activity.time.isEmpty
                      ? activity.action
                      : '${activity.action} · ${activity.time}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _Ui.textMuted, fontSize: 7),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: activity.accentColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(
              activity.status,
              style: TextStyle(
                color: activity.accentColor,
                fontSize: 7,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionPanel extends StatelessWidget {
  const _PermissionPanel({
    required this.permissions,
    required this.isUpdating,
    required this.onViewAll,
    required this.onApprove,
    required this.onReject,
  });

  final List<AdminPermissionModel> permissions;
  final bool isUpdating;

  final VoidCallback onViewAll;
  final ValueChanged<AdminPermissionModel> onApprove;
  final ValueChanged<AdminPermissionModel> onReject;

  @override
  Widget build(BuildContext context) {
    final visible = permissions.take(3).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: _Ui.border, width: 0.7),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text('Pending Permissions', style: _Ui.panelTitle),
              ),
              TextButton(
                onPressed: onViewAll,
                child: const Text(
                  'View All →',
                  style: TextStyle(color: _Ui.blue, fontSize: 8),
                ),
              ),
            ],
          ),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No pending permission requests.',
                style: TextStyle(color: _Ui.textMuted, fontSize: 10),
              ),
            )
          else
            ...visible.map((permission) {
              return Column(
                children: <Widget>[
                  const Divider(height: 1, color: _Ui.divider),
                  _PermissionRow(
                    permission: permission,
                    isUpdating: isUpdating,
                    onApprove: () {
                      onApprove(permission);
                    },
                    onReject: () {
                      onReject(permission);
                    },
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.permission,
    required this.isUpdating,
    required this.onApprove,
    required this.onReject,
  });

  final AdminPermissionModel permission;
  final bool isUpdating;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    _PermissionAvatar(name: permission.employeeName),
                    const SizedBox(width: 8),
                    Expanded(child: _PermissionEmployee(permission)),
                    _StatusBadge(status: permission.statusLabel),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  permission.reason,
                  style: const TextStyle(color: _Ui.textMuted, fontSize: 7.5),
                ),
                const SizedBox(height: 6),
                Text(
                  _AdminDashboardScreenState._permissionDateLabel(permission),
                  style: const TextStyle(color: _Ui.textMuted, fontSize: 7.5),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isUpdating ? null : onReject,
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: FilledButton(
                        onPressed: isUpdating ? null : onApprove,
                        child: const Text('Approve'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: <Widget>[
              _PermissionAvatar(name: permission.employeeName),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: _PermissionEmployee(permission)),
              Expanded(
                flex: 2,
                child: Tooltip(
                  message: permission.reason,
                  child: Text(
                    _AdminDashboardScreenState._permissionTitle(permission),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _Ui.textPrimary, fontSize: 8),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  _AdminDashboardScreenState._permissionDateLabel(permission),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _Ui.textMuted, fontSize: 7.5),
                ),
              ),
              _StatusBadge(status: permission.statusLabel),
              const SizedBox(width: 7),
              SizedBox(
                height: 24,
                child: OutlinedButton(
                  onPressed: isUpdating ? null : onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _Ui.red,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Reject', style: TextStyle(fontSize: 7.5)),
                ),
              ),
              const SizedBox(width: 5),
              SizedBox(
                height: 24,
                child: FilledButton(
                  onPressed: isUpdating ? null : onApprove,
                  style: FilledButton.styleFrom(
                    backgroundColor: _Ui.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Approve', style: TextStyle(fontSize: 7.5)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PermissionAvatar extends StatelessWidget {
  const _PermissionAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initials = _AdminDashboardScreenState._initials(name);

    return CircleAvatar(
      radius: 13,
      backgroundColor: const Color(0xFFE8E9FF),
      child: Text(
        initials,
        style: const TextStyle(
          color: _Ui.blue,
          fontSize: 7.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PermissionEmployee extends StatelessWidget {
  const _PermissionEmployee(this.permission);

  final AdminPermissionModel permission;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          permission.employeeName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _Ui.textPrimary,
            fontSize: 8,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _AdminDashboardScreenState._permissionEmployeeRole(permission),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _Ui.textMuted, fontSize: 7),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toLowerCase();

    final Color color;
    final Color background;

    switch (normalized) {
      case 'approved':
        color = _Ui.green;
        background = const Color(0xFFE4F5EA);
        break;

      case 'rejected':
        color = _Ui.red;
        background = const Color(0xFFFFE4E5);
        break;

      default:
        color = _Ui.brown;
        background = const Color(0xFFFFF0D8);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        status.isEmpty ? 'Pending' : status,
        style: TextStyle(
          color: color,
          fontSize: 7,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _Ui.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFE8E9FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: _Ui.blue, size: 27),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: _Ui.pageTitle),
            const SizedBox(height: 7),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _Ui.textMuted,
                fontSize: 11.5,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminProfileAvatar extends StatelessWidget {
  const _AdminProfileAvatar({required this.imageUrl, required this.initials});

  final String imageUrl;
  final String initials;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: const Color(0xFFE7E8FF),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: _Ui.blue,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );

    return Container(
      width: 72,
      height: 72,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: imageUrl.isEmpty
          ? fallback
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return fallback;
              },
            ),
    );
  }
}

class _ProfileDetailRow extends StatelessWidget {
  const _ProfileDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FA),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _Ui.border),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: _Ui.blue, size: 17),
          const SizedBox(width: 9),
          SizedBox(
            width: 66,
            child: Text(
              label,
              style: const TextStyle(
                color: _Ui.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _Ui.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _AttendanceBarData {
  const _AttendanceBarData({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;
}

class _RoleStatusData {
  const _RoleStatusData({
    required this.name,
    required this.percentage,
    required this.color,
  });

  final String name;
  final int percentage;
  final Color color;
}

class _ActivityData {
  const _ActivityData({
    required this.initials,
    required this.employeeName,
    required this.action,
    required this.time,
    required this.status,
    required this.category,
    required this.avatarColor,
    required this.accentColor,
    required this.sortAt,
  });

  final String initials;
  final String employeeName;
  final String action;
  final String time;
  final String status;
  final String category;
  final Color avatarColor;
  final Color accentColor;
  final DateTime? sortAt;
}

class _Ui {
  const _Ui();

  static const Color navy = Color(0xFF03233D);
  static const Color blue = Color(0xFF1616E8);
  static const Color chartBlue = Color(0xFF1919E5);
  static const Color green = Color(0xFF3B9A50);
  static const Color brown = Color(0xFF9A601F);
  static const Color red = Color(0xFFC72931);

  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textMuted = Color(0xFF596273);
  static const Color border = Color(0xFFD9DAE1);
  static const Color divider = Color(0xFFE9E9ED);

  static const TextStyle pageTitle = TextStyle(
    color: textPrimary,
    fontSize: 18,
    height: 1.15,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
  );

  static const TextStyle pageSubtitle = TextStyle(
    color: textMuted,
    fontSize: 9,
    height: 1.35,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle panelTitle = TextStyle(
    color: textPrimary,
    fontSize: 10,
    height: 1.2,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle panelSubtitle = TextStyle(
    color: textMuted,
    fontSize: 8,
    height: 1.3,
    fontWeight: FontWeight.w500,
  );
}
