import 'package:flutter/material.dart';

import '../../shared/widgets/admin_top_nav.dart';
import '../employees/leave_policy_dialog.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static Widget builder(BuildContext context) => const SettingsPage();

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FD),
      body: Column(
        children: [
          const AdminTopNav(activeRoute: '/admin/settings'),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  mobile ? 16 : 28, 18, mobile ? 16 : 28, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1580),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AdminPageHeader(title: 'Settings'),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFE3E7EF)),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Administration settings',
                                style: TextStyle(
                                    color: Color(0xFF11131A),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700)),
                            SizedBox(height: 7),
                            Text(
                              'Company policies, notifications and account preferences will be managed here.',
                              style: TextStyle(
                                  color: Color(0xFF596176), fontSize: 14),
                            ),
                            SizedBox(height: 18),
                            Divider(),
                            SizedBox(height: 14),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.event_available_outlined, color: Color(0xFF155EEF)),
                              title: Text('Leave Card Settings', style: TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text('Choose names, allowances, visibility and employee card layout.'),
                              trailing: Icon(Icons.chevron_right_rounded),
                              onTap: () => showDialog(context: context, builder: (_) => const LeavePolicyDialog()),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
