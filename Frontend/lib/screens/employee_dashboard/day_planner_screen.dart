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

  DateTime selectedDate = DateTime.now();
  String employeeName = '';
  String employeeRole = '';

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

  static const List<String> statusOptions = ['NOT START', 'PENDING', 'COMPLETE', 'HOLD', 'PROCESSING'];
  static const List<String> yesNoOptions = ['YES', 'NO'];

  String _deadlineLevel = 'none'; // 'none' | 'warning' | 'urgent' | 'admin_notified'

// Update your function signature and logic
// String buildProgress(String taskString, {int completed = 0, bool balance = false}) {
//   if (taskString.trim().isEmpty) return '';

//   List<String> result = [];

//   for (final part in taskString.split(',')) {
//     final item = part.trim();
//     final match = RegExp(r'^(.*?)\((\d+)\)$').firstMatch(item);

//     String task;
//     int total;

//     if (match != null) {
//       task = match.group(1)!.trim();
//       total = int.parse(match.group(2)!);
//     } else {
//       task = item;
//       total = 1; 
//     }

//     result.add(
//       balance
//           ? '$task(${total - completed}/$total)'
//           : '$task($completed/$total)',
//     );
//   }

//   return result.join(', ');
// }
 
  // FIX: rows now carry a local '_editing' flag. New rows start unlocked
  // (editable) so you can fill them in immediately; existing/previously
  // saved rows start locked (read-only) until Edit is tapped, then Save
  // locks them again. This is the Edit/Save workflow that was missing.
  List<Map<String, dynamic>> dayPlanRows = [
    // {
    //   'id': 1,
    //   'date': DateTime.now(),
    //   'client': '',
    //   'ads': '',
    //   'today_leads': '',
    //   'today_report': '',
    //   'deliverables_1': '',
    //   'complete_deliverables_1': '',
    //   'balanced_deliverables_1': '',
    //   'deliverables_2': '',
    //   'complete_deliverables_2': '',
    //   'balanced_deliverables_2': '',
    //   'deliverables_3': '',
    //   'complete_deliverables_3': '',
    //   'balanced_deliverables_3': '',
    //   'today_plan': '',
    //   'status': '',
    //   'remarks': '',
    //   '_editing': true,
    // },
  ];

