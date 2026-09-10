import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/gestures.dart';
import 'dart:async';
import '../../services/api_config.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;


class DayPlannerScreen extends StatefulWidget {
  const DayPlannerScreen({super.key});

  @override
  State<DayPlannerScreen> createState() => _DayPlannerScreenState();
}

class _DayPlannerScreenState extends State<DayPlannerScreen> {
  // static const String _baseUrl = '/api';
  static String get _baseUrl => ApiConfig.baseUrl;

  final ScrollController _horizontalController = ScrollController();

   int get totalClients => filteredRows.length;

  int get completeCount =>
      filteredRows.where((e) => (e['status'] ?? '') == 'COMPLETE').length;

  int get pendingCount =>
      filteredRows.where((e) => (e['status'] ?? '') == 'PENDING').length;

  int get processingCount =>
      filteredRows.where((e) => (e['status'] ?? '') == 'PROCESSING').length;

  int get holdCount =>
      filteredRows.where((e) => (e['status'] ?? '') == 'HOLD').length;

  int get notStartCount =>
      filteredRows.where((e) => (e['status'] ?? '') == 'NOT START').length;


  DateTime selectedDate = DateTime.now();
  String employeeName = '';
  String employeeRole = '';
  Timer? _autoSaveTimer;
  late IO.Socket socket;

  // Unique clients opened in planner rows vs Total unique assigned clients to this employee
int get openedUniqueClientsCount => dayPlanRows.map((e) => e['client']).where((c) => c.toString().isNotEmpty).toSet().length;
int get totalAssignedClientsCount => assignedClients.length;


  final TextEditingController _searchController = TextEditingController();

  double get completionPercentage {
  if (dayPlanRows.isEmpty) return 0;

  return completeCount / dayPlanRows.length;
}

String _searchText = '';

  bool _hasAdsColumn() {
  for (final client in assignedClients) {
    final temp = <String, dynamic>{};

    _prefillRoleFieldsForClient(temp, client);

    if ((temp['ads'] ?? '').toString().trim().isNotEmpty) {
      return true;
    }
  }
  return false;
}

bool _hasDeliverable(int no) {
  final field = 'deliverables_$no';

  for (final client in assignedClients) {
    final temp = <String, dynamic>{};

    _prefillRoleFieldsForClient(temp, client);

    if ((temp[field] ?? '').toString().trim().isNotEmpty) {
      return true;
    }
  }

  return false;
}

  List<Map<String, dynamic>> assignedTasks = [];
  List<String> assignedClients = [];
  Map<String, String> clientMaintenanceDates = {};
List<Map<String, dynamic>> additionalTasks = [];

  static const List<String> statusOptions = ['NOT START', 'PENDING', 'COMPLETE', 'HOLD', 'PROCESSING'];
  static const List<String> yesNoOptions = ['YES', 'NO'];

  String _deadlineLevel = 'none'; // 'none' | 'warning' | 'urgent' | 'admin_notified'


  List<Map<String, dynamic>> dayPlanRows = [];


// ============================================================
// CLIENT ROW LIMIT / SELECTION CONTROL
// ============================================================

int _getMaxAllowedRowsForClient(String clientName) {
  int count = 0;

  final auth = Provider.of<AuthService>(
    context,
    listen: false,
  );

  final myName =
      (auth.user?['fullName'] as String? ?? '')
          .trim()
          .toUpperCase();

  // Safety fallback
  if (myName.isEmpty) {
    return 1;
  }

  // ------------------------------------------------------------
  // 1. NORMAL ASSIGNED TASKS
  // ------------------------------------------------------------

  final clientTasks = assignedTasks.where(
    (task) =>
        (task['client_name'] ?? '').toString().trim() ==
        clientName.trim(),
  );

  for (final task in clientTasks) {
    // ----------------------------------------------------------
    // ADS
    // ----------------------------------------------------------

    final adsEmployee =
        (task['ads_handling'] ?? '')
            .toString()
            .trim()
            .toUpperCase();

    final adsPlatform =
        (task['ads_platform'] ?? '')
            .toString()
            .trim();

    if (adsEmployee == myName && adsPlatform.isNotEmpty) {
      count++;
    }

    // ----------------------------------------------------------
    // OTHER ROLE BASED TASKS
    // ----------------------------------------------------------

    const roleColumns = [
      'page_handling',
      'designer',
      'videographer',
      'video_editor',
      'developer',
      'ui_ux_designer',
    ];

    for (final roleColumn in roleColumns) {
      final String taskField =
          roleColumn == 'page_handling'
              ? 'pages_platform'
              : '${roleColumn}_tasks';

      final taskValues =
          (task[taskField] ?? '')
              .toString()
              .trim();

      final roleEmployee =
          (task[roleColumn] ?? '')
              .toString()
              .trim()
              .toUpperCase();

      if (roleEmployee == myName && taskValues.isNotEmpty) {
        final taskCount = taskValues
            .split(',')
            .where(
              (value) => value.trim().isNotEmpty,
            )
            .length;

        count += taskCount > 0 ? taskCount : 1;
      }
    }
  }

  // ------------------------------------------------------------
  // 2. ADDITIONAL TASKS
  // ------------------------------------------------------------

  final clientAdditionalTasks =
      additionalTasks.where(
    (task) =>
        (task['client_name'] ?? '')
            .toString()
            .trim() ==
        clientName.trim(),
  );

  for (final task in clientAdditionalTasks) {
    count++;
  }

  // ------------------------------------------------------------
  // SAFETY
  // ------------------------------------------------------------

  return count > 0 ? count : 1;
}


// ============================================================
// CHECK WHETHER CLIENT CAN BE SELECTED
// ============================================================

bool _isClientSelectionAllowed(
  String clientName,
  String? currentRowId,
) {
  final maxAllowed =
      _getMaxAllowedRowsForClient(clientName);

  // Count how many planner rows already use
  // this client for the selected date.
  final currentSelectedCount =
      filteredRows.where((row) {

    // While editing an existing row,
    // don't count the same row again.
    if (currentRowId != null &&
        row['id'].toString() ==
            currentRowId.toString()) {
      return false;
    }

    final rowClient =
        (row['client'] ?? '')
            .toString()
            .trim();

    return rowClient == clientName.trim();

  }).length;

  return currentSelectedCount < maxAllowed;
}

bool _didInitialLoad = false;

bool _validateRows() {
  for (final row in filteredRows) {
    // if ((row['client'] ?? '').toString().trim().isEmpty) {
    //   _showValidationMessage("Please select a client.");
    //   return false;
    // }

    if ((row['today_plan'] ?? '').toString().trim().isEmpty) {
      _showValidationMessage("Please enter today's plan.");
      return false;
    }

    if ((row['status'] ?? '').toString().trim().isEmpty) {
      _showValidationMessage("Please select status.");
      return false;
    }
  }

  return true;
}
void _showValidationMessage(String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.orange,
    ),
  );
}
  @override
  void initState() {
    super.initState();
    // FIX: removed loadAssignedClients()/loadTodayDayPlan() from here —
    // employeeName is still '' at this point, so both calls were hitting
    // the backend with a blank name.
  _checkDeadlineStatus();
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
  //   socket.off('task_updated');
  //   socket.on('task_updated', (data) {
  //     print("🔥 Day Planner Live Working Time Update: $data");
  //     if (mounted) {
  //       _fetchTotalWorkingHours(); // Auto refresh working time on any task update!
  //    loadTodayDayPlan();
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

  socket.off('task_updated');

  socket.on('task_updated', (data) async {
    print("🔥 Day Planner Live Update: $data");

    if (!mounted) return;

    try {
      // Reload latest day planner data
      await loadTodayDayPlan();

      // Refresh completed / balanced deliverables
      for (final row in dayPlanRows) {
        if ((row['client'] ?? '').toString().trim().isNotEmpty) {
          await loadProgress(row);
        }
      }

      // Refresh working hours
      await _fetchTotalWorkingHours();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint("Socket refresh error: $e");
    }
  });
}

  @override
  void dispose() {
    _horizontalController.dispose();
    _autoSaveTimer?.cancel();
    _searchController.dispose();
    socket.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authService = Provider.of<AuthService>(context, listen: false);
    employeeName = authService.user?['fullName'] ?? 'Employee';
    employeeRole = authService.user?['role'] ?? 'Employee';

    // FIX: this is the correct place — employeeName is guaranteed set here.
    // Guarded so it only runs once, not on every dependency change.
    if (!_didInitialLoad) {
      _didInitialLoad = true;
      loadAssignedClients();
      loadTodayDayPlan();

  _checkDeadlineStatus();
    }
  }

