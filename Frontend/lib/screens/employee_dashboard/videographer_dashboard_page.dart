// lib/screens/employee_dashboard/videographer_dashboard_page.dart
// Videographer / Video Editor dashboard — layout and work tables live in role_dashboard.dart
// (shared by every role, so all dashboards stay the same).
import 'package:flutter/material.dart';

import 'role_dashboard.dart';

class VideographerDashboardPage extends StatelessWidget {
  final VoidCallback? onOpenAssignedTask;
  final VoidCallback? onViewAllNotifications;

  /// Opens a task in Employee Workspace: {client, due_date, section}.
  final ValueChanged<Map<String, dynamic>>? onOpenWorkspace;

  const VideographerDashboardPage({
    super.key,
    this.onOpenAssignedTask,
    this.onViewAllNotifications,
    this.onOpenWorkspace,
  });

  @override
  Widget build(BuildContext context) => RoleDashboard(
        roleLabel: null,
        holdTitle: 'Holded Shoots',
        isHandler: false,
        onOpenAssignedTask: onOpenAssignedTask,
        onViewAllNotifications: onViewAllNotifications,
        onOpenWorkspace: onOpenWorkspace,
      );
}
