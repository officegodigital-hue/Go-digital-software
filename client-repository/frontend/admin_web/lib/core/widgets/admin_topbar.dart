import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class AdminTopbar extends StatelessWidget {
  const AdminTopbar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      color: AppColors.navy,
      padding: const EdgeInsets.only(left: 42, right: 70),
      child: Row(
        children: [
          SizedBox(
            width: 340,
            height: 34,
            child: TextField(
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Search assets, clients, or projects...',
                hintStyle: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF7A8597),
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 17,
                  color: Color(0xFF6B7280),
                ),
                filled: true,
                fillColor: const Color(0xFFF6F8FC),
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(0),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const Spacer(),

          const Icon(
            Icons.notifications_none,
            color: Colors.white,
            size: 20,
          ),

          const SizedBox(width: 28),

          const Icon(
            Icons.help_outline,
            color: Colors.white,
            size: 18,
          ),

          const SizedBox(width: 30),

          Container(
            width: 1,
            height: 28,
            color: Colors.white.withValues(alpha: 0.35),
          ),

          const SizedBox(width: 22),

          const CircleAvatar(
            radius: 15,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.person,
              color: AppColors.navy,
              size: 18,
            ),
          ),

          const SizedBox(width: 14),

          const Text(
            'Admin User',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}