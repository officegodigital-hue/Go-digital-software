import 'package:godigital_portal/services/socket_auth.dart';
import 'package:godigital_portal/services/auth_storage.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:godigital_portal/services/authenticated_http.dart' as http;
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../../services/api_config.dart';
import '../../services/auth_service.dart';
import 'package:godigital_portal/screens/employee_dashboard/task_actions.dart';

class LiveTrackingTasksPage extends StatefulWidget {
  final String searchQuery;

  /// Open a task's client card (and tab) in Employee Workspace.
  final ValueChanged<Map<String, dynamic>>? onOpenWorkspace;

  const LiveTrackingTasksPage({
    super.key,
    this.searchQuery = '',
    this.onOpenWorkspace,
  });

  @override
  State<LiveTrackingTasksPage> createState() =>
      _LiveTrackingTasksPageState();
}

class _LiveTrackingTasksPageState extends State<LiveTrackingTasksPage> {
  static String get _baseUrl => ApiConfig.baseUrl;

  // ─────────────────────────────────────────────────────────────
  // COLORS
  // ─────────────────────────────────────────────────────────────

  static const Color _primary = Color(0xFF0757D5);
  static const Color _primaryDark = Color(0xFF063B91);
  static const Color _primarySoft = Color(0xFFEAF2FF);

  static const Color _ink = Color(0xFF0F172A);
  static const Color _text = Color(0xFF334155);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  static const Color _success = Color(0xFF16A34A);
  static const Color _successSoft = Color(0xFFDCFCE7);

  static const Color _warning = Color(0xFFD97706);
  static const Color _warningSoft = Color(0xFFFEF3C7);

  static const Color _danger = Color(0xFFDC2626);
  static const Color _dangerSoft = Color(0xFFFEE2E2);

  // ─────────────────────────────────────────────────────────────
  // STATE
  // ─────────────────────────────────────────────────────────────

  String searchQuery = "";
  String activeFilter = "All";

  String loggedInEmployeeName = "";

  bool _loading = true;

  String? _error;

  List<Map<String, dynamic>> liveTasksData = [];

  late IO.Socket socket;

  DateTime selectedDate = DateTime.now();

  String formattedTotalWorkingTime = "00h 00m";

  Timer? _refreshTimer;
  Timer? _durationTicker;

  int _durationSeconds(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

  String _formatTaskDuration(int seconds) {
    final safeSeconds = seconds < 0 ? 0 : seconds;
    final hours = safeSeconds ~/ 3600;
    final minutes = (safeSeconds % 3600) ~/ 60;
    final remainingSeconds = safeSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String get _token => context.read<AuthService>().token ?? '';

  // Total = time actually worked on the selected date (all clients).
  void _updateTotalWorkingTime() {
    final totalSeconds = liveTasksData.fold<int>(
      0,
      (total, task) => total + _durationSeconds(task['secondsOnDate']),
    );
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    formattedTotalWorkingTime =
        '${hours.toString().padLeft(2, '0')}h '
        '${minutes.toString().padLeft(2, '0')}m';
  }

  // ─────────────────────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final authService = context.read<AuthService>();
      final user = authService.user;

      setState(() {
        loggedInEmployeeName =
            user?['fullName'] ??
            user?['name'] ??
            user?['username'] ??
            '';
      });

      _fetchLiveTasks();
      _initSocketListener();
      _durationTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        var hasRunningTask = false;
        for (final task in liveTasksData) {
          if (task['status'].toString().toUpperCase() != 'IN PROGRESS') {
            continue;
          }
          final seconds = _durationSeconds(task['durationSeconds']) + 1;
          task['durationSeconds'] = seconds;
          // Today's total grows only for sessions started today.
          final item = task['_item'];
          if (item is Map && item['today_running'] == true) {
            task['secondsOnDate'] = _durationSeconds(task['secondsOnDate']) + 1;
          }
          task['duration'] = _formatTaskDuration(seconds);
          hasRunningTask = true;
        }
        if (hasRunningTask) {
          setState(_updateTotalWorkingTime);
        }
      });

