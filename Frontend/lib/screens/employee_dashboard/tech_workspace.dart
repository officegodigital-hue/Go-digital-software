// lib/screens/employee_dashboard/tech_workspace.dart
//
// Tech Workspace (employee sidebar) and Tech Projects (admin sidebar).
//
//   • TechWorkspacePage        → employee: my projects → project workspace
//   • TechProjectsAdminScreen  → admin: all projects, add / edit, team + in-charge
//
// Project workspace tabs: Overview · Daily Tasks · Corrections · Review ·
// Live Tracking · History.  Every task keeps who added it, start / completed /
// review dates, who reviewed or approved it, its corrections and a history.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:godigital_portal/services/authenticated_http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../layouts/admin_layout.dart';
import '../../services/api_config.dart';
import '../../services/auth_service.dart';
import '../../services/socket_auth.dart';

const _blue = Color(0xFF2563EB);
const _deep = Color(0xFF101B35);
const _sky = Color(0xFF06B6D4);
const _ink = Color(0xFF111827);
const _muted = Color(0xFF667085);
const _line = Color(0xFFE4E7EC);
const _green = Color(0xFF15803D);
const _red = Color(0xFFB91C1C);
const _canvas = Color(0xFFF6F8FC);

// Soft, premium elevation used across the workspace surfaces.
const List<BoxShadow> _softShadow = [];
const List<BoxShadow> _cardShadow = [];

// Unified, low-elevation surface: crisp borders, no floating-card clutter.
BoxDecoration _surface({Color color = Colors.white, Color? border, double radius = 12}) =>
    BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border ?? _line),
      boxShadow: _cardShadow,
    );

// ─────────────────────────────────────────────────────────────────────────────
// Small helpers
// ─────────────────────────────────────────────────────────────────────────────
List<Map<String, dynamic>> _maps(dynamic v) => (v as List? ?? [])
    .whereType<Map>()
    .map((m) => Map<String, dynamic>.from(m))
    .toList();

String _s(dynamic v) {
  final s = v?.toString() ?? '';
  return s == 'null' ? '' : s;
}

int _i(dynamic v) => v is int ? v : (v is num ? v.toInt() : int.tryParse('${v ?? 0}') ?? 0);

String _iso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

String _day(dynamic v) {
  final d = DateTime.tryParse(_s(v));
  return d == null ? '—' : DateFormat('d MMM yyyy').format(d.toLocal());
}

String _stamp(dynamic v) {
  final d = DateTime.tryParse(_s(v));
  return d == null ? '—' : DateFormat('d MMM, h:mm a').format(d.toLocal());
}

String _clock(dynamic secs) {
  final s = _i(secs) < 0 ? 0 : _i(secs);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(s ~/ 3600)}:${two((s % 3600) ~/ 60)}:${two(s % 60)}';
}

String _initials(String name) {
  final w = name.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
  if (w.isEmpty) return '?';
  return w.take(2).map((x) => x[0].toUpperCase()).join();
}

String _me(AuthService a) =>
    '${a.user?['fullName'] ?? a.user?['full_name'] ?? a.user?['name'] ?? ''}'.trim();

(String, Color, Color) _statusStyle(String s) => switch (s) {
      'IN PROGRESS' => ('WORKING', const Color(0xFFDCFCE7), _green),
      'ON HOLD' => ('ON HOLD', const Color(0xFFFEF3C7), const Color(0xFF92400E)),
      'IN REVIEW' => ('IN REVIEW', const Color(0xFFEDE9FE), const Color(0xFF6D28D9)),
      'APPROVED' => ('APPROVED', const Color(0xFFDCFCE7), _green),
      'CORRECTION' => ('CORRECTION', const Color(0xFFFFEDD5), const Color(0xFFC2410C)),
      'ACTIVE' => ('ACTIVE', const Color(0xFFDCFCE7), _green),
      'PLANNING' => ('PLANNING', const Color(0xFFEFF6FF), _blue),
      'COMPLETED' => ('COMPLETED', const Color(0xFFF1F5F9), _muted),
      _ => (s == 'ADDED' ? 'ADDED' : s, const Color(0xFFF1F5F9), _muted),
    };


Widget _chip(String text, Color bg, Color fg, {IconData? icon}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.14)),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 4)],
          Text(
            text,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: fg,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );

Widget _statusChip(String status) {
  final (label, bg, fg) = _statusStyle(status);
  return _chip(label, bg, fg);
}

Widget _meta(IconData icon, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: _muted),
        const SizedBox(width: 4),
        Flexible(
          child: Text(text, style: const TextStyle(fontSize: 11.5, color: _muted, fontWeight: FontWeight.w600)),
        ),
      ],
    );

void _snack(BuildContext c, String m, {bool ok = false}) {
  if (!c.mounted) return;
  ScaffoldMessenger.of(c).showSnackBar(
    SnackBar(content: Text(m), backgroundColor: ok ? _green : null, behavior: SnackBarBehavior.floating),
  );
}

// A consistent section header: tinted icon tile + title (+ optional trailing).
Widget _sectionHeader(IconData icon, String title, {Widget? trailing}) => Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: _blue),
          ),
          const SizedBox(width: 9),
          Text(
            title,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: _ink, letterSpacing: 0.2),
          ),
          if (trailing != null) ...[const Spacer(), trailing],
        ],
      ),
    );

// A friendly, centered empty state used across the tabs.
Widget _emptyState(IconData icon, String title, String subtitle) => Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: _cardShadow),
            child: Icon(icon, size: 34, color: _blue),
          ),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _ink)),
          const SizedBox(height: 4),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: _muted, fontSize: 12.5)),
        ],
      ),
    );

// ─────────────────────────────────────────────────────────────────────────────
// API
// ─────────────────────────────────────────────────────────────────────────────
class TechApiException implements Exception {
  final String message;
  final String? code;
  final Map<String, dynamic> body;
  TechApiException(this.message, {this.code, this.body = const {}});
  @override
  String toString() => message;
}

class _Api {
  final String token;
  final String me;
  const _Api(this.token, this.me);

