import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/api_config.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class ManagerReviewScreen extends StatefulWidget {
  final String searchQuery;

  const ManagerReviewScreen({
    super.key,
    this.searchQuery = '',
  });

  @override
  State<ManagerReviewScreen> createState() => _ManagerReviewScreenState();
}

class _ManagerReviewScreenState extends State<ManagerReviewScreen> {
  static String get _baseUrl => ApiConfig.baseUrl;

  static const Color _primary = Color(0xFF0757D5);
  static const Color _primaryDark = Color(0xFF063B91);
  static const Color _primarySoft = Color(0xFFEAF2FF);
  static const Color _ink = Color(0xFF0F172A);
  static const Color _text = Color(0xFF334155);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  String activeFilter = "All";
  String activeActionFilter = "All";
  String loggedInEmployeeName = "";

  DateTime selectedDate = DateTime.now(); // 🟢 Default Today Date

  List<Map<String, dynamic>> reviewData = [];
  bool _loading = true;
  String? _error;
  late IO.Socket socket;

  final List<String> actionOptions = ["ACTION", "APPROVED", "REWORK", "REJECTED"];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final authService = context.read<AuthService>();
      final user = authService.user;

      if (!mounted) return;

      setState(() {
        loggedInEmployeeName = user?['fullName'] ??
            user?['name'] ??
            user?['username'] ??
            '';
      });

