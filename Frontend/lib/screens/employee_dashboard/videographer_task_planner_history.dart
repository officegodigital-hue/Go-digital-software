import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:godigital_portal/services/auth_service.dart';
import '../../services/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'employee_layout_page.dart';

class VideographerTaskPlannerHistoryPage extends StatefulWidget {
  final String searchQuery;

  const VideographerTaskPlannerHistoryPage({
    super.key,
    this.searchQuery = '',
  });

  @override
  State<VideographerTaskPlannerHistoryPage> createState() =>
      _VideographerTaskPlannerHistoryPageState();
}

class _VideographerTaskPlannerHistoryPageState
    extends State<VideographerTaskPlannerHistoryPage> {
  static String get _baseUrl => ApiConfig.baseUrl;

  static const Color _brand = Color(0xFF0052CC);
  static const Color _brandDark = Color(0xFF003A99);
  static const Color _cyan = Color(0xFF00B8D9);
  static const Color _surface = Color(0xFFF6F8FC);
  static const Color _textDark = Color(0xFF0B1220);
  static const Color _textMuted = Color(0xFF64748B);

  List<VideographerHistoryItem> allRecords = [];
  List<VideographerHistoryItem> filteredRecords = [];

  bool loading = true;
  String? authToken;
  String? _employeeName;

  bool isSNoAscending = true;
  bool isClientAscending = true;

  String? selectedStatusFilter;
  DateTime? selectedDateFilter;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthService>();

      authToken = auth.token;
      _employeeName = auth.user?['fullName'] ?? '';

      loadHistory();
    });
  }

  @override
  void didUpdateWidget(covariant VideographerTaskPlannerHistoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.searchQuery != widget.searchQuery) {
      applyFilter();
    }
  }

  // ============================================================
  // LOAD HISTORY
  // ============================================================

  Future<void> loadHistory() async {
    if (mounted) {
      setState(() => loading = true);
    }

    try {
      final response = await http.get(
        Uri.parse(
          '$_baseUrl/videographer-planner/shares?employee=$_employeeName',
        ),
        headers: {
          'Authorization': 'Bearer $authToken',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);

        final List data = body['data'] ?? [];

        final records = data.map<VideographerHistoryItem>((e) {
          return VideographerHistoryItem(
            id: e['id'] ?? 0,
            clientName: e['client_name'] ?? '',
            schedulingDetails: e['scheduling_details'] ?? '',
            sharedTo: e['receiver_employee_name'] ?? '',
            receiverRole: e['receiver_role'] ?? '',
            receiverShort: e['receiver_short'] ?? '',
            sharedAt: e['shared_at'] ?? '',
            status: e['status'] ?? 'HOLD',
          );
        }).toList();

        setState(() {
          allRecords = records;
          loading = false;
        });

        applyFilter();
      } else {
        setState(() => loading = false);
        showSnack('Unable to load task history', false);
      }
    } catch (_) {
      if (!mounted) return;

      setState(() => loading = false);

      showSnack('Connection error while loading history', false);
    }
  }

  // ============================================================
  // FILTER + SEARCH
  // ============================================================

  void applyFilter() {
    if (!mounted) return;

    setState(() {
      filteredRecords = allRecords.where((item) {
        // Global Search
        if (widget.searchQuery.trim().isNotEmpty) {
          final keyword = widget.searchQuery.toLowerCase().trim();

          final clientMatch =
              item.clientName.toLowerCase().contains(keyword);

          final employeeMatch =
              item.sharedTo.toLowerCase().contains(keyword);

          final scheduleMatch =
              item.schedulingDetails.toLowerCase().contains(keyword);

          if (!clientMatch &&
              !employeeMatch &&
              !scheduleMatch) {
            return false;
          }
        }

        // Status Filter
        if (selectedStatusFilter != null &&
            selectedStatusFilter != 'All') {
          if (item.status.toUpperCase() !=
              selectedStatusFilter!.toUpperCase()) {
            return false;
          }
        }

        // Date Filter
        if (selectedDateFilter != null) {
          final itemDate = DateTime.tryParse(item.sharedAt);

          if (itemDate == null) {
            return false;
          }

          if (itemDate.year != selectedDateFilter!.year ||
              itemDate.month != selectedDateFilter!.month ||
              itemDate.day != selectedDateFilter!.day) {
            return false;
          }
        }

        return true;
      }).toList();

      filteredRecords.sort(
        (a, b) => isSNoAscending
            ? a.id.compareTo(b.id)
            : b.id.compareTo(a.id),
      );
    });
  }

  // ============================================================
  // UPDATE
  // ============================================================

  Future<void> updateTask(
    VideographerHistoryItem item,
    String client,
    String scheduling,
    String status,
  ) async {
    setState(() => loading = true);

    try {
      final response = await http.put(
        Uri.parse(
          '$_baseUrl/videographer-planner/${item.id}',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'clientName': client,
          'schedulingDetails': scheduling,
          'status': status,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        showSnack('Task updated successfully', true);
        await loadHistory();
      } else {
        setState(() => loading = false);
        showSnack('Failed to update task', false);
      }
    } catch (_) {
      if (!mounted) return;

      setState(() => loading = false);

      showSnack('Error updating task record', false);
    }
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<void> deleteTask(int id) async {
    setState(() => loading = true);

    try {
      final response = await http.delete(
        Uri.parse(
          '$_baseUrl/videographer-planner/$id',
        ),
        headers: {
          'Authorization': 'Bearer $authToken',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        showSnack('Record deleted successfully', true);
        await loadHistory();
      } else {
        setState(() => loading = false);
        showSnack('Failed to delete record', false);
      }
    } catch (_) {
      if (!mounted) return;

      setState(() => loading = false);

      showSnack('Error deleting record', false);
    }
  }

  // ============================================================
  // BACK TO PLANNER
  // ============================================================

  Future<void> _openPlanner() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'employeeMenu',
      'Video Task Planner',
    );

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const EmployeeLayoutPage(),
      ),
    );
  }

  // ============================================================
  // EDIT DIALOG
  // ============================================================

  void showEditDialog(VideographerHistoryItem item) {
    final clientCtrl =
        TextEditingController(text: item.clientName);

    final scheduleCtrl =
        TextEditingController(text: item.schedulingDetails);

    String selectedStatus = item.status;

    const statusOptions = [
      'HOLD',
      'PROCESS',
      'COMPLETED',
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 560,
                ),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: 0.18,
                        ),
                        blurRadius: 40,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    _brand,
                                    _cyan,
                                  ],
                                ),
                                borderRadius:
                                    BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.edit_note_rounded,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Edit Task Record',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight:
                                          FontWeight.w900,
                                      color: _textDark,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'Update task information and workflow status',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                              },
                              icon: const Icon(
                                Icons.close_rounded,
                                color: _textMuted,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 26),

                        _dialogLabel(
                          'CLIENT INFORMATION',
                        ),

                        const SizedBox(height: 8),

                        TextField(
                          controller: clientCtrl,
                          decoration: _premiumInput(
                            'Client Name',
                            Icons.business_rounded,
                          ),
                        ),

                        const SizedBox(height: 20),

                        _dialogLabel(
                          'SCHEDULING DETAILS',
                        ),

                        const SizedBox(height: 8),

                        TextField(
                          controller: scheduleCtrl,
                          maxLines: 4,
                          decoration: _premiumInput(
                            'Enter scheduling details',
                            Icons.calendar_month_rounded,
                          ),
                        ),

                        const SizedBox(height: 20),

                        _dialogLabel(
                          'WORKFLOW STATUS',
                        ),

                        const SizedBox(height: 8),

                        DropdownButtonFormField<String>(
                          value: selectedStatus,
                          isExpanded: true,
                          decoration: _premiumInput(
                            'Select Status',
                            Icons.track_changes_rounded,
                          ),
                          items: statusOptions.map((status) {
                            return DropdownMenuItem(
                              value: status,
                              child: Text(
                                status,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight:
                                      FontWeight.w800,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() {
                                selectedStatus = value;
                              });
                            }
                          },
                        ),

                        const SizedBox(height: 28),

                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                },
                                style:
                                    OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  side: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                  ),
                                  shape:
                                      RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: _textMuted,
                                    fontWeight:
                                        FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(ctx);

                                  updateTask(
                                    item,
                                    clientCtrl.text.trim(),
                                    scheduleCtrl.text.trim(),
                                    selectedStatus,
                                  );
                                },
                                style:
                                    ElevatedButton.styleFrom(
                                  backgroundColor: _brand,
                                  foregroundColor:
                                      Colors.white,
                                  elevation: 0,
                                  padding:
                                      const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  shape:
                                      RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Save Changes',
                                  style: TextStyle(
                                    fontWeight:
                                        FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _dialogLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
        color: _textMuted,
      ),
    );
  }

  InputDecoration _premiumInput(
    String hint,
    IconData icon,
  ) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(
        icon,
        size: 20,
        color: _brand,
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFE2E8F0),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: _brand,
          width: 1.5,
        ),
      ),
    );
  }

  // ============================================================
  // DELETE DIALOG
  // ============================================================

  void showDeleteDialog(int id) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 430,
            ),
            child: Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF1F2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_forever_rounded,
                      color: Colors.redAccent,
                      size: 28,
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'Delete Task Record?',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: _textDark,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'This action cannot be undone. The selected history record will be permanently removed.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: _textMuted,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                          },
                          style:
                              OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            deleteTask(id);
                          },
                          style:
                              ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.redAccent,
                            foregroundColor:
                                Colors.white,
                            elevation: 0,
                            padding:
                                const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Delete',
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.w800,
                            ),
                          ),
                        ),
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

  // ============================================================
  // SNACKBAR
  // ============================================================

  void showSnack(String message, bool success) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              success ? const Color(0xFF059669) : Colors.redAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              Icon(
                success
                    ? Icons.check_circle_rounded
                    : Icons.error_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  // ============================================================
  // DATE FORMAT
  // ============================================================

  String formatDate(String value) {
    if (value.isEmpty) return '-';

    try {
      final d = DateTime.parse(value).toLocal();

      final day =
          d.day.toString().padLeft(2, '0');

      final month =
          d.month.toString().padLeft(2, '0');

      final year = d.year;

      final hour =
          d.hour.toString().padLeft(2, '0');

      final minute =
          d.minute.toString().padLeft(2, '0');

      return '$day/$month/$year  $hour:$minute';
    } catch (_) {
      return value;
    }
  }

  // ============================================================
  // STATUS DATA
  // ============================================================

  int get totalCount => allRecords.length;

  int get completedCount => allRecords
      .where((e) =>
          e.status.toUpperCase() == 'COMPLETED')
      .length;

  int get processingCount => allRecords
      .where((e) =>
          e.status.toUpperCase() == 'PROCESS')
      .length;

  int get holdCount => allRecords
      .where((e) =>
          e.status.toUpperCase() == 'HOLD')
      .length;

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, pageConstraints) {
        final isMobile =
            pageConstraints.maxWidth < 700;

        return Container(
          color: _surface,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(
              isMobile ? 14 : 26,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                _buildHeroHeader(isMobile),

                const SizedBox(height: 20),

                _buildStats(isMobile),

                const SizedBox(height: 20),

                _buildFilters(isMobile),

                const SizedBox(height: 20),

                isMobile
                    ? _buildMobileList()
                    : _buildDesktopTable(),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // FUTURISTIC HERO HEADER
  // ============================================================

  Widget _buildHeroHeader(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        isMobile ? 20 : 28,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF061A3A),
            Color(0xFF003A99),
            Color(0xFF0052CC),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _brand.withValues(alpha: 0.20),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                _heroContent(),

                const SizedBox(height: 20),

                _backButton(fullWidth: true),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: _heroContent(),
                ),
                const SizedBox(width: 20),
                _backButton(),
              ],
            ),
    );
  }

  Widget _heroContent() {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: Colors.white.withValues(
              alpha: 0.12,
            ),
            borderRadius:
                BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(
                alpha: 0.18,
              ),
            ),
          ),
          child: const Icon(
            Icons.history_rounded,
            color: Colors.white,
            size: 29,
          ),
        ),

        const SizedBox(width: 16),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'VIDEO PRODUCTION',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF93C5FD),
                  letterSpacing: 2,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),

              const SizedBox(height: 5),

              const Text(
                'Task History Command Center',
                maxLines: 2,
                overflow:
                    TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight:
                      FontWeight.w900,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Monitor task records, manage workflow progress and review production history.',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFFDBEAFE),
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 14),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _heroPill(
                    Icons.cloud_done_rounded,
                    '$totalCount Total Records',
                  ),
                  _heroPill(
                    Icons.search_rounded,
                    '${filteredRecords.length} Visible',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _heroPill(
    IconData icon,
    String text,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: 0.10,
        ),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: const Color(0xFFBAE6FD),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _backButton({
    bool fullWidth = false,
  }) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: OutlinedButton.icon(
        onPressed: _openPlanner,
        icon: const Icon(
          Icons.arrow_back_rounded,
          size: 18,
        ),
        label: const Text(
          'Back to Planner',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          padding:
              const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 15,
          ),
          side: BorderSide(
            color: Colors.white.withValues(
              alpha: 0.25,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // STATS
  // ============================================================

  Widget _buildStats(bool isMobile) {
    final cards = [
      _StatData(
        'TOTAL',
        totalCount.toString(),
        Icons.dashboard_rounded,
        _brand,
      ),
      _StatData(
        'COMPLETED',
        completedCount.toString(),
        Icons.check_circle_rounded,
        const Color(0xFF16A34A),
      ),
      _StatData(
        'IN PROCESS',
        processingCount.toString(),
        Icons.timelapse_rounded,
        const Color(0xFFD97706),
      ),
      _StatData(
        'ON HOLD',
        holdCount.toString(),
        Icons.pause_circle_rounded,
        const Color(0xFFDC2626),
      ),
    ];

    if (isMobile) {
      return GridView.builder(
        shrinkWrap: true,
        physics:
            const NeverScrollableScrollPhysics(),
        itemCount: cards.length,
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.55,
        ),
        itemBuilder: (_, index) {
          return _statCard(cards[index]);
        },
      );
    }

    return Row(
      children: cards
          .map(
            (item) => Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.only(
                  right: 12,
                ),
                child: _statCard(item),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _statCard(_StatData item) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE8EDF5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: item.color.withValues(
                alpha: 0.10,
              ),
              borderRadius:
                  BorderRadius.circular(13),
            ),
            child: Icon(
              item.icon,
              color: item.color,
              size: 21,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 9,
                    color: _textMuted,
                    fontWeight:
                        FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.value,
                  style: const TextStyle(
                    fontSize: 22,
                    color: _textDark,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FILTER BAR
  // ============================================================

  Widget _buildFilters(bool isMobile) {
    final statusFilter = _filterButton(
      icon: Icons.filter_list_rounded,
      label: selectedStatusFilter ?? 'All Statuses',
      onTap: _showStatusFilter,
      active: selectedStatusFilter != null,
    );

    final dateFilter = _filterButton(
      icon: selectedDateFilter != null
          ? Icons.close_rounded
          : Icons.calendar_month_rounded,
      label: selectedDateFilter != null
          ? '${selectedDateFilter!.day}/${selectedDateFilter!.month}/${selectedDateFilter!.year}'
          : 'Filter by Date',
      onTap: _selectDateFilter,
      active: selectedDateFilter != null,
    );

    final refreshButton = _filterButton(
      icon: Icons.refresh_rounded,
      label: 'Refresh',
      onTap: loadHistory,
    );

    if (isMobile) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: statusFilter),
              const SizedBox(width: 10),
              Expanded(child: dateFilter),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: refreshButton,
          ),
        ],
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        statusFilter,
        dateFilter,
        refreshButton,
      ],
    );
  }

  Widget _filterButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return Material(
      color: Colors.white,
      borderRadius:
          BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(12),
        child: Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(12),
            border: Border.all(
              color: active
                  ? _brand
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 17,
                color: active
                    ? _brand
                    : _textMuted,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: active
                        ? _brand
                        : _textDark,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStatusFilter() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: Wrap(
            runSpacing: 8,
            children: [
              const Text(
                'Filter by Status',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              _statusOption(
                context,
                'All',
                Icons.grid_view_rounded,
              ),
              _statusOption(
                context,
                'HOLD',
                Icons.pause_circle_rounded,
              ),
              _statusOption(
                context,
                'PROCESS',
                Icons.timelapse_rounded,
              ),
              _statusOption(
                context,
                'COMPLETED',
                Icons.check_circle_rounded,
              ),
            ],
          ),
        );
      },
    );

    if (selected != null) {
      setState(() {
        selectedStatusFilter =
            selected == 'All'
                ? null
                : selected;
      });

      applyFilter();
    }
  }

  Widget _statusOption(
    BuildContext context,
    String status,
    IconData icon,
  ) {
    return ListTile(
      leading: Icon(
        icon,
        color: _brand,
      ),
      title: Text(
        status == 'All'
            ? 'All Statuses'
            : status,
        style: const TextStyle(
          fontWeight:
              FontWeight.w700,
        ),
      ),
      onTap: () {
        Navigator.pop(context, status);
      },
    );
  }

  Future<void> _selectDateFilter() async {
    if (selectedDateFilter != null) {
      setState(() {
        selectedDateFilter = null;
      });

      applyFilter();
      return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate:
          selectedDateFilter ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        selectedDateFilter = picked;
      });

      applyFilter();
    }
  }

  // ============================================================
  // DESKTOP TABLE
  // ============================================================

  Widget _buildDesktopTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.025,
            ),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _desktopTableHeader(),

          const Divider(
            height: 1,
            color: Color(0xFFE2E8F0),
          ),

          if (loading)
            const SizedBox(
              height: 300,
              child: Center(
                child:
                    CircularProgressIndicator(
                  color: _brand,
                ),
              ),
            )
          else if (filteredRecords.isEmpty)
            _emptyState()
          else
            ...filteredRecords
                .asMap()
                .entries
                .map(
                  (entry) => _desktopRow(
                    entry.key,
                    entry.value,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _desktopTableHeader() {
    return Container(
      height: 58,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      child: Row(
        children: [
          _headerCell(
            'S.No',
            width: 70,
            onTap: () {
              setState(() {
                isSNoAscending =
                    !isSNoAscending;

                filteredRecords.sort(
                  (a, b) =>
                      isSNoAscending
                          ? a.id.compareTo(b.id)
                          : b.id.compareTo(a.id),
                );
              });
            },
          ),

          _headerCell(
            'Shared Date',
            width: 170,
          ),

          _headerCell(
            'Client Name',
            width: 180,
            onTap: () {
              setState(() {
                isClientAscending =
                    !isClientAscending;

                filteredRecords.sort(
                  (a, b) =>
                      isClientAscending
                          ? a.clientName
                              .toLowerCase()
                              .compareTo(
                                b.clientName
                                    .toLowerCase(),
                              )
                          : b.clientName
                              .toLowerCase()
                              .compareTo(
                                a.clientName
                                    .toLowerCase(),
                              ),
                );
              });
            },
          ),

          const Expanded(
            child: Center(
              child: Text(
                'Scheduling Details',
                style: _headerStyle,
              ),
            ),
          ),

          _headerCell(
            'Shared To',
            width: 170,
          ),

          _headerCell(
            'Status',
            width: 130,
          ),

          _headerCell(
            'Actions',
            width: 130,
          ),
        ],
      ),
    );
  }

  Widget _headerCell(
    String title, {
    required double width,
    VoidCallback? onTap,
  }) {
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Text(
            title,
            style: _headerStyle,
          ),
        ),
      ),
    );
  }

  Widget _desktopRow(
    int index,
    VideographerHistoryItem item,
  ) {
    return Container(
      constraints:
          const BoxConstraints(
        minHeight: 76,
      ),
      decoration: BoxDecoration(
        color: index.isEven
            ? Colors.white
            : const Color(0xFFFAFBFD),
        border: const Border(
          top: BorderSide(
            color: Color(0xFFF1F5F9),
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  fontSize: 12,
                  color: _textMuted,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ),
          ),

          SizedBox(
            width: 170,
            child: Center(
              child: Text(
                formatDate(item.sharedAt),
                textAlign:
                    TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  color: _textMuted,
                ),
              ),
            ),
          ),

          SizedBox(
            width: 180,
            child: Center(
              child: Padding(
                padding:
                    const EdgeInsets.all(10),
                child: Text(
                  item.clientName,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  textAlign:
                      TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _textDark,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),

          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 12,
              ),
              child: Text(
                item.schedulingDetails,
                maxLines: 3,
                overflow:
                    TextOverflow.ellipsis,
                textAlign:
                    TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: _textMuted,
                  height: 1.4,
                ),
              ),
            ),
          ),

          SizedBox(
            width: 170,
            child: Center(
              child: Padding(
                padding:
                    const EdgeInsets.all(10),
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    Text(
                      item.sharedTo,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _brand,
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                    if (item.receiverRole
                        .isNotEmpty)
                      Text(
                        item.receiverRole,
                        style: const TextStyle(
                          fontSize: 9,
                          color: _textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          SizedBox(
            width: 130,
            child: Center(
              child:
                  _statusBadge(item.status),
            ),
          ),

          SizedBox(
            width: 130,
            child: Center(
              child: Row(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  _actionIcon(
                    icon:
                        Icons.edit_rounded,
                    color: _brand,
                    tooltip: 'Edit',
                    onTap: () =>
                        showEditDialog(item),
                  ),
                  const SizedBox(width: 4),
                  _actionIcon(
                    icon: Icons
                        .delete_outline_rounded,
                    color: Colors.redAccent,
                    tooltip: 'Delete',
                    onTap: () =>
                        showDeleteDialog(
                      item.id,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final normalized =
        status.toUpperCase();

    Color color;

    if (normalized == 'COMPLETED') {
      color = const Color(0xFF16A34A);
    } else if (normalized == 'PROCESS') {
      color = const Color(0xFFD97706);
    } else {
      color = const Color(0xFFDC2626);
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: 0.10,
        ),
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(
            alpha: 0.20,
          ),
        ),
      ),
      child: Text(
        normalized,
        style: TextStyle(
          fontSize: 9,
          color: color,
          fontWeight:
              FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _actionIcon({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(10),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(
              alpha: 0.08,
            ),
            borderRadius:
                BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: color,
            size: 17,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MOBILE LIST
  // ============================================================

  Widget _buildMobileList() {
    if (loading) {
      return const SizedBox(
        height: 300,
        child: Center(
          child: CircularProgressIndicator(
            color: _brand,
          ),
        ),
      );
    }

    if (filteredRecords.isEmpty) {
      return _emptyState();
    }

    return ListView.separated(
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(),
      itemCount:
          filteredRecords.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item =
            filteredRecords[index];

        return _mobileCard(
          index,
          item,
        );
      },
    );
  }

  Widget _mobileCard(
    int index,
    VideographerHistoryItem item,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.025,
            ),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _brand.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius:
                      BorderRadius.circular(20),
                ),
                child: Text(
                  'TASK ${(index + 1).toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight:
                        FontWeight.w900,
                    color: _brand,
                    letterSpacing: 1,
                  ),
                ),
              ),

              const Spacer(),

              _statusBadge(item.status),
            ],
          ),

          const SizedBox(height: 16),

          Text(
            item.clientName,
            style: const TextStyle(
              fontSize: 17,
              fontWeight:
                  FontWeight.w900,
              color: _textDark,
            ),
          ),

          const SizedBox(height: 12),

          _mobileInfoRow(
            Icons.description_rounded,
            'Scheduling',
            item.schedulingDetails,
          ),

          const SizedBox(height: 10),

          _mobileInfoRow(
            Icons.person_rounded,
            'Shared To',
            item.sharedTo,
          ),

          const SizedBox(height: 10),

          _mobileInfoRow(
            Icons.access_time_rounded,
            'Shared At',
            formatDate(item.sharedAt),
          ),

          const SizedBox(height: 16),

          const Divider(
            color: Color(0xFFF1F5F9),
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () =>
                      showEditDialog(item),
                  icon: const Icon(
                    Icons.edit_rounded,
                    color: _brand,
                    size: 17,
                  ),
                  label: const Text(
                    'Edit',
                    style: TextStyle(
                      color: _brand,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),
              ),

              Container(
                width: 1,
                height: 24,
                color: const Color(
                  0xFFE2E8F0,
                ),
              ),

              Expanded(
                child: TextButton.icon(
                  onPressed: () =>
                      showDeleteDialog(
                    item.id,
                  ),
                  icon: const Icon(
                    Icons
                        .delete_outline_rounded,
                    color: Colors.redAccent,
                    size: 17,
                  ),
                  label: const Text(
                    'Delete',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mobileInfoRow(
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius:
                BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            size: 15,
            color: _brand,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 9,
                  color: _textMuted,
                  fontWeight:
                      FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                value.isEmpty
                    ? '-'
                    : value,
                style: const TextStyle(
                  fontSize: 12,
                  color: _textDark,
                  fontWeight:
                      FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      constraints:
          const BoxConstraints(
        minHeight: 300,
      ),
      padding: const EdgeInsets.all(30),
      child: Center(
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: _brand.withValues(
                  alpha: 0.08,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.video_library_outlined,
                color: _brand,
                size: 32,
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'No Task Records Found',
              style: TextStyle(
                fontSize: 17,
                fontWeight:
                    FontWeight.w900,
                color: _textDark,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'There are currently no videographer task history records matching your filters.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: _textMuted,
              ),
            ),

            const SizedBox(height: 18),

            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  selectedStatusFilter = null;
                  selectedDateFilter = null;
                });

                applyFilter();
              },
              icon: const Icon(
                Icons.refresh_rounded,
                size: 17,
              ),
              label: const Text(
                'Reset Filters',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// MODEL
// ============================================================

class VideographerHistoryItem {
  final int id;
  final String clientName;
  final String schedulingDetails;
  final String sharedTo;
  final String receiverRole;
  final String receiverShort;
  final String status;
  final String sharedAt;

  VideographerHistoryItem({
    required this.id,
    required this.clientName,
    required this.schedulingDetails,
    required this.sharedTo,
    required this.receiverRole,
    required this.receiverShort,
    required this.sharedAt,
    required this.status,
  });
}

// ============================================================
// STAT MODEL
// ============================================================

class _StatData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatData(
    this.label,
    this.value,
    this.icon,
    this.color,
  );
}

// ============================================================
// TABLE HEADER STYLE
// ============================================================

const TextStyle _headerStyle = TextStyle(
  fontSize: 10,
  fontWeight: FontWeight.w900,
  color: Color(0xFF64748B),
  letterSpacing: 0.8,
);