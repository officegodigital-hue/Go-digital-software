import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../services/api_service.dart';

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF6B7280);
const _blue = Color(0xFF2563EB);
const _line = Color(0xFFE1E7EF);

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

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFF6F8FA),
    child: FutureBuilder<Map<String, dynamic>>(
      future: _dashboardFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: _button('Retry dashboard', _retry, icon: Icons.refresh),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: _blue));
        }
        final data = snapshot.data!;
        return LayoutBuilder(
          builder: (context, box) {
            final narrow = box.maxWidth < 700;
            final padding = narrow ? 16.0 : 40.0;
            final available = box.maxWidth - padding * 2;
            final stats = [
              (
                'Companies',
                'companies',
                Icons.business_outlined,
                _blue,
                const Color(0xFFE9F2FF),
              ),
              (
                'Assets',
                'assets',
                Icons.layers_outlined,
                const Color(0xFF00A653),
                const Color(0xFFE3F7EC),
              ),
              (
                'Users',
                'users',
                Icons.people_outline,
                const Color(0xFF7C3AED),
                const Color(0xFFF1E9FC),
              ),
              (
                'Shared',
                'shared',
                Icons.share_outlined,
                const Color(0xFFF0A000),
                const Color(0xFFFFF5DC),
              ),
            ];
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                padding,
                narrow ? 24 : 44,
                padding,
                22,
              ),
              child: DefaultTextStyle(
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: _ink,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dashboard',
                            style: TextStyle(
                              fontSize: narrow ? 30 : 38,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Welcome back, Admin. Here is your workspace overview.',
                            style: TextStyle(
                              fontSize: 18,
                              height: 1.5,
                              color: _muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    Wrap(
                      spacing: 20,
                      runSpacing: 16,
                      children: [
                        for (final stat in stats)
                          SizedBox(
                            width: available >= 1000
                                ? (available - 60) / 4
                                : available >= 520
                                ? (available - 20) / 2
                                : available,
                            child: _panel(
                              padding: const EdgeInsets.all(20),
                              child: SizedBox(
                                height: 88,
                                child: Row(
                                  children: [
                                    _circle(stat.$3, stat.$4, stat.$5, 72),
                                    const SizedBox(width: 22),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            stat.$1,
                                            style: const TextStyle(
                                              color: Color(0xFF475569),
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            '${_number(data[stat.$2])}',
                                            style: const TextStyle(
                                              fontSize: 34,
                                              height: 1.1,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    _panel(
                      padding: EdgeInsets.fromLTRB(
                        narrow ? 20 : 32,
                        22,
                        narrow ? 20 : 32,
                        26,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Manage all company assets',
                            style: TextStyle(
                              fontSize: 26,
                              height: 1.3,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.7,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Browse and manage assets by category. Choose a category to get started.',
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.5,
                              color: _muted,
                            ),
                          ),
                          const SizedBox(height: 24),
                          LayoutBuilder(
                            builder: (context, inner) {
                              final cards = [
                                _category(
                                  'Digital Marketing',
                                  'Manage marketing assets including logos, social media content, campaign materials and more.',
                                  Icons.campaign_outlined,
                                  _blue,
                                  const Color(0xFFE7F1FF),
                                  inner.maxWidth < 650,
                                ),
                                _category(
                                  'Software Development',
                                  'Manage development assets including source code, documentation, designs and technical resources.',
                                  Icons.code,
                                  const Color(0xFF7C3AED),
                                  const Color(0xFFF1E8FC),
                                  inner.maxWidth < 650,
                                ),
                              ];
                              if (inner.maxWidth < 1050) {
                                return Column(
                                  children: [
                                    cards[0],
                                    const SizedBox(height: 16),
                                    cards[1],
                                  ],
                                );
                              }
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: cards[0]),
                                  const SizedBox(width: 18),
                                  Expanded(child: cards[1]),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    _panel(
                      padding: EdgeInsets.fromLTRB(
                        narrow ? 20 : 32,
                        20,
                        narrow ? 20 : 32,
                        20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Company overview',
                            style: TextStyle(
                              fontSize: 24,
                              height: 1.3,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'A list of all companies and their asset information.',
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.5,
                              color: _muted,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _overview(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ),
  );

  Widget _category(
    String title,
    String description,
    IconData icon,
    Color color,
    Color background,
    bool compact,
  ) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            height: 1.3,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: const TextStyle(fontSize: 16, height: 1.5, color: _muted),
        ),
      ],
    );
    return _panel(
      padding: const EdgeInsets.all(20),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _circle(icon, color, background, 56),
                    const SizedBox(width: 16),
                    Expanded(child: text),
                  ],
                ),
                const SizedBox(height: 16),
                _button('Open', widget.onOpenAssets),
              ],
            )
          : SizedBox(
              height: 94,
              child: Row(
                children: [
                  _circle(icon, color, background, 74),
                  const SizedBox(width: 32),
                  Expanded(child: text),
                  const SizedBox(width: 16),
                  _button('Open', widget.onOpenAssets),
                ],
              ),
            ),
    );
  }

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

  Widget _overview() => FutureBuilder<List<List<dynamic>>>(
    future: _overviewFuture ??= Future.wait([
      ApiService.getCompanies(),
      ApiService.getAssets(),
    ]),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Align(
          alignment: Alignment.centerLeft,
          child: _button(
            'Retry company overview',
            () => setState(_loadOverview),
            icon: Icons.refresh,
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator(color: _blue)),
        );
      }
      final companies = snapshot.data![0].whereType<Map>().toList();
      final assets = snapshot.data![1].whereType<Map>().toList();
      if (companies.isEmpty) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No companies available.',
            style: TextStyle(color: _muted),
          ),
        );
      }
      return LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: box.maxWidth < 700 ? 700 : box.maxWidth,
            child: _panel(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  Container(
                    height: 42,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF3F5F8),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                    ),
                    child: _row(const [
                      Text('Company'),
                      Text('Section'),
                      Text('Assets'),
                      Text('Action'),
                    ]),
                  ),
                  for (final company in companies)
                    Container(
                      constraints: const BoxConstraints(minHeight: 54),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: _line)),
                      ),
                      child: _row([
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFFE7F1FF),
                              child: Text(
                                (company['name']?.toString() ?? '')
                                        .characters
                                        .firstOrNull
                                        ?.toUpperCase() ??
                                    '?',
                                style: const TextStyle(
                                  color: _blue,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Text(
                                company['name']?.toString() ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _sections(company).join(', '),
                          style: const TextStyle(
                            color: Color(0xFF475569),
                            height: 1.5,
                          ),
                        ),
                        Text(
                          '${assets.where((asset) => asset['company_id']?.toString() == company['id']?.toString()).length}',
                        ),
                        _button('Open', widget.onOpenAssets, outlined: true),
                      ]),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _row(List<Widget> cells) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
    child: Row(
      children: [
        Expanded(flex: 28, child: cells[0]),
        Expanded(flex: 30, child: cells[1]),
        Expanded(flex: 30, child: cells[2]),
        SizedBox(
          width: 128,
          child: Align(alignment: Alignment.centerLeft, child: cells[3]),
        ),
      ],
    ),
  );
  Widget _panel({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
  }) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(8),
    ),
    child: child,
  );
  Widget _circle(IconData icon, Color color, Color background, double size) =>
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Icon(icon, size: 34, color: color),
      );
  Widget _button(
    String label,
    VoidCallback onPressed, {
    bool outlined = false,
    IconData icon = Icons.chevron_right,
  }) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: outlined ? _blue : Colors.white,
      backgroundColor: outlined ? Colors.white : _blue,
      padding: EdgeInsets.symmetric(
        horizontal: outlined ? 16 : 24,
        vertical: outlined ? 9 : 14,
      ),
      minimumSize: Size(outlined ? 90 : 110, outlined ? 36 : 50),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: outlined ? _line : _blue),
      ),
      textStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: outlined ? 14 : 16,
        fontWeight: FontWeight.w500,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [Text(label), const SizedBox(width: 10), Icon(icon, size: 18)],
    ),
  );
}
