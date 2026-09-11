import 'package:flutter/material.dart';
import 'package:godigital_portal/core/constants/app_colors.dart';

class AlertsSection extends StatelessWidget {
  final List<Map<String, dynamic>> notifications;
   final VoidCallback? onViewAll;

  const AlertsSection({
    super.key,
    required this.notifications,
    this.onViewAll,
  });
 
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: [
           Row(
            children: [
              Text(
                "Alerts",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              Spacer(),
              // Text(
              //   "View All Notifications",
              //   style: TextStyle(
              //     fontSize: 11,
              //     color: AppColors.primary,
              //     fontWeight: FontWeight.w700,
              //   ),
              // ),
              InkWell(
  onTap: onViewAll,
  child: const Text(
    "View All Notifications",
    style: TextStyle(
      fontSize: 11,
      color: AppColors.primary,
      fontWeight: FontWeight.w700,
    ),
  ),
),
            ],
          ),
          const SizedBox(height: 18),

          Expanded(
            child: Row(
              children: List.generate(
                notifications.length > 3 ? 3 : notifications.length,
                (index) {
                  final item = notifications[index];

                  return Expanded(
                    child: Padding(
                      padding:
                          EdgeInsets.only(right: index == 2 ? 0 : 16),
                      child: _AlertCard(
                        icon: _icon(item["category"]),
                        color: _color(item["category"]),
                        title: item["category"] ?? "",
                        message: item["preview"] ?? "",
                        time: item["createdAt"] ?? "",
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _icon(String? category) {
    switch (category) {
      case "Task Assigned":
        return Icons.assignment;

      case "Task Review":
        return Icons.fact_check;

      case "Warning & Alert":
        return Icons.warning_amber;

      case "Daily Planner":
        return Icons.calendar_today;

      case "Content Shared":
        return Icons.share;

      default:
        return Icons.notifications;
    }
  }

  static Color _color(String? category) {
    switch (category) {
      case "Task Assigned":
        return AppColors.primary;

      case "Task Review":
        return Colors.green;

      case "Warning & Alert":
        return Colors.red;

      case "Daily Planner":
        return Colors.orange;

      case "Content Shared":
        return Colors.purple;

      default:
        return Colors.grey;
    }
  }
}

class _AlertCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String time;
  final Color color;

  const _AlertCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.time,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightBlue,
        border: Border(
          left: BorderSide(
            color: color,
            width: 3,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textGrey,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textGrey.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}