      _refreshTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) {
          if (mounted && loggedInEmployeeName.isNotEmpty) {
            _fetchLiveTasks(showLoader: false);
          }
        },
      );
    });
  }

  // ─────────────────────────────────────────────────────────────
  // SOCKET
  // ─────────────────────────────────────────────────────────────

  void _initSocketListener() {
    socket = IO.io(
      ApiConfig.socketUrl,
      IO.OptionBuilder().setAuthFn(authenticateSocket)
          .setTransports(['websocket'])
          .enableForceNew()
          .disableAutoConnect()
          .build(),
    );

    socket.connect();

    socket.off('task_updated');

    socket.on('task_updated', (data) {
      if (!mounted) return;

      _fetchLiveTasks(showLoader: false);
    });
  }

  // ─────────────────────────────────────────────────────────────
  // DATE PICKER
  // ─────────────────────────────────────────────────────────────

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: _ink,
            ),
            dialogTheme: const DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(
                  Radius.circular(24),
                ),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });

      _fetchLiveTasks();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // FETCH LIVE TASKS
  // ─────────────────────────────────────────────────────────────

  Future<void> _fetchLiveTasks({
    bool showLoader = true,
  }) async {
    if (!mounted) return;

    if (showLoader) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final formattedDate =
          "${selectedDate.year}-"
          "${selectedDate.month.toString().padLeft(2, '0')}-"
          "${selectedDate.day.toString().padLeft(2, '0')}";

      // Every client the employee worked on that day (tasks + Content
      // Calendar categories), with live durations and actions.
      final response = await http.get(
        Uri.parse('$_baseUrl/workspace-tasks/live-all').replace(
          queryParameters: {
            'employee': loggedInEmployeeName,
            'date': formattedDate,
          },
        ),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);

        final rows = List<dynamic>.from(
          body['data'] ?? [],
        );

        final parsedTasks =
            rows.whereType<Map>().map<Map<String, dynamic>>((raw) {
          final row = Map<String, dynamic>.from(raw);
          return {
            "trackingItemId": row['task_id'],
            "client": row['client'] ?? '',
            "task": row['title'] ?? '',
            "taskDescription": row['heading'] ?? '',
            "duration": '',
            "durationSeconds": _durationSeconds(row['duration_secs']),
            "secondsOnDate": _durationSeconds(row['seconds_on_date']),
            "status": row['status'] ?? 'IDLE',
            "action": row['review_action'] ?? 'ACTION',
            "comment": row['comment'] ?? row['hold_reason'] ?? '',
            "taskType": row['kind'] == 'CONTENT_CALENDAR' ? 'CONTENT CALENDAR' : 'TASK',
            "_item": row,
          };
        }).toList();

        for (final task in parsedTasks) {
          final seconds = _durationSeconds(task['durationSeconds']);
          task['duration'] = _formatTaskDuration(seconds);
        }

        setState(() {
          liveTasksData = parsedTasks;
          _updateTotalWorkingTime();
          _loading = false;
          _error = null;
        });
      } else {
        setState(() {
          _error =
              'Failed to load live tasks (${response.statusCode})';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Connection error. Please try again.';
        _loading = false;
      });

      debugPrint(
        'LiveTrackingTasksPage error: $e',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // DISPOSE
  // ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _durationTicker?.cancel();
    socket.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // FILTERED DATA
  // ─────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _filteredTasks {
    final search =
        widget.searchQuery.trim().toLowerCase();

    return liveTasksData.where((row) {
      final statusMatches =
          activeFilter == "All" ||
          row["status"]
                  .toString()
                  .toUpperCase() ==
              activeFilter.toUpperCase();

      if (!statusMatches) {
        return false;
      }

      if (search.isEmpty) {
        return true;
      }

      final client =
          row["client"]
                  ?.toString()
                  .toLowerCase() ??
              '';

      final task =
          row["task"]
                  ?.toString()
                  .toLowerCase() ??
              '';

      final duration =
          row["duration"]
                  ?.toString()
                  .toLowerCase() ??
              '';

      final description =
          row["taskDescription"]
                  ?.toString()
                  .toLowerCase() ??
              '';

      final status =
          row["status"]
                  ?.toString()
                  .toLowerCase() ??
              '';

      final action =
          row["action"]
                  ?.toString()
                  .toLowerCase() ??
              '';

      final comment =
          row["comment"]
                  ?.toString()
                  .toLowerCase() ??
              '';

      return client.contains(search) ||
          task.contains(search) ||
          duration.contains(search) ||
          description.contains(search) ||
          status.contains(search) ||
          action.contains(search) ||
          comment.contains(search);
    }).toList();
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final isMobile = width < 650;
        final isTablet =
            width >= 650 && width < 1050;

        final tasks = _filteredTasks;

        return Scaffold(
          backgroundColor: _surface,
          body: SafeArea(
            child: RefreshIndicator(
              color: _primary,
              onRefresh: () => _fetchLiveTasks(),
              child: SingleChildScrollView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(
                  isMobile ? 14 : 22,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    _buildHero(
                      isMobile,
                      isTablet,
                    ),

                    SizedBox(
                      height: isMobile ? 16 : 22,
                    ),

                    _buildOverviewCards(
                      tasks,
                      isMobile,
                    ),

                    SizedBox(
                      height: isMobile ? 16 : 22,
                    ),

                    _buildTaskWorkspace(
                      tasks,
                      isMobile,
                      isTablet,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HERO
  // ─────────────────────────────────────────────────────────────

Widget _buildHero(
  bool isMobile,
  bool isTablet,
) {
  // 📱 MOBILE HERO
  if (isMobile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _primaryDark,
            _primary,
            Color(0xFF2879EE),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: .22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LIVE + RADAR ICON
          _buildHeroTitle(
            light: true,
          ),

          const SizedBox(height: 18),

          // WORKING TIME + DATE
          Row(
            children: [
              Expanded(
                child: _buildWorkingTimeCard(
                  dark: true,
                  compact: true,
                ),
              ),

              const SizedBox(width: 10),

              _buildDateButton(
                dark: true,
                compact: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 💻 TABLET / DESKTOP HERO
  return Container(
    width: double.infinity,
    padding: EdgeInsets.all(
      isTablet ? 20 : 26,
    ),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          _primaryDark,
          _primary,
          Color(0xFF2879EE),
        ],
      ),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: _primary.withValues(alpha: .18),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          child: _buildHeroTitle(
            light: true,
          ),
        ),

        const SizedBox(width: 20),

        _buildWorkingTimeCard(
          dark: true,
        ),

        const SizedBox(width: 12),

        _buildDateButton(
          dark: true,
        ),
      ],
    ),
  );
}

  Widget _buildHeroTitle({
    bool light = false,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: light
                    ? Colors.white.withValues(alpha: .14)
                    : _primarySoft,
                borderRadius:
                    BorderRadius.circular(14),
                border: Border.all(
                  color: light
                      ? Colors.white.withValues(alpha: .18)
                      : _border,
                ),
              ),
              child: Icon(
                Icons.radar_rounded,
                color: light
                    ? Colors.white
                    : _primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: light
                    ? Colors.white.withValues(alpha: .12)
                    : _primarySoft,
                borderRadius:
                    BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration:
                        const BoxDecoration(
                      color: Color(0xFF4ADE80),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      color: light
                          ? Colors.white
                          : _primary,
                      fontSize: 9,
                      fontWeight:
                          FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 15),

        Text(
          'Live Tracking Tasks',
          style: TextStyle(
            fontSize: 27,
            height: 1.1,
            fontWeight: FontWeight.w900,
            color: light
                ? Colors.white
                : _ink,
            letterSpacing: -.7,
          ),
        ),

        const SizedBox(height: 7),

        Text(
          'Only work started today is shown and counted. An earlier held task comes back here when you restart it.',
          style: TextStyle(
            fontSize: 12.5,
            height: 1.45,
            color: light
                ? Colors.white.withValues(alpha: .78)
                : _muted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // WORKING TIME
  // ─────────────────────────────────────────────────────────────

  Widget _buildWorkingTimeCard({
    bool dark = false,
    bool compact = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 11 : 15,
        vertical: compact ? 9 : 12,
      ),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: .12)
            : Colors.white,
        borderRadius: BorderRadius.circular(
          compact ? 15 : 17,
        ),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: .18)
              : _border,
        ),
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: Colors.black
                      .withValues(alpha: .035),
                  blurRadius: 12,
                  offset:
                      const Offset(0, 5),
                ),
              ],
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Container(
            width: compact ? 32 : 38,
            height: compact ? 32 : 38,
            decoration: BoxDecoration(
              color: dark
                  ? Colors.white.withValues(alpha: .13)
                  : _primarySoft,
              borderRadius:
                  BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.timer_rounded,
              size: compact ? 17 : 19,
              color: dark
                  ? Colors.white
                  : _primary,
            ),
          ),

          const SizedBox(width: 9),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'LIVE WORKING TIME',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight:
                      FontWeight.w900,
                  letterSpacing: .75,
                  color: dark
                      ? Colors.white
                          .withValues(alpha: .68)
                      : _muted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                formattedTotalWorkingTime,
                style: TextStyle(
                  fontSize: compact ? 13 : 16,
                  fontWeight:
                      FontWeight.w900,
                  color: dark
                      ? Colors.white
                      : _primaryDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // DATE BUTTON
  // ─────────────────────────────────────────────────────────────

  Widget _buildDateButton({
    bool dark = false,
    bool compact = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectDate(context),
        borderRadius:
            BorderRadius.circular(15),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 14,
            vertical: compact ? 9 : 12,
          ),
          decoration: BoxDecoration(
            color: dark
                ? Colors.white
                    .withValues(alpha: .12)
                : Colors.white,
            borderRadius:
                BorderRadius.circular(15),
            border: Border.all(
              color: dark
                  ? Colors.white
                      .withValues(alpha: .18)
                  : _border,
            ),
          ),
          child: Row(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: compact ? 17 : 18,
                color: dark
                    ? Colors.white
                    : _primary,
              ),
              const SizedBox(width: 7),
              Text(
                '${selectedDate.day.toString().padLeft(2, '0')}/'
                '${selectedDate.month.toString().padLeft(2, '0')}/'
                '${selectedDate.year}',
                style: TextStyle(
                  fontSize: compact ? 11 : 12,
                  fontWeight:
                      FontWeight.w800,
                  color: dark
                      ? Colors.white
                      : _text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // OVERVIEW CARDS
  // ─────────────────────────────────────────────────────────────

  Widget _buildOverviewCards(
    List<Map<String, dynamic>> tasks,
    bool isMobile,
  ) {
    final total = liveTasksData.length;

    final progress = liveTasksData
        .where(
          (e) =>
              e['status']
                  .toString()
                  .toUpperCase() ==
              'IN PROGRESS',
        )
        .length;

    final hold = liveTasksData
        .where(
          (e) =>
              e['status']
                  .toString()
                  .toUpperCase() ==
              'ON HOLD',
        )
        .length;

    final completed = liveTasksData
        .where(
          (e) =>
              e['status']
                  .toString()
                  .toUpperCase() ==
              'COMPLETED',
        )
        .length;

    final cards = [
      _MetricData(
        icon: Icons.layers_rounded,
        label: 'TOTAL TASKS',
        value: '$total',
        color: _primary,
      ),
      _MetricData(
        icon: Icons.play_circle_outline_rounded,
        label: 'IN PROGRESS',
        value: '$progress',
        color: const Color(0xFF0284C7),
      ),
      _MetricData(
        icon: Icons.pause_circle_outline_rounded,
        label: 'ON HOLD',
        value: '$hold',
        color: _warning,
      ),
      _MetricData(
        icon: Icons.check_circle_outline_rounded,
        label: 'COMPLETED',
        value: '$completed',
        color: _success,
      ),
    ];

    if (isMobile) {
      return SizedBox(
        height: 92,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: cards.length,
          separatorBuilder:
              (_, _) =>
                  const SizedBox(width: 9),
          itemBuilder:
              (context, index) =>
                  SizedBox(
            width: 148,
            child: _buildMetricCard(
              cards[index],
            ),
          ),
        ),
      );
    }

    return Row(
      children: cards.map((card) {
        return Expanded(
          child: Padding(
            padding:
                const EdgeInsets.only(
              right: 10,
            ),
            child: _buildMetricCard(card),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMetricCard(
    _MetricData data,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(17),
        border: Border.all(
          color: _border,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: .035),
            blurRadius: 14,
            offset:
                const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color:
                  data.color.withValues(alpha: .09),
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: Icon(
              data.icon,
              size: 19,
              color: data.color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Text(
                  data.label,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 8.5,
                    fontWeight:
                        FontWeight.w900,
                    color: _muted,
                    letterSpacing: .65,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  data.value,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight:
                        FontWeight.w900,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // WORKSPACE
  // ─────────────────────────────────────────────────────────────

  Widget _buildTaskWorkspace(
    List<Map<String, dynamic>> tasks,
    bool isMobile,
    bool isTablet,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color: _border,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: .035),
            blurRadius: 20,
            offset:
                const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildWorkspaceHeader(
            tasks.length,
            isMobile,
          ),

          const Divider(
            height: 1,
            color: _border,
          ),

          _buildContent(
            tasks,
            isMobile,
            isTablet,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // WORKSPACE HEADER
  // ─────────────────────────────────────────────────────────────

  Widget _buildWorkspaceHeader(
    int visibleCount,
    bool isMobile,
  ) {
    if (isMobile) {
      return Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient:
                        const LinearGradient(
                      colors: [
                        _primary,
                        Color(0xFF2879EE),
                      ],
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                  child: const Icon(
                    Icons.track_changes_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Task Logs',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.w900,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$visibleCount visible task${visibleCount == 1 ? '' : 's'}',
                        style:
                            const TextStyle(
                          fontSize: 10,
                          color: _muted,
                          fontWeight:
                              FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildRefreshButton(),
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        17,
        20,
        17,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient:
                  const LinearGradient(
                colors: [
                  _primary,
                  Color(0xFF2879EE),
                ],
              ),
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.track_changes_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'Task Logs',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w900,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$visibleCount visible task${visibleCount == 1 ? '' : 's'} • Live monitoring',
                style: const TextStyle(
                  fontSize: 10,
                  color: _muted,
                  fontWeight:
                      FontWeight.w500,
                ),
              ),
            ],
          ),
          const Spacer(),
          _buildRefreshButton(),
        ],
      ),
    );
  }

  Widget _buildRefreshButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () =>
            _fetchLiveTasks(),
        borderRadius:
            BorderRadius.circular(11),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius:
                BorderRadius.circular(11),
            border: Border.all(
              color: _border,
            ),
          ),
          child: const Icon(
            Icons.refresh_rounded,
            size: 18,
            color: _primary,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CONTENT
  // ─────────────────────────────────────────────────────────────

  Widget _buildContent(
    List<Map<String, dynamic>> tasks,
    bool isMobile,
    bool isTablet,
  ) {
    if (_loading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (liveTasksData.isNotEmpty) _buildFilterChips(),
        if (tasks.isEmpty) _buildEmptyState() else _buildTaskCards(tasks, isMobile),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // STATUS FILTER CHIPS
  // ─────────────────────────────────────────────────────────────

  static const _filters = ['All', 'IN PROGRESS', 'ON HOLD', 'REWORK', 'COMPLETED'];

  Widget _buildFilterChips() {
    int count(String f) => f == 'All'
        ? liveTasksData.length
        : liveTasksData.where((e) => '${e['status']}'.toUpperCase() == f).length;
    String label(String f) => f == 'All'
        ? 'All'
        : f.split(' ').map((w) => w[0] + w.substring(1).toLowerCase()).join(' ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final f in _filters)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: () => setState(() => activeFilter = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                    decoration: BoxDecoration(
                      color: activeFilter == f ? _primary : Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: activeFilter == f ? _primary : _border),
                    ),
                    child: Text(
                      '${label(f)}  ${count(f)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: activeFilter == f ? Colors.white : _text,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TASK CARDS (invoice-style: header strip + detail tiles)
  // ─────────────────────────────────────────────────────────────

  Widget _buildTaskCards(List<Map<String, dynamic>> tasks, bool isMobile) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      itemCount: tasks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildTaskCard(tasks[index], index),
    );
  }

  String _dmy(dynamic v) {
    final s = '${v ?? ''}';
    final p = s.length >= 10 ? s.substring(0, 10).split('-') : <String>[];
    return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : '—';
  }

  Widget _buildTaskCard(Map<String, dynamic> row, int index) {
    final item = row['_item'] is Map
        ? Map<String, dynamic>.from(row['_item'] as Map)
        : <String, dynamic>{};
    final status = '${row['status']}';
    final isCalendar = item['kind'] == 'CONTENT_CALENDAR';
    final running = status.toUpperCase() == 'IN PROGRESS';
    final review = '${row['action']}';
    final comment = '${row['comment'] ?? ''}'.trim();
    final deliverable = '${item['deliverable'] ?? ''}';
    final todaySecs = _durationSeconds(row['secondsOnDate']);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: running ? _primary.withValues(alpha: .35) : _border,
          width: running ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .035),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final narrow = w < 760;

          // ── Header strip ──
          final pills = <Widget>[
            _labelPill('S.NO', (index + 1).toString().padLeft(2, '0')),
            _labelPill(isCalendar ? 'CALENDAR' : 'TASK', '${row['task']}', maxValueWidth: narrow ? w - 120 : 300),
            _buildStatusBadge(status),
          ];
          final dateBlock = _dateBlock('Submit Date', _dmy(item['submit_date'] ?? item['due_date']));
          final buttons = Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _rowActions(row),
              _openButton(item),
            ],
          );

          final header = narrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: pills),
                    _staleNote(row),
                    const SizedBox(height: 10),
                    dateBlock,
                    const SizedBox(height: 10),
                    buttons,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: pills),
                          _staleNote(row),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    dateBlock,
                    const SizedBox(width: 16),
                    buttons,
                  ],
                );

          // ── Detail tiles ──
          final tiles = <Widget>[
            _tile(Icons.person_rounded, 'Client Name', '${row['client']}', tone: _primary),
            _tile(Icons.layers_rounded, 'Deliverable', deliverable.isEmpty ? '${row['task']}' : deliverable, tone: _primary),
            _tile(Icons.notes_rounded, 'Description', '${row['taskDescription']}', tone: _primary, lines: 2),
            _tile(Icons.timer_rounded, 'Total Time', '${row['duration']}',
                tone: const Color(0xFF0284C7), soft: const Color(0xFFE0F2FE), big: true),
            _tile(Icons.bolt_rounded, 'Today', _formatTaskDuration(todaySecs),
                tone: _success, soft: _successSoft, big: true),
            _tile(Icons.rate_review_rounded, 'Review', review.isEmpty ? '—' : review,
                tone: _reviewColor(review), soft: _reviewColor(review).withValues(alpha: .10)),
            _tile(Icons.chat_bubble_rounded, 'Comment', comment.isEmpty ? '—' : comment,
                tone: _warning, soft: const Color(0xFFFFF7ED), lines: 2),
          ];
          final cols = w >= 1150 ? 7 : w >= 860 ? 4 : w >= 520 ? 3 : 2;
          const gap = 8.0;
          final tileW = (w - gap * (cols - 1)) / cols;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              const SizedBox(height: 12),
              Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (var i = 0; i < tiles.length; i++)
                    SizedBox(
                      // On phones the description spans the full row.
                      width: cols == 2 && i == 2 ? w : tileW,
                      child: tiles[i],
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Color _reviewColor(String review) {
    final r = review.toUpperCase();
    if (r.contains('APPROVED')) return _success;
    if (r.contains('REJECT') || r.contains('REWORK')) return _danger;
    return _primary;
  }

  Widget _labelPill(String label, String value, {double maxValueWidth = 300}) {
    return Container(
      decoration: BoxDecoration(
        color: _primarySoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            child: Text(
              label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: _primary, letterSpacing: .4),
            ),
          ),
          Container(
            constraints: BoxConstraints(maxWidth: maxValueWidth < 80 ? 80 : maxValueWidth),
            margin: const EdgeInsets.all(3),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value.isEmpty ? '—' : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _primaryDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateBlock(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.calendar_month_rounded, size: 20, color: _primary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: _muted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 12.5, color: _ink, fontWeight: FontWeight.w800)),
          ],
        ),
      ],
    );
  }

  Widget _tile(
    IconData icon,
    String label,
    String value, {
    required Color tone,
    Color? soft,
    bool big = false,
    int lines = 1,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: soft ?? _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: soft == null ? _border : tone.withValues(alpha: .18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: tone),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: soft == null ? _muted : tone),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? '—' : value,
                  maxLines: lines,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: big ? 15 : 12.5,
                    height: 1.3,
                    fontWeight: big ? FontWeight.w900 : FontWeight.w700,
                    color: soft == null ? _ink : tone,
                    fontFeatures: big ? const [FontFeature.tabularFigures()] : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Opens this task's client card on the right tab in Employee Workspace.
  Widget _openButton(Map<String, dynamic> item) {
    final canOpen = widget.onOpenWorkspace != null && '${item['client'] ?? ''}'.isNotEmpty;
    return Tooltip(
      message: 'Open in Employee Workspace',
      child: FilledButton.icon(
        onPressed: canOpen ? () => widget.onOpenWorkspace!(item) : null,
        style: FilledButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
        icon: const Icon(Icons.open_in_new_rounded, size: 15),
        label: const Text('Open', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
      ),
    );
  }


  // A task still running from an earlier day: it adds nothing to today's
  // time until it is put on hold and restarted.
  Widget _staleNote(Map<String, dynamic> row) {
    final item = row['_item'];
    if (item is! Map || item['stale_running'] != true) return const SizedBox.shrink();
    final since = '${item['running_since'] ?? ''}';
    final parts = since.split('-');
    final shown = parts.length == 3 ? '${parts[2]}/${parts[1]}' : since;
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Text(
        'Running since $shown — hold & restart to count today',
        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: _danger),
      ),
    );
  }

  // Start / Hold / Complete / Restart for this row.
  Widget _rowActions(Map<String, dynamic> row) {
    final item = row['_item'];
    if (item is! Map<String, dynamic>) return const Text('—');
    return TaskActionButtons(
      item: item,
      token: _token,
      dense: true,
      onDone: () => _fetchLiveTasks(showLoader: false),
    );
  }


  // ─────────────────────────────────────────────────────────────
  // STATUS PILL
  // ─────────────────────────────────────────────────────────────

  Widget _buildStatusBadge(String status) {
    final s = status.isEmpty ? 'IDLE' : status.toUpperCase();
    final (Color bg, Color fg) = switch (s) {
      'IN PROGRESS' => (const Color(0xFFE0F2FE), const Color(0xFF0369A1)),
      'ON HOLD' => (_warningSoft, const Color(0xFFB45309)),
      'REWORK' || 'REJECTED' => (_dangerSoft, _danger),
      'COMPLETED' || 'APPROVED' || 'IN REVIEW' || 'ASSIGNED' => (_successSoft, const Color(0xFF15803D)),
      _ => (const Color(0xFFF1F5F9), _muted),
    };
    final label = s.split(' ').map((w) => w.isEmpty ? w : w[0] + w.substring(1).toLowerCase()).join(' ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: fg.withValues(alpha: .15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: fg)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LOADING
  // ─────────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 65,
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            padding:
                const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _primarySoft,
              borderRadius:
                  BorderRadius.circular(17),
            ),
            child:
                const CircularProgressIndicator(
              strokeWidth: 3,
              color: _primary,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Loading live task logs...',
            style: TextStyle(
              fontSize: 12,
              fontWeight:
                  FontWeight.w700,
              color: _text,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Synchronizing your latest task activity',
            style: TextStyle(
              fontSize: 10,
              color: _muted,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ERROR
  // ─────────────────────────────────────────────────────────────

  Widget _buildErrorState() {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 55,
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: _dangerSoft,
              borderRadius:
                  BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              color: _danger,
              size: 27,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Unable to load live tasks',
            style: TextStyle(
              fontSize: 14,
              fontWeight:
                  FontWeight.w900,
              color: _ink,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _error ??
                'Something went wrong.',
            textAlign:
                TextAlign.center,
            style: const TextStyle(
              fontSize: 10.5,
              color: _muted,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () =>
                _fetchLiveTasks(),
            icon: const Icon(
              Icons.refresh_rounded,
              size: 16,
            ),
            label: const Text(
              'Retry',
            ),
            style:
                ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor:
                  Colors.white,
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 11,
              ),
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // EMPTY
  // ─────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    final hasFilter =
        activeFilter != 'All';

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 60,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _primarySoft,
              borderRadius:
                  BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.inbox_rounded,
              color: _primary,
              size: 30,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            hasFilter
                ? 'No matching tasks'
                : 'Nothing started today',
            style: const TextStyle(
              fontSize: 14,
              fontWeight:
                  FontWeight.w900,
              color: _ink,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            hasFilter
                ? 'Try changing the active status filter above.'
                : 'Start a task from Employee Workspace or the Day Planner. Held tasks from earlier days show here once you restart them.',
            textAlign:
                TextAlign.center,
            style: const TextStyle(
              fontSize: 10.5,
              color: _muted,
            ),
          ),
          if (hasFilter) ...[
            const SizedBox(height: 14),
            TextButton(
              onPressed: () {
                setState(() {
                  activeFilter = 'All';
                });
              },
              child: const Text(
                'Clear Filter',
                style: TextStyle(
                  color: _primary,
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// METRIC MODEL
// ─────────────────────────────────────────────────────────────

class _MetricData {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricData({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
}
