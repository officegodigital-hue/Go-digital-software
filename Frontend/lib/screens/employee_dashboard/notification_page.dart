import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_config.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class DayPlanTableViewer extends StatefulWidget {
  final String employeeName;
  final String date;
  const DayPlanTableViewer({super.key, required this.employeeName, required this.date});
 @override
  State<DayPlanTableViewer> createState() => _DayPlanTableViewerState();
}

class _DayPlanTableViewerState extends State<DayPlanTableViewer> {
  List<Map<String, dynamic>> rows = [];
  final ScrollController _verticalController = ScrollController();
final ScrollController _horizontalController = ScrollController();
 bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDayPlan();
  }

  @override
void dispose() {
  _verticalController.dispose();
  _horizontalController.dispose();
  super.dispose();
}

  Future<void> _fetchDayPlan() async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/day-planner/today/${Uri.encodeComponent(widget.employeeName)}?date=${widget.date}');
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        debugPrint("DAY PLAN RESPONSE = ${res.body}");
        setState(() {
          rows = List<Map<String, dynamic>>.from(decoded is List ? decoded : (decoded['data'] ?? []));
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  List<DataColumn> _buildColumns() {
    return [
      const DataColumn(label: Text("Client Name")),
      const DataColumn(label: Text("Today Plan")),
      const DataColumn(label: Text("Status")),
      const DataColumn(label: Text("Remarks")),
    ];
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor = const Color(0xFFF1F5F9);
    Color textColor = const Color(0xFF64748B);
    switch (status.toUpperCase()) {
      case 'COMPLETE':
        bgColor = const Color(0xFFF0FDF4);
        textColor = const Color(0xFF16A34A);
        break;
      case 'PENDING':
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFB45309);
        break;
      case 'PROCESSING':
        bgColor = const Color(0xFFEFF6FF);
        textColor = const Color(0xFF0369A1);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(4)),
      child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
    );
  }

