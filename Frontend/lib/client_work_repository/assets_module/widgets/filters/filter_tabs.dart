import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class FilterTabs extends StatelessWidget {
  final List<String> tabs;
  final String selected;
  final ValueChanged<String> onChanged;

  const FilterTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((tab) {
          final active = tab == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 7),
            child: InkWell(
              onTap: () => onChanged(tab),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : const Color(0xFFF0F4FA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tab,
                  style: TextStyle(
                    color: active ? Colors.white : AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