  Map<String, String> get _h => {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  Uri _u(String path, [Map<String, String>? q]) =>
      Uri.parse('${ApiConfig.baseUrl}/tech-projects$path').replace(
        queryParameters: {'employee': me, ...?q},
      );

  Future<Map<String, dynamic>> _go(Future<http.Response> f) async {
    final res = await f;
    var body = <String, dynamic>{};
    try {
      final d = jsonDecode(res.body);
      if (d is Map) body = Map<String, dynamic>.from(d);
    } catch (_) {}
    if (res.statusCode < 200 || res.statusCode >= 300 || body['success'] == false) {
      throw TechApiException(
        '${body['message'] ?? 'Request failed (${res.statusCode})'}',
        code: body['code']?.toString(),
        body: body,
      );
    }
    return body;
  }

  Future<Map<String, dynamic>> get(String p, [Map<String, String>? q]) =>
      _go(http.get(_u(p, q), headers: _h));
  Future<Map<String, dynamic>> post(String p, [Map<String, dynamic>? b]) =>
      _go(http.post(_u(p), headers: _h, body: jsonEncode({'employee': me, ...?b})));
  Future<Map<String, dynamic>> put(String p, Map<String, dynamic> b) =>
      _go(http.put(_u(p), headers: _h, body: jsonEncode({'employee': me, ...b})));
  Future<Map<String, dynamic>> patch(String p, Map<String, dynamic> b) =>
      _go(http.patch(_u(p), headers: _h, body: jsonEncode({'employee': me, ...b})));
}

// ─────────────────────────────────────────────────────────────────────────────
// Generic loader: loads once, refreshes on socket ticks, ticks running timers
// ─────────────────────────────────────────────────────────────────────────────
class _Loader extends StatefulWidget {
  final Future<Map<String, dynamic>> Function() load;
  final Widget Function(BuildContext, Map<String, dynamic>, Future<void> Function()) builder;
  final ValueNotifier<int>? tick;

  const _Loader({super.key, required this.load, required this.builder, this.tick});

  @override
  State<_Loader> createState() => _LoaderState();
}

class _LoaderState extends State<_Loader> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;
  Timer? _ticker;

  bool _tickAll(dynamic v) {
    var any = false;
    if (v is Map) {
      if (v['running'] == true) {
        v['secs'] = _i(v['secs']) + 1;
        any = true;
      }
      for (final x in v.values) {
        if (_tickAll(x)) any = true;
      }
    } else if (v is List) {
      for (final x in v) {
        if (_tickAll(x)) any = true;
      }
    }
    return any;
  }

  @override
  void initState() {
    super.initState();
    _reload();
    widget.tick?.addListener(_onTick);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _data != null && _tickAll(_data)) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    widget.tick?.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() => _reload(silent: true);

  Future<void> _reload({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final d = await widget.load();
      if (!mounted) return;
      setState(() {
        _data = d;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (!silent || _data == null) _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _data == null) return const Center(child: CircularProgressIndicator());
    if (_data == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error ?? 'Could not load', style: const TextStyle(color: _muted)),
            const SizedBox(height: 8),
            FilledButton(onPressed: _reload, child: const Text('Try again')),
          ],
        ),
      );
    }
    return widget.builder(context, _data!, () => _reload(silent: true));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Entry widgets
// ─────────────────────────────────────────────────────────────────────────────
/// Admin sidebar page: "Tech Projects".
class TechProjectsAdminScreen extends StatelessWidget {
  const TechProjectsAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      pageTitle: 'Tech Projects',
      currentRoute: '/tech-projects',
      child: LayoutBuilder(
        builder: (context, c) {
          final h = c.hasBoundedHeight ? c.maxHeight : MediaQuery.of(context).size.height - 130;
          return SizedBox(height: h < 560 ? 560 : h, child: const _TechHome(admin: true));
        },
      ),
    );
  }
}

/// Employee sidebar page: "Tech Workspace".
class TechWorkspacePage extends StatelessWidget {
  /// When set, open this project directly (deep-link from Day Planner / Live
  /// Tracking / Dashboard / top-bar running chip).
  final String? initialProjectName;
  const TechWorkspacePage({super.key, this.initialProjectName});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _canvas,
      child: _TechHome(admin: false, initialProjectName: initialProjectName),
    );
  }
}

class _TechHome extends StatefulWidget {
  final bool admin;
  final String? initialProjectName;
  const _TechHome({required this.admin, this.initialProjectName});

  @override
  State<_TechHome> createState() => _TechHomeState();
}

class _TechHomeState extends State<_TechHome> {
  final ValueNotifier<int> _tick = ValueNotifier(0);
  io.Socket? _socket;
  Timer? _debounce;
  int? _openId;

