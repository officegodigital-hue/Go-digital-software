import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(30),
      children: const [
        Text('Profile', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        SizedBox(height: 24),
        Card(
          child: Padding(
            padding: EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(radius: 34, child: Text('U', style: TextStyle(fontSize: 25))),
                SizedBox(height: 18),
                Text('Client User', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                SizedBox(height: 6),
                Text('user@test.com'),
                SizedBox(height: 6),
                Text('User'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
