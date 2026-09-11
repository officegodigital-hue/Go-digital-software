import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/api_config.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class TaskStatusScreen extends StatefulWidget {
  final String searchQuery;

  const TaskStatusScreen({
    super.key,
    this.searchQuery = '',
  });

  @override
  State<TaskStatusScreen> createState() => _TaskStatusScreenState();
}

class _TaskStatusScreenState extends State<TaskStatusScreen> {
  static String get _baseUrl => ApiConfig.baseUrl;

  String activeFilter = "All";
  String activeActionFilter = "All";
  String loggedInEmployeeName = "";

  List<Map<String, dynamic>> reviewData = [];

  bool _loading = true;
  String? _error;
  late IO.Socket socket;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final authService = context.read<AuthService>();
      final user = authService.user;

      if (!mounted) return;

      setState(() {
        loggedInEmployeeName =
            user?['fullName'] ??
            user?['name'] ??
            user?['username'] ??
            '';
      });

      _fetchReviewData();
      _initSocketListener();
    });
  }

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
      print("🔥 $data");
      _fetchReviewData();
    });
  }

  Future<void> loadUser() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      loggedInEmployeeName =
          prefs.getString("employeeName") ?? " ";
    });

    _fetchReviewData();
  }

  Future<void> _fetchReviewData() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final r = await http.get(
        Uri.parse(
          '$_baseUrl/manager-review/task-status/$loggedInEmployeeName',
        ),
      );

      if (!mounted) return;

      if (r.statusCode == 200) {
        final body = jsonDecode(r.body);
        final rows = List<dynamic>.from(body['data'] ?? []);

        for (final row in reviewData) {
          (row["controller"] as TextEditingController).dispose();
        }

        if (!mounted) return;

        setState(() {
          reviewData = rows.map((row) {
            final employeeName =
                row['employee_name'] as String? ?? 'Unassigned';

            return {
              "trackingItemId": row['tracking_item_id'],
              "client": row['client_name'] ?? '',
              "initials": _initialsFor(employeeName),
              "name": employeeName,
              "task": row['task'] ?? '',
              "taskDescription": row['task_description'] ?? '',
              "duration": row['duration'] ?? 'N/A',
              "status": row['status'] ?? 'COMPLETED',
              "action":
                  (row['manager_action'] as String?)?.isNotEmpty == true
                      ? row['manager_action']
                      : 'ACTION',
              "controller": TextEditingController(
                text: row['manager_comment'] as String? ?? '',
              ),
            };
          }).toList();

          _loading = false;
        });
      } else {
        if (!mounted) return;

        setState(() {
          _error = 'Failed to load reviews (${r.statusCode})';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Connection error: $e';
        _loading = false;
      });
    }
  }

  String _initialsFor(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '--';

    if (parts.length == 1) {
      return parts[0]
          .substring(0, parts[0].length >= 2 ? 2 : 1)
          .toUpperCase();
    }

    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  void dispose() {
    for (final row in reviewData) {
      (row["controller"] as TextEditingController).dispose();
    }

    socket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String query = widget.searchQuery.trim().toLowerCase();

    List<Map<String, dynamic>> filteredReviews =
        reviewData.where((row) {
      final client =
          (row["client"] ?? "").toString().toLowerCase();

      final task =
          (row["task"] ?? "").toString().toLowerCase();

      final duration =
          (row["duration"] ?? "").toString().toLowerCase();

      final status =
          (row["status"] ?? "").toString().toLowerCase();

      final action =
          (row["action"] ?? "").toString().toLowerCase();

      final controller =
          row["controller"] as TextEditingController?;

      final comment =
          controller?.text.toLowerCase() ?? "";

      final searchMatches =
          query.isEmpty ||
          client.contains(query) ||
          task.contains(query) ||
          duration.contains(query) ||
          status.contains(query) ||
          action.contains(query) ||
          comment.contains(query);

      if (!searchMatches) {
        return false;
      }

      // Status filter
      if (activeFilter != "All") {
        if (status != activeFilter.toLowerCase()) {
          return false;
        }
      }

      // Action filter
      if (activeActionFilter != "All") {
        if (action != activeActionFilter.toLowerCase()) {
          return false;
        }
      }

      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FC),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isMobile = constraints.maxWidth < 700;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                isMobile ? 14 : 28,
                isMobile ? 14 : 24,
                isMobile ? 14 : 28,
                30,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroSection(isMobile),

                  SizedBox(height: isMobile ? 16 : 24),

                  _buildReviewContainer(
                    isMobile,
                    filteredReviews,
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // HERO SECTION
  // ============================================================

  Widget _buildHeroSection(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 18 : 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0B3B82),
            Color(0xFF0052CC),
            Color(0xFF2879EE),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0052CC).withOpacity(0.20),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _heroIcon(isMobile),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "Task Status",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  "Review completed tasks and provide approval, rework, or rejection with comments.",
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: Color(0xFFEAF3FF),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _heroStat(
                        icon: Icons.task_alt_rounded,
                        label: "Total",
                        value: reviewData.length.toString(),
                        dark: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _heroStat(
                        icon: Icons.check_circle_outline_rounded,
                        label: "Completed",
                        value: reviewData
                            .where(
                              (e) =>
                                  e["status"].toString().toUpperCase() ==
                                  "COMPLETED",
                            )
                            .length
                            .toString(),
                        dark: true,
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                _heroIcon(false),
                const SizedBox(width: 18),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Task Status",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "Review completed tasks and provide approval, rework, or rejection with comments.",
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFFEAF3FF),
                        ),
                      ),
                    ],
                  ),
                ),
                _heroStat(
                  icon: Icons.task_alt_rounded,
                  label: "Total Reviews",
                  value: reviewData.length.toString(),
                  dark: true,
                ),
                const SizedBox(width: 12),
                _heroStat(
                  icon: Icons.check_circle_outline_rounded,
                  label: "Completed",
                  value: reviewData
                      .where(
                        (e) =>
                            e["status"].toString().toUpperCase() ==
                            "COMPLETED",
                      )
                      .length
                      .toString(),
                  dark: true,
                ),
              ],
            ),
    );
  }

  Widget _heroIcon(bool isMobile) {
    return Container(
      width: isMobile ? 46 : 58,
      height: isMobile ? 46 : 58,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(isMobile ? 12 : 15),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Icon(
        Icons.fact_check_rounded,
        color: Colors.white,
        size: isMobile ? 24 : 30,
      ),
    );
  }

  Widget _heroStat({
    required IconData icon,
    required String label,
    required String value,
    bool dark = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withOpacity(0.14) : Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: dark
              ? Colors.white.withOpacity(0.18)
              : const Color(0xFFDCE8F7),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: dark
                  ? Colors.white.withOpacity(0.16)
                  : const Color(0xFFEAF3FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 16,
              color: dark ? Colors.white : const Color(0xFF0052CC),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: dark
                      ? const Color(0xFFDCEBFF)
                      : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: dark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MAIN REVIEW CONTAINER
  // ============================================================

  Widget _buildReviewContainer(
    bool isMobile,
    List<Map<String, dynamic>> filteredReviews,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildToolbar(isMobile),

          const Divider(
            height: 1,
            color: Color(0xFFE2E8F0),
          ),

          if (!isMobile)
            _buildDesktopHeader(),

          _buildContent(
            isMobile,
            filteredReviews,
          ),

          _buildFooter(
            isMobile,
            filteredReviews.length,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TOOLBAR
  // ============================================================

  Widget _buildToolbar(bool isMobile) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 14 : 22,
        isMobile ? 14 : 16,
        isMobile ? 14 : 22,
        isMobile ? 12 : 16,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3FF),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.fact_check_outlined,
              size: 19,
              color: Color(0xFF0052CC),
            ),
          ),

          const SizedBox(width: 10),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Task Status Records",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "Live synchronized review log",
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),

          if (!isMobile)
            Text(
              "${reviewData.length} Records",
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // DESKTOP TABLE HEADER (WITH LIVE-TRACKING STYLE DROPDOWN FILTERS)
  // ============================================================

  Widget _buildDesktopHeader() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(
        horizontal: 22,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0052CC),
      ),
      child: Row(
        children: [
          const Expanded(
            flex: 2,
            child: Text("CLIENT", style: _headerStyle),
          ),
          const Expanded(
            flex: 2,
            child: Text("TASK", style: _headerStyle),
          ),
          const Expanded(
            flex: 3,
            child: Text("TASK DESCRIPTION", style: _headerStyle),
          ),
          const Expanded(
            flex: 2,
            child: Text("TIME / DURATION", style: _headerStyle),
          ),
          // STATUS Column Header with interactive dropdown filter
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
                  value: 'COMPLETED',
                  child: Text('COMPLETED', style: TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                ),
                const PopupMenuItem(
                  value: 'SUBMITTED',
                  child: Text('SUBMITTED', style: TextStyle(fontSize: 12, color: Color(0xFF0052CC), fontWeight: FontWeight.bold)),
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
                        fontSize: 9.5,
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
          // ACTION Column Header with interactive dropdown filter
          Expanded(
            flex: 2,
            child: PopupMenuButton<String>(
              initialValue: activeActionFilter,
              onSelected: (val) {
                setState(() {
                  activeActionFilter = val;
                });
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'All',
                  child: Text('All Actions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const PopupMenuItem(
                  value: 'APPROVED',
                  child: Text('APPROVED', style: TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                ),
                const PopupMenuItem(
                  value: 'REWORK',
                  child: Text('REWORK', style: TextStyle(fontSize: 12, color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
                ),
                const PopupMenuItem(
                  value: 'REJECTED',
                  child: Text('REJECTED', style: TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                ),
                const PopupMenuItem(
                  value: 'ACTION',
                  child: Text('ACTION', style: TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.bold)),
                ),
              ],
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      activeActionFilter == 'All' ? 'ACTION ▾' : 'ACTION: $activeActionFilter ▾',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9.5,
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
          const Expanded(
            flex: 4,
            child: Text("COMMENT", style: _headerStyle),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CONTENT
  // ============================================================

  Widget _buildContent(
    bool isMobile,
    List<Map<String, dynamic>> filteredReviews,
  ) {
    if (_loading) {
      return SizedBox(
        height: isMobile ? 300 : 420,
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Color(0xFF0052CC),
          ),
        ),
      );
    }

    if (_error != null) {
      return SizedBox(
        height: isMobile ? 300 : 420,
        child: Center(
          child: _buildErrorState(),
        ),
      );
    }

    if (filteredReviews.isEmpty) {
      return SizedBox(
        height: isMobile ? 280 : 380,
        child: Center(
          child: _buildEmptyState(),
        ),
      );
    }

    if (isMobile) {
      return _buildMobileList(filteredReviews);
    }

    return _buildDesktopList(filteredReviews);
  }

  // ============================================================
  // DESKTOP LIST (MODERN COLUMN DIFFERENTIATION & CARD STYLE)
  // ============================================================

  Widget _buildDesktopList(
    List<Map<String, dynamic>> filteredReviews,
  ) {
    return SizedBox(
      height: 480,
      child: ListView.separated(
        itemCount: filteredReviews.length,
        physics: const BouncingScrollPhysics(),
        separatorBuilder: (context, index) {
          return const Divider(
            height: 1,
            thickness: 1,
            color: Color(0xFFE2E8F0),
          );
        },
        itemBuilder: (context, index) {
          final row = filteredReviews[index];
          final isEven = index.isEven;

          return Container(
            height: 72,
            padding: const EdgeInsets.symmetric(
              horizontal: 22,
            ),
            color: isEven ? Colors.white : const Color(0xFFF9FBFF),
            child: Row(
              children: [
                // CLIENT
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      _avatar(
                        row["initials"] ?? "--",
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          row["client"].toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // TASK
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      row["task"].toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                // DESCRIPTION
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      row["taskDescription"] ?? "-",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                // DURATION
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF3FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: Color(0xFF0052CC),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          row["duration"].toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0052CC),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // STATUS
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _buildStatusBadge(
                      row["status"] ?? "SUBMITTED",
                    ),
                  ),
                ),

                // ACTION
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _buildActionBadge(
                      row["action"] ?? "ACTION",
                    ),
                  ),
                ),

                // COMMENT
                Expanded(
                  flex: 4,
                  child: Container(
                    height: 38,
                    margin: const EdgeInsets.only(
                      left: 6,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                    ),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Text(
                      (row["controller"]
                                  as TextEditingController)
                              .text
                              .isEmpty
                          ? "-"
                          : (row["controller"]
                                  as TextEditingController)
                              .text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // MOBILE LIST
  // ============================================================

  Widget _buildMobileList(
    List<Map<String, dynamic>> filteredReviews,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: filteredReviews.length,
      separatorBuilder: (context, index) {
        return const SizedBox(height: 10);
      },
      itemBuilder: (context, index) {
        final row = filteredReviews[index];

        return _buildMobileTaskCard(row);
      },
    );
  }

  Widget _buildMobileTaskCard(
    Map<String, dynamic> row,
  ) {
    final controller =
        row["controller"] as TextEditingController;

    final comment = controller.text.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _avatar(
                row["initials"] ?? "--",
              ),
              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      row["client"].toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      row["task"].toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              _buildStatusBadge(
                row["status"] ?? "SUBMITTED",
              ),
            ],
          ),

          const SizedBox(height: 13),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFE8EEF5),
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  "TASK DESCRIPTION",
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  row["taskDescription"] ?? "-",
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 11),

          Row(
            children: [
              Expanded(
                child: _mobileInfoItem(
                  Icons.schedule_rounded,
                  "Duration",
                  row["duration"].toString(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _mobileInfoItem(
                  Icons.flash_on_rounded,
                  "Action",
                  row["action"].toString(),
                  actionWidget: _buildActionBadge(
                    row["action"] ?? "ACTION",
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 11),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF3FF),
                    borderRadius:
                        BorderRadius.circular(7),
                  ),
                  child: const Icon(
                    Icons.comment_outlined,
                    size: 15,
                    color: Color(0xFF0052CC),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "COMMENT",
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        comment.isEmpty ? "-" : comment,
                        style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileInfoItem(
    IconData icon,
    String label,
    String value, {
    Widget? actionWidget,
  }) {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFCFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3FF),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(
              icon,
              size: 14,
              color: const Color(0xFF0052CC),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: actionWidget ??
                Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // AVATAR
  // ============================================================

  Widget _avatar(String initials) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FF),
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFCFE1F7),
        ),
      ),
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Color(0xFF0052CC),
        ),
      ),
    );
  }

  // ============================================================
  // STATUS BADGE
  // ============================================================

  Widget _buildStatusBadge(String status) {
    final String value =
        status.toString().toUpperCase();

    Color bg = const Color(0xFFDCFCE7);
    Color text = const Color(0xFF16A34A);

    if (value == "SUBMITTED" ||
        value == "COMPLETED") {
      bg = const Color(0xFFDCFCE7);
      text = const Color(0xFF16A34A);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        value == "COMPLETED"
            ? "SUBMITTED"
            : value,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: text,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  // ============================================================
  // ACTION BADGE
  // ============================================================

  Widget _buildActionBadge(String action) {
    action = action.toUpperCase();

    Color bg = const Color(0xFFF1F5F9);
    Color txt = const Color(0xFF475569);

    switch (action) {
      case "APPROVED":
        bg = const Color(0xFFDCFCE7);
        txt = const Color(0xFF16A34A);
        break;

      case "REWORK":
        bg = const Color(0xFFFEF3C7);
        txt = const Color(0xFFD97706);
        break;

      case "REJECTED":
        bg = const Color(0xFFFEE2E2);
        txt = const Color(0xFFDC2626);
        break;

      default:
        bg = const Color(0xFFF1F5F9);
        txt = const Color(0xFF475569);
    }

    return Container(
      height: 30,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        action,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: txt,
          fontWeight: FontWeight.bold,
          fontSize: 9.5,
        ),
      ),
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.cloud_off_rounded,
            color: Color(0xFFDC2626),
            size: 25,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: _fetchReviewData,
          icon: const Icon(
            Icons.refresh_rounded,
            size: 16,
          ),
          label: const Text(
            "Retry",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF3FF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.inbox_outlined,
            color: Color(0xFF0052CC),
            size: 28,
          ),
        ),
        const SizedBox(height: 13),
        const Text(
          "No review records found",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          "No tasks match the current search or filter.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // FOOTER
  // ============================================================

  Widget _buildFooter(
    bool isMobile,
    int count,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 14 : 22,
        vertical: 13,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(14),
        ),
      ),
      child: Text(
        "Showing 1 to $count of $count review records",
        style: const TextStyle(
          fontSize: 10.5,
          color: Color(0xFF64748B),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  static const TextStyle _headerStyle = TextStyle(
    fontSize: 9.5,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    letterSpacing: 0.8,
  );
}