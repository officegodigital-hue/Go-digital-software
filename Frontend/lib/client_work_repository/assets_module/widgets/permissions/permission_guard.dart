import 'package:flutter/material.dart';

class PermissionGuard extends StatelessWidget {
  final bool allowed;
  final Widget child;

  const PermissionGuard({
    super.key,
    required this.allowed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return allowed ? child : const SizedBox.shrink();
  }
}
