import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../layouts/admin_layout.dart';
import '../../services/api_config.dart';


class TasksAssignScreen extends StatefulWidget {
  const TasksAssignScreen({super.key});

  @override
  State<TasksAssignScreen> createState() => _TasksAssignScreenState();
}

class _TasksAssignScreenState extends State<TasksAssignScreen> {
  // static const String _baseUrl = '/api';
  static String get _baseUrl => ApiConfig.baseUrl;

  List<Map<String, dynamic>> taskRows  = [];
  List<String>               employees = [];
  List<String>               clients   = [];
  List<String>               packages  = [];

  bool _showAssigned = false;

  bool _loadingTasks     = true;
  bool _loadingEmployees = true;
  bool _loadingClients   = true;
  bool _loadingPackages  = true;
  String? _error;

  static const List<String> _adsPlatformOptions   = ['GOOGLE ADS', 'META ADS', 'YOUTUBE ADS', 'Landing page', 'ALL'];
  static const List<String> _pagesPlatformOptions = ['GMB', 'FACEBOOK', 'INSTAGRAM', 'LINKDIN', 'YOUTUBE', 'DIGITAL MARKET'];
  static const List<String> _deadlineOptions       = ['1 WEEK', '15 DAYS', '1 MONTH', '2 MONTHS'];

