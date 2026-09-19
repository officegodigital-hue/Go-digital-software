import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/api_service.dart';

class AdminDashboardPage extends StatefulWidget {
  final VoidCallback onOpenAssets;

  const AdminDashboardPage({
    super.key,
    required this.onOpenAssets,
  });

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late Future<Map<String, dynamic>> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = ApiService.getDashboard();
  }

  void _retry() {
    setState(() {
      _dashboardFuture = ApiService.getDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _dashboardFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: FilledButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry dashboard'),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final dashboard = snapshot.data!;
        final companies = _number(dashboard['companies']);
        final assets = _number(dashboard['assets']);
        final users = _number(dashboard['users']);
        final shared = _number(dashboard['shared']);

        return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final horizontalPadding = width < 600
            ? 16.0
            : width < 1024
                ? 24.0
                : 30.0;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            30,
            horizontalPadding,
            30,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dashboard',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 7),

              const Text(
                'Welcome back, Admin. Here is your workspace overview.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 28),

              _buildStats(
                context: context,
                width: width,
                companies: companies,
                assets: assets,
                users: users,
                shared: shared,
              ),

              const SizedBox(height: 24),

              _buildManageAssetsCard(width),
            ],
          ),
        );
      },
        );
      },
    );
  }

  int _number(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

  Widget _buildStats({
    required BuildContext context,
    required double width,
    required int companies,
    required int assets,
    required int users,
    required int shared,
  }) {
    final statItems = [
      _StatData(
        title: 'Companies',
        value: '$companies',
        icon: Icons.business_outlined,
      ),
      _StatData(
        title: 'Assets',
        value: '$assets',
        icon: Icons.folder_outlined,
      ),
      _StatData(
        title: 'Users',
        value: '$users',
        icon: Icons.people_outline,
      ),
      _StatData(
        title: 'Shared',
        value: '$shared',
        icon: Icons.share_outlined,
      ),
    ];

    // Desktop: 4 cards in one row.
    if (width >= 1100) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < statItems.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            Expanded(
              child: _Stat(
                data: statItems[i],
              ),
            ),
          ],
        ],
      );
    }

    // Tablet / smaller desktop: 2 x 2.
    if (width >= 600) {
      return GridView.builder(
        itemCount: statItems.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          mainAxisExtent: 100,
        ),
        itemBuilder: (context, index) {
          return _Stat(
            data: statItems[index],
          );
        },
      );
    }

    // Mobile: one card per row.
    return Column(
      children: [
        for (int i = 0; i < statItems.length; i++) ...[
          _Stat(
            data: statItems[i],
          ),
          if (i != statItems.length - 1)
            const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildManageAssetsCard(double width) {
    final isMobile = width < 600;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(
          isMobile ? 16 : 18,
        ),
        child: isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor:
                            AppColors.digitalMarketingLight,
                        child: Icon(
                          Icons.grid_view,
                          color: AppColors.digitalMarketing,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _ManageAssetsText(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: widget.onOpenAssets,
                      child: const Text('Open'),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  const CircleAvatar(
                    backgroundColor:
                        AppColors.digitalMarketingLight,
                    child: Icon(
                      Icons.grid_view,
                      color: AppColors.digitalMarketing,
                    ),
                  ),

                  const SizedBox(width: 14),

                  const Expanded(
                    child: _ManageAssetsText(),
                  ),

                  const SizedBox(width: 16),

                  FilledButton(
                    onPressed: widget.onOpenAssets,
                    child: const Text('Open'),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ManageAssetsText extends StatelessWidget {
  const _ManageAssetsText();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Manage all company assets',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Open Digital Marketing and Software Development asset collections.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _StatData {
  final String title;
  final String value;
  final IconData icon;

  const _StatData({
    required this.title,
    required this.value,
    required this.icon,
  });
}

class _Stat extends StatelessWidget {
  final _StatData data;

  const _Stat({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFEAF2FF),
              child: Icon(
                data.icon,
                color: AppColors.primary,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    data.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    data.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