  @override
  void initState() {
    super.initState();
    _socket = io.io(
      ApiConfig.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuthFn(authenticateSocket)
          .enableForceNew()
          .disableAutoConnect()
          .build(),
    )..connect();
    _socket!.on('tech_updated', (_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 350), () => _tick.value++);
    });
    // Deep-link: open the given project directly once the page is mounted.
    final target = widget.initialProjectName?.trim() ?? '';
    if (target.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openByName(target));
    }
  }

  // Resolve a project name to its id and open its workspace. Used when another
  // screen navigates straight to a specific tech project.
  Future<void> _openByName(String name) async {
    try {
      final auth = context.read<AuthService>();
      final api = _Api(auth.token ?? '', _me(auth));
      final r = await api.get('/projects');
      final key = name.toLowerCase().trim();
      final match = _maps(r['data']).firstWhere(
        (p) => _s(p['name']).toLowerCase().trim() == key,
        orElse: () => const {},
      );
      final id = _i(match['id']);
      if (id > 0 && mounted) setState(() => _openId = id);
    } catch (_) {
      // Fall back to the projects list if the lookup fails.
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _socket?.dispose();
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final api = _Api(auth.token ?? '', _me(auth));
    if (_openId != null) {
      return _ProjectView(
        key: ValueKey('tech-$_openId'),
        api: api,
        projectId: _openId!,
        tick: _tick,
        onBack: () => setState(() => _openId = null),
      );
    }
    return _ProjectsList(
      api: api,
      admin: widget.admin,
      tick: _tick,
      onOpen: (id) => setState(() => _openId = id),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Projects list
// ─────────────────────────────────────────────────────────────────────────────
class _ProjectsList extends StatelessWidget {
  final _Api api;
  final bool admin;
  final ValueNotifier<int> tick;
  final ValueChanged<int> onOpen;

  const _ProjectsList({required this.api, required this.admin, required this.tick, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return _Loader(
      tick: tick,
      load: () => api.get('/projects'),
      builder: (context, data, reload) {
        final projects = _maps(data['data']);
        final canAdd = data['admin'] == true;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_deep, _blue, _sky],
                  stops: [0.0, 0.58, 1.0],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(color: Color(0x1A2563EB), blurRadius: 14, offset: Offset(0, 5)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                    ),
                    child: const Icon(Icons.terminal_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          admin ? 'Tech Projects' : 'Tech Workspace',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          admin
                              ? 'Create projects, build the team and choose the in-charge.'
                              : 'Your software, UI/UX and security projects — daily tasks, corrections and reviews.',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  if (canAdd)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: _blue),
                      onPressed: () async {
                        if (await showDialog<bool>(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => _ProjectEditor(api: api),
                            ) ==
                            true) {
                          reload();
                        }
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('New project', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                ],
              ),
            ),
            Expanded(
              child: projects.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: _cardShadow,
                            ),
                            child: const Icon(Icons.rocket_launch_rounded, size: 40, color: _blue),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            admin ? 'No projects yet' : 'No projects assigned',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _ink),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            admin
                                ? 'Create the first project to get started.'
                                : 'You are not in any project yet.',
                            style: const TextStyle(color: _muted, fontSize: 12.5),
                          ),
                        ],
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, c) {
                        final cols = c.maxWidth >= 1200 ? 3 : (c.maxWidth >= 760 ? 2 : 1);
                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 2, 14, 16),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            mainAxisExtent: 286,
                          ),
                          itemCount: projects.length,
                          itemBuilder: (context, i) => _projectCard(context, projects[i], canAdd, () => onOpen(_i(projects[i]['id'])), () async {
                            if (await showDialog<bool>(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (_) => _ProjectEditor(api: api, project: projects[i]),
                                ) ==
                                true) {
                              reload();
                            }
                          }),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _projectCard(BuildContext context, Map<String, dynamic> p, bool canEdit, VoidCallback onOpen, VoidCallback onEdit) {
    final counts = Map<String, dynamic>.from(p['counts'] as Map? ?? {});
    final members = _maps(p['members']);
    final target = DateTime.tryParse(_s(p['target_date']));
    String? left;
    if (target != null && _s(p['status']) != 'COMPLETED') {
      final n = DateTime.now();
      final diff = target.difference(DateTime(n.year, n.month, n.day)).inDays;
      left = diff > 0 ? '$diff days left' : diff == 0 ? 'Due today' : '${-diff} days overdue';
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _surface(radius: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_blue, _deep],
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.folder_special_rounded, color: Colors.white, size: 19),
              ),
              Expanded(
                child: Text(
                  _s(p['name']),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _ink),
                ),
              ),
              _statusChip(_s(p['status'])),
              if (canEdit)
                IconButton(
                  tooltip: 'Edit project',
                  visualDensity: VisualDensity.compact,
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 18, color: _blue),
                ),
            ],
          ),
          if (_s(p['client_name']).isNotEmpty)
            Text(_s(p['client_name']), style: const TextStyle(fontSize: 12, color: _muted)),
          const SizedBox(height: 6),
          _meta(Icons.workspace_premium_rounded, 'In-charge: ${_s(p['incharge_name']).isEmpty ? '—' : _s(p['incharge_name'])}'),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('${_i(p['progress'])}% approved',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: _blue)),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _i(p['progress']) / 100,
                    minHeight: 7,
                    backgroundColor: const Color(0xFFE8EEF8),
                    color: _blue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chip('${_i(counts['total'])} tasks', const Color(0xFFEFF6FF), _blue),
              _chip('${_i(counts['in_review'])} in review', const Color(0xFFEDE9FE), const Color(0xFF6D28D9)),
              _chip('${_i(counts['corrections_open'])} corrections', const Color(0xFFFFEDD5), const Color(0xFFC2410C)),
              if (_i(counts['in_progress']) > 0) _chip('${_i(counts['in_progress'])} working', const Color(0xFFDCFCE7), _green),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 30,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final m in members.take(7))
                        Tooltip(
                          message: '${m['employee_name']}${_s(m['role_label']).isEmpty ? '' : ' · ${m['role_label']}'}'
                              '${m['is_incharge'] == true ? ' · In-charge' : ''}',
                          child: Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.all(1.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: m['working'] == true
                                    ? const Color(0xFF16A34A)
                                    : (m['is_incharge'] == true ? const Color(0xFFF59E0B) : Colors.transparent),
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: const Color(0xFFEAF2FF),
                              child: Text(_initials(_s(m['employee_name'])),
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _blue)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (left != null)
                Text(left, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: left.contains('overdue') ? _red : _muted)),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onOpen,
              style: FilledButton.styleFrom(
                backgroundColor: _blue,
                minimumSize: const Size.fromHeight(40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.arrow_forward_rounded, size: 17),
              label: const Text('Open project', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Project editor (admin): details + team (persons only) + in-charge
// ─────────────────────────────────────────────────────────────────────────────
class _ProjectEditor extends StatefulWidget {
  final _Api api;
  final Map<String, dynamic>? project;
  const _ProjectEditor({required this.api, this.project});

  @override
  State<_ProjectEditor> createState() => _ProjectEditorState();
}

class _ProjectEditorState extends State<_ProjectEditor> {
  final _name = TextEditingController();
  final _client = TextEditingController();
  final _desc = TextEditingController();
  final _search = TextEditingController();
  String _start = '';
  String _target = '';
  String _status = 'ACTIVE';
  List<Map<String, dynamic>> _people = [];
  final Set<int> _selected = {};
  int? _incharge;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _q = '';

  @override
  void initState() {
    super.initState();
    final p = widget.project;
    if (p != null) {
      _name.text = _s(p['name']);
      _client.text = _s(p['client_name']);
      _desc.text = _s(p['description']);
      _start = _s(p['start_date']);
      _target = _s(p['target_date']);
      _status = _s(p['status']).isEmpty ? 'ACTIVE' : _s(p['status']);
      for (final m in _maps(p['members'])) {
        _selected.add(_i(m['employee_id']));
        if (m['is_incharge'] == true) _incharge = _i(m['employee_id']);
      }
    }
    _loadPeople();
  }

  @override
  void dispose() {
    _name.dispose();
    _client.dispose();
    _desc.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadPeople() async {
    try {
      final r = await widget.api.get('/people');
      if (!mounted) return;
      setState(() {
        _people = _maps(r['data']);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _pick(bool start) async {
    final cur = DateTime.tryParse(start ? _start : _target) ?? DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: cur,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (d != null) setState(() => start ? _start = _iso(d) : _target = _iso(d));
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return setState(() => _error = 'Enter the project name');
    if (_selected.isEmpty) return setState(() => _error = 'Add at least one team member');
    if (_incharge == null || !_selected.contains(_incharge)) {
      return setState(() => _error = 'Tap the star on a member to make them the project in-charge');
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = {
      'name': _name.text.trim(),
      'client_name': _client.text.trim(),
      'description': _desc.text.trim(),
      'start_date': _start,
      'target_date': _target,
      'status': _status,
      'members': _selected.toList(),
      'incharge_id': _incharge,
    };
    try {
      if (widget.project == null) {
        await widget.api.post('/projects', body);
      } else {
        await widget.api.put('/projects/${widget.project!['id']}', body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final shown = _people.where((p) => q.isEmpty || _s(p['name']).toLowerCase().contains(q)).toList();
    final chosen = _people.where((p) => _selected.contains(_i(p['id']))).toList();
    final editing = widget.project != null;
    return AlertDialog(
      title: Text(editing ? 'Edit project' : 'New project', style: const TextStyle(fontWeight: FontWeight.w900)),
      content: SizedBox(
        width: 560,
        child: _loading
            ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Project name *', border: OutlineInputBorder(), isDense: true),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _client,
                      decoration: const InputDecoration(labelText: 'Client (optional)', border: OutlineInputBorder(), isDense: true),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _desc,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder(), isDense: true),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _pick(true),
                          icon: const Icon(Icons.play_circle_outline_rounded, size: 16),
                          label: Text('Start: ${_start.isEmpty ? 'Select' : _day(_start)}'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _pick(false),
                          icon: const Icon(Icons.flag_outlined, size: 16),
                          label: Text('Target: ${_target.isEmpty ? 'Select' : _day(_target)}'),
                        ),
                        SizedBox(
                          width: 150,
                          child: DropdownButtonFormField<String>(
                            initialValue: _status,
                            isDense: true,
                            decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder(), isDense: true),
                            items: [
                              for (final s in ['PLANNING', 'ACTIVE', 'ON HOLD', 'COMPLETED'])
                                DropdownMenuItem(value: s, child: Text(s)),
                            ],
                            onChanged: (v) => setState(() => _status = v ?? 'ACTIVE'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('TEAM — pick persons (their profile role is used automatically)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _muted)),
                    const SizedBox(height: 6),
                    if (chosen.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final p in chosen)
                            InputChip(
                              avatar: Icon(
                                _incharge == _i(p['id']) ? Icons.star_rounded : Icons.star_border_rounded,
                                size: 18,
                                color: const Color(0xFFF59E0B),
                              ),
                              label: Text(_s(p['name'])),
                              tooltip: 'Tap to make in-charge',
                              onPressed: () => setState(() => _incharge = _i(p['id'])),
                              onDeleted: () => setState(() {
                                _selected.remove(_i(p['id']));
                                if (_incharge == _i(p['id'])) _incharge = null;
                              }),
                            ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _search,
                      onChanged: (v) => setState(() => _q = v),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded, size: 18),
                        hintText: 'Search employee',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 220,
                      decoration: BoxDecoration(border: Border.all(color: _line), borderRadius: BorderRadius.circular(10)),
                      child: ListView(
                        children: [
                          for (final p in shown)
                            CheckboxListTile(
                              dense: true,
                              value: _selected.contains(_i(p['id'])),
                              title: Text(_s(p['name']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              subtitle: _s(p['role']).isEmpty
                                  ? null
                                  : Text(_s(p['role']), style: const TextStyle(fontSize: 11, color: _muted)),
                              onChanged: (v) => setState(() {
                                final id = _i(p['id']);
                                if (v == true) {
                                  _selected.add(id);
                                } else {
                                  _selected.remove(id);
                                  if (_incharge == id) _incharge = null;
                                }
                              }),
                            ),
                        ],
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(_error!, style: const TextStyle(color: _red, fontWeight: FontWeight.w700, fontSize: 12.5)),
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving || _loading ? null : _save,
          child: Text(_saving ? 'Saving…' : (editing ? 'Save changes' : 'Create project')),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Project workspace
// ─────────────────────────────────────────────────────────────────────────────
class _ProjectView extends StatelessWidget {
  final _Api api;
  final int projectId;
  final ValueNotifier<int> tick;
  final VoidCallback onBack;

  const _ProjectView({super.key, required this.api, required this.projectId, required this.tick, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return _Loader(
      tick: tick,
      load: () => api.get('/projects/$projectId'),
      builder: (context, data, reload) {
        final p = Map<String, dynamic>.from(data['data'] as Map);
        final acc = Map<String, dynamic>.from(p['access'] as Map);
        final reviewer = acc['admin'] == true || acc['incharge'] == true;
        final counts = Map<String, dynamic>.from(p['counts'] as Map? ?? {});
        final tabs = <(String, IconData)>[
          ('Overview', Icons.dashboard_rounded),
          ('Daily Tasks', Icons.checklist_rounded),
          ('Corrections', Icons.replay_circle_filled_rounded),
          if (reviewer) ('Review', Icons.fact_check_rounded),
          ('Live Tracking', Icons.timer_rounded),
          ('History', Icons.history_rounded),
        ];
        return DefaultTabController(
          length: tabs.length,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                padding: const EdgeInsets.all(18),
                decoration: _surface(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        TextButton.icon(
                          onPressed: onBack,
                          icon: const Icon(Icons.arrow_back_rounded, size: 17),
                          label: const Text('All projects'),
                        ),
                        Text(_s(p['name']), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: _ink)),
                        _statusChip(_s(p['status'])),
                        _chip('In-charge: ${_s(p['incharge_name']).isEmpty ? '—' : _s(p['incharge_name'])}',
                            const Color(0xFFFEF3C7), const Color(0xFF92400E), icon: Icons.star_rounded),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('${_i(p['progress'])}% approved',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _blue)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: _i(p['progress']) / 100,
                              minHeight: 7,
                              backgroundColor: const Color(0xFFE8EEF8),
                              color: _blue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${_i(counts['total'])} tasks · ${_i(counts['in_review'])} in review · ${_i(counts['corrections_open'])} corrections',
                          style: const TextStyle(fontSize: 11.5, color: _muted, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: _surface(radius: 14),
                  child: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: Colors.white,
                    unselectedLabelColor: _muted,
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                    splashBorderRadius: BorderRadius.circular(10),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                    indicator: BoxDecoration(
                      gradient: const LinearGradient(colors: [_blue, _deep]),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(color: Color(0x330757D5), blurRadius: 10, offset: Offset(0, 4)),
                      ],
                    ),
                    tabs: [
                      for (final t in tabs)
                        Tab(
                          height: 38,
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(t.$2, size: 16),
                            const SizedBox(width: 6),
                            Text(t.$1, style: const TextStyle(fontWeight: FontWeight.w800)),
                          ]),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  children: [
                    _OverviewTab(project: p),
                    _DailyTab(api: api, project: p, tick: tick),
                    _CorrectionsTab(api: api, project: p, tick: tick),
                    if (reviewer) _ReviewTab(api: api, project: p, tick: tick),
                    _LiveTab(api: api, project: p, tick: tick),
                    _HistoryTab(api: api, project: p, tick: tick),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Overview ─────────────────────────────────────────────────────────────────
class _OverviewTab extends StatelessWidget {
  final Map<String, dynamic> project;
  const _OverviewTab({required this.project});

  @override
  Widget build(BuildContext context) {
    final counts = Map<String, dynamic>.from(project['counts'] as Map? ?? {});
    final members = _maps(project['members']);
    Widget tile(String label, String value, IconData icon, {Color color = _blue}) => Container(
          width: 208,
          padding: const EdgeInsets.all(14),
          decoration: _surface(radius: 14),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _muted, letterSpacing: 0.3)),
                const SizedBox(height: 3),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _ink)),
              ]),
            ),
          ]),
        );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        _sectionHeader(Icons.insights_rounded, 'PROJECT SNAPSHOT'),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            tile('START DATE', _day(project['start_date']), Icons.play_circle_outline_rounded),
            tile('TARGET DATE', _day(project['target_date']), Icons.flag_rounded),
            tile('TASKS', '${_i(counts['total'])}', Icons.checklist_rounded),
            tile('APPROVED', '${_i(counts['approved'])}', Icons.verified_rounded, color: _green),
            tile('IN REVIEW', '${_i(counts['in_review'])}', Icons.fact_check_rounded, color: const Color(0xFF6D28D9)),
            tile('CORRECTIONS OPEN', '${_i(counts['corrections_open'])}', Icons.replay_rounded, color: const Color(0xFFC2410C)),
          ],
        ),
        if (_s(project['description']).isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _surface(radius: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionHeader(Icons.info_outline_rounded, 'ABOUT THIS PROJECT'),
              SelectableText(_s(project['description']), style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.45)),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _surface(radius: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sectionHeader(Icons.groups_rounded, 'TEAM',
                trailing: Text('${members.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _muted))),
            for (int i = 0; i < members.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: _line),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: members[i]['working'] == true
                            ? _green
                            : (members[i]['is_incharge'] == true ? const Color(0xFFF59E0B) : Colors.transparent),
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFFEAF2FF),
                      child: Text(_initials(_s(members[i]['employee_name'])),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: _blue)),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_s(members[i]['employee_name']), style: const TextStyle(fontWeight: FontWeight.w800, color: _ink)),
                      if (_s(members[i]['role_label']).isNotEmpty)
                        Text(_s(members[i]['role_label']), style: const TextStyle(fontSize: 11.5, color: _muted)),
                    ]),
                  ),
                  if (members[i]['is_incharge'] == true)
                    _chip('IN-CHARGE', const Color(0xFFFEF3C7), const Color(0xFF92400E), icon: Icons.star_rounded),
                  if (members[i]['working'] == true) ...[
                    const SizedBox(width: 6),
                    _chip('WORKING NOW', const Color(0xFFDCFCE7), _green, icon: Icons.circle),
                  ],
                ]),
              ),
            ],
          ]),
        ),
      ],
    );
  }
}

// ── Daily tasks ──────────────────────────────────────────────────────────────
class _DailyTab extends StatefulWidget {
  final _Api api;
  final Map<String, dynamic> project;
  final ValueNotifier<int> tick;
  const _DailyTab({required this.api, required this.project, required this.tick});

  @override
  State<_DailyTab> createState() => _DailyTabState();
}

class _DailyTabState extends State<_DailyTab> {
  DateTime _date = DateTime.now();
  late String _scope;

  Map<String, dynamic> get _acc => Map<String, dynamic>.from(widget.project['access'] as Map);
  bool get _manager => _acc['admin'] == true || _acc['incharge'] == true;

  @override
  void initState() {
    super.initState();
    _scope = _manager ? 'all' : 'mine';
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.project['id'];
    final isToday = _iso(_date) == _iso(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(18, 10, 18, 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: _surface(radius: 14),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                onPressed: _scope == 'open' ? null : () => setState(() => _date = _date.subtract(const Duration(days: 1))),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              OutlinedButton.icon(
                onPressed: _scope == 'open'
                    ? null
                    : () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (d != null) setState(() => _date = d);
                      },
                icon: const Icon(Icons.calendar_month_rounded, size: 16),
                label: Text(_scope == 'open' ? 'All open tasks' : (isToday ? 'Today · ${_day(_iso(_date))}' : _day(_iso(_date)))),
              ),
              IconButton(
                onPressed: _scope == 'open' ? null : () => setState(() => _date = _date.add(const Duration(days: 1))),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
              if (!isToday && _scope != 'open') TextButton(onPressed: () => setState(() => _date = DateTime.now()), child: const Text('Today')),
              if (_manager)
                for (final s in const [('all', 'Team'), ('mine', 'My tasks'), ('open', 'All open')])
                  ChoiceChip(label: Text(s.$2), selected: _scope == s.$1, onSelected: (_) => setState(() => _scope = s.$1)),
              FilledButton.icon(
                onPressed: () async {
                  if (await _taskForm(context, widget.api, widget.project, date: _date)) widget.tick.value++;
                },
                icon: const Icon(Icons.add_task_rounded, size: 18),
                label: const Text('Add task'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _Loader(
            key: ValueKey('daily-${_iso(_date)}-$_scope'),
            tick: widget.tick,
            load: () => widget.api.get('/projects/$id/tasks', {'date': _iso(_date), 'scope': _scope}),
            builder: (context, data, reload) {
              final tasks = _maps(data['data']);
              if (tasks.isEmpty) {
                return _emptyState(
                  Icons.event_available_rounded,
                  _scope == 'open' ? 'No open tasks' : 'Nothing planned yet',
                  _scope == 'open' ? 'There are no open tasks right now.' : 'Add what you are working on today.',
                );
              }
              final tags = (widget.project['correction_tags'] as List? ?? []).map((e) => '$e').toList();
              final children = <Widget>[];
              String? last;
              for (final t in tasks) {
                final who = _s(t['assigned_to_name']);
                if (_scope != 'mine' && who != last) {
                  children.add(Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 8),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(5, 5, 12, 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF4FB),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: _line),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: _blue,
                            child: Text(_initials(who), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                          ),
                          const SizedBox(width: 8),
                          Text(who, style: const TextStyle(fontWeight: FontWeight.w900, color: _ink, fontSize: 12.5)),
                        ]),
                      ),
                    ]),
                  ));
                  last = who;
                }
                children.add(_TaskCard(task: t, api: widget.api, project: widget.project, correctionTags: tags, onChanged: reload));
              }
              return ListView(padding: const EdgeInsets.fromLTRB(14, 2, 14, 16), children: children);
            },
          ),
        ),
      ],
    );
  }
}

