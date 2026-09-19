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
        (value) =>
            value?.toString().toLowerCase().contains(query) ?? false,
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

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Download History',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'View files downloaded by users across the asset library.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        OutlinedButton.icon(
          onPressed: _loading ? null : _loadLogs,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Refresh'),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.download_outlined,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Downloads',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_logs.length}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      onChanged: (value) {
        setState(() {
          _search = value;
        });
      },
      decoration: InputDecoration(
        hintText: 'Search user, file, asset or company...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _search.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  setState(() {
                    _search = '';
                  });
                },
                icon: const Icon(Icons.clear),
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasSearch = _search.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 70),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasSearch
                  ? Icons.search_off_outlined
                  : Icons.download_outlined,
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
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopTable() {
    final rows = _filteredLogs;

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 1050),
          child: DataTable(
            headingRowHeight: 52,
            dataRowMinHeight: 68,
            dataRowMaxHeight: 80,
            columnSpacing: 28,
            horizontalMargin: 20,
            columns: const [
              DataColumn(label: Text('User')),
              DataColumn(label: Text('File')),
              DataColumn(label: Text('Asset')),
              DataColumn(label: Text('Company')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('Downloaded At')),
            ],
            rows: rows.map<DataRow>((item) {
              final map = item is Map ? item : <dynamic, dynamic>{};
              final type = _text(map['asset_type']);

              return DataRow(
                cells: [
                  DataCell(
                    SizedBox(
                      width: 150,
                      child: _userCell(
                        _text(map['user_name']),
                        _text(map['user_email'], ''),
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 190,
                      child: _fileCell(_text(map['file_name'])),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 170,
                      child: Text(
                        _text(map['asset_name']),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 145,
                      child: Text(
                        _text(map['company_name']),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(_typeChip(type, map['section'])),
                  DataCell(
                    Text(
                      _formatDownloadedAt(map['created_at']),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _userCell(String name, String email) {
    final initial = name.trim().isEmpty
        ? 'U'
        : name.trim().substring(0, 1).toUpperCase();

    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFFEAF2FF),
          child: Text(
            initial,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
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
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (email.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _fileCell(String fileName) {
    return Row(
      children: [
        const Icon(
          Icons.insert_drive_file_outlined,
          size: 20,
          color: AppColors.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            fileName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _typeChip(String type, dynamic section) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        type,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildMobileList() {
    final rows = _filteredLogs;

    return Column(
      children: rows.map((item) {
        final map = item is Map ? item : <dynamic, dynamic>{};
        final userName = _text(map['user_name']);
        final email = _text(map['user_email'], '');
        final fileName = _text(map['file_name']);
        final assetName = _text(map['asset_name']);
        final companyName = _text(map['company_name']);
        final type = _text(map['asset_type']);
        final section = _text(map['section'], '');

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _userCell(userName, email)),
                    _typeChip(type, section),
                  ],
                ),
                const SizedBox(height: 16),
                _detailLine('File', fileName),
                const SizedBox(height: 9),
                _detailLine('Asset', assetName),
                const SizedBox(height: 9),
                _detailLine('Company', companyName),
                const SizedBox(height: 9),
                _detailLine(
                  'Downloaded At',
                  _formatDownloadedAt(map['created_at']),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _detailLine(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 105,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isDesktop ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 18),
              _buildSummaryCard(),
              const SizedBox(height: 18),
              _buildSearchField(),
              const SizedBox(height: 18),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_error != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 44,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: _loadLogs,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_filteredLogs.isEmpty)
                Card(child: _buildEmptyState())
              else if (isDesktop)
                _buildDesktopTable()
              else
                _buildMobileList(),
            ],
          ),
        );
      },
    );
  }
}