      _fetchReviewData();
    });
    _initSocketListener();
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
      print("🔥 $data");
      _fetchReviewData();
    });
  }

  // 🟢 Date Picker Function
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
      _fetchReviewData();
    }
  }

  Future<void> _fetchReviewData() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final formattedDate =
          "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

      final r = await http.get(
        Uri.parse('$_baseUrl/manager-review?date=$formattedDate'),
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
              "taskDescription": row['task_description'] ?? row['taskDescription'] ?? '', // 🟢 Fixed description binding
              "duration": row['duration'] ?? 'N/A',
              "status": row['status'] ?? 'COMPLETED',
              "action": (row['manager_action'] as String?)?.isNotEmpty == true
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
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '--';
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Future<void> _saveAction(Map<String, dynamic> row, String action) async {
    final trackingItemId = row['trackingItemId'];
    if (trackingItemId == null) return;

    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/manager-review/$trackingItemId'),
        headers: {'Content-Type': 'application/json'},
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
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 10),
                  Text('$action updated successfully',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
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

  Future<void> _saveComment(Map<String, dynamic> row, String comment) async {
    final trackingItemId = row['trackingItemId'];
    if (trackingItemId == null) return;

    try {
      final r = await http.patch(
        Uri.parse('$_baseUrl/manager-review/$trackingItemId'),
        headers: {'Content-Type': 'application/json'},
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
        }
      }
    } catch (e) {
      debugPrint('Error saving comment: $e');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  @override
  void dispose() {
    socket.dispose();
    for (final row in reviewData) {
      (row["controller"] as TextEditingController).dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String query = widget.searchQuery.trim().toLowerCase();

    List<Map<String, dynamic>> filteredReviews = reviewData.where((row) {
      final client = (row["client"] ?? "").toString().toLowerCase();
      final employee = (row["name"] ?? "").toString().toLowerCase();
      final task = (row["task"] ?? "").toString().toLowerCase();
      final duration = (row["duration"] ?? "").toString().toLowerCase();
      final taskDescription =
          (row["taskDescription"] ?? "").toString().toLowerCase();
      final status = (row["status"] ?? "").toString().toLowerCase();
      final action = (row["action"] ?? "").toString().toLowerCase();
      final controller = row["controller"] as TextEditingController?;
      final comment = controller?.text.toLowerCase() ?? "";

      final searchMatches = query.isEmpty ||
          client.contains(query) ||
          employee.contains(query) ||
          task.contains(query) ||
          taskDescription.contains(query) ||
          duration.contains(query) ||
          status.contains(query) ||
          action.contains(query) ||
          comment.contains(query);

      if (!searchMatches) return false;

      if (activeFilter != "All" && status != activeFilter.toLowerCase()) {
        return false;
      }

      if (activeActionFilter != "All" && action != activeActionFilter.toLowerCase()) {
        return false;
      }

      return true;
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < 750;

        return Scaffold(
          backgroundColor: _surface,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 14 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Blue Hero Section ──
                  _buildHeroSection(isMobile),
                  const SizedBox(height: 24),

                  // ── Main Content Container ──
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.035),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Ribbon Bar Header
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Task Review Submissions",
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B)),
                              ),
                              IconButton(
                                onPressed: _fetchReviewData,
                                icon: const Icon(Icons.refresh_rounded,
                                    color: _primary, size: 20),
                                tooltip: 'Refresh',
                              ),
                            ],
                          ),
                        ),
                        const Divider(
                            height: 1, thickness: 1, color: _border),

                        // Body Content
                        _loading
                            ? const Padding(
                                padding: EdgeInsets.all(50),
                                child: Center(
                                    child: CircularProgressIndicator(
                                        color: _primary)),
                              )
                            : _error != null
                                ? Padding(
                                    padding: const EdgeInsets.all(40),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(_error!,
                                              style: const TextStyle(
                                                  color: _muted, fontSize: 13)),
                                          const SizedBox(height: 10),
                                          TextButton(
                                              onPressed: _fetchReviewData,
                                              child: const Text('Retry')),
                                        ],
                                      ),
                                    ),
                                  )
                                : isMobile
                                    ? _buildMobileReviewList(filteredReviews)
                                    : _buildDesktopReviewTable(
                                        filteredReviews, width),

                        // Footer Summary
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                          decoration: const BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(18)),
                          ),
                          child: Text(
                            "Showing ${filteredReviews.length} review record${filteredReviews.length == 1 ? '' : 's'}",
                            style: const TextStyle(
                                fontSize: 11, color: _muted),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Blue Hero Section Widget ───────────────────────────────────────────────
  Widget _buildHeroSection(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 18 : 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryDark, _primary, Color(0xFF2879EE)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Task Review Command",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white),
                    ),
                    // Date Button
                    InkWell(
                      onTap: () => _selectDate(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded,
                                size: 14, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  "Review completed tasks and provide approvals with real-time tracking.",
                  style: TextStyle(fontSize: 11.5, color: Color(0xFFEAF3FF)),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: const Icon(Icons.fact_check_rounded,
                          color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Task Review Command Center",
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Review completed tasks and provide approvals with real-time tracking.",
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFFEAF3FF)),
                        ),
                      ],
                    ),
                  ],
                ),
                // Date Button
                InkWell(
                  onTap: () => _selectDate(context),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            size: 16, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ── Desktop Table View ─────────────────────────────────────────────────────
  Widget _buildDesktopReviewTable(
      List<Map<String, dynamic>> filteredReviews, double totalWidth) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: totalWidth < 1250 ? 1250 : totalWidth - 40,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Table Header Row
              Container(
                color: _primary,
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const _HeaderCell(title: 'CLIENT', flex: 2),
                    const _HeaderCell(title: 'EMPLOYEE NAME', flex: 3),
                    const _HeaderCell(title: 'TASKS', flex: 2),
                    const _HeaderCell(title: 'TASK DESCRIPTION', flex: 3),
                    const _HeaderCell(title: 'TIME/DURATION', flex: 2),
                    // STATUS Dropdown Header
                    Expanded(
                      flex: 2,
                      child: PopupMenuButton<String>(
                        initialValue: activeFilter,
                        onSelected: (val) => setState(() => activeFilter = val),
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'All', child: Text('All Statuses', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          const PopupMenuItem(value: 'COMPLETED', child: Text('COMPLETED', style: TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.bold))),
                          const PopupMenuItem(value: 'SUBMITTED', child: Text('SUBMITTED', style: TextStyle(fontSize: 12, color: Color(0xFF0052CC), fontWeight: FontWeight.bold))),
                        ],
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                activeFilter == 'All' ? 'STATUS ▾' : 'STATUS: $activeFilter ▾',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _headerStyle,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // ACTION Dropdown Header
                    Expanded(
                      flex: 2,
                      child: PopupMenuButton<String>(
                        initialValue: activeActionFilter,
                        onSelected: (val) => setState(() => activeActionFilter = val),
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'All', child: Text('All Actions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          const PopupMenuItem(value: 'APPROVED', child: Text('APPROVED', style: TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.bold))),
                          const PopupMenuItem(value: 'REWORK', child: Text('REWORK', style: TextStyle(fontSize: 12, color: Color(0xFFD97706), fontWeight: FontWeight.bold))),
                          const PopupMenuItem(value: 'REJECTED', child: Text('REJECTED', style: TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.bold))),
                          const PopupMenuItem(value: 'ACTION', child: Text('ACTION', style: TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.bold))),
                        ],
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                activeActionFilter == 'All' ? 'ACTION ▾' : 'ACTION: $activeActionFilter ▾',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _headerStyle,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const _HeaderCell(title: 'COMMENT', flex: 4),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1, color: _border),

              if (filteredReviews.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: Text(
                      "No review logs found matching this filter criteria.",
                      style: TextStyle(color: _muted, fontSize: 13),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredReviews.length,
                  separatorBuilder: (_, __) => const Divider(
                      height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, index) {
                    final row = filteredReviews[index];
                    return Container(
                      height: 68,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      color: index.isEven ? Colors.white : const Color(0xFFFBFCFE),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              row["client"],
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF334155),
                                  fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: const BoxDecoration(
                                      color: Color(0xFFDCE4F7),
                                      shape: BoxShape.circle),
                                  alignment: Alignment.center,
                                  child: Text(
                                    row["initials"],
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF4A69B3)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    row["name"],
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF334155),
                                        fontWeight: FontWeight.w500),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              row["task"],
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF475569)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              row["taskDescription"] ?? "-",
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF475569)),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              row["duration"],
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF475569)),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(4)),
                                child: const Text(
                                  "SUBMITTED",
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF16A34A)),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _buildInteractiveActionDropdown(row),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: TextField(
                                controller: row["controller"]
                                    as TextEditingController,
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF334155)),
                                decoration: InputDecoration(
                                  hintText: "Write feedback...",
                                  hintStyle: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 11),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 0),
                                  fillColor: const Color(0xFFF8FAFC),
                                  filled: true,
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(4),
                                      borderSide: BorderSide(
                                          color: Colors.grey.shade200)),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(4),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF0052CC))),
                                ),
                                onChanged: (v) {
                                  Future.delayed(const Duration(seconds: 2), () {
                                    final controller = row["controller"]
                                        as TextEditingController;
                                    if (controller.text == v) {
                                      _saveComment(row, v);
                                    }
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
            ],
          ),
        ),
      ),
    );
  }

  // ── Mobile Responsive Card List View ───────────────────────────────────────
  Widget _buildMobileReviewList(List<Map<String, dynamic>> filteredReviews) {
    if (filteredReviews.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: Text(
            "No review logs found matching this filter criteria.",
            style: TextStyle(color: _muted, fontSize: 13),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredReviews.length,
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, index) {
        final row = filteredReviews[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      row["client"] ?? '—',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _ink),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(4)),
                    child: const Text(
                      "SUBMITTED",
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF16A34A)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                        color: Color(0xFFDCE4F7), shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(
                      row["initials"],
                      style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4A69B3)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    row["name"] ?? 'Unassigned',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569)),
                  ),
                ],
              ),
              const Divider(height: 16, color: _border),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Task: ",
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _muted)),
                  Expanded(
                    child: Text(
                      row["task"] ?? '—',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _text),
                    ),
                  ),
                  const Text("Duration: ",
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _muted)),
                  Text(
                    row["duration"] ?? '—',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _text),
                  ),
                ],
              ),
              if ((row["taskDescription"] ?? "").toString().trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  row["taskDescription"],
                  style: const TextStyle(fontSize: 11, color: _text),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(flex: 2, child: _buildInteractiveActionDropdown(row)),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 36,
                      child: TextField(
                        controller: row["controller"] as TextEditingController,
                        style: const TextStyle(fontSize: 11, color: _text),
                        decoration: InputDecoration(
                          hintText: "Add feedback...",
                          hintStyle:
                              TextStyle(color: Colors.grey.shade400, fontSize: 10),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 0),
                          fillColor: const Color(0xFFF8FAFC),
                          filled: true,
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade200)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide:
                                  const BorderSide(color: Color(0xFF0052CC))),
                        ),
                        onChanged: (v) {
                          Future.delayed(const Duration(seconds: 2), () {
                            final controller =
                                row["controller"] as TextEditingController;
                            if (controller.text == v) _saveComment(row, v);
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInteractiveActionDropdown(Map<String, dynamic> row) {
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
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(4),
        border: currentAction == "ACTION"
            ? Border.all(color: const Color(0xFFCBD5E1))
            : null,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: actionOptions.contains(row["action"])
              ? row["action"]
              : actionOptions.first,
          icon: Icon(Icons.arrow_drop_down, color: textColor, size: 16),
          dropdownColor: Colors.white,
          alignment: Alignment.center,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: textColor,
              letterSpacing: 0.3),
          items: actionOptions.map((String choice) {
            return DropdownMenuItem<String>(
              value: choice,
              child: Text(choice),
            );
          }).toList(),
          onChanged: (newValue) {
            setState(() {
              row["action"] = newValue!;

              final TextEditingController targetController =
                  row["controller"] as TextEditingController;
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
              _saveComment(
                  row, (row["controller"] as TextEditingController).text);
            }
          },
        ),
      ),
    );
  }

  static const TextStyle _headerStyle = TextStyle(
      fontSize: 9.5,
      fontWeight: FontWeight.w900,
      color: Colors.white,
      letterSpacing: 0.8);
}

class _HeaderCell extends StatelessWidget {
  final String title;
  final int flex;

  const _HeaderCell({
    required this.title,
    required this.flex,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}