import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/constants/app_colors.dart';
import 'screens/employee_dashboard/employee_layout_page.dart';
// import 'screens/employee_dashboard/employee_dashboard.dart';


class GoDigitalEmployeeApp extends StatelessWidget {
  const GoDigitalEmployeeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GoDigital Employee',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        textTheme: GoogleFonts.interTextTheme(),
        useMaterial3: true,
      ),
      
      home: const EmployeeLayoutPage(),
    );
  }
}