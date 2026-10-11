import 'package:flutter/material.dart';

import '../../shared/widgets/admin_top_nav.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  static Widget builder(BuildContext context) => const SettingsPage();

  void _open(BuildContext context, String route, String action) {
    Navigator.pushReplacementNamed(context, route, arguments: {'settingsAction': action});
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FD),
      bottomNavigationBar: mobile ? const AdminMobileBottomNav(activeRoute: '/admin/settings') : null,
      body: Column(children: [
        const AdminTopNav(activeRoute: '/admin/settings'),
        Expanded(child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(mobile ? 16 : 28, 18, mobile ? 16 : 28, 28),
          child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1320),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const AdminPageHeader(title: 'Settings'),
              const SizedBox(height: 20),
              LayoutBuilder(builder: (context, constraints) {
                final width = mobile ? constraints.maxWidth : (constraints.maxWidth - 16) / 2;
                return Wrap(spacing: 16, runSpacing: 16, children: [
                  _SettingsCategory(width: width, title: 'Dashboard', icon: Icons.dashboard_outlined, items: [
                    _SettingsAction('Manage Time', Icons.schedule_outlined, () => _open(context, '/admin/dashboard', 'manageTime')),
                    _SettingsAction('Manage Calendar', Icons.edit_calendar_outlined, () => _open(context, '/admin/dashboard', 'manageCalendar')),
                  ]),
                  _SettingsCategory(width: width, title: 'Employees', icon: Icons.groups_outlined, items: [
                    _SettingsAction('Device Requests', Icons.phonelink_lock_outlined, () => _open(context, '/admin/employees', 'deviceRequests')),
                    _SettingsAction('Leave Policy', Icons.event_available_outlined, () => _open(context, '/admin/employees', 'leavePolicy')),
                    _SettingsAction('Add Employee', Icons.person_add_alt_1_outlined, () => _open(context, '/admin/employees', 'addEmployee'), primary: true),
                  ]),
                  _SettingsCategory(width: width, title: 'Payroll', icon: Icons.account_balance_wallet_outlined, items: [
                    _SettingsAction('Payroll Policy', Icons.receipt_long_outlined, () => _open(context, '/admin/payroll', 'payrollPolicy')),
                  ]),
                  _SettingsCategory(width: width, title: 'Tracking', icon: Icons.location_on_outlined, items: [
                    _SettingsAction('Manage Office Location', Icons.business_outlined, () => _open(context, '/admin/tracking', 'officeLocation')),
                    _SettingsAction('Tracking Settings', Icons.timer_outlined, () => _open(context, '/admin/tracking', 'trackingSettings')),
                  ]),
                  _SettingsCategory(width: width, title: 'Notifications', icon: Icons.notifications_outlined, items: [
                    _SettingsAction('Notification Settings', Icons.tune_rounded, () => showAdminNotificationSettings(context)),
                  ]),
                ]);
              }),
            ]),
          )),
        )),
      ]),
    );
  }
}

class _SettingsAction {
  const _SettingsAction(this.label, this.icon, this.onTap, {this.primary = false});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;
}

class _SettingsCategory extends StatelessWidget {
  const _SettingsCategory({required this.width, required this.title, required this.icon, required this.items});
  final double width;
  final String title;
  final IconData icon;
  final List<_SettingsAction> items;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFDCE5F2)), borderRadius: BorderRadius.circular(14)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 42, height: 42, decoration: const BoxDecoration(color: Color(0xFFEAF2FF), shape: BoxShape.circle), child: Icon(icon, color: const Color(0xFF075EF7))),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(color: Color(0xFF061457), fontSize: 19, fontWeight: FontWeight.w800)),
      ]),
      const SizedBox(height: 14),
      ...items.map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(color: item.primary ? const Color(0xFF075EF7) : Colors.white, borderRadius: BorderRadius.circular(9), child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
            decoration: BoxDecoration(border: item.primary ? null : Border.all(color: const Color(0xFFDDE5F0)), borderRadius: BorderRadius.circular(9)),
            child: Row(children: [
              Icon(item.icon, size: 20, color: item.primary ? Colors.white : const Color(0xFF061457)),
              const SizedBox(width: 11),
              Expanded(child: Text(item.label, style: TextStyle(color: item.primary ? Colors.white : const Color(0xFF061457), fontWeight: FontWeight.w600))),
              Icon(Icons.chevron_right_rounded, color: item.primary ? Colors.white : const Color(0xFF61708C)),
            ]),
          ),
        )),
      )),
    ]),
  );
}