// ── Corrections ──────────────────────────────────────────────────────────────
class _CorrectionsTab extends StatelessWidget {
  final _Api api;
  final Map<String, dynamic> project;
  final ValueNotifier<int> tick;
  const _CorrectionsTab({required this.api, required this.project, required this.tick});

  @override
  Widget build(BuildContext context) {
    final tags = (project['correction_tags'] as List? ?? []).map((e) => '$e').toList();
    return _Loader(
      tick: tick,
      load: () => api.get('/projects/${project['id']}/corrections'),
      builder: (context, data, reload) {
        final rows = _maps(data['data']);
        if (rows.isEmpty) {
          return _emptyState(Icons.task_alt_rounded, 'No open corrections', 'Every task is clean — nothing to fix right now.');
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
          children: [
            _sectionHeader(Icons.build_circle_rounded, 'OPEN CORRECTIONS',
                trailing: _chip('${rows.length}', const Color(0xFFFFEDD5), const Color(0xFFC2410C))),
            for (final c in rows)
              _TaskCard(task: c, api: api, project: project, correctionTags: tags, onChanged: reload, showParent: true),
          ],
        );
      },
    );
  }
}

// ── Review (in-charge / admin) ───────────────────────────────────────────────
class _ReviewTab extends StatelessWidget {
  final _Api api;
  final Map<String, dynamic> project;
  final ValueNotifier<int> tick;
  const _ReviewTab({required this.api, required this.project, required this.tick});

