import 'package:flutter/material.dart';

import '../../../core/widgets/premium_ui.dart';
import '../../../services/api_service.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _logs = [];
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

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

  List<dynamic> get _filteredLogs {
    final query = _search.trim().toLowerCase();

    if (query.isEmpty) {
      return _logs;
    }

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
        (value) => value?.toString().toLowerCase().contains(query) ?? false,
      );
    }).toList();
  }

  String _text(dynamic value, [String fallback = '—']) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _formatDownloadedAt(dynamic value) {
    final text = _text(value, '—');

    if (text == '—') {
      return text;
    }

    final parsed = DateTime.tryParse(text);
    if (parsed == null) {
      return text;
    }

    final local = parsed.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }

  IconData _assetIcon(String type) {
    final value = type.toLowerCase();

    if (value.contains('poster') || value.contains('image')) {
      return Icons.image_outlined;
    }
    if (value.contains('reel') || value.contains('video')) {
      return Icons.videocam_outlined;
    }
    if (value.contains('document') || value.contains('pdf')) {
      return Icons.description_outlined;
    }
    if (value.contains('web')) {
      return Icons.language_outlined;
    }
    if (value.contains('mobile') || value.contains('application')) {
      return Icons.phone_android_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildHeader(bool mobile) {
    return PremiumHero(
      compact: mobile,
      eyebrow: 'Activity log',
      eyebrowIcon: Icons.history_rounded,
      title: 'Download History',
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
    );
  }

  Widget _buildSummaryCard() {
    final maps = _logs.whereType<Map>();
    final files = maps.map((m) => _text(m['file_name'], '')).toSet()
      ..remove('');
    final companies = maps.map((m) => _text(m['company_name'], '')).toSet()
      ..remove('');
    return PremiumStatRow(
      stats: [
        PremiumStat(
          label: 'Total Downloads',
          value: _logs.length,
          icon: Icons.download_rounded,
          accent: PremiumAccent.blue,
          caption: 'All recorded downloads',
        ),
        PremiumStat(
          label: 'Files',
          value: files.length,
          icon: Icons.insert_drive_file_rounded,
          accent: PremiumAccent.violet,
          caption: 'Unique files',
        ),
        PremiumStat(
          label: 'Companies',
          value: companies.length,
          icon: Icons.apartment_rounded,
          accent: PremiumAccent.cyan,
          caption: 'With downloads',
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return LayoutBuilder(
      builder: (context, box) {
        final field = PremiumSearchField(
          controller: _searchController,
          hint: 'Search user, file, asset or company...',
          onChanged: (value) {
            setState(() {
              _search = value;
            });
          },
          onClear: () => setState(() => _search = ''),
        );
        final count = PremiumBadge(
          label: '${_filteredLogs.length} records',
          icon: Icons.receipt_long_rounded,
        );
        if (box.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [field, const SizedBox(height: 10), count],
          );
        }
        return Row(
          children: [
            SizedBox(width: 380, child: field),
            const Spacer(),
            count,
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final hasSearch = _search.trim().isNotEmpty;

    return PremiumEmptyState(
      icon: hasSearch ? Icons.search_off_outlined : Icons.download_outlined,
      title: hasSearch
          ? 'No matching download records found.'
          : 'No downloads recorded yet.',
      message: hasSearch ? 'Try a different search term.' : null,
    );
  }

  // Fixed-height table: the header stays pinned while rows scroll.
  Widget _buildDesktopTable() {
    final rows = _filteredLogs;
    const p = EdgeInsets.symmetric(horizontal: 12);
    Widget head(int flex, String label) => Expanded(
      flex: flex,
      child: Padding(
        padding: p,
        child: Text(label.toUpperCase(), style: PremiumColors.tableHeaderStyle),
      ),
    );
    return PremiumTable(
      minWidth: 980,
      header: PremiumTableHeader(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            head(20, 'User'),
            head(22, 'File'),
            head(18, 'Asset'),
            head(15, 'Company'),
            head(12, 'Type'),
            head(13, 'Downloaded At'),
          ],
        ),
      ),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final item = rows[i];
        final map = item is Map ? item : <dynamic, dynamic>{};
        final type = _text(map['asset_type']);
        Widget cell(int flex, Widget child) => Expanded(
          flex: flex,
          child: Padding(padding: p, child: child),
        );
        return PremiumTableRow(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            children: [
              cell(
                20,
                _userCell(
                  _text(map['user_name']),
                  _text(map['user_email'], ''),
                ),
              ),
              cell(22, _fileCell(_text(map['file_name']), type)),
              cell(
                18,
                Text(
                  _text(map['asset_name']),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: PremiumColors.body,
                  ),
                ),
              ),
              cell(
                15,
                Text(
                  _text(map['company_name']),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: PremiumColors.body,
                  ),
                ),
              ),
              cell(
                12,
                Align(
                  alignment: Alignment.centerLeft,
                  child: _typeChip(type, map['section']),
                ),
              ),
              cell(
                13,
                Text(
                  _formatDownloadedAt(map['created_at']),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: PremiumColors.muted,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      footer: PremiumTableFooter(
        child: Text('Showing ${rows.length} of ${_logs.length} downloads'),
      ),
    );
  }

  Widget _userCell(String name, String email) {
    final initial = name.trim().isEmpty
        ? 'U'
        : name.trim().substring(0, 1).toUpperCase();

    return Row(
      children: [
        PremiumAvatar(
          text: initial,
          accent: PremiumAccent.forText(name),
          size: 34,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: PremiumColors.ink,
                ),
              ),
              if (email.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: PremiumColors.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _fileCell(String fileName, [String type = '']) {
    return Row(
      children: [
        PremiumIconTile(
          icon: _assetIcon(type.isEmpty ? fileName : type),
          accent: PremiumAccent.blue,
          size: 32,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            fileName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: PremiumColors.ink,
            ),
          ),
        ),
      ],
    );
  }

  Widget _typeChip(String type, dynamic section) {
    return PremiumBadge(
      label: type,
      icon: _assetIcon(type),
      accent: section?.toString() == 'Software Development'
          ? PremiumAccent.violet
          : PremiumAccent.blue,
      maxWidth: 150,
    );
  }

  Widget _buildMobileList() {
    final rows = _filteredLogs;

    return Column(
      children: [
        for (var i = 0; i < rows.length; i++)
          Builder(
            builder: (context) {
              final item = rows[i];
              final map = item is Map ? item : <dynamic, dynamic>{};
              final userName = _text(map['user_name']);
              final email = _text(map['user_email'], '');
              final fileName = _text(map['file_name']);
              final assetName = _text(map['asset_name']);
              final companyName = _text(map['company_name']);
              final type = _text(map['asset_type']);
              final section = _text(map['section'], '');

              return Reveal(
                delay: Duration(milliseconds: 40 * (i < 10 ? i : 10)),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: PremiumColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: _userCell(userName, email)),
                          const SizedBox(width: 8),
                          _typeChip(type, section),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1, color: PremiumColors.line),
                      const SizedBox(height: 10),
                      _detailLine('File', fileName),
                      const SizedBox(height: 6),
                      _detailLine('Asset', assetName),
                      const SizedBox(height: 6),
                      _detailLine('Company', companyName),
                      const SizedBox(height: 6),
                      _detailLine(
                        'Downloaded At',
                        _formatDownloadedAt(map['created_at']),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _detailLine(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 105,
          child: Text(
            label.toUpperCase(),
            style: PremiumColors.tableHeaderStyle.copyWith(fontSize: 10.5),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: PremiumColors.ink,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PremiumPage(
      builder: (context, bp) => [
        Reveal(child: _buildHeader(bp.mobile)),
        SizedBox(height: bp.gap),
        _buildSummaryCard(),
        SizedBox(height: bp.gap),
        Reveal(
          delay: const Duration(milliseconds: 320),
          child: PremiumPanel(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: _buildSearchField(),
                ),
                const Divider(height: 1, color: PremiumColors.line),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: PremiumLoading(label: 'Loading downloads...'),
                  )
                else if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: PremiumErrorState(
                      title: 'Unable to load downloads',
                      message: _error!,
                      retryLabel: 'Try Again',
                      onRetry: _loadLogs,
                    ),
                  )
                else if (_filteredLogs.isEmpty)
                  _buildEmptyState()
                else
                  LayoutBuilder(
                    builder: (context, box) => box.maxWidth >= 860
                        ? _buildDesktopTable()
                        : Padding(
                            padding: const EdgeInsets.all(12),
                            child: _buildMobileList(),
                          ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
