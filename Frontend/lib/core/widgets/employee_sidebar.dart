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

  IconData _iconForMenu(String title) {
    switch (title) { 
      case 'Dashboard': return Icons.dashboard;
      case 'Day Planner': return Icons.task;
      case 'Notifications': return Icons.notifications;
      case 'Daily Reports': return Icons.checklist_outlined;
      case 'Assigned Task': return Icons.assignment;
      case 'Live Tracking Tasks': return Icons.task_alt;
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand Header matching AdminLayout height
          Container(
            height: 64,
            width: double.infinity,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: const Text(
              'GoDigital Employee',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          // Thin divider below brand
          Container(height: 1, color: const Color(0xFF232D42)),
          const SizedBox(height: 10),

          // Expanded scrollable menu items catalog (prevents overflow)
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: menuItems.map(
                  (menu) => _SidebarItem(
                    icon: _iconForMenu(menu),
                    title: menu,
                    isActive: selectedMenu == menu,
                    onTap: () => onMenuTap(menu),
                  ),
                ).toList(),
              ),
            ),
          ),

          // Anchored Logout Bottom Panel
          Container(height: 1, color: const Color(0xFF232D42)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  child: Row(
                    children: const [
                      Icon(Icons.logout_rounded, size: 17, color: Color(0xFF8A94A6)),
                      SizedBox(width: 12),
                      Text(
                        'Logout',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF8A94A6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(icon, size: 17, color: isActive ? Colors.white : const Color(0xFF8A94A6)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive ? Colors.white : const Color(0xFF8A94A6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}