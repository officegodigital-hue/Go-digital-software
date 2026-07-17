import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:my_first_app/core/constants/app_colors.dart';

class ProductivityCard extends StatelessWidget {
  final int approved;
  final int rejected;
  final int rework;
  final int changes;

  const ProductivityCard({
    super.key,
    required this.approved,
    required this.rejected,
    required this.rework,
    required this.changes,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Productivity',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 24),
          // _ProductivityItem(
          //   title: 'Approved',
          //   value: '62%',
          //   color: AppColors.green,
          // ),

          _ProductivityItem(
  title: 'Approved',
  value: approved.toString(),
  color: AppColors.green,
),
          // _ProductivityItem(
          //   title: 'Rejected',
          //   value: '8%',
          //   color: AppColors.red,
          // ),

          _ProductivityItem(
  title: 'Rejected',
  value: rejected.toString(),
  color: AppColors.red,
),
          // _ProductivityItem(
          //   title: 'Reworks',
          //   value: '18%',
          //   color: Colors.purple,
          // ),

         _ProductivityItem(
  title: 'Reworks',
  value: rework.toString(),
  color: Colors.purple,
),
          // _ProductivityItem(
          //   title: 'Changes',
          //   value: '12%',
          //   color: AppColors.textGrey,
          // ),

          _ProductivityItem(
  title: 'Changes',
  value: changes.toString(),
  color: AppColors.textGrey,
),
        ],
      ),
    );
  }
}

class _ProductivityItem extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _ProductivityItem({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          CircleAvatar(radius: 4, backgroundColor: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}