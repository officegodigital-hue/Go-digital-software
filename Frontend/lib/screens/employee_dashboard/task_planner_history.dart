import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import 'package:godigital_portal/core/constants/app_colors.dart';
import 'package:godigital_portal/core/constants/app_text_styles.dart';
import 'package:godigital_portal/services/auth_service.dart';
import '../../services/api_config.dart';

class TaskPlannerHistoryWidget extends StatefulWidget {
  const TaskPlannerHistoryWidget({super.key});

  @override
  State<TaskPlannerHistoryWidget> createState() => _TaskPlannerHistoryWidgetState();
}

class _TaskPlannerHistoryWidgetState extends State<TaskPlannerHistoryWidget> {
  static String get _baseUrl => ApiConfig.baseUrl;

  List<TaskPlannerHistoryItem> allRecords = [];
List<TaskPlannerHistoryItem> filteredRecords = [];

  bool loading = true;
  String? authToken;
  String? _employeeName;

  final searchController = TextEditingController();
  String selectedMonth = "All";
  DateTime? selectedDate;

  List<String> availableMonths = ["All"];

@override
void initState() {
  super.initState();

  WidgetsBinding.instance.addPostFrameCallback((_) {
    final auth = context.read<AuthService>();

    authToken = auth.token;
    _employeeName = auth.user?['fullName'] ?? '';

    loadHistory();
  });

  searchController.addListener(applyFilter);
}

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadHistory() async {
    setState(() => loading = true);

    try {
      final response = await http.get(
        Uri.parse("$_baseUrl/task-planner/shares?employee=$_employeeName"),
        headers: {"Authorization": "Bearer $authToken"},
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List data = body["data"] ?? [];

        final records = data.map((e) {
          return TaskPlannerHistoryItem(
  id: e["id"] ?? 0,
  contentType: e["content_type"] ?? "",
  content: e["content"] ?? "",
  sharedTo: e["receiver_employee_name"] ?? "",
  createdAt: e["shared_at"] ?? e["created_at"] ?? "",
  updatedAt: e["updated_at"] ?? "",
);
        }).toList();

        Set<String> months = {"All"};

for (var item in records) {
  final date = DateTime.tryParse(item.createdAt);

  if (date != null) {
    final month =
        "${date.year}-${date.month.toString().padLeft(2, '0')}";

    months.add(month);
  }
}

        setState(() {
          allRecords = records;
          availableMonths = months.toList()
  ..sort((a,b){

    if(a=="All") return -1;
    if(b=="All") return 1;

    return b.compareTo(a);

  });
          loading = false;
        });

        applyFilter();
      } else {
        setState(() => loading = false);
      }
    } catch (e) {
      setState(() => loading = false);
    }
  }

  void applyFilter() {
    setState(() {
      filteredRecords = allRecords.where((item) {
        // search filter by client name
        if (searchController.text.trim().isNotEmpty) {
  final keyword = searchController.text.toLowerCase();

  if (!item.content.toLowerCase().contains(keyword) &&
      !item.contentType.toLowerCase().contains(keyword)) {
    return false;
  }
}

        // month filter
        if (selectedMonth != "All") {

  final date = DateTime.tryParse(item.createdAt);

  if (date != null) {

    final itemMonth =
        "${date.year}-${date.month.toString().padLeft(2, '0')}";

    if (itemMonth != selectedMonth) {
      return false;
    }

  } else {
    return false;
  }
}

        // date filter
        if (selectedDate != null) {
          final date = DateTime.tryParse(item.createdAt);
          if (date != null) {
            if (date.year != selectedDate!.year ||
                date.month != selectedDate!.month ||
                date.day != selectedDate!.day) {
              return false;
            }
          }
        }

        return true;
      }).toList();
    });
  }

  Future<void> updateTask(TaskPlannerHistoryItem item, String newClient, String newFeedback) async {
    setState(() => loading = true);
    try {
      final r = await http.put(
        Uri.parse("$_baseUrl/feedback/${item.id}"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $authToken",
        },
        body: jsonEncode({
          "clientName": newClient,
          "feedback": newFeedback,
        }),
      );

      if (r.statusCode == 200) {
        showSnack("✅ Updated successfully", true);
        loadHistory();
      } else {
        showSnack("❌ Failed to update", false);
        setState(() => loading = false);
      }
    } catch (e) {
      showSnack("❌ Error updating record", false);
      setState(() => loading = false);
    }
  }

  Future<void> deleteFeedback(int id) async {
    setState(() => loading = true);
    try {
      final r = await http.delete(
        Uri.parse("$_baseUrl/feedback/$id"),
        headers: {"Authorization": "Bearer $authToken"},
      );

      if (r.statusCode == 200) {
        showSnack("✅ Deleted successfully", true);
        loadHistory();
      } else {
        showSnack("❌ Failed to delete", false);
        setState(() => loading = false);
      }
    } catch (e) {
      showSnack("❌ Error deleting record", false);
      setState(() => loading = false);
    }
  }