void _scheduleAutoSave(Map<String, dynamic> row) {
  _autoSaveTimer?.cancel();

  _autoSaveTimer = Timer(
    const Duration(seconds: 2),
    () async {
      if (row['id'] != null) {
  await _saveRow(
    row,
    lockRow: false,
    showMessage: false,
  );
}
    },
  );
}

Future<void> _checkDeadlineStatus() async {
    if (employeeName.isEmpty) return;
    try {
      final r = await http.get(
        Uri.parse('$_baseUrl/day-planner/status/${Uri.encodeComponent(employeeName)}'),
      );
      if (r.statusCode == 200) {
        final body = jsonDecode(r.body);
        setState(() {
          _deadlineLevel = body['data']['deadlineLevel'] as String? ?? 'none';
        });
      }
    } catch (e) {
      debugPrint('❌ Error checking deadline status: $e');
    }
  }

  Widget? _buildDeadlineBanner() {
    if (_deadlineLevel == 'none') return null;
 
    late Color bgColor;
    late Color textColor;
    late IconData icon;
    late String message;
 
    switch (_deadlineLevel) {
      case 'warning':
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFF92400E);
        icon = Icons.warning_amber_rounded;
        message = 'Your Day Plan has not been submitted yet. Please submit before 9:30 AM.';
        break;
      case 'urgent':
        bgColor = const Color(0xFFFFEDD5);
        textColor = const Color(0xFF9A3412);
        icon = Icons.error_outline_rounded;
        message = 'URGENT: Day Plan still not submitted. Submit now to avoid being reported to Admin.';
        break;
      case 'admin_notified':
        bgColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFFB91C1C);
        icon = Icons.report_gmailerrorred_rounded;
        message = 'Deadline passed - Admin has been notified that your Day Plan is not submitted.';
        break;
      default:
        return null;
    }
 
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
      child: Row(children: [
        Icon(icon, size: 18, color: textColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
        ),
      ]),
    );
  }

void _prefillRoleFieldsForClient(
  Map<String, dynamic> row,
  String clientName,
) {
  final auth = Provider.of<AuthService>(context, listen: false);

  final myName =
      (auth.user?['fullName'] as String? ?? '').trim().toUpperCase();

  if (myName.isEmpty) return;

  row['ads'] = '';

  // Clear all deliverables
  for (int i = 1; i <= 6; i++) {
    row['deliverables_$i'] = '';
    row['complete_deliverables_$i'] = '';
    row['balanced_deliverables_$i'] = '';
  }

  final clientTasks = assignedTasks.where(
    (task) => (task['client_name'] ?? '').toString() == clientName,
  );

  int nextIndex = 1;

  for (final task in clientTasks) {
    //---------------------------------------------
    // ADS
    //---------------------------------------------
    final adsEmployee =
        (task['ads_handling'] ?? '').toString().trim().toUpperCase();

    if (adsEmployee == myName) {
      row['ads'] = task['ads_platform'] ?? '';
    }

    //---------------------------------------------
    // PAGE
    //---------------------------------------------
    final pageEmployee =
        (task['page_handling'] ?? '').toString().trim().toUpperCase();

    if (pageEmployee == myName && nextIndex <= 6) {
      row['deliverables_$nextIndex'] =
          (task['pages_platform'] ?? '').toString();
      nextIndex++;
    }

    //---------------------------------------------
    // DESIGNER
    //---------------------------------------------
    final designerEmployee =
        (task['designer'] ?? '').toString().trim().toUpperCase();

    if (designerEmployee == myName && nextIndex <= 6) {
      row['deliverables_$nextIndex'] =
          (task['designer_tasks'] ?? '').toString();
      nextIndex++;
    }

    //---------------------------------------------
    // VIDEOGRAPHER
    //---------------------------------------------
    final videoEmployee =
        (task['videographer'] ?? '').toString().trim().toUpperCase();

    if (videoEmployee == myName && nextIndex <= 6) {
      row['deliverables_$nextIndex'] =
          (task['videographer_tasks'] ?? '').toString();
      nextIndex++;
    }

    //---------------------------------------------
    // VIDEO EDITOR
    //---------------------------------------------
    final editorEmployee =
        (task['video_editor'] ?? '').toString().trim().toUpperCase();

    if (editorEmployee == myName && nextIndex <= 6) {
      row['deliverables_$nextIndex'] =
          (task['video_editor_task'] ?? '').toString();
      nextIndex++;
    }

    //---------------------------------------------
    // DEVELOPER
    //---------------------------------------------
    final developerEmployee =
        (task['developer'] ?? '').toString().trim().toUpperCase();

    if (developerEmployee == myName && nextIndex <= 6) {
      row['deliverables_$nextIndex'] =
          (task['developer_tasks'] ?? '').toString();
      nextIndex++;
    }

    //---------------------------------------------
    // UI UX
    //---------------------------------------------
    final uiuxEmployee =
        (task['ui_ux_designer'] ?? '')
            .toString()
            .trim()
            .toUpperCase();

    if (uiuxEmployee == myName && nextIndex <= 6) {
      row['deliverables_$nextIndex'] =
          (task['ui_ux_tasks'] ?? '').toString();
      nextIndex++;
    }
  }

  //---------------------------------------------
  // ADDITIONAL TASKS
  //---------------------------------------------
  final addTasks = additionalTasks.where(
    (e) => (e['client_name'] ?? '') == clientName,
  );

  for (final task in addTasks) {
    if (nextIndex > 6) break;

    final total = int.tryParse(
          task['no_of_rows'].toString(),
        ) ??
        1;

    final taskName = (task['deliverables'] ?? '').toString();

    row['deliverables_$nextIndex'] = "$taskName ($total)";
    row['complete_deliverables_$nextIndex'] =
        "$taskName (0/$total)";
    row['balanced_deliverables_$nextIndex'] =
        "$taskName ($total/$total)";

    nextIndex++;
  }

  //---------------------------------------------
  // DEFAULT COMPLETE / BALANCE
  //---------------------------------------------
for (int i = 1; i <= 6; i++) {
    final deliverable = (row['deliverables_$i'] ?? '').toString().trim();

    if (deliverable.isNotEmpty) {
      final deliverableList = deliverable
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final completeList = <String>[];
      final balancedList = <String>[];

      for (final taskName in deliverableList) {
        // Parse e.g. "POSTER (1)" -> name="POSTER", total=1
        final match = RegExp(r'^(.*?)\s*\((\d+)\)\s*$').firstMatch(taskName);
        final name = match != null ? match.group(1)!.trim() : taskName;
        final total = match != null ? int.tryParse(match.group(2)!) ?? 1 : 1;

        completeList.add('$name (0/$total)');
        balancedList.add('$name ($total/$total)');
      }

      row['complete_deliverables_$i'] = completeList.join(', ');
      row['balanced_deliverables_$i'] = balancedList.join(', ');
    }
  }
}

