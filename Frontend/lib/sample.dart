import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:my_first_app/core/constants/app_colors.dart';
import 'package:my_first_app/core/constants/employee_role.dart';
import 'package:my_first_app/services/auth_service.dart';
import '../../services/api_config.dart';

enum TaskStatus { idle, running, held, completed, rejected, accepted, rework }

class AssignedTasksContent extends StatefulWidget {
  final EmployeeRole role;
  const AssignedTasksContent({super.key, required this.role});

  @override
  State<AssignedTasksContent> createState() => _AssignedTasksContentState();
}

class _AssignedTasksContentState extends State<AssignedTasksContent> {
  // static const String _baseUrl = '/api';
  static String get _baseUrl => ApiConfig.baseUrl;

  // ✅ FIXED: Updated column widths for better layout
  static const double snoWidth = 50;
  static const double submitDateWidth = 120;
  static const double taskWidth = 150;
  static const double actionWidth = 600;
  static const double durationWidth = 100;
  static const double commentWidth = 180;
  static const double performanceWidth = 140;
  static const double statusWidth = 100;
  static const double cellHeight = 55;

  double get totalTableWidth =>
      snoWidth +
      submitDateWidth +
      taskWidth +
      actionWidth +
      durationWidth +
      commentWidth +
      performanceWidth +
      statusWidth;

  // ✅ FIXED: Single ScrollController for header and body sync
  final ScrollController _horizontalController = ScrollController();

  // Dynamically loaded tasks from backend
  List<Map<String, dynamic>> assignedTasks = [];
  List<String> taskTabNames = [];
  final List<Map<String, dynamic>> additionalTasks = [];

  // ✅ NEW: Time Management data for performance calculation
  Map<String, int> expectedTimingMinutes = {}; // task_name -> minutes

  bool showAdditionalTask = false;
  bool showTimeTracker = false;
  int? selectedTabIndex;

  bool _loadingTasks = true;
  String? _error;
  String? selectedClient;

  // Additional Task input fields
  String clientName = '';
  String deliverableName = '';
  String durationValue = '';
  String submissionDate = '';

  // ✅ NEW: Comments for each task
  Map<String, String> taskComments = {};

  // Timer tracking for individual tasks - INDEPENDENT PER TASK
  Map<String, DateTime> taskStartTimes = {};
  Map<String, DateTime> taskCurrentSessionStartTime = {};
  Map<String, Timer> taskTimers = {};
  Map<String, Duration> taskDurations = {};
  Map<String, Duration> taskTotalDurations = {};
  Map<String, TaskStatus> taskStatus = {};

  // Multiple times tracking
  Map<String, List<DateTime>> taskHoldTimes = {};
  Map<String, List<DateTime>> taskRestartTimes = {};
  Map<String, List<DateTime>> taskCompletedTimes = {};
  Map<String, List<DateTime>> taskRejectedTimes = {};

  // Button visibility state
  Map<String, String> taskButtonState = {};

  // Current running task
  String? currentRunningTaskKey;

  @override
  void initState() {
    super.initState();
    _fetchTimingData();
    _fetchEmployeeAssignedTasks();
  }

  Future<void> _fetchTimingData() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/timings'));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List data = body['data'];

