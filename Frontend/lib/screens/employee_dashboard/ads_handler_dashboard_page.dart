// lib/screens/employee_dashboard/ads_handler_dashboard_page.dart
// Ads Handler dashboard — layout and work tables live in role_dashboard.dart
// (shared by every role, so all dashboards stay the same).
import 'package:flutter/material.dart';

import 'role_dashboard.dart';

class AdsHandlerDashboardPage extends StatelessWidget {
  final VoidCallback? onOpenAssignedTask;
  final VoidCallback? onViewAllNotifications;

  /// Opens a task in Employee Workspace: {client, due_date, section}.
  final ValueChanged<Map<String, dynamic>>? onOpenWorkspace;

  const AdsHandlerDashboardPage({
    super.key,
    this.onOpenAssignedTask,
    this.onViewAllNotifications,
    this.onOpenWorkspace,
  });

  @override
  Widget build(BuildContext context) => RoleDashboard(
        roleLabel: 'ADS HANDLER',
        holdTitle: 'Hold Task',
        isHandler: true,
        onOpenAssignedTask: onOpenAssignedTask,
        onViewAllNotifications: onViewAllNotifications,
        onOpenWorkspace: onOpenWorkspace,
      );
}