Future<void> loadTodayDayPlan() async {
  // Format the date as YYYY-MM-DD to ensure the backend filters correctly
  String formattedDate = "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

  try {
    final response = await http.get(
      Uri.parse("$_baseUrl/day-planner/today/$employeeName?date=$formattedDate"),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      setState(() {
        dayPlanRows.clear();
 
        for (final item in data) {
          dayPlanRows.add({
            'id': item['id'],
            // Use the string date provided by the backend, which is in YYYY-MM-DD format
            'date': DateTime.parse(item['date']), 
            'client': item['client'] ?? '',
            'maintenance_date': item['maintenance_date'] ?? '',
            'ads': item['ads'] ?? '',
            'today_leads': item['today_leads'] ?? '',
            'today_report': item['today_report'] ?? '',
            'deliverables_1': item['deliverables_1'] ?? '',
            'complete_deliverables_1': item['complete_deliverables_1'] ?? '',
            'balanced_deliverables_1': item['balanced_deliverables_1'] ?? '',
            'deliverables_2': item['deliverables_2'] ?? '',
            'complete_deliverables_2': item['complete_deliverables_2'] ?? '',
            'balanced_deliverables_2': item['balanced_deliverables_2'] ?? '',
            'deliverables_3': item['deliverables_3'] ?? '',
            'complete_deliverables_3': item['complete_deliverables_3'] ?? '',
            'balanced_deliverables_3': item['balanced_deliverables_3'] ?? '',
            'deliverables_4': item['deliverables_4'] ?? '',
'complete_deliverables_4': item['complete_deliverables_4'] ?? '',
'balanced_deliverables_4': item['balanced_deliverables_4'] ?? '',

'deliverables_5': item['deliverables_5'] ?? '',
'complete_deliverables_5': item['complete_deliverables_5'] ?? '',
'balanced_deliverables_5': item['balanced_deliverables_5'] ?? '',

'deliverables_6': item['deliverables_6'] ?? '',
'complete_deliverables_6': item['complete_deliverables_6'] ?? '',
'balanced_deliverables_6': item['balanced_deliverables_6'] ?? '',
            'today_plan': item['today_plan'] ?? '',
            'status': item['status'] ?? '',
            'remarks': item['remarks'] ?? '',
            '_editing': false, // Existing records are read-only
          });
        }

      });
      await _fetchTotalWorkingHours();
    } 
    else {
      debugPrint('Failed to load day plan: ${response.statusCode}');
    }
  } catch (e) {
    debugPrint('Error in loadTodayDayPlan: $e');
  }
}

// String _formatMaintenanceDate(String value) {
//   if (value.trim().isEmpty) return '';

//   try {
//     final date = DateTime.parse(value).toLocal();

//     return "${date.day}/${date.month}/${date.year}";
//   } catch (_) {
//     return value;
//   }
// }

String _formatMaintenanceDate(String value) {
  return value;
}

  Future<void> loadAssignedClients() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final name = auth.user?['fullName'] as String?;
    if (name == null || name.isEmpty) return;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/employee-tasks/by-employee/${Uri.encodeComponent(name)}'),
      );
      final additionalRes = await http.get(
        Uri.parse('$_baseUrl/task-list/additional/${Uri.encodeComponent(name)}'),
      );
     
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final rows = List<Map<String, dynamic>>.from(json['data'] ?? []);
        final nameUpper = name.toUpperCase();


        // Check the employee's name against every possible role column on
        // each row — same matching logic AssignedTasksContent already uses.
        const roleColumns = [
          'designer', 'videographer', 'video_editor',
          'ads_handling', 'page_handling', 'ui_ux_designer', 'developer',
        ];

        final uniqueClients = <String>{};
        final maintMap = <String, String>{};
        List<Map<String, dynamic>> allTasksList = [];

        for (final row in rows) {
  final matchesEmployee = roleColumns.any((col) {
    final val = row[col];
    return val != null &&
        val.toString().toUpperCase() == nameUpper;
  });

  if (matchesEmployee) {
    final clientName = row['client_name']?.toString() ?? '';

    final maintDate =
        row['maintenance_date']?.toString() ??
        row['submission_date']?.toString() ??
        '';

    if (clientName.isNotEmpty) {
      uniqueClients.add(clientName);

      if (maintDate.isNotEmpty) {
        maintMap[clientName] = _formatMaintenanceDate(maintDate);
      }
    }
  }
}

        if (additionalRes.statusCode == 200) {
        final addJson = jsonDecode(additionalRes.body);
        final addRows = List<Map<String, dynamic>>.from(addJson['data'] ?? []);
        allTasksList.addAll(addRows);
        

       for (final row in addRows) {
  final clientName = row['client_name']?.toString() ?? '';

  final maintDate =
      row['maintenance_date']?.toString() ??
      row['submission_date']?.toString() ??
      '';

  if (clientName.isNotEmpty) {
    uniqueClients.add(clientName);

    if (maintDate.isNotEmpty) {
      maintMap[clientName] = _formatMaintenanceDate(maintDate);
    }
  }
}
      }

        setState(() {
          assignedTasks = rows;
          additionalTasks = allTasksList; 
          assignedClients = uniqueClients.toList();
          clientMaintenanceDates = maintMap;
        });
      } else {
        debugPrint('❌ loadAssignedClients failed (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error loading assigned clients: $e');
    }
  }

  bool isToday() {
    final now = DateTime.now();
    return selectedDate.year == now.year && selectedDate.month == now.month && selectedDate.day == now.day;
  }

  List<Map<String, dynamic>> get filteredRows {
    return dayPlanRows.where((r) {
      final d = r['date'] as DateTime;
      return d.year == selectedDate.year && d.month == selectedDate.month && d.day == selectedDate.day;
    }).toList();
  }
  