  @override
  Widget build(BuildContext context) {
    final tags = (project['correction_tags'] as List? ?? []).map((e) => '$e').toList();
    return _Loader(
      tick: tick,
      load: () => api.get('/projects/${project['id']}/review'),
      builder: (context, data, reload) {
        final pending = _maps(data['pending']);
        final decided = _maps(data['decided']);
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
          children: [
            _sectionHeader(Icons.fact_check_rounded, 'WAITING FOR REVIEW',
                trailing: _chip('${pending.length}', const Color(0xFFEDE9FE), const Color(0xFF6D28D9))),
            if (pending.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 28),
                alignment: Alignment.center,
                child: _emptyState(Icons.inbox_rounded, 'All caught up', 'Nothing is waiting for your review.'),
              )
            else
              for (final t in pending)
                _TaskCard(task: t, api: api, project: project, correctionTags: tags, onChanged: reload, showAssignee: true),
            const SizedBox(height: 14),
            _sectionHeader(Icons.history_toggle_off_rounded, 'RECENTLY REVIEWED'),
            if (decided.isEmpty)
              const Padding(padding: EdgeInsets.all(8), child: Text('No reviews yet.', style: TextStyle(color: _muted, fontSize: 12.5))),
            for (final t in decided)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: _surface(radius: 12),
                child: Row(children: [
                  _chip(_s(t['review_result']) == 'APPROVED' ? 'APPROVED' : 'CORRECTION',
                      _s(t['review_result']) == 'APPROVED' ? const Color(0xFFDCFCE7) : const Color(0xFFFFEDD5),
                      _s(t['review_result']) == 'APPROVED' ? _green : const Color(0xFFC2410C)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${_s(t['title'])} · ${_s(t['assigned_to_name'])}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: _ink, fontSize: 13),
                    ),
                  ),
                  Text('${_s(t['reviewed_by_name'])} · ${_stamp(t['reviewed_at'])}',
                      style: const TextStyle(fontSize: 11.5, color: _muted)),
                ]),
              ),
          ],
        );
      },
    );
  }
}

