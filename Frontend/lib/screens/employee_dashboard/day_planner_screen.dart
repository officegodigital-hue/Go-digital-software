import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/gestures.dart';
import 'dart:async';
import '../../services/api_config.dart';


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
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _autoSaveTimer?.cancel();
    _searchController.dispose();
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
  final deliverable =
      (row['deliverables_$i'] ?? '').toString().trim();

  if (deliverable.isNotEmpty) {

    final deliverableList = deliverable
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    int total = deliverableList.length;

    final completeList = <String>[];
    final balancedList = <String>[];

    for (final taskName in deliverableList) {

      // default logic
      completeList.add(taskName);
      balancedList.add(taskName);
    }

    row['complete_deliverables_$i'] =
        "${completeList.join(', ')} (0/$total)";

    row['balanced_deliverables_$i'] =
        "${balancedList.join(', ')} ($total/$total)";


    print(row['complete_deliverables_$i']);
    print(row['balanced_deliverables_$i']);
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
  final response = await http.get(
    Uri.parse('$_baseUrl/day-planner/progress/$employeeName/${Uri.encodeComponent(row["client"])}')
  );

  if (response.statusCode == 200) {
    final json = jsonDecode(response.body);
    final list = List<Map<String, dynamic>>.from(json["data"]);

    // for (int i = 0; i < list.length && i < 3; i++) {
    //   final int index = i + 1;
    //   final int completed = int.tryParse(list[i]["completed"].toString().split('/')[0]) ?? 0;
      
    //   row["deliverables_$index"] = list[i]["deliverable"];
    //   // Update these cells with the actual count
    //   row["complete_deliverables_$index"] = buildProgress(list[i]["deliverable"], completed: completed);
    //   row["balanced_deliverables_$index"] = buildProgress(list[i]["deliverable"], completed: completed, balance: true);
    // }

    for (int i = 0; i < list.length && i < 6; i++) {
  final int index = i + 1;

  row["deliverables_$index"] = list[i]["deliverable"];

  // Don't auto fill
  row["complete_deliverables_$index"] = "";
  row["balanced_deliverables_$index"] = "";
}

    setState(() {});
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
        builder: (context) {
          return AlertDialog(
            title: const Text("Submit Day Planner"),
            content: const Text(
              "After submitting, you cannot edit today's planner.\n\nDo you want to continue?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  "Submit",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
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
      Uri.parse('$_baseUrl/day-planner/total-working-hours/${Uri.encodeComponent(employeeName)}?date=$formattedDate'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      int totalSecs = data['totalSeconds'] ?? 0;
      
      int hours = totalSecs ~/ 3600;
      int minutes = (totalSecs % 3600) ~/ 60;

      setState(() {
        totalWorkingTimeFormatted = '${hours.toString().padLeft(2, '0')}h ${minutes.toString().padLeft(2, '0')}m';
      });
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
    final bool isTodayView = isToday();

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // _buildTopBar(isTodayView),
            // const SizedBox(height: 12),

            _buildTopBar(isTodayView),

const SizedBox(height: 12),

SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  child: Row(
    children: [
      _summaryCard(
        "Total Clients",
        "${dayPlanRows.length}",
        Colors.blue,
        Icons.people,
        dayPlanRows.length,
        dayPlanRows.length,
      ),

      _summaryCard(
        "Completed",
        "${dayPlanRows.where((e) => e['status'] == 'COMPLETE').length}",
        Colors.green,
        Icons.check_circle,
        dayPlanRows.where((e) => e['status'] == 'COMPLETE').length,
        dayPlanRows.length,
      ),

      _summaryCard(
        "Pending",
        "${dayPlanRows.where((e) => e['status'] == 'PENDING').length}",
        Colors.orange,
        Icons.pending_actions,
        dayPlanRows.where((e) => e['status'] == 'PENDING').length,
        dayPlanRows.length,
      ),

      _summaryCard(
        "Processing",
        "${dayPlanRows.where((e) => e['status'] == 'PROCESSING').length}",
        Colors.purple,
        Icons.autorenew,
        dayPlanRows.where((e) => e['status'] == 'PROCESSING').length,
        dayPlanRows.length,
      ),

      _summaryCard(
        "Hold",
        "${dayPlanRows.where((e) => e['status'] == 'HOLD').length}",
        Colors.red,
        Icons.pause_circle,
        dayPlanRows.where((e) => e['status'] == 'HOLD').length,
        dayPlanRows.length,
      ),

      _summaryCard(
        "Not Start",
        "${dayPlanRows.where((e) => e['status'] == 'NOT START').length}",
        Colors.grey,
        Icons.hourglass_empty,
        dayPlanRows.where((e) => e['status'] == 'NOT START').length,
        dayPlanRows.length,
      ),
    ],
  ),
),


// const SizedBox(height: 20),

// _productivityCard(),

const SizedBox(height: 20),
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    // 🟢 Left Side: Search Client Box
    SizedBox(
      width: 320,
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchText = value;
          });
        },
        decoration: InputDecoration(
          hintText: "Search Client...",
          hintStyle: TextStyle(color: Colors.grey.shade500),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Colors.blue,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchText = "";
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.grey.shade100,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 15,
            horizontal: 16,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(
              color: Colors.grey.shade300,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(
              color: Colors.blue,
              width: 2,
            ),
          ),
        ),
      ),
    ),

    // 🟢 Right Side: Total Working Time Widget
    Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        border: Border.all(color: const Color(0xFFBFDBFE)),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_rounded, size: 18, color: Color(0xFF004AAD)),
          const SizedBox(width: 8),
          Text(
            "Total Working Time: $totalWorkingTimeFormatted", // Ungaloda dynamic variable
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
        ],
      ),
    ),
  ],
),
const SizedBox(height: 20),

