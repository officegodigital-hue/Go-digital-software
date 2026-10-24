import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/widgets/premium_ui.dart';
import '../../../services/api_service.dart';

class AdminDownloadsPage extends StatefulWidget {
  const AdminDownloadsPage({super.key});

  @override
  State<AdminDownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<AdminDownloadsPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _logs = [];
  String _search = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Backend: load ──────────────────────────────────────────────
  Future<void> _loadLogs() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final logs = await ApiService.getDownloadLogs();
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ── Backend: filter ────────────────────────────────────────────
  List<dynamic> get _filteredLogs {
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) return _logs;
    return _logs.where((item) {
      if (item is! Map) return false;
      final values = [
        item['user_name'],
        item['user_email'],
        item['file_name'],
        item['asset_name'],
        item['company_name'],
        item['asset_type'],
        item['section'],
      ];
      return values.any(
        (v) => v?.toString().toLowerCase().contains(query) ?? false,
      );
    }).toList();
  }

  // ── Backend: helpers ───────────────────────────────────────────
  String _text(dynamic value, [String fallback = '—']) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  /// Returns ["24 Sep 2026", "3:23 PM"] for display
  List<String> _formatDate(dynamic value) {
    final text = _text(value, '');
    if (text.isEmpty) return ['—', ''];
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return [text, ''];
    final local = parsed.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final datePart = '${local.day} ${months[local.month - 1]} ${local.year}';
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return [datePart, '$hour:$minute $period'];
  }

  IconData _assetIcon(String type) {
    final v = type.toLowerCase();
    if (v.contains('poster') || v.contains('image'))
      return Icons.image_outlined;
    if (v.contains('reel') || v.contains('video'))
      return Icons.videocam_outlined;
    if (v.contains('document') || v.contains('pdf'))
      return Icons.description_outlined;
    if (v.contains('web')) return Icons.language_outlined;
    if (v.contains('mobile') || v.contains('application'))
      return Icons.phone_android_outlined;
    return Icons.image_outlined;
  }

  PremiumAccent _typeAccent(String type) {
    final v = type.toLowerCase();
    if (v.contains('poster') || v.contains('image')) return PremiumAccent.rose;
    if (v.contains('reel') || v.contains('video')) return PremiumAccent.violet;
    if (v.contains('document') || v.contains('pdf')) return PremiumAccent.blue;
    if (v.contains('web')) return PremiumAccent.cyan;
    if (v.contains('mobile') || v.contains('application')) {
      return PremiumAccent.green;
    }
    return PremiumAccent.amber;
  }

  int _uniqueCount(String key, [String? fallbackKey]) => _logs
      .whereType<Map>()
      .map((item) {
        final value = _text(item[key], '');
        return (value.isEmpty && fallbackKey != null
                ? _text(item[fallbackKey], '')
                : value)
            .toLowerCase();
      })
      .where((value) => value.isNotEmpty)
      .toSet()
      .length;

  String _initial(String userName) => userName.trim().isEmpty || userName == '—'
      ? 'U'
      : userName.trim()[0].toUpperCase();

  // ── BUILD ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumColors.surface,
      body: SafeArea(
        child: PremiumPage(
          builder: (context, bp) {
            final isDesktop = bp.width >= 800;
            return [
              Reveal(child: _buildHeader(bp.mobile)),
              SizedBox(height: bp.gap),
              _buildSummaryStats(),
              SizedBox(height: bp.gap),
              Reveal(
                delay: const Duration(milliseconds: 380),
                child: _buildTableCard(isDesktop),
              ),
              SizedBox(height: bp.gap),
              Reveal(
                delay: const Duration(milliseconds: 460),
                child: _buildInfoBar(),
              ),
            ];
          },
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────
  Widget _buildHeader(bool compact) {
    return PremiumHero(
      compact: compact,
      eyebrow: 'Activity log',
      eyebrowIcon: Icons.history_rounded,
      title: 'Download history',
      subtitle: 'View files downloaded by users across the asset library.',
      actions: [
        PremiumButton(
          label: 'Refresh',
          icon: Icons.refresh_rounded,
          iconLeading: true,
          variant: PremiumButtonVariant.glass,
          loading: _loading,
          onPressed: _loading ? null : _loadLogs,
        ),
      ],
      trailing: _buildSummaryBadge(),
    );
  }

  // ── Summary badge ───────────────────────────────────────────────
  Widget _buildSummaryBadge() {
    return PremiumGlassStat(
      icon: Icons.download_rounded,
      value: _logs.length,
      label: 'total download${_logs.length == 1 ? '' : 's'}',
    );
  }

  Widget _buildSummaryStats() {
    return PremiumStatRow(
      stats: [
        PremiumStat(
          label: 'Users',
          value: _uniqueCount('user_email', 'user_name'),
          icon: Icons.people_alt_rounded,
          accent: PremiumAccent.violet,
          caption: 'People who downloaded',
        ),
        PremiumStat(
          label: 'Files',
          value: _uniqueCount('file_name'),
          icon: Icons.insert_drive_file_rounded,
          accent: PremiumAccent.blue,
          caption: 'Different files downloaded',
        ),
        PremiumStat(
          label: 'Companies',
          value: _uniqueCount('company_name'),
          icon: Icons.business_rounded,
          accent: PremiumAccent.green,
          caption: 'Companies with downloads',
        ),
      ],
    );
  }

  // ── Table card ──────────────────────────────────────────────────
  Widget _buildTableCard(bool isDesktop) {
    final count = _filteredLogs.length;
    return PremiumPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search row inside card
          Padding(
            padding: const EdgeInsets.all(14),
            child: LayoutBuilder(
              builder: (context, box) {
                final search = PremiumSearchField(
                  controller: _searchController,
                  hint: 'Search user, file, asset or company...',
                  onChanged: (v) => setState(() => _search = v),
                  onClear: () => setState(() => _search = ''),
                );
                final badge = PremiumBadge(
                  label: '$count record${count == 1 ? '' : 's'}',
                  icon: Icons.receipt_long_rounded,
                  accent: PremiumAccent.slate,
                );
                if (box.maxWidth < 480) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [search, const SizedBox(height: 12), badge],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: search),
                    const SizedBox(width: 16),
                    badge,
                  ],
                );
              },
            ),
          ),

          const Divider(height: 1, color: PremiumColors.line),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: KeyedSubtree(
              key: ValueKey(
                _loading
                    ? 'loading'
                    : _error != null
                    ? 'error'
                    : count == 0
                    ? 'empty'
                    : 'list',
              ),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: PremiumLoading(label: 'Loading downloads...'),
                    )
                  : _error != null
                  ? _buildError()
                  : count == 0
                  ? _buildEmptyState()
                  : isDesktop
                  ? _buildDesktopTable()
                  : _buildMobileList(),
            ),
          ),

          // Footer
          if (!_loading && _error == null && count > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                gradient: PremiumColors.tableHeaderGradient,
                border: Border(top: BorderSide(color: PremiumColors.line)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: Color(0xFF059669),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Showing $count download record${count == 1 ? '' : 's'}.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: PremiumColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Column header row ──────────────────────────────────────────
  Widget _buildColumnHeader() {
    const p = EdgeInsets.symmetric(horizontal: 16);
    Widget cell(int flex, String label) => Expanded(
      flex: flex,
      child: Padding(
        padding: p,
        child: Text(label.toUpperCase(), style: PremiumColors.tableHeaderStyle),
      ),
    );
    return PremiumTableHeader(
      child: Row(
        children: [
          cell(34, 'File / asset'),
          cell(24, 'Downloaded by'),
          cell(16, 'Company'),
          cell(12, 'Type'),
          cell(14, 'Downloaded at'),
        ],
      ),
    );
  }

  // ── Desktop table ───────────────────────────────────────────────
  Widget _buildDesktopTable() {
    final logs = _filteredLogs;
    return PremiumTable(
      minWidth: 900,
      header: _buildColumnHeader(),
      itemCount: logs.length,
      itemBuilder: (context, i) =>
          _buildRow(logs[i] is Map ? logs[i] as Map : {}),
    );
  }

  Widget _buildRow(Map map) {
    final fileName = _text(map['file_name']);
    final assetName = _text(map['asset_name'], '');
    final userName = _text(map['user_name']);
    final email = _text(map['user_email'], '');
    final company = _text(map['company_name']);
    final type = _text(map['asset_type']);
    final dateParts = _formatDate(map['created_at']);
    const p = EdgeInsets.symmetric(horizontal: 16);

    return HoverBuilder(
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: hovered ? PremiumColors.rowHover : Colors.white,
          border: const Border(
            bottom: BorderSide(color: PremiumColors.rowLine),
          ),
        ),
        child: Row(
          children: [
            // File / asset
            Expanded(
              flex: 34,
              child: Padding(
                padding: p,
                child: Row(
                  children: [
                    AnimatedScale(
                      scale: hovered ? 1.08 : 1,
                      duration: const Duration(milliseconds: 220),
                      child: PremiumIconTile(
                        icon: _assetIcon(type),
                        accent: _typeAccent(type),
                        size: 36,
                        iconSize: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: PremiumColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Asset: ${assetName.isEmpty ? '—' : assetName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: PremiumColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Downloaded by
            Expanded(
              flex: 24,
              child: Padding(
                padding: p,
                child: Row(
                  children: [
                    PremiumAvatar(
                      text: _initial(userName),
                      accent: PremiumAccent.forText(userName),
                      size: 36,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: PremiumColors.ink,
                            ),
                          ),
                          if (email.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: PremiumColors.muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Company
            Expanded(
              flex: 16,
              child: Padding(
                padding: p,
                child: Text(
                  company,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: PremiumColors.body,
                  ),
                ),
              ),
            ),
            // Type chip
            Expanded(
              flex: 12,
              child: Padding(
                padding: p,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _typeChip(type, map['section']),
                ),
              ),
            ),
            // Downloaded at
            Expanded(
              flex: 14,
              child: Padding(
                padding: p,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateParts[0],
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: PremiumColors.ink,
                      ),
                    ),
                    if (dateParts[1].isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 13,
                            color: PremiumColors.faint,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              dateParts[1],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: PremiumColors.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Type chip ──────────────────────────────────────────────────
  Widget _typeChip(String type, dynamic section) {
    return PremiumBadge(
      label: type,
      icon: _assetIcon(type),
      accent: _typeAccent(type),
      maxWidth: 160,
    );
  }

  // ── Mobile list ────────────────────────────────────────────────
  Widget _buildMobileList() {
    final items = _filteredLogs;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            Reveal(
              delay: Duration(milliseconds: 40 * math.min(i, 10)),
              child: _buildMobileCard(items[i] is Map ? items[i] as Map : {}),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileCard(Map map) {
    final fileName = _text(map['file_name']);
    final assetName = _text(map['asset_name'], '');
    final userName = _text(map['user_name']);
    final email = _text(map['user_email'], '');
    final company = _text(map['company_name']);
    final type = _text(map['asset_type']);
    final dateParts = _formatDate(map['created_at']);
    final accent = _typeAccent(type);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.soft, Colors.white],
          stops: const [0, 0.45],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PremiumColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PremiumIconTile(
                icon: _assetIcon(type),
                accent: accent,
                size: 42,
                iconSize: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: PremiumColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Asset: ${assetName.isEmpty ? '—' : assetName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: PremiumColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _typeChip(type, map['section']),
          const SizedBox(height: 12),
          const Divider(color: PremiumColors.line, height: 1),
          const SizedBox(height: 8),
          _mobileDetailRow(
            'Downloaded by',
            Row(
              children: [
                PremiumAvatar(
                  text: _initial(userName),
                  accent: PremiumAccent.forText(userName),
                  size: 30,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: PremiumColors.ink,
                        ),
                      ),
                      if (email.isNotEmpty)
                        Text(
                          email,
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
          ),
          _mobileDetailRow(
            'Company',
            Text(
              company,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: PremiumColors.body,
              ),
            ),
          ),
          _mobileDetailRow(
            'Downloaded at',
            Text(
              '${dateParts[0]}${dateParts[1].isNotEmpty ? '  ·  ${dateParts[1]}' : ''}',
              style: const TextStyle(fontSize: 14, color: PremiumColors.body),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileDetailRow(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: PremiumColors.faint),
            ),
          ),
          Expanded(child: value),
        ],
      ),
    );
  }

  // ── Info bar ───────────────────────────────────────────────────
  Widget _buildInfoBar() {
    return const PremiumInfoNote(
      text: 'Download history records who downloaded each asset and when.',
    );
  }

  // ── Error state ────────────────────────────────────────────────
  Widget _buildError() {
    return PremiumErrorState(
      title: 'Unable to load downloads',
      message: _error!,
      retryLabel: 'Try Again',
      onRetry: _loadLogs,
    );
  }

  // ── Empty state ────────────────────────────────────────────────
  Widget _buildEmptyState() {
    final hasSearch = _search.trim().isNotEmpty;
    return PremiumEmptyState(
      icon: hasSearch ? Icons.search_off_rounded : Icons.download_rounded,
      title: hasSearch
          ? 'No matching download records found.'
          : 'No downloads recorded yet.',
      message: hasSearch ? 'Try a different search term.' : null,
    );
  }
}