bool _didInitialLoad = false;

  @override
  void initState() {
    super.initState();
    // FIX: removed loadAssignedClients()/loadTodayDayPlan() from here —
    // employeeName is still '' at this point, so both calls were hitting
    // the backend with a blank name.
  }

  @override
  void dispose() {
    _horizontalController.dispose();
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
    }
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

  // Clear previous values
  row['ads'] = '';
  row['deliverables_1'] = '';
  row['deliverables_2'] = '';
  row['deliverables_3'] = '';

  final clientTasks = assignedTasks.where(
    (task) =>
        (task['client_name'] ?? '').toString() == clientName,
  );

  for (final task in clientTasks) {

    //---------------------------------------------
    // ADS HANDLER
    //---------------------------------------------
    final adsEmployee =
        (task['ads_handling'] ?? '').toString().trim().toUpperCase();

    if (adsEmployee == myName) {
      row['ads'] = task['ads_platform'] ?? '';
    }

    //---------------------------------------------
    // PAGE HANDLER
    //---------------------------------------------
    final pageEmployee =
        (task['page_handling'] ?? '').toString().trim().toUpperCase();

    //---------------------------------------------
    // DESIGNER
    //---------------------------------------------
    final designerEmployee =
        (task['designer'] ?? '').toString().trim().toUpperCase();

    final pageTask =
        (task['pages_platform'] ?? '').toString();

    final designerTask =
        (task['designer_tasks'] ?? '').toString();

    bool isPageAssigned = pageEmployee == myName;
    bool isDesignerAssigned = designerEmployee == myName;

    //---------------------------------------------
    // ONLY PAGE HANDLER
    //---------------------------------------------
    if (isPageAssigned && !isDesignerAssigned) {

      row['deliverables_1'] = pageTask;

    }

    //---------------------------------------------
    // ONLY DESIGNER
    //---------------------------------------------
    else if (!isPageAssigned && isDesignerAssigned) {

      row['deliverables_1'] = designerTask;

    }

    //---------------------------------------------
    // BOTH PAGE + DESIGNER
    //---------------------------------------------
    else if (isPageAssigned && isDesignerAssigned) {

      row['deliverables_1'] = pageTask;

      row['deliverables_2'] = designerTask;

    }

    //---------------------------------------------
    // VIDEOGRAPHER (optional)
    //---------------------------------------------
    final videoEmployee =
        (task['videographer'] ?? '').toString().trim().toUpperCase();

    if (videoEmployee == myName) {
      row['deliverables_3'] =
          task['videographer_tasks'] ?? '';
    }

    //---------------------------------------------
    // DEVELOPER (optional)
    //---------------------------------------------
    final developerEmployee =
        (task['developer'] ?? '').toString().trim().toUpperCase();

    if (developerEmployee == myName &&
        (row['deliverables_3'] ?? '').toString().isEmpty) {

      row['deliverables_3'] =
          task['developer_tasks'] ?? '';

    }

    //---------------------------------------------
    // UI UX (optional)
    //---------------------------------------------
    final uiuxEmployee =
        (task['ui_ux_designer'] ?? '')
            .toString()
            .trim()
            .toUpperCase();

    if (uiuxEmployee == myName &&
        (row['deliverables_3'] ?? '').toString().isEmpty) {

      row['deliverables_3'] =
          task['ui_ux_tasks'] ?? '';

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
            'today_plan': item['today_plan'] ?? '',
            'status': item['status'] ?? '',
            'remarks': item['remarks'] ?? '',
            '_editing': false, // Existing records are read-only
          });
        }

        // Only add an empty row if the list is empty AND we are looking at today's date
      //   if (dayPlanRows.isEmpty && isToday()) {
      //     dayPlanRows.add({
      //       'id': DateTime.now().millisecondsSinceEpoch,
      //       'date': selectedDate, // Use selectedDate instead of DateTime.now()
      //       'client': '',
      //       'ads': '',
      //       'today_leads': '',
      //       'today_report': '',
      //       'deliverables_1': '',
      //       'complete_deliverables_1': '',
      //       'balanced_deliverables_1': '',
      //       'deliverables_2': '',
      //       'complete_deliverables_2': '',
      //       'balanced_deliverables_2': '',
      //       'deliverables_3': '',
      //       'complete_deliverables_3': '',
      //       'balanced_deliverables_3': '',
      //       'today_plan': '',
      //       'status': '',
      //       'remarks': '',
      //       '_editing': true, // New rows start as editable
      //     });
      //   }
      });
    } 
    else {
      debugPrint('Failed to load day plan: ${response.statusCode}');
    }
  } catch (e) {
    debugPrint('Error in loadTodayDayPlan: $e');
  }
}

  Future<void> loadAssignedClients() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final name = auth.user?['fullName'] as String?;
    if (name == null || name.isEmpty) return;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/employee-tasks/by-employee/${Uri.encodeComponent(name)}'),
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
        for (final row in rows) {
          final matchesEmployee = roleColumns.any((col) {
            final val = row[col];
            return val != null && val.toString().toUpperCase() == nameUpper;
          });
          if (matchesEmployee) {
            final clientName = row['client_name']?.toString() ?? '';
            if (clientName.isNotEmpty) uniqueClients.add(clientName);
          }
        }

        setState(() {
          assignedTasks = rows;
          assignedClients = uniqueClients.toList();
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

    for (int i = 0; i < list.length && i < 3; i++) {
  final int index = i + 1;

  row["deliverables_$index"] = list[i]["deliverable"];

  // Don't auto fill
  row["complete_deliverables_$index"] = "";
  row["balanced_deliverables_$index"] = "";
}

    setState(() {});
  }
}
  // void _addRow() {
  //   setState(() {
  //     dayPlanRows.add({
  //       'id': DateTime.now().millisecondsSinceEpoch,
  //       'date': selectedDate,
  //       'client': assignedClients.isNotEmpty ? assignedClients.first : '',
  //       'ads': '',
  //       'today_leads': '',
  //       'today_report': '',
  //       'deliverables_1': '',
  //       'complete_deliverables_1': '',
  //       'balanced_deliverables_1': '',
  //       'deliverables_2': '',
  //       'complete_deliverables_2': '',
  //       'balanced_deliverables_2': '',
  //       'deliverables_3': '',
  //       'complete_deliverables_3': '',
  //       'balanced_deliverables_3': '',
  //       'today_plan': '',
  //       'status': '',
  //       'remarks': '',
  //       'date': selectedDate,
  //       '_editing': true,
  //     });
  //   });
  // }

  // FIX: this now actually creates the row on the backend first and uses
  // the REAL database id — the fake millisecond id was why new rows always
  // failed to save (PUT to a nonexistent id returns 404 silently).
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
            'ads': '', 'today_leads': '', 'today_report': '',
            'deliverables_1': '', 'complete_deliverables_1': '', 'balanced_deliverables_1': '',
            'deliverables_2': '', 'complete_deliverables_2': '', 'balanced_deliverables_2': '',
            'deliverables_3': '', 'complete_deliverables_3': '', 'balanced_deliverables_3': '',
            'today_plan': '', 'status': '', 'remarks': '',
            '_editing': true,
          });
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

  // void _saveRow(Map<String, dynamic> row) {
  //   setState(() => row['_editing'] = false);
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     const SnackBar(content: Text('✅ Row saved'), backgroundColor: Color(0xFF16A34A), duration: Duration(seconds: 2)),
  //   );
  // }

  // PUT /api/day-planner/:id — sends this row's current field values to the
