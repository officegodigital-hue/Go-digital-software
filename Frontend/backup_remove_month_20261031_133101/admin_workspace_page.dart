// GODIGITAL_ADMIN_COMPLETE_V12
// lib/screens/employee_dashboard/admin_workspace_page.dart
//
// Main admin → Employee Workspace.
//   • Every client card (client + submit date) for the last 3 months, with the
//     same ribbons as the employee workspace plus LATE (deadline rule broken).
//     Cards of the current month are highlighted.
//   • Pending list: every task that broke a Task Deadline Rule.
//   • Open a card → Employee Tasks (all team tasks, live: who is working),
//     Content Calendar, Task Review, Live Tracking, Team Chat, Pending.
//
// This file is a `part` of employee_workspace_page.dart so it can reuse the
// client card, ribbons, header and team chat widgets.
part of 'employee_workspace_page.dart';

const _aBlue = Color(0xFF0757D5);
const _aDeep = Color(0xFF0A3D91);
const _aInk = Color(0xFF14213D);
const _aMuted = Color(0xFF64748B);
const _aLine = Color(0xFFE2E8F0);
const _aLate = Color(0xFFB91C1C);

/// Route page for the admin panel (wrapped in AdminLayout).
class AdminWorkspaceScreen extends StatelessWidget {
  const AdminWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      pageTitle: 'Employee Workspace',
      currentRoute: '/admin-workspace',
      child: LayoutBuilder(
        builder: (context, c) {
          final h = c.hasBoundedHeight
              ? c.maxHeight
              : MediaQuery.of(context).size.height - 130;
          return SizedBox(
            height: h < 560 ? 560 : h,
            child: const AdminWorkspacePage(),
          );
        },
      ),
    );
  }
}

/// The workspace itself (can also be embedded in any admin page).
class AdminWorkspacePage extends StatefulWidget {
  const AdminWorkspacePage({super.key});

  @override
  State<AdminWorkspacePage> createState() => _AdminWorkspacePageState();
}

class _AdminCard {
  final _WorkspaceClient client;
  final int late;
  const _AdminCard(this.client, this.late);

  // CURRENT: unfinished submission due today or later this month.
  // GODIGITAL_ADMIN_FINAL_V5
  // CURRENT only for unfinished submissions due today or later this month.
  // CURRENT only for unfinished work due today or later this month.
  // GODIGITAL_ADMIN_DATE_STATUS_V9
  // CURRENT remains until the submit date ends, even next month.
  bool get isCurrent {
    final date = client.dueDate;
    if (date == null || client.isCompleted) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(date.year, date.month, date.day);

    return !due.isBefore(today);
  }

  // Deadline has passed and client work is incomplete.
  bool get isPastSubmitDate {
    final date = client.dueDate;
    if (date == null || client.isCompleted) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(date.year, date.month, date.day);

    return due.isBefore(today);
  }

  String? get ribbon => isPastSubmitDate ? 'LATE' : client.ribbon;
}

_WorkspaceClient _clientFromAdminCard(Map<String, dynamic> card) {
  int n(dynamic v) => v is int ? v : int.tryParse('${v ?? 0}') ?? 0;
  final tasks = <_WorkspaceTask>[];
  for (final raw in (card['tasks'] as List? ?? []).whereType<Map>()) {
    final t = Map<String, dynamic>.from(raw);
    final inProgress = n(t['in_progress']);
    final rework = n(t['rework']);
    final onHold = n(t['on_hold']);
    final inReview = n(t['in_review']);
    final total = n(t['total']);
    final approved = n(t['approved']);
    tasks.add(
      _WorkspaceTask(
        key: '${t['key']}',
        name: '${t['name'] ?? ''}',
        employee: '${t['employee'] ?? ''}',
        role: '${t['role'] ?? ''}',
        status: inProgress > 0
            ? _WorkspaceTaskStatus.inProgress
            : rework > 0
            ? _WorkspaceTaskStatus.rework
            : onHold > 0
            ? _WorkspaceTaskStatus.onHold
            : inReview > 0
            ? _WorkspaceTaskStatus.inReview
            : (total > 0 && approved >= total)
            ? _WorkspaceTaskStatus.completed
            : _WorkspaceTaskStatus.pending,
        total: total,
        completedCount: approved,
        pendingCount: n(t['pending']),
        inProgressCount: inProgress,
        onHoldCount: onHold,
        inReviewCount: inReview,
        reworkCount: rework,
        awaitingHandoff: t['awaiting_handoff'] == true,
      ),
    );
  }
  return _WorkspaceClient(
    name: '${card['client_name'] ?? ''}',
    submissionDate: '${card['submission_date'] ?? ''}',
    employeeRole: EmployeeRole.values.first,
    tasks: tasks,
    toReview: n(card['to_review']),
    assignedAt: DateTime.tryParse('${card['assigned_at'] ?? ''}')?.toLocal(),
    team: (card['team'] as List? ?? [])
        .whereType<Map>()
        .map((t) => Map<String, dynamic>.from(t))
        .toList(),
  );
}

