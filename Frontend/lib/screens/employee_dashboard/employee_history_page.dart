// name=employee_history_page.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:godigital_portal/core/constants/app_colors.dart';
import 'package:godigital_portal/core/constants/employee_role.dart';
import 'package:godigital_portal/services/auth_service.dart';
import '../../services/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'employee_layout_page.dart';

enum TaskStatus { idle, running, held, completed, rejected }

class EmployeeHistoryPage extends StatefulWidget {
  final EmployeeRole role;
  const EmployeeHistoryPage({super.key, required this.role});

  @override
  State<EmployeeHistoryPage> createState() => _EmployeeHistoryPageState();
}

class _EmployeeHistoryPageState extends State<EmployeeHistoryPage> {
  static String get _baseUrl => ApiConfig.baseUrl;

  static const double snoWidth         = 50;
  static const double submitDateWidth  = 120;
  static const double taskWidth        = 150;
  static const double actionWidth      = 650; 
  static const double durationWidth    = 100;
  static const double commentWidth     = 140;
  static const double performanceWidth = 100;
  static const double statusWidth      = 100;
  static const double cellHeight       = 55;

  double get totalTableWidth =>
      snoWidth + submitDateWidth + taskWidth + actionWidth +
      durationWidth + commentWidth + performanceWidth + statusWidth + 100;

  final ScrollController _horizontalController = ScrollController();

  List<Map<String, dynamic>> completedTasks = [];
  List<String> taskTabNames = [];

  Map<String, int> expectedTimingMinutes = {};
  bool _loadingTasks = true;
  String? expandedTaskId;
  int? selectedTabIndex;
  String? _selectedClientFilter;
  TextEditingController? _clientSearchFieldController;
  String? _error;
  String? _employeeName;

  Map<String, String> editableSubmitDates = {};
  Map<String, String> editableTaskDescs = {};
  Map<String, String> taskComments = {};
  Map<String, Duration> taskTotalDurations = {};
  Map<String, TaskStatus> taskStatus = {};
  Map<String, int> rowCounts = {};
  
  Map<String, DateTime?> taskStartTimes = {};
  Map<String, List<DateTime>> taskHoldTimes = {};
  Map<String, List<DateTime>> taskRestartTimes = {};
  Map<String, List<DateTime>> taskCompletedTimes = {};
  Map<String, List<DateTime>> taskRejectedTimes = {};

  List<String> get _assignedClientNames {
    final names = completedTasks
        .map((t) => (t['client_name'] ?? '').toString())
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();
    names.sort();
    return names;
  }

  List<int> get _visibleTabIndices {
    if (_selectedClientFilter == null || _selectedClientFilter!.isEmpty) {
      return List.generate(taskTabNames.length, (i) => i);
    }
    final indices = <int>[];
    for (int i = 0; i < taskTabNames.length; i++) {
      final tabName = taskTabNames[i];
      final hasMatch = completedTasks.any((t) =>
          t['singleTask'] == tabName &&
          (t['client_name'] ?? '').toString() == _selectedClientFilter);
      if (hasMatch) indices.add(i);
    }
    return indices;
  }

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().user;
    _employeeName = (user?['fullName'] ?? user?['name'] ?? '') as String? ?? '';
    _fetchTimingData();
    _fetchCompletedHistory();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  Future<void> _fetchTimingData() async {
    try {
      final r = await http.get(Uri.parse('$_baseUrl/timings'));
      if (r.statusCode == 200) {
        final body = jsonDecode(r.body);
        for (var item in List.from(body['data'])) {
          final key = (item['task_name'] as String).trim().toLowerCase();
          expectedTimingMinutes[key] = _convertTimingToMinutes(item['timing'] as String);
        }
      }
    } catch (e) { debugPrint('Timing fetch error: $e'); }
  }

  int _convertTimingToMinutes(String timing) {
    final parts = timing.trim().split(' ');
    if (parts.length < 2) return 0;
    final v = int.tryParse(parts[0]) ?? 0;
    final u = parts[1].toLowerCase();
    if (u.startsWith('min')) return v;
    if (u.startsWith('hr'))  return v * 60;
    if (u.startsWith('day')) return v * 1440;
    return 0;
  }

