import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:godigital_portal/core/constants/app_colors.dart';
import 'package:godigital_portal/core/constants/employee_role.dart';
import 'package:godigital_portal/services/auth_service.dart';
import '../../services/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'employee_layout_page.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

enum TaskStatus { idle, running, held, completed, rejected }

class AssignedTasksContent extends StatefulWidget {
  final EmployeeRole role;
  const AssignedTasksContent({super.key, required this.role});

  @override
  State<AssignedTasksContent> createState() => _AssignedTasksContentState();
}

class _AssignedTasksContentState extends State<AssignedTasksContent> with WidgetsBindingObserver {
  // static const String _baseUrl = '/api';
  static String get _baseUrl => ApiConfig.baseUrl;

  static const double snoWidth         = 50;
  static const double submitDateWidth  = 120;
  static const double taskWidth        = 150;
  static const double actionWidth      = 600;
  static const double durationWidth    = 100;
  static const double commentWidth     = 140;
  static const double performanceWidth = 100;
  static const double statusWidth      = 100;
  static const double cellHeight       = 55;

  double get totalTableWidth =>
      snoWidth + submitDateWidth + taskWidth + actionWidth +
      durationWidth + commentWidth + performanceWidth + statusWidth + 100;

  final ScrollController _horizontalController = ScrollController();

  List<Map<String, dynamic>> assignedTasks = [];
  List<String>               taskTabNames  = [];
  final List<Map<String, dynamic>> additionalTasks = [];

  Map<String, int> expectedTimingMinutes = {};
  Map<String, int> taskListIds = {};              // taskId -> task_list.id
  Map<String, int> trackingItemIds = {};          // taskKey -> time_tracking_task_items.id
  Map<String, String> taskListDurations = {};     // taskId -> task_list.duration (resolved from task_timings)

  Map<String, dynamic> _parseTaskWithCount(String raw) {
    final trimmed = raw.trim();
    final match = RegExp(r'^(.*?)\s*\((\d+)\)\s*$').firstMatch(trimmed);
    if (match != null) {
      final name = match.group(1)!.trim();
      final count = int.tryParse(match.group(2)!) ?? 1;
      return {'name': name.isEmpty ? trimmed : name, 'count': count};
    }
    return {'name': trimmed, 'count': 1};
  }

  bool showAdditionalTask = false;
  bool showTimeTracker    = false;
  bool _isSaving          = false;
  bool _loadingTasks      = true;
  String? expandedTaskId;
  int? selectedTabIndex;
   String? _selectedClientFilter;
  // final TextEditingController _clientSearchController = TextEditingController();
  TextEditingController? _clientSearchFieldController;
  String? _error;
  late IO.Socket socket;

  String clientName      = '';
  String deliverableName = '';
  String durationValue   = '';
  String submissionDate  = '';

  List<String> get _assignedClientNames {
    final names = assignedTasks
        .map((t) => (t['client_name'] ?? '').toString())
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();
    names.sort();
    return names;
  }

  // FIX: only tabs that actually have a task for the filtered client (or
  // all tabs, when nothing is filtered) show up. Kept as full-list INDICES
  // (not a separately-ordered list) so selectedTabIndex still correctly
  // points into taskTabNames everywhere else in this file.
  // 🟢 Hides tabs completely if all tasks/rows under that deliverable tab are completed or rejected
  // List<int> get _visibleTabIndices {
  //   final indices = <int>[];
    
  //   for (int i = 0; i < taskTabNames.length; i++) {
  //     final tabName = taskTabNames[i];
      
  //     // Check if this tab has ANY task with at least one active (non-completed/non-rejected) row
  //     bool hasActiveTaskForTab = false;
      
  //     final tasksForThisTab = assignedTasks.where((t) => t['singleTask'] == tabName).toList();
  //     for (var task in tasksForThisTab) {
  //       if (_selectedClientFilter != null && _selectedClientFilter!.isNotEmpty) {
  //         if ((task['client_name'] ?? '').toString() != _selectedClientFilter) continue;
  //       }

  //       final taskId = _taskIdFor(task);
  //       final rowCount = rowCounts[taskId] != null ? rowCounts[taskId]! : (task['rowCount'] ?? 1);

  //       for (int r = 0; r < rowCount; r++) {
  //         final taskKey = '${taskId}_row_$r';
  //         final status = taskStatus[taskKey] ?? TaskStatus.idle;

  //         if (status != TaskStatus.completed && status != TaskStatus.rejected) {
  //           hasActiveTaskForTab = true;
  //           break;
  //         }
  //       }
  //       if (hasActiveTaskForTab) break;
  //     }

  //     // If active tasks exist, include this tab index
  //     if (hasActiveTaskForTab) {
  //       indices.add(i);
  //     }
  //   }
    
  //   return indices;
  // }


List<int> get _visibleTabIndices {
    final indices = <int>[];
    
    for (int i = 0; i < taskTabNames.length; i++) {
      final tabName = taskTabNames[i];
      bool hasActiveTaskForTab = false;
      
      final tasksForThisTab = assignedTasks.where((t) => t['singleTask'] == tabName).toList();
      for (var task in tasksForThisTab) {
        if (_selectedClientFilter != null && _selectedClientFilter!.isNotEmpty) {
          if ((task['client_name'] ?? '').toString() != _selectedClientFilter) continue;
        }

        final taskId = _taskIdFor(task);
        final rowCount = rowCounts[taskId] != null ? rowCounts[taskId]! : (task['rowCount'] ?? 1);

        // 🟢 Check if submit date is still valid (not yet passed)
        final rawDeadline = task['deadline'] ?? '';
        final parsedDate = _parseFlexibleDate(rawDeadline);
        bool isDateValid = false;
        
        if (parsedDate != null) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final target = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
          if (target.compareTo(today) >= 0) {
            isDateValid = true; // Submit date innum mudiyala!
          }
        }

        // Oru vela submit date innum mudiyala na, yella rows complete aayirunthalum tab hide aagathu
        if (isDateValid) {
          hasActiveTaskForTab = true;
          break;
        }

        // Normal check: If any row is NOT completed/rejected
        for (int r = 0; r < rowCount; r++) {
          final taskKey = '${taskId}_row_$r';
          final status = taskStatus[taskKey] ?? TaskStatus.idle;

          if (status != TaskStatus.completed && status != TaskStatus.rejected) {
            hasActiveTaskForTab = true;
            break;
          }
        }
        if (hasActiveTaskForTab) break;
      }

      if (hasActiveTaskForTab) {
        indices.add(i);
      }
    }
    
    return indices;
  }


  // ── All state maps keyed by taskKey = '{taskId}_row_{rowIndex}' ───────────
  Map<String, String>   taskComments            = {};
  Map<String, DateTime> taskStartTimes          = {};
  Map<String, DateTime> taskCurrentSessionStart = {};
  Map<String, Timer>    taskTimers              = {};
  Map<String, Duration> taskDurations           = {};
  Map<String, Duration> taskTotalDurations      = {};
  Map<String, TaskStatus> taskStatus            = {};

  Map<String, String> editableSubmitDates = {};
  Map<String, String> editableTaskDescs   = {};
  Map<String, int>    rowCounts           = {};

  Map<String, List<DateTime>> taskHoldTimes      = {};
  Map<String, List<DateTime>> taskRestartTimes   = {};
  Map<String, List<DateTime>> taskCompletedTimes = {};
  Map<String, List<DateTime>> taskRejectedTimes  = {};

  final Map<String, Map<String, dynamic>> _rowContext = {};
  // Track saved DB ids so we can PUT instead of POST on updates
  Map<String, int> savedTrackerIds = {};

  String? currentRunningTaskKey;
  String? _employeeName;
  // FIX: cache the logged-in employee's id once, resolved from whichever key
  // AuthService actually exposes, so task_list.employee_id is reliably saved.
  dynamic _employeeId;

 @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 🟢 Page load aagum pothu session-ai mark pannurom
    try {
      html.window.sessionStorage['is_page_refreshed'] = 'true';
    } catch (_) {}

    // 🟢 Window close listener with Refresh Protection
    html.window.onBeforeUnload.listen((event) {
      // Refresh pannum pothu sessionStorage irukkum, athnaala antha time-la hold aagathu.
      // Aana true-ah browser/tab close pannum pothu matum hold aagum.
      try {
        final isRefreshed = html.window.sessionStorage['is_page_refreshed'];
        if (isRefreshed == 'true') {
          // Temporarily remove or bypass so refresh won't hold, 
          // but since beforeunload triggers on close, we check if it's an actual close.
          html.window.sessionStorage.remove('is_page_refreshed');
          return; 
        }
      } catch (_) {}

      if (currentRunningTaskKey != null) {
        final prevKey = currentRunningTaskKey!;
        final ctx = _rowContext[prevKey];
        if (ctx != null) {
          _handleHold(
            prevKey,
            ctx['task'] as Map<String, dynamic>,
            ctx['rowIndex'] as int,
            ctx['taskId'] as String,
          );
        }
      }
    });

    _resolveLoggedInEmployee();
    _fetchTimingData();
    _fetchEmployeeAssignedTasks();
    _initSocketListener();
  }

  
  // void _initSocketListener() {
  //   socket = IO.io(
  //     ApiConfig.socketUrl,
  //     IO.OptionBuilder()
  //         .setTransports(['websocket'])
  //         .enableForceNew()
  //         .disableAutoConnect()
  //         .build(),
  //   );

  //   socket.connect();

  //   socket.on('task_updated', (data) {
  //    if (mounted) {
  //       _fetchEmployeeAssignedTasks(); // Auto refresh tasks when assigned by admin!
  //     }
  //   });
  // }
  

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
    print("🔥 task_updated received: $data");

    if (!mounted) return;

    if (data is Map &&
        data['type'] == 'TRACKING_ITEM_UPDATE') {
      print("⏭️ Tracking action update - keeping current tab/task");
      return;
    }

    _fetchEmployeeAssignedTasks();
  });
}

   @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    socket.dispose();
    _horizontalController.dispose();
    for (final t in taskTimers.values) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only trigger hold on absolute detachment, preventing accidental pause/refresh state jumps
    if (state == AppLifecycleState.detached) {
      _holdActiveTaskOnAppClose();
    }
    super.didChangeAppLifecycleState(state);
  }

