import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/company_model.dart';

class CompanyRow extends StatelessWidget {
  final CompanyModel company;
  final int assetCount;
  final VoidCallback onTap;

  const CompanyRow({
    super.key,
    required this.company,
    required this.assetCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [
      AppColors.primary,
      const Color(0xFF16A88B),
      AppColors.digitalMarketing,
      const Color(0xFFE93D72),
    ];
    final color = colors[company.name.codeUnitAt(0) % colors.length];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(9),
          color: Colors.white,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: color,
              child: Text(company.name.substring(0, 1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(company.name, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text('$assetCount assets', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Last updated:', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                Text(_date(company.updatedAt), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(width: 10),
            const Icon(Icons.chevron_right, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')} ${_month(d.month)} ${d.year}';

  String _month(int m) => const ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m - 1];
}