        for (var item in data) {
          final taskName = item['task_name'] as String;
          final timing = item['timing'] as String;
          final minutes = _convertTimingToMinutes(timing);
          expectedTimingMinutes[taskName] = minutes;
        }
        debugPrint('✅ Loaded expected timings: $expectedTimingMinutes');
      }
    } catch (e) {
      debugPrint('❌ Error fetching timings: $e');
    }
  }

  int _convertTimingToMinutes(String timing) {
    try {
      final parts = timing.split(' ');
      if (parts.length < 2) return 0;

      final value = int.tryParse(parts[0]) ?? 0;
      final unit = parts[1].toLowerCase();

      if (unit.startsWith('min')) return value;
      if (unit.startsWith('hr')) return value * 60;
      if (unit.startsWith('day')) return value * 24 * 60;

      return 0;
    } catch (e) {
      debugPrint('❌ Error converting timing: $e');
      return 0;
    }
  }

  String _calculatePerformance(String singleTask, Duration? actualDuration) {
    if (actualDuration == null) return 'N/A';

    final expected = expectedTimingMinutes[singleTask];
    if (expected == null) return 'N/A';

    final actualMinutes = actualDuration.inMinutes;

    if (actualMinutes == expected) {
      return 'Achieved';
    } else if (actualMinutes < expected) {
      return 'Before In';
    } else {
      return 'Delay Out';
    }
  }

  Color _getPerformanceColor(String performance) {
    switch (performance) {
      case 'Achieved':
        return const Color(0xFF00812B);
      case 'Before In':
        return const Color(0xFF1D4ED8);
      case 'Delay Out':
        return const Color(0xFFC40000);
      default:
        return Colors.grey;
    }
  }

  List<String> _splitTasks(String tasksString) {
    if (tasksString.isEmpty) return [];
    return tasksString
        .split(',')
        .map((task) => task.trim())
        .where((task) => task.isNotEmpty)
        .toList();
  }

  Future<void> _fetchEmployeeAssignedTasks() async {
    setState(() => _loadingTasks = true);
    try {
      final authService = context.read<AuthService>();
      final employeeName = authService.user?['fullName'] ?? '';

      if (employeeName.isEmpty) {
        setState(() {
          _error = 'Employee name not found. Please re-login.';
          _loadingTasks = false;
        });
        return;
      }

      debugPrint('👤 Fetching tasks for employee: $employeeName');

      final response = await http.get(
        Uri.parse('$_baseUrl/employee-tasks/by-employee/$employeeName'),
      );

      debugPrint('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final List<dynamic> data = jsonData['data'] ?? [];

        final allTabs = <String>{};
        final processedTasks = <Map<String, dynamic>>[];

        for (var task in data) {
          final taskMap = Map<String, dynamic>.from(task);
          final employeeNameUpper = employeeName.toUpperCase();

          if (taskMap['designer'] != null &&
              taskMap['designer'].toString().toUpperCase() == employeeNameUpper) {
            final taskList = taskMap['designer_tasks']?.toString() ?? '';
            final individualTasks = _splitTasks(taskList);

            for (var singleTask in individualTasks) {
              allTabs.add(singleTask);
              processedTasks.add({
                'client_name': taskMap['client_name'],
                'deliverables': taskMap['deliverables'],
                'deadline': taskMap['deadline'],
                'assignedRole': 'designer',
                'singleTask': singleTask,
                'assignedDate': taskMap['designer_submit_date'],
                'taskType': 'Designer',
              });
            }
          } else if (taskMap['videographer'] != null &&
              taskMap['videographer'].toString().toUpperCase() == employeeNameUpper) {
            final taskList = taskMap['videographer_tasks']?.toString() ?? '';
            final individualTasks = _splitTasks(taskList);

            for (var singleTask in individualTasks) {
              allTabs.add(singleTask);
              processedTasks.add({
                'client_name': taskMap['client_name'],
                'deliverables': taskMap['deliverables'],
                'deadline': taskMap['deadline'],
                'assignedRole': 'videographer',
                'singleTask': singleTask,
                'assignedDate': taskMap['videographer_submit_date'],
                'taskType': 'Videographer',
              });
            }
          } else if (taskMap['ads_handling'] != null &&
              taskMap['ads_handling'].toString().toUpperCase() == employeeNameUpper) {
            final taskList = taskMap['ads_platform']?.toString() ?? '';
            final individualTasks = _splitTasks(taskList);

            for (var singleTask in individualTasks) {
              allTabs.add(singleTask);
              processedTasks.add({
                'client_name': taskMap['client_name'],
                'deliverables': taskMap['deliverables'],
                'deadline': taskMap['deadline'],
                'assignedRole': 'ads',
                'singleTask': singleTask,
                'assignedDate': taskMap['ads_submit_date'],
                'taskType': 'Ads Handler',
              });
            }
          } else if (taskMap['page_handling'] != null &&
              taskMap['page_handling'].toString().toUpperCase() == employeeNameUpper) {
            final taskList = taskMap['pages_platform']?.toString() ?? '';
            final individualTasks = _splitTasks(taskList);

            for (var singleTask in individualTasks) {
              allTabs.add(singleTask);
              processedTasks.add({
                'client_name': taskMap['client_name'],
                'deliverables': taskMap['deliverables'],
                'deadline': taskMap['deadline'],
                'assignedRole': 'page',
                'singleTask': singleTask,
                'assignedDate': taskMap['page_submit_date'],
                'taskType': 'Page Handler',
              });
            }
          } else if (taskMap['ui_ux_designer'] != null &&
              taskMap['ui_ux_designer'].toString().toUpperCase() == employeeNameUpper) {
            final taskList = taskMap['ui_ux_tasks']?.toString() ?? '';
            final individualTasks = _splitTasks(taskList);

            for (var singleTask in individualTasks) {
              allTabs.add(singleTask);
              processedTasks.add({
                'client_name': taskMap['client_name'],
                'deliverables': taskMap['deliverables'],
                'deadline': taskMap['deadline'],
                'assignedRole': 'uiux',
                'singleTask': singleTask,
                'assignedDate': taskMap['ui_ux_submit_date'],
                'taskType': 'UI/UX Designer',
              });
            }
          } else if (taskMap['developer'] != null &&
              taskMap['developer'].toString().toUpperCase() == employeeNameUpper) {
            final taskList = taskMap['developer_tasks']?.toString() ?? '';
            final individualTasks = _splitTasks(taskList);

            for (var singleTask in individualTasks) {
              allTabs.add(singleTask);
              processedTasks.add({
                'client_name': taskMap['client_name'],
                'deliverables': taskMap['deliverables'],
                'deadline': taskMap['deadline'],
                'assignedRole': 'developer',
                'singleTask': singleTask,
                'assignedDate': taskMap['developer_submit_date'],
                'taskType': 'Developer',
              });
            }
          }
        }

        setState(() {
          assignedTasks = processedTasks;
          taskTabNames = allTabs.toList();
          if (taskTabNames.isNotEmpty) {
            selectedTabIndex = 0;
          }
          _loadingTasks = false;
          debugPrint('✅ Loaded ${assignedTasks.length} individual tasks');
        });
      } else {
        setState(() {
          _error = 'Failed to load tasks (${response.statusCode})';
          _loadingTasks = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error fetching tasks: $e');
      setState(() {
        _error = 'Connection error: $e';
        _loadingTasks = false;
      });
    }
  }

  String _getTaskKey(int index, String clientName, String singleTask) =>
      'task_${index}_${clientName}_$singleTask';

  void _handleStart(String taskKey) {
    setState(() {
      if (currentRunningTaskKey != null && currentRunningTaskKey != taskKey) {
        _handleHold(currentRunningTaskKey!);
      }

      taskStatus[taskKey] = TaskStatus.running;
      taskStartTimes[taskKey] = DateTime.now();
      taskCurrentSessionStartTime[taskKey] = DateTime.now();
      taskDurations[taskKey] = Duration.zero;
      taskButtonState[taskKey] = 'hold_complete_reject';
      currentRunningTaskKey = taskKey;

      taskTimers[taskKey] = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          taskDurations[taskKey] =
              DateTime.now().difference(taskCurrentSessionStartTime[taskKey]!);
        });
      });
    });
  }

  void _handleHold(String taskKey) {
    setState(() {
      taskStatus[taskKey] = TaskStatus.held;

      taskHoldTimes.putIfAbsent(taskKey, () => []);
      taskHoldTimes[taskKey]!.add(DateTime.now());

      if (taskDurations[taskKey] != null) {
        taskTotalDurations[taskKey] = (taskTotalDurations[taskKey] ?? Duration.zero) +
            taskDurations[taskKey]!;
      }

      taskTimers[taskKey]?.cancel();
      taskTimers.remove(taskKey);
      taskCurrentSessionStartTime.remove(taskKey);
      taskDurations[taskKey] = Duration.zero;
      taskButtonState[taskKey] = 'restart';
      currentRunningTaskKey = null;
    });
  }

  void _handleRestart(String taskKey) {
    setState(() {
      taskStatus[taskKey] = TaskStatus.running;

      taskRestartTimes.putIfAbsent(taskKey, () => []);
      taskRestartTimes[taskKey]!.add(DateTime.now());

      taskCurrentSessionStartTime[taskKey] = DateTime.now();

      taskDurations[taskKey] = Duration.zero;
      taskButtonState[taskKey] = 'hold_complete_reject';
      currentRunningTaskKey = taskKey;

      taskTimers[taskKey] = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          taskDurations[taskKey] =
              DateTime.now().difference(taskCurrentSessionStartTime[taskKey]!);
        });
      });
    });
  }

  void _handleComplete(String taskKey) {
    setState(() {
      taskStatus[taskKey] = TaskStatus.completed;

      taskCompletedTimes.putIfAbsent(taskKey, () => []);
      taskCompletedTimes[taskKey]!.add(DateTime.now());

      if (taskDurations[taskKey] != null) {
        taskTotalDurations[taskKey] = (taskTotalDurations[taskKey] ?? Duration.zero) +
            taskDurations[taskKey]!;
      }

      taskTimers[taskKey]?.cancel();
      taskTimers.remove(taskKey);
      taskCurrentSessionStartTime.remove(taskKey);
      taskDurations[taskKey] = Duration.zero;
      taskButtonState[taskKey] = 'completed';
      currentRunningTaskKey = null;
    });
  }

  void _handleReject(String taskKey) {
    setState(() {
      taskStatus[taskKey] = TaskStatus.rejected;

      taskRejectedTimes.putIfAbsent(taskKey, () => []);
      taskRejectedTimes[taskKey]!.add(DateTime.now());

      if (taskDurations[taskKey] != null) {
        taskTotalDurations[taskKey] = (taskTotalDurations[taskKey] ?? Duration.zero) +
            taskDurations[taskKey]!;
      }

      taskTimers[taskKey]?.cancel();
      taskTimers.remove(taskKey);
      taskCurrentSessionStartTime.remove(taskKey);
      taskDurations[taskKey] = Duration.zero;
      taskButtonState[taskKey] = 'rejected';
      currentRunningTaskKey = null;
    });
  }

  String formatTime(DateTime? dateTime) {
    if (dateTime == null) return '--:--:--';
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  String formatDuration(Duration? duration) {
    if (duration == null) return '--:--:--';
    return '${duration.inHours.toString().padLeft(2, '0')}:${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${duration.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }

  String _getTaskStatus(String taskKey) {
    final status = taskStatus[taskKey] ?? TaskStatus.idle;
    switch (status) {
      case TaskStatus.completed:
        return 'COMPLETED';
      case TaskStatus.rejected:
        return 'REJECTED';
      case TaskStatus.running:
        return 'IN PROGRESS';
      case TaskStatus.held:
        return 'ON HOLD';
      default:
        return 'IDLE';
    }
  }

  @override
  void dispose() {
    _horizontalController.dispose();

    for (var timer in taskTimers.values) {
      timer.cancel();
    }

    super.dispose();
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
          if (showAdditionalTask)
            _additionalTaskSection()
          else ...[
            _taskCategoryTabs(),
            if (_loadingTasks)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(children: [
                    Text(_error!,
                        style: const TextStyle(color: AppColors.textGrey)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _fetchEmployeeAssignedTasks,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF004AAD)),
                      child: const Text('Retry',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ]),
                ),
              )
            else if (selectedTabIndex != null && assignedTasks.isNotEmpty)
              _taskDetailsContainer()
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Text(
                    taskTabNames.isEmpty
                        ? 'No tasks assigned yet'
                        : 'No tasks for this category',
                    style: const TextStyle(color: AppColors.textGrey),
                  ),
                ),
              )
          ],
        ],
      ),
    );
  }

  Widget _pageHeader() {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              showAdditionalTask ? 'Additional Tasks' : 'Assigned Tasks',
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark),
            ),
            const SizedBox(height: 6),
            const Text(
              'Monitor and manage tasks assigned to you with real-time progress updates.',
              style: TextStyle(fontSize: 14, color: AppColors.textGrey),
            ),
          ],
        ),
        const Spacer(),
        if (!showAdditionalTask)
          ElevatedButton(
            onPressed: () => setState(() => showAdditionalTask = true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF004AAD),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
            ),
            child: const Text('+ Add Additional Task',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          ),
      ],
    );
  }

  Widget _taskCategoryTabs() {
    if (taskTabNames.isEmpty) {
      return Container(
        height: 50,
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: const Center(
          child: Text(
            'No task categories assigned',
            style: TextStyle(color: AppColors.textGrey),
          ),
        ),
      );
    }

    return Container(
      height: 60,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < taskTabNames.length; i++)
              InkWell(
                onTap: () {
                  setState(() {
                    selectedTabIndex = i;
                    selectedClient = null;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  margin: const EdgeInsets.only(right: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: selectedTabIndex == i
                            ? const Color(0xFF004AAD)
                            : Colors.transparent,
                        width: selectedTabIndex == i ? 3 : 0,
                      ),
                    ),
                  ),
                  child: Text(
                    taskTabNames[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selectedTabIndex == i
                          ? const Color(0xFF004AAD)
                          : Colors.grey,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _taskDetailsContainer() {
    if (selectedTabIndex == null || selectedTabIndex! >= taskTabNames.length) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: Text('No task details available'),
        ),
      );
    }

    final selectedTabName = taskTabNames[selectedTabIndex!];

    final tasksForTab = assignedTasks
        .where((task) => task['singleTask'] == selectedTabName)
        .toList();

    if (tasksForTab.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: Text('No tasks for this category'),
        ),
      );
    }

    final uniqueClients = <String>[];
    for (var task in tasksForTab) {
      final clientName = task['client_name'] as String?;
      if (clientName != null && !uniqueClients.contains(clientName)) {
        uniqueClients.add(clientName);
      }
    }

    if (selectedClient == null || !uniqueClients.contains(selectedClient)) {
      selectedClient = uniqueClients.first;
    }

    final currentClientIndex = uniqueClients.indexOf(selectedClient!);

    final currentTask = tasksForTab.firstWhere(
      (task) => task['client_name'] == selectedClient,
      orElse: () => tasksForTab.first,
    );

    final tasksForSelectedClient = tasksForTab
        .where((task) => task['client_name'] == selectedClient)
        .toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: currentClientIndex > 0
                        ? () {
                            setState(() {
                              selectedClient = uniqueClients[currentClientIndex - 1];
                            });
                          }
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: currentClientIndex > 0
                            ? const Color(0xFFD9E8FF)
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        '← PREV',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: currentClientIndex > 0
                              ? const Color(0xFF004AAD)
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    '${currentClientIndex + 1} / ${uniqueClients.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF172554),
                    ),
                  ),
                  InkWell(
                    onTap: currentClientIndex < uniqueClients.length - 1
                        ? () {
                            setState(() {
                              selectedClient =
                                  uniqueClients[currentClientIndex + 1];
                            });
                          }
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: currentClientIndex < uniqueClients.length - 1
                            ? const Color(0xFFD9E8FF)
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        'NEXT →',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: currentClientIndex < uniqueClients.length - 1
                              ? const Color(0xFF004AAD)
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildDetailItem(
                    'CLIENT :',
                    currentTask['client_name'] ?? 'N/A',
                    flex: 2,
                  ),
                  _buildDetailItem(
                    'DELIVERABLES :',
                    currentTask['deliverables'] ?? 'N/A',
                    flex: 3,
                  ),
                  // ✅ FIXED: Show DEADLINE value properly
                  _buildDetailItem(
                    'DEADLINE :',
                    currentTask['deadline'] ?? 'N/A',
                    flex: 2,
                  ),
                  ElevatedButton(
                    onPressed: () =>
                        setState(() => showTimeTracker = !showTimeTracker),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          showTimeTracker ? AppColors.red : const Color(0xFFD9E8FF),
                      foregroundColor: showTimeTracker
                          ? Colors.white
                          : const Color(0xFF003A9B),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(3)),
                    ),
                    child: Text(
                      showTimeTracker ? 'HIDE' : 'OPEN',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (showTimeTracker) _buildTaskTable(tasksForSelectedClient),
      ],
    );
  }

  // ✅ FIXED: Header and body use SAME ScrollController
  Widget _buildTaskTable(List<Map<String, dynamic>> tasks) {
    return Column(
      children: [
        // ✅ Header with sync ScrollController
        Container(
          width: double.infinity,
          height: 45,
          color: const Color(0xFFF1F5F9),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: totalTableWidth,
              child: Row(
                children: const [
                  SizedBox(
                    width: snoWidth,
                    child: Text(
                      "S.NO",
                      style: _tableHeaderStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(
                    width: submitDateWidth,
                    child: Text(
                      "SUBMIT DATE",
                      style: _tableHeaderStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(
                    width: taskWidth,
                    child: Text(
                      "TASK DESCRIPTION",
                      style: _tableHeaderStyle,
                    ),
                  ),
                  SizedBox(
                    width: actionWidth,
                    child: Text(
                      "ACTION",
                      style: _tableHeaderStyle,
                    ),
                  ),
                  SizedBox(
                    width: durationWidth,
                    child: Text(
                      "DURATION",
                      style: _tableHeaderStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(
                    width: commentWidth,
                    child: Text(
                      "COMMENT",
                      style: _tableHeaderStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(
                    width: performanceWidth,
                    child: Text(
                      "PERFORMANCE",
                      style: _tableHeaderStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(
                    width: statusWidth,
                    child: Text(
                      "STATUS",
                      style: _tableHeaderStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // ✅ Body with same ScrollController
        SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: totalTableWidth,
              child: Column(
                children: [
                  for (int i = 0; i < tasks.length; i++)
                    _buildEnhancedTaskRow(i, tasks[i]),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedTaskRow(int index, Map<String, dynamic> task) {
    final taskKey = _getTaskKey(index, task['client_name'], task['singleTask']);
    final currentStatus = taskStatus[taskKey] ?? TaskStatus.idle;
    final currentDuration = taskDurations[taskKey] ?? Duration.zero;

    final totalDuration = taskTotalDurations[taskKey];
    final performance = _calculatePerformance(task['singleTask'], totalDuration);
    final performanceColor = _getPerformanceColor(performance);

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20,vertical: 5),
      margin: const EdgeInsets.symmetric(horizontal: 5,vertical: 4,),

      child: Row(
        children: [
          // S.NO
          SizedBox(
            width: snoWidth,
            child: Text(
              '${index + 1}.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
          // SUBMIT DATE
          SizedBox(
            width: submitDateWidth,
            child: Text(
              task['assignedDate'] ?? '--',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
            ),
          ),
          // TASK DESCRIPTION
          SizedBox(
            width: taskWidth,
            child: Text(
              task['singleTask'] ?? 'N/A',
              style: const TextStyle(fontSize: 11),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          // ACTION COLUMN
          SizedBox(
            width: actionWidth,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  _actionButton(
                    "START",
                    currentStatus == TaskStatus.idle ? Colors.blue[100]! : Colors.grey[200]!,
                    currentStatus == TaskStatus.idle ? Colors.blue[900]! : Colors.grey,
                    currentStatus == TaskStatus.idle ? () => _handleStart(taskKey) : () {},
                  ),
                  const SizedBox(width: 4),
                  if (taskStartTimes[taskKey] != null)
                    Text(
                      'S: ${formatTime(taskStartTimes[taskKey])}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        color: Colors.blue,
                      ),
                    ),
                  const SizedBox(width: 12),
                  _actionButton(
                    "HOLD",
                    currentStatus == TaskStatus.running ? Colors.grey[300]! : Colors.grey[200]!,
                    currentStatus == TaskStatus.running ? Colors.black : Colors.grey,
                    currentStatus == TaskStatus.running ? () => _handleHold(taskKey) : () {},
                  ),
                  const SizedBox(width: 4),
                  if (taskHoldTimes[taskKey] != null && taskHoldTimes[taskKey]!.isNotEmpty)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var holdTime in taskHoldTimes[taskKey]!) ...[
                          Text(
                            formatTime(holdTime),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ],
                    ),
                  const SizedBox(width: 12),
                  _actionButton(
                    "RESTART",
                    currentStatus == TaskStatus.held ? Colors.orange[300]! : Colors.grey[200]!,
                    currentStatus == TaskStatus.held ? Colors.white : Colors.grey,
                    currentStatus == TaskStatus.held ? () => _handleRestart(taskKey) : () {},
                  ),
                  const SizedBox(width: 4),
                  if (taskRestartTimes[taskKey] != null && taskRestartTimes[taskKey]!.isNotEmpty)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var restartTime in taskRestartTimes[taskKey]!) ...[
                          Text(
                            'R: ${formatTime(restartTime)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ],
                    ),
                  const SizedBox(width: 12),
                  _actionButton(
                    "COMPLETED",
                    currentStatus == TaskStatus.running || currentStatus == TaskStatus.completed
                        ? Colors.green[300]!
                        : Colors.grey[200]!,
                    currentStatus == TaskStatus.running || currentStatus == TaskStatus.completed
                        ? Colors.white
                        : Colors.grey,
                    currentStatus == TaskStatus.running ? () => _handleComplete(taskKey) : () {},
                  ),
                  const SizedBox(width: 4),
                  if (taskCompletedTimes[taskKey] != null && taskCompletedTimes[taskKey]!.isNotEmpty)
                    Text(
                      'C: ${formatTime(taskCompletedTimes[taskKey]!.first)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        color: Color(0xFF00812B),
                      ),
                    ),
                  const SizedBox(width: 12),
                  _actionButton(
                    "REJECTED",
                    currentStatus == TaskStatus.running || currentStatus == TaskStatus.rejected
                        ? Colors.red[300]!
                        : Colors.grey[200]!,
                    currentStatus == TaskStatus.running || currentStatus == TaskStatus.rejected
                        ? Colors.white
                        : Colors.grey,
                    currentStatus == TaskStatus.running ? () => _handleReject(taskKey) : () {},
                  ),
                  const SizedBox(width: 4),
                  if (taskRejectedTimes[taskKey] != null && taskRejectedTimes[taskKey]!.isNotEmpty)
                    Text(
                      'Rj: ${formatTime(taskRejectedTimes[taskKey]!.first)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        color: Color(0xFFC40000),
                      ),
                    ),
                  if (currentStatus == TaskStatus.running && currentDuration != Duration.zero)
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(
                        'Running: ${formatDuration(currentDuration)}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF004AAD),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // DURATION COLUMN
          SizedBox(
            width: durationWidth,
            child: Text(
              formatDuration(taskTotalDurations[taskKey]),
              textAlign: TextAlign.left,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF004AAD),
              ),
            ),
          ),
          // COMMENT COLUMN
          SizedBox(
  
  height: cellHeight,
  width:150 ,
   child: Container(
    
      padding: const EdgeInsets.symmetric(horizontal: 5,vertical: 4,),
    alignment: Alignment.center,
    
  child: TextField(
    minLines: 3,
    maxLines: 6,
    style: const TextStyle(fontSize: 10),
    decoration: InputDecoration(
      hintText: 'Add note...',
      hintStyle: const TextStyle(
        fontSize: 9,
        color: Colors.grey,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 8,
      ),
      isDense: true,
    ),
    onChanged: (value) {
      setState(() {
        taskComments[taskKey] = value;
      });
    },
  ),
),// PERFORMANCE COLUMN
          ),    

           

          SizedBox(
  width: 110,
  height: 40,
  child: Container(
    
      padding: const EdgeInsets.symmetric(horizontal: 5,vertical: 4,),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: performanceColor.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(
        color: performanceColor.withValues(alpha: 0.3),
      ),
    ),
    child: Text(
      performance,
      textAlign: TextAlign.center,
      // overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: performanceColor,
      ),
    ),
  ),
),
// STATUS COLUMN
          SizedBox(
            width: statusWidth,
            child: Text(
              _getTaskStatus(taskKey),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _getStatusColor(currentStatus),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.completed:
        return const Color(0xFF00812B);
      case TaskStatus.rejected:
        return const Color(0xFFC40000);
      case TaskStatus.running:
        return const Color(0xFF004AAD);
      case TaskStatus.held:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _actionButton(String title, Color bgColor, Color textColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: textColor.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 9,
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF172554))),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textGrey),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _additionalTaskSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        children: [
          _additionalTaskHeader(),
          if (showTimeTracker) _timeTrackerSection(),
        ],
      ),
    );
  }

  Widget _additionalTaskHeader() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'CLIENT :',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              onChanged: (value) => setState(() => clientName = value),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 3,
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'DELIVERABLES :',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              onChanged: (value) => setState(() => deliverableName = value),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 3,
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'DURATION :',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              onChanged: (value) => setState(() => durationValue = value),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 4,
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'SUBMISSION DATE :',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              onChanged: (value) => setState(() => submissionDate = value),
            ),
          ),
          const SizedBox(width: 60),
          SizedBox(
            width: 80,
            height: 30,
            child: ElevatedButton(
              onPressed: () => setState(() => showTimeTracker = !showTimeTracker),
              style: ElevatedButton.styleFrom(
                backgroundColor: showTimeTracker ? AppColors.red : const Color(0xFFD9E8FF),
                foregroundColor:
                    showTimeTracker ? Colors.white : const Color(0xFF003A9B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                elevation: 0,
              ),
              child: Text(
                showTimeTracker ? 'HIDE' : 'OPEN',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeTrackerSection() {
    return Column(
      children: [
        Container(
          height: 28,
          alignment: Alignment.center,
          color: AppColors.lightBlue,
          child: const Text(
            'TIME TRACKER',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF172554),
            ),
          ),
        ),
        _timeTrackerHeader(),
        if (additionalTasks.isNotEmpty)
          for (int i = 0; i < additionalTasks.length; i++)
            _buildAdditionalTaskRow(i),
      ],
    );
  }

  Widget _timeTrackerHeader() {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: const Row(
        children: [
          SizedBox(width: 80, child: Text('S.NO', style: _tableHeaderStyle, textAlign: TextAlign.center)),
          SizedBox(width: 140, child: Text('SUBMIT DATE', style: _tableHeaderStyle, textAlign: TextAlign.center)),
          Expanded(child: Text('ACTION', style: _tableHeaderStyle)),
        ],
      ),
    );
  }

  Widget _buildAdditionalTaskRow(int index) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text('$index.', textAlign: TextAlign.center)),
          SizedBox(
            width: 140,
            child: Text(submissionDate, textAlign: TextAlign.center),
          ),
          Expanded(
            child: Row(
              children: [
                _actionButton(
                  "START",
                  const Color(0xFFD9E8FF),
                  const Color(0xFF004AAD),
                  () => _handleStart('additional_$index'),
                ),
                const SizedBox(width: 12),
                Text(
                  formatDuration(taskDurations['additional_$index']),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const TextStyle _tableHeaderStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w800,
  color: Color(0xFF172554),
);