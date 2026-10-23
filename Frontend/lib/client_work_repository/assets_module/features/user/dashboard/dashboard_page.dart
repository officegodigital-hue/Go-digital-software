import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
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

  // Thumbnail palette (cycles per row).
  static const _dmThumbs = [
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFF6366F1),
  ];
  static const _sdThumbs = [
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFF0F172A),
  ];

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            isMobile ? 16 : 32,
            isMobile ? 24 : 40,
            isMobile ? 16 : 32,
            32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 96),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _buildErrorState()
              else ...[
                _buildHero(isMobile),
                SizedBox(height: isMobile ? 20 : 28),
                _buildPanels(isMobile),
                SizedBox(height: isMobile ? 16 : 20),
                _buildActivityStrip(isMobile),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorState() => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 46,
            color: Color(0xFF64748B),
          ),
          const SizedBox(height: 14),
          Text(_error ?? 'Unable to load assets.'),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _loadDashboardData,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
        ],
      ),
    ),
  );

  // ─── Hero ───────────────────────────────────────────────────
  Widget _buildHero(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back, $_employeeName',
          style: TextStyle(
            fontSize: isMobile ? 24 : 32,
            height: 1.15,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Access your marketing and software assets in one place.',
          style: TextStyle(
            fontSize: isMobile ? 13 : 15,
            height: 1.45,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  // ─── Panels ─────────────────────────────────────────────────
  Widget _buildPanels(bool isMobile) {
    final dm = _buildPanel(
      section: AppConstants.digitalMarketing,
      subtitle: 'Marketing assets for all your brands and campaigns.',
      gradient: const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
      icon: Icons.campaign_rounded,
      thumbs: _dmThumbs,
      ctaLabel: 'Browse Digital Marketing',
      isMobile: isMobile,
    );
    final sd = _buildPanel(
      section: AppConstants.softwareDevelopment,
      subtitle: 'Software assets, applications and technical resources.',
      gradient: const [Color(0xFF14B8A6), Color(0xFF0D9488)],
      icon: Icons.code_rounded,
      thumbs: _sdThumbs,
      ctaLabel: 'Browse Software Development',
      isMobile: isMobile,
    );

    if (isMobile) {
      return Column(children: [dm, const SizedBox(height: 16), sd]);
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: dm),
          const SizedBox(width: 20),
          Expanded(child: sd),
        ],
      ),
    );
  }

  Widget _buildPanel({
    required String section,
    required String subtitle,
    required List<Color> gradient,
    required IconData icon,
    required List<Color> thumbs,
    required String ctaLabel,
    required bool isMobile,
  }) {
    final assets = _assetCount(section);
    final companies = _companyCount(section);
    final recent = _recentAssets(section);
    final iconSize = isMobile ? 48.0 : 64.0;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: isMobile ? 24 : 28,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: isMobile ? 12 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section,
                      style: TextStyle(
                        fontSize: isMobile ? 18 : 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: isMobile ? 16 : 20),

          // Stat boxes
          Row(
            children: [
              Expanded(
                child: _statBox(
                  icon: Icons.apartment_rounded,
                  value: '$companies',
                  label: 'Companies',
                  compact: isMobile,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statBox(
                  icon: Icons.description_outlined,
                  value: '$assets',
                  label: 'Assets',
                  compact: isMobile,
                ),
              ),
            ],
          ),

          SizedBox(height: isMobile ? 18 : 24),

          // Recent assets
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Assets',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
              GestureDetector(
                onTap: () => widget.onOpenSection?.call(section),
                child: const Text(
                  'View all',
                  style: TextStyle(fontSize: 13, color: Color(0xFF3B82F6)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (recent.isEmpty)
            _emptyRecent()
          else
            ...List.generate(recent.length, (i) {
              final a = recent[i];
              return _assetRow(
                asset: a,
                thumbColor: thumbs[i % thumbs.length],
                isLast: i == recent.length - 1,
              );
            }),

          const SizedBox(height: 20),

          // CTA
          SizedBox(
            width: double.infinity,
            height: isMobile ? 46 : 48,
            child: ElevatedButton(
              onPressed: () => widget.onOpenSection?.call(section),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      ctaLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox({
    required IconData icon,
    required String value,
    required String label,
    bool compact = false,
  }) {
    final iconSize = compact ? 32.0 : 36.0;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 12 : 14,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F6FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: compact ? 16 : 18,
              color: const Color(0xFF3B82F6),
            ),
          ),
          SizedBox(width: compact ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 20 : 22,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
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
    required Color thumbColor,
    required bool isLast,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 48,
            decoration: BoxDecoration(
              color: thumbColor,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  asset.companyName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            asset.type,
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _emptyRecent() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Text(
        'No assets yet.',
        style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
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
        bgColor: isSd ? const Color(0xFFEDE9FE) : const Color(0xFFDBEAFE),
        iconColor: isSd ? const Color(0xFF8B5CF6) : const Color(0xFF3B82F6),
        icon: isSd ? Icons.visibility_outlined : Icons.download_rounded,
        verb: isSd ? 'You viewed' : 'You accessed',
        assetName: a.name,
        meta: '${a.companyName} · ${_relativeTime(a.updatedAt)}',
      );
    });

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              const Text(
                'View all',
                style: TextStyle(fontSize: 13, color: Color(0xFF3B82F6)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const Text(
              'No recent activity.',
              style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            )
          else if (isMobile)
            Column(
              children: [
                for (int i = 0; i < activityWidgets.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  activityWidgets[i],
                ],
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < activityWidgets.length; i++) ...[
                  if (i > 0) const SizedBox(width: 16),
                  Expanded(child: activityWidgets[i]),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _activityItem({
    required Color bgColor,
    required Color iconColor,
    required IconData icon,
    required String verb,
    required String assetName,
    required String meta,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
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
                    color: Color(0xFF64748B),
                  ),
                  children: [
                    TextSpan(text: '$verb '),
                    TextSpan(
                      text: assetName,
                      style: const TextStyle(
                        color: Color(0xFF3B82F6),
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
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