class _AdminWorkspacePageState extends State<AdminWorkspacePage> {
  List<_AdminCard> _cards = [];
  List<Map<String, dynamic>> _pending = [];
  bool _loading = true;
  String? _error;
  int _tab = 0; // 0 = cards, 1 = pending list
  _AdminCard? _selected;
  String _search = '';
  String _sort = 'current';
  String? _month;
  String _ribbonFilter = 'ALL';
  io.Socket? _socket;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
    _socket = io.io(
      ApiConfig.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .disableAutoConnect()
          .build(),
    )..connect();
    void refresh(_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 800), () {
        if (mounted) _load(silent: true);
      });
    }

    _socket!
      ..on('task_updated', refresh)
      ..on('calendar:assigned', refresh);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _socket?.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final responses = await Future.wait([
        http.get(Uri.parse('${ApiConfig.baseUrl}/workspace-tasks/admin/cards')),
        http.get(
          Uri.parse('${ApiConfig.baseUrl}/workspace-tasks/compliance?late=1'),
        ),
      ]);
      if (responses[0].statusCode != 200) {
        throw Exception(
          'Cards: ${jsonDecode(responses[0].body)['message'] ?? responses[0].statusCode}',
        );
      }
      final cards = <_AdminCard>[];
      for (final raw
          in (jsonDecode(responses[0].body)['data'] as List? ?? [])
              .whereType<Map>()) {
        final card = Map<String, dynamic>.from(raw);
        final client = _clientFromAdminCard(card);
        if (client.tasks.isEmpty) continue;
        cards.add(
          _AdminCard(client, int.tryParse('${card['late'] ?? 0}') ?? 0),
        );
      }
      final pending = responses[1].statusCode == 200
          ? (jsonDecode(responses[1].body)['data'] as List? ?? [])
                .whereType<Map>()
                .map((m) => Map<String, dynamic>.from(m))
                .toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _pending = pending;
        _loading = false;
        _error = null;
        // keep the open card in sync
        if (_selected != null) {
          for (final c in cards) {
            if (c.client.name == _selected!.client.name &&
                c.client.submissionDate == _selected!.client.submissionDate) {
              _selected = c;
            }
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (!silent) _error = '$e'.replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final adminName =
        '${auth.user?['fullName'] ?? auth.user?['full_name'] ?? auth.user?['name'] ?? 'Admin'}'
            .trim();
    final selected = _selected;
    return PremiumTheme.wrap(
      context,
      Container(
        color: const Color(0xFFF4F7FC),
        child: selected != null
            ? _AdminClientView(
                key: ValueKey(
                  'admin-${selected.client.name}-${selected.client.submissionDate}',
                ),
                card: selected,
                adminName: adminName,
                adminId: int.tryParse('${auth.user?['id'] ?? ''}') ?? 0,
                token: auth.token ?? '',
                pending: _pending
                    .where(
                      (p) =>
                          '${p['client']}'.toLowerCase() ==
                              selected.client.name.toLowerCase() &&
                          '${p['submission_date']}' ==
                              selected.client.submissionDate,
                    )
                    .toList(),
                onBack: () => setState(() => _selected = null),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!(MediaQuery.sizeOf(context).width < 600 &&
                      _tab == 0 &&
                      !_loading &&
                      _error == null))
                    _header(),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _error != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _error!,
                                  style: const TextStyle(color: _aMuted),
                                ),
                                const SizedBox(height: 10),
                                FilledButton.icon(
                                  onPressed: _load,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Try again'),
                                ),
                              ],
                            ),
                          )
                        : _tab == 0
                        ? _cardsView()
                        : _PendingList(
                            items: _pending,
                            showClient: true,
                            onOpenClient: (client, date) {
                              final match = _cards.where(
                                (c) =>
                                    c.client.name.toLowerCase() ==
                                        client.toLowerCase() &&
                                    c.client.submissionDate == date,
                              );
                              if (match.isNotEmpty)
                                setState(() => _selected = match.first);
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _header() {
    final lateCards = _cards.where((c) => c.late > 0).length;
    final running = _cards.where((c) => c.client.inProgress > 0).length;
    Widget stat(String label, String value, IconData icon) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
    Widget tabButton(int i, String label, IconData icon, {int? badge}) {
      final on = _tab == i;
      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _tab = i),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: on ? Colors.white : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: on ? _aBlue : Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: on ? _aBlue : Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
              if (badge != null && badge > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_aDeep, _aBlue, Color(0xFF1E88E5)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _aBlue.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.workspaces_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Employee Workspace · All clients',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final stats = Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  stat('cards', '${_cards.length}', Icons.dashboard_rounded),
                  stat(
                    'working now',
                    '$running',
                    Icons.play_circle_outline_rounded,
                  ),
                  stat(
                    'with late tasks',
                    '$lateCards',
                    Icons.warning_amber_rounded,
                  ),
                  stat(
                    'late tasks',
                    '${_pending.length}',
                    Icons.timer_off_outlined,
                  ),
                ],
              );

              final buttons = Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  tabButton(0, 'Client cards', Icons.grid_view_rounded),
                  tabButton(
                    1,
                    'Pending list',
                    Icons.pending_actions_rounded,
                    badge: _pending.length,
                  ),
                ],
              );

              if (constraints.maxWidth < 1100) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    stats,
                    const SizedBox(height: 10),
                    Align(alignment: Alignment.centerRight, child: buttons),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: stats),
                  const SizedBox(width: 16),
                  buttons,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  List<_AdminCard> _visible() {
    final q = _search.trim().toLowerCase();
    final list = _cards.where((c) {
      if (q.isNotEmpty &&
          !c.client.name.toLowerCase().contains(q) &&
          !c.client.team.any(
            (m) => '${m['employee']}'.toLowerCase().contains(q),
          )) {
        return false;
      }
      if (_month == '__last2__') {
        final date = c.client.dueDate;
        if (date == null) return false;

        final now = DateTime.now();
        final start = DateTime(now.year, now.month - 1, 1);
        final end = DateTime(now.year, now.month + 1, 1);

        if (date.isBefore(start) || !date.isBefore(end)) {
          return false;
        }
      } else if (_month != null &&
          (c.client.dueDate == null ||
              _monthKey(c.client.dueDate!) != _month)) {
        return false;
      }
      if (_ribbonFilter == 'ALL') return true;
      if (_ribbonFilter == 'CURRENT') return c.isCurrent;
      if (_ribbonFilter == 'PENDING') return c.ribbon == null;
      return c.ribbon == _ribbonFilter;
    }).toList();
    int byDate(_AdminCard a, _AdminCard b) =>
        (a.client.dueDate ?? DateTime(2100)).compareTo(
          b.client.dueDate ?? DateTime(2100),
        );
    list.sort((a, b) {
      if (a.client.isCompleted != b.client.isCompleted)
        return a.client.isCompleted ? 1 : -1;
      switch (_sort) {
        case 'current':
          if (a.isCurrent != b.isCurrent) return a.isCurrent ? -1 : 1;
          if ((a.late > 0) != (b.late > 0)) return a.late > 0 ? -1 : 1;
          return byDate(a, b);
        case 'date_desc':
          return byDate(b, a);
        case 'name_asc':
          return a.client.name.toLowerCase().compareTo(
            b.client.name.toLowerCase(),
          );
        default:
          return byDate(a, b);
      }
    });
    return list;
  }

  Widget _cardsView() {
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
    final monthKeys =
        _cards
            .map((c) => c.client.dueDate)
            .whereType<DateTime>()
            .map(_monthKey)
            .toSet()
            .toList()
          ..sort();
    const ribbons = [
      'ALL',
      'CURRENT',
      'LATE',
      'NEW',
      'PROCESSING',
      'HOLD',
      'REWORK',
      'OVERDUE',
      'IN REVIEW',
      'PENDING',
      'COMPLETED',
    ];
    int countFor(String f) => switch (f) {
      'ALL' => _cards.length,
      'CURRENT' => _cards.where((c) => c.isCurrent).length,
      'PENDING' => _cards.where((c) => c.ribbon == null).length,
      _ => _cards.where((c) => c.ribbon == f).length,
    };
    final visible = _visible();
    InputDecoration deco(String label, {Widget? prefix}) => InputDecoration(
      labelText: label,
      prefixIcon: prefix,
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );

    // GODIGITAL_ADMIN_FILTER_V3
    Widget filterToolbar(bool mobile) {
      const height = 44.0;

      final statuses = ribbons.toList();

      Widget search() => SizedBox(
        height: height,
        child: TextField(
          style: const TextStyle(fontSize: 13),
          decoration: deco(
            'Search client / employee',
            prefix: const Icon(Icons.search_rounded, size: 18),
          ),
          onChanged: (value) => setState(() => _search = value),
        ),
      );

      Widget sort() => SizedBox(
        height: height,
        child: DropdownButtonFormField<String>(
          key: const ValueKey('admin-sort-v3'),
          initialValue: _sort,
          isExpanded: true,
          decoration: deco('Sort'),
          items: const [
            DropdownMenuItem(
              value: 'current',
              child: Text('Current & late', overflow: TextOverflow.ellipsis),
            ),
            DropdownMenuItem(
              value: 'date_asc',
              child: Text('Submit date up', overflow: TextOverflow.ellipsis),
            ),
            DropdownMenuItem(
              value: 'date_desc',
              child: Text('Submit date down', overflow: TextOverflow.ellipsis),
            ),
            DropdownMenuItem(
              value: 'name_asc',
              child: Text('Client A-Z', overflow: TextOverflow.ellipsis),
            ),
          ],
          onChanged: (value) => setState(() => _sort = value ?? 'current'),
        ),
      );

      Widget month() => SizedBox(
        height: height,
        child: DropdownButtonFormField<String?>(
          key: ValueKey('admin-month-v3-${monthKeys.join("-")}'),
          initialValue: (_month == '__last2__' || monthKeys.contains(_month))
              ? _month
              : null,
          isExpanded: true,
          decoration: deco('Month'),
          items: [
            // GODIGITAL_ADMIN_LAST2_V11
            const DropdownMenuItem<String?>(
              value: '__last2__',
              child: Text('Last 2 months'),
            ),
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Last 3 months'),
            ),
            for (final k in monthKeys)
              DropdownMenuItem<String?>(
                value: k,
                child: Text(
                  '${months[int.parse(k.substring(5)) - 1]} ${k.substring(0, 4)}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) => setState(() => _month = value),
        ),
      );

      Widget status(String f) {
        final selected = _ribbonFilter == f;
        final label = switch (f) {
          'ALL' => 'All',
          'IN REVIEW' => 'Review',
          _ => f[0] + f.substring(1).toLowerCase(),
        };

        return SizedBox(
          height: height,
          child: OutlinedButton(
            onPressed: () => setState(() => _ribbonFilter = f),
            style: OutlinedButton.styleFrom(
              backgroundColor: selected
                  ? const Color(0xFF2563EB)
                  : Colors.white,
              foregroundColor: selected ? Colors.white : _aInk,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              side: const BorderSide(color: _aLine),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              '$label ${countFor(f)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        );
      }

      if (mobile) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            children: [
              search(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: sort()),
                  const SizedBox(width: 8),
                  Expanded(child: month()),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final f in statuses) ...[
                      status(f),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      }

      // GODIGITAL_ADMIN_LIVE_TWO_ROWS_V8
      // Match live Admin Workspace desktop filter arrangement.
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(flex: 3, child: search()),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: sort()),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: month()),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final f in statuses) ...[
                      status(f),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // GODIGITAL_ADMIN_PINNED_V6
    // Only mobile filters pin; all cards remain vertically scrollable.
    if (MediaQuery.sizeOf(context).width < 600) {
      return RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(child: _header()),
            SliverPersistentHeader(
              pinned: true,
              delegate: _AdminPinnedFiltersV6(child: filterToolbar(true)),
            ),
            if (visible.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: Text(
                      'No client cards match these filters.',
                      style: TextStyle(color: _aMuted),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final card = visible[index];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: SizedBox(height: 440, child: _adminCard(card)),
                    );
                  }, childCount: visible.length),
                ),
              ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        filterToolbar(false),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: visible.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 80),
                      Center(
                        child: Text(
                          'No client cards match these filters.',
                          style: TextStyle(color: _aMuted),
                        ),
                      ),
                    ],
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 1200
                          ? 3
                          : constraints.maxWidth >= 760
                          ? 2
                          : 1;
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          mainAxisExtent: 364,
                        ),
                        itemCount: visible.length,
                        itemBuilder: (context, i) => _adminCard(visible[i]),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _adminCard(_AdminCard card) {
    final running = card.client.inProgress;
    Widget tag(String text, Color bg, Color fg, IconData icon) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 26,
          child: Row(
            children: [
              if (card.isCurrent)
                tag('CURRENT', _aBlue, Colors.white, Icons.star_rounded),
              if (card.isCurrent) const SizedBox(width: 6),
              if (running > 0)
                tag(
                  '$running working now',
                  const Color(0xFFDCFCE7),
                  const Color(0xFF15803D),
                  Icons.circle,
                ),
              if (running > 0) const SizedBox(width: 6),
              if (card.late > 0 && !card.isCurrent)
                tag(
                  '${card.late} late',
                  const Color(0xFFFEE2E2),
                  _aLate,
                  Icons.warning_amber_rounded,
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            decoration: card.isCurrent
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _aBlue, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: _aBlue.withValues(alpha: 0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  )
                : null,
            child: _RibbonedCard(
              ribbon: card.ribbon,
              child: _ClientCard(
                client: card.client,
                onOpen: () => setState(() => _selected = card),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// One client card opened by the admin
// ─────────────────────────────────────────────────────────────────────────────
class _AdminClientView extends StatefulWidget {
  final _AdminCard card;
  final String adminName;
  final int adminId;
  final String token;
  final List<Map<String, dynamic>> pending;
  final VoidCallback onBack;

  const _AdminClientView({
    super.key,
    required this.card,
    required this.adminName,
    required this.adminId,
    required this.token,
    required this.pending,
    required this.onBack,
  });

  @override
  State<_AdminClientView> createState() => _AdminClientViewState();
}

class _AdminClientViewState extends State<_AdminClientView> {
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _sheets = [];
  List<Map<String, dynamic>> _compliance = [];
  bool _loading = true;
  String? _error;
  String? _selectedGroup; // "employee|groupKey"
  io.Socket? _socket;
  Timer? _debounce;
  Timer? _ticker;

  _WorkspaceClient get client => widget.card.client;

  @override
  void initState() {
    super.initState();
    _load();
    _socket = io.io(
      ApiConfig.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .disableAutoConnect()
          .build(),
    )..connect();
    _socket!.on('task_updated', (_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        if (mounted) _load(silent: true);
      });
    });
    // Running timers tick every second.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      var changed = false;
      for (final row in _allRows()) {
        if (row['state'] == 'IN PROGRESS') {
          row['current_secs'] =
              (int.tryParse('${row['current_secs'] ?? 0}') ?? 0) + 1;
          changed = true;
        }
      }
      for (final s in _sheets) {
        if (s['running'] == true) {
          s['duration_secs'] =
              (int.tryParse('${s['duration_secs'] ?? 0}') ?? 0) + 1;
          changed = true;
        }
      }
      if (changed) setState(() {});
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ticker?.cancel();
    _socket?.dispose();
    super.dispose();
  }

  Iterable<Map<String, dynamic>> _allRows() sync* {
    for (final m in _members) {
      for (final g in (m['groups'] as List? ?? []).whereType<Map>()) {
        for (final r in (g['rows'] as List? ?? []).whereType<Map>()) {
          yield r.cast<String, dynamic>();
        }
      }
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/workspace-tasks/admin/tasks').replace(
          queryParameters: {
            'client': client.name,
            'date': client.submissionDate,
          },
        ),
      );
      final body = jsonDecode(res.body);
      if (res.statusCode != 200)
        throw Exception(body['message'] ?? 'Server ${res.statusCode}');
      final data = Map<String, dynamic>.from(body['data'] as Map);
      List<Map<String, dynamic>> maps(dynamic v) => (v as List? ?? [])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      final members = maps(data['members']);
      for (final m in members) {
        final groups = maps(m['groups']);
        for (final g in groups) {
          g['rows'] = maps(g['rows']);
        }
        m['groups'] = groups;
      }
      if (!mounted) return;
      setState(() {
        _members = members;
        _sheets = maps(data['sheets']);
        _compliance = maps(data['compliance']);
        _loading = false;
        _error = null;
        // pick the first running group (or the first group) on first load
        if (_selectedGroup == null) {
          String? first;
          for (final m in members) {
            for (final g
                in (m['groups'] as List).cast<Map<String, dynamic>>()) {
              final key = '${m['employee']}|${g['key']}';
              first ??= key;
              if ((g['rows'] as List).cast<Map<String, dynamic>>().any(
                (r) => r['state'] == 'IN PROGRESS',
              )) {
                _selectedGroup = key;
                break;
              }
            }
            if (_selectedGroup != null) break;
          }
          _selectedGroup ??= first;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (!silent) _error = '$e'.replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lateItems = _compliance.where((c) => c['status'] == 'LATE').toList();
    final tabs = <(String, IconData, int)>[
      (
        'Employee Tasks',
        Icons.groups_2_rounded,
        _allRows().where((r) => r['state'] == 'IN PROGRESS').length,
      ),
      ('Content Calendar', Icons.calendar_month_rounded, 0),
      (
        'Task Review',
        Icons.fact_check_rounded,
        _allRows().where((r) => r['state'] == 'IN REVIEW').length,
      ),
      ('Live Tracking', Icons.timer_rounded, 0),
      ('Team Chat', Icons.forum_rounded, 0),
      ('Pending', Icons.pending_actions_rounded, lateItems.length),
    ];
    return DefaultTabController(
      length: tabs.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: _ClientContextHeader(
              client: client,
              role: 'Admin',
              employeeName: widget.adminName,
              onBack: widget.onBack,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _aLine),
              ),
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: _aBlue,
                unselectedLabelColor: _aMuted,
                indicatorColor: _aBlue,
                tabs: [
                  for (final t in tabs)
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(t.$2, size: 17),
                          const SizedBox(width: 6),
                          Text(
                            t.$1,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (t.$3 > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: t.$1 == 'Pending'
                                    ? const Color(0xFFEF4444)
                                    : _aBlue,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${t.$3}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
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
          const SizedBox(height: 10),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, style: const TextStyle(color: _aMuted)),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  )
                : TabBarView(
                    children: [
                      _WorkspaceTabKeepAlive(child: _employeeTasks()),
                      _WorkspaceTabKeepAlive(
                        child: ContentCalendarScreen(
                          key: ValueKey('admin-cc-${client.name}'),
                          apiBaseUrl: ApiConfig.baseUrl,
                          authToken: widget.token,
                          currentUserId: widget.adminId,
                          currentUserName: widget.adminName,
                          currentUserRole: 'admin',
                          initialClient: {
                            'client_name': client.name,
                            'submission_date': client.submissionDate,
                          },
                          myTasksMode: false,
                          readOnly: true,
                        ),
                      ),
                      // Main admin: Approve / Pending / Rework / Reject any row.
                      _WorkspaceTabKeepAlive(
                        child: WorkspaceTaskReviewSection(
                          key: ValueKey(
                            'admin-review-${client.name}-${client.submissionDate}',
                          ),
                          clientName: client.name,
                          submissionDate: client.submissionDate,
                          employeeName: widget.adminName,
                          authToken: widget.token,
                          adminMode: true,
                        ),
                      ),
                      _WorkspaceTabKeepAlive(child: _live()),
                      _WorkspaceTabKeepAlive(
                        child: _WorkspaceTeamChat(
                          key: ValueKey('admin-chat-${client.name}'),
                          employeeName: widget.adminName,
                          clientName: client.name,
                        ),
                      ),
                      _WorkspaceTabKeepAlive(
                        child: _PendingList(
                          items: _compliance,
                          showClient: false,
                          showAll: true,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ── Employee Tasks ─────────────────────────────────────────────────────────
  Map<String, dynamic>? _complianceFor(
    Map<String, dynamic> member,
    Map<String, dynamic> g,
  ) {
    final c = g['compliance'];
    return c is Map ? Map<String, dynamic>.from(c) : null;
  }

  Widget _employeeTasks() {
    if (_members.isEmpty) {
      return const Center(
        child: Text(
          'No tasks are assigned on this client yet.',
          style: TextStyle(color: _aMuted),
        ),
      );
    }
    final chips = <Widget>[];
    Map<String, dynamic>? selMember;
    Map<String, dynamic>? selGroup;
    for (final m in _members) {
      for (final g in (m['groups'] as List).cast<Map<String, dynamic>>()) {
        final key = '${m['employee']}|${g['key']}';
        final rows = (g['rows'] as List).cast<Map<String, dynamic>>();
        final running = rows.any((r) => r['state'] == 'IN PROGRESS');
        final done = rows
            .where(
              (r) => r['parent_item_id'] == null && r['state'] == 'APPROVED',
            )
            .length;
        final total =
            (int.tryParse('${g['assigned_count'] ?? 0}') ?? 0) >
                rows.where((r) => r['parent_item_id'] == null).length
            ? int.tryParse('${g['assigned_count'] ?? 0}') ?? 0
            : rows.where((r) => r['parent_item_id'] == null).length;
        final late = _complianceFor(m, g)?['status'] == 'LATE';
        final selected = key == _selectedGroup;
        if (selected) {
          selMember = m;
          selGroup = g;
        }
        chips.add(
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _selectedGroup = key),
            child: Container(
              width: 230,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected
                    ? _aBlue
                    : (late ? const Color(0xFFFFF1F2) : Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? _aBlue
                      : late
                      ? const Color(0xFFFCA5A5)
                      : _aLine,
                  width: late && !selected ? 1.5 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: _aBlue.withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: selected
                        ? Colors.white
                        : const Color(0xFFEAF2FF),
                    child: Text(
                      _clientInitials('${m['employee']}'),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: _aBlue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${g['deliverable'] ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: selected ? Colors.white : _aInk,
                          ),
                        ),
                        Text(
                          '${m['employee']} · ${g['role_label'] ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: selected ? Colors.white70 : _aMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$done/$total',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: selected ? Colors.white : _aBlue,
                        ),
                      ),
                      if (running)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.circle,
                              size: 7,
                              color: selected
                                  ? const Color(0xFF86EFAC)
                                  : const Color(0xFF16A34A),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'LIVE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFF15803D),
                              ),
                            ),
                          ],
                        )
                      else if (late)
                        Text(
                          'LATE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: selected ? Colors.white : _aLate,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Wrap(spacing: 10, runSpacing: 10, children: chips),
        const SizedBox(height: 16),
        if (selGroup != null && selMember != null)
          _groupDetail(selMember!, selGroup!),
      ],
    );
  }

  Widget _stateBadge(String state) {
    final (label, bg, fg) = switch (state) {
      'IN PROGRESS' => (
        'WORKING',
        const Color(0xFFDCFCE7),
        const Color(0xFF15803D),
      ),
      'ON HOLD' => (
        'ON HOLD',
        const Color(0xFFFEF3C7),
        const Color(0xFF92400E),
      ),
      'IN REVIEW' => (
        'IN REVIEW',
        const Color(0xFFEDE9FE),
        const Color(0xFF6D28D9),
      ),
      'REWORK' => ('REWORK', const Color(0xFFFFEDD5), const Color(0xFFC2410C)),
      'APPROVED' => (
        'APPROVED',
        const Color(0xFFDCFCE7),
        const Color(0xFF15803D),
      ),
      'REJECTED' => (
        'REJECTED',
        const Color(0xFFFEE2E2),
        const Color(0xFFB91C1C),
      ),
      _ => ('NOT STARTED', const Color(0xFFF1F5F9), _aMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: fg),
      ),
    );
  }

  static String _timer(dynamic secs) {
    final s = int.tryParse('${secs ?? 0}') ?? 0;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(s ~/ 3600)}:${two((s % 3600) ~/ 60)}:${two(s % 60)}';
  }

  static String _when(dynamic v) {
    final d = DateTime.tryParse('${v ?? ''}');
    if (d == null) return '—';
    return DateFormat('d MMM, h:mm a').format(d.toLocal());
  }

  Widget _groupDetail(Map<String, dynamic> m, Map<String, dynamic> g) {
    final rows = (g['rows'] as List).cast<Map<String, dynamic>>();
    final comp = _complianceFor(m, g);
    final issues = (comp?['issues'] as List? ?? []).whereType<Map>().toList();
    final workingNow = rows.where((r) => r['state'] == 'IN PROGRESS').toList();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _aLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PremiumTheme.dialogHeader(
            '${g['deliverable'] ?? ''}',
            icon: Icons.task_alt_rounded,
            subtitle:
                '${m['employee']} · ${g['role_label'] ?? ''} · '
                '${rows.where((r) => r['parent_item_id'] == null).length} rows',
          ),
          if (workingNow.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 9, color: Color(0xFF16A34A)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${m['employee']} is working now on row ${workingNow.map((r) => r['display_no']).join(', ')}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ),
                  Text(
                    _timer(workingNow.first['current_secs']),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF15803D),
                    ),
                  ),
                ],
              ),
            ),
          if (issues.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final i in issues)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 15,
                            color: _aLate,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${i['message']}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: _aLate,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                g['awaiting_handoff'] == true
                    ? 'Waiting for the Page / Ads Handler to prepare and assign this in the Content Calendar.'
                    : 'No rows yet.',
                style: const TextStyle(color: _aMuted),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(14),
              child: DataTable(
                headingRowHeight: 38,
                dataRowMinHeight: 44,
                dataRowMaxHeight: 64,
                headingTextStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: _aMuted,
                ),
                columns: const [
                  DataColumn(label: Text('ROW')),
                  DataColumn(label: Text('TASK')),
                  DataColumn(label: Text('STATUS')),
                  DataColumn(label: Text('WORKED')),
                  DataColumn(label: Text('STARTED')),
                  DataColumn(label: Text('SUBMITTED')),
                  DataColumn(label: Text('SUBMIT DATE')),
                  DataColumn(label: Text('BY')),
                ],
                rows: [
                  for (final r in rows)
                    DataRow(
                      color: WidgetStatePropertyAll(
                        r['state'] == 'IN PROGRESS'
                            ? const Color(0xFFF0FDF4)
                            : null,
                      ),
                      cells: [
                        DataCell(
                          Text(
                            '${r['display_no']}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 260,
                            child: Text(
                              '${(r['hook_headline'] ?? '').toString().isNotEmpty ? r['hook_headline'] : r['task_description'] ?? ''}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        DataCell(_stateBadge('${r['state']}')),
                        DataCell(
                          Text(
                            _timer(r['current_secs']),
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w800,
                              color: r['state'] == 'IN PROGRESS'
                                  ? const Color(0xFF15803D)
                                  : _aInk,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            _when(r['start_time']),
                            style: const TextStyle(fontSize: 11.5),
                          ),
                        ),
                        DataCell(
                          Text(
                            _when(r['complete_time']),
                            style: const TextStyle(fontSize: 11.5),
                          ),
                        ),
                        DataCell(
                          Text(
                            _formatDate('${r['submit_date'] ?? ''}'),
                            style: const TextStyle(fontSize: 11.5),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (r['state'] == 'IN PROGRESS') ...[
                                const Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: Color(0xFF16A34A),
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                '${(r['employee_name'] ?? '').toString().isNotEmpty ? r['employee_name'] : m['employee']}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Live Tracking: who is working / on hold right now ──────────────────────
  Widget _live() {
    final live = <Widget>[];
    Widget tile({
      required String who,
      required String title,
      required String sub,
      required String state,
      required dynamic secs,
    }) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: state == 'IN PROGRESS' ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: state == 'IN PROGRESS' ? const Color(0xFFBBF7D0) : _aLine,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: state == 'IN PROGRESS'
                ? const Color(0xFF16A34A)
                : const Color(0xFFF59E0B),
            child: Text(
              _clientInitials(who),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: _aInk,
                  ),
                ),
                Text(
                  sub,
                  style: const TextStyle(fontSize: 11.5, color: _aMuted),
                ),
              ],
            ),
          ),
          _stateBadge(state),
          const SizedBox(width: 10),
          Text(
            _timer(secs),
            style: TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: state == 'IN PROGRESS' ? const Color(0xFF15803D) : _aInk,
            ),
          ),
        ],
      ),
    );

    final rows =
        <(Map<String, dynamic>, Map<String, dynamic>, Map<String, dynamic>)>[];
    for (final m in _members) {
      for (final g in (m['groups'] as List).cast<Map<String, dynamic>>()) {
        for (final r in (g['rows'] as List).cast<Map<String, dynamic>>()) {
          if (r['state'] == 'IN PROGRESS' || r['state'] == 'ON HOLD')
            rows.add((m, g, r));
        }
      }
    }
    rows.sort(
      (a, b) => (a.$3['state'] == 'IN PROGRESS' ? 0 : 1).compareTo(
        b.$3['state'] == 'IN PROGRESS' ? 0 : 1,
      ),
    );
    for (final (m, g, r) in rows) {
      live.add(
        tile(
          who: '${m['employee']}',
          title: '${g['deliverable']} · Row ${r['display_no']}',
          sub:
              '${m['employee']} · ${g['role_label']} · started ${_when(r['start_time'])}',
          state: '${r['state']}',
          secs: r['current_secs'],
        ),
      );
    }
    for (final s in _sheets.where(
      (s) => s['status'] == 'IN PROGRESS' || s['status'] == 'ON HOLD',
    )) {
      live.add(
        tile(
          who: '${s['prepared_by'] ?? ''}',
          title: 'Content Calendar · ${s['deliverable']}',
          sub:
              '${s['prepared_by'] ?? ''} · preparing ${s['calendar_ids'] is List ? (s['calendar_ids'] as List).length : ''} rows',
          state: '${s['status']}',
          secs: s['duration_secs'],
        ),
      );
    }
    if (live.isEmpty) {
      return const Center(
        child: Text(
          'Nobody is working on this client right now.',
          style: TextStyle(color: _aMuted),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: live,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pending list — tasks that broke a Task Deadline Rule
// ─────────────────────────────────────────────────────────────────────────────
class _PendingList extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final bool showClient;
  final bool showAll; // also show ON TRACK items (client tab)
  final void Function(String client, String date)? onOpenClient;

  const _PendingList({
    required this.items,
    required this.showClient,
    this.showAll = false,
    this.onOpenClient,
  });

  @override
  State<_PendingList> createState() => _PendingListState();
}

class _PendingListState extends State<_PendingList> {
  String _type = 'ALL';
  String _search = '';

  static const _types = {
    'ALL': 'All',
    'NOT_STARTED': 'Not started',
    'NOT_COMPLETED': 'Not completed',
    'BEHIND_WEEKLY': 'Behind weekly target',
  };

  @override
  Widget build(BuildContext context) {
    final q = _search.trim().toLowerCase();
    final list = widget.items.where((i) {
      if (!widget.showAll && i['status'] != 'LATE') return false;
      if (widget.showAll && i['status'] == 'NO RULE') return false;
      final issues = (i['issues'] as List? ?? []).whereType<Map>();
      if (_type != 'ALL' && !issues.any((x) => x['type'] == _type))
        return false;
      if (q.isNotEmpty &&
          !'${i['client']} ${i['employee']} ${i['task']} ${i['role_label']}'
              .toLowerCase()
              .contains(q)) {
        return false;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 240,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: widget.showClient
                        ? 'Search client, employee, task'
                        : 'Search employee, task',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              for (final e in _types.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: _type == e.key,
                  onSelected: (_) => setState(() => _type = e.key),
                ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.verified_rounded,
                        size: 40,
                        color: Color(0xFF16A34A),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.showAll
                            ? 'No deadline rules apply here yet.'
                            : 'Nothing is late. 🎉',
                        style: const TextStyle(
                          color: _aMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: list.length,
                  itemBuilder: (context, i) => _tile(list[i]),
                ),
        ),
      ],
    );
  }

  Widget _tile(Map<String, dynamic> i) {
    final late = i['status'] == 'LATE';
    final done = i['status'] == 'DONE';
    final issues = (i['issues'] as List? ?? []).whereType<Map>().toList();
    final color = late
        ? _aLate
        : done
        ? const Color(0xFF15803D)
        : _aBlue;
    String d(dynamic v) {
      final t = DateTime.tryParse('${v ?? ''}');
      return t == null ? '—' : DateFormat('d MMM').format(t.toLocal());
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: late ? const Color(0xFFFECACA) : _aLine),
        boxShadow: late
            ? [
                BoxShadow(
                  color: _aLate.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(14),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${i['task']} · ${i['role_label']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13.5,
                              color: _aInk,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${i['status']}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        _meta(Icons.person_rounded, '${i['employee']}'),
                        if (widget.showClient)
                          _meta(Icons.business_rounded, '${i['client']}'),
                        _meta(
                          Icons.event_rounded,
                          'Assigned ${d(i['assigned_at'])}',
                        ),
                        if (i['start_due'] != null)
                          _meta(
                            Icons.play_arrow_rounded,
                            'Start by ${d(i['start_due'])}',
                          ),
                        if (i['complete_due'] != null)
                          _meta(
                            Icons.flag_rounded,
                            'Complete by ${d(i['complete_due'])}',
                          ),
                        if (i['per_week'] != null)
                          _meta(
                            Icons.date_range_rounded,
                            '${i['per_week']} / week',
                          ),
                        _meta(
                          Icons.task_alt_rounded,
                          '${i['done']}/${i['total']} done',
                        ),
                        _meta(
                          i['started'] == true
                              ? Icons.check_circle_outline
                              : Icons.radio_button_unchecked,
                          i['started'] == true ? 'Started' : 'Not started',
                        ),
                      ],
                    ),
                    for (final x in issues) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 15,
                            color: _aLate,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${x['message']}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: _aLate,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (widget.onOpenClient != null) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => widget.onOpenClient!(
                            '${i['client']}',
                            '${i['submission_date']}',
                          ),
                          icon: const Icon(Icons.open_in_new_rounded, size: 15),
                          label: const Text('Open client'),
                        ),
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

  Widget _meta(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: _aMuted),
      const SizedBox(width: 3),
      Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          color: _aMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

// Mobile-only pinned Admin filter toolbar.
class _AdminPinnedFiltersV6 extends SliverPersistentHeaderDelegate {
  final Widget child;

  _AdminPinnedFiltersV6({required this.child});

  @override
  double get minExtent => 176;

  @override
  double get maxExtent => 176;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: const Color(0xFFF4F7FC),
      elevation: overlapsContent ? 3 : 0,
      child: SizedBox(width: double.infinity, height: 176, child: child),
    );
  }

  @override
  bool shouldRebuild(covariant _AdminPinnedFiltersV6 oldDelegate) => true;
}
