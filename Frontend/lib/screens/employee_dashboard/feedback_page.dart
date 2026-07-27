import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:godigital_portal/core/constants/app_colors.dart';
import 'package:godigital_portal/core/constants/app_text_styles.dart';
import 'package:godigital_portal/services/auth_service.dart';
import '../../services/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'employee_layout_page.dart';

// ════════════════════════════════════════════════════════════════════════════
// FEEDBACK PAGE - Main Page
// ════════════════════════════════════════════════════════════════════════════
class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}
 
class _FeedbackPageState extends State<FeedbackPage> {
  // static const String _baseUrl = '/api/feedback';
  static String get _baseUrl => ApiConfig.baseUrl;

  List<FeedbackRowModel> feedbackRows = [];
  bool _loading = false;
  String? _employeeName;
  int? _employeeId;
  String? _authToken;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = context.read<AuthService>();
      _employeeName = authService.user?['fullName'] ?? '';
      _employeeId = authService.user?['id'] as int?;
      _authToken = authService.token;

      debugPrint('🔐 Auth Token: $_authToken');
      debugPrint('👤 Employee: $_employeeName (ID: $_employeeId)');

      _addNewFeedbackRow();
    });
  }

  // ── ADD NEW FEEDBACK ROW ──────────────────────────────────────────────
  void _addNewFeedbackRow() {
    setState(() {
      feedbackRows.add(FeedbackRowModel());
    });
  }

  // ── SAVE FEEDBACK TO BACKEND ──────────────────────────────────────────
  Future<void> saveFeedback(FeedbackRowModel row) async {
     Future<void> saveFeedback(FeedbackRowModel row) async {
    if (row.clientNameController.text.trim().isEmpty) {
      _showSnack('Please enter client name.', success: false);
      return;
    }

    if (row.feedbackController.text.trim().isEmpty) {
      _showSnack('Please enter feedback before saving.', success: false);
      return;
    }

    if (_authToken == null) {
      _showSnack('❌ Authentication error - No token found', success: false);
      return;
    }

    setState(() => _loading = true);

    try {
      final clientName = row.clientNameController.text.trim();
      final feedback = row.feedbackController.text.trim();

      debugPrint('📤 Sending POST to: $_baseUrl');
      debugPrint('📦 Body: { clientName: "$clientName", feedback: "..." }');

      // final r = await http.post(
      //   Uri.parse(_baseUrl),

      final r = await http.post(
  Uri.parse('$_baseUrl/feedback'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: jsonEncode({
          'clientName': clientName,
          'feedback': feedback,
        }),
      ).timeout(const Duration(seconds: 10));

      debugPrint('📥 Status: ${r.statusCode}');
      debugPrint('📦 Response: ${r.body}');

      if (r.statusCode == 201) {
        final responseData = jsonDecode(r.body)['data'];
        setState(() {
          row.isSaved = true;
          row.feedbackId = responseData['id'] as int?;
          row.createdAt = responseData['createdAt'] as String?;
        });
        _showSnack('✅ Feedback saved for $clientName', success: true);
        debugPrint('✅ Saved ID: ${row.feedbackId}');
      } else if (r.statusCode == 401) {
        _showSnack('❌ Unauthorized - Please login again', success: false);
      } else if (r.statusCode == 400) {
        final error = jsonDecode(r.body)['message'] ?? 'Bad request';
        _showSnack('❌ Error: $error', success: false);
      } else if (r.statusCode == 500) {
        _showSnack('❌ Server Error (500) - Check backend & database', success: false);
        debugPrint('❌ 500 Error: ${r.body}');
      } else {
        _showSnack('❌ Failed (${r.statusCode})', success: false);
      }
    } catch (e) {
      if (e is TimeoutException) {
        _showSnack('❌ Timeout - Backend not responding', success: false);
      } else {
        _showSnack('❌ Error: ${e.toString()}', success: false);
      }
    } finally {
      setState(() => _loading = false);
    }
  }

    if (row.clientNameController.text.trim().isEmpty) {
      _showSnack('Please enter client name.', success: false);
      return;
    }

    if (row.feedbackController.text.trim().isEmpty) {
      _showSnack('Please enter feedback before saving.', success: false);
      return;
    }

    if (_authToken == null) {
      _showSnack('❌ Authentication error - No token found', success: false);
      return;
    }

    setState(() => _loading = true);

    try {
      final clientName = row.clientNameController.text.trim();
      final feedback = row.feedbackController.text.trim();

      debugPrint('📤 Sending POST to: $_baseUrl');
      debugPrint('📦 Body: { clientName: "$clientName", feedback: "..." }');

      // final r = await http.post(
      //   Uri.parse(_baseUrl),

      final r = await http.post(
  Uri.parse('$_baseUrl/feedback'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: jsonEncode({
          'clientName': clientName,
          'feedback': feedback,
        }),
      ).timeout(const Duration(seconds: 10));

      debugPrint('📥 Status: ${r.statusCode}');
      debugPrint('📦 Response: ${r.body}');

      if (r.statusCode == 201) {
        final responseData = jsonDecode(r.body)['data'];
        setState(() {
          row.isSaved = true;
          row.feedbackId = responseData['id'] as int?;
          row.createdAt = responseData['createdAt'] as String?;
        });
        _showSnack('✅ Feedback saved for $clientName', success: true);
        debugPrint('✅ Saved ID: ${row.feedbackId}');
      } else if (r.statusCode == 401) {
        _showSnack('❌ Unauthorized - Please login again', success: false);
      } else if (r.statusCode == 400) {
        final error = jsonDecode(r.body)['message'] ?? 'Bad request';
        _showSnack('❌ Error: $error', success: false);
      } else if (r.statusCode == 500) {
        _showSnack('❌ Server Error (500) - Check backend & database', success: false);
        debugPrint('❌ 500 Error: ${r.body}');
      } else {
        _showSnack('❌ Failed (${r.statusCode})', success: false);
      }
    } catch (e) {
      if (e is TimeoutException) {
        _showSnack('❌ Timeout - Backend not responding', success: false);
      } else {
        _showSnack('❌ Error: ${e.toString()}', success: false);
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  // ── UPDATE FEEDBACK ───────────────────────────────────────────────────
  Future<void> updateFeedback(FeedbackRowModel row) async {
    if (row.clientNameController.text.trim().isEmpty ||
        row.feedbackController.text.trim().isEmpty) {
      _showSnack('Both fields required', success: false);
      return;
    }

    setState(() => _loading = true);
    try {
      final r = await http.put(
        Uri.parse('$_baseUrl/${row.feedbackId}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: jsonEncode({
          'clientName': row.clientNameController.text.trim(),
          'feedback': row.feedbackController.text.trim(),
        }),
      ).timeout(const Duration(seconds: 10));

      if (r.statusCode == 200) {
        _showSnack('✅ Feedback updated', success: true);
        debugPrint('✅ Updated feedback ID ${row.feedbackId}');
      } else {
        _showSnack('❌ Failed to update', success: false);
      }
    } catch (e) {
      _showSnack('❌ Error: ${e.toString()}', success: false);
    } finally {
      setState(() => _loading = false);
    }
  }

  // ── DELETE FEEDBACK ───────────────────────────────────────────────────
  Future<void> deleteFeedback(FeedbackRowModel row) async {
    setState(() => _loading = true);
    try {
      final r = await http.delete(
        Uri.parse('$_baseUrl/${row.feedbackId}'),
        headers: {'Authorization': 'Bearer $_authToken'},
      ).timeout(const Duration(seconds: 10));

      if (r.statusCode == 200) {
        setState(() => feedbackRows.remove(row));
        row.dispose();
        _showSnack('✅ Feedback deleted', success: true);
        debugPrint('✅ Deleted feedback ID ${row.feedbackId}');
      } else {
        _showSnack('❌ Failed to delete', success: false);
      }
    } catch (e) {
      _showSnack('❌ Error: ${e.toString()}', success: false);
    } finally {
      setState(() => _loading = false);
    }
  }

  // ── SHOW SNACKBAR ─────────────────────────────────────────────────────
  void _showSnack(String msg, {required bool success}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(success ? Icons.check_circle : Icons.error, color: Colors.white, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(msg, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        backgroundColor: success ? AppColors.green : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    for (final row in feedbackRows) row.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && feedbackRows.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF004AAD)),
      );
    }

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(38, 30, 38, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
              const SizedBox(height: 28),
              _table(),
            ],
          ),
        ),
        if (_loading)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: CircularProgressIndicator(color: Color(0xFF004AAD)),
            ),
          ),
      ],
    );
  }

  // ── PAGE HEADER ───────────────────────────────────────────────────────
  Widget _header() {
    return Row(
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Feedback', style: AppTextStyles.heading),
            SizedBox(height: 6),
            Text(
              'Share your thoughts, suggestions, or concerns to help us improve our services.',
              style: AppTextStyles.subHeading,
            ),
          ],
        ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('employeeMenu', 'Feedback History');

            if (!mounted) return;

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const EmployeeLayoutPage(),
              ),
            );
          },
          icon: const Icon(Icons.history_rounded, size: 16, color: Color(0xFF004AAD)),
          label: const Text('View History',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF004AAD))),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF004AAD)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _addNewFeedbackRow,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Feedback',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF004AAD),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
          ),
        ),
      ],
    );
  }
  // ── FEEDBACK TABLE ────────────────────────────────────────────────────
  Widget _table() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            height: 50,
            color: AppColors.lightBlue,
            child: const Row(
              children: [
                SizedBox(
                  width: 200,
                  child: Center(
                    child: Text('Client Name',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        )),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text('Feedbacks',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        )),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: Center(
                    child: Text('Action',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        )),
                  ),
                ),
              ],
            ),
          ),
          if (feedbackRows.isEmpty)
            Container(
              height: 200,
              alignment: Alignment.center,
              child: const Text(
                'No feedback yet. Click "Add Feedback" to get started.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            )
          else
            ...feedbackRows.map(_buildRow),
        ],
      ),
    );
  }

  // ── FEEDBACK ROW ──────────────────────────────────────────────────────
  Widget _buildRow(FeedbackRowModel row) {
    return Container(
      constraints: const BoxConstraints(minHeight: 160),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Client Name Input
          Container(
            width: 200,
            color: AppColors.lightBlue,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: TextField(
              controller: row.clientNameController,
              textAlign: TextAlign.center,
              maxLines: 3,
              enabled: !row.isSaved,
              decoration: InputDecoration(
                hintText: 'Enter client name',
                border: InputBorder.none,
                hintStyle: const TextStyle(color: AppColors.textGrey, fontSize: 14),
              ),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark,
              ),
            ),
          ),
          // Feedback Text Field
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              alignment: Alignment.center,
              child: TextField(
                controller: row.feedbackController,
                maxLines: 3,
                enabled: !row.isSaved,
                decoration: const InputDecoration(
                  hintText: 'Enter your feedback here',
                  hintStyle: TextStyle(color: Color(0xFFE1E5EA), fontSize: 16),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          // Action Buttons
          Container(
            width: 200,
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: AppColors.border)),
            ),
            child: Center(child: row.isSaved ? _savedActions(row) : _saveButton(row)),
          ),
        ],
      ),
    );
  }

  // ── SAVE BUTTON ───────────────────────────────────────────────────────
  Widget _saveButton(FeedbackRowModel row) {
    return GestureDetector(
      onTap: () => saveFeedback(row),
      child: Container(
        height: 34,
        width: 70,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF0057E7),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: const Text(
          'Save',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
    );
  }

  // ── SAVED ACTIONS (Edit & Delete) ─────────────────────────────────────
  Widget _savedActions(FeedbackRowModel row) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => updateFeedback(row),
            child: Container(
              height: 34,
              width: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Edit',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => deleteFeedback(row),
            child: Container(
              height: 34,
              width: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Delete',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// FEEDBACK ROW MODEL
// ════════════════════════════════════════════════════════════════════════════
class FeedbackRowModel {
  final TextEditingController clientNameController;
  final TextEditingController feedbackController;
  bool isSaved;
  int? feedbackId;
  String? createdAt;
  String? updatedAt;

  FeedbackRowModel({
    String clientName = '',
    String feedback = '',
    this.isSaved = false,
    this.feedbackId,
    this.createdAt,
    this.updatedAt,
  })  : clientNameController = TextEditingController(text: clientName),
        feedbackController = TextEditingController(text: feedback);

  void dispose() {
    clientNameController.dispose();
    feedbackController.dispose();
  }
}

// ════════════════════════════════════════════════════════════════════════════
// FEEDBACK HISTORY PAGE
// ════════════════════════════════════════════════════════════════════════════
class FeedbackHistoryPage extends StatefulWidget {
  const FeedbackHistoryPage({super.key});

  @override
  State<FeedbackHistoryPage> createState() => _FeedbackHistoryPageState();
}

class _FeedbackHistoryPageState extends State<FeedbackHistoryPage> {
  // static const String _baseUrl = '/api/feedback';
  static String get _baseUrl => ApiConfig.baseUrl;

  List<FeedbackHistoryItem> _allRecords = [];
  List<FeedbackHistoryItem> _filteredRecords = [];
  bool _loading = true;
  String? _authToken;
  String _selectedMonth = 'All';
  List<String> _availableMonths = ['All'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = context.read<AuthService>();
      _authToken = authService.token;
      _loadHistory();
    });
  }

  // ── LOAD FEEDBACK HISTORY ─────────────────────────────────────────────
  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    try {
      final r = await http.get(
        Uri.parse(_baseUrl),
        headers: {'Authorization': 'Bearer $_authToken'},
      ).timeout(const Duration(seconds: 10));

      if (r.statusCode == 200) {
        final data = List<dynamic>.from(jsonDecode(r.body)['data'] ?? []);
        final items = data.map((item) {
          return FeedbackHistoryItem(
            id: item['id'] as int? ?? 0,
            clientName: item['client_name'] as String? ?? 'Unknown',
            feedback: item['feedback_text'] as String? ?? '',
            createdAt: item['created_at'] as String? ?? '',
            updatedAt: item['updated_at'] as String? ?? '',
          );
        }).toList();

        final months = <String>{'All'};
        for (final item in items) {
          if (item.createdAt.length >= 7) {
            months.add(item.createdAt.substring(0, 7));
          }
        }

        setState(() {
          _allRecords = items;
          _availableMonths = months.toList()
            ..sort((a, b) {
              if (a == 'All') return -1;
              if (b == 'All') return 1;
              return b.compareTo(a);
            });
          _loading = false;
        });

        _applyFilters();
      } else {
        setState(() => _loading = false);
        _showSnack('Failed to load history');
      }
    } catch (e) {
      setState(() => _loading = false);
      _showSnack('Error: ${e.toString()}');
    }
  }

  // ── APPLY FILTERS ─────────────────────────────────────────────────────
  void _applyFilters() {
    setState(() {
      _filteredRecords = _allRecords.where((item) {
        if (_selectedMonth != 'All') {
          final itemMonth = item.createdAt.length >= 7 ? item.createdAt.substring(0, 7) : '';
          if (itemMonth != _selectedMonth) return false;
        }
        return true;
      }).toList();
    });
  }

  // ── SHOW SNACKBAR ─────────────────────────────────────────────────────
  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  // ── FORMAT DATE ───────────────────────────────────────────────────────
  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final dd = date.day.toString().padLeft(2, '0');
      final mm = date.month.toString().padLeft(2, '0');
      final yy = date.year;
      final hh = date.hour.toString().padLeft(2, '0');
      final min = date.minute.toString().padLeft(2, '0');
      return '$dd/$mm/$yy  $hh:$min';
    } catch (_) {
      return dateString;
    }
  }

  // ── FORMAT MONTH LABEL ────────────────────────────────────────────────
  String _monthLabel(String m) {
    if (m == 'All') return 'All Months';
    final parts = m.split('-');
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final idx = int.tryParse(parts[1]) ?? 0;
    return '${months[idx]} ${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF004AAD)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Feedback History',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF172554))),
        actions: [
          IconButton(
            onPressed: _loadHistory,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF004AAD)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            color: Colors.white,
            child: Row(
              children: [
                const Text('Month:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                const SizedBox(width: 10),
                Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedMonth,
                      items: _availableMonths
                          .map((m) => DropdownMenuItem(
                            value: m,
                            child: Text(_monthLabel(m), style: const TextStyle(fontSize: 13)),
                          ))
                          .toList(),
                      onChanged: (v) {
                        setState(() => _selectedMonth = v!);
                        _applyFilters();
                      },
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(20)),
                  child: Text('${_filteredRecords.length} record${_filteredRecords.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF004AAD),
                      )),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Table header
          Container(
            height: 44,
            color: const Color(0xFFF1F5F9),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: const Row(
              children: [
                SizedBox(width: 50, child: Text('#', style: _headerStyle)),
                SizedBox(width: 150, child: Text('Client', style: _headerStyle)),
                Expanded(child: Text('Feedback', style: _headerStyle)),
                SizedBox(width: 140, child: Text('Created', style: _headerStyle)),
                SizedBox(width: 140, child: Text('Updated', style: _headerStyle)),
              ],
            ),
          ),
          const Divider(height: 1),
          // Table content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF004AAD)))
                : _filteredRecords.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.history_rounded, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            const Text(
                              'No feedback history yet',
                              style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        itemCount: _filteredRecords.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, idx) {
                          final item = _filteredRecords[idx];
                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            color: idx.isEven ? Colors.white : const Color(0xFFFAFAFC),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 50,
                                  child: Text('${idx + 1}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                ),
                                SizedBox(
                                  width: 150,
                                  child: Text(item.clientName,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1E293B),
                                      ),
                                      overflow: TextOverflow.ellipsis),
                                ),
                                Expanded(
                                  child: Text(item.feedback,
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1),
                                ),
                                SizedBox(
                                  width: 140,
                                  child: Text(_formatDate(item.createdAt),
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                ),
                                SizedBox(
                                  width: 140,
                                  child: Text(_formatDate(item.updatedAt),
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// FEEDBACK HISTORY ITEM MODEL
// ════════════════════════════════════════════════════════════════════════════
class FeedbackHistoryItem {
  final int id;
  final String clientName;
  final String feedback;
  final String createdAt;
  final String updatedAt;

  FeedbackHistoryItem({
    required this.id,
    required this.clientName,
    required this.feedback,
    required this.createdAt,
    required this.updatedAt,
  });
}

const TextStyle _headerStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569));