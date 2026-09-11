import 'package:flutter/material.dart';

import '../attendance/attendance_dashboard_section.dart';
import '../shared/employee_ui.dart';

class EmployeeDashboardPage extends StatefulWidget {
  const EmployeeDashboardPage({super.key});
  @override
  State<EmployeeDashboardPage> createState() => _EmployeeDashboardPageState();
}

class _EmployeeDashboardPageState extends State<EmployeeDashboardPage> {
  bool menuOpen = false;
  static const routes = <String>{
    '/employee/dashboard',
    '/employee/attendance',
    '/employee/clock-log',
    '/employee/leave',
    '/employee/permission',
    '/employee/extra-hours',
    '/employee/salary',
    '/employee/tracking',
  };
  void go(String route) {
    setState(() => menuOpen = false);
    if (routes.contains(route))
      Navigator.pushNamed(context, route);
    else
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This page is not available yet.')));
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
        body: SafeArea(
            child: Stack(children: [
      Column(children: [
        _Header(
            mobile: mobile,
            open: menuOpen,
            onMenu: () => setState(() => menuOpen = !menuOpen)),
        Expanded(
            child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              mobile ? 18 : 36, mobile ? 24 : 34, mobile ? 18 : 36, 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: const _Content(),
          ),
        )),
      ]),
      if (menuOpen)
        _Menu(onClose: () => setState(() => menuOpen = false), onSelect: go),
    ])));
  }
}

class _Header extends StatelessWidget {
  const _Header(
      {required this.mobile, required this.open, required this.onMenu});
  final bool mobile, open;
  final VoidCallback onMenu;
  @override
  Widget build(BuildContext context) => Container(
        height: mobile ? 78 : 88,
        padding: EdgeInsets.symmetric(horizontal: mobile ? 18 : 36),
        decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE7EDF7))),
            boxShadow: [
              BoxShadow(
                  color: Color(0x0D102C5A),
                  blurRadius: 14,
                  offset: Offset(0, 4))
            ]),
        child: Row(children: [
          Image.asset('assets/images/godigital_logo.png',
              height: mobile ? 45 : 53,
              width: mobile ? 136 : 164,
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft),
          const Spacer(),
          if (!mobile) ...[
            const Text('Employee Portal',
                style: TextStyle(color: employeeMuted)),
            const SizedBox(width: 24)
          ],
          const EmployeeNotificationButton(),
          const SizedBox(width: 18),
          const EmployeeProfileMenu(radius: 25),
        ]),
      );
}

class _Content extends StatelessWidget {
  const _Content();
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AttendanceDashboardSection(),
        const SizedBox(height: 18),
        const _Actions(
            'ATTENDANCE', employeeBlue, Icons.calendar_month_outlined, [
          ('Calendar', Icons.calendar_today_outlined, '/employee/attendance'),
          ('Clock Log', Icons.history_rounded, '/employee/clock-log')
        ]),
        const SizedBox(height: 12),
        const _Actions('LEAVE', Color(0xFF6C36E8), Icons.eco_outlined, [
          ('Apply Leave', Icons.note_add_outlined, '/employee/leave'),
          ('My Requests', Icons.assignment_outlined, '/employee/leave')
        ]),
        const SizedBox(height: 12),
        const _Actions(
            'PERMISSION', Color(0xFF5B35D5), Icons.verified_user_outlined, [
          (
            'Apply Permission',
            Icons.verified_user_outlined,
            '/employee/permission'
          ),
          ('View Log', Icons.history_rounded, '/employee/permission')
        ]),
        const SizedBox(height: 12),
        const _Actions('EXTRA HOURS', employeeOrange, Icons.more_time_rounded, [
          ('Log Hours', Icons.more_time_rounded, '/employee/extra-hours'),
          ('0h', Icons.timelapse_rounded, null)
        ]),
        const SizedBox(height: 12),
        const _Actions(
            'SALARY', Color(0xFF07368D), Icons.currency_rupee_rounded, [
          ('Net Pay ₹37,846', Icons.currency_rupee_rounded, null),
          ('View Payslip', Icons.description_outlined, '/employee/salary')
        ]),
        const SizedBox(height: 12),
        const _Actions(
            'TRACKING', Color(0xFF079B9B), Icons.location_on_outlined, [
          ('Live Tracking', Icons.location_on_outlined, '/employee/tracking'),
          ('Route History', Icons.map_outlined, '/employee/tracking')
        ]),
      ]);
}