  String _calculatePerformance(String singleTask, Duration? actual) {
    if (actual == null) return 'N/A';
    final exp = expectedTimingMinutes[singleTask.trim().toLowerCase()];
    if (exp == null) return 'N/A';
    final act = actual.inMinutes;
    if (act == exp) return 'Achieved';
    if (act < exp)  return 'Before In';
    return 'Delay Out';
  }

  Color _getPerformanceColor(String perf) {
    switch (perf) {
      case 'Achieved':  return const Color(0xFF00812B);
      case 'Before In': return const Color(0xFF1D4ED8);
      case 'Delay Out': return const Color(0xFFC40000);
      default:          return Colors.grey;
    }
  }

  Future<void> _fetchCompletedHistory() async {
    setState(() { _loadingTasks = true; _error = null; });
    try {
      if (_employeeName == null || _employeeName!.isEmpty) {
        setState(() { _error = 'Employee name not found.'; _loadingTasks = false; });
        return;
      }

      final r = await http.get(Uri.parse('$_baseUrl/tracking-items/history/$_employeeName'));
      if (r.statusCode == 200) {
        final body = jsonDecode(r.body);
        final allRows = List<dynamic>.from(body['data'] ?? []);

        final Set<String> allTabs = {};
        final Map<String, List<Map<String, dynamic>>> groupedTasks = {};

        for (var row in allRows) {
          final m = Map<String, dynamic>.from(row);
          final client = m['client_name']?.toString() ?? '';
          final deliverable = m['deliverables']?.toString() ?? m['single_task']?.toString() ?? '';
          final taskListId = m['task_list_id']?.toString() ?? '0';
          
          final key = '${client}_${deliverable}_$taskListId';

          if (deliverable.isNotEmpty) {
            allTabs.add(deliverable);
            groupedTasks.putIfAbsent(key, () => []).add(m);
          }
        }

        final List<Map<String, dynamic>> processed = [];
        groupedTasks.forEach((key, rows) {
          if (rows.isNotEmpty) {
            final first = rows.first;
            processed.add({
              'historyTaskId': key,
              'client_name': first['client_name'],
              'singleTask': first['deliverables'] ?? first['single_task'],
              'assignedDate': first['submit_date'],
              'rowsData': rows,
            });
          }
        });

        rowCounts.clear();
        for (final tab in allTabs) {
          final tasksForTab = processed.where((t) => t['singleTask'] == tab).toList();
          for (final t in tasksForTab) {
            final taskId = t['historyTaskId'].toString();

            final rowsList = List<dynamic>.from(t['rowsData'] ?? []);
            final firstRow = rowsList.isNotEmpty ? Map<String, dynamic>.from(rowsList.first) : <String, dynamic>{};
            final noOfRows = int.tryParse((firstRow['no_of_rows'] ?? rowsList.length).toString()) ?? rowsList.length;

            rowCounts[taskId] = noOfRows;

            for (int ri = 0; ri < rowsList.length; ri++) {
              final rItem = rowsList[ri];
              final taskKey = '${taskId}_row_$ri';
              
              editableSubmitDates[taskKey] = _formatDateForDisplay(rItem['submit_date']);
              editableTaskDescs[taskKey] = rItem['task_description'] ?? t['singleTask'];
              taskComments[taskKey] = rItem['comment'] ?? '';
              taskTotalDurations[taskKey] = Duration(seconds: rItem['duration_secs'] ?? 0);
              
              final st = (rItem['status'] ?? '').toString().toUpperCase();

              if (st == 'COMPLETED') {
                taskStatus[taskKey] = TaskStatus.completed;
              } else if (st == 'REJECTED') {
                taskStatus[taskKey] = TaskStatus.rejected;
              } else {
                taskStatus[taskKey] = TaskStatus.idle;
              }

              if (rItem['start_time'] != null && rItem['start_time'].toString().isNotEmpty) {
                try { taskStartTimes[taskKey] = DateTime.parse(rItem['start_time']).toLocal(); } catch (_) {}
              }

              final holds = <DateTime>[];
              for (int slot = 1; slot <= 10; slot++) {
                final v = rItem['hold_time_$slot'];
                if (v != null && v.toString().isNotEmpty) {
                  try { holds.add(DateTime.parse(v).toLocal()); } catch (_) {}
                }
              }
              if (holds.isNotEmpty) taskHoldTimes[taskKey] = holds;

              final restarts = <DateTime>[];
              for (int slot = 1; slot <= 10; slot++) {
                final v = rItem['restart_time_$slot'];
                if (v != null && v.toString().isNotEmpty) {
                  try { restarts.add(DateTime.parse(v).toLocal()); } catch (_) {}
                }
              }
              if (restarts.isNotEmpty) taskRestartTimes[taskKey] = restarts;

              if (rItem['complete_time'] != null && rItem['complete_time'].toString().isNotEmpty) {
                try { taskCompletedTimes[taskKey] = [DateTime.parse(rItem['complete_time']).toLocal()]; } catch (_) {}
              }

              if (rItem['reject_time'] != null && rItem['reject_time'].toString().isNotEmpty) {
                try { taskRejectedTimes[taskKey] = [DateTime.parse(rItem['reject_time']).toLocal()]; } catch (_) {}
              }
            }
          }
        }

        setState(() {
          completedTasks = processed;
          taskTabNames = allTabs.toList();
          if (taskTabNames.isNotEmpty && selectedTabIndex == null) selectedTabIndex = 0;
          _loadingTasks = false;
        });
      } else {
        setState(() { _error = 'Failed to load history'; _loadingTasks = false; });
      }
    } catch (e) {
      setState(() { _error = 'Error: $e'; _loadingTasks = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(38, 30, 38, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pageHeader(),
          const SizedBox(height: 28),
          _clientSearchBox(),
          const SizedBox(height: 20),
          _taskCategoryTabs(),
          const SizedBox(height: 20),
          if (_loadingTasks)
            const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 60), child: CircularProgressIndicator()))
          else if (_error != null)
            Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
          else if (selectedTabIndex != null && completedTasks.isNotEmpty)
            _taskDetailsContainer()
          else
            const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 60), child: Text('No completed tasks in history yet', style: TextStyle(color: AppColors.textGrey)))),
        ],
      ),
    );
  }

  Widget _pageHeader() {
    return Row(
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Task History', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textDark)),
            SizedBox(height: 6),
            Text('View all your successfully completed tasks and performance records.', style: TextStyle(fontSize: 14, color: AppColors.textGrey)),
          ],
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: _fetchCompletedHistory,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004AAD), foregroundColor: Colors.white),
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text("Refresh", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10),
        OutlinedButton(
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('employeeMenu', 'Assigned Task');
            if (!mounted) return;
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const EmployeeLayoutPage()));
          },
          child: const Text('← Back to Assigned Tasks', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _clientSearchBox() {
    return Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFCBD5E1)), borderRadius: BorderRadius.circular(6)),
      child: Row(children: [
        const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
        const SizedBox(width: 10),
        Expanded(
          child: Autocomplete<String>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) return _assignedClientNames;
              return _assignedClientNames.where((c) => c.toLowerCase().contains(textEditingValue.text.toLowerCase()));
            },
            onSelected: (String selected) {
              setState(() {
                _selectedClientFilter = selected;
                final visible = _visibleTabIndices;
                if (visible.isNotEmpty && !visible.contains(selectedTabIndex)) {
                  selectedTabIndex = visible.first;
                }
              });
            },
            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
              _clientSearchFieldController = controller;
              return TextField(
                controller: controller,
                focusNode: focusNode,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: 'Search client name...'),
              );
            },
          ),
        ),
        if (_selectedClientFilter != null)
          GestureDetector(
            onTap: () {
              setState(() => _selectedClientFilter = null);
              _clientSearchFieldController?.clear();
            },
            child: const Icon(Icons.close, size: 16, color: Color(0xFF94A3B8)),
          ),
      ]),
    );
  }

  // 🟢 Custom Slanted Tabs Layout matching assigned tasks page reference style
  Widget _taskCategoryTabs() {
    if (taskTabNames.isEmpty) {
      return Container(
        width: double.infinity,
        height: 72,
        color: const Color(0xFFF8FAFD),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        child: const Text(
          'No task categories assigned',
          style: TextStyle(
            color: AppColors.textGrey,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    const Color blue = Color(0xFF0057B8);
    const Color inactive = Color(0xFFE9EEF5);
    const Color inactiveText = Color(0xFF43536A);

    return Container(
      width: double.infinity,
      color: const Color(0xFFF8FAFD),
      padding: const EdgeInsets.only(
        left: 0,
        right: 12,
        top: 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 58,
            child: Listener(
              onPointerSignal: (pointerSignal) {
                if (pointerSignal is PointerScrollEvent) {
                  final offset = _horizontalController.offset + pointerSignal.scrollDelta.dy;
                  if (offset >= 0 && offset <= _horizontalController.position.maxScrollExtent) {
                    _horizontalController.jumpTo(offset);
                  }
                }
              },
              child: SingleChildScrollView(
                controller: _horizontalController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (int i = 0; i < _visibleTabIndices.length; i++)
                      _buildTaskCategoryTab(
                        tabIndex: _visibleTabIndices[i],
                        isSelected: selectedTabIndex == _visibleTabIndices[i],
                        blue: blue,
                        inactive: inactive,
                        inactiveText: inactiveText,
                      ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            height: 4,
            width: double.infinity,
            decoration: BoxDecoration(
              color: blue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(
            height: 14,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                height: 5,
                width: 90,
                decoration: BoxDecoration(
                  color: blue.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 38,
                    height: 5,
                    decoration: BoxDecoration(
                      color: blue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCategoryTab({
    required int tabIndex,
    required bool isSelected,
    required Color blue,
    required Color inactive,
    required Color inactiveText,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedTabIndex = tabIndex;
        });
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: ClipPath(
          clipper: _TaskTabClipper(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: isSelected ? 58 : 56,
            constraints: const BoxConstraints(
              minWidth: 160,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
            ),
            decoration: BoxDecoration(
              color: isSelected ? blue : inactive,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: blue.withValues(alpha: 0.25),
                        blurRadius: 12,
                        spreadRadius: 1,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              taskTabNames[tabIndex],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : inactiveText,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getRowStatusText(TaskStatus status) {
    switch (status) {
      case TaskStatus.completed:
        return 'COMPLETED';
      case TaskStatus.rejected:
        return 'REJECTED';
      case TaskStatus.running:
      case TaskStatus.held:
      case TaskStatus.idle:
        return 'PENDING';
    }
  }

  Widget _taskDetailsContainer() {
    if (selectedTabIndex == null ||
        selectedTabIndex! >= taskTabNames.length) {
      return const SizedBox.shrink();
    }

    final tabName = taskTabNames[selectedTabIndex!];

    var tasksForTab = completedTasks
        .where((t) => t['singleTask'] == tabName)
        .toList();

    if (_selectedClientFilter != null &&
        _selectedClientFilter!.isNotEmpty) {
      tasksForTab = tasksForTab
          .where(
            (t) =>
                (t['client_name'] ?? '').toString() ==
                _selectedClientFilter,
          )
          .toList();
    }

    if (tasksForTab.isEmpty) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(
          horizontal: 28,
          vertical: 16,
        ),
        padding: const EdgeInsets.symmetric(
          vertical: 40,
          horizontal: 20,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history_rounded,
                size: 25,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'No history found',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No completed records available for $tabName.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: tasksForTab.map((task) {
        final taskId = task['historyTaskId'].toString();
        final isExpand = expandedTaskId == taskId;

        final clientName = (task['client_name'] ?? 'N/A').toString();
        final deliverable = (task['singleTask'] ?? '').toString();
        final submitDate = _formatDateForDisplay(task['assignedDate']?.toString());

        return Column(
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.025),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 🟢 CLIENT NAME CONTAINER WITH BLUE BACKGROUND (Color(0xFF004AAD))
                  Expanded(
                    flex: 3,
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF004AAD),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.business_outlined, size: 15, color: Colors.white),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('CLIENT', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8), letterSpacing: 0.7)),
                                const SizedBox(height: 2),
                                Text(clientName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 14),

                  // DELIVERABLE
                  Expanded(
                    flex: 3,
                    child: _taskInfoBlock(
                      icon: Icons.layers_outlined,
                      label: 'DELIVERABLES',
                      value: deliverable.isEmpty ? 'N/A' : deliverable,
                    ),
                  ),

                  const SizedBox(width: 14),

                  // SUBMIT DATE
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF475569)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('SUBMIT DATE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5)),
                              const SizedBox(height: 3),
                              Text(submitDate, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 14),

                  // OPEN / HIDE
                  SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          expandedTaskId = isExpand ? null : taskId;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isExpand ? const Color(0xFFFEF2F2) : const Color(0xFFE8F1FF),
                        foregroundColor: isExpand ? const Color(0xFFDC2626) : const Color(0xFF004AAD),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 17),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: isExpand ? const Color(0xFFFECACA) : const Color(0xFFBFDBFE)),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(isExpand ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 17),
                          const SizedBox(width: 4),
                          Text(isExpand ? 'HIDE' : 'OPEN', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (isExpand)
              _buildTaskTable(task, taskId),
          ],
        );
      }).toList(),
    );
  }

  Widget _taskInfoBlock({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(
              icon,
              size: 15,
              color: const Color(0xFF475569),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
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

  Widget _buildTaskTable(Map<String, dynamic> task, String taskId) {
    final rowCount = rowCounts[taskId] ?? 1;
    return Scrollbar(
      controller: _horizontalController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _horizontalController,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: totalTableWidth,
          child: Column(
            children: [
              Container(
                height: 45, width: totalTableWidth, color: const Color(0xFFF1F5F9),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const Row(children: [
                  SizedBox(width: snoWidth, child: Text("S.NO", style: _headerStyle, textAlign: TextAlign.center)),
                  SizedBox(width: submitDateWidth, child: Text("DATE", style: _headerStyle, textAlign: TextAlign.center)),
                  SizedBox(width: taskWidth, child: Text("TASK DESC", style: _headerStyle)),
                  SizedBox(width: actionWidth, child: Text("ACTION", style: _headerStyle)),
                  SizedBox(width: durationWidth, child: Text("DURATION", style: _headerStyle, textAlign: TextAlign.center)),
                  SizedBox(width: commentWidth, child: Text("COMMENT", style: _headerStyle, textAlign: TextAlign.center)),
                  SizedBox(width: performanceWidth, child: Text("PERFORMANCE", style: _headerStyle, textAlign: TextAlign.center)),
                  SizedBox(width: statusWidth, child: Text("STATUS", style: _headerStyle, textAlign: TextAlign.center)),
                ]),
              ),
              for (int i = 0; i < rowCount; i++) _buildRow(i, task, taskId),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(int index, Map<String, dynamic> task, String taskId) {
    final taskKey = '${taskId}_row_$index';
    final editDate = editableSubmitDates[taskKey] ?? '--';
    final rowsData = List<dynamic>.from(task['rowsData'] ?? []);

    final rowData = index < rowsData.length ? Map<String, dynamic>.from(rowsData[index]) : <String, dynamic>{};
    final actualSno = rowData['s_no'] ?? index + 1;
    final editDesc = editableTaskDescs[taskKey] ?? task['singleTask'] ?? 'N/A';
    final savedComment = taskComments[taskKey] ?? '';
    final totalDur = taskTotalDurations[taskKey] ?? Duration.zero;
    final perf = _calculatePerformance(task['singleTask'] ?? '', totalDur);
    final perfColor = _getPerformanceColor(perf);
    final curStatus = taskStatus[taskKey] ?? TaskStatus.idle;

    bool hasStarted = taskStartTimes[taskKey] != null;
    bool hasHeld = (taskHoldTimes[taskKey] ?? []).isNotEmpty;
    bool hasRestarted = (taskRestartTimes[taskKey] ?? []).isNotEmpty;
    bool isCompleted = curStatus == TaskStatus.completed;
    bool isRejected = curStatus == TaskStatus.rejected;

    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Row(children: [
        SizedBox(
          width: snoWidth,
          child: Text(
            actualSno.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(width: submitDateWidth, child: Text(editDate, style: const TextStyle(fontSize: 11, color: Color(0xFF004AAD)))),
        SizedBox(width: taskWidth, child: Text(editDesc, style: const TextStyle(fontSize: 11))),
        
        SizedBox(width: actionWidth,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _viewBtn("START", hasStarted ? Colors.blue.shade900 : Colors.grey.shade200, hasStarted ? Colors.white : Colors.grey),
                const SizedBox(width: 4),
                if (hasStarted)
                  Text('S: ${formatTime(taskStartTimes[taskKey])}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
                const SizedBox(width: 12),

                _viewBtn("HOLD", hasHeld ? Colors.grey.shade700 : Colors.grey.shade200, hasHeld ? Colors.white : Colors.grey),
                const SizedBox(width: 4),
                if (hasHeld)
                  ...taskHoldTimes[taskKey]!.map((h) => Text('${formatTime(h)} ', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey))),
                const SizedBox(width: 12),

                _viewBtn("RESTART", hasRestarted ? Colors.orange.shade800 : Colors.grey.shade200, hasRestarted ? Colors.white : Colors.grey),
                const SizedBox(width: 4),
                if (hasRestarted)
                  ...taskRestartTimes[taskKey]!.map((r) => Text('R: ${formatTime(r)} ', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange))),
                const SizedBox(width: 12),

                _viewBtn("COMPLETED", isCompleted ? Colors.green.shade700 : Colors.grey.shade200, isCompleted ? Colors.white : Colors.grey),
                const SizedBox(width: 4),
                if (isCompleted && (taskCompletedTimes[taskKey] ?? []).isNotEmpty)
                  Text('C: ${formatTime(taskCompletedTimes[taskKey]!.first)}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF00812B))),
                const SizedBox(width: 12),

                _viewBtn("REJECTED", isRejected ? Colors.red.shade700 : Colors.grey.shade200, isRejected ? Colors.white : Colors.grey),
                const SizedBox(width: 4),
                if (isRejected && (taskRejectedTimes[taskKey] ?? []).isNotEmpty)
                  Text('Rj: ${formatTime(taskRejectedTimes[taskKey]!.first)}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFC40000))),
              ],
            ),
          ),
        ),

        SizedBox(width: durationWidth, child: Text(formatDuration(totalDur), textAlign: TextAlign.left, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF004AAD)))),
        SizedBox(width: commentWidth, height: cellHeight, child: Container(alignment: Alignment.centerLeft, child: Text(savedComment.isEmpty ? '-' : savedComment, style: const TextStyle(fontSize: 10)))),
        SizedBox(width: performanceWidth, height: 40, child: Container(alignment: Alignment.center, child: Text(perf, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: perfColor)))),
        SizedBox(width: statusWidth, child: Text(_statusString(curStatus), textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _statusColor(curStatus)))),
      ]),
    );
  }

  Widget _viewBtn(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: fg.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 9)),
    );
  }

  String formatTime(DateTime? dt) {
    if (dt == null) return '--:--:--';
    return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}:${dt.second.toString().padLeft(2,'0')}';
  }

  String formatDuration(Duration? d) {
    if (d == null) return '--:--:--';
    return '${d.inHours.toString().padLeft(2,'0')}:${d.inMinutes.remainder(60).toString().padLeft(2,'0')}:${d.inSeconds.remainder(60).toString().padLeft(2,'0')}';
  }

  String _statusString(TaskStatus s) {
    switch (s) {
      case TaskStatus.completed:
        return 'COMPLETED';
      case TaskStatus.rejected:
        return 'REJECTED';
      case TaskStatus.running:
      case TaskStatus.held:
      case TaskStatus.idle:
        return 'PENDING';
    }
  }

  Color _statusColor(TaskStatus s) {
    switch (s) {
      case TaskStatus.completed:
        return const Color(0xFF00812B);
      case TaskStatus.rejected:
        return const Color(0xFFC40000);
      case TaskStatus.running:
      case TaskStatus.held:
      case TaskStatus.idle:
        return const Color(0xFFD97706);
    }
  }

  String _formatDateForDisplay(String? raw) {
    if (raw == null || raw.isEmpty) return '--';
    try {
      final date = DateTime.parse(raw);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      return raw;
    }
  }
}

// 🟢 Slanted Tab Shape Clipper
class _TaskTabClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const double slant = 18.0;

    final Path path = Path();

    path.moveTo(0, size.height);
    path.lineTo(slant, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width - slant, size.height);

    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant _TaskTabClipper oldClipper) {
    return false;
  }
}

const TextStyle _headerStyle = TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF172554));