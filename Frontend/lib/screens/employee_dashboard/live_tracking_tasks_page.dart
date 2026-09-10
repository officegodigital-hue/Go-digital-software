import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../../services/api_config.dart';
import '../../services/auth_service.dart';

class LiveTrackingTasksPage extends StatefulWidget {
  final String searchQuery;

  const LiveTrackingTasksPage({
    super.key,
    this.searchQuery = '',
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
      IO.OptionBuilder()
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

      final encodedEmployee =
          Uri.encodeComponent(loggedInEmployeeName);

      final response = await http.get(
        Uri.parse(
          '$_baseUrl/dashboard/live-tracking-tasks/'
          '$encodedEmployee?date=$formattedDate',
        ),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);

        final rows = List<dynamic>.from(
          body['data'] ?? [],
        );

        final parsedTasks =
            rows.map<Map<String, dynamic>>((row) {
          return {
            "trackingItemId": row['trackingItemId'],
            "client": row['client_name'] ?? '',
            "task": row['task'] ?? '',
            "taskDescription":
                row['task_description'] ?? '',
            "duration": row['duration'] ?? 'N/A',
            "status": row['status'] ?? 'IDLE',
            "action": row['manager_action'] ?? 'ACTION',
            "comment": row['comment'] ?? '',
          };
        }).toList();

        int totalSumSeconds = 0;

        for (final task in parsedTasks) {
          final duration =
              task["duration"].toString().toLowerCase();

          int hrs = 0;
          int mins = 0;

          final hourMatch = RegExp(
            r'(\d+)\s*(?:hrs|hr)',
          ).firstMatch(duration);

          final minMatch = RegExp(
            r'(\d+)\s*(?:mins|min)',
          ).firstMatch(duration);

          if (hourMatch != null) {
            hrs = int.tryParse(
                  hourMatch.group(1) ?? '',
                ) ??
                0;
          }

          if (minMatch != null) {
            mins = int.tryParse(
                  minMatch.group(1) ?? '',
                ) ??
                0;
          }

          totalSumSeconds +=
              (hrs * 3600) + (mins * 60);
        }

        final totalHours =
            totalSumSeconds ~/ 3600;

        final totalMinutes =
            (totalSumSeconds % 3600) ~/ 60;

        setState(() {
          formattedTotalWorkingTime =
              '${totalHours.toString().padLeft(2, '0')}h '
              '${totalMinutes.toString().padLeft(2, '0')}m';

          liveTasksData = parsedTasks;
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
    if (isMobile) {
      return Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _buildHeroTitle(),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildWorkingTimeCard(
                  compact: true,
                ),
              ),
              const SizedBox(width: 10),
              _buildDateButton(compact: true),
            ],
          ),
        ],
      );
    }

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
          'Monitor your tasks, working time and live progress in real-time.',
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
              (_, __) =>
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

    if (isMobile) {
      return tasks.isEmpty ? _buildEmptyState() : _buildMobileTaskList(tasks);
    }

    return _buildDesktopTable(
      tasks,
      isTablet,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // DESKTOP TABLE
  // ─────────────────────────────────────────────────────────────

  Widget _buildDesktopTable(
    List<Map<String, dynamic>> tasks,
    bool isTablet,
  ) {
    return ClipRRect(
      borderRadius:
          const BorderRadius.vertical(
        bottom: Radius.circular(22),
      ),
      child: SingleChildScrollView(
        scrollDirection:
            Axis.horizontal,
        child: SizedBox(
          width: isTablet
              ? 1100
              : 1280,
          child: Column(
            children: [
              _buildTableHeader(),

              const Divider(
                height: 1,
                color: _border,
              ),

              if (tasks.isEmpty)
                _buildEmptyState()
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics:
                      const NeverScrollableScrollPhysics(),
                  itemCount: tasks.length,
                  separatorBuilder:
                      (_, __) =>
                          const Divider(
                    height: 1,
                    color: Color(0xFFF1F5F9),
                  ),
                  itemBuilder:
                      (context, index) {
                    return _buildDesktopRow(
                      tasks[index],
                      index,
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      height: 52,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 20,
      ),
      decoration: const BoxDecoration(
        color: _primary,
      ),
      child: Row(
        children: [
          const _HeaderCell(
            title: 'CLIENT',
            flex: 2,
          ),
          const _HeaderCell(
            title: 'TASK',
            flex: 2,
          ),
          const _HeaderCell(
            title: 'DURATION',
            flex: 1,
          ),
          const _HeaderCell(
            title: 'TASK DESCRIPTION',
            flex: 3,
          ),
          // 🟢 STATUS Column Header with interactive dropdown filter
          Expanded(
            flex: 2,
            child: PopupMenuButton<String>(
              initialValue: activeFilter,
              onSelected: (val) {
                setState(() {
                  activeFilter = val;
                });
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'All',
                  child: Text('All Statuses', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const PopupMenuItem(
                  value: 'IN PROGRESS',
                  child: Text('IN PROGRESS', style: TextStyle(fontSize: 12, color: Color(0xFF0284C7), fontWeight: FontWeight.bold)),
                ),
                const PopupMenuItem(
                  value: 'ON HOLD',
                  child: Text('ON HOLD', style: TextStyle(fontSize: 12, color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
                ),
                const PopupMenuItem(
                  value: 'COMPLETED',
                  child: Text('COMPLETED', style: TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                ),
              ],
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      activeFilter == 'All' ? 'STATUS ▾' : 'STATUS: $activeFilter ▾',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: .75,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const _HeaderCell(
            title: 'REVIEW ACTION',
            flex: 2,
          ),
          const _HeaderCell(
            title: 'COMMENT',
            flex: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopRow(
    Map<String, dynamic> row,
    int index,
  ) {
    final client =
        row["client"].toString();

    final task =
        row["task"].toString();

    final duration =
        row["duration"].toString();

    final description =
        row["taskDescription"].toString();

    final status =
        row["status"].toString();

    final action =
        row["action"].toString();

    final comment =
        row["comment"].toString();

    return Container(
      constraints:
          const BoxConstraints(
        minHeight: 68,
      ),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 10,
      ),
      color: index.isEven
          ? Colors.white
          : const Color(0xFFFBFDFF),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _tableText(
              client,
              bold: true,
            ),
          ),

          Expanded(
            flex: 2,
            child: _tableText(
              task,
            ),
          ),

          Expanded(
            flex: 1,
            child: _durationBadge(
              duration,
            ),
          ),

          Expanded(
            flex: 3,
            child: _tableText(
              description,
              muted: true,
            ),
          ),

          Expanded(
            flex: 2,
            child: Align(
              alignment:
                  Alignment.centerLeft,
              child:
                  _buildStatusBadge(
                status,
              ),
            ),
          ),

          Expanded(
            flex: 2,
            child: _actionBadge(
              action,
            ),
          ),

          Expanded(
            flex: 3,
            child: _tableText(
              comment.isEmpty
                  ? '-'
                  : comment,
              muted: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableText(
    String text, {
    bool bold = false,
    bool muted = false,
  }) {
    return Padding(
      padding:
          const EdgeInsets.only(
        right: 12,
      ),
      child: Text(
        text.isEmpty ? '-' : text,
        maxLines: 2,
        overflow:
            TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11.5,
          height: 1.35,
          fontWeight: bold
              ? FontWeight.w800
              : FontWeight.w500,
          color: muted
              ? _muted
              : _text,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // MOBILE TASK LIST
  // ─────────────────────────────────────────────────────────────

  Widget _buildMobileTaskList(
    List<Map<String, dynamic>> tasks,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(),
      padding:
          const EdgeInsets.all(12),
      itemCount: tasks.length,
      separatorBuilder:
          (_, __) =>
              const SizedBox(height: 10),
      itemBuilder:
          (context, index) {
        return _buildMobileTaskCard(
          tasks[index],
          index,
        );
      },
    );
  }

  Widget _buildMobileTaskCard(
    Map<String, dynamic> row,
    int index,
  ) {
    final client =
        row["client"].toString();

    final task =
        row["task"].toString();

    final duration =
        row["duration"].toString();

    final description =
        row["taskDescription"]
            .toString();

    final status =
        row["status"].toString();

    final action =
        row["action"].toString();

    final comment =
        row["comment"].toString();

    return Container(
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: _border,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: .025),
            blurRadius: 12,
            offset:
                const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
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
                      BorderRadius.circular(
                    12,
                  ),
                ),
                alignment:
                    Alignment.center,
                child: Text(
                  '${index + 1}',
                  style:
                      const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CLIENT',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight:
                            FontWeight.w900,
                        color: _muted,
                        letterSpacing:
                            .7,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      client.isEmpty
                          ? '-'
                          : client,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 14,
                        fontWeight:
                            FontWeight.w900,
                        color: _ink,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              _buildStatusBadge(
                status,
              ),
            ],
          ),

          const SizedBox(height: 14),

          _mobileInfoBlock(
            icon:
                Icons.task_alt_rounded,
            label: 'TASK',
            value: task,
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child:
                    _mobileSmallInfo(
                  icon:
                      Icons.timer_outlined,
                  label: 'DURATION',
                  child:
                      _durationBadge(
                    duration,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child:
                    _mobileSmallInfo(
                  icon:
                      Icons.rate_review_outlined,
                  label: 'ACTION',
                  child:
                      _actionBadge(
                    action,
                  ),
                ),
              ),
            ],
          ),

          if (description
              .trim()
              .isNotEmpty) ...[
            const SizedBox(height: 10),
            _mobileInfoBlock(
              icon:
                  Icons.description_outlined,
              label:
                  'TASK DESCRIPTION',
              value: description,
            ),
          ],

          const SizedBox(height: 10),

          _mobileInfoBlock(
            icon:
                Icons.chat_bubble_outline_rounded,
            label: 'COMMENT',
            value: comment.trim().isEmpty
                ? '-'
                : comment,
          ),
        ],
      ),
    );
  }

  Widget _mobileInfoBlock({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE5EEFC),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _primarySoft,
              borderRadius:
                  BorderRadius.circular(9),
            ),
            child: Icon(
              icon,
              size: 15,
              color: _primary,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style:
                      const TextStyle(
                    fontSize: 7.5,
                    fontWeight:
                        FontWeight.w900,
                    color: _muted,
                    letterSpacing:
                        .65,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value.isEmpty
                      ? '-'
                      : value,
                  maxLines: 3,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    fontWeight:
                        FontWeight.w600,
                    color: _text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileSmallInfo({
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE5EEFC),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 13,
                color: _primary,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style:
                    const TextStyle(
                  fontSize: 7.5,
                  fontWeight:
                      FontWeight.w900,
                  color: _muted,
                  letterSpacing: .55,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          child,
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // DURATION
  // ─────────────────────────────────────────────────────────────

  Widget _durationBadge(
    String duration,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: _primarySoft,
        borderRadius:
            BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFD6E5FF),
        ),
      ),
      child: Text(
        duration.isEmpty
            ? 'N/A'
            : duration,
        maxLines: 1,
        overflow:
            TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight:
              FontWeight.w900,
          color: _primary,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ACTION
  // ─────────────────────────────────────────────────────────────

  Widget _actionBadge(
    String action,
  ) {
    final normalized =
        action.toUpperCase();

    Color bg =
        const Color(0xFFF1F5F9);

    Color color = _muted;

    if (normalized.contains(
      'APPROVED',
    )) {
      bg = _successSoft;
      color = _success;
    } else if (normalized.contains(
      'REJECT',
    )) {
      bg = _dangerSoft;
      color = _danger;
    } else if (normalized.contains(
      'ACTION',
    )) {
      bg = _primarySoft;
      color = _primary;
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius:
            BorderRadius.circular(8),
      ),
      child: Text(
        action.isEmpty
            ? '-'
            : action,
        maxLines: 1,
        overflow:
            TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 8.5,
          fontWeight:
              FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // STATUS
  // ─────────────────────────────────────────────────────────────

  Widget _buildStatusBadge(
    String status,
  ) {
    final normalized =
        status.toUpperCase();

    Color bg =
        const Color(0xFFF1F5F9);

    Color txt = _muted;

    IconData icon =
        Icons.circle_outlined;

    if (normalized ==
        "IN PROGRESS") {
      bg = _primarySoft;
      txt = const Color(0xFF0284C7);
      icon =
          Icons.play_circle_fill_rounded;
    } else if (normalized ==
        "ON HOLD") {
      bg = _warningSoft;
      txt = _warning;
      icon =
          Icons.pause_circle_filled_rounded;
    } else if (normalized ==
        "COMPLETED") {
      bg = _successSoft;
      txt = _success;
      icon =
          Icons.check_circle_rounded;
    } else if (normalized ==
        "IDLE") {
      bg = const Color(0xFFF1F5F9);
      txt = _muted;
      icon =
          Icons.hourglass_empty_rounded;
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius:
            BorderRadius.circular(9),
        border: Border.all(
          color: txt.withValues(alpha: .12),
        ),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
            color: txt,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              status.isEmpty
                  ? 'IDLE'
                  : status,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 8,
                fontWeight:
                    FontWeight.w900,
                color: txt,
              ),
            ),
          ),
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
                : 'No live task logs',
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
                : 'There are no tracking logs for the selected date.',
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

// ─────────────────────────────────────────────────────────────
// TABLE HEADER
// ─────────────────────────────────────────────────────────────

class _HeaderCell extends StatelessWidget {
  final String title;
  final int flex;

  const _HeaderCell({
    required this.title,
    required this.flex,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding:
            const EdgeInsets.only(
          right: 12,
        ),
        child: Text(
          title,
          maxLines: 1,
          overflow:
              TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 9,
            fontWeight:
                FontWeight.w900,
            color: Colors.white,
            letterSpacing: .75,
          ),
        ),
      ),
    );
  }
}