// // SizedBox(
//   width: 320,
//   child: TextField(
//     controller: _searchController,
//     onChanged: (value) {
//       setState(() {
//         _searchText = value;
//       });
//     },
//     decoration: InputDecoration(
//       hintText: "Search Client...",
//       hintStyle: TextStyle(color: Colors.grey.shade500),

//       prefixIcon: const Icon(
//         Icons.search_rounded,
//         color: Colors.blue,
//       ),

//       suffixIcon: _searchController.text.isNotEmpty
//           ? IconButton(
//               icon: const Icon(Icons.close, size: 18),
//               onPressed: () {
//                 _searchController.clear();
//                 setState(() {
//                   _searchText = "";
//                 });
//               },
//             )
//           : null,

//       filled: true,
//       fillColor: Colors.grey.shade100,

//       contentPadding: const EdgeInsets.symmetric(
//         vertical: 15,
//         horizontal: 16,
//       ),

//       enabledBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(30),
//         borderSide: BorderSide(
//           color: Colors.grey.shade300,
//         ),
//       ),

//       focusedBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(30),
//         borderSide: const BorderSide(
//           color: Colors.blue,
//           width: 2,
//         ),
//       ),
//     ),
//   ),
// ),

// const SizedBox(height: 12),

// Container(
//       height: 48,
//       padding: const EdgeInsets.symmetric(horizontal: 16),
//       decoration: BoxDecoration(
//         color: const Color(0xFFEFF6FF),
//         border: Border.all(color: const Color(0xFFBFDBFE)),
//         borderRadius: BorderRadius.circular(24),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           const Icon(Icons.timer_rounded, size: 18, color: Color(0xFF004AAD)),
//           const SizedBox(width: 8),
//           Text(
//             "Total Working Time: 05h 42m", // Inga ungaloda dynamic variable-ai pass seyyungal
//             style: const TextStyle(
//               fontSize: 12,
//               fontWeight: FontWeight.bold,
//               color: Color(0xFF1E3A8A),
//             ),
//           ),
//         ],
//       ),
//     ),
 
            if (isTodayView && _buildDeadlineBanner() != null)
            _buildDeadlineBanner()!,

            if (!isTodayView)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6)),
                child: const Row(children: [
                  Icon(Icons.info, size: 16, color: Color(0xFF92400E)),
                  SizedBox(width: 8),
                  Text('Previous day records are read-only', style: TextStyle(fontSize: 12, color: Color(0xFF92400E))),
                ]),
              ),
              
            _buildSheetGrid(rows, isTodayView),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isTodayView) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$employeeName · $employeeRole',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
            const SizedBox(height: 4),
            const Text('Day Plan Sheet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        Row(children: [
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              // if (picked != null) setState(() => selectedDate = picked);
              if (picked != null) {

   setState(() {
      selectedDate = picked;
   });

   await loadTodayDayPlan();
   await _checkDeadlineStatus();

}
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF0052CC), width: 1.5),
                borderRadius: BorderRadius.circular(6),
                color: const Color(0xFFF0F4F8),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today, size: 15, color: Color(0xFF0052CC)),
                const SizedBox(width: 8),
                Text(_formatDate(selectedDate),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0052CC))),
              ]),
            ),
          ),
          if (isTodayView) ...[
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: _addRow,
              icon: const Icon(Icons.add, size: 16, color: Colors.white),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0052CC),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              label: const Text('Add Row', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: _submitDay,
              icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.white),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              label: const Text('Submit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ],
        ]),
      ],
    );
  }

