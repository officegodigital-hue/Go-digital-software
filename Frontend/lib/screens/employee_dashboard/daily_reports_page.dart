import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:godigital_portal/services/auth_service.dart';
import '../../services/api_config.dart';

// ── Data Model ─────────────────────────────────────────────────────────────────

class DailyReportModel {
  int id;
  String client;
  String report;
  String submissionDate;
  String status;

  DailyReportModel({
    required this.id,
    required this.client,
    required this.report,
    required this.submissionDate,
    required this.status,
  });

  factory DailyReportModel.fromJson(Map<String, dynamic> json) {
    return DailyReportModel(
      id: json['id'] ?? 0,
      client: json['client'] ?? '',
      report: json['report'] ?? '',
      submissionDate: json['submissionDate'] ?? '',
      status: json['status'] ?? 'DONE',
    );
  }
}

// ── Screen ✅ CONNECTED TO BACKEND ─────────────────────────────────────────────

class DailyReportsPage extends StatefulWidget {
  const DailyReportsPage({super.key});

  @override
  State<DailyReportsPage> createState() => _DailyReportsPageState();
}

class _DailyReportsPageState extends State<DailyReportsPage> {
  final TextEditingController _clientController = TextEditingController();
  final TextEditingController _reportController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  DateTime? _filterDate;
  int? _editingId;
  bool _saving = false;
  bool _loading = false;
  String? _error;

  // Backend API URL
  // static const String _baseUrl = '/api';
  static String get _baseUrl => ApiConfig.baseUrl;

  List<DailyReportModel> _reports = [];
  List<String> _assignedClients = [];
String? _selectedClient;

  @override
  void initState() {
    super.initState();
    _fetchReports();

  _loadAssignedClients();
  }