  static const List<String> _taskOptions = [
    'POSTER', 'VIDEO', 'REELS', 'WEBSITE',
    'MOB APP', 'VIDEOGRAPHY', 'UI/UX DESIGNS',
  ];

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    await Future.wait([_fetchEmployees(), _fetchClients(), _fetchPackages(), _fetchTasks()]);
  }

  // ── FETCH Invoice Details for Selected Client ──────────────────────────────────
  Future<void> _loadClientInvoiceData(Map<String, dynamic> row) async {
    try {
      final clientName = row['client_name'];
      if (clientName == null || clientName.isEmpty) return;

      debugPrint('👤 Client selected: $clientName');
      debugPrint('📥 Fetching invoice data for client: $clientName');

      final response = await http.get(
        Uri.parse('$_baseUrl/invoices/client-details/$clientName'),
      ).timeout(const Duration(seconds: 10));

      debugPrint('📡 Response status: ${response.statusCode}');
      debugPrint('📄 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final data = jsonData['data'] ?? jsonData;

        // ✅ FIXED: Handle different API response structures
        final packages = (data['packages'] ?? data['deliverables'] ?? '').toString();
        final maintenanceDate = (data['maintenance_date'] ?? data['maintenanceDate'] ?? '').toString();

        debugPrint('✅ Invoice Data Received:');
        debugPrint('   Packages: $packages');
        debugPrint('   Maintenance Date: $maintenanceDate');

        // ✅ FIXED: Update row data
        setState(() {
          row['deliverables'] = packages;
          row['maintenance_date'] = maintenanceDate;
          debugPrint('🔄 State updated - row data refreshed');
        });

        // Save to database
        await _saveRow(row);
        debugPrint('💾 Data saved to database');
      } else {
        debugPrint('❌ Error: Server returned ${response.statusCode}');
        debugPrint('   Response: ${response.body}');
        
        // Show error to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to fetch client details: ${response.statusCode}')),
          );
        }
      }
    } on TimeoutException {
      debugPrint('❌ Request timeout');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request timeout. Please try again.')),
        );
      }
    } catch (e) {
      debugPrint('❌ Exception: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _fetchPackages() async {
    setState(() => _loadingPackages = true);
    try {
      final r = await http.get(Uri.parse('$_baseUrl/packages'));
      if (r.statusCode == 200) {
        final data = List<Map<String, dynamic>>.from(jsonDecode(r.body)['data']);
        setState(() {
          packages = data.map((p) => (p['title'] ?? '').toString()).where((t) => t.isNotEmpty).toList();
          _loadingPackages = false;
        });
      } else { setState(() => _loadingPackages = false); }
    } catch (_) { setState(() => _loadingPackages = false); }
  }

  Future<void> _fetchEmployees() async {
    setState(() => _loadingEmployees = true);
    try {
      final r = await http.get(Uri.parse('$_baseUrl/employees'));
      if (r.statusCode == 200) {
        final data = List<Map<String, dynamic>>.from(jsonDecode(r.body)['data']);
        setState(() {
          employees = data.map((e) => (e['full_name'] ?? '').toString().toUpperCase()).toList();
          _loadingEmployees = false;
        });
      } else { setState(() => _loadingEmployees = false); }
    } catch (_) { setState(() => _loadingEmployees = false); }
  }

  Future<void> _fetchClients() async {
    setState(() => _loadingClients = true);
    try {
      final r = await http.get(Uri.parse('$_baseUrl/clients'));
      if (r.statusCode == 200) {
        final data = List<Map<String, dynamic>>.from(jsonDecode(r.body)['data']);
        setState(() {
          clients = data.map((c) => (c['company_name'] ?? '').toString()).toSet().toList();
          _loadingClients = false;
        });
      } else { setState(() => _loadingClients = false); }
    } catch (_) { setState(() => _loadingClients = false); }
  }

  Future<void> _fetchTasks() async {
    setState(() { _loadingTasks = true; _error = null; });
    try {
      final r = await http.get(Uri.parse('$_baseUrl/tasks'));
      if (r.statusCode == 200) {
        setState(() {
          taskRows = List<Map<String, dynamic>>.from(jsonDecode(r.body)['data']);
          _loadingTasks = false;
        });
      } else {
        setState(() { _error = 'Server error ${r.statusCode}'; _loadingTasks = false; });
      }
    } catch (e) {
      setState(() { _error = 'Cannot connect to server'; _loadingTasks = false; });
    }
  }

  Future<void> _addRow() async {
    try {
      final r = await http.post(
        Uri.parse('$_baseUrl/tasks'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'clientName': clients.isNotEmpty ? clients.first : 'CLIENT'}),
      );
      if (r.statusCode == 201) await _fetchTasks();
    } catch (_) {}
  }

  Future<void> _saveRow(Map<String, dynamic> row) async {
    try {
      await http.put(
        Uri.parse('$_baseUrl/tasks/${row["id"]}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'clientName':         row['client_name']         ?? '',
          'deliverables':       row['deliverables']        ?? '',
          'maintenanceDate':    row['maintenance_date']    ?? '',
          'adsHandling':        row['ads_handling']        ?? '',
          'adsPlatform':        row['ads_platform']        ?? '',
          'adsSubmitDate':      row['ads_submit_date']     ?? '',
          'pageHandling':       row['page_handling']       ?? '',
          'pagesPlatform':      row['pages_platform']      ?? '',
          'pageSubmitDate':     row['page_submit_date']    ?? '',
          'designer':           row['designer']            ?? '',
          'designerTasks':      row['designer_tasks']      ?? '',
          'designerSubmitDate': row['designer_submit_date']?? '',
          'videographer':       row['videographer']        ?? '',
          'videographerTasks':  row['videographer_tasks']  ?? '',
          'videographerSubmitDate': row['videographer_submit_date'] ?? '',
          'uiUxDesigner':       row['ui_ux_designer']      ?? '',
          'uiUxTasks':          row['ui_ux_tasks']         ?? '',
          'uiUxSubmitDate':     row['ui_ux_submit_date']   ?? '',
          'developer':          row['developer']           ?? '',
          'developerTasks':     row['developer_tasks']     ?? '',
          'developerSubmitDate': row['developer_submit_date'] ?? '',
          'deadline':           row['deadline']            ?? '',
          'comments':           row['comments']            ?? '',
          'isAssigned':         row['is_assigned'] == 1 || row['is_assigned'] == true,
        }),
      );
    } catch (e) {
      debugPrint("Save error: $e");
    }
  }

  Future<void> _toggleAssign(Map<String, dynamic> row) async {
    final newVal = !(row['is_assigned'] == 1 || row['is_assigned'] == true);
    setState(() => row['is_assigned'] = newVal ? 1 : 0);
    try {
      await http.patch(
        Uri.parse('$_baseUrl/tasks/${row["id"]}/assign'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'isAssigned': newVal}),
      );
    } catch (_) {}
  }

  Future<void> _deleteRow(int id) async {
    try {
      await http.delete(Uri.parse('$_baseUrl/tasks/$id'));
      await _fetchTasks();
    } catch (_) {}
  }

  Future<void> _pickDate(Map<String, dynamic> row, String fieldKey) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      final formattedDate = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      setState(() => row[fieldKey] = formattedDate);
      await _saveRow(row);
    }
  }

  Future<void> _showMultiSelectDropdown({
    required BuildContext context,
    required List<String> options,
    required String currentValue,
    required String title,
    required void Function(String) onChanged,
  }) async {
    final selected = currentValue.isEmpty
        ? <String>[]
        : currentValue.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final tempSelected = List<String>.from(selected);

    await showDialog(
      context: context,
      barrierColor: Colors.black12,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300, maxHeight: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0052CC),
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: const Icon(Icons.close, size: 18, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () {
                    setDialogState(() {
                      if (tempSelected.length == options.length) {
                        tempSelected.clear();
                      } else {
                        tempSelected..clear()..addAll(options);
                      }
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Row(children: [
                      Checkbox(
                        value: tempSelected.length == options.length
                            ? true
                            : tempSelected.isEmpty ? false : null,
                        tristate: true,
                        activeColor: const Color(0xFF0052CC),
                        onChanged: (v) {
                          setDialogState(() {
                            if (v == true) {
                              tempSelected..clear()..addAll(options);
                            } else {
                              tempSelected.clear();
                            }
                          });
                        },
                      ),
                      const Text('Select All',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0052CC))),
                    ]),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: options.map((option) {
                      final isChecked = tempSelected.contains(option);
                      return InkWell(
                        onTap: () {
                          setDialogState(() {
                            isChecked ? tempSelected.remove(option) : tempSelected.add(option);
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          child: Row(children: [
                            Checkbox(
                              value: isChecked,
                              activeColor: const Color(0xFF0052CC),
                              onChanged: (v) {
                                setDialogState(() {
                                  v == true ? tempSelected.add(option) : tempSelected.remove(option);
                                });
                              },
                            ),
                            Expanded(
                              child: Text(option, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                            ),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
                  child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(
                      onPressed: () => setDialogState(() => tempSelected.clear()),
                      child: const Text('Clear All', style: TextStyle(color: Color(0xFF64748B))),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onChanged(tempSelected.join(', '));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0052CC),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        elevation: 0,
                      ),
                      child: const Text('Apply', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool loading = _loadingTasks || _loadingEmployees || _loadingClients || _loadingPackages;

    final visibleRows = taskRows.where((r) {
      final assigned = r['is_assigned'] == 1 || r['is_assigned'] == true;
      return _showAssigned ? assigned : !assigned;
    }).toList();

    return AdminLayout(
      pageTitle: "Tasks Assign",
      currentRoute: "/tasks",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                Text("Task Assign - Employees",
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                SizedBox(height: 4),
                Text("Assign, monitor, and manage employee tasks based on departments and client deliverables.",
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              ]),
              Row(children: [
                OutlinedButton.icon(
                  onPressed: () => setState(() => _showAssigned = !_showAssigned),
                  icon: Icon(
                    _showAssigned ? Icons.pending_actions_rounded : Icons.check_circle_outline_rounded,
                    size: 16,
                    color: const Color(0xFF0052CC),
                  ),
                  label: Text(
                    _showAssigned ? "Show Pending" : "Show Assigned",
                    style: const TextStyle(color: Color(0xFF0052CC), fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF0052CC)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _fetchAll,
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0052CC)),
                  tooltip: 'Refresh',
                ),
                const SizedBox(width: 4),
                ElevatedButton.icon(
                  onPressed: loading ? null : _addRow,
                  icon: const Icon(Icons.add, size: 16, color: Colors.white),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0052CC),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    elevation: 0,
                  ),
                  label: const Text("Add Section",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ]),
            ],
          ),

          const SizedBox(height: 12),

          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _showAssigned ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _showAssigned
                    ? "Showing ${visibleRows.length} assigned task(s)"
                    : "Showing ${visibleRows.length} pending task(s) — assigned rows are hidden",
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: _showAssigned ? const Color(0xFF16A34A) : const Color(0xFF1D4ED8),
                ),
              ),
            ),
          ]),

          const SizedBox(height: 16),

          if (loading && taskRows.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: CircularProgressIndicator(color: Color(0xFF0052CC)),
            ))
          else if (_error != null)
            Center(child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(children: [
                Text(_error!, style: const TextStyle(color: Color(0xFF64748B))),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _fetchAll,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0052CC)),
                  child: const Text('Retry', style: TextStyle(color: Colors.white)),
                ),
              ]),
            ))
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 180,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Container(
                            height: 48,
                            color: const Color(0xFF0052CC),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            alignment: Alignment.centerLeft,
                            child: const Text("CLIENT NAME",
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                                    color: Colors.white, letterSpacing: 0.5)),
                          ),
                          ...visibleRows.map((row) => _buildClientCell(row)),
                          ...List.generate(4, (_) => _buildClientCell(null)),
                        ]),
                      ),
                      const VerticalDivider(width: 1, color: Color(0xFFCBD5E1)),

                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: 4200,
                            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              Container(
                                height: 48,
                                color: const Color(0xFFF8FAFC),
                                child: Row(children: const [
                                  _HeaderCell(width: 250, label: "DELIVERABLES"),
                                  _HeaderCell(width: 160, label: "MAINTENANCE DATE"),
                                  _HeaderCell(width: 140, label: "ADS HANDLER"),
                                  _HeaderCell(width: 160, label: "ADS TASKS"),
                                  _HeaderCell(width: 140, label: "ADS DATE"),
                                  _HeaderCell(width: 140, label: "PAGE HANDLER"),
                                  _HeaderCell(width: 160, label: "PAGE TASKS"),
                                  _HeaderCell(width: 140, label: "PAGE DATE"),
                                  _HeaderCell(width: 140, label: "DESIGNER"),
                                  _HeaderCell(width: 160, label: "DESIGN TASKS"),
                                  _HeaderCell(width: 140, label: "DESIGN DATE"),
                                  _HeaderCell(width: 140, label: "VIDEOGRAPHER"),
                                  _HeaderCell(width: 160, label: "VIDEO TASKS"),
                                  _HeaderCell(width: 140, label: "VIDEO DATE"),
                                  _HeaderCell(width: 140, label: "UI/UX DESIGNER"),
                                  _HeaderCell(width: 160, label: "UI/UX TASKS"),
                                  _HeaderCell(width: 140, label: "UI/UX DATE"),
                                  _HeaderCell(width: 140, label: "DEVELOPER"),
                                  _HeaderCell(width: 160, label: "DEV TASKS"),
                                  _HeaderCell(width: 140, label: "DEV DATE"),
                                  _HeaderCell(width: 140, label: "DEADLINE"),
                                  _HeaderCell(width: 160, label: "COMMENTS"),
                                  _HeaderCell(width: 140, label: "ACTION"),
                                ]),
                              ),
                              const Divider(height: 1, color: Color(0xFFE2E8F0)),
                              ...visibleRows.map((row) => _buildDataRow(row)),
                              ...List.generate(4, (_) => _buildEmptyRow()),
                            ]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClientCell(Map<String, dynamic>? row) {
    if (row == null) {
      return Container(
        height: 54,
        decoration: const BoxDecoration(
          color: Color(0xFF0052CC),
          border: Border(bottom: BorderSide(color: Color(0xFF0044B3))),
        ),
      );
    }

    String currentClient = row['client_name'] ?? '';
    if (!clients.contains(currentClient) && clients.isNotEmpty) currentClient = clients.first;

    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0052CC),
        border: Border(bottom: BorderSide(color: Color(0xFF0044B3))),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentClient.isEmpty ? null : currentClient,
          isExpanded: true,
          dropdownColor: const Color(0xFF1A5FCC),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
          items: clients.isEmpty
              ? [DropdownMenuItem(value: currentClient, child: Text(currentClient))]
              : clients.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (val) async {
            if (val != null && val != currentClient) {
              setState(() => row['client_name'] = val);
              // ✅ FIXED: Delay to ensure UI updates before fetching
              await Future.delayed(const Duration(milliseconds: 100));
              await _loadClientInvoiceData(row);
            }
          },
        ),
      ),
    );
  }

  Widget _buildDataRow(Map<String, dynamic> row) {
    final bool assigned = row['is_assigned'] == 1 || row['is_assigned'] == true;

    final empItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: '', child: Text('—', style: TextStyle(color: Color(0xFFCBD5E1)))),
      ...employees.map((e) => DropdownMenuItem(value: e, child: Text(e))),
    ];

    String empVal(String key) {
      final v = (row[key] ?? '').toString().toUpperCase();
      return employees.contains(v) ? v : '';
    }

    Widget multiCell(double width, String key, List<String> options, String colTitle) {
      final currentVal = row[key] ?? '';
      final selected = currentVal.toString().isEmpty
          ? <String>[]
          : currentVal.toString().split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

      return GestureDetector(
        onTap: () => _showMultiSelectDropdown(
          context: context,
          options: options,
          currentValue: currentVal.toString(),
          title: colTitle,
          onChanged: (newVal) { setState(() => row[key] = newVal); _saveRow(row); },
        ),
        child: Container(
          width: width, height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0xFFE2E8F0)))),
          child: Row(children: [
            Expanded(
              child: selected.isEmpty
                  ? const Text('—', style: TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)))
                  : Wrap(
                      spacing: 4, runSpacing: 2,
                      children: selected.map((s) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(3)),
                        child: Text(s, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8))),
                      )).toList(),
                    ),
            ),
            const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF64748B)),
          ]),
        ),
      );
    }

    // ── MAINTENANCE DATE CELL - Shows fetched date with calendar ──────────────────
    Widget maintenanceDateCell(double width) {
      final value = row['maintenance_date'] ?? '';
      return GestureDetector(
        onTap: () => _pickDate(row, 'maintenance_date'),
        child: Container(
          width: width,
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0xFFE2E8F0)))),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value.isEmpty ? '—' : value,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: value.isEmpty ? FontWeight.normal : FontWeight.w600,
                    color: value.isEmpty ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.calendar_today, size: 16, color: value.isEmpty ? const Color(0xFFCBD5E1) : const Color(0xFF0052CC)),
            ],
          ),
        ),
      );
    }

    // ── DELIVERABLES CELL ─────────────────────────────────────────────────────────
    Widget deliverableCell(double width) {
      final value = row['deliverables'] ?? '';
      return Container(
        width: width,
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0xFFE2E8F0)))),
        alignment: Alignment.centerLeft,
        child: Text(
          value.isEmpty ? '—' : value,
          style: TextStyle(
            fontSize: 10,
            color: value.isEmpty ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
            fontWeight: value.isEmpty ? FontWeight.normal : FontWeight.w600,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    // ── DATE CELL WITH CALENDAR PICKER ────────────────────────────────────────────
    Widget dateCell(double width, String key) {
      final value = row[key] ?? '';
      return GestureDetector(
        onTap: () => _pickDate(row, key),
        child: Container(
          width: width,
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0xFFE2E8F0)))),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value.isEmpty ? '—' : value,
                  style: TextStyle(
                    fontSize: 11,
                    color: value.isEmpty ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.calendar_today, size: 14, color: value.isEmpty ? const Color(0xFFCBD5E1) : const Color(0xFF0052CC)),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 54,
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
      child: Row(children: [
        // DELIVERABLES (Auto-fetched)
        deliverableCell(250),
        
        // MAINTENANCE DATE (Auto-fetched + Calendar)
        maintenanceDateCell(160),
        
        // ADS HANDLER
        _empDropCell(140, empVal('ads_handling'), empItems, onChanged: (v) { setState(() => row['ads_handling'] = v); _saveRow(row); }),
        
        // ADS TASKS
        multiCell(160, 'ads_platform', _adsPlatformOptions, 'ADS TASKS'),
        
        // ADS DATE
        dateCell(140, 'ads_submit_date'),
        
        // PAGE HANDLER
        _empDropCell(140, empVal('page_handling'), empItems, onChanged: (v) { setState(() => row['page_handling'] = v); _saveRow(row); }),
        
        // PAGE TASKS
        multiCell(160, 'pages_platform', _pagesPlatformOptions, 'PAGE TASKS'),
        
        // PAGE DATE
        dateCell(140, 'page_submit_date'),
        
        // DESIGNER
        _empDropCell(140, empVal('designer'), empItems, onChanged: (v) { setState(() => row['designer'] = v); _saveRow(row); }),
        
        // DESIGNER TASKS
        multiCell(160, 'designer_tasks', _taskOptions, 'DESIGNER TASKS'),
        
        // DESIGNER DATE
        dateCell(140, 'designer_submit_date'),
        
        // VIDEOGRAPHER
        _empDropCell(140, empVal('videographer'), empItems, onChanged: (v) { setState(() => row['videographer'] = v); _saveRow(row); }),
        
        // VIDEOGRAPHER TASKS
        multiCell(160, 'videographer_tasks', _taskOptions, 'VIDEOGRAPHER TASKS'),
        
        // VIDEOGRAPHER DATE
        dateCell(140, 'videographer_submit_date'),
        
        // UI/UX DESIGNER
        _empDropCell(140, empVal('ui_ux_designer'), empItems, onChanged: (v) { setState(() => row['ui_ux_designer'] = v); _saveRow(row); }),
        
        // UI/UX TASKS
        multiCell(160, 'ui_ux_tasks', _taskOptions, 'UI/UX TASKS'),
        
        // UI/UX DATE
        dateCell(140, 'ui_ux_submit_date'),
        
        // DEVELOPER
        _empDropCell(140, empVal('developer'), empItems, onChanged: (v) { setState(() => row['developer'] = v); _saveRow(row); }),
        
        // DEVELOPER TASKS
        multiCell(160, 'developer_tasks', _taskOptions, 'DEV TASKS'),
        
        // DEVELOPER DATE
        dateCell(140, 'developer_submit_date'),
        
        // DEADLINE
        _dropCell(140, row['deadline'] ?? '', _deadlineOptions, onChanged: (v) { setState(() => row['deadline'] = v); _saveRow(row); }),
        
        // COMMENTS
        Container(
          width: 160,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0xFFE2E8F0)))),
          child: Center(child: SizedBox(height: 32, child: TextField(controller: TextEditingController(text: row['comments'] ?? ''), style: const TextStyle(fontSize: 10), onSubmitted: (v) { row['comments'] = v; _saveRow(row); }))),
        ),
        
        // ACTION
        Container(
          width: 140,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: [
            Expanded(
              child: SizedBox(
                height: 32,
                child: ElevatedButton(
                  onPressed: () => _toggleAssign(row),
                  style: ElevatedButton.styleFrom(backgroundColor: assigned ? const Color(0xFF00C853) : const Color(0xFF0052CC), padding: EdgeInsets.zero),
                  child: FittedBox(child: Text(assigned ? "ASSIGNED" : "ASSIGN", style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w900))),
                ),
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => _deleteRow(row['id']),
              child: Container(width: 24, height: 24, decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(4)), child: const Icon(Icons.delete_outline, size: 12, color: Color(0xFFDC2626))),
            ),
          ]),
        ),
      ]),
    );
  }
  
  Widget _dropCell(double width, String current, List<String> options, {required ValueChanged<String> onChanged}) {
    final safeVal = options.contains(current) ? current : '';
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0xFFE2E8F0)))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeVal.isEmpty ? null : safeVal,
          isExpanded: true,
          hint: const Text('—', style: TextStyle(fontSize: 11, color: Color(0xFFCBD5E1))),
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B), size: 16),
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }

  Widget _empDropCell(double width, String current, List<DropdownMenuItem<String>> items,
      {required ValueChanged<String> onChanged}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0xFFE2E8F0)))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: current.isEmpty ? '' : current,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B), size: 16),
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF0052CC)),
          items: items,
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }

  Widget _buildEmptyRow() {
    const widths = [250, 160, 140, 160, 140, 140, 160, 140, 140, 160, 140, 140, 160, 140, 140, 160, 140, 140, 160, 140, 140, 160, 140];
    return Container(
      height: 54,
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
      child: Row(
        children: widths.map((w) => Container(
          width: w.toDouble(),
          decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0xFFE2E8F0)))),
        )).toList(),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final double width;
  final String label;
  const _HeaderCell({required this.width, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0xFFE2E8F0)))),
      alignment: Alignment.centerLeft,
      child: Text(label, style: const TextStyle(
          fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.3),
          maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }
}