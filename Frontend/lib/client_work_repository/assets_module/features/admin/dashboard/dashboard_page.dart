import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/widgets/premium_ui.dart';
import '../../../services/api_service.dart';

class AdminDashboardPage extends StatefulWidget {
  final VoidCallback onOpenAssets;
  const AdminDashboardPage({super.key, required this.onOpenAssets});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late Future<Map<String, dynamic>> _dashboardFuture;
  Future<List<List<dynamic>>>? _overviewFuture;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _dashboardFuture = ApiService.getDashboard();
    _overviewFuture = null;
  }

  void _loadOverview() {
    _overviewFuture = Future.wait([
      ApiService.getCompanies(),
      ApiService.getAssets(),
    ]);
  }

  void _retry() => setState(_load);
  int _number(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _dashboardFuture,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return PremiumBackground(
          child: PremiumErrorState(
            title: 'Could not load dashboard',
            message: 'Something went wrong while fetching your workspace data. Please try again.',
            retryLabel: 'Retry dashboard',
            onRetry: _retry,
          ),
        );
      }
      if (!snapshot.hasData) {
        return const PremiumBackground(
          child: PremiumLoading(label: 'Loading your workspace...'),
        );
      }
      final data = snapshot.data!;
      return PremiumPage(
        builder: (context, bp) => [
          Reveal(child: _hero(bp.mobile)),
          SizedBox(height: bp.gap),
          PremiumStatRow(
            stats: [
              PremiumStat(
                label: 'Companies',
                value: _number(data['companies']),
                icon: Icons.business_rounded,
                accent: PremiumAccent.blue,
                caption: 'Registered companies',
              ),
              PremiumStat(
                label: 'Assets',
                value: _number(data['assets']),
                icon: Icons.layers_rounded,
                accent: PremiumAccent.green,
                caption: 'Total assets stored',
              ),
              PremiumStat(
                label: 'Users',
                value: _number(data['users']),
                icon: Icons.people_alt_rounded,
                accent: PremiumAccent.violet,
                caption: 'Team members',
              ),
              PremiumStat(
                label: 'Shared',
                value: _number(data['shared']),
                icon: Icons.share_rounded,
                accent: PremiumAccent.amber,
                caption: 'Shared items',
              ),
            ],
          ),
          SizedBox(height: bp.gap),
          Reveal(
            delay: const Duration(milliseconds: 420),
            child: PremiumPanel(
              padding: EdgeInsets.all(bp.mobile ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PremiumSectionHeader(
                    title: 'Manage all company assets',
                    subtitle: 'Browse and manage assets by category. Choose a category to get started.',
                    icon: Icons.dashboard_customize_rounded,
                    compact: bp.mobile,
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, inner) {
                      final compact = inner.maxWidth < 560;
                      final cards = [
                        _category(
                          'Digital Marketing',
                          'Manage marketing assets including logos, social media content, campaign materials and more.',
                          Icons.campaign_rounded,
                          PremiumAccent.blue,
                          compact,
                        ),
                        _category(
                          'Software Development',
                          'Manage development assets including source code, documentation, designs and technical resources.',
                          Icons.code_rounded,
                          PremiumAccent.violet,
                          compact,
                        ),
                      ];
                      if (inner.maxWidth < 900) {
                        return Column(
                          children: [
                            cards[0],
                            const SizedBox(height: 12),
                            cards[1],
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: cards[0]),
                          const SizedBox(width: 12),
                          Expanded(child: cards[1]),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: bp.gap),
          Reveal(
            delay: const Duration(milliseconds: 520),
            child: PremiumPanel(
              padding: EdgeInsets.all(bp.mobile ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PremiumSectionHeader(
                    title: 'Company overview',
                    subtitle:
                        'A list of all companies and their asset information.',
                    icon: Icons.apartment_rounded,
                    accent: PremiumAccent.green,
                    compact: bp.mobile,
                  ),
                  const SizedBox(height: 14),
                  _overview(),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );

  Widget _hero(bool mobile) => PremiumHero(
    compact: mobile,
    eyebrow: '${_greeting()}, Admin',
    eyebrowIcon: Icons.waving_hand_rounded,
    title: 'Dashboard',
    subtitle: 'Welcome back, Admin. Here is your workspace overview.',
    actions: [
      PremiumButton(
        label: 'Open assets',
        icon: Icons.arrow_forward_rounded,
        variant: PremiumButtonVariant.light,
        onPressed: widget.onOpenAssets,
      ),
      PremiumButton(
        label: 'Refresh',
        icon: Icons.refresh_rounded,
        iconLeading: true,
        variant: PremiumButtonVariant.glass,
        onPressed: _retry,
      ),
    ],
  );

  Widget _category(
    String title,
    String description,
    IconData icon,
    PremiumAccent accent,
    bool compact,
  ) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            height: 1.3,
            fontWeight: FontWeight.w700,
            color: PremiumColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: const TextStyle(
            fontSize: 13.5,
            height: 1.45,
            color: PremiumColors.muted,
          ),
        ),
      ],
    );
    return HoverBuilder(
      builder: (context, hovered) {
        final tile = AnimatedScale(
          scale: hovered ? 1.08 : 1,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          child: PremiumIconTile(icon: icon, accent: accent, size: 44),
        );
        final button = PremiumButton(
          label: 'Open',
          icon: Icons.arrow_forward_rounded,
          gradient: accent.gradient,
          small: true,
          expand: compact,
          onPressed: widget.onOpenAssets,
        );
        return AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, hovered ? -3 : 0, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accent.soft, Colors.white],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hovered ? accent.start.withAlpha(110) : PremiumColors.line,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.start.withAlpha(hovered ? 36 : 0),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        tile,
                        const SizedBox(width: 12),
                        Expanded(child: text),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: button),
                  ],
                )
              : Row(
                  children: [
                    tile,
                    const SizedBox(width: 14),
                    Expanded(child: text),
                    const SizedBox(width: 12),
                    button,
                  ],
                ),
        );
      },
    );
  }

  // ── Company overview ─────────────────────────────────────────────────────
  List<String> _sections(Map company) {
    dynamic raw = company['sections'];
    if (raw is String) {
      try {
        raw = jsonDecode(raw);
      } catch (_) {
        raw = [raw];
      }
    }
    if (raw is List && raw.isNotEmpty) {
      return raw.map((value) => value.toString()).toList();
    }
    final section = company['section']?.toString() ?? '';
    return section.isEmpty ? [] : [section];
  }

  int _assetCount(Map company, List<Map> assets) => assets
      .where(
        (asset) => asset['company_id']?.toString() == company['id']?.toString(),
      )
      .length;

  Widget _overview() => FutureBuilder<List<List<dynamic>>>(
    future: _overviewFuture ??= Future.wait([
      ApiService.getCompanies(),
      ApiService.getAssets(),
    ]),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Align(
          alignment: Alignment.centerLeft,
          child: PremiumButton(
            label: 'Retry company overview',
            icon: Icons.refresh_rounded,
            iconLeading: true,
            onPressed: () => setState(_loadOverview),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: PremiumLoading(label: 'Loading companies...'),
        );
      }
      final companies = snapshot.data![0].whereType<Map>().toList();
      final assets = snapshot.data![1].whereType<Map>().toList();
      if (companies.isEmpty) {
        return const PremiumEmptyState(
          icon: Icons.domain_disabled_rounded,
          title: 'No companies available.',
        );
      }
      return LayoutBuilder(
        builder: (context, box) {
          if (box.maxWidth < 640) {
            return Column(
              children: [
                for (var i = 0; i < companies.length; i++)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
                    child: Reveal(
                      delay: Duration(milliseconds: 60 * math.min(i, 10)),
                      child: _companyCard(companies[i], assets, i),
                    ),
                  ),
              ],
            );
          }
          return PremiumTable(
            minWidth: 760,
            header: PremiumTableHeader(
              child: _row([
                const Text('COMPANY', style: PremiumColors.tableHeaderStyle),
                const Text('SECTION', style: PremiumColors.tableHeaderStyle),
                const Text('ASSETS', style: PremiumColors.tableHeaderStyle),
                const Text('ACTION', style: PremiumColors.tableHeaderStyle),
              ]),
            ),
            itemCount: companies.length,
            itemBuilder: (context, i) => PremiumTableRow(
              child: _row([
                Row(
                  children: [
                    _avatar(companies[i], 34),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        companies[i]['name']?.toString() ?? '',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: PremiumColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                _sectionChips(companies[i]),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _assetPill(_assetCount(companies[i], assets)),
                ),
                PremiumButton(
                  label: 'Open',
                  variant: PremiumButtonVariant.outlined,
                  small: true,
                  onPressed: widget.onOpenAssets,
                ),
              ]),
            ),
            footer: PremiumTableFooter(
              child: Text('${companies.length} companies'),
            ),
          );
        },
      );
    },
  );

  Widget _companyCard(Map company, List<Map> assets, int index) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: PremiumColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _avatar(company, 38),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                company['name']?.toString() ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: PremiumColors.ink,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _assetPill(_assetCount(company, assets)),
          ],
        ),
        const SizedBox(height: 10),
        _sectionChips(company),
        const SizedBox(height: 12),
        PremiumButton(
          label: 'Open',
          variant: PremiumButtonVariant.outlined,
          small: true,
          expand: true,
          onPressed: widget.onOpenAssets,
        ),
      ],
    ),
  );

  Widget _row(List<Widget> cells) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18),
    child: Row(
      children: [
        Expanded(flex: 28, child: cells[0]),
        const SizedBox(width: 12),
        Expanded(flex: 30, child: cells[1]),
        const SizedBox(width: 12),
        Expanded(flex: 22, child: cells[2]),
        SizedBox(
          width: 110,
          child: Align(alignment: Alignment.centerLeft, child: cells[3]),
        ),
      ],
    ),
  );

  Widget _sectionChips(Map company) {
    final sections = _sections(company);
    if (sections.isEmpty) {
      return const Text('—', style: TextStyle(color: PremiumColors.muted));
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final section in sections)
          PremiumBadge(
            label: section,
            accent: section.toLowerCase().contains('software')
                ? PremiumAccent.violet
                : PremiumAccent.blue,
          ),
      ],
    );
  }

  Widget _assetPill(int count) => PremiumBadge(
    label: '$count',
    icon: Icons.layers_rounded,
    accent: PremiumAccent.green,
  );

  Widget _avatar(Map company, double size) {
    final name = company['name']?.toString() ?? '';
    return PremiumAvatar(
      text: name.characters.firstOrNull?.toUpperCase() ?? '?',
      accent: PremiumAccent.forText(name),
      size: size,
    );
  }
}