// ── Live ─────────────────────────────────────────────────────────────────────
class _LiveTab extends StatelessWidget {
  final _Api api;
  final Map<String, dynamic> project;
  final ValueNotifier<int> tick;
  const _LiveTab({required this.api, required this.project, required this.tick});

  @override
  Widget build(BuildContext context) {
    return _Loader(
      tick: tick,
      load: () => api.get('/projects/${project['id']}/live'),
      builder: (context, data, reload) {
        final rows = _maps(data['data']);
        if (rows.isEmpty) {
          return _emptyState(Icons.bolt_rounded, 'No live activity', 'Nobody is working on this project right now.');
        }
        final activeNow = rows.where((t) => t['running'] == true).length;
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
          children: [
            _sectionHeader(Icons.sensors_rounded, 'LIVE TRACKING',
                trailing: _chip('$activeNow working now', const Color(0xFFDCFCE7), _green, icon: Icons.circle)),
            for (final t in rows)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: t['running'] == true ? const Color(0xFFF0FDF4) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: t['running'] == true ? const Color(0xFFBBF7D0) : _line),
                ),
                child: Row(children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: t['running'] == true ? const Color(0xFF16A34A) : const Color(0xFFF59E0B),
                    child: Text(_initials(_s(t['assigned_to_name'])),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_s(t['title']), style: const TextStyle(fontWeight: FontWeight.w800, color: _ink)),
                      Text('${_s(t['assigned_to_name'])} · ${_s(t['tag'])}', style: const TextStyle(fontSize: 11.5, color: _muted)),
                    ]),
                  ),
                  _statusChip(_s(t['status'])),
                  const SizedBox(width: 10),
                  Text(_clock(t['secs']),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: t['running'] == true ? _green : _ink,
                      )),
                ]),
              ),
          ],
        );
      },
    );
  }
}

// ── History ──────────────────────────────────────────────────────────────────
IconData _historyIcon(String a) => switch (a) {
      'TASK_ADDED' => Icons.add_task_rounded,
      'TASK_STARTED' || 'TASK_RESTARTED' => Icons.play_arrow_rounded,
      'TASK_HELD' => Icons.pause_rounded,
      'TASK_COMPLETED' => Icons.check_rounded,
      'TASK_APPROVED' => Icons.verified_rounded,
      'CORRECTION_RAISED' => Icons.replay_rounded,
      'MEMBER_ADDED' || 'MEMBER_REMOVED' => Icons.group_rounded,
      'TASK_EDITED' => Icons.edit_rounded,
      _ => Icons.circle_outlined,
    };

String _historyLabel(String a) => a.replaceAll('_', ' ').toLowerCase().replaceFirstMapped(RegExp(r'^.'), (m) => m[0]!.toUpperCase());

Widget _historyTile(Map<String, dynamic> h, {bool showTask = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(9)),
          child: Icon(_historyIcon(_s(h['action'])), size: 16, color: _blue),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              '${_historyLabel(_s(h['action']))} · ${_s(h['actor_name'])}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: _ink),
            ),
            if (showTask && _s(h['task_title']).isNotEmpty)
              Text(_s(h['task_title']), style: const TextStyle(fontSize: 11.5, color: _blue, fontWeight: FontWeight.w700)),
            if (_s(h['note']).isNotEmpty)
              Text(_s(h['note']), style: const TextStyle(fontSize: 12, color: _muted)),
            Text(_stamp(h['created_at']), style: const TextStyle(fontSize: 10.5, color: _muted)),
          ]),
        ),
      ]),
    );

class _HistoryTab extends StatelessWidget {
  final _Api api;
  final Map<String, dynamic> project;
  final ValueNotifier<int> tick;
  const _HistoryTab({required this.api, required this.project, required this.tick});

  @override
  Widget build(BuildContext context) {
    return _Loader(
      tick: tick,
      load: () => api.get('/projects/${project['id']}/history'),
      builder: (context, data, reload) {
        final rows = _maps(data['data']);
        if (rows.isEmpty) return _emptyState(Icons.history_rounded, 'No activity yet', 'Project activity will show up here as work happens.');
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
          children: [
            _sectionHeader(Icons.history_rounded, 'ACTIVITY TIMELINE'),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: _surface(radius: 14),
              child: Column(children: [for (final h in rows) _historyTile(h, showTask: true)]),
            ),
          ],
        );
      },
    );
  }
}

