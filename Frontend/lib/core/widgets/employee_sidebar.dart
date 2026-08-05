import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class EmployeeSidebar extends StatelessWidget {
  final String selectedMenu;
  final List<String> menuItems;
  final Function(String) onMenuTap;

  const EmployeeSidebar({
    super.key,
    required this.selectedMenu,
    required this.menuItems,
    required this.onMenuTap,
  });

  // IconData _iconForMenu(String title) {
  //   if (title == 'Dashboard') return Icons.dashboard_outlined;
  //   if (title == 'Notifications') return Icons.notifications_none;
  //   if (title.contains('Daily')) return Icons.checklist_outlined;
  //   if (title.contains('Assigned')) return Icons.assignment_outlined;
  //   if (title.contains('Planner')) return Icons.event_note_outlined;
  //   if (title.contains('Feedback')) return Icons.feedback_outlined;
  //   return Icons.circle_outlined;
  // }

  IconData _iconForMenu(String title) {
  switch (title) { 
    case 'Dashboard': return Icons.dashboard;
    case 'Day Planner': return Icons.task;
    case 'Notifications': return Icons.notifications;
    case 'Daily Reports': return Icons.checklist_outlined;
    case 'Assigned Task': return Icons.assignment;
    case 'Live Tracking Tasks': return Icons.location_on;
    case 'Task Planner': return Icons.event_note_outlined;
    case 'Task Review': return Icons.fact_check_outlined;
    case 'Task Status': return Icons.fact_check_outlined;
    case 'Video Task Planner': return Icons.event_note_outlined;
    case 'Feedback': return Icons.feedback_outlined;
    default: return Icons.circle_outlined;
  }
}

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: AppColors.sidebar,
      child: Column(
        children: [
          const SizedBox(height: 32),
          const Text(
            'GoDigital Employee',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 36),

          ...menuItems.map(
            (menu) => _SidebarItem(
              icon: _iconForMenu(menu),
              title: menu,
              isActive: selectedMenu == menu,
              onTap: () => onMenuTap(menu),
            ),
          ),

          const Spacer(),

Container(height: 1, color: Colors.white24),

          // _SidebarItem(
          //   icon: Icons.home,
          //   title: 'HOME',
          //   isActive: false,
          //   onTap: () {
          //     Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
          //   },
          // ),

          _SidebarItem(
            icon: Icons.logout,
            title: 'Logout',
            isActive: false,
            onTap: () {
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}



class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isActive;
  final VoidCallback onTap; 

  const _SidebarItem({
    required this.icon,
    required this.title,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 46,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}