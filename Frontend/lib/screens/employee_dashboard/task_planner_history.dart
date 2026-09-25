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
  State<TaskPlannerHistoryWidget> createState() =>
      _TaskPlannerHistoryWidgetState();
}

class _TaskPlannerHistoryWidgetState extends State<TaskPlannerHistoryWidget>
    with SingleTickerProviderStateMixin {
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

  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  static const Color _primaryBlue = Color(0xFF146BFF);
  static const Color _deepBlue = Color(0xFF0B3B91);
  static const Color _lightBlue = Color(0xFFEAF3FF);
  static const Color _softBlue = Color(0xFFF5F9FF);
  static const Color _borderBlue = Color(0xFFD6E6FF);
  static const Color _textBlue = Color(0xFF173B72);

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, .035),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthService>();

      authToken = auth.token;
      _employeeName = auth.user?['fullName'] ?? '';

      loadHistory();
      _animationController.forward();
    });

    searchController.addListener(applyFilter);
  }

  @override
  void dispose() {
    searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> loadHistory() async {
    if (mounted) {
      setState(() => loading = true);
    }

    try {
      final response = await http.get(
        Uri.parse("$_baseUrl/task-planner/shares?employee=$_employeeName"),
        headers: {"Authorization": "Bearer $authToken"},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List data = body["data"] ?? [];

        final records = data.map<TaskPlannerHistoryItem>((e) {
          return TaskPlannerHistoryItem(
            id: e["id"] ?? 0,
            contentType: e["content_type"] ?? "",
            content: e["content"] ?? "",
            sharedTo: e["receiver_employee_name"] ?? "",
            createdAt: e["shared_at"] ?? e["created_at"] ?? "",
            updatedAt: e["updated_at"] ?? "",
          );
        }).toList();

        final Set<String> months = {"All"};

        for (final item in records) {
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
            ..sort((a, b) {
              if (a == "All") return -1;
              if (b == "All") return 1;
              return b.compareTo(a);
            });
          loading = false;
        });

        applyFilter();
      } else {
        setState(() => loading = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void applyFilter() {
    if (!mounted) return;

    final keyword = searchController.text.trim().toLowerCase();

    final result = allRecords.where((item) {
      if (keyword.isNotEmpty) {
        if (!item.content.toLowerCase().contains(keyword) &&
            !item.contentType.toLowerCase().contains(keyword)) {
          return false;
        }
      }

      if (selectedMonth != "All") {
        final date = DateTime.tryParse(item.createdAt);

        if (date == null) return false;

        final itemMonth =
            "${date.year}-${date.month.toString().padLeft(2, '0')}";

        if (itemMonth != selectedMonth) {
          return false;
        }
      }

      if (selectedDate != null) {
        final date = DateTime.tryParse(item.createdAt);

        if (date == null) return false;

        if (date.year != selectedDate!.year ||
            date.month != selectedDate!.month ||
            date.day != selectedDate!.day) {
          return false;
        }
      }

      return true;
    }).toList();

    setState(() {
      filteredRecords = result;
    });
  }

  Future<void> updateTask(
    TaskPlannerHistoryItem item,
    String newContentType,
    String newContent,
  ) async {
    setState(() => loading = true);

    try {
      final r = await http.put(
        Uri.parse("$_baseUrl/task-planner/${item.id}"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $authToken",
        },
        body: jsonEncode({
          "contentType": newContentType,
          "content": newContent,
        }),
      );

      if (r.statusCode == 200) {
        showSnack("Updated successfully & Notification sent", true);
        await loadHistory();
      } else {
        String errorMsg = "Failed to update";

        try {
          final resBody = jsonDecode(r.body);
          errorMsg = resBody["message"] ?? errorMsg;
        } catch (_) {}

        showSnack(errorMsg, false);

        if (mounted) {
          setState(() => loading = false);
        }
      }
    } catch (e) {
      showSnack("Error updating record: $e", false);

      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> deleteTask(int id) async {
    setState(() => loading = true);

    try {
      final r = await http.delete(
        Uri.parse("$_baseUrl/task-planner/$id"),
        headers: {"Authorization": "Bearer $authToken"},
      );

      if (r.statusCode == 200) {
        showSnack("Deleted successfully", true);
        await loadHistory();
      } else {
        showSnack("Failed to delete", false);

        if (mounted) {
          setState(() => loading = false);
        }
      }
    } catch (_) {
      showSnack("Error deleting record", false);

      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void showEditDialog(TaskPlannerHistoryItem item) {
    final contentCtrl = TextEditingController(text: item.contentType);
    final feedbackCtrl = TextEditingController(text: item.content);

    showDialog(
      context: context,
      builder: (ctx) {
        final isMobile = MediaQuery.of(ctx).size.width < 560;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 30,
            vertical: 24,
          ),
          child: Container(
            width: 520,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _borderBlue),
              boxShadow: [
                BoxShadow(
                  color: _deepBlue.withValues(alpha: .14),
                  blurRadius: 35,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_deepBlue, _primaryBlue],
                          ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.edit_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Edit Task Planner",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: _textBlue,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              "Update the shared planner content.",
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF7890B2),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _dialogField(
                    controller: contentCtrl,
                    label: "Content Type",
                    icon: Icons.category_rounded,
                  ),
                  const SizedBox(height: 16),
                  _dialogField(
                    controller: feedbackCtrl,
                    label: "Content",
                    icon: Icons.notes_rounded,
                    maxLines: 5,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(color: _textBlue),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          updateTask(
                            item,
                            contentCtrl.text.trim(),
                            feedbackCtrl.text.trim(),
                          );
                        },
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text("Save Changes"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _dialogField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _primaryBlue, size: 20),
        filled: true,
        fillColor: _softBlue,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _borderBlue),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _borderBlue),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _primaryBlue, width: 1.6),
        ),
      ),
    );
  }

  void showDeleteDialog(int id) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFF64748B),
              ),
              SizedBox(width: 10),
              Text(
                "Confirm Delete",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _textBlue,
                ),
              ),
            ],
          ),
          content: const Text(
            "Are you sure you want to delete this record?",
            style: TextStyle(color: Color(0xFF64748B)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                "Cancel",
                style: TextStyle(color: _textBlue),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                deleteTask(id);
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }

  void showSnack(String msg, bool success) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success
                  ? Icons.check_circle_rounded
                  : Icons.error_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: success ? _primaryBlue : const Color(0xFF52647D),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        margin: const EdgeInsets.all(18),
      ),
    );
  }

  String formatDate(String value) {
    if (value.isEmpty) return "-";

    try {
      final d = DateTime.parse(value).toLocal();

      final day = d.day.toString().padLeft(2, '0');
      final month = d.month.toString().padLeft(2, '0');
      final year = d.year;

      final hour = d.hour.toString().padLeft(2, '0');
      final minute = d.minute.toString().padLeft(2, '0');

      return "$day/$month/$year $hour:$minute";
    } catch (_) {
      return value;
    }
  }

  String monthName(String value) {
    if (value == "All") return "All Months";

    final split = value.split("-");
    if (split.length < 2) return value;

    const months = [
      "",
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec"
    ];

    final idx = int.tryParse(split[1]) ?? 0;

    if (idx < 1 || idx > 12) return value;

    return "${months[idx]} ${split[0]}";
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _primaryBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: _textBlue,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => selectedDate = picked);
      applyFilter();
    }
  }

  void _clearDate() {
    setState(() => selectedDate = null);
    applyFilter();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < 650;
        final isTablet = width >= 650 && width < 1050;

        final horizontalPadding = isMobile
            ? 14.0
            : isTablet
                ? 22.0
                : 30.0;

        return Container(
          color: const Color(0xFFF5F9FF),
          child: Stack(
            children: [
              Positioned(
                top: -90,
                right: -80,
                child: _backgroundOrb(220, _lightBlue),
              ),
              Positioned(
                top: 310,
                left: -120,
                child: _backgroundOrb(250, const Color(0xFFEAF2FF)),
              ),
              SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  isMobile ? 16 : 24,
                  horizontalPadding,
                  32,
                ),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHero(isMobile),
                        const SizedBox(height: 18),
                        _buildFilterPanel(
                          isMobile: isMobile,
                          isTablet: isTablet,
                        ),
                        const SizedBox(height: 18),
                        if (isMobile)
                          _buildMobileRecords()
                        else
                          _buildDesktopTable(),
                      ],
                    ),
                  ),
                ),
              ),
              if (loading && filteredRecords.isNotEmpty)
                Positioned(
                  top: 8,
                  right: 18,
                  child: _loadingPill(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _backgroundOrb(double size, Color color) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: .75),
        ),
      ),
    );
  }

  Widget _buildHero(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 18 : 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_deepBlue, _primaryBlue],
        ),
        borderRadius: BorderRadius.circular(isMobile ? 22 : 28),
        boxShadow: [
          BoxShadow(
            color: _primaryBlue.withValues(alpha: .22),
            blurRadius: 28,
            offset: const Offset(0, 13),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heroIcon(),
                const SizedBox(height: 14),
                _heroText(),
                const SizedBox(height: 18),
                _recordBadge(),
              ],
            )
          : Row(
              children: [
                _heroIcon(),
                const SizedBox(width: 16),
                Expanded(child: _heroText()),
                const SizedBox(width: 20),
                _recordBadge(),
              ],
            ),
    );
  }

  Widget _heroIcon() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: Colors.white.withValues(alpha: .25),
        ),
      ),
      child: const Icon(
        Icons.history_rounded,
        color: Colors.white,
        size: 28,
      ),
    );
  }

  Widget _heroText() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "TASK PLANNER",
          style: TextStyle(
            color: Color(0xFFBBD6FF),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.2,
          ),
        ),
        SizedBox(height: 5),
        Text(
          "Planner History",
          style: TextStyle(
            color: Colors.white,
            fontSize: 27,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        SizedBox(height: 6),
        Text(
          "Review, search and manage your shared task planner records.",
          style: TextStyle(
            color: Color(0xFFDCEBFF),
            fontSize: 13,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _recordBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: .24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            "${filteredRecords.length}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Text(
            "Records Found",
            style: TextStyle(
              color: Color(0xFFDCEBFF),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel({
    required bool isMobile,
    required bool isTablet,
  }) {
    final controls = [
      Expanded(
        flex: 3,
        child: _searchField(),
      ),
      Expanded(
        flex: 2,
        child: _monthDropdown(),
      ),
      Expanded(
        flex: 2,
        child: _dateFilter(),
      ),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borderBlue),
        boxShadow: [
          BoxShadow(
            color: _deepBlue.withValues(alpha: .055),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              children: [
                _searchField(),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _monthDropdown()),
                    const SizedBox(width: 10),
                    Expanded(child: _dateFilter()),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                ...controls.expand(
                  (widget) => [
                    widget,
                    const SizedBox(width: 10),
                  ],
                ).take(5),
              ],
            ),
    );
  }

  Widget _searchField() {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: searchController,
        decoration: InputDecoration(
          hintText: "Search content or content type...",
          hintStyle: const TextStyle(
            fontSize: 12,
            color: Color(0xFF91A4C0),
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: _primaryBlue,
          ),
          filled: true,
          fillColor: _softBlue,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _borderBlue),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _borderBlue),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: _primaryBlue,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _monthDropdown() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _softBlue,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderBlue),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: selectedMonth,
          items: availableMonths.map((m) {
            return DropdownMenuItem(
              value: m,
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    size: 17,
                    color: _primaryBlue,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      monthName(m),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _textBlue,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) {
              setState(() => selectedMonth = v);
              applyFilter();
            }
          },
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: _primaryBlue,
          ),
        ),
      ),
    );
  }

  Widget _dateFilter() {
    final text = selectedDate == null
        ? "Filter by date"
        : "${selectedDate!.day.toString().padLeft(2, '0')}/"
            "${selectedDate!.month.toString().padLeft(2, '0')}/"
            "${selectedDate!.year}";

    return SizedBox(
      height: 48,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _pickDate,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: _softBlue,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _borderBlue),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.event_rounded,
                size: 18,
                color: _primaryBlue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selectedDate == null
                        ? const Color(0xFF91A4C0)
                        : _textBlue,
                  ),
                ),
              ),
              if (selectedDate != null)
                InkWell(
                  onTap: _clearDate,
                  child: const Padding(
                    padding: EdgeInsets.all(3),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: _primaryBlue,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopTable() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borderBlue),
        boxShadow: [
          BoxShadow(
            color: _deepBlue.withValues(alpha: .06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _tableHeader(),
          if (loading)
            _loadingState()
          else if (filteredRecords.isEmpty)
            _emptyState()
          else
            ...filteredRecords.asMap().entries.map(
                  (entry) => _desktopRow(entry.key, entry.value),
                ),
        ],
      ),
    );
  }

  Widget _tableHeader() {
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF1F7FF), Color(0xFFE7F1FF)],
        ),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 70,
            child: Center(child: Text("S.No", style: _headerStyle)),
          ),
          SizedBox(
            width: 175,
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
            width: 145,
            child: Center(child: Text("Action", style: _headerStyle)),
          ),
        ],
      ),
    );
  }

  Widget _desktopRow(int idx, TaskPlannerHistoryItem item) {
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      decoration: BoxDecoration(
        color: idx.isEven ? Colors.white : const Color(0xFFFBFDFF),
        border: const Border(
          top: BorderSide(color: _borderBlue),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Center(
              child: _numberBadge(idx + 1),
            ),
          ),
          SizedBox(
            width: 175,
            child: Center(
              child: Text(
                formatDate(item.createdAt),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF637999),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 180,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 9,
              ),
              child: _contentTypeBadge(item.contentType),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 13,
              ),
              child: Text(
                item.content.isEmpty ? "-" : item.content,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: Color(0xFF30496E),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 180,
            child: Center(
              child: _employeeBadge(item.sharedTo),
            ),
          ),
          SizedBox(
            width: 145,
            child: Center(
              child: _actionButtons(item),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileRecords() {
    if (loading) {
      return _loadingState();
    }

    if (filteredRecords.isEmpty) {
      return _emptyState();
    }

    return Column(
      children: filteredRecords.asMap().entries.map((entry) {
        return _mobileCard(entry.key, entry.value);
      }).toList(),
    );
  }

  Widget _mobileCard(int idx, TaskPlannerHistoryItem item) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderBlue),
        boxShadow: [
          BoxShadow(
            color: _deepBlue.withValues(alpha: .055),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _numberBadge(idx + 1),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  formatDate(item.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF637999),
                  ),
                ),
              ),
              _actionButtons(item),
            ],
          ),
          const SizedBox(height: 14),
          _mobileLabel("CONTENT TYPE"),
          const SizedBox(height: 6),
          _contentTypeBadge(
            item.contentType.isEmpty ? "Content Type" : item.contentType,
            expanded: true,
          ),
          const SizedBox(height: 13),
          _mobileLabel("CONTENT"),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: _softBlue,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _borderBlue),
            ),
            child: Text(
              item.content.isEmpty ? "-" : item.content,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Color(0xFF30496E),
              ),
            ),
          ),
          const SizedBox(height: 13),
          _mobileLabel("SHARED TO"),
          const SizedBox(height: 6),
          _employeeBadge(
            item.sharedTo.isEmpty ? "Not specified" : item.sharedTo,
            expanded: true,
          ),
        ],
      ),
    );
  }

  Widget _mobileLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        color: Color(0xFF7390B8),
        letterSpacing: 1.3,
      ),
    );
  }

  Widget _numberBadge(int number) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_deepBlue, _primaryBlue],
        ),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        "$number",
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _contentTypeBadge(
    String text, {
    bool expanded = false,
  }) {
    final child = Container(
      width: expanded ? double.infinity : null,
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: _lightBlue,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderBlue),
      ),
      child: Row(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        children: [
          const Icon(
            Icons.category_rounded,
            size: 16,
            color: _primaryBlue,
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              text.isEmpty ? "Content Type" : text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _textBlue,
              ),
            ),
          ),
        ],
      ),
    );

    return child;
  }

  Widget _employeeBadge(
    String name, {
    bool expanded = false,
  }) {
    final initials = name.trim().isEmpty
        ? "?"
        : name
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((e) => e[0].toUpperCase())
            .join();

    return Container(
      width: expanded ? double.infinity : null,
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F7FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderBlue),
      ),
      child: Row(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Container(
            width: 29,
            height: 29,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_deepBlue, _primaryBlue],
              ),
            ),
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _textBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButtons(TaskPlannerHistoryItem item) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _iconAction(
          icon: Icons.edit_rounded,
          tooltip: "Edit",
          onPressed: () => showEditDialog(item),
        ),
        const SizedBox(width: 4),
        _iconAction(
          icon: Icons.delete_outline_rounded,
          tooltip: "Delete",
          onPressed: () => showDeleteDialog(item.id),
        ),
      ],
    );
  }

  Widget _iconAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: _lightBlue,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onPressed,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(
              icon,
              size: 18,
              color: _primaryBlue,
            ),
          ),
        ),
      ),
    );
  }

  Widget _loadingState() {
    return Container(
      width: double.infinity,
      height: 210,
      alignment: Alignment.center,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: _primaryBlue,
            ),
          ),
          SizedBox(height: 14),
          Text(
            "Loading planner history...",
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF7186A5),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: _lightBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.history_rounded,
              size: 30,
              color: _primaryBlue,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            "No task planner history found",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _textBlue,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            "Try changing your search or filter.",
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF8193AF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingPill() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderBlue),
        boxShadow: [
          BoxShadow(
            color: _deepBlue.withValues(alpha: .08),
            blurRadius: 14,
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _primaryBlue,
            ),
          ),
          SizedBox(width: 7),
          Text(
            "Updating",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _textBlue,
            ),
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
  fontSize: 12,
  fontWeight: FontWeight.w800,
  color: Color(0xFF173B72),
);
