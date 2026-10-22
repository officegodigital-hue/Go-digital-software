// lib/screens/employee_dashboard/designer_dashboard_page.dart
// Designer dashboard — layout and work tables live in role_dashboard.dart
// (shared by every role, so all dashboards stay the same).
import 'package:flutter/material.dart';

import 'role_dashboard.dart';

class DesignerDashboardPage extends StatelessWidget {
  final VoidCallback? onOpenAssignedTask;
  final VoidCallback? onViewAllNotifications;

  /// Opens a task in Employee Workspace: {client, due_date, section}.
  final ValueChanged<Map<String, dynamic>>? onOpenWorkspace;

  const DesignerDashboardPage({
    super.key,
    this.onOpenAssignedTask,
    this.onViewAllNotifications,
    this.onOpenWorkspace,
  });

  @override
  Widget build(BuildContext context) => RoleDashboard(
        roleLabel: null,
        holdTitle: 'Hold Task',
        isHandler: false,
        onOpenAssignedTask: onOpenAssignedTask,
        onViewAllNotifications: onViewAllNotifications,
        onOpenWorkspace: onOpenWorkspace,
      );
}