Future<void> _showTaskHistory(BuildContext context, _Api api, Map<String, dynamic> task) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('History · ${_s(task['title'])}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
      content: SizedBox(
        width: 480,
        height: 420,
        child: _Loader(
          load: () => api.get('/tasks/${task['id']}/history'),
          builder: (c, data, _) {
            final rows = _maps(data['data']);
            if (rows.isEmpty) return const Center(child: Text('No history yet.'));
            return ListView(children: [for (final h in rows) _historyTile(h)]);
          },
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Task card (tasks and their corrections)
// ─────────────────────────────────────────────────────────────────────────────
class _TaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final _Api api;
  final Map<String, dynamic> project;
  final List<String> correctionTags;
  final Future<void> Function() onChanged;
  final bool nested;
  final bool showAssignee;
  final bool showParent;

  const _TaskCard({
    required this.task,
    required this.api,
    required this.project,
    required this.correctionTags,
    required this.onChanged,
    this.nested = false,
    this.showAssignee = false,
    this.showParent = false,
  });

  Widget _btn(String label, IconData icon, Color color, VoidCallback onTap, {bool filled = false}) {
    final style = ButtonStyle(
      visualDensity: VisualDensity.compact,
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
    );
    return filled
        ? FilledButton.icon(
            style: style.merge(FilledButton.styleFrom(backgroundColor: color)),
            onPressed: onTap,
            icon: Icon(icon, size: 15),
            label: Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
          )
        : OutlinedButton.icon(
            style: style.merge(OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color.withValues(alpha: 0.6)))),
            onPressed: onTap,
            icon: Icon(icon, size: 15),
            label: Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
          );
  }

  @override
  Widget build(BuildContext context) {
    final status = _s(task['status']);
    final isCorrection = _s(task['kind']) == 'CORRECTION';
    final corrections = _maps(task['corrections']);
    final running = task['running'] == true;
    Future<void> work(String action) async {
      if (await _runAction(context, api, task, action)) await onChanged();
    }

    final buttons = <Widget>[
      if (task['can_work'] == true && status == 'ADDED') _btn('START', Icons.play_arrow_rounded, _blue, () => work('start'), filled: true),
      if (task['can_work'] == true && status == 'ON HOLD') _btn('RESTART', Icons.replay_rounded, const Color(0xFFB45309), () => work('restart'), filled: true),
      if (task['can_work'] == true && status == 'IN PROGRESS') ...[
        _btn('HOLD', Icons.pause_rounded, const Color(0xFFEA580C), () => work('hold')),
        _btn('COMPLETE', Icons.check_rounded, _green, () => work('complete'), filled: true),
      ],
      if (task['can_work'] == true && (status == 'ADDED' || status == 'ON HOLD'))
        _btn('ADD TO PLANNER', Icons.playlist_add_rounded, _blue, () async {
          try {
            final r = await api.post('/tasks/${task['id']}/planner');
            _snack(context, '${r['message'] ?? 'Added to today’s Day Planner'}', ok: true);
          } on TechApiException catch (e) {
            _snack(context, e.message);
          }
        }),
      if (task['can_review'] == true)
        _btn('REVIEW', Icons.fact_check_rounded, const Color(0xFF6D28D9), () async {
          if (await _reviewDialog(context, api, task, correctionTags)) await onChanged();
        }, filled: true),
      if (task['can_edit'] == true)
        _btn('EDIT', Icons.edit_rounded, _muted, () async {
          if (await _taskForm(context, api, project, existing: task)) await onChanged();
        }),
      _btn('HISTORY', Icons.history_rounded, _muted, () => _showTaskHistory(context, api, task)),
    ];

    return Container(
      margin: EdgeInsets.only(left: nested ? 22 : 0, bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: nested ? const Color(0xFFFFFBF5) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: running ? const Color(0xFF86EFAC) : (nested ? const Color(0xFFFED7AA) : _line),
          width: running ? 1.5 : 1,
        ),
        boxShadow: running
            ? const [BoxShadow(color: Color(0x2622C55E), blurRadius: 18, offset: Offset(0, 8))]
            : _cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (isCorrection)
                _chip('CORRECTION ${_i(task['round_no'])} · ${_s(task['correction_tag'])}', const Color(0xFFFFEDD5), const Color(0xFFC2410C), icon: Icons.replay_rounded)
              else
                _chip(_s(task['tag']).isEmpty ? 'Task' : _s(task['tag']), const Color(0xFFEFF6FF), _blue),
              _statusChip(status),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: running ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _line),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.timer_outlined, size: 13, color: running ? _blue : _muted),
                  const SizedBox(width: 4),
                  Text(_clock(task['secs']),
                      style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, fontSize: 12, color: running ? _blue : _ink)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(_s(task['title']), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: _ink)),
          if (showParent && _s(task['parent_title']).isNotEmpty)
            Text('On task: ${_s(task['parent_title'])}', style: const TextStyle(fontSize: 11.5, color: _blue, fontWeight: FontWeight.w700)),
          if (_s(task['details']).isNotEmpty) ...[
            const SizedBox(height: 4),
            SelectableText(_s(task['details']), style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.35)),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              if (showAssignee || showParent) _meta(Icons.person_rounded, _s(task['assigned_to_name'])),
              _meta(Icons.person_add_alt_1_rounded, 'Added by ${_s(task['added_by_name'])} (${_s(task['added_by_role'])}) · ${_day(task['task_date'])}'),
              if (_s(task['first_start_at']).isNotEmpty) _meta(Icons.play_circle_outline_rounded, 'Started ${_stamp(task['first_start_at'])}'),
              if (_s(task['completed_at']).isNotEmpty) _meta(Icons.check_circle_outline_rounded, 'Completed ${_stamp(task['completed_at'])}'),
              if (_s(task['reviewed_at']).isNotEmpty)
                _meta(Icons.fact_check_outlined, 'Reviewed ${_stamp(task['reviewed_at'])} by ${_s(task['reviewed_by_name'])}'),
            ],
          ),
          if (_s(task['review_comment']).isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _s(task['review_result']) == 'APPROVED' ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${_s(task['reviewed_by_name'])}: ${_s(task['review_comment'])}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
            ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: buttons),
          if (corrections.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final c in corrections)
              _TaskCard(task: c, api: api, project: project, correctionTags: correctionTags, onChanged: onChanged, nested: true, showAssignee: showAssignee),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialogs
// ─────────────────────────────────────────────────────────────────────────────
Future<String?> _askReason(BuildContext context, String title, String hint) async {
  final c = TextEditingController();
  String? error;
  final r = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: c,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(labelText: 'Reason *', hintText: hint, errorText: error, border: const OutlineInputBorder()),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (c.text.trim().isEmpty) {
                set(() => error = 'Reason is required');
                return;
              }
              Navigator.pop(ctx, c.text.trim());
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    ),
  );
  c.dispose();
  return r;
}

Future<bool> _confirm(BuildContext context, String title, String message) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Complete')),
      ],
    ),
  );
  return r == true;
}

