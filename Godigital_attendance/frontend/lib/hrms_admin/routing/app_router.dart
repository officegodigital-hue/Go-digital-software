import 'package:flutter/material.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/clock_logs/clock_logs_page.dart';
import '../features/employees/employees_page.dart';
import '../features/approvals/approvals_page.dart';
import '../features/payroll/payroll_page.dart';
import '../features/tracking/tracking_page.dart';
import '../features/settings/settings_page.dart';

/// Routes per HRMS_PROJECT_BLUEPRINT.md, Section 1 (Approved Admin pages).
/// One "Approvals" route covers Leave + Extra Hours; there is no separate
/// Admin Attendance route (Manage Calendar is a Dashboard modal).
class AppRouter {
  AppRouter._();

  static final Map<String, WidgetBuilder> routes = {
    '/admin/dashboard': DashboardPage.builder,
    '/admin/clock-logs': ClockLogsPage.builder,
    // Reference-friendly alias; the existing clock-log implementation is
    // reused so attendance behavior and API calls remain unchanged.
    '/admin/attendance': ClockLogsPage.builder,
    '/admin/employees': EmployeesPage.builder,
    '/admin/approvals': ApprovalsPage.builder,
    // Leave currently shares the existing approvals workflow.
    '/admin/leave': ApprovalsPage.builder,
    '/admin/payroll': PayrollPage.builder,
    '/admin/tracking': TrackingPage.builder,
    // Performance currently reuses the existing tracking analytics page.
    '/admin/performance': TrackingPage.builder,
    '/admin/settings': SettingsPage.builder,
  };
}
