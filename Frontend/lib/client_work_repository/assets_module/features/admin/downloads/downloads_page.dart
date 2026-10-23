import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    _loadLogs();
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

  // ── BUILD ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;
        return Scaffold(
          backgroundColor: const Color(0xFFF3F4F6),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 32 : 16,
                28,
                isDesktop ? 32 : 16,
                28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildSummaryBadge(),
                  const SizedBox(height: 20),
                  _buildTableCard(isDesktop),
                  const SizedBox(height: 16),
                  _buildInfoBar(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Header ─────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Download history',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                  height: 1.2,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'View files downloaded by users across the asset library.',
                style: TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        OutlinedButton.icon(
          onPressed: _loading ? null : _loadLogs,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Refresh'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF2563EB),
            side: const BorderSide(color: Color(0xFFBFDBFE)),
            backgroundColor: const Color(0xFFEFF6FF),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ── Summary badge ───────────────────────────────────────────────
  Widget _buildSummaryBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(
              Icons.download_outlined,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${_logs.length} total download${_logs.length == 1 ? '' : 's'}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2563EB),
            ),
          ),
        ],
      ),
    );
  }

  // ── Table card ──────────────────────────────────────────────────
  Widget _buildTableCard(bool isDesktop) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search row inside card
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF111827),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search user, file, asset or company...',
                        hintStyle: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF9CA3AF),
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          size: 18,
                          color: Color(0xFF9CA3AF),
                        ),
                        suffixIcon: _search.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () => setState(() => _search = ''),
                                icon: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 0,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: const BorderSide(
                            color: Color(0xFF2563EB),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '${_filteredLogs.length} record${_filteredLogs.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _buildError()
          else if (_filteredLogs.isEmpty)
            _buildEmptyState()
          else if (isDesktop)
            _buildDesktopTable()
          else
            _buildMobileList(),

          // Footer
          if (!_loading && _error == null && _filteredLogs.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Text(
                'Showing ${_filteredLogs.length} download record${_filteredLogs.length == 1 ? '' : 's'}.',
                style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
            ),
        ],
      ),
    );
  }

  // ── Column header row ──────────────────────────────────────────
  Widget _buildColumnHeader() {
    const style = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Color(0xFF9CA3AF),
      letterSpacing: 0.3,
    );
    const p = EdgeInsets.symmetric(horizontal: 16);
    return Container(
      height: 44,
      color: const Color(0xFFF9FAFB),
      child: Row(
        children: [
          Expanded(
            flex: 34,
            child: Padding(
              padding: p,
              child: const Text('File / asset', style: style),
            ),
          ),
          Expanded(
            flex: 24,
            child: Padding(
              padding: p,
              child: const Text('Downloaded by', style: style),
            ),
          ),
          Expanded(
            flex: 16,
            child: Padding(
              padding: p,
              child: const Text('Company', style: style),
            ),
          ),
          Expanded(
            flex: 12,
            child: Padding(
              padding: p,
              child: const Text('Type', style: style),
            ),
          ),
          Expanded(
            flex: 14,
            child: Padding(
              padding: p,
              child: const Text('Downloaded at', style: style),
            ),
          ),
        ],
      ),
    );
  }

  // ── Desktop table ───────────────────────────────────────────────
  Widget _buildDesktopTable() {
    return Column(
      children: [
        _buildColumnHeader(),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        ...List.generate(_filteredLogs.length, (i) {
          final map = _filteredLogs[i] is Map ? _filteredLogs[i] as Map : {};
          return Column(
            children: [
              _buildRow(map),
              if (i < _filteredLogs.length - 1)
                const Divider(height: 1, color: Color(0xFFF3F4F6)),
            ],
          );
        }),
      ],
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
    final initial = userName.trim().isEmpty
        ? 'U'
        : userName.trim()[0].toUpperCase();
    const p = EdgeInsets.symmetric(horizontal: 16);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // File / asset
          Expanded(
            flex: 34,
            child: Padding(
              padding: p,
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _assetIcon(type),
                      size: 20,
                      color: const Color(0xFF2563EB),
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
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Asset: ${assetName.isEmpty ? '—' : assetName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
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
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE5E7EB),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF374151),
                      ),
                    ),
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
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
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
                              color: Color(0xFF6B7280),
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
                style: const TextStyle(fontSize: 15, color: Color(0xFF374151)),
              ),
            ),
          ),
          // Type chip
          Expanded(
            flex: 12,
            child: Padding(padding: p, child: _typeChip(type, map['section'])),
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
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF111827),
                    ),
                  ),
                  if (dateParts[1].isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      dateParts[1],
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Type chip ──────────────────────────────────────────────────
  Widget _typeChip(String type, dynamic section) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F0FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_assetIcon(type), size: 13, color: const Color(0xFF7C3AED)),
          const SizedBox(width: 5),
          Text(
            type,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF7C3AED),
            ),
          ),
        ],
      ),
    );
  }

  // ── Mobile list ────────────────────────────────────────────────
  Widget _buildMobileList() {
    return Column(
      children: _filteredLogs.map((item) {
        final map = item is Map ? item as Map : {};
        final fileName = _text(map['file_name']);
        final assetName = _text(map['asset_name'], '');
        final userName = _text(map['user_name']);
        final email = _text(map['user_email'], '');
        final company = _text(map['company_name']);
        final type = _text(map['asset_type']);
        final dateParts = _formatDate(map['created_at']);
        final initial = userName.trim().isEmpty
            ? 'U'
            : userName.trim()[0].toUpperCase();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _assetIcon(type),
                      size: 20,
                      color: const Color(0xFF2563EB),
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
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        Text(
                          'Asset: ${assetName.isEmpty ? '—' : assetName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _typeChip(type, map['section']),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(color: Color(0xFFE5E7EB), height: 1),
              const SizedBox(height: 10),
              _mobileDetailRow(
                'Downloaded by',
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE5E7EB),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF374151),
                        ),
                      ),
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
                              color: Color(0xFF111827),
                            ),
                          ),
                          if (email.isNotEmpty)
                            Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
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
                    color: Color(0xFF374151),
                  ),
                ),
              ),
              _mobileDetailRow(
                'Downloaded at',
                Text(
                  '${dateParts[0]}${dateParts[1].isNotEmpty ? '  ${dateParts[1]}' : ''}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _mobileDetailRow(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            ),
          ),
          Expanded(child: value),
        ],
      ),
    );
  }

  // ── Info bar ───────────────────────────────────────────────────
  Widget _buildInfoBar() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF9CA3AF)),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Download history records who downloaded each asset and when.',
            style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
          ),
        ),
      ],
    );
  }

  // ── Error state ────────────────────────────────────────────────
  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 44, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _loadLogs,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────
  Widget _buildEmptyState() {
    final hasSearch = _search.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasSearch ? Icons.search_off_outlined : Icons.download_outlined,
              size: 54,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 14),
            Text(
              hasSearch
                  ? 'No matching download records found.'
                  : 'No downloads recorded yet.',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (hasSearch) ...[
              const SizedBox(height: 6),
              const Text(
                'Try a different search term.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