// backend, then locks the row (read-only) on success.
Future<void> _saveRow(Map<String, dynamic> row) async {
  final id = row['id'];

  try {
    final body = {
      'client': row['client'] ?? '',
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
        row['_editing'] = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Saved Successfully"),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.body),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    print(e);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.toString()),
        backgroundColor: Colors.red,
      ),
    );
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

  // FIX: bulk-locks every editable row for today at once — the "Submit"
  // button next to Add Row, for when you're done filling the whole sheet
  // and don't want to hit Save on each row individually.
  void _submitDay() {
    setState(() {
      for (final row in filteredRows) {
        row['_editing'] = false;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Day plan submitted'), backgroundColor: Color(0xFF16A34A), duration: Duration(seconds: 2)),
    );
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
            _buildTopBar(isTodayView),
            const SizedBox(height: 12),
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

  // ── Spreadsheet-style grid: frozen CLIENT column + wide scrollable rest ──
  // FIX: no longer wrapped in Expanded — sizes to its content (header +
  // however many rows exist), letting the outer page scroll vertically.
  Widget _buildSheetGrid(List<Map<String, dynamic>> rows, bool isTodayView) {
    final showAds = _hasAdsColumn();

final showD1 = _hasDeliverable(1);
final showD2 = _hasDeliverable(2);
final showD3 = _hasDeliverable(3);

final displayRows = rows;

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

const _HeaderCell(width:180,label:'TODAY PLAN'),
const _HeaderCell(width:130,label:'STATUS'),
const _HeaderCell(width:180,label:'REMARKS'),
const _HeaderCell(width:130,label:'ACTION'),

],
)
                      ),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      // ...rows.map((row) => SizedBox(
                      ...displayRows.map((row) => SizedBox(width: _totalGridWidth, child: _buildDataRow(row, isTodayView, showAds, showD1, showD2, showD3))),
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

  double width = 0;

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

  width += 180 + 130 + 180 + 130;

  return width;
}
  
  Widget _clientCell(Map<String, dynamic> row, bool isTodayView) {
    final current = (row['client'] ?? '').toString();
    final bool rowEditable = isTodayView && row['_editing'] == true;
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0052CC),
        border: Border(bottom: BorderSide(color: Color(0xFF0044B3))),
      ),
      child: rowEditable
          ? DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: current.isEmpty ? null : current,
                isExpanded: true,
                hint: const Text('— Select —', style: TextStyle(fontSize: 11, color: Colors.white70)),
                dropdownColor: const Color(0xFF1A5FCC),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                items: assignedClients.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                // onChanged: (v) {
                //   if (v != null) {
                //     setState(() {
                //       row['client'] = v;
                //       _prefillRoleFieldsForClient(row, v);
                //     });
                //   }
                // },
                onChanged: (v) async {
  if (v != null) {
    setState(() {
      row['client'] = v;

      // Prefill only Ads and Deliverables
      _prefillRoleFieldsForClient(row, v);

      // Keep Complete & Balanced empty
      row['complete_deliverables_1'] = '';
      row['balanced_deliverables_1'] = '';

      row['complete_deliverables_2'] = '';
      row['balanced_deliverables_2'] = '';

      row['complete_deliverables_3'] = '';
      row['balanced_deliverables_3'] = '';
    });

    // Remove this if you don't want auto progress
    // await loadProgress(row);
  }
}
              ),
            )
          : Align(
              alignment: Alignment.centerLeft,
              child: Text(current.isEmpty ? '—' : current,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
    );
  }

  Widget _buildDataRow(Map<String, dynamic> row, bool isTodayView,bool showAds,bool showD1,bool showD2,bool showD3) {
    final bool rowEditable = isTodayView && row['_editing'] == true;
    return 
  Row(
children:[

if(showAds)...[
  _textCell(row,'ads',140,rowEditable),
  _dropdownCell(row,'today_leads',110,yesNoOptions,rowEditable),
  _dropdownCell(row,'today_report',110,yesNoOptions,rowEditable),
],

if(showD1)...[
  _textCell(row,'deliverables_1',150,rowEditable),
  _textCell(row,'complete_deliverables_1',150,rowEditable),
  _textCell(row,'balanced_deliverables_1',150,rowEditable),
],

if(showD2)...[
  _textCell(row,'deliverables_2',150,rowEditable),
  _textCell(row,'complete_deliverables_2',150,rowEditable),
  _textCell(row,'balanced_deliverables_2',150,rowEditable),
],

if(showD3)...[
  _textCell(row,'deliverables_3',150,rowEditable),
  _textCell(row,'complete_deliverables_3',150,rowEditable),
  _textCell(row,'balanced_deliverables_3',150,rowEditable),
],

_textCell(row,'today_plan',180,rowEditable),
_dropdownCell(row,'status',130,statusOptions,rowEditable,useStatusBadge:true),
_textCell(row,'remarks',180,rowEditable),
_actionCell(row,isTodayView,rowEditable),

],
);
}

  Widget _textCell(Map<String, dynamic> row, String field, double width, bool rowEditable) {
    final value = (row[field] ?? '').toString();
    return Container(
      width: width,
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: Color(0xFFE2E8F0)),
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      alignment: Alignment.centerLeft,
      child: rowEditable
          ? TextField(
              controller: TextEditingController(text: value)
                ..selection = TextSelection.collapsed(offset: value.length),
              maxLines: 1,
              style: const TextStyle(fontSize: 11),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: '—',
                hintStyle: TextStyle(color: Color(0xFFCBD5E1)),
              ),
              onChanged: (v) => row[field] = v,
            )
          : Text(
              value.isEmpty ? '—' : value,
              style: TextStyle(fontSize: 11, color: value.isEmpty ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
    );
  }

  // FIX: Today Leads / Today Report now show yellow for YES and red for NO
  // — as a colored background, in both the editable dropdown and the
  // read-only view, not just as plain text. Status reuses its existing
  // badge colors as the cell background so the dropdown itself is
  // color-coded too, not just the read-only badge.
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

  Widget _dropdownCell(Map<String, dynamic> row, String field, double width, List<String> options, bool rowEditable,
      {bool useStatusBadge = false}) {
    final current = (row[field] ?? '').toString();
    final colorPair = _yesNoColors(field, current) ?? _statusColors(field, current);

    return Container(
      width: width,
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: const Border(
          right: BorderSide(color: Color(0xFFE2E8F0)),
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
        color: colorPair?.$1,
      ),
      alignment: Alignment.centerLeft,
      child: rowEditable
          ? DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: current.isEmpty ? null : current,
                isExpanded: true,
                hint: const Text('— Select —', style: TextStyle(fontSize: 10, color: Color(0xFFCBD5E1))),
                icon: Icon(Icons.arrow_drop_down, color: colorPair?.$2 ?? const Color(0xFF64748B), size: 16),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: colorPair?.$2 ?? const Color(0xFF0052CC)),
                items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => row[field] = v);
                },
              ),
            )
          : Text(
              current.isEmpty ? '—' : current,
              style: TextStyle(
                fontSize: 11,
                fontWeight: colorPair != null ? FontWeight.w700 : FontWeight.normal,
                color: colorPair?.$2 ?? (current.isEmpty ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
              ),
            ),
    );
  }

  // FIX: this is the Edit/Save/Delete action column. Previous-day rows
  // (isTodayView == false) get no buttons at all — pure read-only. Today's
  // rows show Edit (unlocks the row) when locked, or Save (locks it again)
  // when unlocked, plus Delete always available for today's rows.
  Widget _actionCell(Map<String, dynamic> row, bool isTodayView, bool rowEditable) {
    if (!isTodayView) {
      return Container(
        width: 130,
        height: 54,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        ),
      );
    }

    return Container(
      width: 130,
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (rowEditable)
            _smallActionButton(
              label: 'SAVE',
              color: const Color(0xFF16A34A),
              icon: Icons.check,
              onTap: () => _saveRow(row),
            )
          else
            _smallActionButton(
              label: 'EDIT',
              color: const Color(0xFF0052CC),
              icon: Icons.edit,
              onTap: () => _editRow(row),
            ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _deleteRow(row['id']),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(4)),
              child: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFDC2626)),
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
