import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_config.dart';
import '../services/authenticated_http.dart' as http;

class EmployeePerformanceButton extends StatefulWidget {
  final bool onDarkBackground;

  const EmployeePerformanceButton({super.key, this.onDarkBackground = true});

  @override
  State<EmployeePerformanceButton> createState() =>
      _EmployeePerformanceButtonState();
}

class _EmployeePerformanceButtonState extends State<EmployeePerformanceButton> {
  Map<String, dynamic>? _data;
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _refresh = Timer.periodic(const Duration(minutes: 1), (_) => _load());
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _load() async {
    try {
      final response = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/workspace-tasks/performance/me'))
          .timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) return null;
      final data = _map(_map(jsonDecode(response.body))['data']);
      if (mounted) setState(() => _data = data);
      return data;
    } catch (error) {
      debugPrint('Could not load employee performance: $error');
      return null;
    }
  }

  void _openDetails() {
    final request = _load();
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(22, 18, 14, 18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0B3B91), Color(0xFF1D74E8)],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.insights_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Your performance today',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 10),
                  child: SizedBox(
                    width: 480,
                    child: SingleChildScrollView(
                      child: FutureBuilder<Map<String, dynamic>?>(
                        future: request,
                        initialData: _data,
                        builder: (context, snapshot) {
                          final data = snapshot.data ?? _data;
                          if (data == null) {
                            return snapshot.connectionState ==
                                    ConnectionState.waiting
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : const Text(
                                    'Performance is temporarily unavailable.',
                                  );
                          }
                          final performance = _map(data['performance']);
                          final comparison = _map(data['comparison']);
                          final change = _number(comparison['change']);
                          final lowerFactors =
                              (comparison['lowerFactors'] as List?)?.join(
                                ', ',
                              ) ??
                              '';
                          final parts = _maps(performance['parts']);
                          final factors =
                              parts
                                  .where((part) => part['valuePct'] != null)
                                  .toList()
                                ..sort(
                                  (a, b) => _number(
                                    b['pointsLost'],
                                  ).compareTo(_number(a['pointsLost'])),
                                );
                          final theme = Theme.of(context).textTheme;
                          final current = performance['grade'] != 'No Activity';
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                current
                                    ? '${performance['score']}% · ${performance['grade']}'
                                    : 'No scored activity yet',
                                style: theme.headlineSmall,
                              ),
                              if (comparison.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  change == 0
                                      ? 'Same score as ${comparison['date']}'
                                      : '${change.abs()} points ${change < 0 ? 'down' : 'up'} '
                                            'from ${comparison['score']}% on ${comparison['date']}',
                                ),
                                if (change < 0 && lowerFactors.isNotEmpty)
                                  Text('Lower results for $lowerFactors.'),
                              ],
                              if (snapshot.connectionState ==
                                      ConnectionState.done &&
                                  snapshot.data == null)
                                const Text('Showing the last available score.'),
                              const SizedBox(height: 16),
                              PerformanceWorkDetails(data: data),
                              if (factors.isNotEmpty) ...[
                                const SizedBox(height: 18),
                                Text(
                                  'What affected your score',
                                  style: theme.titleMedium,
                                ),
                                for (final factor in factors)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${factor['label']} · ${factor['valuePct']}%',
                                          style: theme.titleSmall,
                                        ),
                                        Text('${factor['evidence']}'),
                                        if (factor['improvement'] != null)
                                          Text(
                                            '${factor['pointsLost']} points below full credit. '
                                            '${factor['improvement']}',
                                          ),
                                      ],
                                    ),
                                  ),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 18, 12),
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final score = _map(_data?['performance']);
    final available = score.isNotEmpty && score['grade'] != 'No Activity';
    return OutlinedButton.icon(
      onPressed: _openDetails,
      style: widget.onDarkBackground
          ? OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
              backgroundColor: Colors.white12,
              minimumSize: const Size(0, 36),
            )
          : null,
      icon: const Icon(Icons.insights_rounded, size: 17),
      label: Text(available ? 'Performance ${score['score']}%' : 'Performance'),
    );
  }
}

class PerformanceWorkDetails extends StatelessWidget {
  final Map<String, dynamic> data;

  const PerformanceWorkDetails({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final attendance = _maps(data['attendance']);
    final sources = _maps(data['sources']);
    final hours = _map(data['workingHours']);
    final theme = Theme.of(context).textTheme;
    String time(Object? value) {
      final date = DateTime.tryParse('${value ?? ''}');
      return date == null ? '—' : DateFormat('h:mm a').format(date);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Attendance', style: theme.titleSmall),
        Text(
          attendance.isEmpty
              ? 'No check-in recorded for this period.'
              : '${hours['available'] ?? '0m'} after breaks · '
                    '${hours['productive'] ?? '0m'} tracked within attendance',
        ),
        if (hours['missingSessionHistory'] == true)
          const Text(
            'Some Content Calendar work has only a cumulative total. '
            'Productivity needs dated sessions for this period.',
          ),
        for (final day in attendance.take(1))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${day['date']} · In ${time(day['checkIn'])} · '
              '${day['live'] == true ? 'Still checked in' : 'Out ${time(day['checkOut'])}'} · '
              '${day['worked'] ?? 'Incomplete attendance'}',
            ),
          ),
        if (attendance.length > 1)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('All attendance days'),
            children: [
              for (final day in attendance)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    '${day['date']} · ${day['worked'] ?? 'Incomplete'}',
                  ),
                  subtitle: Text(
                    'In ${time(day['checkIn'])} · '
                    '${day['live'] == true ? 'Still checked in' : 'Out ${time(day['checkOut'])}'}',
                  ),
                ),
            ],
          ),
        if (sources.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Work by source', style: theme.titleSmall),
          for (final source in sources)
            Text(
              '${source['label']} · ${source['completed']} delivered'
              '${_number(source['trackedSecs']) > 0 ? ' · ${source['tracked']} recorded' : ''}',
            ),
        ],
      ],
    );
  }
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};

List<Map<String, dynamic>> _maps(Object? value) =>
    value is List ? value.whereType<Map>().map(_map).toList() : [];

num _number(Object? value) => value is num ? value : 0;