Future<void> _holdActiveTaskOnAppClose() async {
    if (currentRunningTaskKey != null) {
      final prevKey = currentRunningTaskKey!;
      final ctx = _rowContext[prevKey];
      if (ctx != null) {
        await _handleHold(
          prevKey,
          ctx['task'] as Map<String, dynamic>,
          ctx['rowIndex'] as int,
          ctx['taskId'] as String,
        );
      }
    }
  }
 

  // FIX: centralised employee resolution — tries the common key variants so a
  // schema/key rename in AuthService.user doesn't silently null out employeeId.
  void _resolveLoggedInEmployee() {
    final user = context.read<AuthService>().user;
    _employeeName = (user?['fullName'] ?? user?['name'] ?? '') as String? ?? '';
    _employeeId = user?['id'] ?? user?['employeeId'] ?? user?['employee_id'] ?? user?['userId'];
  }

  // ── FIX: single source of truth for building a taskId. Every place that
  // used to do '${client_name}_${singleTask}_$i' (with i computed differently
  // in different functions) now calls this instead, so the same task always
  // maps to the same taskId everywhere in the widget. ─────────────────────
  String _taskIdFor(Map<String, dynamic> task) {
    final tab = task['singleTask'] as String? ?? '';
    final tasksForTab = assignedTasks.where((t) => t['singleTask'] == tab).toList();
    // Prefer matching on the unique taskAssignmentId when available — this is
    // the only field that reliably disambiguates two rows that share the same
    // client_name + singleTask (e.g. the same client assigned "GMB" twice).
    final idx = task['taskAssignmentId'] != null
        ? tasksForTab.indexWhere((t) => t['taskAssignmentId'] == task['taskAssignmentId'])
        : tasksForTab.indexWhere((t) => t['client_name'] == task['client_name']);
    final safeIdx = idx < 0 ? 0 : idx;
    return '${task['client_name']}_${task['singleTask']}_$safeIdx';
  }

  // ── FETCH TIMING ──────────────────────────────────────────────────────────
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

  List<String> _splitTasks(String s) =>
      s.isEmpty ? [] : s.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

  // ── FETCH ASSIGNED TASKS then load saved tracker data ─────────────────────
  Future<void> _fetchEmployeeAssignedTasks() async {
    setState(() { _loadingTasks = true; _error = null; });
    try {
      _resolveLoggedInEmployee();

      if (_employeeName == null || _employeeName!.isEmpty) {
        setState(() { _error = 'Employee name not found. Please re-login.'; _loadingTasks = false; });
        return;
      }

      // final r = await http.get(Uri.parse('$_baseUrl/employee-tasks/by-employee/$_employeeName'));

final r = await http.get(
  Uri.parse('$_baseUrl/employee-tasks/by-employee/$_employeeName')
);

print(r.body);

      if (r.statusCode == 200) {
        final data = List<dynamic>.from(jsonDecode(r.body)['data'] ?? []);
        final allTabs   = <String>{};
        final processed = <Map<String, dynamic>>[];
        final nameUpper = _employeeName!.toUpperCase();

        for (var task in data) {
          final m = Map<String, dynamic>.from(task);

          // void addRole(String? colVal, String tasksCol, String submitCol, String role, String typeLabel) {
          //   if (colVal == null || colVal.toUpperCase() != nameUpper) return;
          //   for (var st in _splitTasks(m[tasksCol]?.toString() ?? '')) {
          //     final parsed    = _parseTaskWithCount(st);
          //     final taskName  = parsed['name'] as String;
          //     final taskCount = parsed['count'] as int;

          //     allTabs.add(taskName);
          //     processed.add({
          //       'client_name':      m['client_name'],
          //       'deliverables':     m['deliverables'],
          //       'deadline':         m['deadline'],
          //       'assignedRole':     role,
          //       'singleTask':       taskName,
          //       'rowCount':         taskCount,
          //       'assignedDate':     m[submitCol],
          //       'taskType':         typeLabel,
          //       'taskAssignmentId': m['id'],
          //     });
          //   }
          // }

          // addRole(m['designer'],       'designer_tasks',    'designer_submit_date',     'designer',    'Designer');
          // addRole(m['videographer'],   'videographer_tasks','videographer_submit_date', 'videographer','Videographer');
          // addRole(m['video_editor'],   'video_editor_task', 'video_editor_submit_date', 'video_editor','Video Editor');
          // addRole(m['ads_handling'],   'ads_platform',      'ads_submit_date',          'ads',         'Ads Handler');
          // addRole(m['page_handling'],  'pages_platform',    'page_submit_date',         'page',        'Page Handler');
          // addRole(m['ui_ux_designer'], 'ui_ux_tasks',       'ui_ux_submit_date',        'uiux',        'UI/UX Designer');
          // addRole(m['developer'],      'developer_task',    'developer_submit_date',    'developer',   'Developer');
        void addDesignerTasks() {
            if (m['designer'] == null || m['designer'].toString().toUpperCase() != nameUpper) return;
            for (var st in _splitTasks(m['designer_tasks']?.toString() ?? '')) {
              final parsed = _parseTaskWithCount(st);
              allTabs.add(parsed['name'] as String);
              processed.add({
                'client_name':      m['client_name'],
                'deliverables':     m['deliverables'],
                'deadline':         m['deadline'],
                'assignedRole':     'designer',
                'singleTask':       parsed['name'] as String,
                'rowCount':         parsed['count'] as int,
                'assignedDate':     m['deadline'],   
                'taskType':         'Designer',
                'taskAssignmentId': m['id'],
              });
            }
          }

          void addVideographerTasks() {
            if (m['videographer'] == null || m['videographer'].toString().toUpperCase() != nameUpper) return;
            for (var st in _splitTasks(m['videographer_tasks']?.toString() ?? '')) {
              final parsed = _parseTaskWithCount(st);
              allTabs.add(parsed['name'] as String);
              processed.add({
                'client_name':      m['client_name'],
                'deliverables':     m['deliverables'],
                'deadline':         m['deadline'],
                'assignedRole':     'videographer',
                'singleTask':       parsed['name'] as String,
                'rowCount':         parsed['count'] as int,
                'assignedDate':     m['deadline'],
                'taskType':         'Videographer',
                'taskAssignmentId': m['id'],
              });
            }
          }

          void addVideoEditorTasks() {
            if (m['video_editor'] == null || m['video_editor'].toString().toUpperCase() != nameUpper) return;
            for (var st in _splitTasks(m['video_editor_task']?.toString() ?? '')) {
              final parsed = _parseTaskWithCount(st);
              allTabs.add(parsed['name'] as String);
              processed.add({
                'client_name':      m['client_name'],
                'deliverables':     m['deliverables'],
                'deadline':         m['deadline'],
                'assignedRole':     'video_editor',
                'singleTask':       parsed['name'] as String,
                'rowCount':         parsed['count'] as int,
                'assignedDate':     m['deadline'],
                'taskType':         'Video Editor',
                'taskAssignmentId': m['id'],
              });
            }
          }

          void addAdsHandlingTasks() {
            if (m['ads_handling'] == null || m['ads_handling'].toString().toUpperCase() != nameUpper) return;
            for (var st in _splitTasks(m['ads_platform']?.toString() ?? '')) {
              final parsed = _parseTaskWithCount(st);
              allTabs.add(parsed['name'] as String);
              processed.add({
                'client_name':      m['client_name'],
                'deliverables':     m['deliverables'],
                'deadline':         m['deadline'],
                'assignedRole':     'ads',
                'singleTask':       parsed['name'] as String,
                'rowCount':         parsed['count'] as int,
                'assignedDate':     m['deadline'],
                'taskType':         'Ads Handler',
                'taskAssignmentId': m['id'],
              });
            }
          }

          void addPageHandlingTasks() {
            if (m['page_handling'] == null || m['page_handling'].toString().toUpperCase() != nameUpper) return;
            for (var st in _splitTasks(m['pages_platform']?.toString() ?? '')) {
              final parsed = _parseTaskWithCount(st);
              allTabs.add(parsed['name'] as String);
              processed.add({
                'client_name':      m['client_name'],
                'deliverables':     m['deliverables'],
                'deadline':         m['deadline'],
                'assignedRole':     'page',
                'singleTask':       parsed['name'] as String,
                'rowCount':         parsed['count'] as int,
                'assignedDate':     m['deadline'],
                'taskType':         'Page Handler',
                'taskAssignmentId': m['id'],
              });
            }
          }

          void addUiUxTasks() {
            if (m['ui_ux_designer'] == null || m['ui_ux_designer'].toString().toUpperCase() != nameUpper) return;
            for (var st in _splitTasks(m['ui_ux_tasks']?.toString() ?? '')) {
              final parsed = _parseTaskWithCount(st);
              allTabs.add(parsed['name'] as String);
              processed.add({
                'client_name':      m['client_name'],
                'deliverables':     m['deliverables'],
                'deadline':         m['deadline'],
                'assignedRole':     'uiux',
                'singleTask':       parsed['name'] as String,
                'rowCount':         parsed['count'] as int,
                'assignedDate':     m['deadline'],
                'taskType':         'UI/UX Designer',
                'taskAssignmentId': m['id'],
              });
            }
          }

          void addDeveloperTasks() {
            if (m['developer'] == null || m['developer'].toString().toUpperCase() != nameUpper) return;
            for (var st in _splitTasks(m['developer_tasks']?.toString() ?? '')) {
              final parsed = _parseTaskWithCount(st);
              allTabs.add(parsed['name'] as String);
              processed.add({
                'client_name':      m['client_name'],
                'deliverables':     m['deliverables'],
                'deadline':         m['deadline'],
                'assignedRole':     'developer',
                'singleTask':       parsed['name'] as String,
                'rowCount':         parsed['count'] as int,
                'assignedDate':     m['deadline'],
                'taskType':         'Developer',
                'taskAssignmentId': m['id'],
              });
            }
          }

          void addWebsiteDesignerTasks() {
            if (m['website_designer'] == null || m['website_designer'].toString().toUpperCase() != nameUpper) return;
            for (var st in _splitTasks(m['website_designer_tasks']?.toString() ?? '')) {
              final parsed = _parseTaskWithCount(st);
              allTabs.add(parsed['name'] as String);
              processed.add({
                'client_name':      m['client_name'],
                'deliverables':     m['deliverables'],
                'deadline':         m['deadline'],
                'assignedRole':     'website_designer_task',
                'singleTask':       parsed['name'] as String,
                'rowCount':         parsed['count'] as int,
                'assignedDate':     m['deadline'],
                'taskType':         'Website Designer',
                'taskAssignmentId': m['id'],
              });
            }
          }

          addDesignerTasks();
          addVideographerTasks();
          addVideoEditorTasks();
          addAdsHandlingTasks();
          addPageHandlingTasks();
          addUiUxTasks();
          addDeveloperTasks();
          addWebsiteDesignerTasks();
        
        }

        // seed rowCounts using the SAME scheme as _taskIdFor (index within the
        // tab, matched by taskAssignmentId first, client_name as fallback)
        for (final tab in allTabs) {
          final tasksForTab = processed.where((t) => t['singleTask'] == tab).toList();
          for (int i = 0; i < tasksForTab.length; i++) {
            final t = tasksForTab[i];
            final taskId = '${t['client_name']}_${t['singleTask']}_$i';
            rowCounts.putIfAbsent(taskId, () => (t['rowCount'] as int?) ?? 1);
          }
        }

        final oldTabIndex = selectedTabIndex;

setState(() {
  assignedTasks = processed;
  taskTabNames = allTabs.toList();

  if (taskTabNames.isNotEmpty) {
    if (oldTabIndex != null &&
        oldTabIndex >= 0 &&
        oldTabIndex < taskTabNames.length) {
      selectedTabIndex = oldTabIndex;
    } else {
      selectedTabIndex = 0;
    }
  }

  _loadingTasks = false;
});
        await Future.delayed(const Duration(milliseconds: 100));

        // ── Pull real duration + no_of_rows from task_list for every task ────
        await _prefetchTaskListData();

        // ── After loading tasks, restore saved tracker data ─────────────────
        await _loadSavedTrackerData();

      } else {
        setState(() { _error = 'Failed to load tasks (${r.statusCode})'; _loadingTasks = false; });
      }
    } catch (e) {
      setState(() { _error = 'Connection error: $e'; _loadingTasks = false; });
    }
  }

 Future<void> _loadSavedTrackerData() async {
    if (_employeeName == null || _employeeName!.isEmpty) return;

    try {
      final r = await http.get(
        Uri.parse('$_baseUrl/employee-tasks/tracker?employee=$_employeeName'),
      );

      if (r.statusCode != 200) return;

      final response = jsonDecode(r.body);
      final savedRows = List<dynamic>.from(response['data'] ?? []);

      setState(() {
        for (var saved in savedRows) {
          final clientName        = saved['client_name']  as String? ?? '';
          final singleTask        = saved['single_task']   as String? ?? '';
          final rowIndex          = saved['row_index']      as int? ?? 0;
          final savedAssignmentId = saved['task_assignment_id'];

          final tasksForClient = assignedTasks
              .where((t) => t['singleTask'] == singleTask &&
                  (savedAssignmentId != null
                      ? t['taskAssignmentId'] == savedAssignmentId
                      : t['client_name'] == clientName))
              .toList();
          if (tasksForClient.isEmpty) continue;

          final matchedTask = tasksForClient.first;
          final taskId  = _taskIdFor(matchedTask);
          final taskKey = '${taskId}_row_$rowIndex';

          if (saved['id'] != null) {
            savedTrackerIds[taskKey] = saved['id'] as int;
          }

          final current = rowCounts[taskId] ?? 1;
          if (rowIndex + 1 > current) {
            rowCounts[taskId] = rowIndex + 1;
          }

          final submitDate = saved['submit_date'] as String? ?? '';
          if (submitDate.isNotEmpty) {
            editableSubmitDates[taskKey] = _formatDateForDisplay(submitDate);
          }

          final taskDesc = saved['task_description'] as String? ?? '';
          if (taskDesc.isNotEmpty) {
            editableTaskDescs[taskKey] = taskDesc;
          }

          final comment = saved['comment'] as String? ?? '';
          if (comment.isNotEmpty) {
            taskComments[taskKey] = comment;
          }

          final statusStr = saved['status'] as String? ?? 'IDLE';
          taskStatus[taskKey] = _statusFromString(statusStr);

          final totalSecs = saved['total_duration_secs'] as int? ?? 0;
          if (totalSecs > 0) {
            taskTotalDurations[taskKey] = Duration(seconds: totalSecs);
          }

          final startTimeStr = saved['start_time'] as String?;
          if (startTimeStr != null && startTimeStr.isNotEmpty) {
            try { taskStartTimes[taskKey] = DateTime.parse(startTimeStr).toLocal(); } catch (_) {}
          }

          final holdTimesJson = saved['hold_times'] as String? ?? '[]';
          try {
            final List holdList = jsonDecode(holdTimesJson);
            taskHoldTimes[taskKey] = holdList.map((t) => DateTime.parse(t as String).toLocal()).toList();
          } catch (_) {}

          final restartTimesJson = saved['restart_times'] as String? ?? '[]';
          try {
            final List restartList = jsonDecode(restartTimesJson);
            taskRestartTimes[taskKey] = restartList.map((t) => DateTime.parse(t as String).toLocal()).toList();
          } catch (_) {}

          final completedTimeStr = saved['completed_time'] as String?;
          if (completedTimeStr != null && completedTimeStr.isNotEmpty) {
            try { taskCompletedTimes[taskKey] = [DateTime.parse(completedTimeStr).toLocal()]; } catch (_) {}
          }

          final rejectedTimeStr = saved['rejected_time'] as String?;
          if (rejectedTimeStr != null && rejectedTimeStr.isNotEmpty) {
            try { taskRejectedTimes[taskKey] = [DateTime.parse(rejectedTimeStr).toLocal()]; } catch (_) {}
          }
        }
      });

      // 🟢 CRITICAL SYNC: tracker data load aana piragum, database task_list no_of_rows-ai eppovum munnurimai thandu retain panrom
      await _prefetchTaskListData();

      await _restoreLastExpandedTask();

    } catch (e) {
      debugPrint('❌ Error loading saved tracker data: $e');
    }
  }

