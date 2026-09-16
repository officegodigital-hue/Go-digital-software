import 'package:flutter/material.dart';
import 'package:hrms_design_system/hrms_design_system.dart';

import '../routing/app_router.dart';

class AdminPortalApp extends StatelessWidget {
  const AdminPortalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Go Digital HRMS — Admin',
      theme: HrmsTheme.light(),
      initialRoute: '/admin/dashboard',
      routes: AppRouter.routes,
      debugShowCheckedModeBanner: false,
    );
  }
}