Future<void> loadProgress(Map<String, dynamic> row) async {
  try {
    final clientName = row['client'] ?? '';
    if (clientName.isEmpty) return;

    final response = await http.get(
      Uri.parse('$_baseUrl/day-planner/progress/$employeeName/${Uri.encodeComponent(clientName)}')
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final List<dynamic> list = json["data"] ?? [];

      setState(() {
        for (int i = 0; i < list.length && i < 6; i++) {
          final int index = i + 1;
          final item = list[i];
          
          // 🟢 Backend-il irunthu varukira accurate completed & balanced strings-ai assign seyyungal
          row["deliverables_$index"] = item["deliverable"] ?? '';
          row["complete_deliverables_$index"] = item["completed"] ?? ''; // e.g. "POSTER (2/5)"
          row["balanced_deliverables_$index"] = item["balanced"] ?? ''; // e.g. "POSTER (3/5)"
        }
      });
    }
  } catch (e) {
    debugPrint("Error loading progress: $e");
  }
}

  Future<void> _addRow() async {
    try {
      final r = await http.post(
        Uri.parse('$_baseUrl/day-planner'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'employeeName': employeeName,
          'employeeRole': employeeRole,
          'date': '${selectedDate.year.toString().padLeft(4, '0')}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
          'client': assignedClients.isNotEmpty ? assignedClients.first : '',
        }),
      );

      if (r.statusCode == 201) {
        final body = jsonDecode(r.body);
        final newId = body['data']['id'];
        setState(() {
         dayPlanRows.add({
  'id': newId,
  'date': selectedDate,
  'client': assignedClients.isNotEmpty ? assignedClients.first : '',
  'ads': '',
  'today_leads': '',
  'today_report': '',

  'deliverables_1': '',
  'complete_deliverables_1': '',
  'balanced_deliverables_1': '',

  'deliverables_2': '',
  'complete_deliverables_2': '',
  'balanced_deliverables_2': '',

  'deliverables_3': '',
  'complete_deliverables_3': '',
  'balanced_deliverables_3': '',

  'deliverables_4': '',
  'complete_deliverables_4': '',
  'balanced_deliverables_4': '',

  'deliverables_5': '',
  'complete_deliverables_5': '',
  'balanced_deliverables_5': '',

  'deliverables_6': '',
  'complete_deliverables_6': '',
  'balanced_deliverables_6': '',

  'today_plan': '',
  'status': '',
  'remarks': '',
  '_editing': true,
});;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add row (${r.statusCode})'), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding row: $e'), backgroundColor: const Color(0xFFDC2626)),
      );
    }
  }

  // void _deleteRow(int id) {
  //   setState(() => dayPlanRows.removeWhere((r) => r['id'] == id));
  // }

  Future<void> _deleteRow(int id) async {
  try {
    final response = await http.delete(
      Uri.parse('$_baseUrl/day-planner/$id'),
    );

    if (response.statusCode == 200) {
      setState(() {
        dayPlanRows.removeWhere((r) => r['id'] == id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Row deleted successfully"),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Delete failed : ${response.body}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Error : $e"),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  void _editRow(Map<String, dynamic> row) {
    setState(() => row['_editing'] = true);
  }

Future<void> _saveRow(
  Map<String, dynamic> row, {
  bool lockRow = true,
  bool showMessage = true,
}) async {
  final id = row['id'];

  try {
    final body = {
      'client': row['client'] ?? '',
      'maintenanceDate': row['maintenance_date'] ?? '',
      'ads': row['ads'] ?? '',
      'todayLeads': row['today_leads'] ?? '',
      'todayReport': row['today_report'] ?? '',
      'deliverables1': row['deliverables_1'] ?? '',
      'completeDeliverables1': row['complete_deliverables_1'] ?? '',
      'balancedDeliverables1': row['balanced_deliverables_1'] ?? '',
      'deliverables2': row['deliverables_2'] ?? '',
      'completeDeliverables2': row['complete_deliverables_2'] ?? '',
      'balancedDeliverables2': row['balanced_deliverables_2'] ?? '',
      'deliverables3': row['deliverables_3'] ?? '',
      'completeDeliverables3': row['complete_deliverables_3'] ?? '',
      'balancedDeliverables3': row['balanced_deliverables_3'] ?? '',
      'deliverables4': row['deliverables_4'] ?? '',
'completeDeliverables4': row['complete_deliverables_4'] ?? '',
'balancedDeliverables4': row['balanced_deliverables_4'] ?? '',

'deliverables5': row['deliverables_5'] ?? '',
'completeDeliverables5': row['complete_deliverables_5'] ?? '',
'balancedDeliverables5': row['balanced_deliverables_5'] ?? '',

'deliverables6': row['deliverables_6'] ?? '',
'completeDeliverables6': row['complete_deliverables_6'] ?? '',
'balancedDeliverables6': row['balanced_deliverables_6'] ?? '',
      'todayPlan': row['today_plan'] ?? '',
      'status': row['status'] ?? '',
      'remarks': row['remarks'] ?? '',
    };  

    print("PUT URL : $_baseUrl/day-planner/$id");
    print("BODY : ${jsonEncode(body)}");

    final response = await http.put(
      Uri.parse('$_baseUrl/day-planner/$id'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    print("STATUS : ${response.statusCode}");
    print("RESPONSE : ${response.body}");

    if (response.statusCode == 200) {
  setState(() {
    if (lockRow) {
      row['_editing'] = false;
    }
  });

  if (showMessage) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Saved Successfully"),
        backgroundColor: Colors.green,
      ),
    );
  }
} else {
      if (showMessage) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(response.body),
      backgroundColor: Colors.red,
    ),
  );
};
    }
  } catch (e) {
    print(e);

   if (showMessage) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(e.toString()),
      backgroundColor: Colors.red,
    ),
  );
}
  }
}


void _setDeliverableProgress(
  Map<String, dynamic> row,
  String deliverableField,
) {
  final task = (row[deliverableField] ?? '').toString().trim();

  if (task.isEmpty) {
    row['complete_$deliverableField'] = '';
    row['balanced_$deliverableField'] = '';
  } else {
    row['complete_$deliverableField'] = '0/1';
    row['balanced_$deliverableField'] = '1/1';
  }
}
Future<void> _confirmDelete(int id) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text("Delete Row"),
        content: const Text(
          "Are you sure you want to delete this row?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      );
    },
  );

  if (result == true) {
    _deleteRow(id);
  }
}

Future<bool> _confirmSubmit() async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
            ),
            child: Container(
              width: 420,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ICON
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.task_alt_rounded,
                      color: Color(0xFF2563EB),
                      size: 31,
                    ),
                  ),

                  const SizedBox(height: 18),

                  // TITLE
                  const Text(
                    "Submit Day Planner?",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // DESCRIPTION
                  const Text(
                    "Once you submit today's planner, "
                    "you won't be able to edit it.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Color(0xFF64748B),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ENCOURAGEMENT BOX
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFBBF7D0),
                      ),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 19,
                          color: Color(0xFF16A34A),
                        ),
                        SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            "Make sure today's plan and status "
                            "are completely filled before submitting. "
                            "Keep your day plan updated and stay on track!",
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.45,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF166534),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // BUTTONS
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.pop(context, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  const Color(0xFF475569),
                              side: const BorderSide(
                                color: Color(0xFFCBD5E1),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              "Cancel",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            onPressed: () =>
                                Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(10),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 17,
                                ),
                                SizedBox(width: 7),
                                Text(
                                  "Submit",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ) ??
      false;
}

String totalWorkingTimeFormatted = "00h 00m";

Future<void> _fetchTotalWorkingHours() async {
  try {
    String formattedDate = "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
    
    final response = await http.get(
      Uri.parse('$_baseUrl/dashboard/live-tracking-tasks/$employeeName?date=$formattedDate'),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final rows = List<dynamic>.from(body['data'] ?? []);

      // 🟢 Parse duration values from the list like live_tracking_tasks_page.dart
      int totalSumSeconds = 0;
      for (var row in rows) {
        String durStr = (row['duration'] ?? '').toString().toLowerCase();
        
        int hrs = 0;
        int mins = 0;

        if (durStr.contains('hrs') || durStr.contains('hr')) {
          final parts = durStr.split('hr');
          hrs = int.tryParse(parts[0].trim()) ?? 0;
          if (parts.length > 1 && parts[1].contains('min')) {
            final minPart = parts[1].replaceAll('s', '').replaceAll('mins', '').replaceAll('min', '').trim();
            mins = int.tryParse(minPart) ?? 0;
          }
        } else if (durStr.contains('min')) {
          final minPart = durStr.replaceAll('s', '').replaceAll('mins', '').replaceAll('min', '').trim();
          mins = int.tryParse(minPart) ?? 0;
        }

        totalSumSeconds += (hrs * 3600) + (mins * 60);
      }

      int totalHours = totalSumSeconds ~/ 3600;
      int totalMinutes = (totalSumSeconds % 3600) ~/ 60;

      setState(() {
        totalWorkingTimeFormatted = '${totalHours.toString().padLeft(2, '0')}h ${totalMinutes.toString().padLeft(2, '0')}m';
      });

      // 🟢 Automatically sync total working seconds to backend day_plan_rows
      await http.put(
        Uri.parse('$_baseUrl/day-planner/working-hours'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'employeeName': employeeName,
          'date': formattedDate,
          'reportType': 'Morning', // or dynamic if you have reportType state
          'totalWorkingSecs': totalSumSeconds,
        }),
      );

    }
  } catch (e) {
    debugPrint('Error fetching total working hours: $e');
  }
}

