import 'package:flutter/material.dart';
import '../../pages/leave_page.dart' as legacy;

/// See HRMS_PROJECT_BLUEPRINT.md, Section 1 for this page's purpose.
class LeavePage extends StatelessWidget {
  const LeavePage({super.key});

  static Widget builder(BuildContext context) => const LeavePage();

  @override
  Widget build(BuildContext context) {
    return const legacy.EmployeeLeavePage();
  }
}