  @override
  void dispose() {
    _clientController.dispose();
    _reportController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAssignedClients() async {
  final auth = Provider.of<AuthService>(context, listen: false);
  final name = auth.user?['fullName'] as String?;

  if (name == null || name.isEmpty) return;

  try {
    final response = await http.get(
      Uri.parse(
        '$_baseUrl/employee-tasks/by-employee/${Uri.encodeComponent(name)}',
      ),
    );

    final additionalRes = await http.get(
      Uri.parse(
        '$_baseUrl/task-list/additional/${Uri.encodeComponent(name)}',
      ),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final rows = List<Map<String, dynamic>>.from(json['data'] ?? []);

      const roleColumns = [
        'designer',
        'videographer',
        'video_editor',
        'ads_handling',
        'page_handling',
        'ui_ux_designer',
        'developer',
      ];

      final nameUpper = name.toUpperCase();
      final clients = <String>{};

      for (final row in rows) {
        final matches = roleColumns.any((col) =>
            (row[col] ?? '').toString().toUpperCase() == nameUpper);

        if (matches) {
          final client = row['client_name']?.toString() ?? '';
          if (client.isNotEmpty) {
            clients.add(client);
          }
        }
      }

      if (additionalRes.statusCode == 200) {
        final addJson = jsonDecode(additionalRes.body);
        final addRows =
            List<Map<String, dynamic>>.from(addJson['data'] ?? []);

        for (final row in addRows) {
          final client = row['client_name']?.toString() ?? '';
          if (client.isNotEmpty) {
            clients.add(client);
          }
        }
      }

      setState(() {
        _assignedClients = clients.toList();
      });
    }
  } catch (e) {
    debugPrint(e.toString());
  }
}

  // ── API: Fetch all reports ─────────────────────────────────────────────────
  Future<void> _fetchReports() async {
    try {
      setState(() => _loading = true);
      final authService = context.read<AuthService>();
      final token = authService.token;

      if (token == null) {
        _showSnack('Not authenticated');
        return;
      }

      debugPrint('📋 Fetching daily reports from backend...');

      final response = await http.get(
        Uri.parse('$_baseUrl/daily-reports'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List<dynamic> reportsList = data['data'] ?? [];
          setState(() {
            _reports = reportsList
                .map((item) => DailyReportModel.fromJson(item))
                .toList();
            _error = null;
          });
          debugPrint('✅ Fetched ${_reports.length} reports');
        } else {
          _showSnack(data['message'] ?? 'Failed to fetch reports');
        }
      } else if (response.statusCode == 401) {
        _showSnack('Token expired - please login again');
      } else {
        _showSnack('Error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching reports: $e');
      if (mounted) _showSnack('Connection error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── API: Create new report ─────────────────────────────────────────────────
  Future<void> _createReport(String client, String report, String date) async {
    try {
      final authService = context.read<AuthService>();
      final token = authService.token;

      if (token == null) {
        _showSnack('Not authenticated');
        return;
      }

      debugPrint('➕ Creating new report...');

      final response = await http.post(
        Uri.parse('$_baseUrl/daily-reports'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'client': client,
          'report': report,
          'submissionDate': date,
          'status': 'DONE',
        }),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _showSnack('Report created successfully', success: true);
          debugPrint('✅ Report created');
          await _fetchReports(); // Refresh list
        } else {
          _showSnack(data['message'] ?? 'Failed to create report');
        }
      } else {
        _showSnack('Error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error creating report: $e');
      if (mounted) _showSnack('Connection error: $e');
    }
  }

  // ── API: Update report ─────────────────────────────────────────────────────
  Future<void> _updateReport(
      int id, String client, String report, String date) async {
    try {
      final authService = context.read<AuthService>();
      final token = authService.token;

      if (token == null) {
        _showSnack('Not authenticated');
        return;
      }

      debugPrint('✏️ Updating report $id...');

      final response = await http.put(
        Uri.parse('$_baseUrl/daily-reports/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'client': client,
          'report': report,
          'submissionDate': date,
          'status': 'DONE',
        }),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _showSnack('Report updated successfully', success: true);
          debugPrint('✅ Report updated');
          await _fetchReports(); // Refresh list
        } else {
          _showSnack(data['message'] ?? 'Failed to update report');
        }
      } else {
        _showSnack('Error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error updating report: $e');
      if (mounted) _showSnack('Connection error: $e');
    }
  }

  // ── API: Delete report ─────────────────────────────────────────────────────
  Future<void> _deleteReportApi(int id) async {
    try {
      final authService = context.read<AuthService>();
      final token = authService.token;

      if (token == null) {
        _showSnack('Not authenticated');
        return;
      }

      debugPrint('🗑️ Deleting report $id...');

      final response = await http.delete(
        Uri.parse('$_baseUrl/daily-reports/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _showSnack('Report deleted', success: true);
          debugPrint('✅ Report deleted');
          await _fetchReports(); // Refresh list
        } else {
          _showSnack(data['message'] ?? 'Failed to delete report');
        }
      } else {
        _showSnack('Error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error deleting report: $e');
      if (mounted) _showSnack('Connection error: $e');
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? const Color(0xFF16A34A) : Colors.redAccent,
    ));
  }

  void _clearForm() {
    setState(() {
      _selectedClient = null;
      _clientController.clear();
      _reportController.clear();
      _selectedDate = DateTime.now();
      _editingId = null;
    });
  }

  void _populateForm(DailyReportModel report) {
    setState(() {
      _editingId = report.id;
      _selectedClient = report.client;
      _clientController.text = report.client;
      _reportController.text = report.report;
      _selectedDate = DateFormat('dd/MM/yyyy').parse(report.submissionDate);
    });
  }

  void _saveForm() {
    final client = _clientController.text.trim();
    final report = _reportController.text.trim();
    final date = DateFormat('dd/MM/yyyy').format(_selectedDate);

    if (client.isEmpty || report.isEmpty) {
      _showSnack('Please fill all required fields');
      return;
    }

    setState(() => _saving = true);

    // Call backend API instead of local storage
    if (_editingId != null) {
      _updateReport(_editingId!, client, report, date).then((_) {
        if (mounted) {
          setState(() => _saving = false);
          _clearForm();
        }
      });
    } else {
      _createReport(client, report, date).then((_) {
        if (mounted) {
          setState(() => _saving = false);
          _clearForm();
        }
      });
    }
  }

  void _deleteReport(int id) {
    _deleteReportApi(id);
    if (_editingId == id) _clearForm();
  }

  List<DailyReportModel> get _filteredReports {
    return _reports.where((r) {
      final matchesSearch = r.client.toLowerCase().contains(
            _searchController.text.toLowerCase(),
          ) ||
          r.report.toLowerCase().contains(
            _searchController.text.toLowerCase(),
          );
      final matchesDate = _filterDate == null ||
          r.submissionDate == DateFormat('dd/MM/yyyy').format(_filterDate!);
      return matchesSearch && matchesDate;
    }).toList();
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'DONE':
        return const Color(0xFF16A34A);
      case 'PENDING':
        return const Color(0xFFF59E0B);
      case 'IN_PROGRESS':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Page Header ────────────────────────────────────────────────────────
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Reports',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Track daily tasks, progress, achievements, and updates.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ── Content Grid ───────────────────────────────────────────────────────
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 800;

                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: _buildReportsTable()),
                            const SizedBox(width: 24),
                            Expanded(flex: 2, child: _buildSubmitForm()),
                          ],
                        );
                      }

