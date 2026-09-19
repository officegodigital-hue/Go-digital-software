import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(30),
      children: const [
        Text('Settings', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        SizedBox(height: 7),
        Text('Configure your Go Digital workspace.', style: TextStyle(color: AppColors.textSecondary)),
        SizedBox(height: 24),
        Card(
          child: Column(
            children: [
              ListTile(leading: Icon(Icons.business_outlined), title: Text('Company settings'), subtitle: Text('Manage workspace information')),
              Divider(height: 1),
              ListTile(leading: Icon(Icons.security_outlined), title: Text('Security'), subtitle: Text('Authentication and account security')),
              Divider(height: 1),
              ListTile(leading: Icon(Icons.cloud_outlined), title: Text('Storage'), subtitle: Text('Google Drive integration will be connected later')),
            ],
          ),
        ),
      ],
    );
  }
}
