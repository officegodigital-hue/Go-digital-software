import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class SharedPage extends StatelessWidget {
  const SharedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Shared Assets', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
    );
  }
}
