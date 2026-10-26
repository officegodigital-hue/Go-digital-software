import 'package:flutter/material.dart';

import '../../shared/widgets/admin_top_nav.dart';
import '../../shared/widgets/admin_page_scroll_view.dart';
import '../employees/leave_policy_dialog.dart';
import '../payroll/payroll_page.dart';
import '../dashboard/widgets/manage_time_dialog.dart';
import '../dashboard/widgets/manage_calendar_dialog.dart';
import '../tracking/tracking_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static Widget builder(BuildContext context) => const SettingsPage();

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final mobile = w < 650;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FD),
      bottomNavigationBar: const AdminMobileBottomNav(activeRoute: '/admin/settings'),
      body: Column(
        children: [
          const AdminTopNav(activeRoute: '/admin/settings'),
          Expanded(
            child: AdminPageScrollView(
              padding: EdgeInsets.fromLTRB(
                  mobile ? 14 : 28, mobile ? 14 : 20, mobile ? 14 : 28, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: mobile
                      ? _MobileLayout(context: context)
                      : _DesktopLayout(context: context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Desktop layout ──────────────────────────────────────────────────────────

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({required this.context});
  final BuildContext context;

  @override
  Widget build(BuildContext ctx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Settings',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0D1330))),
                  SizedBox(height: 4),
                  Text('Configure attendance, payroll and tracking rules.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF596176))),
                  SizedBox(height: 6),
                  _Breadcrumb(),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Top row: Time & Calendar | Policies
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _DesktopSection(
                  label: 'Time & Calendar',
                  tiles: [
                    _DesktopTile(
                      icon: Icons.schedule_rounded,
                      iconColor: const Color(0xFF075EF7),
                      iconBg: const Color(0xFFEAF1FF),
                      title: 'Manage Time',
                      subtitle: 'Shift hours, late thresholds and overtime rules.',
                      onTap: () => showManageTimeDialog(context),
                    ),
                    _DesktopTile(
                      icon: Icons.edit_calendar_outlined,
                      iconColor: const Color(0xFF075EF7),
                      iconBg: const Color(0xFFEAF1FF),
                      title: 'Manage Calendar',
                      subtitle: 'Holidays and non-working days for the month.',
                      onTap: () => showManageCalendarDialog(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: _DesktopSection(
                  label: 'Policies',
                  tiles: [
                    _DesktopTile(
                      icon: Icons.event_available_outlined,
                      iconColor: const Color(0xFF0E7A45),
                      iconBg: const Color(0xFFE6F4EE),
                      title: 'Leave Policy',
                      subtitle: 'Leave types, allowances and deduction rules.',
                      onTap: () => showDialog(
                          context: context,
                          builder: (_) => const LeavePolicyDialog()),
                    ),
                    _DesktopTile(
                      icon: Icons.receipt_long_outlined,
                      iconColor: const Color(0xFF0E7A45),
                      iconBg: const Color(0xFFE6F4EE),
                      title: 'Payroll Policy',
                      subtitle: 'Weekly off days and absence deduction rules.',
                      onTap: () => showDialog<bool>(
                          context: context,
                          builder: (_) => const PayrollPolicyDialog()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Full-width: Location & Tracking (2-column grid inside)
        _DesktopSection(
          label: 'Location & Tracking',
          gridItems: [
            _DesktopTile(
              icon: Icons.gps_fixed_rounded,
              iconColor: const Color(0xFF5B2ECC),
              iconBg: const Color(0xFFEEE9FB),
              title: 'Office Location',
              subtitle: 'Office address and employee check-in radius.',
              onTap: () => showOfficeLocationDialog(context),
            ),
            _DesktopTile(
              icon: Icons.tune_rounded,
              iconColor: const Color(0xFF5B2ECC),
              iconBg: const Color(0xFFEEE9FB),
              title: 'Hybrid Settings',
              subtitle: 'Employees allowed to work from home or remotely.',
              onTap: () => showHybridSettingsDialog(context),
            ),
            _DesktopTile(
              icon: Icons.home_outlined,
              iconColor: const Color(0xFF5B2ECC),
              iconBg: const Color(0xFFEEE9FB),
              title: 'Home Approvals',
              subtitle: 'Review and approve home work-location requests.',
              onTap: () => showHomeApprovalsDialog(context),
            ),
          ],
        ),
      ],
    );
  }
}

class _DesktopSection extends StatelessWidget {
  const _DesktopSection({
    required this.label,
    this.tiles,
    this.gridItems,
  });
  final String label;
  final List<_DesktopTile>? tiles;
  final List<_DesktopTile>? gridItems;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE3E7EF)),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x07061457),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 10),
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF596176),
                  letterSpacing: 0.9),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFECEFF5)),
          if (tiles != null)
            ...List.generate(tiles!.length, (i) => Column(children: [
              tiles![i],
              if (i < tiles!.length - 1)
                const Divider(height: 1, indent: 76, color: Color(0xFFF0F3F9)),
            ])),
          if (gridItems != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: _GridTiles(items: gridItems!),
            ),
        ],
      ),
    );
  }
}

class _GridTiles extends StatelessWidget {
  const _GridTiles({required this.items});
  final List<_DesktopTile> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 500 ? 2 : 1;
      final rows = <Widget>[];
      for (var i = 0; i < items.length; i += cols) {
        final rowItems = items.sublist(i, (i + cols).clamp(0, items.length));
        rows.add(Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var j = 0; j < rowItems.length; j++) ...[
              Expanded(child: _GridCard(tile: rowItems[j])),
              if (j < rowItems.length - 1) const SizedBox(width: 12),
            ],
            if (rowItems.length < cols)
              ...[const SizedBox(width: 12), const Expanded(child: SizedBox())],
          ],
        ));
        if (i + cols < items.length) rows.add(const SizedBox(height: 12));
      }
      return Column(children: rows);
    });
  }
}

