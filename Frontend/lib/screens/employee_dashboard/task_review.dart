import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/api_config.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO; // Add import

class ManagerReviewScreen extends StatefulWidget {
  const ManagerReviewScreen({super.key});

  @override
  State<ManagerReviewScreen> createState() => _ManagerReviewScreenState();
}

class _ManagerReviewScreenState extends State<ManagerReviewScreen> {
  // static const String _baseUrl = '/api';
  static String get _baseUrl => ApiConfig.baseUrl;

  // Current active filter category tab tracker
  String activeFilter = "All";

  String loggedInEmployeeName = "";

  // ── FILTER VISIBILITY TOGGLE TRACKER FLAG ──
  bool _isFilterMenuOpen = false;

  // FIX: no longer hardcoded — populated from the backend in
  // _fetchReviewData(). Only COMPLETED tracking items come back, i.e. work
  // an employee has actually submitted, which is what "SUBMITTED" meant here.
  List<Map<String, dynamic>> reviewData = [];

  bool _loading = true;
  String? _error;
  Timer? _commentTimer;
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
      loggedInEmployeeName =
          user?['fullName'] ??
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
      Uri.parse('$_baseUrl/manager-review'),
    );

    if (!mounted) return;

    if (r.statusCode == 200) {
      final body = jsonDecode(r.body);
      final rows = List<dynamic>.from(body['data'] ?? []);

      // Dispose old controllers
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

  // Fires immediately when the dropdown changes.
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

        _showSnack(
          body['message'] ?? 'Failed to save action'
        );

      }

    } else {

      _showSnack(
        'Failed to save action (${response.statusCode})'
      );

    }


  } catch(e) {

    _showSnack(
      'Error saving action: $e'
    );

  }
}

  // Debounced like the comment fields elsewhere in the app — fires 2s after
  // typing stops, and only if the text hasn't changed again since.
Future<void> _saveComment(
    Map<String, dynamic> row,
    String comment,
) async {

  print("COMMENT SENDER NAME => $loggedInEmployeeName");

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

        _showSnack(
          body['message'] ?? 'Failed to save comment'
        );

      }


    } else {

      _showSnack(
        'Failed to save comment (${r.statusCode})'
      );

    }


  } catch (e) {

    _showSnack(
      'Error saving comment: $e'
    );

  }
}

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

 @override
void dispose() {

  _commentTimer?.cancel();
  socket.dispose();

  for (final row in reviewData) {
    (row["controller"] as TextEditingController).dispose();
  }

  super.dispose();
}

  @override
  Widget build(BuildContext context) {
    // ── REACTIVE DATA FILTERING ENGINE ──
    List<Map<String, dynamic>> filteredReviews = reviewData.where((row) {
      if (!_isFilterMenuOpen || activeFilter == "All") return true;
      return row["action"].toString().toUpperCase() == activeFilter.toUpperCase();
    }).toList();

    return Scaffold(
  backgroundColor: const Color(0xFFF8FAFC),
  // appBar: AppBar(
  //   title: const Text("Task Review"),
  //   centerTitle: false,
  //   elevation: 0,
  //   backgroundColor: Colors.white,
  //   foregroundColor: Colors.black,
  // ),
  body: SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title Header & Description ──
          const Text(
            "Task  Review",
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          const Text(
  "Review completed tasks and provide approval, rework, or rejection with comments.",
  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),

          const SizedBox(height: 28),

          // ── Work Review Layout Container Data Grid ──
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Data Grid Control Ribbon Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Task review",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                      ),
                      Row(
                        children: [
                          // ── DYNAMIC HORIZONTAL FILTER MENU TABS ──
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

                          // ── FILTER VISIBILITY TOGGLE BUTTON ──
                          InkWell(
                            onTap: () {
                              setState(() {
                                _isFilterMenuOpen = !_isFilterMenuOpen;
                                if (!_isFilterMenuOpen) {
                                  activeFilter = "All"; // Resets filter layout cleanly when hidden
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: _isFilterMenuOpen ? const Color(0xFFF1F5F9) : Colors.transparent,
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _isFilterMenuOpen ? Icons.filter_list_off_rounded : Icons.filter_list_rounded,
                                    size: 14,
                                    color: const Color(0xFF475569)
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _isFilterMenuOpen ? "Hide Filters" : "Filters",
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))
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

                // 2. Table Column Heading Titles Row
                Container(
                  color: Colors.white,
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
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
                const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

                // 3. Scrollable List of Work Review Submissions
                SizedBox(
                  height: 480,
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_error!, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                                  const SizedBox(height: 10),
                                  TextButton(onPressed: _fetchReviewData, child: const Text('Retry')),
                                ],
                              ),
                            )
                          : filteredReviews.isEmpty
                              ? const Center(
                                  child: Text(
                                    "No review logs found matching this active filter status.",
                                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                  ),
                                )
                              : ListView.separated(
                          itemCount: filteredReviews.length,
                          physics: const BouncingScrollPhysics(),
                          separatorBuilder: (context, index) => const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, index) {
                            final row = filteredReviews[index];
                            return Container(
                              height: 64,
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              color: Colors.white,
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      row["client"],
                                      style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 26,
                                          height: 26,
                                          decoration: const BoxDecoration(color: Color(0xFFDCE4F7), shape: BoxShape.circle),
                                          alignment: Alignment.center,
                                          child: Text(
                                            row["initials"],
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF4A69B3)),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          row["name"],
                                          style: const TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(row["task"], style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(row["duration"], style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(4)),
                                        child: const Text(
                                          "SUBMITTED",
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF16A34A), letterSpacing: 0.2),
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
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
                                      child: TextField(
                                        controller: row["controller"] as TextEditingController,
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                                        decoration: InputDecoration(
                                          hintText: "Write manager review feedback...",
                                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                          fillColor: const Color(0xFFF8FAFC),
                                          filled: true,
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.grey.shade200)),
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFF0052CC))),
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

                // 4. Data Ledger Pagination Footer Area Component
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Showing 1 to ${filteredReviews.length} of ${filteredReviews.length} review records", style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      Row(
                        children: [
                          _buildPageButton("<", false),
                          _buildPageButton("1", true),
                          _buildPageButton("2", false),
                          _buildPageButton("3", false),
                          _buildPageButton(">", false),
                        ],
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
    ),
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
        borderRadius: BorderRadius.circular(4),
        border: currentAction == "ACTION" ? Border.all(color: const Color(0xFFCBD5E1)) : null,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: actionOptions.contains(row["action"]) ? row["action"] : actionOptions.first,
          icon: Icon(Icons.arrow_drop_down, color: textColor, size: 16),
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
            // FIX: this is the persistence that was missing — a dropdown
            // change now writes manager_action (and the default comment text,
            // if one was just auto-filled) straight to the backend.
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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

  Widget _buildPageButton(String text, bool isActive) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      width: 26, height: 26,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF0052CC) : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: isActive ? null : Border.all(color: const Color(0xFFE2E8F0)),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isActive ? Colors.white : const Color(0xFF475569)),
      ),
    );
  }

  static const TextStyle _headerStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569), letterSpacing: 0.8);
}

// ── CUSTOM LIGHTWEIGHT ANIMATED VISIBILITY HELPER WIDGET ──
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