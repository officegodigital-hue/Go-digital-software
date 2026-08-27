import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:godigital_portal/services/auth_service.dart';

class EmployeeSidebar extends StatelessWidget {
  final String selectedMenu;
  final List<String> menuItems;
  final Function(String) onMenuTap;
  final bool isMobileDrawer;

  const EmployeeSidebar({
    super.key,
    required this.selectedMenu,
    required this.menuItems,
    required this.onMenuTap,
    this.isMobileDrawer = false,
  });

  IconData _iconForMenu(String title) {
    switch (title) { 
      case 'Dashboard': return Icons.dashboard_rounded;
      case 'Day Planner': return Icons.task_alt_rounded;
      case 'Notifications': return Icons.notifications_rounded;
      case 'Daily Reports': return Icons.checklist_outlined;
      case 'Assigned Task': return Icons.assignment_rounded;
      case 'Live Tracking Tasks': return Icons.timer_rounded;
      case 'Task Planner': return Icons.event_note_rounded;
      case 'Task Review': return Icons.fact_check_rounded;
      case 'Task Status': return Icons.assessment_rounded;
      case 'Video Task Planner': return Icons.video_collection_rounded;
      case 'Feedback': return Icons.feedback_outlined;
      default: return Icons.circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget sidebarWidget = Container(
      width: 230,
      color: AppColors.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 64,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'GoDigital Employee',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                if (isMobileDrawer)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
          Container(height: 1, color: const Color(0xFF232D42)),
          const SizedBox(height: 10),
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
                    onTap: () {
                      onMenuTap(menu);
                      if (isMobileDrawer) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ).toList(),
              ),
            ),
          ),
          Container(height: 1, color: const Color(0xFF232D42)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  final authService = Provider.of<AuthService>(context, listen: false);
                  await authService.logout();
                  if (!context.mounted) return;
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

    if (isMobileDrawer) {
      return Drawer(
        backgroundColor: AppColors.sidebar,
        child: sidebarWidget,
      );
    }

    return sidebarWidget;
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