  void showEditDialog(TaskPlannerHistoryItem item) {
    final clientCtrl = TextEditingController(text: item.contentType);
    final feedbackCtrl = TextEditingController(text: item.content);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Feedback", style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: clientCtrl,
                decoration: const InputDecoration(labelText: "Client Name", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: feedbackCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: "Feedback", border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004AAD), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              updateTask(item, clientCtrl.text.trim(), feedbackCtrl.text.trim());
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void showDeleteDialog(int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text("Are you sure you want to delete this record?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              deleteFeedback(id);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void showSnack(String msg, bool success) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: success ? Colors.green : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String formatDate(String value) {

  if (value.isEmpty) {
    return "-";
  }

  try {

    final d = DateTime.parse(value).toLocal();

    final day = d.day.toString().padLeft(2,'0');
    final month = d.month.toString().padLeft(2,'0');
    final year = d.year;

    final hour = d.hour.toString().padLeft(2,'0');
    final minute = d.minute.toString().padLeft(2,'0');

    return "$day/$month/$year $hour:$minute";

  } catch(e){

    return value;
  }
}

  String monthName(String value) {
    if (value == "All") return "All Months";
    final split = value.split("-");
    if (split.length < 2) return value;
    const months = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    int idx = int.tryParse(split[1]) ?? 0;
    if (idx < 1 || idx > 12) return value;
    return "${months[idx]} ${split[0]}";
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Task Planner History", style: AppTextStyles.heading),
                  SizedBox(height: 4),
                  Text("Review and manage task planner history efficiently.", style: AppTextStyles.subHeading),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "${filteredRecords.length} Records Found",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF004AAD)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Search & Filter Toolbar
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              // Search Input Box
              SizedBox(
                width: 280,
                height: 42,
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: "Search content...",
                    hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  ),
                ),
              ),
              // Month Filter Dropdown
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedMonth,
                    items: availableMonths.map((m) {
                      return DropdownMenuItem(
                        value: m,
                        child: Text(monthName(m), style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => selectedMonth = v);
                        applyFilter();
                      }
                    },
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Table Container
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                // Table Header
                Container(
  height: 50,
  color: AppColors.lightBlue,
  child: const Row(
    children: [
      SizedBox(
        width: 60,
        child: Center(child: Text("S.No", style: _headerStyle)),
      ),
      SizedBox(
        width: 170,
        child: Center(child: Text("Shared Date", style: _headerStyle)),
      ),
      SizedBox(
        width: 180,
        child: Center(child: Text("Content Type", style: _headerStyle)),
      ),
      Expanded(
        child: Center(child: Text("Content", style: _headerStyle)),
      ),
      SizedBox(
        width: 180,
        child: Center(child: Text("Shared To", style: _headerStyle)),
      ),
      SizedBox(
        width: 150,
        child: Center(child: Text("Action", style: _headerStyle)),
      ),
    ],
  ),
),
              
               if (loading)
  Container(
    height: 200,
    alignment: Alignment.center,
    child: const CircularProgressIndicator(
      color: Color(0xFF004AAD),
    ),
  )
else if (filteredRecords.isEmpty)
  Container(
    height: 200,
    alignment: Alignment.center,
    child: const Text(
      'No task planner history found.',
      style: TextStyle(fontSize: 14, color: Colors.grey),
    ),
  )
else
  ...filteredRecords.asMap().entries.map((entry) {
  final idx = entry.key;
  final item = entry.value;

  return Container(
    constraints: const BoxConstraints(minHeight: 65),
    decoration: BoxDecoration(
      border: const Border(
        top: BorderSide(color: AppColors.border),
      ),
      color: idx.isEven
          ? Colors.white
          : const Color(0xFFFAFAFC),
    ),
    child: Row(
      children: [

        SizedBox(
          width: 60,
          child: Center(
            child: Text(
              "${idx + 1}",
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
            ),
          ),
        ),

        SizedBox(
          width: 170,
          child: Center(
            child: Text(
              formatDate(item.createdAt),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
        ),

        Container(
          width: 180,
          color: AppColors.lightBlue.withValues(alpha: .25),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(12),
          child: Text(
            item.contentType,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 12,
            ),
            child: Text(
              item.content,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ),

        SizedBox(
          width: 180,
          child: Center(
            child: Text(
              item.sharedTo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF004AAD),
              ),
            ),
          ),
        ),

        SizedBox(
          width: 150,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                IconButton(
                  tooltip: "Edit",
                  icon: const Icon(
                    Icons.edit,
                    color: Color(0xFFF59E0B),
                  ),
                  onPressed: () => showEditDialog(item),
                ),

                IconButton(
                  tooltip: "Delete",
                  icon: const Icon(
                    Icons.delete,
                    color: Colors.red,
                  ),
                  onPressed: () => showDeleteDialog(item.id),
                ),

              ],
            ),
          ),
        ),

      ],
    ),
  );
}),  
         ], ),
          ),
        ],
      ),
    );
  }
}

class TaskPlannerHistoryItem {
  final int id;
  final String contentType;
  final String content;
  final String sharedTo;
  final String createdAt;
  final String updatedAt;

  TaskPlannerHistoryItem({
    required this.id,
    required this.contentType,
    required this.content,
    required this.sharedTo,
    required this.createdAt,
    required this.updatedAt,
  });
}

const TextStyle _headerStyle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w800,
  color: AppColors.textDark,
);