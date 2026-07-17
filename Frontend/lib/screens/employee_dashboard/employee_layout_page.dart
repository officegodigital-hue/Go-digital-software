import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:my_first_app/core/constants/employee_role.dart';
import 'package:my_first_app/core/widgets/employee_sidebar.dart';
import 'package:my_first_app/core/widgets/employee_topbar.dart';
import 'package:my_first_app/services/auth_service.dart';

import 'package:my_first_app/screens/employee_dashboard/designer_dashboard_page.dart';
import 'package:my_first_app/screens/employee_dashboard/page_handler_dashboard_page.dart';
import 'package:my_first_app/screens/employee_dashboard/ads_handler_dashboard_page.dart';
import 'package:my_first_app/screens/employee_dashboard/videographer_dashboard_page.dart';

import 'package:my_first_app/screens/employee_dashboard/assigned_tasks_page.dart';
import 'package:my_first_app/screens/employee_dashboard/day_planner_screen.dart';
import 'package:my_first_app/screens/employee_dashboard/notification_page.dart';
import 'package:my_first_app/screens/employee_dashboard/daily_reports_page.dart';
import 'package:my_first_app/screens/employee_dashboard/task_planner_page.dart';
import 'package:my_first_app/screens/employee_dashboard/feedback_page.dart';
// ← ADD THIS IMPORT for the videographer task planner
import 'package:my_first_app/screens/employee_dashboard/videographer_task_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmployeeLayoutPage extends StatefulWidget {
  const EmployeeLayoutPage({super.key});

  @override
  State<EmployeeLayoutPage> createState() => _EmployeeLayoutPageState();
}

class _EmployeeLayoutPageState extends State<EmployeeLayoutPage> {
  String selectedMenu = 'Dashboard';
  Future<void> loadMenu() async {
  final prefs = await SharedPreferences.getInstance();

  setState(() {
    selectedMenu = prefs.getString('employeeMenu') ?? 'Dashboard';
  });
}

Future<void> saveMenu(String menu) async {
  final prefs = await SharedPreferences.getInstance();

  await prefs.setString('employeeMenu', menu);

  setState(() {
    selectedMenu = menu;
  });
}
@override
void initState() {
  super.initState();
  loadMenu();
}

  EmployeeRole _getRoleFromString(String? roleString) {
    if (roleString == null) return EmployeeRole.designer;

    final role = roleString.toLowerCase().trim();

    if (role.contains('ads') || role.contains('marketing')) {
      return EmployeeRole.adsHandler;
    }
    if (role.contains('video') || role.contains('editor')) {
      return EmployeeRole.videographer;
    }
    if (role.contains('page') || role.contains('handler') || role.contains('gmb')) {
      return EmployeeRole.pageHandler;
    }
    if (role.contains('ui') || role.contains('ux') || role.contains('graphic') ||
        role.contains('designer') || role.contains('web')) {
      return EmployeeRole.designer;
    }
    return EmployeeRole.designer;
  }

  Widget getDashboardByRole(EmployeeRole loggedInRole) {
    switch (loggedInRole) {
      case EmployeeRole.designer:
        return DesignerDashboardPage(
          onOpenAssignedTask: () => setState(() => selectedMenu = 'Assigned Task'),
        );
      case EmployeeRole.pageHandler:
        return PageHandlerDashboardPage(
          onOpenAssignedTask: () => setState(() => selectedMenu = 'Assigned Task'),
        );
      case EmployeeRole.adsHandler:
        return AdsHandlerDashboardPage(
          onOpenAssignedTask: () => setState(() => selectedMenu = 'Assigned Task'),
        );
      case EmployeeRole.videographer:
        return VideographerDashboardPage(
          onOpenAssignedTask: () => setState(() => selectedMenu = 'Assigned Task'),
        );
    }
  }

  Widget getSelectedPage(EmployeeRole loggedInRole) {
    switch (selectedMenu) {
      case 'Dashboard':
        return getDashboardByRole(loggedInRole);

      case 'Day Planner':
        return const DayPlannerScreen();

      case 'Assigned Task':
        return AssignedTasksContent(role: loggedInRole);

      case 'Daily Reports':
        return const DailyReportsPage();

      case 'Task Planner':
        return const TaskPlannerPage();

      case 'Video Task Planner':
        return const VideographerTaskPlannerPage();

      case 'Notifications':
        return const NotificationsScreen();

      case 'Feedback':
        return const FeedbackPage();

      default:
        return Center(
          child: Text(
            '$selectedMenu Page Coming Soon',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {

        if (!authService.isInitialized) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      
      if (!authService.isAuthenticated) {
        Future.microtask(() => Navigator.pushReplacementNamed(context, '/'));
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }

        // if (!authService.isAuthenticated || authService.user == null) {
        //   Future.microtask(() => Navigator.pushReplacementNamed(context, '/'));
        //   return const Scaffold(body: Center(child: CircularProgressIndicator()));
        // }

        final rawRole    = authService.userRole;
        final loggedInRole = _getRoleFromString(rawRole);
        debugPrint('🎯 Role: $loggedInRole');

        return Scaffold(
          body: Row(children: [
            EmployeeSidebar(
              selectedMenu: selectedMenu,
              menuItems:    loggedInRole.menuItems,
              onMenuTap: saveMenu,
            ),
            Expanded(child: Column(children: [
              EmployeeTopbar(role: loggedInRole),
              Expanded(child: getSelectedPage(loggedInRole)),
            ])),
          ]),
        );
      },
    );
  }
}