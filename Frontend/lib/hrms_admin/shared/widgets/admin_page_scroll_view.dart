import 'package:flutter/material.dart';

/// Full-page admin scroller using the same sliver structure as the dashboard.
/// Horizontal tables and nested lists keep their own scroll controllers.
class AdminPageScrollView extends StatelessWidget {
  const AdminPageScrollView({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.controller,
    this.primary,
    this.physics,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final ScrollController? controller;
  final bool? primary;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: controller,
      primary: primary,
      physics: physics ?? const ClampingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: padding,
          sliver: SliverToBoxAdapter(child: child),
        ),
      ],
    );
  }
}
