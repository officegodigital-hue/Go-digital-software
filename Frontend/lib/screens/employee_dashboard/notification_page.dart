import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const String _baseUrl = '/api';

  // Selected employee filter (i.e. which conversation thread to show)
  String? _selectedEmployee;

  // Logged-in employee (from auth service)
  String? _loggedInEmployee;

  // FIX: no longer hardcoded — populated from the backend in
  // _fetchNotifications(), scoped to whoever is actually logged in. The
  // backend guarantees only threads where this person is sender OR
  // recipient ever come back, so there's no way to see someone else's
  // messages by accident.
  List<Map<String, dynamic>> notificationLogs = [];

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = context.read<AuthService>();
      final loggedInName = authService.user?['fullName'] as String? ?? 'Unknown';
      setState(() {
        _loggedInEmployee = loggedInName;
      });
      _fetchNotifications();
    });
  }

  Future<void> _fetchNotifications() async {
    if (_loggedInEmployee == null || _loggedInEmployee!.isEmpty) return;
    setState(() { _loading = true; _error = null; });

    try {
      final r = await http.get(
        Uri.parse('$_baseUrl/notifications/${Uri.encodeComponent(_loggedInEmployee!)}'),
      );
      if (r.statusCode == 200) {
        final body = jsonDecode(r.body);
        final rows = List<dynamic>.from(body['data'] ?? []);
        setState(() {
          notificationLogs = rows.map((row) {
            final otherParty = row['otherParty'] as String? ?? 'Unknown';
            return {
              "id": row['id'],
              "initials": _initialsFor(otherParty),
              "name": otherParty,
              "message": row['message'] ?? '',
              "time": row['time'] ?? '',
              "type": row['type'] ?? 'RECEIVED',
              "isSeen": row['isSeen'] as bool? ?? false,
              "isFavorite": row['isFavorite'] as bool? ?? false,
              "isArchived": row['isArchived'] as bool? ?? false,
            };
          }).toList();
          _loading = false;
        });
      } else {
        setState(() { _error = 'Failed to load notifications (${r.statusCode})'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Connection error: $e'; _loading = false; });
    }
  }

  String _initialsFor(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '--';
    if (parts.length == 1) return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Future<void> _toggleFavorite(Map<String, dynamic> log) async {
    final newValue = !(log["isFavorite"] as bool);
    setState(() => log["isFavorite"] = newValue);
    try {
      await http.patch(
        Uri.parse('$_baseUrl/notifications/${log["id"]}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'isFavorite': newValue}),
      );
    } catch (_) {
      // Non-fatal — local UI already updated; a refresh will resync if it failed.
    }
  }

  Future<void> _deleteNotification(Map<String, dynamic> log) async {
    setState(() => notificationLogs.remove(log));
    try {
      await http.delete(Uri.parse('$_baseUrl/notifications/${log["id"]}'));
    } catch (_) {}
  }

  // Get unique "other party" list — i.e. everyone THIS logged-in person has
  // an actual conversation thread with. Never anyone else's data.
  List<String> get _uniqueEmployees {
    final names = notificationLogs.map((log) => log["name"] as String).toSet().toList();
    names.sort();
    return names;
  }

  // Filter notifications based on selected thread
  List<Map<String, dynamic>> get _filteredNotifications {
    return notificationLogs.where((log) {
      if (_selectedEmployee == null) return true;
      return log["name"] == _selectedEmployee;
    }).toList();
  }

  // FIX: this file lives under employee_dashboard/, so it must never render
  // AdminLayout — that was causing "undefined_method: AdminLayout" since the
  // import for it isn't (and shouldn't be) present here. It now just returns
  // its own content in a plain scroll view, same as your other employee-side
  // screens (e.g. NotificationContent), which rely on whatever shell already
  // wraps them for the sidebar/header.
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(38, 30, 38, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title Header Banner ──
          const Text(
            "Notification",
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          const Text(
            "Never miss an update — get real-time notifications on all your activities.",
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 28),

          // ── Main Content Container ──
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Title Bar ──
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Text(
                    "List of Notification",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // ── Main Content Row: Sidebar + Notifications ──
                SizedBox(
                  height: 520,
                  child: Row(
                    children: [
                      // ── LEFT SIDEBAR: threads for THIS logged-in person only ──
                      Container(
                        width: 200,
                        decoration: const BoxDecoration(
                          border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                        child: ListView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          children: [
                            _buildEmployeeItem("All", null),
                            const Divider(height: 1),
                            ..._uniqueEmployees.map((employee) {
                              return _buildEmployeeItem(employee, employee);
                            }).toList(),
                          ],
                        ),
                      ),

                      // ── RIGHT SECTION: Notifications List ──
                      Expanded(
                        child: Column(
                          children: [
                            // ── Table Header ──
                            Container(
                              height: 44,
                              color: const Color(0xFFF8FAFC),
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: const Row(
                                children: [
                                  SizedBox(width: 100, child: Text("TYPE", style: _headerStyle)),
                                  Expanded(child: Text("MESSAGE", style: _headerStyle)),
                                  SizedBox(width: 120, child: Text("TIME", textAlign: TextAlign.center, style: _headerStyle)),
                                  SizedBox(width: 60, child: Text("STATUS", textAlign: TextAlign.center, style: _headerStyle)),
                                  SizedBox(width: 60, child: Text("ACTION", textAlign: TextAlign.center, style: _headerStyle)),
                                ],
                              ),
                            ),
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),

                            // ── Notifications List ──
                            Expanded(
                              child: _loading
                                  ? const Center(child: CircularProgressIndicator())
                                  : _error != null
                                      ? Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(_error!, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                                              const SizedBox(height: 10),
                                              TextButton(onPressed: _fetchNotifications, child: const Text('Retry')),
                                            ],
                                          ),
                                        )
                                      : _filteredNotifications.isEmpty
                                          ? const Center(
                                              child: Text(
                                                "No notifications found.",
                                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                              ),
                                            )
                                          : ListView.separated(
                                      itemCount: _filteredNotifications.length,
                                      physics: const BouncingScrollPhysics(),
                                      separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                                      itemBuilder: (context, index) {
                                        final log = _filteredNotifications[index];
                                        final isSent = log["type"] == "SENT";
                                        final isSeen = log["isSeen"] as bool;

                                        return Container(
                                          height: 60,
                                          color: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 24),
                                          child: Row(
                                            children: [
                                              // ── TYPE BADGE (SENT/RECEIVED) ──
                                              SizedBox(
                                                width: 100,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: isSent ? const Color(0xFFEFF6FF) : const Color(0xFFFFF7ED),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    isSent ? "Sent" : "Received",
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w700,
                                                      color: isSent ? const Color(0xFF0052CC) : const Color(0xFFEA580C),
                                                    ),
                                                  ),
                                                ),
                                              ),

                                              // ── MESSAGE ──
                                              Expanded(
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          log["message"],
                                                          overflow: TextOverflow.ellipsis,
                                                          maxLines: 2,
                                                          style: const TextStyle(
                                                            fontSize: 13,
                                                            color: Color(0xFF334155),
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                      IconButton(
                                                        onPressed: () => _toggleFavorite(log),
                                                        icon: Icon(
                                                          log["isFavorite"] ? Icons.star_rounded : Icons.star_border_rounded,
                                                          color: log["isFavorite"] ? const Color(0xFF0052CC) : const Color(0xFFCBD5E1),
                                                          size: 18,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),

                                              // ── TIME ──
                                              SizedBox(
                                                width: 120,
                                                child: Text(
                                                  log["time"],
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF64748B),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),

                                              // ── STATUS (SEEN INDICATOR) ──
                                              SizedBox(
                                                width: 60,
                                                child: Center(
                                                  child: isSent
                                                      ? isSeen
                                                          ? Tooltip(
                                                              message: "Seen",
                                                              child: Column(
                                                                mainAxisAlignment: MainAxisAlignment.center,
                                                                children: [
                                                                  const SizedBox(
                                                                    width: 16,
                                                                    height: 16,
                                                                    child: Stack(
                                                                      alignment: Alignment.center,
                                                                      children: [
                                                                        Positioned(
                                                                          left: -2,
                                                                          child: Icon(Icons.check, size: 12, color: Color(0xFF0052CC)),
                                                                        ),
                                                                        Positioned(
                                                                          right: -2,
                                                                          child: Icon(Icons.check, size: 12, color: Color(0xFF0052CC)),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            )
                                                          : Tooltip(
                                                              message: "Sent",
                                                              child: const Icon(Icons.check, size: 12, color: Color(0xFF94A3B8)),
                                                            )
                                                      : const SizedBox(),
                                                ),
                                              ),

                                              // ── DELETE ACTION ──
                                              SizedBox(
                                                width: 60,
                                                child: Center(
                                                  child: IconButton(
                                                    onPressed: () => _deleteNotification(log),
                                                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFF94A3B8)),
                                                    hoverColor: Colors.red.shade50,
                                                    splashRadius: 20,
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
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── Build Employee Sidebar Item ──
  Widget _buildEmployeeItem(String label, String? employeeName) {
    final isSelected = _selectedEmployee == employeeName;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedEmployee = employeeName;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? const Color(0xFF0052CC) : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  static const TextStyle _headerStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: Color(0xFF475569),
    letterSpacing: 0.8,
  );
}