/// Start / restart / hold / complete a task (asks for the hold reason, and for
/// the reason to hold another running task).
Future<bool> _runAction(BuildContext context, _Api api, Map<String, dynamic> t, String action) async {
  final body = <String, dynamic>{};
  if (action == 'hold') {
    final r = await _askReason(context, 'Hold this task', 'Why are you putting it on hold?');
    if (r == null) return false;
    body['reason'] = r;
  }
  if (action == 'complete') {
    if (!await _confirm(context, 'Complete this task?', 'It goes to review. If a correction is needed you will get a correction row to work on.')) {
      return false;
    }
  }
  if (!context.mounted) return false;
  try {
    try {
      await api.post('/tasks/${t['id']}/$action', body);
    } on TechApiException catch (e) {
      if (e.code != 'AUTO_HOLD_REASON_REQUIRED') rethrow;
      final running = (e.body['running'] as List? ?? []).map((r) => '${(r as Map)['title']}').join(', ');
      if (!context.mounted) return false;
      final r = await _askReason(context, 'Put the running task on hold?', '${running.isEmpty ? 'Your running task' : running} will be put on hold. Why?');
      if (r == null) return false;
      await api.post('/tasks/${t['id']}/$action', {...body, 'auto_hold_reason': r});
    }
    return true;
  } on TechApiException catch (e) {
    _snack(context, e.message);
    return false;
  }
}

/// Review: Approve, or send a correction (tag + what to fix). The reviewer's
/// name and the review date are stored by the server.
Future<bool> _reviewDialog(BuildContext context, _Api api, Map<String, dynamic> t, List<String> tags) async {
  var mode = 'APPROVED';
  var tag = tags.isEmpty ? 'Other' : tags.first;
  final c = TextEditingController();
  String? err;
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text('Review · ${_s(t['title'])}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('By ${_s(t['assigned_to_name'])} · completed ${_stamp(t['completed_at'])}',
                  style: const TextStyle(color: _muted, fontSize: 12)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'APPROVED', icon: Icon(Icons.verified_rounded), label: Text('Approve')),
                  ButtonSegment(value: 'CORRECTION', icon: Icon(Icons.replay_rounded), label: Text('Correction')),
                ],
                selected: {mode},
                onSelectionChanged: (v) => set(() => mode = v.first),
              ),
              if (mode == 'CORRECTION') ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: tag,
                  decoration: const InputDecoration(labelText: 'Correction type', border: OutlineInputBorder(), isDense: true),
                  items: [for (final x in tags) DropdownMenuItem(value: x, child: Text(x))],
                  onChanged: (v) => set(() => tag = v ?? tag),
                ),
              ],
              const SizedBox(height: 8),
              TextField(
                controller: c,
                minLines: 2,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: mode == 'APPROVED' ? 'Comment (optional)' : 'What must be corrected? *',
                  errorText: err,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (mode == 'CORRECTION' && c.text.trim().isEmpty) {
                set(() => err = 'Write what must be corrected');
                return;
              }
              try {
                await api.post('/tasks/${t['id']}/review', {'action': mode, 'comment': c.text.trim(), 'tag': tag});
                if (ctx.mounted) Navigator.pop(ctx, true);
              } on TechApiException catch (e) {
                set(() => err = e.message);
              }
            },
            child: Text(mode == 'APPROVED' ? 'Approve' : 'Send correction'),
          ),
        ],
      ),
    ),
  );
  c.dispose();
  return ok == true;
}

/// Add a task (or edit one that has not started).
Future<bool> _taskForm(
  BuildContext context,
  _Api api,
  Map<String, dynamic> project, {
  DateTime? date,
  Map<String, dynamic>? existing,
}) async {
  final acc = Map<String, dynamic>.from(project['access'] as Map);
  final manager = acc['admin'] == true || acc['incharge'] == true;
  final members = _maps(project['members']);
  final tags = (project['tags'] as List? ?? []).map((e) => '$e').toList();
  final title = TextEditingController(text: existing == null ? '' : _s(existing['title']));
  final details = TextEditingController(text: existing == null ? '' : _s(existing['details']));
  var tag = existing == null ? (tags.isEmpty ? 'Other' : tags.first) : (_s(existing['tag']).isEmpty ? 'Other' : _s(existing['tag']));
  if (!tags.contains(tag)) tag = tags.isEmpty ? 'Other' : tags.first;
  var day = existing == null ? (date ?? DateTime.now()) : (DateTime.tryParse(_s(existing['task_date'])) ?? DateTime.now());
  int? assignee = existing == null ? null : _i(existing['assigned_to_id']);
  if (assignee == null && manager && members.isNotEmpty) {
    final mine = members.where((m) => _s(m['employee_name']).toLowerCase() == _s(acc['me']).toLowerCase());
    assignee = _i((mine.isNotEmpty ? mine.first : members.first)['employee_id']);
  }
  String? err;
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(existing == null ? 'Add task' : 'Edit task', style: const TextStyle(fontWeight: FontWeight.w900)),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'What are you working on? *', border: OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: details,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Details', border: OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: tag,
                      decoration: const InputDecoration(labelText: 'Tag', border: OutlineInputBorder(), isDense: true),
                      items: [for (final x in tags) DropdownMenuItem(value: x, child: Text(x))],
                      onChanged: (v) => set(() => tag = v ?? tag),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final d = await showDatePicker(context: ctx, initialDate: day, firstDate: DateTime(2020), lastDate: DateTime(2035));
                      if (d != null) set(() => day = d);
                    },
                    icon: const Icon(Icons.calendar_month_rounded, size: 16),
                    label: Text(_day(_iso(day))),
                  ),
                ]),
                if (manager) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: assignee,
                    decoration: const InputDecoration(labelText: 'Assign to', border: OutlineInputBorder(), isDense: true),
                    items: [
                      for (final m in members) DropdownMenuItem(value: _i(m['employee_id']), child: Text(_s(m['employee_name']))),
                    ],
                    onChanged: (v) => set(() => assignee = v),
                  ),
                ],
                if (err != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(err!, style: const TextStyle(color: _red, fontWeight: FontWeight.w700, fontSize: 12.5)),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (title.text.trim().isEmpty) {
                set(() => err = 'Enter the task');
                return;
              }
              final body = {
                'title': title.text.trim(),
                'details': details.text.trim(),
                'tag': tag,
                'task_date': _iso(day),
                if (manager && assignee != null) 'assigned_to_id': assignee,
              };
              try {
                if (existing == null) {
                  await api.post('/projects/${project['id']}/tasks', body);
                } else {
                  await api.patch('/tasks/${existing['id']}', body);
                }
                if (ctx.mounted) Navigator.pop(ctx, true);
              } on TechApiException catch (e) {
                set(() => err = e.message);
              }
            },
            child: Text(existing == null ? 'Add task' : 'Save'),
          ),
        ],
      ),
    ),
  );
  title.dispose();
  details.dispose();
  return ok == true;
}