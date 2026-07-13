import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/employee_role.dart';
import '../../services/auth_service.dart';


class EmployeeTopbar extends StatelessWidget {
  final EmployeeRole role;

  const EmployeeTopbar({
    super.key,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 460,
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
              children: [
                Icon(Icons.search, size: 17, color: AppColors.textGrey),
                SizedBox(width: 10),
                Text(
                  'Search tasks, clients...',
                  style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                ),
              ],
            ),
          ),
          const Spacer(),
          const Icon(Icons.notifications_none, size: 18, color: AppColors.textDark),
          const SizedBox(width: 24),
          const Icon(Icons.help_outline, size: 18, color: AppColors.textDark),
          const SizedBox(width: 24),
          Container(height: 30, width: 1, color: AppColors.border),
          const SizedBox(width: 14),
          // ✅ FIXED: Get employee data from AuthService (backend)
          Consumer<AuthService>(
            builder: (context, authService, _) {
              // ✅ Get actual employee name from login response
              final employeeName = authService.user?['fullName'] ?? 'Employee';
              
              // ✅ Get actual role from login response
              final employeeRole = authService.user?['role'] ?? role.title;
              
              // ✅ Get actual initials from login response
              final initials = authService.user?['initials'] ?? 
                _generateInitials(employeeName);

              return Row(
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // ✅ Shows actual employee name from backend
                      Text(
                        employeeName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      // ✅ Shows actual role from backend
                      Text(
                        employeeRole,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  // ✅ Shows actual initials from backend
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ✅ Helper method to generate initials if not provided by backend
  String _generateInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return (parts.first[0] + parts.last[0]).toUpperCase();
    } else {
      return parts.first[0].toUpperCase();
    }
  }
}