Future<void> _restoreLastExpandedTask() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTabIdx = prefs.getInt('last_selected_tab');
    final savedExpandedId = prefs.getString('last_expanded_task');

    setState(() {
      if (savedTabIdx != null && savedTabIdx < taskTabNames.length) {
        selectedTabIndex = savedTabIdx;
      }

      if (savedExpandedId != null) {
        for (final tab in taskTabNames) {
          final tasksForTab = assignedTasks.where((t) => t['singleTask'] == tab).toList();
          for (int i = 0; i < tasksForTab.length; i++) {
            final t = tasksForTab[i];
            final tid = '${t['client_name']}_${t['singleTask']}_$i';
            if (tid == savedExpandedId) {
              expandedTaskId = savedExpandedId;
              selectedTabIndex = taskTabNames.indexOf(tab);
              // Ensure tracking data for this specific restored task is loaded immediately
              _ensureTaskListEntry(t, tid);
              break;
            }
          }
        }
      }
    });
  }

  TaskStatus _statusFromString(String s) {
    switch (s.toUpperCase()) {
      case 'IN PROGRESS': return TaskStatus.running;
      case 'ON HOLD':     return TaskStatus.held;
      case 'COMPLETED':   return TaskStatus.completed;
      case 'REJECTED':    return TaskStatus.rejected;
      default:            return TaskStatus.idle;
    }
  }

  // ── Prefetch task_list rows for ALL assigned tasks ─────────────────────
 // ── Prefetch task_list rows and strictly respect database no_of_rows without any reduction ─────────────────────
 // ── Prefetch task_list rows and strictly lock database no_of_rows ─────────────────────
  Future<void> _prefetchTaskListData() async {
    final Map<String, int> fetchedTaskListIds = {};
    final Map<String, String> fetchedTaskListDurations = {};
    final Map<String, int> fetchedRowCounts = {};

    for (final tab in taskTabNames) {
      final tasksForTab = assignedTasks.where((t) => t['singleTask'] == tab).toList();
      
      for (int i = 0; i < tasksForTab.length; i++) {
        final task = tasksForTab[i];
        final taskAssignmentId = task['taskAssignmentId'];
        final deliverables = task['singleTask'] as String?;

        if (taskAssignmentId == null || deliverables == null) continue;

        final taskId = '${task['client_name']}_${task['singleTask']}_$i';

        try {
          // 1. Ensure find-or-create runs
          await http.post(
            Uri.parse('$_baseUrl/task-list/find-or-create'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'taskAssignmentId': taskAssignmentId,
              'clientName': task['client_name'],
              'deliverables': deliverables,
              'submissionDate': task['assignedDate'],
              // 'noOfRows': rowCounts[taskId] ?? 1,
              'employeeName': _employeeName,
            }),
          );

          // 2. Fetch latest task list row from DB
          final r = await http.get(
            Uri.parse('$_baseUrl/task-list/by-assignment/$taskAssignmentId/${Uri.encodeComponent(deliverables)}'),
          );
          
          if (r.statusCode == 200) {
            final body = jsonDecode(r.body);
            final data = body['data'];
            if (data != null) {
              if (data['id'] != null) {
                fetchedTaskListIds[taskId] = data['id'] as int;
              }
              if (data['duration'] != null) {
                fetchedTaskListDurations[taskId] = data['duration'] as String;
              }
              
              // 🟢 CRITICAL FIX: Database-il irukkira exact 'no_of_rows'-ai direct-ah eduthu lock panrom. 
              // Oru podhum antha count reduce aagakudathu, history-la plus pannalum inga exact-ah reflect aaganum.
              if (data['no_of_rows'] != null) {
                final dbRows = int.tryParse(data['no_of_rows'].toString()) ?? 1;
                final currentLocal = rowCounts[taskId] ?? 1;
                // Eppovum max value-ai mattum select panrom so it never drops back
                fetchedRowCounts[taskId] = dbRows > currentLocal ? dbRows : currentLocal;
              }
            }
          }
        } catch (e) {
          debugPrint('❌ _prefetchTaskListData error for $taskId: $e');
        }
      }
    }

    if (mounted) {
      setState(() {
        taskListIds.addAll(fetchedTaskListIds);
        taskListDurations.addAll(fetchedTaskListDurations);
        rowCounts.addAll(fetchedRowCounts);
      });
    }
  }
  Future<void> _autoSaveRow(String taskKey, Map<String, dynamic> task, int rowIndex, String taskId) async {
    if (_employeeName == null) return;

    final taskListId = taskListIds[taskId];
    if (taskListId == null) {
      debugPrint('⚠️ _autoSaveRow skipped — task_list row not created yet for $taskId');
      return;
    }
debugPrint("================================");
debugPrint("taskKey : $taskKey");
debugPrint("assignedDate : ${task['assignedDate']}");
debugPrint("editableSubmitDate : ${editableSubmitDates[taskKey]}");
debugPrint("================================");

    final status = taskStatus[taskKey] ?? TaskStatus.idle;
    final total  = taskTotalDurations[taskKey];
    final perf   = _calculatePerformance(task['singleTask'] ?? '', total);



    final payload = {
      'taskListId': taskListId,
      'taskTimingId': null,
      'sNo': rowIndex + 1,
      // 'submitDate': editableSubmitDates[taskKey] ?? task['assignedDate'],
      'submitDate': editableSubmitDates[taskKey] ?? _formatDateForDatabase(task['assignedDate']),
      'taskDescription': editableTaskDescs[taskKey] ?? task['singleTask'] ?? '',
      'durationSecs': (taskTotalDurations[taskKey] ?? Duration.zero).inSeconds,
      'comment': taskComments[taskKey] ?? '',
      'performance': perf,
      'status': _statusString(status),
    };
    debugPrint("PAYLOAD submitDate => ${payload['submitDate']}");
debugPrint("SUBMIT DATE = ${payload['submitDate']}");
    try {
      final r = await http.post(
        Uri.parse('$_baseUrl/tracking-items'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (r.statusCode == 200 || r.statusCode == 201) {
        final body = jsonDecode(r.body);
        if (body['data'] != null && body['data']['id'] != null) {
          setState(() {
            trackingItemIds[taskKey] = body['data']['id'] as int;
          });
        }
        debugPrint('✅ Auto-saved: $taskKey (tracking item id=${trackingItemIds[taskKey]})');
      } else {
        debugPrint('❌ Auto-save failed (${r.statusCode}): ${r.body}');
      }
    } catch (e) {
      debugPrint('❌ Auto-save error: $e');
    }
  }

// ── MANUAL SAVE ALL (Safely handles all active and newly added rows) ────────
  Future<void> _saveAll() async {
    if (_employeeName == null) return;
    setState(() => _isSaving = true);

    try {
      final allRows = <Map<String, dynamic>>[];

      for (int ti = 0; ti < taskTabNames.length; ti++) {
        final tabName = taskTabNames[ti];
        final tasksForTab = assignedTasks.where((t) => t['singleTask'] == tabName).toList();

        for (int i = 0; i < tasksForTab.length; i++) {
          final task   = tasksForTab[i];
          final taskId = '${task['client_name']}_${task['singleTask']}_$i';
          final rows   = rowCounts[taskId] ?? 1;

          for (int ri = 0; ri < rows; ri++) {
            final taskKey = '${taskId}_row_$ri';
            
            // 🟢 Ensure every row (even newly added ones from history) has a valid default payload if not initialized yet
            if (!taskStatus.containsKey(taskKey)) {
              taskStatus[taskKey] = TaskStatus.idle;
            }
            
            allRows.add(_buildPayload(taskKey, task, ri));
          }
        }
      }

      if (allRows.isEmpty) {
        _showSnack('Nothing to save yet.', success: false);
        return;
      }

      final r = await http.post(
        Uri.parse('$_baseUrl/employee-tasks/tracker/save-all'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'rows': allRows}),
      );

      final body = jsonDecode(r.body);
      if (r.statusCode == 200) {
        _showSnack('✅ ${body['message']}', success: true);
        await _loadSavedTrackerData();
        await _prefetchTaskListData(); // Refresh row counts and task list mappings
      } else {
        _showSnack('❌ Save failed: ${body['message']}', success: false);
      }
    } catch (e) {
      _showSnack('❌ Error: $e', success: false);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Map<String, dynamic> _buildPayload(String taskKey, Map<String, dynamic> task, int rowIndex) {
    final status = taskStatus[taskKey] ?? TaskStatus.idle;
    final total  = taskTotalDurations[taskKey];
    final perf   = _calculatePerformance(task['singleTask'] ?? '', total);

    return {
      'employeeName':      _employeeName,
      'employeeId':        _employeeId,
      'clientName':        task['client_name'] ?? '',
      'singleTask':        task['singleTask']  ?? '',
      'taskType':          task['taskType']    ?? '',
      'assignedRole':      task['assignedRole'] ?? '',
      'rowIndex':          rowIndex,
      'submitDate':        editableSubmitDates[taskKey] ?? task['assignedDate'] ?? '',
      'taskDescription':   editableTaskDescs[taskKey]   ?? task['singleTask']   ?? '',
      'startTime':         taskStartTimes[taskKey]?.toIso8601String(),
      'holdTimes':         jsonEncode((taskHoldTimes[taskKey]    ?? []).map((d) => d.toIso8601String()).toList()),
      'restartTimes':      jsonEncode((taskRestartTimes[taskKey] ?? []).map((d) => d.toIso8601String()).toList()),
      'completedTime':     (taskCompletedTimes[taskKey] ?? []).isNotEmpty
                               ? taskCompletedTimes[taskKey]!.first.toIso8601String() : null,
      'rejectedTime':      (taskRejectedTimes[taskKey]  ?? []).isNotEmpty
                               ? taskRejectedTimes[taskKey]!.first.toIso8601String()  : null,
      'totalDurationSecs': (taskTotalDurations[taskKey] ?? Duration.zero).inSeconds,
      'status':            _statusString(status),
      'performance':       perf,
      'comment':           taskComments[taskKey] ?? '',
      'isAdditional':      false,
      'taskAssignmentId':  task['taskAssignmentId'],
    };
  }

  String _statusString(TaskStatus s) {
    switch (s) {
      case TaskStatus.running:   return 'IN PROGRESS';
      case TaskStatus.held:      return 'ON HOLD';
      case TaskStatus.completed: return 'COMPLETED';
      case TaskStatus.rejected:  return 'REJECTED';
      default:                   return 'IDLE';
    }
  }

  void _showSnack(String msg, {required bool success}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? const Color(0xFF00812B) : Colors.redAccent,
      duration: const Duration(seconds: 2),
    ));
  }

  // ── ACTION HANDLERS ─────────────────────────────────────────────────────
  // FIX: all handlers now take taskId explicitly (passed straight through
  // from _buildRow, which already knows it) instead of recomputing it later
  // inside _autoSaveRow / _recordTaskAction. This removes the duplicate-index
  // ambiguity that could route a Start/Hold/Complete click's save to the
  // wrong task_list row.

  // Future<void> _handleStart(String taskKey, Map<String, dynamic> task, int rowIndex, String taskId) async {
  //   // if (currentRunningTaskKey != null && currentRunningTaskKey != taskKey) {
  //   //   // Note: we don't have that other row's task/taskId handy here; holding
  //   //   // it just stops its timer bookkeeping locally without an extra network
  //   //   // call, since its own Hold button remains available to the user.
  //   //   taskTimers[currentRunningTaskKey]?.cancel();
  //   // }
  //     if (currentRunningTaskKey != null && currentRunningTaskKey != taskKey) {
  //     await _autoHoldRunningTask(taskKey);
  //   }
  //   setState(() {
  //     taskStatus[taskKey]              = TaskStatus.running;
  //     taskStartTimes[taskKey]          = DateTime.now();
  //     taskCurrentSessionStart[taskKey] = DateTime.now();
  //     taskDurations[taskKey]           = Duration.zero;
  //     currentRunningTaskKey            = taskKey;
  //     taskTimers[taskKey] = Timer.periodic(const Duration(seconds: 1), (_) {
  //       if (mounted) {
  //         setState(() {
  //         taskDurations[taskKey] =
  //             DateTime.now().difference(taskCurrentSessionStart[taskKey]!);
  //       });
  //       }
  //     });
  //   });
  //   await _autoHoldRunningTask(taskKey);
  //   setState(() {
  //     taskStatus[taskKey] = TaskStatus.running;
  //   });
  //   await _autoSaveRow(taskKey, task, rowIndex, taskId);
  //   await _recordTaskAction(taskKey, task, rowIndex, taskId, 'start');
  // }

  // Future<void> _handleHold(String taskKey, Map<String, dynamic> task, int rowIndex, String taskId) async {
  //   setState(() {
  //     taskStatus[taskKey] = TaskStatus.held;
  //     (taskHoldTimes[taskKey] ??= []).add(DateTime.now());
  //     taskTotalDurations[taskKey] =
  //         (taskTotalDurations[taskKey] ?? Duration.zero) + (taskDurations[taskKey] ?? Duration.zero);
  //     taskTimers[taskKey]?.cancel();
  //     taskTimers.remove(taskKey);
  //     taskCurrentSessionStart.remove(taskKey);
  //     taskDurations[taskKey] = Duration.zero;
  //     currentRunningTaskKey  = null;
  //   });
  //   await _autoSaveRow(taskKey, task, rowIndex, taskId);
  //   await _recordTaskAction(taskKey, task, rowIndex, taskId, 'hold');
  // }

  // Future<void> _handleRestart(String taskKey, Map<String, dynamic> task, int rowIndex, String taskId) async {
  //     if (currentRunningTaskKey != null && currentRunningTaskKey != taskKey) {
  //     await _autoHoldRunningTask(taskKey);
  //   }
  //   setState(() {
  //     taskStatus[taskKey] = TaskStatus.running;
  //     (taskRestartTimes[taskKey] ??= []).add(DateTime.now());
  //     taskCurrentSessionStart[taskKey] = DateTime.now();
  //     taskDurations[taskKey]           = Duration.zero;
  //     currentRunningTaskKey            = taskKey;
  //     taskTimers[taskKey] = Timer.periodic(const Duration(seconds: 1), (_) {
  //       if (mounted) {
  //         setState(() {
  //         taskDurations[taskKey] =
  //             DateTime.now().difference(taskCurrentSessionStart[taskKey]!);
  //       });
  //       }
  //     });
  //   });
  //    await _autoHoldRunningTask(taskKey);
  //   setState(() {
  //     taskStatus[taskKey] = TaskStatus.running;
  //   });
  //   await _autoSaveRow(taskKey, task, rowIndex, taskId);
  //   await _recordTaskAction(taskKey, task, rowIndex, taskId, 'restart');
  // }

  // Future<void> _handleComplete(String taskKey, Map<String, dynamic> task, int rowIndex, String taskId) async {
  //   setState(() {
  //     taskStatus[taskKey] = TaskStatus.completed;
  //     (taskCompletedTimes[taskKey] ??= []).add(DateTime.now());
  //     taskTotalDurations[taskKey] =
  //         (taskTotalDurations[taskKey] ?? Duration.zero) + (taskDurations[taskKey] ?? Duration.zero);
  //     taskTimers[taskKey]?.cancel();
  //     taskTimers.remove(taskKey);
  //     taskCurrentSessionStart.remove(taskKey);
  //     taskDurations[taskKey] = Duration.zero;
  //     currentRunningTaskKey  = null;
  //   });
  //   await _autoSaveRow(taskKey, task, rowIndex, taskId);
  //   await _recordTaskAction(taskKey, task, rowIndex, taskId, 'complete');
  // }

  // Future<void> _handleReject(String taskKey, Map<String, dynamic> task, int rowIndex, String taskId) async {
  //   setState(() {
  //     taskStatus[taskKey] = TaskStatus.rejected;
  //     (taskRejectedTimes[taskKey] ??= []).add(DateTime.now());
  //     taskTotalDurations[taskKey] =
  //         (taskTotalDurations[taskKey] ?? Duration.zero) + (taskDurations[taskKey] ?? Duration.zero);
  //     taskTimers[taskKey]?.cancel();
  //     taskTimers.remove(taskKey);
  //     taskCurrentSessionStart.remove(taskKey);
  //     taskDurations[taskKey] = Duration.zero;
  //     currentRunningTaskKey  = null;
  //   });
  //   await _autoSaveRow(taskKey, task, rowIndex, taskId);
  //   await _recordTaskAction(taskKey, task, rowIndex, taskId, 'reject');
  // }


Future<void> _handleStart(String taskKey, Map<String, dynamic> task, int rowIndex, String taskId) async {
    if (currentRunningTaskKey != null && currentRunningTaskKey != taskKey) {
      await _autoHoldRunningTask(taskKey);
    }
    
    setState(() {
      taskStatus[taskKey]              = TaskStatus.running;
      taskStartTimes[taskKey]          = DateTime.now();
      taskCurrentSessionStart[taskKey] = DateTime.now();
      taskDurations[taskKey]           = Duration.zero;
      currentRunningTaskKey            = taskKey;
      
      taskTimers[taskKey] = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {
            taskDurations[taskKey] = DateTime.now().difference(taskCurrentSessionStart[taskKey]!);
          });
        }
      });
    });

    await _autoSaveRow(taskKey, task, rowIndex, taskId);
    await _recordTaskAction(taskKey, task, rowIndex, taskId, 'start');
  }

  Future<void> _handleHold(String taskKey, Map<String, dynamic> task, int rowIndex, String taskId) async {
    setState(() {
      taskStatus[taskKey] = TaskStatus.held;
      (taskHoldTimes[taskKey] ??= []).add(DateTime.now());
      taskTotalDurations[taskKey] =
          (taskTotalDurations[taskKey] ?? Duration.zero) + (taskDurations[taskKey] ?? Duration.zero);
      taskTimers[taskKey]?.cancel();
      taskTimers.remove(taskKey);
      taskCurrentSessionStart.remove(taskKey);
      taskDurations[taskKey] = Duration.zero;
      currentRunningTaskKey  = null;
    });
    
    await _autoSaveRow(taskKey, task, rowIndex, taskId);
    await _recordTaskAction(taskKey, task, rowIndex, taskId, 'hold');
  }

  Future<void> _handleRestart(String taskKey, Map<String, dynamic> task, int rowIndex, String taskId) async {
    if (currentRunningTaskKey != null && currentRunningTaskKey != taskKey) {
      await _autoHoldRunningTask(taskKey);
    }
    
    setState(() {
      taskStatus[taskKey] = TaskStatus.running;
      (taskRestartTimes[taskKey] ??= []).add(DateTime.now());
      taskCurrentSessionStart[taskKey] = DateTime.now();
      taskDurations[taskKey]           = Duration.zero;
      currentRunningTaskKey            = taskKey;
      
      taskTimers[taskKey] = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {
            taskDurations[taskKey] = DateTime.now().difference(taskCurrentSessionStart[taskKey]!);
          });
        }
      });
    });

    await _autoSaveRow(taskKey, task, rowIndex, taskId);
    await _recordTaskAction(taskKey, task, rowIndex, taskId, 'restart');
  }

  Future<void> _handleComplete(String taskKey, Map<String, dynamic> task, int rowIndex, String taskId) async {
    setState(() {
      taskStatus[taskKey] = TaskStatus.completed;
      (taskCompletedTimes[taskKey] ??= []).add(DateTime.now());
      taskTotalDurations[taskKey] =
          (taskTotalDurations[taskKey] ?? Duration.zero) + (taskDurations[taskKey] ?? Duration.zero);
      taskTimers[taskKey]?.cancel();
      taskTimers.remove(taskKey);
      taskCurrentSessionStart.remove(taskKey);
      taskDurations[taskKey] = Duration.zero;
      currentRunningTaskKey  = null;
    });
    
    await _autoSaveRow(taskKey, task, rowIndex, taskId);
    await _recordTaskAction(taskKey, task, rowIndex, taskId, 'complete');
  }

  Future<void> _handleReject(String taskKey, Map<String, dynamic> task, int rowIndex, String taskId) async {
    setState(() {
      taskStatus[taskKey] = TaskStatus.rejected;
      (taskRejectedTimes[taskKey] ??= []).add(DateTime.now());
      taskTotalDurations[taskKey] =
          (taskTotalDurations[taskKey] ?? Duration.zero) + (taskDurations[taskKey] ?? Duration.zero);
      taskTimers[taskKey]?.cancel();
      taskTimers.remove(taskKey);
      taskCurrentSessionStart.remove(taskKey);
      taskDurations[taskKey] = Duration.zero;
      currentRunningTaskKey  = null;
    });
    
    await _autoSaveRow(taskKey, task, rowIndex, taskId);
    await _recordTaskAction(taskKey, task, rowIndex, taskId, 'reject');
  }

  
  String formatTime(DateTime? dt) {
    if (dt == null) return '--:--:--';
    return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}:${dt.second.toString().padLeft(2,'0')}';
  }

  String formatDuration(Duration? d) {
    if (d == null) return '--:--:--';
    return '${d.inHours.toString().padLeft(2,'0')}:${d.inMinutes.remainder(60).toString().padLeft(2,'0')}:${d.inSeconds.remainder(60).toString().padLeft(2,'0')}';
  }

  String _formatExpectedDuration(int? mins) {
    if (mins == null) return 'N/A';
    if (mins < 60)   return '$mins mins';
    if (mins < 1440) {
      final h = mins ~/ 60; final m = mins % 60;
      return m == 0 ? '$h hr${h > 1 ? 's' : ''}' : '$h hr${h > 1 ? 's' : ''} $m mins';
    }
    final d = mins ~/ 1440;
    return '$d day${d > 1 ? 's' : ''}';
  }

 

 Future<void> _recordTaskAction(
      String taskKey, Map<String, dynamic> task, int rowIndex, String taskId, String action) async {
    final taskListId = taskListIds[taskId];
    final trackingItemId = trackingItemIds[taskKey];

    if (taskListId == null || trackingItemId == null) {
      debugPrint('⚠️ _recordTaskAction skipped ($action) — taskListId=$taskListId trackingItemId=$trackingItemId');
      return;
    }

    final validActions = {'start', 'hold', 'restart', 'complete', 'reject'};
    if (!validActions.contains(action)) return;

    final body = <String, dynamic>{};
    if (action == 'complete') {
      final total = taskTotalDurations[taskKey];
      body['performance'] = _calculatePerformance(task['singleTask'] ?? '', total);
    }

    try {
      final r = await http.post(
        Uri.parse('$_baseUrl/tracking-items/$trackingItemId/$action'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (r.statusCode == 200) {
        debugPrint('✅ action recorded: $action for $taskKey');
        // Do NOT call _loadTrackingItemsForTask here, as local states are already 
        // updated optimistically and instantly by individual _handleX methods.
      } else {
        debugPrint('❌ action failed ($action, ${r.statusCode}): ${r.body}');
      }
    } catch (e) {
      debugPrint('❌ action error ($action): $e');
    }
  }
  
  void _clearLocalStateForTask(String taskId) {
    final prefix = '${taskId}_row_';
    final allKeys = <String>{
      ...taskStatus.keys,
      ...taskStartTimes.keys,
      ...taskCurrentSessionStart.keys,
      ...taskDurations.keys,
      ...taskTotalDurations.keys,
      ...editableSubmitDates.keys,
      ...editableTaskDescs.keys,
      ...taskComments.keys,
      ...taskHoldTimes.keys,
      ...taskRestartTimes.keys,
      ...taskCompletedTimes.keys,
      ...taskRejectedTimes.keys,
      ...trackingItemIds.keys,
    }.where((k) => k.startsWith(prefix)).toList();

    for (final key in allKeys) {
      taskTimers[key]?.cancel();
      taskTimers.remove(key);
      taskStatus.remove(key);
      taskStartTimes.remove(key);
      taskCurrentSessionStart.remove(key);
      taskDurations.remove(key);
      taskTotalDurations.remove(key);
      editableSubmitDates.remove(key);
      editableTaskDescs.remove(key);
      taskComments.remove(key);
      taskHoldTimes.remove(key);
      taskRestartTimes.remove(key);
      taskCompletedTimes.remove(key);
      taskRejectedTimes.remove(key);
      trackingItemIds.remove(key);
    }
    if (currentRunningTaskKey != null && currentRunningTaskKey!.startsWith(prefix)) {
      currentRunningTaskKey = null;
    }
  }

  // ── ensures a task_list row exists, then ALWAYS pulls fresh tracking items
  // FIX: previously this returned early ("already resolved") whenever
  // taskListIds already had an entry, which meant tracking items were only
  // ever fetched once per session — stale even after the DB was truncated.
  // Now it only skips the find-or-create network call when cached, but
  // always clears local state and re-fetches tracking items fresh.
  Future<void> _ensureTaskListEntry(Map<String, dynamic> task, String taskId) async {
    int? taskListId = taskListIds[taskId];

    if (taskListId == null) {
      final taskAssignmentId = task['taskAssignmentId'];
      if (taskAssignmentId == null) return;

      final expMins = expectedTimingMinutes[(task['singleTask'] as String).trim().toLowerCase()];
      final durationString = expMins != null ? _formatExpectedDuration(expMins) : null;

      try {
        _resolveLoggedInEmployee();

        final r = await http.post(
          Uri.parse('$_baseUrl/task-list/find-or-create'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'taskAssignmentId': taskAssignmentId,
            'taskMasterId': null,
            'taskTimingId': null,
            'clientName': task['client_name'] ?? '',
            'deliverables': task['singleTask'] ?? '',
            'duration': durationString,
            'submissionDate': task['assignedDate'],
            'noOfRows': rowCounts[taskId] ?? (task['rowCount'] as int?) ?? 1,
            'employeeId': _employeeId,
            'employeeName': _employeeName,
          }),
        );

        if (r.statusCode == 200 || r.statusCode == 201) {
          final body = jsonDecode(r.body);
          final data = body['data'];
          if (data != null && data['id'] != null) {
            taskListId = data['id'] as int;
            setState(() {
              taskListIds[taskId] = taskListId!;
              if (data['no_of_rows'] != null) {
                rowCounts[taskId] = data['no_of_rows'] as int;
              }
            });
          }
        } else {
          debugPrint('❌ find-or-create failed (${r.statusCode}): ${r.body}');
          return;
        }
      } catch (e) {
        debugPrint('❌ _ensureTaskListEntry error: $e');
        return;
      }
    }

    if (taskListId != null) {
      setState(() => _clearLocalStateForTask(taskId));
      await _loadTrackingItemsForTask(taskId, taskListId, task);
    }
  }

// 🟢 Calculate how many rows are completed for this specific task
  int _getCompletedRowsCount(String taskId) {
    final rowCount = rowCounts[taskId] ?? 1;
    int completed = 0;
    for (int i = 0; i < rowCount; i++) {
      final taskKey = '${taskId}_row_$i';
      final status = taskStatus[taskKey] ?? TaskStatus.idle;
      if (status == TaskStatus.completed || status == TaskStatus.rejected) {
        completed++;
      }
    }
    return completed;
  }

 // 🟢 Helper to calculate completed count vs total rows for any specific task under a client
int _calculateTaskProgress(String clientName, String taskName) {
    int completed = 0;
    for (var entry in rowCounts.entries) {
      final key = entry.key; // e.g. 'Jeyasri Hostal_GMB-_0_row_0'
      if (key.startsWith(clientName) && key.contains(taskName)) {
        final status = taskStatus[key] ?? TaskStatus.idle;
        // Oru row completed illa rejected-na athu completed count-la count aagum
        if (status == TaskStatus.completed || status == TaskStatus.rejected) {
          completed++;
        }
      }
    }
    return completed;
  }


  // 🟢 Professional + User Friendly Client Task Summary Dialog
// 🟢 Professional Client Task Summary Dialog (With Direct Database Progress Sync for All Roles)
  void _showClientTaskSummaryDialog(
      Map<String, dynamic> task, String taskId) async {
    final clientName = task['client_name'] ?? 'N/A';

    List<Map<String, dynamic>> clientAssignments = [];
    Map<String, int> dbTaskProgressCounts = {}; // deliverableName -> completedCount

    try {
      // 1. Fetch all client assignments for summary
      final r = await http.get(Uri.parse('$_baseUrl/tasks'));
      if (r.statusCode == 200) {
        final body = jsonDecode(r.body);
        final allRows = List<Map<String, dynamic>>.from(body['data'] ?? []);

        clientAssignments = allRows.where((row) {
          return (row['client_name'] ?? '').toString().trim().toLowerCase() ==
              clientName.toString().trim().toLowerCase();
        }).toList();
      }

      // 2. Fetch real completed counts directly from database task-list & tracking-items for this client
      final trRes = await http.get(Uri.parse('$_baseUrl/task-list/client/${Uri.encodeComponent(clientName)}'));
      if (trRes.statusCode == 200) {
        final trBody = jsonDecode(trRes.body);
        final taskLists = List<dynamic>.from(trBody['data'] ?? []);

        for (var tl in taskLists) {
          final tListId = tl['id'];
          final deliverables = (tl['deliverables'] ?? '').toString().trim().toLowerCase();

          // Fetch tracking items for this task list entry
          final itemsRes = await http.get(Uri.parse('$_baseUrl/tracking-items/by-task-list/$tListId'));
          if (itemsRes.statusCode == 200) {
            final itemsBody = jsonDecode(itemsRes.body);
            final items = List<dynamic>.from(itemsBody['data'] ?? []);

            int completedRows = items.where((item) {
              final st = (item['status'] ?? '').toString().toUpperCase();
              return st == 'COMPLETED' || st == 'REJECTED';
            }).length;

            dbTaskProgressCounts[deliverables] = completedRows;
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching client assignments or progress for summary: $e');
    }

    if (!mounted) return;

    final roleMappings = [
      {
        'roleLabel': 'Ads Handler',
        'icon': Icons.campaign_outlined,
        'empField': 'ads_handling',
        'taskField': 'ads_platform',
      },
      {
        'roleLabel': 'Page Handler',
        'icon': Icons.pages_outlined,
        'empField': 'page_handling',
        'taskField': 'pages_platform',
      },
      {
        'roleLabel': 'Designer',
        'icon': Icons.design_services_outlined,
        'empField': 'designer',
        'taskField': 'designer_tasks',
      },
      {
        'roleLabel': 'Videographer',
        'icon': Icons.videocam_outlined,
        'empField': 'videographer',
        'taskField': 'videographer_tasks',
      },
      {
        'roleLabel': 'Video Editor',
        'icon': Icons.video_settings_outlined,
        'empField': 'video_editor',
        'taskField': 'video_editor_task',
      },
      {
        'roleLabel': 'UI/UX Designer',
        'icon': Icons.web_outlined,
        'empField': 'ui_ux_designer',
        'taskField': 'ui_ux_tasks',
      },
      {
        'roleLabel': 'Developer',
        'icon': Icons.code_outlined,
        'empField': 'developer',
        'taskField': 'developer_tasks',
      },
      {
        'roleLabel': 'Website Designer',
        'icon': Icons.language_outlined,
        'empField': 'website_designer',
        'taskField': 'website_designer_tasks',
      },
    ];

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) {
        return Dialog(
          backgroundColor: const Color(0xFFF8FAFC),
          elevation: 12,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 30,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 620,
              maxHeight: 700,
            ),
            child: Column(
              children: [
                // =========================================================
                // HEADER
                // =========================================================
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: Color(0xFFE5E7EB),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.analytics_outlined,
                          color: Color(0xFF004AAD),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Task Summary',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              clientName.toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 21,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),

                // =========================================================
                // BODY
                // =========================================================
                Expanded(
                  child: clientAssignments.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(30),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.assignment_outlined,
                                    size: 30,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'No assignments found',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                const Text(
                                  'There are no tasks assigned to this client yet.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Assigned Team',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'View employees and their current task progress.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ...roleMappings.map((roleInfo) {
                                final roleLabel = roleInfo['roleLabel'] as String;
                                final icon = roleInfo['icon'] as IconData;
                                final empField = roleInfo['empField'] as String;
                                final taskField = roleInfo['taskField'] as String;

                                final Map<String, List<String>> empTaskMap = {};

                                for (var assignment in clientAssignments) {
                                  final empName = (assignment[empField] ?? '').toString().trim();
                                  final taskStr = (assignment[taskField] ?? '').toString().trim();

                                  if (empName.isEmpty ||
                                      empName.toUpperCase() == 'NONE' ||
                                      taskStr.isEmpty) {
                                    continue;
                                  }

                                  final tasksList = taskStr
                                      .split(',')
                                      .map((t) => t.trim())
                                      .where((t) => t.isNotEmpty)
                                      .toList();

                                  empTaskMap.putIfAbsent(empName, () => []).addAll(tasksList);
                                }

                                if (empTaskMap.isEmpty) {
                                  return const SizedBox.shrink();
                                }

                                return Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(14, 13, 14, 11),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 34,
                                              height: 34,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEFF6FF),
                                                borderRadius: BorderRadius.circular(9),
                                              ),
                                              child: Icon(
                                                icon,
                                                size: 18,
                                                color: const Color(0xFF004AAD),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                roleLabel,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF0F172A),
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                '${empTaskMap.length} ${empTaskMap.length == 1 ? 'Employee' : 'Employees'}',
                                                style: const TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                      ...empTaskMap.entries.map((entry) {
                                        final employeeName = entry.key;
                                        final tasks = entry.value;

                                        return Padding(
                                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    width: 28,
                                                    height: 28,
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFF8FAFC),
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: const Color(0xFFE2E8F0),
                                                      ),
                                                    ),
                                                    child: const Icon(
                                                      Icons.person_outline,
                                                      size: 16,
                                                      color: Color(0xFF475569),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      employeeName,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w700,
                                                        color: Color(0xFF1E293B),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 9),
                                              Wrap(
                                                spacing: 7,
                                                runSpacing: 7,
                                                children: tasks.map((tClean) {
                                                  final parsed = _parseTaskWithCount(tClean);
                                                  final tName = parsed['name'] as String;
                                                  final totalR = parsed['count'] as int;

                                                  // 🟢 Get real completed count directly from database lookup or local fallback
                                                  int compR = dbTaskProgressCounts[tName.trim().toLowerCase()] ?? 0;
                                                  if (compR == 0) {
                                                    compR = _calculateTaskProgress(clientName, tName);
                                                  }

                                                  final isCompleted = totalR > 0 && compR >= totalR;
                                                  final progressText = '$compR/$totalR';

                                                  return Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                                    decoration: BoxDecoration(
                                                      color: isCompleted ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                                                      borderRadius: BorderRadius.circular(9),
                                                      border: Border.all(
                                                        color: isCompleted ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          isCompleted ? Icons.check_circle_outline : Icons.radio_button_unchecked,
                                                          size: 14,
                                                          color: isCompleted ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Flexible(
                                                          child: Text(
                                                            tName,
                                                            style: TextStyle(
                                                              fontSize: 10.5,
                                                              fontWeight: FontWeight.w600,
                                                              color: isCompleted ? const Color(0xFF166534) : const Color(0xFF475569),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: isCompleted ? const Color(0xFFDCFCE7) : const Color(0xFFE2E8F0),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            progressText,
                                                            style: TextStyle(
                                                              fontSize: 9,
                                                              fontWeight: FontWeight.w800,
                                                              color: isCompleted ? const Color(0xFF15803D) : const Color(0xFF64748B),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                ),

                // =========================================================
                // FOOTER
                // =========================================================
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                    border: Border(
                      top: BorderSide(
                        color: Color(0xFFE5E7EB),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 15,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Progress is updated from the assigned tasks.',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 36,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF004AAD),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                          child: const Text(
                            'Done',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _summaryRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF004AAD))),
        ),
      ],
    );
  }

  Future<void> _loadTrackingItemsForTask(String taskId, int taskListId, Map<String, dynamic> task) async {
    try {
      final r = await http.get(Uri.parse('$_baseUrl/tracking-items/by-task-list/$taskListId'));
      if (r.statusCode != 200) return;
      final body = jsonDecode(r.body);
      final rows = List<dynamic>.from(body['data'] ?? []);

      setState(() {
        for (final row in rows) {
          final sNo = row['s_no'] as int;
          final rowIndex = sNo - 1;
          final taskKey = '${taskId}_row_$rowIndex';

          trackingItemIds[taskKey] = row['id'] as int;

          // 🟢 Ippo antha task['deadline']-ai inga safe-ah use pannikalam
          final deadlineDate = task['deadline'] as String? ?? row['submit_date'] as String?;
          if (deadlineDate != null && deadlineDate.isNotEmpty) {
            editableSubmitDates[taskKey] = _formatDateForDisplay(deadlineDate);
          }

          final desc = row['task_description'] as String?;
          if (desc != null && desc.isNotEmpty) editableTaskDescs[taskKey] = desc;

          final comment = row['comment'] as String?;
          if (comment != null && comment.isNotEmpty) taskComments[taskKey] = comment;

          final status = row['status'] as String? ?? 'IDLE';
          taskStatus[taskKey] = _statusFromString(status);

          final durSecs = row['duration_secs'] as int? ?? 0;
          if (durSecs > 0) taskTotalDurations[taskKey] = Duration(seconds: durSecs);

          // FIX: if this row is still IN PROGRESS (e.g. the app was closed
          // and reopened, or the user navigated away and back mid-task),
          // the ticking timer was lost along with the old widget state.
          // Resume it here so the live "Running: HH:MM:SS" counter starts
          // moving again instead of staying frozen until the user manually
          // hits Hold then Restart.
          if (_statusFromString(status) == TaskStatus.running) {
            taskTimers[taskKey]?.cancel();
            taskCurrentSessionStart[taskKey] = DateTime.now();
            taskDurations[taskKey] = Duration.zero;
            currentRunningTaskKey = taskKey;
            taskTimers[taskKey] = Timer.periodic(const Duration(seconds: 1), (_) {
              if (mounted) {
                setState(() {
                taskDurations[taskKey] =
                    DateTime.now().difference(taskCurrentSessionStart[taskKey]!);
              });
              }
            });
          }

          // FIX: task_action table is gone — start/complete/reject and the
          // hold_time_1..10 / restart_time_1..10 slot columns now live
          // directly on this row, so parse them straight from here.
          final startTimeStr = row['start_time'] as String?;
          if (startTimeStr != null && startTimeStr.isNotEmpty) {
            try { taskStartTimes[taskKey] = DateTime.parse(startTimeStr).toLocal(); } catch (_) {}
          }

          final completeTimeStr = row['complete_time'] as String?;
          if (completeTimeStr != null && completeTimeStr.isNotEmpty) {
            try { taskCompletedTimes[taskKey] = [DateTime.parse(completeTimeStr).toLocal()]; } catch (_) {}
          }

          final rejectTimeStr = row['reject_time'] as String?;
          if (rejectTimeStr != null && rejectTimeStr.isNotEmpty) {
            try { taskRejectedTimes[taskKey] = [DateTime.parse(rejectTimeStr).toLocal()]; } catch (_) {}
          }

          final holds = <DateTime>[];
          for (int slot = 1; slot <= 10; slot++) {
            final v = row['hold_time_$slot'] as String?;
            if (v != null && v.isNotEmpty) {
              try { holds.add(DateTime.parse(v).toLocal()); } catch (_) {}
            }
          }
          if (holds.isNotEmpty) taskHoldTimes[taskKey] = holds;


          final restarts = <DateTime>[];
          for (int slot = 1; slot <= 10; slot++) {
            final v = row['restart_time_$slot'] as String?;
            if (v != null && v.isNotEmpty) {
              try { restarts.add(DateTime.parse(v).toLocal()); } catch (_) {}
            }
          }
          if (restarts.isNotEmpty) taskRestartTimes[taskKey] = restarts;
        }
      });
    } catch (e) {
      debugPrint('❌ _loadTrackingItemsForTask error: $e');
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(38, 30, 38, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pageHeader(),
          const SizedBox(height: 28),
          // if (showAdditionalTask)
          //   _additionalTaskSection()
           
            _clientSearchBox(),
            _taskCategoryTabs(),
            if (_loadingTasks)
            
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: CircularProgressIndicator(),
              ))
            else if (_error != null)
              Center(child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(children: [
                  Text(_error!, style: const TextStyle(color: AppColors.textGrey)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _fetchEmployeeAssignedTasks,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004AAD)),
                    child: const Text('Retry', style: TextStyle(color: Colors.white)),
                  ),
                ]),
              ))
            else if (selectedTabIndex != null && assignedTasks.isNotEmpty)
              _taskDetailsContainer()
            else
              Center(child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Text(
                  taskTabNames.isEmpty ? 'No tasks assigned yet' : 'No tasks for this category',
                  style: const TextStyle(color: AppColors.textGrey),
                ),
              )),
          
        
        ],
      ),
    );
  }

  // ── PAGE HEADER ───────────────────────────────────────────────────────────
  Widget _pageHeader() {
  return Row(
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Assigned Tasks',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Monitor and manage tasks assigned to you with real-time progress updates.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textGrey,
            ),
          ),
        ],
      ),

      const Spacer(),

      // 🟢 HISTORY BUTTON ADDED HERE
      OutlinedButton.icon(
        onPressed: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('employeeMenu', 'History');

          if (!mounted) return;

          // Switch to EmployeeLayoutPage so it loads the History page case
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const EmployeeLayoutPage(),
            ),
          );
        },
        icon: const Icon(Icons.history_rounded, size: 16, color: Color(0xFF004AAD)),
        label: const Text(
          'History',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF004AAD),
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF004AAD)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),

      const SizedBox(width: 10),

      // ElevatedButton.icon(
      //   onPressed: _isSaving ? null : _saveAll,
      //   icon: _isSaving
      //       ? const SizedBox(
      //           width: 14,
      //           height: 14,
      //           child: CircularProgressIndicator(
      //             strokeWidth: 2,
      //             color: Colors.white,
      //           ),
      //         )
      //       : const Icon(
      //           Icons.save_rounded,
      //           size: 16,
      //           color: Colors.white,
      //         ),
      //   label: Text(
      //     _isSaving ? 'Saving...' : 'Save',
      //     style: const TextStyle(
      //       fontSize: 11,
      //       fontWeight: FontWeight.w800,
      //       color: Colors.white,
      //     ),
      //   ),
      //   style: ElevatedButton.styleFrom(
      //     backgroundColor: const Color(0xFF00812B),
      //     padding: const EdgeInsets.symmetric(
      //       horizontal: 18,
      //       vertical: 14,
      //     ),
      //     shape: RoundedRectangleBorder(
      //       borderRadius: BorderRadius.circular(3),
      //     ),
      //   ),
      // ),

      // const SizedBox(width: 10),