class _Actions extends StatelessWidget {
  const _Actions(this.title, this.color, this.icon, this.actions);
  final String title;
  final Color color;
  final IconData icon;
  final List<(String, IconData, String?)> actions;
  @override
  Widget build(BuildContext context) => EmployeeCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
                color: color,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14))),
            child: Row(children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 14),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800))
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: _ActionTile(action: actions[i], color: color)),
              ],
            ]),
          ),
        ]),
      );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action, required this.color});
  final (String, IconData, String?) action;
  final Color color;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: action.$3 == null
            ? null
            : () => Navigator.pushNamed(context, action.$3!,
                arguments: switch (action.$1) {
                  'Route History' => 'history',
                  'View Log' => 'log',
                  'My Requests' => 'requests',
                  _ => null
                }),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
          decoration: BoxDecoration(
              border: Border.all(color: employeeLine),
              borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Icon(action.$2, color: color),
            const SizedBox(width: 10),
            Expanded(
                child: Text(action.$1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: employeeNavy, fontWeight: FontWeight.w600))),
            if (action.$3 != null)
              const Icon(Icons.chevron_right_rounded, color: employeeNavy),
          ]),
        ),
      );
}

class _Menu extends StatelessWidget {
  const _Menu({required this.onClose, required this.onSelect});
  final VoidCallback onClose;
  final ValueChanged<String> onSelect;
  static const items = [
    ('Dashboard', Icons.grid_view_rounded, '/employee/dashboard'),
    ('Attendance', Icons.calendar_month_outlined, '/employee/attendance'),
    ('Clock In / Out', Icons.schedule_rounded, '/employee/clock-log'),
    ('Leave', Icons.description_outlined, '/employee/leave'),
    ('Permission', Icons.verified_user_outlined, '/employee/permission'),
    ('Extra Hours', Icons.more_time_rounded, '/employee/extra-hours'),
    ('Salary', Icons.currency_rupee_rounded, '/employee/salary'),
    ('Tracking', Icons.location_on_outlined, '/employee/tracking')
  ];
  @override
  Widget build(BuildContext context) => Stack(children: [
        GestureDetector(
            onTap: onClose, child: Container(color: const Color(0x4A07143F))),
        Align(
            alignment: Alignment.centerRight,
            child: Material(
                color: Colors.white,
                elevation: 24,
                child: SafeArea(
                    child: SizedBox(
                        width: MediaQuery.sizeOf(context)
                            .width
                            .clamp(280.0, 350.0),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(22, 19, 12, 15),
                                  child: Row(children: [
                                    const Expanded(
                                        child: Text('Menu',
                                            style: TextStyle(
                                                color: employeeNavy,
                                                fontSize: 20,
                                                fontWeight: FontWeight.w800))),
                                    IconButton(
                                        onPressed: onClose,
                                        icon: const Icon(Icons.close_rounded,
                                            color: employeeNavy))
                                  ])),
                              const Divider(height: 1, color: employeeLine),
                              const SizedBox(height: 8),
                              ...items.map((item) => InkWell(
                                  onTap: () => onSelect(item.$3),
                                  child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 23, vertical: 15),
                                      child: Row(children: [
                                        Icon(item.$2,
                                            color: employeeBlue, size: 22),
                                        const SizedBox(width: 16),
                                        Text(item.$1,
                                            style: const TextStyle(
                                                color: employeeNavy,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600))
                                      ]))))
                            ])))))
      ]);
}
