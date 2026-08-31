// name=manager_review_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../layouts/admin_layout.dart';
import '../../services/api_config.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class ManagerReviewScreen extends StatefulWidget {
  const ManagerReviewScreen({super.key});

  @override
  State<ManagerReviewScreen> createState() => _ManagerReviewScreenState();
}

class _ManagerReviewScreenState extends State<ManagerReviewScreen> {
  static String get _baseUrl => ApiConfig.baseUrl;

  String activeFilter = "All";
  String loggedInEmployeeName = "";
  bool _isFilterMenuOpen = false;

  List<Map<String, dynamic>> reviewData = [];

  bool _loading = true;
  String? _error;
  late IO.Socket socket;

  String _searchQuery = '';
  final List<String> actionOptions = ["ACTION", "APPROVED", "REWORK", "REJECTED"];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = context.read<AuthService>();
      final user = authService.user;
      setState(() {
        loggedInEmployeeName = user?['fullName'] ??
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

    socket.on('task_updated', (data) {
      _fetchReviewData();
    });
  }

  @override
  void dispose() {
    socket.dispose();
    for (var row in reviewData) {
      (row["controller"] as TextEditingController).dispose();
    }
    super.dispose();
  }

  Future<void> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      loggedInEmployeeName = prefs.getString("employeeName") ?? " ";
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
        Uri.parse('$_baseUrl/manager-review'),
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
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '--';
    if (parts.length == 1) return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Future<void> _saveAction(Map<String, dynamic> row, String action) async {
    final trackingItemId = row['trackingItemId'];
    if (trackingItemId == null) return;

    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/manager-review/$trackingItemId'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'action': action,
          'senderEmployeeName': loggedInEmployeeName,
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);

        if (body['success'] == true) {
          setState(() {
            row['action'] = action;
          });

          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$action updated successfully',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          _showSnack(body['message'] ?? 'Failed to save action');
        }
      } else {
        _showSnack('Failed to save action (${response.statusCode})');
      }
    } catch (e) {
      _showSnack('Error saving action: $e');
    }
  }

  Future<void> _saveComment(
    Map<String, dynamic> row,
    String comment,
  ) async {
    final trackingItemId = row['trackingItemId'];
    if (trackingItemId == null) return;

    try {
      final r = await http.patch(
        Uri.parse('$_baseUrl/manager-review/$trackingItemId'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'comment': comment,
          'senderEmployeeName': loggedInEmployeeName,
        }),
      );

      if (r.statusCode == 200) {
        final body = jsonDecode(r.body);

        if (body['success'] == true) {
          setState(() {
            row['comment'] = comment;
          });

          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.white,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Comment updated successfully',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          _showSnack(body['message'] ?? 'Failed to save comment');
        }
      } else {
        _showSnack('Failed to save comment (${r.statusCode})');
      }
    } catch (e) {
      _showSnack('Error saving comment: $e');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> filteredReviews = reviewData.where((row) {
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.trim().toLowerCase();
        final clientName = (row["client"] ?? '').toString().toLowerCase();
        final employeeName = (row["name"] ?? '').toString().toLowerCase();

        if (!clientName.contains(query) && !employeeName.contains(query)) {
          return false;
        }
      }

      if (!_isFilterMenuOpen || activeFilter == "All") return true;
      return row["action"].toString().toUpperCase() == activeFilter.toUpperCase();
    }).toList();

    int approvedCount = reviewData.where((row) => row["action"].toString().toUpperCase() == "APPROVED").length;
    int reworkCount = reviewData.where((row) => row["action"].toString().toUpperCase() == "REWORK").length;
    int actionNeededCount = reviewData.where((row) => row["action"].toString().toUpperCase() == "ACTION").length;

    return AdminLayout(
      pageTitle: "Manager Review",
      currentRoute: "/manager-review",
      onSearch: (query) {
        setState(() {
          _searchQuery = query;
        });
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          bool isMobile = constraints.maxWidth < 750;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── HERO BANNER HEADER (Matching Employee Status Style) ──
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isMobile ? 20 : 28),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF003B95),
                      Color(0xFF0052CC),
                      Color(0xFF1267E8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(isMobile ? 22 : 28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0052CC).withValues(alpha: 0.25),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: 18,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: isMobile ? 52 : 62,
                          height: isMobile ? 52 : 62,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
                          ),
                          child: Icon(
                            Icons.rate_review_outlined,
                            size: isMobile ? 27 : 32,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Manager Review',
                                style: TextStyle(
                                  fontSize: isMobile ? 20 : 28,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Review submitted works, provide feedback, and update statuses.',
                                style: TextStyle(
                                  fontSize: isMobile ? 12 : 13,
                                  height: 1.5,
                                  color: Colors.white.withValues(alpha: 0.82),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                      ),
                      child: Text(
                        '${filteredReviews.length} REVIEWS FOUND',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── QUICK STATS CARDS ──
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 3,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isMobile ? 1 : 3,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: isMobile ? 3.8 : 2.6,
                ),
                itemBuilder: (context, index) {
                  final statsData = [
                    {'label': 'Total Submissions', 'value': reviewData.length.toString(), 'icon': Icons.description_outlined, 'color': const Color(0xFF0052CC)},
                    {'label': 'Approved', 'value': approvedCount.toString(), 'icon': Icons.verified_rounded, 'color': const Color(0xFF16A34A)},
                    {'label': 'Action Needed', 'value': actionNeededCount.toString(), 'icon': Icons.warning_amber_rounded, 'color': const Color(0xFFF59E0B)},
                  ];
                  final item = statsData[index];
                  final color = item['color'] as Color;

                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(item['icon'] as IconData, color: color, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['value'] as String,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF172033)),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item['label'] as String,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // ── WORK REVIEW CONTAINER ──
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.025),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Control Ribbon Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: isMobile
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Work Review Submissions",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF172033)),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    _buildFilterTab("All"),
                                    _buildFilterTab("Action"),
                                    _buildFilterTab("Approved"),
                                    _buildFilterTab("Rework"),
                                    _buildFilterTab("Rejected"),
                                  ],
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Work Review Submissions",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF172033)),
                                ),
                                Row(
                                  children: [
                                    AnimatedVisibility(
                                      visible: _isFilterMenuOpen,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _buildFilterTab("All"),
                                          _buildFilterTab("Action"),
                                          _buildFilterTab("Approved"),
                                          _buildFilterTab("Rework"),
                                          _buildFilterTab("Rejected"),
                                          const SizedBox(width: 8),
                                        ],
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          _isFilterMenuOpen = !_isFilterMenuOpen;
                                          if (!_isFilterMenuOpen) {
                                            activeFilter = "All";
                                          }
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: _isFilterMenuOpen ? const Color(0xFFF1F5F9) : Colors.transparent,
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              _isFilterMenuOpen ? Icons.filter_list_off_rounded : Icons.filter_list_rounded,
                                              size: 15,
                                              color: const Color(0xFF64748B),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              _isFilterMenuOpen ? "Hide Filters" : "Filters",
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                    ),
                    const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

                    // Table Header Titles Row (Desktop only)
                    if (!isMobile)
                      Container(
                        color: const Color(0xFFF7F9FC),
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: const [
                            Expanded(flex: 2, child: Text("CLIENT", style: _headerStyle)),
                            Expanded(flex: 3, child: Text("EMPLOYEE NAME", style: _headerStyle)),
                            Expanded(flex: 2, child: Text("TASKS", style: _headerStyle)),
                            Expanded(flex: 2, child: Text("TIME/DURATION", style: _headerStyle)),
                            Expanded(flex: 2, child: Text("STATUS", style: _headerStyle)),
                            Expanded(flex: 2, child: Text("ACTION", style: _headerStyle)),
                            Expanded(flex: 4, child: Text("COMMENT", style: _headerStyle)),
                          ],
                        ),
                      ),
                    if (!isMobile) const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

                    // Scrollable List / Cards
                    SizedBox(
                      height: 480,
                      child: _loading
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0052CC)))
                          : _error != null
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(_error!, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                                      const SizedBox(height: 10),
                                      OutlinedButton(onPressed: _fetchReviewData, child: const Text('Retry')),
                                    ],
                                  ),
                                )
                              : filteredReviews.isEmpty
                                  ? const Center(
                                      child: Text(
                                        "No review logs found matching this active filter status.",
                                        style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                    )
                                  : isMobile
                                      ? ListView.builder(
                                          itemCount: filteredReviews.length,
                                          padding: const EdgeInsets.all(14),
                                          itemBuilder: (context, index) {
                                            final row = filteredReviews[index];
                                            return Container(
                                              margin: const EdgeInsets.only(bottom: 12),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: 0.02),
                                                    blurRadius: 10,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.all(16),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Text(
                                                          row["client"],
                                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                                                        ),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFFDCFCE7),
                                                            borderRadius: BorderRadius.circular(10),
                                                            border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.2)),
                                                          ),
                                                          child: const Text(
                                                            "SUBMITTED",
                                                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF16A34A), letterSpacing: 0.5),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Row(
                                                      children: [
                                                        Container(
                                                          width: 26,
                                                          height: 26,
                                                          decoration: const BoxDecoration(color: Color(0xFFEAF2FF), shape: BoxShape.circle),
                                                          alignment: Alignment.center,
                                                          child: Text(
                                                            row["initials"],
                                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF0052CC)),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Text(
                                                          row["name"],
                                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Row(
                                                      children: [
                                                        const Icon(Icons.work_outline_rounded, size: 14, color: Color(0xFF0052CC)),
                                                        const SizedBox(width: 6),
                                                        Text("Task: ${row["task"]}", style: const TextStyle(fontSize: 12, color: Color(0xFF0052CC), fontWeight: FontWeight.w700)),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF64748B)),
                                                        const SizedBox(width: 6),
                                                        Text("Duration: ${row["duration"]}", style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 12),
                                                    _buildInteractiveActionDropdown(row, index),
                                                    const SizedBox(height: 12),
                                                    TextField(
                                                      controller: row["controller"] as TextEditingController,
                                                      style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                                                      decoration: InputDecoration(
                                                        hintText: "Write manager review feedback...",
                                                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                        fillColor: const Color(0xFFF8FAFC),
                                                        filled: true,
                                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0052CC))),
                                                      ),
                                                      onChanged: (v) {
                                                        Future.delayed(const Duration(seconds: 2), () {
                                                          final controller = row["controller"] as TextEditingController;
                                                          if (controller.text == v) _saveComment(row, v);
                                                        });
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        )
                                      : ListView.separated(
                                          itemCount: filteredReviews.length,
                                          physics: const BouncingScrollPhysics(),
                                          separatorBuilder: (context, index) => const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
                                          itemBuilder: (context, index) {
                                            final row = filteredReviews[index];
                                            return Container(
                                              height: 64,
                                              padding: const EdgeInsets.symmetric(horizontal: 20),
                                              color: index.isEven ? Colors.white : const Color(0xFFFBFCFE),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      row["client"],
                                                      style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w800),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 3,
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Container(
                                                          width: 28,
                                                          height: 28,
                                                          decoration: const BoxDecoration(color: Color(0xFFEAF2FF), shape: BoxShape.circle),
                                                          alignment: Alignment.center,
                                                          child: Text(
                                                            row["initials"],
                                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF0052CC)),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 9),
                                                        Expanded(
                                                          child: Text(
                                                            row["name"],
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: const TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w700, fontSize: 11.5),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(row["task"], style: const TextStyle(fontSize: 11, color: Color(0xFF0052CC), fontWeight: FontWeight.w700)),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(row["duration"], style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Align(
                                                      alignment: Alignment.centerLeft,
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFDCFCE7),
                                                          borderRadius: BorderRadius.circular(10),
                                                          border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.16)),
                                                        ),
                                                        child: const Text(
                                                          "SUBMITTED",
                                                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF16A34A), letterSpacing: 0.5),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Align(
                                                      alignment: Alignment.centerLeft,
                                                      child: _buildInteractiveActionDropdown(row, index),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 4,
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                                                      child: TextField(
                                                        controller: row["controller"] as TextEditingController,
                                                        style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                                                        decoration: InputDecoration(
                                                          hintText: "Write manager review feedback...",
                                                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                                          fillColor: const Color(0xFFF8FAFC),
                                                          filled: true,
                                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0052CC))),
                                                        ),
                                                        onChanged: (v) {
                                                          Future.delayed(const Duration(seconds: 2), () {
                                                            final controller = row["controller"] as TextEditingController;
                                                            if (controller.text == v) _saveComment(row, v);
                                                          });
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInteractiveActionDropdown(Map<String, dynamic> row, int index) {
    String currentAction = row["action"].toString().toUpperCase();

    Color containerColor = const Color(0xFFF1F5F9);
    Color textColor = const Color(0xFF475569);

    if (currentAction == "APPROVED") {
      containerColor = const Color(0xFFDCFCE7);
      textColor = const Color(0xFF16A34A);
    } else if (currentAction == "REWORK") {
      containerColor = const Color(0xFFFEF3C7);
      textColor = const Color(0xFFD97706);
    } else if (currentAction == "REJECTED") {
      containerColor = const Color(0xFFFEE2E2);
      textColor = const Color(0xFFDC2626);
    }

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(10),
        border: currentAction == "ACTION" ? Border.all(color: const Color(0xFFCBD5E1)) : null,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: actionOptions.contains(row["action"]) ? row["action"] : actionOptions.first,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: textColor, size: 16),
          dropdownColor: Colors.white,
          alignment: Alignment.center,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: textColor, letterSpacing: 0.3),
          items: actionOptions.map((String choice) {
            return DropdownMenuItem<String>(
              value: choice,
              child: Text(choice),
            );
          }).toList(),
          onChanged: (newValue) {
            setState(() {
              row["action"] = newValue!;

              final TextEditingController targetController = row["controller"] as TextEditingController;
              if (targetController.text.isEmpty) {
                if (newValue == "APPROVED") {
                  targetController.text = "Approved asset distributions.";
                } else if (newValue == "REWORK") {
                  targetController.text = "Needs adjustments.";
                } else if (newValue == "REJECTED") {
                  targetController.text = "Declined due to specification errors.";
                }
              }
            });
            _saveAction(row, newValue!);
            if ((row["controller"] as TextEditingController).text.isNotEmpty) {
              _saveComment(row, (row["controller"] as TextEditingController).text);
            }
          },
        ),
      ),
    );
  }

  Widget _buildFilterTab(String label) {
    bool isActive = activeFilter.toUpperCase() == label.toUpperCase();
    return Container(
      margin: const EdgeInsets.only(right: 4),
      child: OutlinedButton(
        onPressed: () {
          setState(() {
            activeFilter = label;
          });
        },
        style: OutlinedButton.styleFrom(
          backgroundColor: isActive ? const Color(0xFF0052CC) : Colors.transparent,
          side: BorderSide(color: isActive ? const Color(0xFF0052CC) : const Color(0xFFE2E8F0)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          elevation: 0,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
            color: isActive ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  static const TextStyle _headerStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w900,
    color: Color(0xFF64748B),
    letterSpacing: 0.7,
  );
}

class AnimatedVisibility extends StatelessWidget {
  final bool visible;
  final Widget child;

  const AnimatedVisibility({super.key, required this.visible, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: visible ? child : const SizedBox.shrink(),
    );
  }
}