// ElevatedButton(
//   onPressed: () async {
//     final result = await Navigator.push<bool>(
//       context,
//       MaterialPageRoute(
//         builder: (_) => AdditionalTasksPage(
//           role: widget.role,
//         ),
//       ),
//     );

//     if (result == true) {
//       await _fetchEmployeeAssignedTasks();
//     }
//   },

ElevatedButton(
  onPressed: () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('employeeMenu', 'Additional Task');

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const EmployeeLayoutPage(),
      ),
    );
  },
  
  style: ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFF004AAD),
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(
      horizontal: 22,
      vertical: 14,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(3),
    ),
  ),
  child: const Text(
    '+ Add Additional Task',
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
    ),
  ),
),
    ],
  );
}
  
  Widget _clientSearchBox() {
    return Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFCBD5E1)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(children: [
        const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
        const SizedBox(width: 10),
        Expanded(
          child: Autocomplete<String>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return _assignedClientNames;
              }
              return _assignedClientNames.where((c) =>
                  c.toLowerCase().contains(textEditingValue.text.toLowerCase()));
            },
            onSelected: (String selected) {
              setState(() {
                _selectedClientFilter = selected;
                // FIX: jump to the first tab that actually has data for
                // this client, instead of staying on a tab that just became
                // hidden (which was showing "No tasks for POSTER" even
                // though WEBSITE DESIGN had real data).
                final visible = _visibleTabIndices;
                if (visible.isNotEmpty && !visible.contains(selectedTabIndex)) {
                  selectedTabIndex = visible.first;
                }
              });
            },
            // fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            //   // Keep our own controller in sync so we can clear it externally
            //   controller.addListener(() {
            //     if (controller.text.isEmpty && _selectedClientFilter != null) {
            //       setState(() => _selectedClientFilter = null);
            //     }
            //   });
            //   return TextField(
            //     controller: controller,
            //     focusNode: focusNode,
            //     style: const TextStyle(fontSize: 13),
            //     decoration: const InputDecoration(
            //       isDense: true,
            //       border: InputBorder.none,
            //       hintText: 'Search client name...',
            //       hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            //     ),
            //   );
            // },

            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
              // FIX: this IS the controller Autocomplete actually renders —
              // save a reference so the external X button can clear it.
              // (The old _clientSearchController was a different, unrelated
              // controller that the visible TextField never used.)
              _clientSearchFieldController = controller;

              controller.addListener(() {
                if (controller.text.isEmpty && _selectedClientFilter != null) {
                  setState(() => _selectedClientFilter = null);
                }
              });
              return TextField(
                controller: controller,
                focusNode: focusNode,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Search client name...',
                  hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220, minWidth: 300),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options.elementAt(index);
                        return InkWell(
                          onTap: () => onSelected(option),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Text(option, style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
                          ),
                        );
                      },
                    ),
                  ),
                ),
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

  // ── TASK TABS ─────────────────────────────────────────────────────────────
  Widget _taskCategoryTabs() {
    if (taskTabNames.isEmpty) {
      return Container(height: 50, color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: const Center(child: Text('No task categories assigned',
            style: TextStyle(color: AppColors.textGrey))));
    }
    return Container(height: 60, color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        // child: Row(children: [
        //   for (int i = 0; i < taskTabNames.length; i++)
        //     InkWell(
        //       onTap: () => setState(() => selectedTabIndex = i),
        child: Row(children: [
          for (int i in _visibleTabIndices)
            InkWell(
              onTap: () => setState(() => selectedTabIndex = i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(
                  color: selectedTabIndex == i ? const Color(0xFF004AAD) : Colors.transparent,
                  width: selectedTabIndex == i ? 3 : 0,
                ))),
                child: Text(taskTabNames[i], style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: selectedTabIndex == i ? const Color(0xFF004AAD) : Colors.grey)),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _taskInfoBlock({
  required IconData icon,
  required String label,
  required String value,
  Color valueColor = const Color(0xFF334155),
}) {
  return Row(
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
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                color: Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),

            const SizedBox(height: 3),

            Text(
              value.isEmpty ? 'N/A' : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

// ── TASK DETAILS ──────────────────────────────────────────────────────────
// ── TASK DETAILS (Hides only when ALL rows are actually completed or rejected) ──
  Widget _taskDetailsContainer() {
    if (selectedTabIndex == null || selectedTabIndex! >= taskTabNames.length) {
      return const Center(child: Text('No task details available'));
    }

    final tabName = taskTabNames[selectedTabIndex!];
    
    // 🟢 Yella rows-um 'COMPLETED' (illa) 'REJECTED' aana piragu mattum thaan intha task card hide aagum.
    // Oru row pudhusa add aanaalum (athuvum innum complete aagavillai enral), intha card active list-lae thaan irukkum!
    var tasksForTab = assignedTasks.where((t) {
      if (t['singleTask'] != tabName) return false;
      
      final taskId = _taskIdFor(t);
      final rowCount = rowCounts[taskId] != null ? rowCounts[taskId]! : (t['rowCount'] ?? 1);
      
      // 🟢 Check if submit date is still valid (not yet passed)
      final rawDeadline = t['deadline'] ?? '';
      final parsedDate = _parseFlexibleDate(rawDeadline);
      bool isDateValid = false;
      
      if (parsedDate != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final target = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
        if (target.compareTo(today) >= 0) {
          isDateValid = true; // Submit date innum mudiyala, so card hide aagathu!
        }
      }

      if (isDateValid) {
        return true; // Keep card visible as long as the submit date is valid
      }
      
      // Normal check: Check if there is AT LEAST ONE row whose status is NOT completed and NOT rejected
      bool hasActiveRows = false;
      for (int i = 0; i < rowCount; i++) {
        final taskKey = '${taskId}_row_$i';
        final status = taskStatus[taskKey] ?? TaskStatus.idle;
        
        if (status != TaskStatus.completed && status != TaskStatus.rejected) {
          hasActiveRows = true;
          break;
        }
      }
      
      return hasActiveRows; 
    }).toList();
    // FIX: narrows the list to just the searched/selected client, if any.
    if (_selectedClientFilter != null && _selectedClientFilter!.isNotEmpty) {
      tasksForTab = tasksForTab
          .where((t) => (t['client_name'] ?? '').toString() == _selectedClientFilter)
          .toList();
    }

    if (tasksForTab.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: Text('No active tasks for this category', style: TextStyle(color: AppColors.textGrey)),
        ),
      );
    }

    return Column(children: tasksForTab.asMap().entries.map((entry) {
      final idx      = entry.key;
      final task     = entry.value;
      final taskId   = '${task['client_name']}_${task['singleTask']}_$idx';
      final isExpand = expandedTaskId == taskId;
      final expMins  = expectedTimingMinutes[(task['singleTask'] as String).trim().toLowerCase()];
      final currentRowsCount = rowCounts[taskId] ?? (task['rowCount'] as int?) ?? 1;

      return Column(children: [
        Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              
              // 1. CLIENT NAME BUTTON
              // Expanded(
              //   flex: 3,
              //   child: InkWell(
              //     onTap: () => _showClientTaskSummaryDialog(task, taskId),
              //     borderRadius: BorderRadius.circular(6),
              //     child: Container(
              //       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              //       decoration: BoxDecoration(
              //         color: const Color(0xFF0F172A),
              //         borderRadius: BorderRadius.circular(6),
              //         boxShadow: [
              //           BoxShadow(
              //             color: Colors.black.withValues(alpha: 0.08),
              //             blurRadius: 4,
              //             offset: const Offset(0, 2),
              //           ),
              //         ],
              //       ),
              //       child: Row(
              //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //         children: [
              //           Flexible(
              //             child: Row(
              //               children: [
              //                 Flexible(
              //                   child: Text(
              //                     task['client_name'] ?? 'N/A',
              //                     style: const TextStyle(
              //                       fontSize: 12,
              //                       fontWeight: FontWeight.w700,
              //                       color: Colors.white,
              //                       letterSpacing: 0.3,
              //                     ),
              //                     overflow: TextOverflow.ellipsis,
              //                   ),
              //                 ),
              //               ],
              //             ),
              //           ),
              //         ],
              //       ),
              //     ),
              //   ),
              // ),

Expanded(
  flex: 3,
  child: InkWell(
    onTap: () => _showClientTaskSummaryDialog(task, taskId),
    borderRadius: BorderRadius.circular(8),
    child: Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF004AAD), // Dark Theme Background
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF004AAD),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon Container
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.business_outlined,
              size: 15,
              color: Colors.white,
            ),
          ),

          const SizedBox(width: 9),

          // Client Label & Name
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CLIENT',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  task['client_name'] ?? 'N/A',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Summary / Chevron Right Icon
          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: Color(0xFF94A3B8),
          ),
        ],
      ),
    ),
  ),
),
              const SizedBox(width: 12),
              
              // 2. DELIVERABLES
              Expanded(
                flex: 3,
                child: _taskInfoBlock(
                  icon: Icons.layers_outlined,
                  label: 'DELIVERABLES',
                  value: task['singleTask'] ?? 'N/A',
                ),
              ),

              const SizedBox(width: 12),

              // 3. DURATION
              Expanded(
                flex: 2,
                child: _taskInfoBlock(
                  icon: Icons.schedule_outlined,
                  label: 'DURATION',
                  value: taskListDurations[taskId] ?? _formatExpectedDuration(expMins),
                  valueColor: (taskListDurations[taskId] != null || expMins != null)
                      ? const Color(0xFF0052CC)
                      : const Color(0xFF94A3B8),
                ),
              ),

              const SizedBox(width: 12),

              // 4. SUBMIT DATE
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
                      child: const Icon(
                        Icons.calendar_today_outlined,
                        size: 15,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'SUBMIT DATE',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          _dateWithDaysLeft(task['assignedDate']),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // 5. ROWS (Plus/Minus Controller)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('ROWS', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                    const SizedBox(width: 7),
                    
                    Container(
                      width: 34, height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Text(
                        '$currentRowsCount',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                    ),

                    const SizedBox(width: 5),
                    
                    // Plus Button
                    InkWell(
                      borderRadius: BorderRadius.circular(5),
                      onTap: () async {
                        final currentCount = rowCounts[taskId] ?? (task['rowCount'] as int?) ?? 1;
                        final newCount = currentCount + 1;
                        setState(() { rowCounts[taskId] = newCount; });

                        final taskListId = taskListIds[taskId];
                        if (taskListId != null) {
                          http.patch(
                            Uri.parse('$_baseUrl/task-list/$taskListId/rows'),
                            headers: {'Content-Type': 'application/json'},
                            body: jsonEncode({'noOfRows': newCount}),
                          ).catchError((e) => debugPrint('Row count save error: $e'));
                        }
                        await _saveAll();
                      },
                      child: Container(
                        width: 24, height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: const Color(0xFF004AAD), borderRadius: BorderRadius.circular(5)),
                        child: const Icon(Icons.add, size: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // 6. OPEN / HIDE BUTTON
              SizedBox(
                height: 40,
                child: ElevatedButton(
                  onPressed: () async {
                    if (!isExpand) {
                      await _ensureTaskListEntry(task, taskId);
                    }
                    setState(() => expandedTaskId = isExpand ? null : taskId);

                    final prefs = await SharedPreferences.getInstance();
                    if (expandedTaskId != null) {
                      await prefs.setString('last_expanded_task', expandedTaskId!);
                      if (selectedTabIndex != null) {
                        await prefs.setInt('last_selected_tab', selectedTabIndex!);
                      }
                    } else {
                      await prefs.remove('last_expanded_task');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isExpand ? const Color(0xFFFEF2F2) : const Color(0xFFE8F1FF),
                    foregroundColor: isExpand ? const Color(0xFFDC2626) : const Color(0xFF004AAD),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isExpand ? const Color(0xFFFECACA) : const Color(0xFFBFDBFE),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isExpand ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 17),
                      const SizedBox(width: 5),
                      Text(isExpand ? 'HIDE' : 'OPEN', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isExpand) _buildTaskTable(task, taskId),
      ]);
    }).toList());
  }
  
  // ── SINGLE ROW (With permanent original S.NO index preservation) ───────────
 // ── SINGLE ROW (With completed/rejected hiding & permanent S.NO) ───────────
  Widget _buildRow(int index, Map<String, dynamic> task, String taskId) {
    final taskKey = '${taskId}_row_$index';
    _rowContext[taskKey] = {'task': task, 'rowIndex': index, 'taskId': taskId};
    final curStatus = taskStatus[taskKey] ?? TaskStatus.idle;

    // 🟢 COMPLETED or REJECTED rows are hidden from this active table list
    if (curStatus == TaskStatus.completed || curStatus == TaskStatus.rejected) {
      return const SizedBox.shrink(); // Hide completed/rejected row smoothly
    }

    final curDur = taskDurations[taskKey] ?? Duration.zero;
    final totalDur = taskTotalDurations[taskKey];
    final perf = _calculatePerformance(task['singleTask'] ?? '', totalDur);
    final perfColor = _getPerformanceColor(perf);
    final rawDeadline = task['deadline'] ?? '';
    final editDate = _formatDateForDisplay(editableSubmitDates[taskKey] ?? rawDeadline);
    final editDesc = editableTaskDescs[taskKey] ?? task['singleTask'] ?? 'N/A';
    final savedComment = taskComments[taskKey] ?? '';

    // 🟢 S.NO is permanent based on index + 1
    final displaySNo = index + 1;

    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Row(children: [

        // S.NO
        SizedBox(width: snoWidth,
          child: Text('$displaySNo.', textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500))),

        // DEADLINE DATE CONTAINER
        SizedBox(width: submitDateWidth,
          child: GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _parseDate(editDate),
                firstDate: DateTime(2020), lastDate: DateTime(2030),
                builder: (c, child) => Theme(
                  data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF004AAD))),
                  child: child!),
              );
              if (picked != null) {
                setState(() => editableSubmitDates[taskKey] =
                    '${picked.day.toString().padLeft(2,'0')}/${picked.month.toString().padLeft(2,'0')}/${picked.year}');
                await _autoSaveRow(taskKey, task, index, taskId);
              }
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF004AAD)),
                borderRadius: BorderRadius.circular(4),
                color: const Color(0xFFEFF6FF),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(child: Text(editDate,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF004AAD)),
                    overflow: TextOverflow.ellipsis)),
                const Icon(Icons.calendar_today, size: 12, color: Color(0xFF004AAD)),
              ]),
            ),
          ),
        ),

        // TASK DESCRIPTION
        SizedBox(width: taskWidth,
          child: GestureDetector(
            onTap: () => _showEditDialog('Task Description', editDesc, (v) async {
              setState(() => editableTaskDescs[taskKey] = v);
              await _autoSaveRow(taskKey, task, index, taskId);
            }),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(children: [
                Expanded(child: Text(editDesc,
                    style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                const Icon(Icons.edit, size: 12, color: Colors.grey),
              ]),
            ),
          ),
        ),

        // ACTION BUTTONS
        SizedBox(width: actionWidth,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
              _btn("START",
                curStatus == TaskStatus.idle ? Colors.blue.shade900 : Colors.grey.shade200,
                curStatus == TaskStatus.idle ? const Color.fromARGB(255, 248, 249, 249) : Colors.grey,
                curStatus == TaskStatus.idle ? () => _handleStart(taskKey, task, index, taskId) : null),
              const SizedBox(width: 4),
              if (taskStartTimes[taskKey] != null)
                Text('S: ${formatTime(taskStartTimes[taskKey])}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),

              const SizedBox(width: 12),
              _btn("HOLD",
                curStatus == TaskStatus.running ? const Color.fromARGB(255, 100, 99, 99) : Colors.grey.shade200,
                curStatus == TaskStatus.running ? const Color.fromARGB(255, 249, 248, 248) : Colors.grey,
                curStatus == TaskStatus.running ? () => _handleHold(taskKey, task, index, taskId) : null),
              const SizedBox(width: 4),
              if ((taskHoldTimes[taskKey] ?? []).isNotEmpty)
                Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                  children: taskHoldTimes[taskKey]!.map((t) =>
                    Text(formatTime(t), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey))
                  ).toList()),

              const SizedBox(width: 12),
              _btn("RESTART",
                curStatus == TaskStatus.held ? const Color.fromARGB(255, 230, 161, 0) : Colors.grey.shade200,
                curStatus == TaskStatus.held ? Colors.white : Colors.grey,
                curStatus == TaskStatus.held ? () => _handleRestart(taskKey, task, index, taskId) : null),
              const SizedBox(width: 4),
              if ((taskRestartTimes[taskKey] ?? []).isNotEmpty)
                Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                  children: taskRestartTimes[taskKey]!.map((t) =>
                    Text('R: ${formatTime(t)}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange))
                  ).toList()),

              const SizedBox(width: 12),
              _btn("COMPLETED",
                (curStatus == TaskStatus.running || curStatus == TaskStatus.completed)
                    ? const Color.fromARGB(255, 0, 110, 7) : Colors.grey.shade200,
                (curStatus == TaskStatus.running || curStatus == TaskStatus.completed)
                    ? Colors.white : Colors.grey,
                curStatus == TaskStatus.running ? () => _handleComplete(taskKey, task, index, taskId) : null),
              const SizedBox(width: 4),
              if ((taskCompletedTimes[taskKey] ?? []).isNotEmpty)
                Text('C: ${formatTime(taskCompletedTimes[taskKey]!.first)}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF00812B))),

              const SizedBox(width: 12),
              _btn("REJECTED",
                (curStatus == TaskStatus.running || curStatus == TaskStatus.rejected)
                    ? const Color.fromARGB(255, 183, 7, 7) : Colors.grey.shade200,
                (curStatus == TaskStatus.running || curStatus == TaskStatus.rejected)
                    ? Colors.white : Colors.grey,
                curStatus == TaskStatus.running ? () => _handleReject(taskKey, task, index, taskId) : null),
              const SizedBox(width: 4),
              if ((taskRejectedTimes[taskKey] ?? []).isNotEmpty)
                Text('Rj: ${formatTime(taskRejectedTimes[taskKey]!.first)}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFC40000))),
            ]),
          ),
        ),

        // DURATION
        SizedBox(width: durationWidth,
          child: Text(formatDuration(totalDur),
          textAlign: TextAlign.left,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF004AAD)))),

        // COMMENT
        SizedBox(width: commentWidth, height: cellHeight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            alignment: Alignment.centerLeft,
            child: TextFormField(
              key: ValueKey('comment_$taskKey'),
              initialValue: savedComment,
              minLines: 3, maxLines: 6,
              style: const TextStyle(fontSize: 10),
              decoration: InputDecoration(
                hintText: 'Add note...',
                hintStyle: const TextStyle(fontSize: 9, color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                isDense: true,
              ),
              onChanged: (v) {
                taskComments[taskKey] = v;
                Future.delayed(const Duration(seconds: 2), () {
                  if (taskComments[taskKey] == v) _autoSaveRow(taskKey, task, index, taskId);
                });
              },
            ),
          ),
        ),

        // PERFORMANCE
        SizedBox(width: performanceWidth, height: 40,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: perfColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: perfColor.withValues(alpha: 0.3)),
            ),
            child: Text(perf, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: perfColor)),
          ),
        ),

        // STATUS
        SizedBox(width: statusWidth,
          child: Text(_statusString(curStatus), textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _statusColor(curStatus)))),
      ]),
    );
  }

  // ── TASK TABLE ────────────────────────────────────────────────────────────