Future<void> _submitDay() async {
  final confirm = await _confirmSubmit();

  if (!confirm) return;

  if (!_validateRows()) return;

  // Set default status if empty
  for (final row in filteredRows) {
    if ((row['status'] ?? '').toString().trim().isEmpty) {
      row['status'] = 'NOT START';
    }

    // Ensure latest changes are saved before submit
    await _saveRow(
      row,
      lockRow: false,
      showMessage: false,
    );
  }

  // Submit to backend
  try {
    final response = await http.post(
      Uri.parse('$_baseUrl/day-planner/submit'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'employeeName': employeeName,
        'date':
            '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
      }),
    );

    if (response.statusCode == 200) {
      await _checkDeadlineStatus();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Day plan submitted & Admin notified!'),
          backgroundColor: Color(0xFF16A34A),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      throw Exception('Failed to submit');
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
  
  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  @override
  Widget build(BuildContext context) {
    final rows = filteredRows;
    final isTodayView = isToday();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 700;
            final horizontalPadding = isMobile ? 12.0 : 24.0;

            return RefreshIndicator(
              color: const Color(0xFF0757D5),
              onRefresh: () async {
                await loadAssignedClients();
                await loadTodayDayPlan();
                await _fetchTotalWorkingHours();
                await _checkDeadlineStatus();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  isMobile ? 12 : 22,
                  horizontalPadding,
                  28,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHero(isTodayView, isMobile),
                    const SizedBox(height: 14),
                    _buildStatusStrip(isMobile),
                    const SizedBox(height: 14),
                    if (isTodayView) ...[
                      if (_buildDeadlineBanner() != null)
                        _buildDeadlineBanner()!,
                    ] else
                      _buildReadOnlyBanner(),
                    _buildWorkspaceToolbar(isMobile),
                    const SizedBox(height: 14),
                    _buildSheetGrid(rows, isTodayView, isMobile),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHero(bool isTodayView, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF063A9B), Color(0xFF0B6BDE)],
        ),
        borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0757D5).withOpacity(.20),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeroIdentity(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildHeroDate(isMobile)),
                    const SizedBox(width: 8),
                    _buildWorkingTimePill(inHero: true),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: _buildHeroIdentity()),
                const SizedBox(width: 18),
                _buildHeroDate(isMobile),
                const SizedBox(width: 10),
                _buildWorkingTimePill(inHero: true),
              ],
            ),
    );
  }

  Widget _buildHeroIdentity() {
    final displayName = employeeName.trim().isEmpty ? 'Employee' : employeeName.trim();
    final displayRole = employeeRole.trim().isEmpty ? 'Team Member' : employeeRole.trim();

    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.16),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(.24)),
          ),
          child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 25),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DAY PLANNER • 2050',
                style: TextStyle(
                  color: Colors.white.withOpacity(.72),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Good day, $displayName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.3,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '$displayRole  •  Plan your day with clarity',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(.76),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroDate(bool isMobile) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _pickPlannerDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(.20)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              _formatDate(selectedDate),
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 5),
            Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white.withOpacity(.75), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroActions(bool isTodayView, bool isMobile) {
    if (!isTodayView) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _heroActionButton(
          icon: Icons.add_rounded,
          label: 'Add Row',
          filled: false,
          onTap: _addRow,
        ),
        const SizedBox(width: 8),
        _heroActionButton(
          icon: Icons.check_circle_rounded,
          label: 'Submit',
          filled: true,
          onTap: _submitDay,
        ),
      ],
    );
  }

  Widget _heroActionButton({
    required IconData icon,
    required String label,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: filled ? Colors.white : Colors.white.withOpacity(.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(.24)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: filled ? const Color(0xFF0757D5) : Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: filled ? const Color(0xFF0757D5) : Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickPlannerDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0757D5),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF102A56),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;
    setState(() => selectedDate = picked);
    await loadTodayDayPlan();
    await _checkDeadlineStatus();
    await _fetchTotalWorkingHours();
  }

  Widget _buildStatusStrip(bool isMobile) {
    final total = dayPlanRows.length;
    final cards = <Widget>[
      _metricCard('Clients', '$openedUniqueClientsCount/$totalAssignedClientsCount', Icons.groups_2_rounded, const Color(0xFF0757D5), totalAssignedClientsCount == 0 ? 0 : openedUniqueClientsCount / totalAssignedClientsCount),
      _metricCard('Completed', '$completeCount', Icons.check_circle_rounded, const Color(0xFF087F5B), total == 0 ? 0 : completeCount / total),
      _metricCard('Pending', '$pendingCount', Icons.schedule_rounded, const Color(0xFFB66A00), total == 0 ? 0 : pendingCount / total),
      _metricCard('Processing', '$processingCount', Icons.autorenew_rounded, const Color(0xFF1557B0), total == 0 ? 0 : processingCount / total),
      _metricCard('On Hold', '$holdCount', Icons.pause_circle_rounded, const Color(0xFF5C4AC7), total == 0 ? 0 : holdCount / total),
      _metricCard('Not Started', '$notStartCount', Icons.radio_button_unchecked_rounded, const Color(0xFF64748B), total == 0 ? 0 : notStartCount / total),
    ];

    return SizedBox(
      height: isMobile ? 116 : 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, index) => cards[index],
      ),
    );
  }

  Widget _metricCard(String title, String value, IconData icon, Color color, double progress) {
    final double safeProgress = progress.clamp(0.0, 1.0).toDouble();
    return Container(
      width: 172,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE8FB)),
        boxShadow: [
          BoxShadow(color: const Color(0xFF174A8B).withOpacity(.06), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(11)),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
            ],
          ),
          const Spacer(),
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF52637B))),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: safeProgress,
              minHeight: 5,
              backgroundColor: const Color(0xFFEAF0F9),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceToolbar(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE8FB)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF174A8B).withOpacity(.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSearchBox(),
                const SizedBox(height: 10),
                if (isToday()) _buildToolbarActions(true),
              ],
            )
          : Row(
              children: [
                Expanded(child: _buildSearchBox()),
                const SizedBox(width: 12),
                if (isToday()) _buildToolbarActions(false),
              ],
            ),
    );
  }

  Widget _buildToolbarActions(bool isMobile) {
    if (isMobile) {
      return Row(
        children: [
          Expanded(
            child: _toolbarActionButton(
              icon: Icons.add_rounded,
              label: 'Add Row',
              primary: true,
              onTap: _addRow,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _toolbarActionButton(
              icon: Icons.check_circle_rounded,
              label: 'Submit',
              primary: false,
              onTap: _submitDay,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _toolbarActionButton(
          icon: Icons.add_rounded,
          label: 'Add Row',
          primary: true,
          onTap: _addRow,
        ),
        const SizedBox(width: 8),
        _toolbarActionButton(
          icon: Icons.check_circle_rounded,
          label: 'Submit',
          primary: false,
          onTap: _submitDay,
        ),
      ],
    );
  }

  Widget _toolbarActionButton({
    required IconData icon,
    required String label,
    required bool primary,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            gradient: primary
                ? const LinearGradient(
                    colors: [Color(0xFF0757D5), Color(0xFF0A70E8)],
                  )
                : null,
            color: primary ? null : const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: primary
                  ? const Color(0xFF0757D5)
                  : const Color(0xFFB7E6CF),
            ),
            boxShadow: [
              BoxShadow(
                color: primary
                    ? const Color(0xFF0757D5).withOpacity(.14)
                    : const Color(0xFF16A34A).withOpacity(.07),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 17,
                color: primary
                    ? Colors.white
                    : const Color(0xFF15803D),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: primary
                      ? Colors.white
                      : const Color(0xFF15803D),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBox() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchText = value),
      decoration: InputDecoration(
        hintText: 'Search clients, plans or work...',
        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF91A0B7)),
        prefixIcon: const Icon(Icons.search_rounded, size: 19, color: Color(0xFF0757D5)),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.close_rounded, size: 17, color: Color(0xFF71819A)),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchText = '');
                },
              ),
        filled: true,
        fillColor: const Color(0xFFF6F9FE),
        contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xFFE0E9F7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xFF0757D5), width: 1.4),
        ),
      ),
    );
  }

  Widget _buildWorkingTimePill({bool inHero = false}) {
    return Container(
      constraints: BoxConstraints(minWidth: inHero ? 150 : 0),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: inHero ? Colors.white.withOpacity(.13) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: inHero ? Colors.white.withOpacity(.22) : const Color(0xFFCFE0FF),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 31,
            height: 31,
            decoration: BoxDecoration(
              color: inHero ? Colors.white.withOpacity(.14) : const Color(0xFF0757D5).withOpacity(.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              Icons.timer_rounded,
              size: 17,
              color: inHero ? Colors.white : const Color(0xFF0757D5),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'LIVE WORKING TIME',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  color: inHero ? Colors.white.withOpacity(.70) : const Color(0xFF6C7F9C),
                  letterSpacing: .65,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                totalWorkingTimeFormatted,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: inHero ? Colors.white : const Color(0xFF124B9B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCFE0FF)),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_clock_rounded, size: 18, color: Color(0xFF0757D5)),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Previous day records are read-only. Select today to continue editing.',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF174A8B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetGrid(List<Map<String, dynamic>> rows, bool isTodayView, bool isMobile) {
    final showAds = _hasAdsColumn();
    final showD1 = _hasDeliverable(1);
    final showD2 = _hasDeliverable(2);
    final showD3 = _hasDeliverable(3);
    final showD4 = _hasDeliverable(4);
    final showD5 = _hasDeliverable(5);
    final showD6 = _hasDeliverable(6);

    final displayRows = rows.where((row) {
      final search = _searchText.trim().toLowerCase();
      if (search.isEmpty) return true;
      final values = [
        row['client'], row['today_plan'], row['remarks'], row['status'],
        row['ads'], row['today_leads'], row['today_report'],
        row['deliverables_1'], row['deliverables_2'], row['deliverables_3'],
        row['deliverables_4'], row['deliverables_5'], row['deliverables_6'],
      ].map((e) => (e ?? '').toString().toLowerCase());
      return values.any((v) => v.contains(search));
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD9E5F6)),
        boxShadow: [
          BoxShadow(color: const Color(0xFF174A8B).withOpacity(.07), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildTableHeaderBar(displayRows.length, isMobile),
          if (displayRows.isEmpty)
            _buildEmptyTableState()
          else
            _buildTableViewport(
              displayRows,
              isTodayView,
              showAds,
              showD1,
              showD2,
              showD3,
              showD4,
              showD5,
              showD6,
              isMobile,
            ),
        ],
      ),
    );
  }

  Widget _buildTableHeaderBar(int count, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 13 : 17, vertical: 13),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0757D5), Color(0xFF0A70E8)],
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.grid_view_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 9),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PLANNER WORKSPACE', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: .9)),
                SizedBox(height: 2),
                Text('Client-wise daily execution board', style: TextStyle(color: Color(0xFFDCEBFF), fontSize: 9.5, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(color: Colors.white.withOpacity(.14), borderRadius: BorderRadius.circular(20)),
            child: Text('$count ROW${count == 1 ? '' : 'S'}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .5)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTableState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 55, horizontal: 20),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.inbox_rounded, color: Color(0xFF0757D5), size: 28),
          ),
          const SizedBox(height: 13),
          const Text('No planner rows found', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1D3557))),
          const SizedBox(height: 5),
          const Text('Add a row or choose another date to view your plan.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Color(0xFF7C8DA6))),
        ],
      ),
    );
  }

  Widget _buildTableViewport(
    List<Map<String, dynamic>> rows,
    bool isTodayView,
    bool showAds,
    bool showD1,
    bool showD2,
    bool showD3,
    bool showD4,
    bool showD5,
    bool showD6,
    bool isMobile,
  ) {
    return SizedBox(
      width: double.infinity,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isMobile ? 155 : 205,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _stickyClientHeader(isMobile),
                ...rows.map((row) => _clientCell(row, isTodayView)),
              ],
            ),
          ),
          Container(width: 1, color: const Color(0xFFBBD0ED)),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxHeight = isMobile ? 600.0 : 650.0;
                return Listener(
                  onPointerSignal: (signal) {
                    if (signal is PointerScrollEvent && _horizontalController.hasClients) {
                      final next = (_horizontalController.offset + signal.scrollDelta.dy)
                          .clamp(0.0, _horizontalController.position.maxScrollExtent);
                      _horizontalController.jumpTo(next);
                    }
                  },
                  child: Scrollbar(
                    controller: _horizontalController,
                    thumbVisibility: false,
                    interactive: true,
                    child: SingleChildScrollView(
                      controller: _horizontalController,
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
                      child: SizedBox(
                        width: _totalGridWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDataHeader(showAds, showD1, showD2, showD3, showD4, showD5, showD6),
                            ...rows.map((row) => _buildDataRow(row, isTodayView, showAds, showD1, showD2, showD3, showD4, showD5, showD6)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _stickyClientHeader(bool isMobile) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: const BoxDecoration(
        color: Color(0xFF0757D5),
        border: Border(bottom: BorderSide(color: Color(0xFF4E8CE6))),
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          const Icon(Icons.business_rounded, size: 16, color: Colors.white),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'CLIENT NAME',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white, fontSize: isMobile ? 9 : 10, fontWeight: FontWeight.w900, letterSpacing: .7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataHeader(bool showAds, bool showD1, bool showD2, bool showD3, bool showD4, bool showD5, bool showD6) {
    final cells = <Widget>[
      const _HeaderCell(width: 140, label: 'MAINTENANCE DATE'),
    ];

    if (showAds) {
      cells.addAll(const [
        _HeaderCell(width: 140, label: 'ADS'),
        _HeaderCell(width: 110, label: 'TODAY LEADS'),
        _HeaderCell(width: 110, label: 'TODAY REPORT'),
      ]);
    }

    void addDeliverable(int n, bool show) {
      if (!show) return;
      cells.addAll([
        _HeaderCell(width: 150, label: 'DELIVERABLES $n'),
        _HeaderCell(width: 150, label: 'COMPLETE $n'),
        _HeaderCell(width: 150, label: 'BALANCED $n'),
      ]);
    }

    addDeliverable(1, showD1);
    addDeliverable(2, showD2);
    addDeliverable(3, showD3);
    addDeliverable(4, showD4);
    addDeliverable(5, showD5);
    addDeliverable(6, showD6);

    cells.addAll(const [
      _HeaderCell(width: 180, label: 'TODAY PLAN'),
      _HeaderCell(width: 130, label: 'STATUS'),
      _HeaderCell(width: 180, label: 'REMARKS'),
      _HeaderCell(width: 130, label: 'ACTION'),
    ]);

    return SizedBox(
      height: 58,
      child: Row(children: cells),
    );
  }

  double get _totalGridWidth {
    double width = 140;
    if (_hasAdsColumn()) width += 140 + 110 + 110;
    if (_hasDeliverable(1)) width += 150 * 3;
    if (_hasDeliverable(2)) width += 150 * 3;
    if (_hasDeliverable(3)) width += 150 * 3;
    if (_hasDeliverable(4)) width += 150 * 3;
    if (_hasDeliverable(5)) width += 150 * 3;
    if (_hasDeliverable(6)) width += 150 * 3;
    return width + 180 + 130 + 180 + 130;
  }

  Future<void> _showClientPicker(Map<String, dynamic> row, bool isTodayView) async {
    if (!isTodayView) return;

    final currentClient = row['client']?.toString() ?? '';
    String search = '';
    final searchCtrl = TextEditingController();

    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(.48),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final filtered = assignedClients.where((client) {
              return client.toLowerCase().contains(search.toLowerCase());
            }).toList();

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              backgroundColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.20),
                        blurRadius: 36,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 20, 14, 18),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF0052CC), Color(0xFF0A70E8)],
                          ),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(.14),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withOpacity(.18)),
                              ),
                              child: const Icon(Icons.business_rounded, color: Colors.white, size: 21),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Select Client', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                                  SizedBox(height: 3),
                                  Text('Choose the client for this planner row', style: TextStyle(color: Color(0xFFDCEBFF), fontSize: 10.5, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              icon: const Icon(Icons.close_rounded, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                        child: TextField(
                          controller: searchCtrl,
                          onChanged: (value) => setDialogState(() => search = value),
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'Search client...',
                            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF0757D5), size: 20),
                            suffixIcon: searchCtrl.text.isEmpty
                                ? null
                                : IconButton(
                                    onPressed: () {
                                      searchCtrl.clear();
                                      setDialogState(() => search = '');
                                    },
                                    icon: const Icon(Icons.close_rounded, size: 17),
                                  ),
                            filled: true,
                            fillColor: const Color(0xFFF6F9FE),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFFDCE8FB)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFFDCE8FB)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFF0757D5), width: 1.4),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        child: Row(
                          children: [
                            const Text('ASSIGNED CLIENTS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: .8)),
                            const Spacer(),
                            Text('${filtered.length}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF0757D5))),
                          ],
                        ),
                      ),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text('No matching clients found', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (_, index) {
                                  final client = filtered[index];
                                  final maintenance = clientMaintenanceDates[client] ?? '';
                                  final allowed = _isClientSelectionAllowed(client, row['id']?.toString());
                                  final selected = currentClient == client;

                                  return Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: !allowed && !selected
                                          ? null
                                          : () {
                                              setState(() {
                                                row['client'] = client;
                                                row['maintenance_date'] = maintenance;
                                                _prefillRoleFieldsForClient(row, client);
                                              });
                                              Navigator.pop(dialogContext);
                                              loadProgress(row);
                                              _scheduleAutoSave(row);
                                            },
                                      borderRadius: BorderRadius.circular(15),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 150),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? const Color(0xFFEAF2FF)
                                              : allowed
                                                  ? const Color(0xFFF8FAFE)
                                                  : const Color(0xFFF3F4F6),
                                          borderRadius: BorderRadius.circular(15),
                                          border: Border.all(
                                            color: selected
                                                ? const Color(0xFF0757D5)
                                                : const Color(0xFFE2E8F0),
                                            width: selected ? 1.3 : 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: selected
                                                    ? const Color(0xFF0757D5)
                                                    : const Color(0xFFEAF2FF),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Icon(
                                                selected ? Icons.check_rounded : Icons.business_rounded,
                                                color: selected ? Colors.white : const Color(0xFF0757D5),
                                                size: 19,
                                              ),
                                            ),
                                            const SizedBox(width: 11),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    client,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w800,
                                                      color: allowed || selected ? const Color(0xFF172B4D) : const Color(0xFF9CA3AF),
                                                    ),
                                                  ),
                                                  if (maintenance.isNotEmpty) ...[
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      'Maintenance • $maintenance',
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(fontSize: 9.5, color: Color(0xFF71819A), fontWeight: FontWeight.w600),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            if (!allowed && !selected)
                                              const Icon(Icons.lock_outline_rounded, size: 17, color: Color(0xFF9CA3AF))
                                            else
                                              Icon(
                                                selected ? Icons.radio_button_checked_rounded : Icons.chevron_right_rounded,
                                                size: 18,
                                                color: selected ? const Color(0xFF0757D5) : const Color(0xFF8CA0BB),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    searchCtrl.dispose();
  }

  Widget _clientCell(Map<String, dynamic> row, bool isTodayView) {
    final currentClient = row['client']?.toString() ?? '';
    final selected = assignedClients.contains(currentClient);

    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF0052CC), Color(0xFF0757D5)],
        ),
        border: const Border(bottom: BorderSide(color: Color(0xFF4E8CE6))),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isTodayView ? () => _showClientPicker(row, isTodayView) : null,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(.10)),
            ),
            child: Row(
              children: [
                Container(
                  width: 29,
                  height: 29,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.13),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.business_rounded, color: Colors.white, size: 15),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    selected ? currentClient : 'Select Client',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white.withOpacity(.78),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 19),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDataRow(
    Map<String, dynamic> row,
    bool isTodayView,
    bool showAds,
    bool showD1,
    bool showD2,
    bool showD3,
    bool showD4,
    bool showD5,
    bool showD6,
  ) {
    final rowEditable = isTodayView;
    return Row(
      children: [
        _textCell(row, 'maintenance_date', 140, false),
        if (showAds) ...[
          _textCell(row, 'ads', 140, false),
          _dropdownCell(row, 'today_leads', 110, yesNoOptions, rowEditable),
          _dropdownCell(row, 'today_report', 110, yesNoOptions, rowEditable),
        ],
        if (showD1) ...[
          _textCell(row, 'deliverables_1', 150, false),
          _textCell(row, 'complete_deliverables_1', 150, false),
          _textCell(row, 'balanced_deliverables_1', 150, false),
        ],
        if (showD2) ...[
          _textCell(row, 'deliverables_2', 150, false),
          _textCell(row, 'complete_deliverables_2', 150, false),
          _textCell(row, 'balanced_deliverables_2', 150, false),
        ],
        if (showD3) ...[
          _textCell(row, 'deliverables_3', 150, false),
          _textCell(row, 'complete_deliverables_3', 150, false),
          _textCell(row, 'balanced_deliverables_3', 150, false),
        ],
        if (showD4) ...[
          _textCell(row, 'deliverables_4', 150, false),
          _textCell(row, 'complete_deliverables_4', 150, false),
          _textCell(row, 'balanced_deliverables_4', 150, false),
        ],
        if (showD5) ...[
          _textCell(row, 'deliverables_5', 150, false),
          _textCell(row, 'complete_deliverables_5', 150, false),
          _textCell(row, 'balanced_deliverables_5', 150, false),
        ],
        if (showD6) ...[
          _textCell(row, 'deliverables_6', 150, false),
          _textCell(row, 'complete_deliverables_6', 150, false),
          _textCell(row, 'balanced_deliverables_6', 150, false),
        ],
        _textCell(row, 'today_plan', 180, rowEditable),
        _dropdownCell(row, 'status', 130, statusOptions, rowEditable, useStatusBadge: true),
        _textCell(row, 'remarks', 180, rowEditable),
        _actionCell(row, isTodayView, rowEditable),
      ],
    );
  }

  Widget _textCell(Map<String, dynamic> row, String field, double width, bool rowEditable) {
    final value = (row[field] ?? '').toString();
    const editableFields = ['today_plan', 'remarks'];
    final canEdit = rowEditable && editableFields.contains(field);
    final bg = _getRowColor((row['status'] ?? '').toString());

    return Container(
      width: width,
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        border: const Border(right: BorderSide(color: Color(0xFFDCE5F2)), bottom: BorderSide(color: Color(0xFFDCE5F2))),
      ),
      alignment: Alignment.centerLeft,
      child: canEdit
          ? TextField(
              controller: TextEditingController(text: value)..selection = TextSelection.collapsed(offset: value.length),
              maxLines: 1,
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF19375E), fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Colors.white.withOpacity(.72),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
                hintText: field == 'today_plan' ? 'Enter today\'s plan...' : 'Add remarks...',
                hintStyle: const TextStyle(fontSize: 9.5, color: Color(0xFF98A8BE)),
              ),
              onChanged: (v) {
                row[field] = v;
                _scheduleAutoSave(row);
              },
            )
          : Text(
              value.isEmpty ? '—' : value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: value.isEmpty ? const Color(0xFF9AAAC0) : const Color(0xFF334D70)),
            ),
    );
  }

  (Color, Color)? _yesNoColors(String field, String value) {
    if (field != 'today_leads' && field != 'today_report') return null;
    switch (value.toUpperCase()) {
      case 'YES':
        return (const Color(0xFFEAF8F2), const Color(0xFF087F5B));
      case 'NO':
        return (const Color(0xFFFDEEEE), const Color(0xFFB42318));
      default:
        return null;
    }
  }

  (Color, Color)? _statusColors(String field, String value) {
    if (field != 'status') return null;
    switch (value.toUpperCase()) {
      case 'COMPLETE':
        return (const Color(0xFFEAF8F2), const Color(0xFF087F5B));
      case 'PENDING':
        return (const Color(0xFFFFF5DD), const Color(0xFF9A6700));
      case 'HOLD':
        return (const Color(0xFFF0F3F8), const Color(0xFF475569));
      case 'PROCESSING':
        return (const Color(0xFFEAF3FF), const Color(0xFF1557B0));
      case 'NOT START':
        return (const Color(0xFFF1F5F9), const Color(0xFF64748B));
      default:
        return null;
    }
  }

  Widget _dropdownCell(
    Map<String, dynamic> row,
    String field,
    double width,
    List<String> options,
    bool isTodayView, {
    bool useStatusBadge = false,
  }) {
    final current = (row[field] ?? '').toString();
    final colorPair = _yesNoColors(field, current) ?? _statusColors(field, current);
    const editableDropdowns = ['today_leads', 'today_report', 'status'];
    final canEdit = isTodayView && editableDropdowns.contains(field);
    final bg = colorPair?.$1 ?? _getRowColor((row['status'] ?? '').toString());

    return Container(
      width: width,
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        border: const Border(right: BorderSide(color: Color(0xFFDCE5F2)), bottom: BorderSide(color: Color(0xFFDCE5F2))),
      ),
      alignment: Alignment.centerLeft,
      child: canEdit
          ? DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: options.contains(current) ? current : null,
                isExpanded: true,
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(12),
                menuMaxHeight: 280,
                hint: const Text('Select', style: TextStyle(fontSize: 10, color: Color(0xFF8EA0B8), fontWeight: FontWeight.w700)),
                icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: colorPair?.$2 ?? const Color(0xFF0757D5)),
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: colorPair?.$2 ?? const Color(0xFF0757D5)),
                items: options.map((o) {
                  final pair = _yesNoColors(field, o) ?? _statusColors(field, o);
                  return DropdownMenuItem<String>(
                    value: o,
                    child: Row(
                      children: [
                        Container(width: 7, height: 7, decoration: BoxDecoration(color: pair?.$2 ?? const Color(0xFF0757D5), shape: BoxShape.circle)),
                        const SizedBox(width: 7),
                        Text(o, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: pair?.$2 ?? const Color(0xFF334D70))),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => row[field] = value);
                  _scheduleAutoSave(row);
                },
              ),
            )
          : _statusBadgeOrText(current, colorPair, useStatusBadge),
    );
  }

  Widget _statusBadgeOrText(String value, (Color, Color)? pair, bool useStatusBadge) {
    if (value.isEmpty) return const Text('—', style: TextStyle(fontSize: 11, color: Color(0xFF9AAAC0)));
    if (!useStatusBadge && pair == null) {
      return Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: Color(0xFF334D70), fontWeight: FontWeight.w600));
    }
    final bg = pair?.$1 ?? const Color(0xFFEAF3FF);
    final fg = pair?.$2 ?? const Color(0xFF0757D5);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: fg)),
    );
  }

  Color _getRowColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETE':
        return const Color(0xFFF2FBF7);
      case 'PENDING':
        return const Color(0xFFFFFCF2);
      case 'PROCESSING':
        return const Color(0xFFF3F8FF);
      case 'HOLD':
        return const Color(0xFFF7F8FB);
      case 'NOT START':
        return const Color(0xFFF8FAFD);
      default:
        return Colors.white;
    }
  }

  Widget _actionCell(Map<String, dynamic> row, bool isTodayView, bool rowEditable) {
    if (!isTodayView) {
      return Container(
        width: 130,
        height: 58,
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFDCE5F2)))),
        alignment: Alignment.center,
        child: const Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFF9AAAC0)),
      );
    }

    return Container(
      width: 130,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: _getRowColor((row['status'] ?? '').toString()), border: const Border(bottom: BorderSide(color: Color(0xFFDCE5F2)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // _smallActionButton(label: 'SAVE', color: const Color(0xFF087F5B), icon: Icons.save_rounded, onTap: () => _saveRow(row, lockRow: false, showMessage: true)),
          // const SizedBox(width: 6),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _confirmDelete(row['id']),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: const Color(0xFFFDEEEE), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFB42318)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallActionButton({required String label, required Color color, required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: Colors.white),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  // Compatibility helpers kept so existing callers/references do not break.
  Widget _buildTopBar(bool isTodayView) => _buildHero(isTodayView, MediaQuery.sizeOf(context).width < 700);

  Widget _summaryCard(
    String title,
    String value,
    Color color,
    IconData icon,
    int count,
    int total,
  ) {
    return _metricCard(title, value, icon, color, total == 0 ? 0 : count / total);
  }

  Widget _productivityCard() {
    final total = dayPlanRows.length;
    final completed = completeCount;
    final score = total == 0 ? 0.0 : completed / total;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE8FB)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            height: 62,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(value: score, strokeWidth: 6, backgroundColor: const Color(0xFFEAF0F9), color: const Color(0xFF0757D5)),
                Text('${(score * 100).round()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF174A8B))),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TODAY\'S PRODUCTIVITY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF71839C), letterSpacing: .7)),
                const SizedBox(height: 4),
                Text('$completed of $total tasks completed', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF19375E))),
              ],
            ),
          ),
          Container(width: 1, height: 42, color: const Color(0xFFE1EAF6)),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('WORKING TIME', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF71839C), letterSpacing: .7)),
              const SizedBox(height: 4),
              Text(totalWorkingTimeFormatted, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0757D5))),
            ],
          ),
        ],
      ),
    );
  }

  String get _formattedTotalWorkingHours => totalWorkingTimeFormatted;

  Widget _statusBadge(String status) {
    final pair = _statusColors('status', status);
    return _statusBadgeOrText(status, pair, true);
  }
}

class _HeaderCell extends StatelessWidget {
  final double width;
  final String label;

  const _HeaderCell({required this.width, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 58,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.centerLeft,
        decoration: const BoxDecoration(
          color: Color(0xFF0757D5),
          border: Border(right: BorderSide(color: Color(0xFF4E8CE6), width: .8)),
        ),
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .35),
        ),
      ),
    );
  }
}