@override
Widget build(BuildContext context) {
  if (isLoading) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  if (rows.isEmpty) {
    return const Center(
      child: Text(
        "No Day Plan Data Found",
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey,
        ),
      ),
    );
  }

  return SizedBox(
    width: 1200,
    height: 500,
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xffCBD5E1),
        ),
      ),
      child: Scrollbar(
        controller: _verticalController,
        thumbVisibility: true,
        trackVisibility: true,
        interactive: true,
        child: SingleChildScrollView(
          controller: _verticalController,
          scrollDirection: Axis.vertical,
          child: Scrollbar(
            controller: _horizontalController,
            thumbVisibility: true,
            trackVisibility: true,
            interactive: true,
            notificationPredicate: (notification) =>
                notification.depth == 1,
            child: SingleChildScrollView(
              controller: _horizontalController,
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 55,
                dataRowMinHeight: 85,
                dataRowMaxHeight: 85,
                columnSpacing: 25,
                dividerThickness: 1,
                border: TableBorder.all(
                  color: const Color(0xffCBD5E1),
                ),
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xff0F4CC9),
                ),
                columns: const [
                  DataColumn(
                    label: Text(
                      "CLIENT NAME",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      "ADS",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      "LEADS",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      "REPORT",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      "DELIVERABLE 1",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      "COMPLETE",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      "BALANCE",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      "TODAY PLAN",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      "STATUS",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      "REMARKS",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                rows: List.generate(rows.length, (index) {
                  final r = rows[index];

                  return DataRow(
                    color: WidgetStateProperty.all(
                      index.isEven
                          ? Colors.white
                          : const Color(0xffF8FAFC),
                    ),
                    cells: [
                      // CLIENT
                      DataCell(
                        Container(
                          width: 160,
                          height: double.infinity,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          color: const Color(0xff0F4CC9),
                          child: Text(
                            r["client"] ?? "-",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      // ADS
                      DataCell(
                        SizedBox(
                          width: 220,
                          child: Text(
                            r["ads"] ?? "-",
                            softWrap: true,
                          ),
                        ),
                      ),

                      // LEADS
                      DataCell(
                        Text(
                          r["today_leads"] ?? "-",
                        ),
                      ),

                      // REPORT
                      DataCell(
                        Text(
                          r["today_report"] ?? "-",
                        ),
                      ),

                      // DELIVERABLE
                      DataCell(
                        SizedBox(
                          width: 250,
                          child: Text(
                            r["deliverables_1"] ?? "-",
                            softWrap: true,
                          ),
                        ),
                      ),

                      // COMPLETE
                      DataCell(
                        Text(
                          r["complete_deliverables_1"] ?? "-",
                        ),
                      ),

                      // BALANCE
                      DataCell(
                        Text(
                          r["balanced_deliverables_1"] ?? "-",
                        ),
                      ),

                      // TODAY PLAN
                      DataCell(
                        SizedBox(
                          width: 180,
                          child: Text(
                            r["today_plan"] ?? "-",
                            softWrap: true,
                          ),
                        ),
                      ),

                      // STATUS
                      DataCell(
                        _buildStatusBadge(
                          (r["status"] ?? "-").toString(),
                        ),
                      ),

                      // REMARKS
                      DataCell(
                        SizedBox(
                          width: 200,
                          child: Text(
                            r["remarks"] ?? "-",
                            softWrap: true,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static String get _baseUrl => ApiConfig.baseUrl;
  String? _selectedEmployee;
  String? _loggedInEmployee;
  List<Map<String, dynamic>> notificationLogs = [];
  bool _loading = true;
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Warning & Alert',
    'Task Assigned',
    'Task Review',
    'Content Shared',
    'Daily Planner'
  ];

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

debugPrint("Logged In Employee = $_loggedInEmployee");

    setState(() => _loading = true);

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/notifications/${Uri.encodeComponent(_loggedInEmployee!)}'),
      );

      if (response.statusCode != 200) {
        setState(() => _loading = false);
        return;
      }

      final body = jsonDecode(response.body);
      final List rows = body["data"] ?? [];

      notificationLogs = [];
debugPrint("Total Rows = ${rows.length}");
debugPrint("API RESPONSE = ${response.body}");

      for (final row in rows) {

        debugPrint("ROW = ${jsonEncode(row)}");

       final sender = (row["senderName"] ?? "").toString().trim();
final recipient = (row["recipientName"] ?? "").toString().trim();

final bool isSentByMe = row["type"] == "SENT";

// final String otherParty = isSentByMe ? recipient : sender;
String otherParty = isSentByMe ? recipient : sender;

// Normalize name
otherParty = otherParty.trim().toUpperCase();
final rawMessage = (row["message"] ?? "").toString();
debugPrint("RAW MESSAGE: $rawMessage");

        String displayMessage = rawMessage;
        String categoryTag = 'General';

        debugPrint(row.toString());

        if (rawMessage.startsWith("PLAN_SUBMITTED")) {
          categoryTag = 'Daily Planner';
          displayMessage = "Day plan submission record.";
        } else {
          try {
            final json = jsonDecode(rawMessage);
            debugPrint("JSON: $json");
debugPrint("PAYLOAD: ${json["payload"]}");
            if (json is Map<String, dynamic>) {
              // displayMessage = json["preview"] ?? json["title"] ?? json["contentType"] ?? json["content"] ?? "Notification";
              displayMessage =
      json["preview"] ??
      json["message"] ??
      json["content"] ??
      json["description"] ??
      json["remarks"] ??
      json["title"] ??
      json["contentType"] ??
      "Notification";
              // final typeStr = (json["type"] ?? "").toString().toUpperCase();
              final payload =
    json["payload"] is Map<String, dynamic>
        ? json["payload"] as Map<String, dynamic>
        : {};
final typeStr = (
  payload["type"] ??
  json["type"] ??
  ""
).toString().toUpperCase();

debugPrint("FINAL TYPE = $typeStr");

debugPrint("TYPE = $typeStr");
              
              // if (typeStr.contains("TASK_ASSIGN") || typeStr.contains("TASK")) {
              //   categoryTag = 'Task Assigned';
              // } else if (typeStr.contains("REVIEW") || typeStr.contains("MANAGER_REVIEW") || typeStr.contains("ACTION")) {
              //   categoryTag = 'Task Review';
              // } else if (typeStr.contains("CONTENT") || typeStr.contains("VIDEOGRAPHER") || typeStr.contains("SHARED")) {
              //   categoryTag = 'Content Shared';
              // } else if (typeStr.contains("WARN") || typeStr.contains("ALERT") || typeStr.contains("UNSUBMITTED")) {
              //   categoryTag = 'Warning & Alert';
              // } else if (typeStr.contains("PLAN")) {
              //   categoryTag = 'Daily Planner';
              // }

bool categoryMatched = false;

switch (typeStr) {

  case "TASK_REVIEW":
  case "MANAGER_REVIEW":
    categoryTag = "Task Review";
    categoryMatched = true;
    break;


  case "TASK_PLANNER_SHARE":
  case "VIDEOGRAPHER_SHARE":
    categoryTag = "Content Shared";
    categoryMatched = true;
    break;


  case "TASK_ASSIGNED":
  case "TASK_ASSIGN":
    categoryTag = "Task Assigned";
    categoryMatched = true;
    break;

    case "PLAN_SUBMITTED":
    case "DAY_PLAN_SUBMITTED":
    categoryTag = "Daily Planner";
    break;

    case "DAY_PLANNER_REMINDER":
case "DAY_PLANNER_ALERT":
case "DAY_PLANNER_WARNING":
case "DAY_PLANNER_ADMIN_WARNING":
  categoryTag = "Warning & Alert";
  break;

}


// Only run fallback if no exact match found
if (!categoryMatched) {

  if (typeStr.contains("WARN") ||
      typeStr.contains("ALERT")) {

    categoryTag = "Warning & Alert";

  } 
  else if (typeStr.contains("REVIEW") ||
           typeStr.contains("APPROVED") ||
           typeStr.contains("REWORK") ||
           typeStr.contains("REJECT")) {

    categoryTag = "Task Review";

  }
  // ✅ TASK PLANNER must be Content Shared
  else if (typeStr.contains("TASK_PLANNER") ||
           typeStr.contains("SHARE") ||
           typeStr.contains("CONTENT") ||
           typeStr.contains("VIDEO")) {

    categoryTag = "Content Shared";

  }
  // ✅ Only actual day planner notifications
  else if (typeStr.contains("DAY_PLANNER") ||
           typeStr == "PLAN_SUBMITTED" ||
           typeStr == "DAY_PLAN_SUBMITTED") {

    categoryTag = "Daily Planner";

  }
  else if (typeStr.contains("TASK") ||
           typeStr.contains("ASSIGN")) {

    categoryTag = "Task Assigned";

  }
}


debugPrint("TYPE = $typeStr");
debugPrint("CATEGORY = $categoryTag");
            }
          } catch (_) {
            final lower = rawMessage.toLowerCase();
            if (lower.contains("warning") || lower.contains("alert") || lower.contains("unsubmitted")) {
              categoryTag = 'Warning & Alert';
            } else if (lower.contains("task assigned") || lower.contains("task")) {
              categoryTag = 'Task Assigned';
            } else if (lower.contains("reviewed") || lower.contains("manager") || lower.contains("approved") || lower.contains("rework")) {
              categoryTag = 'Task Review';
            } else if (lower.contains("content") || lower.contains("video") ) {
              categoryTag = 'Content Shared';
            } else if (lower.contains("plan")) {
              categoryTag = 'Daily Planner';
            }
          }
        }

        notificationLogs.add({
          "id": row["id"],
          "senderName": sender,
          "recipientName": recipient,
          "initials": _initialsFor(otherParty),
          "name": otherParty,
          "rawMessage": rawMessage,
          "message": displayMessage,
          "category": categoryTag,
          "time": row["time"] ?? "",
          "type": row["type"],          // ADD THIS

          "isSentByMe": isSentByMe,
          "isSeen": row["isSeen"] ?? false,
          "isFavorite": row["isFavorite"] ?? false,
          "isArchived": row["isArchived"] ?? false,
        });
      }
      debugPrint("Final Notification Count = ${notificationLogs.length}");
      setState(() => _loading = false);
    } catch (e) {
      debugPrint("Fetch Error: $e");
      setState(() => _loading = false);
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
    } catch (_) {}
  }

  Future<void> _deleteNotification(Map<String, dynamic> log) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
  elevation: 8,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(18),
  ),
        title: const Text("Delete Notification", style: TextStyle(color: Color(0xFF0052CC), fontWeight: FontWeight.bold)),
        content: const Text("Would you like to delete this message for yourself or completely for everyone?"),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => notificationLogs.remove(log));
              await http.delete(Uri.parse('$_baseUrl/notifications/${log["id"]}?mode=me'));
            },
            child: const Text("Delete for Me", style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0052CC), foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => notificationLogs.remove(log));
              await http.delete(Uri.parse('$_baseUrl/notifications/${log["id"]}?mode=everyone'));
            },
            child: const Text("Delete for Everyone"),
          ),
        ],
      ),
    );
  }

  List<String> get _uniqueEmployees {
    // final names = notificationLogs.map((log) => log["name"] as String).toSet().toList();
    final names = notificationLogs
    .map((log) => (log["name"] as String).trim().toUpperCase())
    .toSet()
    .toList();
    names.sort();
    return names;
  }

  List<Map<String, dynamic>> get _filteredNotifications {
    return notificationLogs.where((log) {
      if (_selectedEmployee != null && log["name"] != _selectedEmployee) {
        return false;
      }
      if (_selectedCategory != 'All' && log["category"] != _selectedCategory) {
        return false;
      }
      return true;
    }).toList();
  }

  void _showDayPlanPopup(String empName, String date) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
  elevation: 8,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(18),
  ),
        title: Text("Day Plan Details: $empName ($date)", style: const TextStyle(color: Color(0xFF0052CC), fontWeight: FontWeight.bold)),
        // content: SizedBox(
        //   width: 900,
        //   height: 500,
        //   child: DayPlanTableViewer(employeeName: empName, date: date),
        // ),
        content: SizedBox(
  width: 1250,
  height: 550,
  child: DayPlanTableViewer(
    employeeName: empName,
    date: date,
  ),
),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0052CC), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _showDayPlanPopupFromNotification(
String employee,
String date,
List<Map<String,dynamic>> plannerData
){

showDialog(

context: context,

builder:(context){

return AlertDialog(

backgroundColor: Colors.white,

shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(18)
),


title: Text(
"Day Planner - $employee ($date)",
style: const TextStyle(
fontWeight: FontWeight.bold,
color: Color(0xFF0052CC)
),
),


content:SizedBox(

width:1200,
height:500,


child:SingleChildScrollView(

scrollDirection: Axis.horizontal,


child:DataTable(

columns:[

"Client",
"Ads",
"Leads",
"Report",
"Deliverable 1",
"Complete",
"Balance",
"Today Plan",
"Status",
"Remarks"

].map(
(e)=>DataColumn(label:Text(e))
).toList(),



rows: plannerData.map((row){


return DataRow(

cells:[


DataCell(Text(row["client_name"] ?? "-")),

DataCell(Text(row["ads"] ?? "-")),

DataCell(Text(row["today_leads"] ?? "-")),

DataCell(Text(row["today_report"] ?? "-")),

DataCell(Text(row["deliverables_1"] ?? "-")),

DataCell(Text(row["complete_deliverables_1"] ?? "-")),

DataCell(Text(row["balanced_deliverables_1"] ?? "-")),

DataCell(Text(row["today_plan"] ?? "-")),

DataCell(Text(row["status"] ?? "-")),

DataCell(Text(row["remarks"] ?? "-")),


]

);


}).toList(),



),

),

),



actions:[

ElevatedButton(

onPressed:(){

Navigator.pop(context);

},

child:const Text("Close")

)

],


);

}

);

}

 void _handleNotificationClick(Map<String, dynamic> log) async {

  final String msg =
      ((log["rawMessage"] ?? log["message"])?.toString() ?? "").trim();

  // if (!(log["isSeen"] as bool)) {
  //   await _markAsSeen(log);
  // }

  final bool seen =
    log["isSeen"] == true ||
    log["isSeen"] == 1 ||
    log["isSeen"] == "1" ||
    log["isSeen"] == "true";

if (!seen) {
  await _markAsSeen(log);
}

  if (!mounted) return;

  // if (msg.startsWith("PLAN_SUBMITTED")) {
  //   final parts = msg.split("|");
  //   if (parts.length >= 3) {
  //     _showDayPlanPopup(parts[1].trim(), parts[2].trim());
  //   }
  //   return;
  // }

  if (msg.startsWith("PLAN_SUBMITTED")) {
  final parts = msg.split("|");

  final employee = parts.length >= 2
      ? parts[1].trim()
      : "Employee";

  final time = parts.length >= 3
      ? parts[2].trim()
      : "";

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      title: const Row(
        children: [
          Icon(
            Icons.notifications_active,
            color: Color(0xFF0052CC),
          ),
          SizedBox(width: 10),
          Text(
            "Daily Planner",
            style: TextStyle(
              color: Color(0xFF0052CC),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Text(
        "$employee submitted the day planner today at $time.",
        style: const TextStyle(
          fontSize: 15,
          color: Color(0xFF1E293B),
          fontWeight: FontWeight.w500,
        ),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0052CC),
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
          child: const Text("Close"),
        ),
      ],
    ),
  );

  return;
}

  try {
    final Map<String, dynamic> data =
        jsonDecode(msg) as Map<String, dynamic>;

    final Map<String, dynamic> payload =
    data["payload"] is Map<String, dynamic>
        ? Map<String, dynamic>.from(data["payload"])
        : {};

//         // ⭐ DAY PLANNER SUBMIT POPUP
// if(payload["type"] == "PLAN_SUBMITTED") {

//   final employee =
//       payload["sender"]?.toString() ?? "";

//   final date =
//       payload["date"]?.toString() ?? "";


//   final plannerData =
//       payload["plannerData"] ?? [];


//   _showDayPlanPopupFromNotification(
//       employee,
//       date,
//       List<Map<String,dynamic>>.from(plannerData)
//   );


//   return;

// }

// ⭐ DAY PLANNER SUBMITTED - SIMPLE MESSAGE ONLY
if (payload["type"] == "PLAN_SUBMITTED" ||
    payload["type"] == "DAY_PLAN_SUBMITTED") {

  final employee =
      payload["sender"]?.toString() ??
      log["senderName"]?.toString() ??
      "Employee";

  final submittedAt =
      payload["submittedAt"]?.toString() ??
      payload["time"]?.toString() ??
      log["time"]?.toString() ??
      "";

  String displayTime = submittedAt;

  // If submittedAt is ISO datetime, convert to AM/PM
  try {
    final parsed = DateTime.parse(submittedAt).toLocal();

    final hour = parsed.hour;
    final minute = parsed.minute;

    final period = hour >= 12 ? "PM" : "AM";
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;

    displayTime =
        "$hour12:${minute.toString().padLeft(2, '0')} $period";
  } catch (_) {
    // Keep existing time if parsing fails
  }

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      title: const Row(
        children: [
          Icon(
            Icons.notifications_active,
            color: Color(0xFF0052CC),
          ),
          SizedBox(width: 10),
          Text(
            "Daily Planner",
            style: TextStyle(
              color: Color(0xFF0052CC),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Text(
        "$employee submitted the day planner today at $displayTime.",
        style: const TextStyle(
          fontSize: 15,
          color: Color(0xFF1E293B),
          fontWeight: FontWeight.w500,
        ),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0052CC),
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
          child: const Text("Close"),
        ),
      ],
    ),
  );

  return;
}

        final String popupTitle =
    data["title"]?.toString() ??
    payload["type"]?.toString() ??
    log["category"]?.toString() ??
    "Notification";

        List<Widget> details = [];

void addRow(String title, dynamic value) {
  if (value == null) return;

  final text = value.toString().trim();

  if (text.isEmpty) return;

  details.add(_buildDetailRow(title, text));
}

addRow("Sender", payload["sender"]);
addRow("Recipient", payload["recipient"]);
addRow("Project", payload["project"]);
addRow("Client", payload["client"]);
addRow("Scheduling Details", payload["schedulingDetails"]);
addRow("Status", payload["status"]);

addRow("Task", payload["taskName"]);
addRow("Content Type", payload["contentType"]);
addRow("Content", payload["content"]);

if (payload["action"] != null) {
  String status = payload["action"].toString().toUpperCase();

  if (status == "APPROVED") {
    status = "✅ Approved";
  } else if (status == "REWORK") {
    status = "🔄 Rework";
  } else if (status == "REJECTED") {
    status = "❌ Rejected";
  }

  addRow("Review Status", status);
}

if (payload["sharedAt"] != null) {
  try {
    final parsedDate = DateTime.parse(payload["sharedAt"].toString());
    final formattedDate = "${parsedDate.day.toString().padLeft(2, '0')}/"
                          "${parsedDate.month.toString().padLeft(2, '0')}/"
                          "${parsedDate.year}";
    addRow("Shared At", formattedDate);
  } catch (_) {
    addRow("Shared At", payload["sharedAt"]);
  }
}

addRow("Manager Comment", payload["comment"]);
addRow("Reviewed At", payload["reviewedAt"]);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),

        title: Row(
          children: [
            const Icon(
              Icons.notifications_active,
              color: Color(0xFF0052CC),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                popupTitle,
                style: const TextStyle(
                  color: Color(0xFF0052CC),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),

content: SizedBox(
  width: 650,
  child: SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: details,
    ),
  ),
),

        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0052CC),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
            label: const Text("Close"),
          )
        ],
      ),
    );
  } catch (e) {
    debugPrint("Popup Error : $e");

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Notification"),
        content: SelectableText(msg),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          )
        ],
      ),
    );
  }
}

  Future<void> _markAsSeen(Map<String, dynamic> log) async {
    try {
      await http.patch(
        Uri.parse('$_baseUrl/notifications/${log["id"]}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'isSeen': true}),
      );
      setState(() => log["isSeen"] = true);
    } catch (e) {
      debugPrint("Error marking seen: $e");
    }
  }

  int _unreadCount(String employee) {
    return notificationLogs.where((log) => 
      log["name"] == employee && 
      log["isSeen"] == false && 
      log["type"] == "RECEIVED" // 👈 RECEIVED messages-ku mattum count varum
    ).length;
  }

  Widget _buildDetailRow(String title, String value) {
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFFE2E8F0)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        SizedBox(
          width: 120,
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF475569),
            ),
          ),
        ),

        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(
              color: Color(0xFF1E293B),
            ),
          ),
        ),

      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final ScrollController scrollController = ScrollController();
    return Material(
        color: Colors.transparent,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(38, 30, 38, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Notifications & Chat Hub", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  IconButton(
                    onPressed: _fetchNotifications,
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0052CC)),
                    tooltip: "Refresh Chats",
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text("Real-time updates, task assignments, reviews, and alerts stream.", style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              const SizedBox(height: 20),
              
              // Category Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _selectedCategory = cat),
                        selectedColor: const Color(0xFF0052CC),
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(color: isSelected ? Colors.white : const Color(0xFF475569), fontWeight: FontWeight.w600),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // WhatsApp-Style Chat Container
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: SizedBox(
                  height: 560,
                  child: Row(
                    children: [
                      // Left Sidebar: Conversations
                      Container(
                        width: 240,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8FAFC),
                          border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
                          borderRadius: BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
                        ),
                        child: ListView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          children: [
                            _buildEmployeeItem("All Chats", null),
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            ..._uniqueEmployees.map((employee) => _buildEmployeeItem(employee, employee)),
                          ],
                        ),
                      ),

                      // Right Section: WhatsApp Bubble Chat Stream
                      Expanded(
                        child: Container(
                          color: const Color(0xFFF9FAFB),
                          child: _loading
                                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF0052CC)))
                                    : _filteredNotifications.isEmpty
                                        ? const Center(child: Text("No messages or notifications found for this filter.", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)))
                                        : ListView.builder(
                                            padding: const EdgeInsets.all(20),
                                            itemCount: _filteredNotifications.length,
                                            itemBuilder: (context, index) {
                                              final log = _filteredNotifications[index];
                                              final bool isSentByMe = log["type"] == "SENT";
                                              final isSeen = log["isSeen"] as bool;

                                              // Date divider logic (WhatsApp style)
                                              bool showDateDivider = false;
                                              String currentDateLabel = log["time"] ?? ""; // Or group by raw date if available
                                              
                                              // Simple grouping check based on adjacent items if date strings match
                                              if (index == 0) {
                                                showDateDivider = true;
                                              } else {
                                                final prevLog = _filteredNotifications[index - 1];
                                                if (prevLog["time"] != log["time"]) {
                                                  showDateDivider = true;
                                                }
                                              }

                                              return Column(
                                                children: [
                                                  if (showDateDivider) ...[
                                                    Padding(
                                                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                                                      child: Center(
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
                                                            borderRadius: BorderRadius.circular(10),
                                                          ),
                                                          child: Text(
                                                            currentDateLabel,
                                                            style: const TextStyle(
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.w600,
                                                              color: Color(0xFF64748B),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                  Align(
                                                    alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
                                                    child: Container(
                                                      margin: const EdgeInsets.symmetric(vertical: 6),
                                                      constraints: const BoxConstraints(maxWidth: 480),
                                                      child: InkWell(
                                                        onTap: () => _handleNotificationClick(log),
                                                        borderRadius: BorderRadius.circular(12),
                                                        child: Container(
                                                          padding: const EdgeInsets.all(12),
                                                          decoration: BoxDecoration(
                                                            color: isSentByMe ? const Color(0xFFEFF6FF) : Colors.white,
                                                            borderRadius: BorderRadius.circular(12),
                                                            border: Border.all(
                                                              color: isSentByMe ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
                                                            ),
                                                          ),
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Wrap(
                                                                alignment: WrapAlignment.start,
                                                                crossAxisAlignment: WrapCrossAlignment.center,
                                                                spacing: 6,
                                                                runSpacing: 4,
                                                                children: [
                                                                  Container(
                                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                                    decoration: BoxDecoration(
                                                                      color: isSentByMe ? const Color(0xFF0052CC).withValues(alpha: 0.1) : const Color(0xFFEA580C).withValues(alpha: 0.1),
                                                                      borderRadius: BorderRadius.circular(4),
                                                                    ),
                                                                    child: Text(
                                                                      log["category"],
                                                                      style: TextStyle(
                                                                        fontSize: 10,
                                                                        fontWeight: FontWeight.w700,
                                                                        color: isSentByMe ? const Color(0xFF0052CC) : const Color(0xFFEA580C),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  const SizedBox(width: 10),
                                                                  Text(
                                                                    log["name"],
                                                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                                                  ),
                                                                ],
                                                              ),
                                                              const SizedBox(height: 6),
                                                              Text(
                                                                log["message"],
                                                                style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
                                                              ),
                                                              const SizedBox(height: 6),
                                                              Row(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                  Text(
                                                                    log["time"],
                                                                    style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                                                  ),
                                                                  const SizedBox(width: 6),
                                                                  IconButton(
                                                                    padding: EdgeInsets.zero,
                                                                    constraints: const BoxConstraints(),
                                                                    onPressed: () => _toggleFavorite(log),
                                                                    icon: Icon(
                                                                      log["isFavorite"] ? Icons.star_rounded : Icons.star_border_rounded,
                                                                      color: log["isFavorite"] ? const Color(0xFF0052CC) : const Color(0xFFCBD5E1),
                                                                      size: 14,
                                                                    ),
                                                                  ),
                                                                  if (isSentByMe) ...[
                                                                    const SizedBox(width: 4),
                                                                    Icon(
                                                                      isSeen ? Icons.done_all : Icons.check,
                                                                      size: 14,
                                                                      color: isSeen ? const Color(0xFF0052CC) : const Color(0xFF94A3B8),
                                                                    ),
                                                                  ],
                                                                  const SizedBox(width: 6),
                                                                  IconButton(
                                                                    padding: EdgeInsets.zero,
                                                                    constraints: const BoxConstraints(),
                                                                    onPressed: () => _deleteNotification(log),
                                                                    icon: const Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFF94A3B8)),
                                                                  ),
                                                                ],
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  Widget _buildEmployeeItem(String label, String? employeeName) {
    final isSelected = _selectedEmployee == employeeName;
    return InkWell(
      onTap: () => setState(() => _selectedEmployee = employeeName),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? const Color(0xFF0052CC) : const Color(0xFF475569),
                ),
              ),
            ),
            if (employeeName != null && _unreadCount(employeeName) > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: const BoxDecoration(color: Color(0xFF0052CC), shape: BoxShape.circle),
                child: Text("${_unreadCount(employeeName)}", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }
}