Widget _buildTaskTable(Map<String, dynamic> task, String taskId) {
  final rowCount = rowCounts[taskId] ?? 1;

  return Scrollbar(
    controller: _horizontalController,
    thumbVisibility: true,
    scrollbarOrientation: ScrollbarOrientation.bottom,
    child: SingleChildScrollView(
      controller: _horizontalController,
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: totalTableWidth,
        child: Column(
          children: [

            // HEADER
            Container(
              height: 45,
              width: totalTableWidth,
              color: const Color(0xFFF1F5F9),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Row(
                children: [
                  SizedBox(
                    width: snoWidth,
                    child: Text(
                      "S.NO",
                      style: _headerStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(
                    width: submitDateWidth,
                    child: Text(
                      "DATE",
                      style: _headerStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(
                    width: taskWidth,
                    child: Text(
                      "TASK DESC",
                      style: _headerStyle,
                    ),
                  ),
                  SizedBox(
                    width: actionWidth,
                    child: Text(
                      "ACTION",
                      style: _headerStyle,
                    ),
                  ),
                  SizedBox(
                    width: durationWidth,
                    child: Text(
                      "DURATION",
                      style: _headerStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(
                    width: commentWidth,
                    child: Text(
                      "COMMENT",
                      style: _headerStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(
                    width: performanceWidth,
                    child: Text(
                      "PERFORMANCE",
                      style: _headerStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(
                    width: statusWidth,
                    child: Text(
                      "STATUS",
                      style: _headerStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),

            // BODY
            for (int i = 0; i < rowCount; i++)
              _buildRow(i, task, taskId),
          ],
        ),
      ),
    ),
  );
}

// FIX: your DB stores designer_submit_date / ads_submit_date / etc. as
  // "DD/MM/YYYY" text (e.g. "31/07/2026"), confirmed from the actual table
  // rows — not ISO format. DateTime.parse() only understands ISO
  // ("YYYY-MM-DD"), so it silently threw on every real value and fell
  // through to just printing the raw string with no days-left calculation
  // at all. This tries DD/MM/YYYY first (the format your data is actually
  // in), then falls back to DateTime.parse for any value that IS already
  // ISO, before giving up and returning null.
  DateTime? _parseFlexibleDate(String raw) {
    final ddmmyyyy = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(raw.trim());
    if (ddmmyyyy != null) {
      final day = int.parse(ddmmyyyy.group(1)!);
      final month = int.parse(ddmmyyyy.group(2)!);
      final year = int.parse(ddmmyyyy.group(3)!);
      try {
        return DateTime(year, month, day);
      } catch (_) {
        return null;
      }
    }
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }


Widget _dateWithDaysLeft(String? isoOrDateString) {
    if (isoOrDateString == null || isoOrDateString.isEmpty) {
      return const Text('N/A', style: TextStyle(fontSize: 10, color: AppColors.textGrey));
    }

    final date = _parseFlexibleDate(isoOrDateString);
    if (date == null) {
      return Text(isoOrDateString, style: const TextStyle(fontSize: 10, color: AppColors.textGrey));
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final daysLeft = target.difference(today).inDays;
    final formattedDate = '${date.day} ${_monthName(date.month)} ${date.year}';

    String label;
    Color color;
    if (daysLeft > 0) {
      label = '$daysLeft Day${daysLeft == 1 ? '' : 's'} Left';
      color = const Color(0xFF00812B);
    } else if (daysLeft == 0) {
      label = 'Due Today';
      color = const Color(0xFFFFA500);
    } else {
      label = '${daysLeft.abs()} Day${daysLeft.abs() == 1 ? '' : 's'} Overdue';
      color = const Color(0xFFC40000);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(formattedDate, style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    ]);
  }

  
  String _monthName(int m) {
    const names = ['', 'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return names[m];
  }
  // FIX: this is what was missing. Given the taskKey of whatever's about to
  // start, if a DIFFERENT task is currently running, this properly holds it
  // — folding its elapsed time into its total (never overwriting/reducing,
  // always +=) and persisting that hold to the backend — instead of just
  // silently cancelling its timer and losing that session's time.
  Future<void> _autoHoldRunningTask(String excludeTaskKey) async {
    if (currentRunningTaskKey == null || currentRunningTaskKey == excludeTaskKey) return;

    final prevKey = currentRunningTaskKey!;
    final ctx = _rowContext[prevKey];

    if (ctx == null) {
      // Row was never built in this session (shouldn't normally happen,
      // since starting it requires the row to have been visible) — fall
      // back to at least stopping the timer so it doesn't keep ticking.
      taskTimers[prevKey]?.cancel();
      taskTimers.remove(prevKey);
      return;
    }

    await _handleHold(
      prevKey,
      ctx['task'] as Map<String, dynamic>,
      ctx['rowIndex'] as int,
      ctx['taskId'] as String,
    );
  }

  // // ── SINGLE ROW ────────────────────────────────────────────────────────────
  // Widget _buildRow(int index, Map<String, dynamic> task, String taskId) {
  //   final taskKey   = '${taskId}_row_$index';
  //   _rowContext[taskKey] = {'task': task, 'rowIndex': index, 'taskId': taskId};
  //   final curStatus = taskStatus[taskKey] ?? TaskStatus.idle;
  //   // final curStatus = taskStatus[taskKey] ?? TaskStatus.idle;
  //   final curDur    = taskDurations[taskKey] ?? Duration.zero;
  //   final totalDur  = taskTotalDurations[taskKey];
  //   final perf      = _calculatePerformance(task['singleTask'] ?? '', totalDur);
  //   final perfColor = _getPerformanceColor(perf);
  //   // final editDate  = _formatDateForDisplay(editableSubmitDates[taskKey] ?? task['assignedDate'] as String?);
  //   // final editDesc  = editableTaskDescs[taskKey]   ?? task['singleTask']   ?? 'N/A';
  //   // final savedComment = taskComments[taskKey] ?? '';
  //   // 🟢 Submit date-ku pathila task-la irukkira deadline date-ai edukkurom
  //   final rawDeadline = task['deadline'] ?? '';
  //   final editDate  = _formatDateForDisplay(editableSubmitDates[taskKey] ?? rawDeadline);
  //   final editDesc  = editableTaskDescs[taskKey]   ?? task['singleTask']   ?? 'N/A';
  //   final savedComment = taskComments[taskKey] ?? '';

  //   return Container(
  //     decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
  //     padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
  //     child: Row(children: [

  //       // S.NO
  //       SizedBox(width: snoWidth,
  //         child: Text('${index + 1}.', textAlign: TextAlign.center,
  //             style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500))),

        
  //      // DEADLINE DATE CONTAINER (Replaces Submit Date)
  //       SizedBox(width: submitDateWidth,
  //         child: GestureDetector(
  //           onTap: () async {
  //             final picked = await showDatePicker(
  //               context: context,
  //               initialDate: _parseDate(editDate),
  //               firstDate: DateTime(2020), lastDate: DateTime(2030),
  //               builder: (c, child) => Theme(
  //                 data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF004AAD))),
  //                 child: child!),
  //             );
  //             if (picked != null) {
  //               setState(() => editableSubmitDates[taskKey] =
  //                   '${picked.day.toString().padLeft(2,'0')}/${picked.month.toString().padLeft(2,'0')}/${picked.year}');
  //               await _autoSaveRow(taskKey, task, index, taskId);
  //             }
  //           },
  //           child: Container(
  //             margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
  //             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  //             decoration: BoxDecoration(
  //               border: Border.all(color: const Color(0xFF004AAD)),
  //               borderRadius: BorderRadius.circular(4),
  //               color: const Color(0xFFEFF6FF),
  //             ),
  //             child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
  //               Expanded(child: Text(editDate,
  //                   style: const TextStyle(fontSize: 11, color: Color(0xFF004AAD)),
  //                   overflow: TextOverflow.ellipsis)),
  //               const Icon(Icons.calendar_today, size: 12, color: Color(0xFF004AAD)),
  //             ]),
  //           ),
  //         ),
  //       ),
  //       // TASK DESCRIPTION
  //       SizedBox(width: taskWidth,
  //         child: GestureDetector(
  //           onTap: () => _showEditDialog('Task Description', editDesc, (v) async {
  //             setState(() => editableTaskDescs[taskKey] = v);
  //             await _autoSaveRow(taskKey, task, index, taskId);
  //           }),
  //           child: Container(
  //             margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
  //             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  //             decoration: BoxDecoration(
  //               border: Border.all(color: Colors.grey.shade300),
  //               borderRadius: BorderRadius.circular(4),
  //             ),
  //             child: Row(children: [
  //               Expanded(child: Text(editDesc,
  //                   style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
  //               const Icon(Icons.edit, size: 12, color: Colors.grey),
  //             ]),
  //           ),
  //         ),
  //       ),

  //       // ACTION BUTTONS
  //       SizedBox(width: actionWidth,
  //         child: SingleChildScrollView(
  //           scrollDirection: Axis.horizontal,
  //           child: Row(
  //             mainAxisAlignment: MainAxisAlignment.start,
  //             children: [
  //             _btn("START",
  //               curStatus == TaskStatus.idle ? Colors.blue.shade900 : Colors.grey.shade200,
  //               curStatus == TaskStatus.idle ? const Color.fromARGB(255, 248, 249, 249) : Colors.grey,
  //               curStatus == TaskStatus.idle ? () => _handleStart(taskKey, task, index, taskId) : null),
  //             const SizedBox(width: 4),
  //             if (taskStartTimes[taskKey] != null)
  //               Text('S: ${formatTime(taskStartTimes[taskKey])}',
  //                   style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),

  //             const SizedBox(width: 12),
  //             _btn("HOLD",
  //               curStatus == TaskStatus.running ? const Color.fromARGB(255, 100, 99, 99) : Colors.grey.shade200,
  //               curStatus == TaskStatus.running ? const Color.fromARGB(255, 249, 248, 248) : Colors.grey,
  //               curStatus == TaskStatus.running ? () => _handleHold(taskKey, task, index, taskId) : null),
  //             const SizedBox(width: 4),
  //             if ((taskHoldTimes[taskKey] ?? []).isNotEmpty)
  //               Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: taskHoldTimes[taskKey]!.map((t) =>
  //                   Text(formatTime(t), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey))
  //                 ).toList()),

  //             const SizedBox(width: 12),
  //             _btn("RESTART",
  //               curStatus == TaskStatus.held ? const Color.fromARGB(255, 230, 161, 0) : Colors.grey.shade200,
  //               curStatus == TaskStatus.held ? Colors.white : Colors.grey,
  //               curStatus == TaskStatus.held ? () => _handleRestart(taskKey, task, index, taskId) : null),
  //             const SizedBox(width: 4),
  //             if ((taskRestartTimes[taskKey] ?? []).isNotEmpty)
  //               Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: taskRestartTimes[taskKey]!.map((t) =>
  //                   Text('R: ${formatTime(t)}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange))
  //                 ).toList()),

  //             const SizedBox(width: 12),
  //             _btn("COMPLETED",
  //               (curStatus == TaskStatus.running || curStatus == TaskStatus.completed)
  //                   ? const Color.fromARGB(255, 0, 110, 7) : Colors.grey.shade200,
  //               (curStatus == TaskStatus.running || curStatus == TaskStatus.completed)
  //                   ? Colors.white : Colors.grey,
  //               curStatus == TaskStatus.running ? () => _handleComplete(taskKey, task, index, taskId) : null),
  //             const SizedBox(width: 4),
  //             if ((taskCompletedTimes[taskKey] ?? []).isNotEmpty)
  //               Text('C: ${formatTime(taskCompletedTimes[taskKey]!.first)}',
  //                   style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF00812B))),

  //             const SizedBox(width: 12),
  //             _btn("REJECTED",
  //               (curStatus == TaskStatus.running || curStatus == TaskStatus.rejected)
  //                   ? const Color.fromARGB(255, 183, 7, 7) : Colors.grey.shade200,
  //               (curStatus == TaskStatus.running || curStatus == TaskStatus.rejected)
  //                   ? Colors.white : Colors.grey,
  //               curStatus == TaskStatus.running ? () => _handleReject(taskKey, task, index, taskId) : null),
  //             const SizedBox(width: 4),
  //             if ((taskRejectedTimes[taskKey] ?? []).isNotEmpty)
  //               Text('Rj: ${formatTime(taskRejectedTimes[taskKey]!.first)}',
  //                   style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFC40000))),

  //             // if (curStatus == TaskStatus.running && curDur != Duration.zero)
  //             //   Padding(padding: const EdgeInsets.only(left: 12),
  //             //     child: 
  //             //     Text('Running: ${formatDuration(curDur)}',
  //             //         style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF004AAD)))
  //             //   ),
  //           ]),
  //         ),
  //       ),

  //       // DURATION
  //       SizedBox(width: durationWidth,
  //         child: Text(formatDuration(totalDur),
  //         textAlign: TextAlign.left,
  //             style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF004AAD)))),

  //       // COMMENT
  //       SizedBox(width: commentWidth, height: cellHeight,
  //         child: Container(
  //           padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
  //           alignment: Alignment.centerLeft,
  //           child: TextFormField(
  //             key: ValueKey('comment_$taskKey'),
  //             initialValue: savedComment,
  //             minLines: 3, maxLines: 6,
  //             style: const TextStyle(fontSize: 10),
  //             decoration: InputDecoration(
  //               hintText: 'Add note...',
  //               hintStyle: const TextStyle(fontSize: 9, color: Colors.grey),
  //               border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
  //               contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
  //               isDense: true,
  //             ),
  //             onChanged: (v) {
  //               taskComments[taskKey] = v;
  //               Future.delayed(const Duration(seconds: 2), () {
  //                 if (taskComments[taskKey] == v) _autoSaveRow(taskKey, task, index, taskId);
  //               });
  //             },
  //           ),
  //         ),
  //       ),

  //       // PERFORMANCE
  //       SizedBox(width: performanceWidth, height: 40,
  //         child: Container(
  //           padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
  //           alignment: Alignment.center,
  //           decoration: BoxDecoration(
  //             color: perfColor.withValues(alpha: 0.1),
  //             borderRadius: BorderRadius.circular(4),
  //             border: Border.all(color: perfColor.withValues(alpha: 0.3)),
  //           ),
  //           child: Text(perf, textAlign: TextAlign.center,
  //               style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: perfColor)),
  //         ),
  //       ),

  //       // STATUS
  //       SizedBox(width: statusWidth,
  //         child: Text(_statusString(curStatus), textAlign: TextAlign.center,
  //             style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _statusColor(curStatus)))),
  //     ]),
  //   );
  // }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Color _statusColor(TaskStatus s) {
    switch (s) {
      case TaskStatus.completed: return const Color(0xFF00812B);
      case TaskStatus.rejected:  return const Color(0xFFC40000);
      case TaskStatus.running:   return const Color(0xFF004AAD);
      case TaskStatus.held:      return Colors.orange;
      default:                   return Colors.grey;
    }
  }

  Widget _btn(String label, Color bg, Color fg, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(2),
          border: Border.all(color: fg.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 9)),
      ),
    );
  }

  Widget _detailItem(String label, String value, {required int flex, Color? color}) {
    return Expanded(flex: flex, child: Row(children: [
      Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF172554))),
      const SizedBox(width: 4),
      Expanded(child: Text(value,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w400, color: color ?? AppColors.textGrey),
        overflow: TextOverflow.ellipsis, maxLines: 2)),
    ]));
  }

  DateTime _parseDate(String s) {
    try {
      final p = s.split('/');
      if (p.length == 3) return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
    } catch (_) {}
    return DateTime.now();
  }

  String _formatDateForDisplay(String? raw) {
    if (raw == null || raw.isEmpty) return '--';
    if (raw.contains('/') && !raw.contains('T')) return raw;
    try {
      final date = DateTime.parse(raw);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      return raw;
    }
  }

  String _formatDateForDatabase(String? raw) {
  if (raw == null || raw.isEmpty) return '';

  try {
    final date = DateTime.parse(raw).toLocal();

    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')} '
        '00:00:00';

  } catch (_) {
    return raw;
  }
}

  void _showEditDialog(String title, String initial, Function(String) onSave) {
    final ctrl = TextEditingController(text: initial);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('Edit $title'),
      content: TextField(controller: ctrl, minLines: 3, maxLines: 5,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
          hintText: 'Enter $title',
        )),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () { onSave(ctrl.text); Navigator.pop(ctx); },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004AAD)),
          child: const Text('Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

}

const TextStyle _headerStyle = TextStyle(
    fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF172554));