import 'package:flutter/material.dart';

import '../widgets/admin_sidebar.dart';
import '../widgets/admin_topbar.dart';

class AdminLayout extends StatelessWidget {
  final Widget child;
  final String selectedMenu;

  const AdminLayout({
    super.key,
    required this.child,
    required this.selectedMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          AdminSidebar(selectedMenu: selectedMenu),
          Expanded(
            child: Column(
              children: [
                const AdminTopbar(),
                Expanded(
                  child: Container(
                    color: Colors.white,
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}