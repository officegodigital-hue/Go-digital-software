import 'package:flutter/material.dart';

class TaskManagerScreen extends StatefulWidget {
  // ✨ ADD: Accept tasks passed from HomeScreen
  final List<Task>? initialTasks;
  
  const TaskManagerScreen({
    super.key,
    this.initialTasks,
  });

  @override
  State<TaskManagerScreen> createState() => _TaskManagerScreenState();
}

class _TaskManagerScreenState extends State<TaskManagerScreen> {
  int _selectedTab = 0; // 0 = All, 1 = Assigned, 2 = Completed
  late List<Task> _tasks;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
    // ✨ Initialize with passed tasks or sample tasks
    if (widget.initialTasks != null && widget.initialTasks!.isNotEmpty) {
      _tasks = widget.initialTasks!;
      debugPrint('✅ Loaded ${_tasks.length} tasks from HomeScreen');
    } else {
      _tasks = _getSampleTasks();
      debugPrint('⚠️ Using sample tasks (no tasks passed)');
    }
  }

  /// Sample tasks for fallback
  List<Task> _getSampleTasks() {
    return [
      Task(
        id: '1',
        title: 'Design Homepage',
        description: 'Create mockup for new homepage',
        status: 'In Progress',
        priority: 'High',
        assignedTo: 'John Doe',
        dueDate: DateTime.now().add(const Duration(days: 2)),
      ),
      Task(
        id: '2',
        title: 'Update Database Schema',
        description: 'Add new tables for user preferences',
        status: 'Pending',
        priority: 'Medium',
        assignedTo: 'Sarah Smith',
        dueDate: DateTime.now().add(const Duration(days: 5)),
      ),
      Task(
        id: '3',
        title: 'Bug Fix - Login Issue',
        description: 'Fix authentication timeout bug',
        status: 'Completed',
        priority: 'High',
        assignedTo: 'Mike Johnson',
        dueDate: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Task(
        id: '4',
        title: 'Client Meeting Prep',
        description: 'Prepare presentation for Q3 review',
        status: 'In Progress',
        priority: 'High',
        assignedTo: 'Emma Davis',
        dueDate: DateTime.now().add(const Duration(days: 1)),
      ),
      Task(
        id: '5',
        title: 'Video Editing - Campaign',
        description: 'Edit promotional video for new product',
        status: 'Pending',
        priority: 'Medium',
        assignedTo: 'Alex Chen',
        dueDate: DateTime.now().add(const Duration(days: 7)),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildTabBar(),
                Expanded(
                  child: _buildTaskList(),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTaskDialog,
        backgroundColor: const Color(0xFF2A52BE),
        label: const Text('New Task'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  // ── App Bar ─────────────────────────────────────────────────────────────────

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Task Manager',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '${_tasks.length} tasks',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.black54),
          onPressed: () {
            debugPrint('Search clicked');
          },
        ),
        IconButton(
          icon: const Icon(Icons.filter_list, color: Colors.black54),
          onPressed: () {
            debugPrint('Filter clicked');
          },
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  // ── Tab Bar ─────────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: Row(
        children: [
          _buildTabOption('All Tasks', 0, _getTotalTaskCount()),
          _buildTabOption('Assigned', 1, _getAssignedTaskCount()),
          _buildTabOption('Completed', 2, _getCompletedTaskCount()),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildTabOption(String label, int index, int count) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xFF2A52BE) : Colors.transparent,
              width: isSelected ? 3 : 0,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? const Color(0xFF2A52BE) : Colors.black54,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF2A52BE).withValues(alpha: 0.1)
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? const Color(0xFF2A52BE)
                      : Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Task List ───────────────────────────────────────────────────────────────

  Widget _buildTaskList() {
    List<Task> displayedTasks = _getFilteredTasks();

    if (displayedTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No tasks found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: displayedTasks.length,
      itemBuilder: (context, index) => _buildTaskCard(displayedTasks[index]),
    );
  }

  Widget _buildTaskCard(Task task) {
    return GestureDetector(
      onTap: () => _showTaskDetail(task),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and Priority
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                _buildPriorityBadge(task.priority),
              ],
            ),
            const SizedBox(height: 8),

            // Description
            Text(
              task.description,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            // Status and Details
            Row(
              children: [
                _buildStatusBadge(task.status),
                const SizedBox(width: 12),
                Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  task.assignedTo,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  _formatDate(task.dueDate),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Status Badge ────────────────────────────────────────────────────────────

  Widget _buildStatusBadge(String status) {
    Color bgColor, textColor;
    switch (status.toLowerCase()) {
      case 'completed':
        bgColor = Colors.green.withValues(alpha: 0.1);
        textColor = Colors.green[700]!;
        break;
      case 'in progress':
        bgColor = Colors.blue.withValues(alpha: 0.1);
        textColor = Colors.blue[700]!;
        break;
      case 'pending':
        bgColor = Colors.orange.withValues(alpha: 0.1);
        textColor = Colors.orange[700]!;
        break;
      default:
        bgColor = Colors.grey.withValues(alpha: 0.1);
        textColor = Colors.grey[700]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

  // ── Priority Badge ──────────────────────────────────────────────────────────

  Widget _buildPriorityBadge(String priority) {
    Color color;
    switch (priority.toLowerCase()) {
      case 'high':
        color = Colors.red;
        break;
      case 'medium':
        color = Colors.orange;
        break;
      case 'low':
        color = Colors.green;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  List<Task> _getFilteredTasks() {
    switch (_selectedTab) {
      case 1: // Assigned
        return _tasks
            .where((task) => task.status.toLowerCase() != 'completed')
            .toList();
      case 2: // Completed
        return _tasks
            .where((task) => task.status.toLowerCase() == 'completed')
            .toList();
      default: // All
        return _tasks;
    }
  }

  int _getTotalTaskCount() => _tasks.length;

  int _getAssignedTaskCount() =>
      _tasks.where((t) => t.status.toLowerCase() != 'completed').length;

  int _getCompletedTaskCount() =>
      _tasks.where((t) => t.status.toLowerCase() == 'completed').length;

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck == today) {
      return 'Today';
    } else if (dateToCheck.isBefore(today)) {
      return 'Overdue';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  // ── Dialog: Add Task ────────────────────────────────────────────────────────

  void _showAddTaskDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Task'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'Task Title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Task created successfully!')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2A52BE),
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  // ── Dialog: Task Detail ─────────────────────────────────────────────────────

  void _showTaskDetail(Task task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(task.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Status', task.status),
              _detailRow('Priority', task.priority),
              _detailRow('Assigned To', task.assignedTo),
              _detailRow('Due Date', _formatDate(task.dueDate)),
              const SizedBox(height: 12),
              const Text(
                'Description',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(task.description),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: TextStyle(color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }
}

// ── Task Model ──────────────────────────────────────────────────────────────

class Task {
  final String id;
  final String title;
  final String description;
  final String status; // Pending, In Progress, Completed
  final String priority; // High, Medium, Low
  final String assignedTo;
  final DateTime dueDate;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.assignedTo,
    required this.dueDate,
  });

  // ✨ Convert from JSON (from API)
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Untitled',
      description: json['description'] ?? '',
      status: json['status'] ?? 'Pending',
      priority: json['priority'] ?? 'Medium',
      assignedTo: json['assignedTo'] ?? 'Unknown',
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'])
          : DateTime.now(),
    );
  }

  // ✨ Convert to JSON (for API)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status,
      'priority': priority,
      'assignedTo': assignedTo,
      'dueDate': dueDate.toIso8601String(),
    };
  }
}