import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/premium_ui.dart';
import '../../../models/asset_model.dart';
import '../../../models/company_model.dart';
import '../../../services/api_service.dart';

class UserDashboardPage extends StatefulWidget {
  final void Function(String section)? onOpenSection;

  const UserDashboardPage({super.key, this.onOpenSection});

  @override
  State<UserDashboardPage> createState() => _UserDashboardPageState();
}

class _UserDashboardPageState extends State<UserDashboardPage> {
  List<AssetModel> _assets = [];
  List<CompanyModel> _companies = [];
  bool _loading = true;
  String? _error;
  String _employeeName = 'Employee';

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        ApiService.getCompanies(),
        ApiService.getAssets(),
      ]);
      // A missing profile must not prevent the employee from accessing
      // assets. The shell already refreshes this profile independently.
      final profile = await ApiService.getMyProfile().catchError(
        (_) => <String, dynamic>{},
      );
      if (!mounted) return;

      final assets = <AssetModel>[];
      for (final raw in results[1] as List<dynamic>) {
        if (raw is! Map) continue;
        final data = Map<String, dynamic>.from(raw);
        final id = data['id']?.toString() ?? '';
        final companyId = data['company_id']?.toString() ?? '';
        final section = data['section']?.toString() ?? '';
        final type = data['type']?.toString() ?? '';
        final name = data['name']?.toString() ?? '';
        if (id.isEmpty ||
            companyId.isEmpty ||
            section.isEmpty ||
            type.isEmpty ||
            name.isEmpty)
          continue;
        final now = DateTime.now();
        assets.add(
          AssetModel(
            id: id,
            companyId: companyId,
            companyName: data['company_name']?.toString() ?? '',
            section: section,
            type: type,
            name: name,
            description: data['description']?.toString(),
            link: data['link']?.toString(),
            filePath: data['file_url']?.toString(),
            fileName: data['file_name']?.toString(),
            createdAt:
                DateTime.tryParse(data['created_at']?.toString() ?? '') ?? now,
            updatedAt:
                DateTime.tryParse(data['updated_at']?.toString() ?? '') ?? now,
          ),
        );
      }

      final companies = <CompanyModel>[];
      for (final raw in results[0] as List<dynamic>) {
        if (raw is! Map) continue;
        final data = Map<String, dynamic>.from(raw);
        final id = data['id']?.toString() ?? '';
        final name = data['name']?.toString().trim() ?? '';
        if (id.isEmpty || name.isEmpty) continue;
        final rawSections = data['sections'];
        final sections = rawSections is List
            ? rawSections
                  .map((value) => value.toString().trim())
                  .where((value) => value.isNotEmpty)
                  .toList()
            : <String>[];
        final now = DateTime.now();
        for (final section in sections) {
          companies.add(
            CompanyModel(
              id: id,
              name: name,
              section: section,
              allSections: sections,
              logoUrl: data['logo_url']?.toString(),
              createdAt:
                  DateTime.tryParse(data['created_at']?.toString() ?? '') ??
                  now,
              updatedAt:
                  DateTime.tryParse(data['updated_at']?.toString() ?? '') ??
                  now,
            ),
          );
        }
      }

      // Preserve visibility for legacy companies that have assets but no
      // company_sections record yet.
      for (final asset in assets) {
        if (companies.any(
          (company) =>
              company.id == asset.companyId && company.section == asset.section,
        ))
          continue;
        companies.add(
          CompanyModel(
            id: asset.companyId,
            name: asset.companyName.isEmpty ? 'Company' : asset.companyName,
            section: asset.section,
            createdAt: asset.createdAt,
            updatedAt: asset.updatedAt,
          ),
        );
      }

      setState(() {
        _assets = assets;
        _companies = companies;
        final name = profile['name']?.toString().trim();
        _employeeName = name == null || name.isEmpty ? 'Employee' : name;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  List<AssetModel> _assetsFor(String section) =>
      _assets.where((a) => a.section == section).toList();

  int _assetCount(String section) => _assetsFor(section).length;

  int _companyCount(String section) => _companies
      .where((company) => company.section == section)
      .map((company) => company.id)
      .toSet()
      .length;

  /// 3 most recently updated assets in a section.
  List<AssetModel> _recentAssets(String section) {
    final list = _assetsFor(section)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list.take(3).toList();
  }

  /// 3 most recently updated assets across all sections.
  List<AssetModel> get _recentActivity {
    final list = [..._assets]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list.take(3).toList();
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return '$h hour${h == 1 ? '' : 's'} ago';
    }
    final d = diff.inDays;
    if (d < 30) return '$d day${d == 1 ? '' : 's'} ago';
    final mo = (d / 30).floor();
    return '$mo month${mo == 1 ? '' : 's'} ago';
  }

  // Thumbnail accents (cycle per row), all shades of blue.
  static const _dmThumbs = [
    PremiumAccent.blue,
    PremiumAccent.cyan,
    PremiumAccent.violet,
  ];
  static const _sdThumbs = [
    PremiumAccent.violet,
    PremiumAccent.amber,
    PremiumAccent.green,
  ];

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const PremiumBackground(
        child: PremiumLoading(label: 'Loading your workspace...'),
      );
    }
    if (_error != null) return _buildErrorState();

    final dmCompanies = _companyCount(AppConstants.digitalMarketing);
    final sdCompanies = _companyCount(AppConstants.softwareDevelopment);
    return PremiumPage(
      builder: (context, bp) => [
        Reveal(child: _buildHero(bp.mobile)),
        SizedBox(height: bp.gap),
        PremiumStatRow(
          stats: [
            PremiumStat(
              label: 'Total assets',
              value: _assets.length,
              icon: Icons.layers_rounded,
              accent: PremiumAccent.blue,
              caption: 'Across both sections',
            ),
            PremiumStat(
              label: 'Companies',
              value: _companies.map((c) => c.id).toSet().length,
              icon: Icons.apartment_rounded,
              accent: PremiumAccent.violet,
              caption: '$dmCompanies marketing · $sdCompanies software',
            ),
            PremiumStat(
              label: 'Digital Marketing',
              value: _assetCount(AppConstants.digitalMarketing),
              icon: Icons.campaign_rounded,
              accent: PremiumAccent.cyan,
              caption: 'Marketing assets',
            ),
            PremiumStat(
              label: 'Software Development',
              value: _assetCount(AppConstants.softwareDevelopment),
              icon: Icons.code_rounded,
              accent: PremiumAccent.amber,
              caption: 'Software assets',
            ),
          ],
        ),
        SizedBox(height: bp.gap),
        Reveal(
          delay: const Duration(milliseconds: 380),
          child: _buildPanels(bp.mobile),
        ),
        SizedBox(height: bp.gap),
        Reveal(
          delay: const Duration(milliseconds: 480),
          child: _buildActivityStrip(bp.mobile),
        ),
      ],
    );
  }

  Widget _buildErrorState() => PremiumBackground(
    child: PremiumErrorState(
      title: 'Unable to load assets',
      message: _error ?? 'Unable to load assets.',
      retryLabel: 'Try Again',
      onRetry: _loadDashboardData,
    ),
  );

  // ─── Hero ───────────────────────────────────────────────────
  Widget _buildHero(bool isMobile) {
    return PremiumHero(
      compact: isMobile,
      eyebrow: 'Employee workspace',
      eyebrowIcon: Icons.waving_hand_rounded,
      title: 'Welcome back, $_employeeName',
      subtitle: 'Access your marketing and software assets in one place.',
      actions: [
        PremiumButton(
          label: 'Refresh',
          icon: Icons.refresh_rounded,
          iconLeading: true,
          variant: PremiumButtonVariant.glass,
          onPressed: _loadDashboardData,
        ),
      ],
    );
  }

  // ─── Panels ─────────────────────────────────────────────────
  Widget _buildPanels(bool isMobile) {
    final dm = _buildPanel(
      section: AppConstants.digitalMarketing,
      subtitle: 'Marketing assets for all your brands and campaigns.',
      accent: PremiumAccent.blue,
      icon: Icons.campaign_rounded,
      thumbs: _dmThumbs,
      ctaLabel: 'Browse Digital Marketing',
      isMobile: isMobile,
    );
    final sd = _buildPanel(
      section: AppConstants.softwareDevelopment,
      subtitle: 'Software assets, applications and technical resources.',
      accent: PremiumAccent.violet,
      icon: Icons.code_rounded,
      thumbs: _sdThumbs,
      ctaLabel: 'Browse Software Development',
      isMobile: isMobile,
    );

    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth < 860) {
          return Column(children: [dm, const SizedBox(height: 12), sd]);
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: dm),
              const SizedBox(width: 16),
              Expanded(child: sd),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPanel({
    required String section,
    required String subtitle,
    required PremiumAccent accent,
    required IconData icon,
    required List<PremiumAccent> thumbs,
    required String ctaLabel,
    required bool isMobile,
  }) {
    final assets = _assetCount(section);
    final companies = _companyCount(section);
    final recent = _recentAssets(section);

    return HoverBuilder(
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: hovered ? accent.start.withAlpha(90) : PremiumColors.line,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.start.withAlpha(hovered ? 30 : 10),
              blurRadius: hovered ? 24 : 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                AnimatedScale(
                  scale: hovered ? 1.08 : 1,
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutBack,
                  child: PremiumIconTile(icon: icon, accent: accent, size: 44),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: PremiumColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: PremiumColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Stat boxes
            Row(
              children: [
                Expanded(
                  child: _statBox(
                    icon: Icons.apartment_rounded,
                    value: companies,
                    label: 'Companies',
                    accent: accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statBox(
                    icon: Icons.description_outlined,
                    value: assets,
                    label: 'Assets',
                    accent: accent,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Recent assets
            Row(
              children: [
                const Text(
                  'RECENT ASSETS',
                  style: PremiumColors.tableHeaderStyle,
                ),
                const Spacer(),
                HoverBuilder(
                  cursor: SystemMouseCursors.click,
                  builder: (context, linkHovered) => GestureDetector(
                    onTap: () => widget.onOpenSection?.call(section),
                    child: Text(
                      'View all',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: PremiumColors.blue,
                        decoration: linkHovered
                            ? TextDecoration.underline
                            : TextDecoration.none,
                        decorationColor: PremiumColors.blue,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            if (recent.isEmpty)
              _emptyRecent()
            else
              ...List.generate(recent.length, (i) {
                final a = recent[i];
                return _assetRow(
                  asset: a,
                  thumb: thumbs[i % thumbs.length],
                  isLast: i == recent.length - 1,
                );
              }),

            const SizedBox(height: 12),

            // CTA
            PremiumButton(
              label: ctaLabel,
              icon: Icons.arrow_forward_rounded,
              gradient: accent.gradient,
              expand: true,
              onPressed: () => widget.onOpenSection?.call(section),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBox({
    required IconData icon,
    required int value,
    required String label,
    required PremiumAccent accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: accent.start),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedCount(
                  value: value,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: PremiumColors.ink,
                    height: 1.1,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: PremiumColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _assetRow({
    required AssetModel asset,
    required PremiumAccent thumb,
    required bool isLast,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: PremiumColors.rowLine)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 36,
            decoration: BoxDecoration(
              gradient: thumb.gradient,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(_thumbIcon(asset.type), size: 17, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: PremiumColors.ink,
                  ),
                ),
                Text(
                  asset.companyName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: PremiumColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PremiumBadge(
            label: _typeLabel(asset.type),
            accent: thumb,
            maxWidth: 120,
          ),
        ],
      ),
    );
  }

  IconData _thumbIcon(String type) => switch (type) {
    AppConstants.poster => Icons.image_outlined,
    AppConstants.reelVideo => Icons.play_arrow_rounded,
    AppConstants.document => Icons.description_outlined,
    AppConstants.websiteLink => Icons.language_rounded,
    AppConstants.webApplication => Icons.desktop_windows_outlined,
    AppConstants.mobileApplication => Icons.phone_android_outlined,
    _ => Icons.folder_outlined,
  };

  String _typeLabel(String type) => switch (type) {
    AppConstants.poster => 'Poster',
    AppConstants.reelVideo => 'Video',
    AppConstants.document => 'Document',
    AppConstants.websiteLink => 'Link',
    AppConstants.webApplication => 'Web App',
    AppConstants.mobileApplication => 'Mobile App',
    _ => type,
  };

  Widget _emptyRecent() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: Text(
        'No assets yet.',
        style: TextStyle(fontSize: 13, color: PremiumColors.faint),
      ),
    );
  }

  // ─── Recent activity strip ──────────────────────────────────
  Widget _buildActivityStrip(bool isMobile) {
    final items = _recentActivity;

    final activityWidgets = List.generate(items.length, (i) {
      final a = items[i];
      final isSd = a.section == AppConstants.softwareDevelopment;
      return _activityItem(
        accent: isSd ? PremiumAccent.violet : PremiumAccent.blue,
        icon: isSd ? Icons.visibility_outlined : Icons.download_rounded,
        verb: isSd ? 'You viewed' : 'You accessed',
        assetName: a.name,
        meta: '${a.companyName} · ${_relativeTime(a.updatedAt)}',
      );
    });

    return PremiumPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeader(
            title: 'Recent Activity',
            icon: Icons.history_rounded,
            compact: true,
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Text(
              'No recent activity.',
              style: TextStyle(fontSize: 13, color: PremiumColors.faint),
            )
          else
            LayoutBuilder(
              builder: (context, box) {
                if (box.maxWidth < 700) {
                  return Column(
                    children: [
                      for (int i = 0; i < activityWidgets.length; i++) ...[
                        if (i > 0) const SizedBox(height: 10),
                        activityWidgets[i],
                      ],
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < activityWidgets.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(child: activityWidgets[i]),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _activityItem({
    required PremiumAccent accent,
    required IconData icon,
    required String verb,
    required String assetName,
    required String meta,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: PremiumColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PremiumColors.line),
      ),
      child: Row(
        children: [
          PremiumIconTile(icon: icon, accent: accent, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 13,
                      color: PremiumColors.muted,
                    ),
                    children: [
                      TextSpan(text: '$verb '),
                      TextSpan(
                        text: assetName,
                        style: TextStyle(
                          color: accent.start,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: PremiumColors.faint,
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
