import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(30),
      children: const [
        Text('Support', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        SizedBox(height: 7),
        Text('Get help with your Go Digital workspace.', style: TextStyle(color: AppColors.textSecondary)),
        SizedBox(height: 24),
        Card(child: ListTile(leading: Icon(Icons.email_outlined), title: Text('Contact support'), subtitle: Text('support@godigital.example'))),
      ],
    );
  }
}