Widget _summaryCard(
  String title,
  String value,
  Color color,
  IconData icon,
  int count,
  int total,
) {
  final double percent = total == 0 ? 0 : count / total;

  return Container(
    width: 180,
    margin: const EdgeInsets.only(right: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: color.withOpacity(.25)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.05),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withOpacity(.15),
              child: Icon(icon, color: color, size: 20),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),

        const SizedBox(height: 15),

        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 10),

        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 8,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),

        const SizedBox(height: 6),

        Align(
          alignment: Alignment.centerRight,
          child: Text(
            "${(percent * 100).toStringAsFixed(0)}%",
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _productivityCard() {
  final int total = dayPlanRows.length;
  final int completed = dayPlanRows
      .where((e) => e['status'] == 'COMPLETE')
      .length;

  final double score = total == 0 ? 0 : completed / total;

  String message;
  Color color;

  if (score >= .90) {
    message = "Excellent";
    color = Colors.green;
  } else if (score >= .70) {
    message = "Very Good";
    color = Colors.blue;
  } else if (score >= .50) {
    message = "Good";
    color = Colors.orange;
  } else {
    message = "Needs Improvement";
    color = Colors.red;
  }

  return Container(
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    boxShadow: [
      BoxShadow(
        color: Colors.black12,
        blurRadius: 8,
      ),
    ],
  ),
  child: Row(
    children: [

      /// Productivity
      Expanded(
        flex: 2,
        child: Row(
          children: [

            CircularProgressIndicator(
                value: score,
                strokeWidth: 8,
                color: color,
                backgroundColor: Colors.grey.shade300,
              ),

            const SizedBox(width: 20),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Today's Productivity"),
                Text("Needs Improvement"),
                Text("1 / 3 Tasks Completed"),
              ],
            ),
          ],
        ),
      ),

      VerticalDivider(),

      /// Working Hours
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Text("⏱ Today's Working Time"),

            SizedBox(height: 10),

            Text(
              "05h 42m",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 10),

            Row(
              children: [
                Icon(Icons.circle,
                    size: 10,
                    color: Colors.green),
                SizedBox(width: 6),
                Text("Working"),
              ],
            )
          ],
        ),
      )
    ],
  ),
);
}
  Widget _buildSheetGrid(List<Map<String, dynamic>> rows, bool isTodayView) {
    final showAds = _hasAdsColumn();

final showD1 = _hasDeliverable(1);
final showD2 = _hasDeliverable(2);
final showD3 = _hasDeliverable(3);
final showD4 = _hasDeliverable(4);
final showD5 = _hasDeliverable(5);
final showD6 = _hasDeliverable(6);

final displayRows = rows.where((row) {
  final client =
      (row['client'] ?? '').toString().toLowerCase();

  return client.contains(
    _searchText.toLowerCase(),
  );
}).toList();

    // if (rows.isEmpty) {

    //   return Container(
    //     padding: const EdgeInsets.symmetric(vertical: 40),
    //     alignment: Alignment.center,
    //     child: const Text('No rows for this date.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
    //   );
    // }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 180,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                Container(
                  height: 48,
                  color: const Color(0xFF0052CC),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.centerLeft,
                  child: const Text('CLIENT NAME',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.4)),
                ),
                // ...rows.map((row) => _clientCell(row, isTodayView)),
                ...displayRows.map((row) => _clientCell(row, isTodayView)),
              ]),
            ),
            const VerticalDivider(width: 1, color: Color(0xFFCBD5E1)),
            Flexible(
              child: Listener(
                onPointerSignal: (pointerSignal) {
                  if (pointerSignal is PointerScrollEvent) {
                    final double delta = pointerSignal.scrollDelta.dy;
                    if (delta != 0 && _horizontalController.hasClients) {
                      final newOffset = (_horizontalController.offset + delta).clamp(
                        _horizontalController.position.minScrollExtent,
                        _horizontalController.position.maxScrollExtent,
                      );
                      _horizontalController.jumpTo(newOffset);
                    }
                  }
                },
                child: Scrollbar(
      controller: _horizontalController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _horizontalController,
        scrollDirection: Axis.horizontal,
        child: Column(
          children: [
                      SizedBox(
                        width: _totalGridWidth,
                        height: 48,
                        child: 
                       Row(
children:[
const _HeaderCell(width: 140, label: 'MAINTENANCE DATE'),
if(showAds)...[
  const _HeaderCell(width:140,label:'ADS'),
  const _HeaderCell(width:110,label:'TODAY LEADS'),
  const _HeaderCell(width:110,label:'TODAY REPORT'),
],

if(showD1)...[
  const _HeaderCell(width:150,label:'DELIVERABLES 1'),
  const _HeaderCell(width:150,label:'COMPLETE DELIVERABLES 1'),
  const _HeaderCell(width:150,label:'BALANCED DELIVERABLES 1'),
],

if(showD2)...[
  const _HeaderCell(width:150,label:'DELIVERABLES 2'),
  const _HeaderCell(width:150,label:'COMPLETE DELIVERABLES 2'),
  const _HeaderCell(width:150,label:'BALANCED DELIVERABLES 2'),
],

if(showD3)...[
  const _HeaderCell(width:150,label:'DELIVERABLES 3'),
  const _HeaderCell(width:150,label:'COMPLETE DELIVERABLES 3'),
  const _HeaderCell(width:150,label:'BALANCED DELIVERABLES 3'),
],

if(showD4)...[
  const _HeaderCell(width:150,label:'DELIVERABLES 4'),
  const _HeaderCell(width:150,label:'COMPLETE DELIVERABLES 4'),
  const _HeaderCell(width:150,label:'BALANCED DELIVERABLES 4'),
],

if(showD5)...[
  const _HeaderCell(width:150,label:'DELIVERABLES 5'),
  const _HeaderCell(width:150,label:'COMPLETE DELIVERABLES 5'),
  const _HeaderCell(width:150,label:'BALANCED DELIVERABLES 5'),
],

if(showD6)...[
  const _HeaderCell(width:150,label:'DELIVERABLES 6'),
  const _HeaderCell(width:150,label:'COMPLETE DELIVERABLES 6'),
  const _HeaderCell(width:150,label:'BALANCED DELIVERABLES 6'),
],

const _HeaderCell(width:180,label:'TODAY PLAN'),
const _HeaderCell(width:130,label:'STATUS'),
const _HeaderCell(width:180,label:'REMARKS'),
const _HeaderCell(width:130,label:'ACTION'),

],
)
                      ),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      // ...rows.map((row) => SizedBox(
                      ...displayRows.map((row) => SizedBox(width: _totalGridWidth, child: _buildDataRow(row, isTodayView, showAds, showD1, showD2, showD3,showD4 , showD5, showD6))),
                    ],
        ),
      
                

                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // double get _totalGridWidth => 140 + 110 + 110 + (150 * 9) + 180 + 130 + 180 + 130;
double get _totalGridWidth {

  final showAds = _hasAdsColumn();
  final showD1 = _hasDeliverable(1);
  final showD2 = _hasDeliverable(2);
  final showD3 = _hasDeliverable(3);
  final showD4 = _hasDeliverable(4);
final showD5 = _hasDeliverable(5);
final showD6 = _hasDeliverable(6);

  double width = 140;

  if(showAds){
    width += 140 + 110 + 110;
  }

  if(showD1){
    width += 150 * 3;
  }

  if(showD2){
    width += 150 * 3;
  }

  if(showD3){
    width += 150 * 3;
  }

  if(showD4){
  width += 150 * 3;
}

if(showD5){
  width += 150 * 3;
}

if(showD6){
  width += 150 * 3;
}

  width += 180 + 130 + 180 + 130;

  return width;
}
  
String get _formattedTotalWorkingHours {
  int totalSeconds = 0;
  
  // Ella rows-layum irukkura duration-ai sum seyyungal (unakku thevaiyanal backend field-il irunthu eduthukollalam)
  for (var row in dayPlanRows) {
    // Ungaloda model-la duration iruntha inga add pannalam, 
    // Illana active trackers-oda time-ai sum pannalam.
  }

  // Example format return seiyum helper:
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  return '${hours.toString().padLeft(2, '0')}h ${minutes.toString().padLeft(2, '0')}m';
}

Widget _clientCell(Map<String, dynamic> row, bool isTodayView) {
  return Container(
    height: 54,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: const BoxDecoration(
      color: Color(0xFF0052CC),
      border: Border(
        bottom: BorderSide(color: Color(0xFF0044B3)),
      ),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        isExpanded: true,
        dropdownColor: Colors.white,
        value: assignedClients.contains(row['client'])
            ? row['client']
            : null,
        hint: const Text(
          "Select Client",
          style: TextStyle(color: Colors.white),
        ),
        icon: const Icon(
          Icons.arrow_drop_down,
          color: Colors.white,
        ),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
        items: assignedClients.map((client) {
          return DropdownMenuItem(
            value: client,
            child: Text(client),
          );
        }).toList(),
        onChanged: (value) {
          if (value == null) return;

          setState(() {
            row['client'] = value;

            row['maintenance_date'] =
                clientMaintenanceDates[value] ?? '';

            _prefillRoleFieldsForClient(row, value);
          });

          _scheduleAutoSave(row);
        },
      ),
    ),
  );
}

  Color _getRowColor(String status) {
  switch (status.toUpperCase()) {
    case 'COMPLETE':
      return const Color(0xFFF0FDF4); // Light Green

    case 'PENDING':
      return const Color(0xFFFFFBEB); // Light Yellow

    case 'PROCESSING':
      return const Color(0xFFEFF6FF); // Light Blue

    case 'HOLD':
      return const Color(0xFFFEF2F2); // Light Red

    case 'NOT START':
      return const Color(0xFFF8FAFC); // Light Grey

    default:
      return Colors.white;
  }
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
  // final bool rowEditable = isTodayView && row['_editing'] == true;

  final bool rowEditable = isTodayView;

  return Row(
    children: [

      // Maintenance Date
      _textCell(
        row,
        'maintenance_date',
        140,
        false,
      ),


      // ADS Section
      if (showAds) ...[
        _textCell(
          row,
          'ads',
          140,
          false,
        ),

        _dropdownCell(
          row,
          'today_leads',
          110,
          yesNoOptions,
          rowEditable,
        ),

        _dropdownCell(
          row,
          'today_report',
          110,
          yesNoOptions,
          rowEditable,
        ),
      ],


      // Deliverable 1
      if (showD1) ...[
        _textCell(row, 'deliverables_1', 150, false),
        _textCell(row, 'complete_deliverables_1', 150, false),
        _textCell(row, 'balanced_deliverables_1', 150, false),
      ],


      // Deliverable 2
      if (showD2) ...[
        _textCell(row, 'deliverables_2', 150, false),
        _textCell(row, 'complete_deliverables_2', 150, false),
        _textCell(row, 'balanced_deliverables_2', 150, false),
      ],


      // Deliverable 3
      if (showD3) ...[
        _textCell(row, 'deliverables_3', 150, false),
        _textCell(row, 'complete_deliverables_3', 150, false),
        _textCell(row, 'balanced_deliverables_3', 150, false),
      ],


      // Deliverable 4
      if (showD4) ...[
        _textCell(row, 'deliverables_4', 150, false),
        _textCell(row, 'complete_deliverables_4', 150, false),
        _textCell(row, 'balanced_deliverables_4', 150, false),
      ],


      // Deliverable 5
      if (showD5) ...[
        _textCell(row, 'deliverables_5', 150, false),
        _textCell(row, 'complete_deliverables_5', 150, false),
        _textCell(row, 'balanced_deliverables_5', 150, false),
      ],


      // Deliverable 6
      if (showD6) ...[
        _textCell(row, 'deliverables_6', 150, false),
        _textCell(row, 'complete_deliverables_6', 150, false),
        _textCell(row, 'balanced_deliverables_6', 150, false),
      ],


      // Editable fields only
      _textCell(
        row,
        'today_plan',
        180,
        rowEditable,
      ),


      _dropdownCell(
        row,
        'status',
        130,
        statusOptions,
        rowEditable,
        useStatusBadge: true,
      ),


      _textCell(
        row,
        'remarks',
        180,
        rowEditable,
      ),


      // Actions
      _actionCell(
        row,
        isTodayView,
        rowEditable,
      ),
    ],
  );
}
 Widget _textCell(
  Map<String, dynamic> row,
  String field,
  double width,
  bool rowEditable,
) {

  final value = (row[field] ?? '').toString();

  // Only these fields are editable
  final editableFields = [
    'today_plan',
    'remarks',
  ];

  // final canEdit = rowEditable && editableFields.contains(field);
  final canEdit = editableFields.contains(field);

  return Container(
    width: width,
    height: 54,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: _getRowColor(
        (row['status'] ?? '').toString(),
      ),
      border: const Border(
        right: BorderSide(color: Color(0xFFE2E8F0)),
        bottom: BorderSide(color: Color(0xFFE2E8F0)),
      ),
    ),
    alignment: Alignment.centerLeft,

    child: canEdit

        ? TextField(
            controller: TextEditingController(text: value)
              ..selection = TextSelection.collapsed(
                offset: value.length,
              ),

            maxLines: 1,

            style: const TextStyle(
              fontSize: 11,
            ),

            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: '—',
              hintStyle: TextStyle(
                color: Color(0xFFCBD5E1),
              ),
            ),

            onChanged: (v) {

              row[field] = v;

              // auto update
              _scheduleAutoSave(row);

            },
          )


        : Text(
            value.isEmpty ? '—' : value,

            style: TextStyle(
              fontSize: 11,
              color: value.isEmpty
                  ? const Color(0xFFCBD5E1)
                  : const Color(0xFF334155),
            ),

            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
  );
}
  
  (Color, Color)? _yesNoColors(String field, String value) {
    if (field != 'today_leads' && field != 'today_report') return null;
    switch (value.toUpperCase()) {
      case 'YES':
        return (const Color(0xFFFEF9C3), const Color(0xFF854D0E)); // yellow
      case 'NO':
        return (const Color(0xFFFEE2E2), const Color(0xFFDC2626)); // red
      default:
        return null;
    }
  }

  (Color, Color)? _statusColors(String field, String value) {
    if (field != 'status') return null;
    switch (value.toUpperCase()) {
      case 'COMPLETE':
        return (const Color(0xFFF0FDF4), const Color(0xFF16A34A));
      case 'PENDING':
        return (const Color(0xFFFEF3C7), const Color(0xFFB45309));
      case 'HOLD':
        return (const Color(0xFFF0F4F8), const Color(0xFF1E293B));
      case 'PROCESSING':
        return (const Color(0xFFEFF6FF), const Color(0xFF0369A1));
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
  bool isTodayView,
  {bool useStatusBadge = false}
) {

  final current = (row[field] ?? '').toString();

  final colorPair =
      _yesNoColors(field, current) ??
      _statusColors(field, current);


  // Only these dropdowns are editable
  final editableDropdowns = [
    'today_leads',
    'today_report',
    'status',
  ];


  // final canEdit =
  //     isTodayView &&
  //     editableDropdowns.contains(field);

  final canEdit = editableDropdowns.contains(field);



  return Container(

    width: width,

    height: 54,

    padding: const EdgeInsets.symmetric(horizontal: 8),


    decoration: BoxDecoration(

      border: const Border(
        right: BorderSide(
          color: Color(0xFFE2E8F0),
        ),

        bottom: BorderSide(
          color: Color(0xFFE2E8F0),
        ),
      ),


      color: colorPair?.$1 ??
          _getRowColor(
            (row['status'] ?? '').toString(),
          ),

    ),


    alignment: Alignment.centerLeft,


    child: canEdit

        ?

    DropdownButtonHideUnderline(

      child: DropdownButton<String>(

        value: current.isEmpty
            ? null
            : current,


        isExpanded: true,


        hint: const Text(
          '— Select —',
          style: TextStyle(
            fontSize: 10,
            color: Color(0xFFCBD5E1),
          ),
        ),


        icon: Icon(
          Icons.arrow_drop_down,

          color:
              colorPair?.$2 ??
              const Color(0xFF64748B),

          size: 16,
        ),



        style: TextStyle(

          fontSize: 10,

          fontWeight:
              FontWeight.w700,

          color:
              colorPair?.$2 ??
              const Color(0xFF0052CC),

        ),



        items: options.map(

          (o) => DropdownMenuItem(

            value: o,

            child: Text(o),

          ),

        ).toList(),



        onChanged: (v){

          if(v != null){

            setState((){

              row[field] = v;

            });


            _scheduleAutoSave(row);

          }

        },

      ),

    )



    : Text(

      current.isEmpty
          ? '—'
          : current,


      style: TextStyle(

        fontSize: 11,


        fontWeight:
            colorPair != null
            ? FontWeight.w700
            : FontWeight.normal,


        color:
            colorPair?.$2 ??
            (
              current.isEmpty
              ? const Color(0xFFCBD5E1)
              : const Color(0xFF334155)
            ),

      ),

    ),


  );
}
 
 Widget _actionCell(
  Map<String, dynamic> row,
  bool isTodayView,
  bool rowEditable,
) {
  if (!isTodayView) {
    return Container(
      width: 130,
      height: 54,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
    );
  }

  return Container(
    width: 130,
    height: 54,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: _getRowColor(
        (row['status'] ?? '').toString(),
      ),
      border: const Border(
        bottom: BorderSide(color: Color(0xFFE2E8F0)),
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [

        _smallActionButton(
          label: "SAVE",
          color: const Color(0xFF16A34A),
          icon: Icons.save,
          onTap: () => _saveRow(
            row,
            lockRow: false,
            showMessage: true,
          ),
        ),

        const SizedBox(width: 6),

        GestureDetector(
          onTap: () => _confirmDelete(row['id']),
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(
              Icons.delete_outline,
              size: 14,
              color: Color(0xFFDC2626),
            ),
          ),
        ),
      ],
    ),
  );
}


  Widget _smallActionButton({required String label, required Color color, required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: Colors.white),
            const SizedBox(width: 3),
            Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color bgColor;
    Color textColor;
    switch (status.toUpperCase()) {
      case 'COMPLETE':
        bgColor = const Color(0xFFF0FDF4);
        textColor = const Color(0xFF16A34A);
        break;
      case 'PENDING':
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFB45309);
        break;
      case 'HOLD':
        bgColor = const Color(0xFFF0F4F8);
        textColor = const Color(0xFF1E293B);
        break;
      case 'PROCESSING':
        bgColor = const Color(0xFFEFF6FF);
        textColor = const Color(0xFF0369A1);
        break;
      case 'NOT START':
        bgColor = const Color(0xFFF1F5F9);
        textColor = const Color(0xFF64748B);
        break;
      default:
        bgColor = const Color(0xFFF0F4F8);
        textColor = const Color(0xFF475569);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(3)),
      child: Text(status, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: textColor)),
    );
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: const BoxDecoration(
          color: Color(0xFFF1F5F9),
          border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.2),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