class _GridCard extends StatelessWidget {
  const _GridCard({required this.tile});
  final _DesktopTile tile;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: tile.onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFECEFF5)),
        borderRadius: BorderRadius.circular(10),
        color: const Color(0xFFFAFBFD),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: tile.iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(tile.icon, color: tile.iconColor, size: 21),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tile.title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF11131A))),
            const SizedBox(height: 3),
            Text(tile.subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF596176), height: 1.4)),
          ]),
        ),
        const SizedBox(width: 6),
        const Icon(Icons.chevron_right_rounded, color: Color(0xFFB0B8CC), size: 22),
      ]),
    ),
  );
}

class _DesktopTile extends StatelessWidget {
  const _DesktopTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color iconColor, iconBg;
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF11131A))),
            const SizedBox(height: 3),
            Text(subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF596176), height: 1.4)),
          ]),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.chevron_right_rounded, color: Color(0xFFB0B8CC), size: 22),
      ]),
    ),
  );
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb();
  @override
  Widget build(BuildContext context) => Row(
    children: [
      GestureDetector(
        onTap: () => Navigator.pushReplacementNamed(context, '/admin/dashboard'),
        child: const Text('Home',
            style: TextStyle(fontSize: 12, color: Color(0xFF075EF7), fontWeight: FontWeight.w500)),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFF9BA8C0)),
      ),
      const Text('Settings',
          style: TextStyle(fontSize: 12, color: Color(0xFF596176), fontWeight: FontWeight.w500)),
    ],
  );
}

// ── Mobile layout ────────────────────────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({required this.context});
  final BuildContext context;

  @override
  Widget build(BuildContext ctx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Settings',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0D1330))),
        const SizedBox(height: 14),
        _MobileSection(
          label: 'Time & Calendar',
          tiles: [
            _MobileTile(
              icon: Icons.schedule_rounded,
              iconColor: const Color(0xFF075EF7),
              iconBg: const Color(0xFFEAF1FF),
              title: 'Manage Time',
              subtitle: 'Shift hours, late thresholds and overtime.',
              onTap: () => showManageTimeDialog(context),
            ),
            _MobileTile(
              icon: Icons.edit_calendar_outlined,
              iconColor: const Color(0xFF075EF7),
              iconBg: const Color(0xFFEAF1FF),
              title: 'Manage Calendar',
              subtitle: 'Holidays and non-working days.',
              onTap: () => showManageCalendarDialog(context),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _MobileSection(
          label: 'Policies',
          tiles: [
            _MobileTile(
              icon: Icons.event_available_outlined,
              iconColor: const Color(0xFF0E7A45),
              iconBg: const Color(0xFFE6F4EE),
              title: 'Leave Policy',
              subtitle: 'Leave types, allowances and deduction.',
              onTap: () => showDialog(
                  context: context, builder: (_) => const LeavePolicyDialog()),
            ),
            _MobileTile(
              icon: Icons.receipt_long_outlined,
              iconColor: const Color(0xFF0E7A45),
              iconBg: const Color(0xFFE6F4EE),
              title: 'Payroll Policy',
              subtitle: 'Weekly off days and absence deduction.',
              onTap: () => showDialog<bool>(
                  context: context, builder: (_) => const PayrollPolicyDialog()),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _MobileSection(
          label: 'Location & Tracking',
          tiles: [
            _MobileTile(
              icon: Icons.gps_fixed_rounded,
              iconColor: const Color(0xFF5B2ECC),
              iconBg: const Color(0xFFEEE9FB),
              title: 'Office Location',
              subtitle: 'Address and check-in radius.',
              onTap: () => showOfficeLocationDialog(context),
            ),
            _MobileTile(
              icon: Icons.tune_rounded,
              iconColor: const Color(0xFF5B2ECC),
              iconBg: const Color(0xFFEEE9FB),
              title: 'Hybrid Settings',
              subtitle: 'Work-from-home and remote settings.',
              onTap: () => showHybridSettingsDialog(context),
            ),
            _MobileTile(
              icon: Icons.home_outlined,
              iconColor: const Color(0xFF5B2ECC),
              iconBg: const Color(0xFFEEE9FB),
              title: 'Home Approvals',
              subtitle: 'Approve home work-location requests.',
              onTap: () => showHomeApprovalsDialog(context),
            ),
          ],
        ),
      ],
    );
  }
}

class _MobileSection extends StatelessWidget {
  const _MobileSection({required this.label, required this.tiles});
  final String label;
  final List<_MobileTile> tiles;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE3E7EF)),
      borderRadius: BorderRadius.circular(12),
      boxShadow: const [
        BoxShadow(color: Color(0x07061457), blurRadius: 8, offset: Offset(0, 2)),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Text(label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF596176),
                  letterSpacing: 0.8)),
        ),
        const Divider(height: 1, color: Color(0xFFECEFF5)),
        ...List.generate(tiles.length, (i) => Column(children: [
          tiles[i],
          if (i < tiles.length - 1)
            Divider(height: 1, indent: 62, color: const Color(0xFFF0F3F9)),
        ])),
      ],
    ),
  );
}

class _MobileTile extends StatelessWidget {
  const _MobileTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color iconColor, iconBg;
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF11131A))),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(fontSize: 11, color: Color(0xFF596176), height: 1.4)),
          ]),
        ),
        const SizedBox(width: 6),
        const Icon(Icons.chevron_right_rounded, color: Color(0xFFB0B8CC), size: 20),
      ]),
    ),
  );
}
