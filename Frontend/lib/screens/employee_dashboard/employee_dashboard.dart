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
import 'package:my_first_app/screens/notifications_screen.dart';
import 'package:my_first_app/screens/employee_dashboard/daily_reports_page.dart';
import 'package:my_first_app/screens/employee_dashboard/task_planner_page.dart';
import 'package:my_first_app/screens/employee_dashboard/feedback_page.dart';

class EmployeeLayoutPage extends StatefulWidget {
  const EmployeeLayoutPage({super.key});

  @override
  State<EmployeeLayoutPage> createState() => _EmployeeLayoutPageState();
}

class _EmployeeLayoutPageState extends State<EmployeeLayoutPage> {
  String selectedMenu = 'Dashboard';

  /// Convert actual database role strings to EmployeeRole enum
  /// Handles: 'UI/ UX Designer', 'Graphic Designer', 'Digital Marketing', 
  ///          'Video Editor', 'Web Developer'
  // EmployeeRole _getRoleFromString(String? roleString) {
  //   if (roleString == null) {
  //     debugPrint('⚠️ WARNING: Role is null, defaulting to designer');
  //     return EmployeeRole.designer;
  //   }

  //   final role = roleString.toLowerCase().trim();
  //   debugPrint('🔍 Role mapping: "$roleString" → role string: "$role"');

  //   // Designer roles (UI/UX Designer, Graphic Designer, Web Developer)
  //   if (role.contains('ui') || 
  //       role.contains('ux') || 
  //       role.contains('graphic') ||
  //       role.contains('designer')) {
  //     debugPrint('✅ Mapped to: EmployeeRole.designer');
  //     return EmployeeRole.designer;
  //   }

  //   // Video Editor
  //   if (role.contains('video') || role.contains('editor')) {
  //     debugPrint('✅ Mapped to: EmployeeRole.videographer');
  //     return EmployeeRole.videographer;
  //   }

  //   // Digital Marketing (map to ads handler or page handler)
  //   if (role.contains('marketing') || role.contains('digital')) {
  //     debugPrint('✅ Mapped to: EmployeeRole.adsHandler');
  //     return EmployeeRole.adsHandler; // or EmployeeRole.adsHandler depending on your preference
  //   }

  //   // Page Handler
  //   if (role.contains('page') || role.contains('handler')) {
  //     debugPrint('✅ Mapped to: EmployeeRole.pageHandler');
  //     return EmployeeRole.pageHandler;
  //   }

  //   // Web Developer
  //   if (role.contains('web') || role.contains('developer')) {
  //     debugPrint('✅ Mapped to: EmployeeRole.designer');
  //     return EmployeeRole.designer;
  //   }

  //   // Default fallback
  //   debugPrint('⚠️ Unknown role "$roleString", defaulting to designer');
  //   return EmployeeRole.designer;
  // }

EmployeeRole _getRoleFromString(String? roleString) {
  if (roleString == null) return EmployeeRole.designer;

  final role = roleString.toLowerCase().trim();

  // 1. First Ads Handler (Ads, Marketing check)
  if (role.contains('ads') || role.contains('marketing')) {
    return EmployeeRole.adsHandler;
  }

  // 2. Video related
  if (role.contains('video') || role.contains('editor')) {
    return EmployeeRole.videographer;
  }

  // 3. Page Handler (GMB, Social Media)
  if (role.contains('page') || role.contains('handler') || role.contains('gmb')) {
    return EmployeeRole.pageHandler;
  }

  // 4. Designer / Web (Designer, UI/UX, Dev)
  if (role.contains('ui') || role.contains('ux') || role.contains('graphic') || role.contains('designer') || role.contains('web')) {
    return EmployeeRole.designer;
  }

  return EmployeeRole.designer; // Default
}

  Widget getDashboardByRole(EmployeeRole loggedInRole) {
    switch (loggedInRole) {
      case EmployeeRole.designer:
        return DesignerDashboardPage(
          onOpenAssignedTask: () {
            setState(() {
              selectedMenu = 'Assigned Task';
            });
          },
        );

      case EmployeeRole.pageHandler:
        return PageHandlerDashboardPage(
          onOpenAssignedTask: () {
            setState(() {
              selectedMenu = 'Assigned Task';
            });
          },
        );

      case EmployeeRole.adsHandler:
        return AdsHandlerDashboardPage(
          onOpenAssignedTask: () {
            setState(() {
              selectedMenu = 'Assigned Task';
            });
          },
        );

      case EmployeeRole.videographer:
        return VideographerDashboardPage(
          onOpenAssignedTask: () {
            setState(() {
              selectedMenu = 'Assigned Task';
            });
          },
        );
    }
  }

  Widget getSelectedPage(EmployeeRole loggedInRole) {
    if (selectedMenu == 'Dashboard') {
      return getDashboardByRole(loggedInRole);
    }

    if (selectedMenu == 'Assigned Task') {
      return AssignedTasksContent(role: loggedInRole);
    }

    if (selectedMenu == 'Daily Reports') {
      return const DailyReportsPage();
    }

    if (selectedMenu == 'Task Planner') {
      return const TaskPlannerPage();
    }

    if (selectedMenu == 'Notifications') {
      return const NotificationsScreen();
    }

    if (selectedMenu == 'Feedback') {
      return const FeedbackPage();
    }

    return Center(
      child: Text(
        '$selectedMenu Page Coming Soon',
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        // Check if user is authenticated
        if (!authService.isAuthenticated || authService.user == null) {
          // User not authenticated, redirect to login
          Future.microtask(() {
            Navigator.pushReplacementNamed(context, '/');
          });
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Get the logged-in user's role from backend
        final rawRole = authService.userRole;
        debugPrint('📱 Raw role from backend: "$rawRole"');
        
        final loggedInRole = _getRoleFromString(rawRole);
        debugPrint('🎯 Final EmployeeRole: $loggedInRole');

        return Scaffold(
          body: Row(
            children: [
              EmployeeSidebar(
                selectedMenu: selectedMenu,
                menuItems: loggedInRole.menuItems,
                onMenuTap: (menu) {
                  setState(() {
                    selectedMenu = menu;
                  });
                },
              ),
              Expanded(
                child: Column(
                  children: [
                    EmployeeTopbar(role: loggedInRole),
                    Expanded(
                      child: getSelectedPage(loggedInRole),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}