                      return Column(
                        children: [
                          _buildSubmitForm(),
                          const SizedBox(height: 24),
                          _buildReportsTable(),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  // ── LEFT: Reports Table ────────────────────────────────────────────────────
  Widget _buildReportsTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              color: const Color(0xFFF1F5F9),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Report History',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  GestureDetector(
                    onTap: _fetchReports,
                    child: const Icon(
                      Icons.refresh_rounded,
                      size: 18,
                      color: Color(0xFF1A3A8F),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Filter Bar
          _buildFilterBar(),

          // Column Headers
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Row(
              children: const [
                _TableHeader('CLIENT', flex: 2),
                _TableHeader('REPORT', flex: 3),
                _TableHeader('DATE', flex: 2),
                _TableHeader('STATUS', flex: 2),
              ],
            ),
          ),

          // Table Body
          if (_filteredReports.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No reports found. Use the form to add one.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ),
            )
          else
            Column(
              children: _filteredReports.map((report) {
                final isEditing = _editingId == report.id;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isEditing ? const Color(0xFFF0F4FF) : Colors.white,
                    border: const Border(
                      bottom: BorderSide(color: Color(0xFFF3F4F6)),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Client
                      Expanded(
                        flex: 2,
                        child: Text(
                          report.client,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                      ),

                      // Report
                      Expanded(
                        flex: 3,
                        child: Text(
                          report.report,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),

                      // Date
                      Expanded(
                        flex: 2,
                        child: Text(
                          report.submissionDate,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ),

                      // Status
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(report.status)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: _getStatusColor(report.status)
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            report.status,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _getStatusColor(report.status),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),

                      // Actions
                 ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ── Filter Bar ─────────────────────────────────────────────────────────────
  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFD1D5DB)),
                borderRadius: BorderRadius.circular(6),
                color: const Color(0xFFF9FAFB),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search by client or report...',
                  hintStyle: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 16,
                    color: Color(0xFF6B7280),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _filterDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setState(() => _filterDate = picked);
              }
            },
            icon: const Icon(Icons.calendar_today_rounded, size: 14),
            label: Text(
              _filterDate == null
                  ? 'Filter by Date'
                  : DateFormat('dd/MM/yyyy').format(_filterDate!),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0052CC),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              elevation: 0,
            ),
          ),
          if (_filterDate != null) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => setState(() => _filterDate = null),
              icon: const Icon(Icons.close, size: 16),
              tooltip: 'Clear filter',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }

  // ── RIGHT: Submit Form Panel ───────────────────────────────────────────────
  Widget _buildSubmitForm() {
    final isEditing = _editingId != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              color: const Color(0xFF1A3A8F),
              child: Row(
                children: [
                  Icon(
                    isEditing
                        ? Icons.edit_note_rounded
                        : Icons.add_circle_outline_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isEditing ? 'Edit Report' : 'Submit New Report',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Client Name
                // _buildFormField(
                //   label: 'Client Name *',
                //   controller: _clientController,
                //   hint: 'e.g., GA MALL, JYOTHI',
                // ),

                Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    const Text(
      'Client Name *',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: Color(0xFF374151),
      ),
    ),
    const SizedBox(height: 6),
    DropdownButtonFormField<String>(
      initialValue: _selectedClient,
      isExpanded: true,
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      hint: const Text('Select Client'),
      items: _assignedClients.map((client) {
        return DropdownMenuItem(
          value: client,
          child: Text(client),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedClient = value;
          _clientController.text = value ?? '';
        });
      },
    ),
  ],
),

                const SizedBox(height: 16),

                // Report Details
                _buildFormField(
                  label: 'Report Details *',
                  controller: _reportController,
                  hint: 'Describe your work and achievements...',
                  maxLines: 4,
                ),

                const SizedBox(height: 16),

                // Date Picker
                _buildDatePickerField(),

                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : _clearForm,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF374151),
                          side:
                              const BorderSide(color: Color(0xFFD1D5DB)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saving ? null : _saveForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A3A8F),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                isEditing ? 'Update' : 'Submit',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: Color(0xFF1D4ED8),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Reports are submitted with DONE status and become part of your work history.',
                          style: TextStyle(
                            fontSize: 11,
                            color: const Color(0xFF1E40AF),
                            height: 1.4,
                          ),
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

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: maxLines == 1 ? 38 : 100,
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF1A1A2E),
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                fontSize: 13,
                color: Color(0xFF9CA3AF),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(
                  color: Color(0xFFD1D5DB),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(
                  color: Color(0xFF1A3A8F),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePickerField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Report Date *',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        Material(
          child: InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
              }
            },
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFD1D5DB)),
                borderRadius: BorderRadius.circular(6),
                color: const Color(0xFFF9FAFB),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('dd/MM/yyyy').format(_selectedDate),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: Color(0xFF6B7280),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Helper Widgets ────────────────────────────────────────────────────────────

class _TableHeader extends StatelessWidget {
  final String text;
  final int flex;

  const _TableHeader(this.text, {required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6B7280),
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}