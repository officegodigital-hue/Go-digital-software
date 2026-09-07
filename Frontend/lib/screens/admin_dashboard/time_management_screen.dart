import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../layouts/admin_layout.dart';
import '../../services/api_config.dart';


// ── Data model ─────────────────────────────────────────────────────────────────

class _TaskEntry {
  int id;
  String taskName;
  int? taskMasterId;
  String qty;
  String timing;

  _TaskEntry({
    required this.id,
    required this.taskName,
    this.taskMasterId,
    required this.qty,
    required this.timing,
  });
}

// ── Screen ─────────────────────────────────────────────────────────────────────

class TimeManagerScreen extends StatefulWidget {
  const TimeManagerScreen({super.key});

  @override
  State<TimeManagerScreen> createState() => _TimeManagerScreenState();
}

class _TimeManagerScreenState extends State<TimeManagerScreen> {

  // ── API base URL ──────────────────────────────────────────────────────────────
  // static const String _baseUrl = '/api';
  static String get _baseUrl => ApiConfig.baseUrl;

  bool _loading = true;
  String? _loadError;

  // Task entries (the table rows) — now loaded from backend
  List<_TaskEntry> _entries = [];


  // ✅ Task names now fetched live from task_master table
List<Map<String, dynamic>> _taskMasterList = [];
bool _loadingTaskMaster = true;

  // Segmented duration types options array mapping
  final List<String> _unitOptions = ['mins', 'hrs', 'days'];

  // Form state fields tracking variables
  int? _selectedTaskMasterId;
  String? _selectedTaskName;
  final TextEditingController _otherTaskCtrl = TextEditingController();
  final TextEditingController _qtyCtrl     = TextEditingController();
  final TextEditingController _timingValCtrl = TextEditingController();
  final TextEditingController _timingMinCtrl = TextEditingController(); 
  String _selectedTimingUnit = 'mins';
  int? _editingId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fetchTaskMaster();
    _fetchEntries();
  } 

  Future<void> _fetchTaskMaster() async {
    setState(() => _loadingTaskMaster = true);
    try {
      final response = await http.get(Uri.parse('$_baseUrl/task-master'));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        setState(() {
          _taskMasterList = List<Map<String, dynamic>>.from(body['data']);
          _loadingTaskMaster = false;
        });
      } else {
        setState(() => _loadingTaskMaster = false);
      }
    } catch (e) {
      setState(() => _loadingTaskMaster = false);
    }
  }

  @override
void dispose() {
  _otherTaskCtrl.dispose();
  _qtyCtrl.dispose();
  _timingValCtrl.dispose();
  _timingMinCtrl.dispose(); // ✅ NEW
  super.dispose();
}

  // ── API: FETCH all entries ───────────────────────────────────────────────────
  Future<void> _fetchEntries() async {
    setState(() { _loading = true; _loadError = null; });
    try {
      final response = await http.get(Uri.parse('$_baseUrl/timings'));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List data = body['data'];
        setState(() {
          _entries = data.map((e) => _TaskEntry(
            id:           e['id'],
            taskName:     e['task_name'],
            taskMasterId: e['task_master_id'],
            qty:          e['qty'].toString(),
            timing:       e['timing'],
          )).toList();
          _loading = false;
        });
      } else {
        setState(() { _loadError = 'Server returned ${response.statusCode}'; _loading = false; });
      }
    } catch (e) {
      setState(() { _loadError = 'Cannot connect to server'; _loading = false; });
    }
  }

  // ── API: CREATE entry ─────────────────────────────────────────────────────────
  Future<void> _createEntry(String taskName, int? taskMasterId, String qty, String timing) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/timings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'taskName': taskName,
          'taskMasterId': taskMasterId,
          'qty': qty,
          'timing': timing,
        }),
      );
      if (response.statusCode == 201) {
        await _fetchEntries();
        
      _showSnack(
        'Task timing created successfully.',
        success: true,
      );
      } else {
        final body = jsonDecode(response.body);
        _showSnack(body['message'] ?? 'Failed to create entry');
      }
    } catch (e) {
      _showSnack('Cannot connect to server');
    }
  }

  // ── API: UPDATE entry ─────────────────────────────────────────────────────────
  Future<void> _updateEntry(int id, String taskName, int? taskMasterId, String qty, String timing) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/timings/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'taskName': taskName,
          'taskMasterId': taskMasterId,
          'qty': qty,
          'timing': timing,
        }),
      ); 
      if (response.statusCode == 200) {
        await _fetchEntries();

        _showSnack(
      'Task timing updated successfully.',
      success: true,
    );
      } else {
        final body = jsonDecode(response.body);
        _showSnack(body['message'] ?? 'Failed to update entry');
      }
    } catch (e) {
      _showSnack('Cannot connect to server');
    }
  }

  // ── API: DELETE entry ─────────────────────────────────────────────────────────
  Future<void> _deleteEntryApi(int id) async {
    try {
      final response = await http.delete(Uri.parse('$_baseUrl/timings/$id'));
      if (response.statusCode == 200) {
        await _fetchEntries();
        _showSnack('Entry deleted', success: true);
      } else {
        _showSnack('Failed to delete entry');
      }
    } catch (e) {
      _showSnack('Cannot connect to server');
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? const Color(0xFF16A34A) : Colors.redAccent,
    ));
  }

  // ── Form helpers ──────────────────────────────────────────────────────────────

  void _clearForm() {
    setState(() {
      _selectedTaskMasterId = null;
      _selectedTaskName = null;
      _otherTaskCtrl.clear();
      _qtyCtrl.clear();
      _timingValCtrl.clear();
      _timingMinCtrl.clear(); 
      _selectedTimingUnit = 'mins';
      _editingId = null;
    });
  }

  void _populateForm(_TaskEntry entry) {
  setState(() {
    _editingId = entry.id;
    _qtyCtrl.text = entry.qty;

    final match = _taskMasterList.firstWhere(
      (t) => t['task_name'] == entry.taskName,
      orElse: () => {},
    );

    if (entry.taskMasterId != null && match.isNotEmpty) {
      _selectedTaskMasterId = entry.taskMasterId;
      _selectedTaskName = entry.taskName;
      _otherTaskCtrl.clear();
    } else {
      _selectedTaskMasterId = -1; // "Other"
      _selectedTaskName = null;
      _otherTaskCtrl.text = entry.taskName;
    }

    // ✅ Parse compound timing strings like "2 hrs 30 mins", "45 mins", "5 days"
    _timingMinCtrl.clear();
    final matches = RegExp(r'(\d+)\s*(hrs|hr|mins|min|days|day)').allMatches(entry.timing);
    final Map<String, String> parsed = {};
    for (final m in matches) {
      final num = m.group(1)!;
      final rawUnit = m.group(2)!;
      final unit = rawUnit.startsWith('hr') ? 'hrs' : rawUnit.startsWith('min') ? 'mins' : 'days';
      parsed[unit] = num;
    }

    if (parsed.containsKey('hrs')) {
      _selectedTimingUnit = 'hrs';
      _timingValCtrl.text = parsed['hrs']!;
      if (parsed.containsKey('mins')) _timingMinCtrl.text = parsed['mins']!;
    } else if (parsed.containsKey('mins')) {
      _selectedTimingUnit = 'mins';
      _timingValCtrl.text = parsed['mins']!;
    } else if (parsed.containsKey('days')) {
      _selectedTimingUnit = 'days';
      _timingValCtrl.text = parsed['days']!;
    } else {
      // fallback for malformed/legacy data
      _timingValCtrl.text = entry.timing.replaceAll(RegExp(r'[^0-9]'), '');
      _selectedTimingUnit = 'mins';
    }
  });
}

  Future<void> _saveForm() async {
  String task = '';
  int? taskMasterId;

  if (_selectedTaskMasterId == -1) {
    task = _otherTaskCtrl.text.trim();
    taskMasterId = null;
  } else if (_selectedTaskMasterId != null) {
    final match = _taskMasterList.firstWhere(
      (t) => t['id'] == _selectedTaskMasterId,
      orElse: () => {},
    );
    task = match['task_name'] ?? '';
    taskMasterId = _selectedTaskMasterId;
  }

  final qtyInput = _qtyCtrl.text.trim();
  final qty = qtyInput.isEmpty ? '1' : qtyInput;

  final timingVal = _timingValCtrl.text.trim();
  final timingMin  = _timingMinCtrl.text.trim();

  if (task.isEmpty || timingVal.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please fill all fields.'), backgroundColor: Colors.redAccent),
    );
    return;
  }

  // ✅ Build compound timing string, e.g. "2 hrs 30 mins", "2 hrs", "30 mins", "5 days"
  String timingMerged;
  if (_selectedTimingUnit == 'hrs' && timingMin.isNotEmpty && timingMin != '0') {
    timingMerged = "$timingVal hrs $timingMin mins";
  } else {
    timingMerged = "$timingVal $_selectedTimingUnit";
  }

  setState(() => _saving = true);

  if (_editingId != null) {
    await _updateEntry(_editingId!, task, taskMasterId, qty, timingMerged);
  } else {
    await _createEntry(task, taskMasterId, qty, timingMerged);
  }

  setState(() => _saving = false);
  _clearForm();
}

  void _deleteEntry(int id) {
    if (_editingId == id) _clearForm();
    _deleteEntryApi(id); // ← API DELETE call
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      pageTitle: 'Time Manager',
      currentRoute: '/time-manager',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 750;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTimeManagerHero(isMobile),
              const SizedBox(height: 18),
              if (isMobile)
                _buildMobileWorkspace()
              else
                _buildDesktopWorkspace(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimeManagerHero(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 18 : 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF003B95),
            Color(0xFF0052CC),
            Color(0xFF1267E8),
          ],
        ),
        borderRadius: BorderRadius.circular(isMobile ? 20 : 26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0052CC).withValues(alpha: 0.20),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: isMobile ? 50 : 60,
                height: isMobile ? 50 : 60,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.20),
                  ),
                ),
                child: Icon(
                  Icons.schedule_rounded,
                  size: isMobile ? 26 : 31,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Time Management',
                      style: TextStyle(
                        fontSize: isMobile ? 20 : 34,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage task timings, quantities, and productivity schedules.',
                      style: TextStyle(
                        fontSize: isMobile ? 11.5 : 13,
                        height: 1.45,
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.20),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.timer_outlined,
                  size: 17,
                  color: Colors.white,
                ),
                const SizedBox(width: 7),
                Text(
                  '${_entries.length} ${_entries.length == 1 ? 'Task' : 'Tasks'} Configured',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopWorkspace() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: _buildTable()),
        const SizedBox(width: 22),
        Expanded(flex: 2, child: _buildFormPanel()),
      ],
    );
  }

  Widget _buildMobileWorkspace() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMobileFormCard(),
        const SizedBox(height: 14),
        _buildMobileTaskLog(),
      ],
    );
  }

  Widget _buildMobileFormCard() {
    final isEditing = _editingId != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF003B95), Color(0xFF0052CC)],
              ),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    isEditing
                        ? Icons.edit_note_rounded
                        : Icons.add_alarm_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditing ? 'Edit Task Timing' : 'Set Task Timing',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isEditing
                            ? 'Update the selected timing configuration'
                            : 'Create a timing rule for a task',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMobileTaskSelector(),
                if (_selectedTaskMasterId == -1) ...[
                  const SizedBox(height: 12),
                  _buildInlineFormInputField(
                    label: 'Custom Task Name *',
                    controller: _otherTaskCtrl,
                    hint: 'Enter custom task name',
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInlineFormInputField(
                        label: 'Qty',
                        controller: _qtyCtrl,
                        hint: '1',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: _buildMobileTimingEditor(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : _clearForm,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF374151),
                          side: const BorderSide(
                            color: Color(0xFFD1D5DB),
                          ),
                          minimumSize: const Size.fromHeight(43),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saving ? null : _saveForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0052CC),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size.fromHeight(43),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 17,
                                height: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                isEditing ? 'Update Timing' : 'Create Timing',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileTaskSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Task Name *',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 45,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9FC),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedTaskMasterId,
              isExpanded: true,
              hint: Text(
                _loadingTaskMaster ? 'Loading tasks...' : 'Select task',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                ),
              ),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF0052CC),
              ),
              items: [
                ..._taskMasterList.map((t) {
                  final int tId = t['id'];
                  final String tName = t['task_name'];
                  final isUsed = _entries.any(
                    (e) =>
                        e.taskName == tName &&
                        e.id != _editingId,
                  );

                  return DropdownMenuItem<int>(
                    value: tId,
                    enabled: !isUsed,
                    child: Text(
                      isUsed ? '$tName (already added)' : tName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isUsed
                            ? const Color(0xFFB0B7C3)
                            : const Color(0xFF1A1A2E),
                      ),
                    ),
                  );
                }),
                const DropdownMenuItem<int>(
                  value: -1,
                  child: Text(
                    'Other',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
              onChanged: (val) {
                setState(() {
                  _selectedTaskMasterId = val;
                  if (val != null && val != -1) {
                    final match = _taskMasterList.firstWhere(
                      (t) => t['id'] == val,
                      orElse: () => {},
                    );
                    _selectedTaskName = match['task_name'];
                  } else {
                    _selectedTaskName = null;
                  }
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileTimingEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Timing *',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 45,
                child: TextField(
                  controller: _timingValCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF1A1A2E),
                  ),
                  decoration: InputDecoration(
                    hintText:
                        _selectedTimingUnit == 'hrs' ? 'hrs' : '30',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF7F9FC),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(11),
                      borderSide: const BorderSide(
                        color: Color(0xFFE2E8F0),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(11),
                      borderSide: const BorderSide(
                        color: Color(0xFF0052CC),
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _buildUnitSegment(),
            ),
          ],
        ),
        if (_selectedTimingUnit == 'hrs') ...[
          const SizedBox(height: 6),
          SizedBox(
            height: 42,
            child: TextField(
              controller: _timingMinCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF1A1A2E),
              ),
              decoration: InputDecoration(
                prefixIcon: const Icon(
                  Icons.more_time_rounded,
                  size: 17,
                  color: Color(0xFF0052CC),
                ),
                hintText: 'Additional minutes',
                hintStyle: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF94A3B8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                filled: true,
                fillColor: const Color(0xFFF7F9FC),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(
                    color: Color(0xFFE2E8F0),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(
                    color: Color(0xFF0052CC),
                    width: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMobileTaskLog() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 13,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.list_alt_rounded,
                    size: 18,
                    color: Color(0xFF0052CC),
                  ),
                ),
                const SizedBox(width: 9),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Task Timing Log',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Configured task duration rules',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _fetchEntries,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    size: 19,
                    color: Color(0xFF0052CC),
                  ),
                ),
              ],
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF0052CC),
                ),
              ),
            )
          else if (_loadError != null)
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 38,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _loadError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _fetchEntries,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0052CC),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (_entries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Column(
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: 42,
                    color: Color(0xFFCBD5E1),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No task timings yet',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Create a timing rule using the form above.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: _entries.asMap().entries.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildMobileTaskCard(
                      item.value,
                      item.key,
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileTaskCard(_TaskEntry entry, int index) {
    final isEditing = _editingId == entry.id;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isEditing
            ? const Color(0xFFF0F5FF)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isEditing
              ? const Color(0xFF9DBCF5)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0052CC),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry.taskName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              if (isEditing)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'EDITING',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMobileInfoTile(
                  Icons.production_quantity_limits_rounded,
                  'Quantity',
                  entry.qty.trim().isEmpty ? '1' : entry.qty,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _buildMobileInfoTile(
                  Icons.timer_outlined,
                  'Duration',
                  entry.timing,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _populateForm(entry),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0052CC),
                    side: const BorderSide(
                      color: Color(0xFFBBD1F7),
                    ),
                    minimumSize: const Size.fromHeight(38),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _deleteEntry(entry.id),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                  ),
                  label: const Text(
                    'Delete',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(
                      color: Color(0xFFFECACA),
                    ),
                    minimumSize: const Size.fromHeight(38),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
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

  Widget _buildMobileInfoTile(
    IconData icon,
    String label,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: const Color(0xFF0052CC),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── LEFT: Data log table ──
  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              color: const Color(0xFFF1F5F9),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Task Log',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                  ),
                  // Refresh button
                  GestureDetector(
                    onTap: _fetchEntries,
                    child: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF1A3A8F)),
                  ),
                ],
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB)))),
            child: Row(
              children: const [
                _TH('NO.',     flex: 1),
                _TH('TASK',    flex: 3),
                _TH('QTY',     flex: 2),
                _TH('TIMING',  flex: 2),
                _TH('ACTIONS', flex: 2),
              ],
            ),
          ),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(color: Color(0xFF1A3A8F))),
            )
          else if (_loadError != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(children: [
                  Text(_loadError!, style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _fetchEntries,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A3A8F)),
                    child: const Text('Retry', style: TextStyle(color: Colors.white)),
                  ),
                ]),
              ),
            )
          else if (_entries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('No tasks yet. Use the form to add one.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
              ),
            )
          else
            Column(
              children: _entries.asMap().entries.map((e) {
                final idx   = e.key;
                final entry = e.value;
                final isEditing = _editingId == entry.id;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isEditing ? const Color(0xFFF0F4FF) : Colors.white,
                    border: const Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Text('${idx + 1}', style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          entry.taskName,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1A1A2E)),
                        ),
                      ),
                      Expanded(
  flex: 2,
  child: Text(
    entry.qty.trim().isEmpty ? '1' : entry.qty,
    style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
  ),
),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              entry.timing,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            _ActionBtn(
                              icon: Icons.edit_outlined,
                              color: const Color(0xFF2A52BE),
                              bg: const Color(0xFFEFF6FF),
                              onTap: () => _populateForm(entry),
                            ),
                            const SizedBox(width: 8),
                            _ActionBtn(
                              icon: Icons.delete_outline,
                              color: const Color(0xFFDC2626),
                              bg: const Color(0xFFFEE2E2),
                              onTap: () => _deleteEntry(entry.id),
                            ),
                          ],
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
  }

  

  // ── RIGHT: Form editor panel ──
  Widget _buildFormPanel() {
    final isEditing = _editingId != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              color: const Color(0xFF1A3A8F),
              child: Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit_note_rounded : Icons.add_circle_outline_rounded,
                    color: Colors.white, size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isEditing ? 'Edit Task Timing' : 'Set Timing',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Task Name *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
                const SizedBox(height: 6),
                Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFD1D5DB)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedTaskMasterId,
                      isExpanded: true,
                      hint: Text(
                        _loadingTaskMaster ? 'Loading tasks...' : 'Select task',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                      ),
                      items: [
                        ..._taskMasterList.map((t) {
                          final int tId = t['id'];
                          final String tName = t['task_name'];
                          final isUsed = _entries.any((e) => e.taskName == tName && e.id != _editingId);

                          return DropdownMenuItem(
                            value: tId,
                            enabled: !isUsed,
                            child: Text(
                              isUsed ? '$tName (already added)' : tName,
                              style: TextStyle(
                                fontSize: 13,
                                color: isUsed ? const Color(0xFFB0B7C3) : const Color(0xFF1A1A2E),
                              ),
                            ),
                          );
                        }),
                        const DropdownMenuItem(
                          value: -1,
                          child: Text('Other', style: TextStyle(fontSize: 13, color: Color(0xFF1A1A2E))),
                        ),
                      ],
                      onChanged: (val) => setState(() {
                        _selectedTaskMasterId = val;
                        if (val != null && val != -1) {
                          final match = _taskMasterList.firstWhere(
                            (t) => t['id'] == val,
                            orElse: () => {},
                          );
                          _selectedTaskName = match['task_name'];
                        } else {
                          _selectedTaskName = null;
                        }
                      }),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6B7280)),
                    ),
                  ),
                  ),

                // ── DYNAMIC RENDERING BLOCK FOR CUSTOM "OTHER" TASK ENTRY INPUT ──
                if (_selectedTaskMasterId == -1) ...[
                  const SizedBox(height: 14),
                  _buildInlineFormInputField(
                    label: 'Specify Custom Task Name *',
                    controller: _otherTaskCtrl,
                    hint: 'Enter your custom task name...',
                  ),
                ],

                const SizedBox(height: 16),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildInlineFormInputField(
                        label: 'Qty',
                        controller: _qtyCtrl,
                        hint: '1',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 14),

                    // ── TWO-SEGMENT TIMING FIELD MATRIX ──
                    Expanded(
                      flex: 3, 
                      child: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    const Text('Timing *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
    const SizedBox(height: 6),
    Row(
      children: [
        Expanded(
          flex: 3,
          child: SizedBox(
            height: 38,
            child: TextField(
              controller: _timingValCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
              decoration: InputDecoration(
                hintText: _selectedTimingUnit == 'hrs' ? 'hrs' : '30',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF1A3A8F), width: 1.5),
                ),
              ),
            ),
          ),
        ),

        // ✅ Extra "mins" field appears only when "hrs" is the active unit
        if (_selectedTimingUnit == 'hrs') ...[
          const SizedBox(width: 6),
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: _timingMinCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
                decoration: InputDecoration(
                  hintText: 'min',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xFF1A3A8F), width: 1.5),
                  ),
                ),
              ),
            ),
          ),
        ],

        const SizedBox(width: 6),
        Expanded(
          flex: 5,
          child: _buildUnitSegment(),
        ),
      ],
    ),
  ],
),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : _clearForm,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF374151),
                          side: const BorderSide(color: Color(0xFFD1D5DB)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saving ? null : _saveForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A3A8F),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                isEditing ? 'Update' : 'Create',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitSegment() {
  return Container(
    height: 38,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0xFFF9FAFB),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: const Color(0xFFD1D5DB)),
    ),
    child: Row(
      children: _unitOptions.map((unit) {
        final isSelected = _selectedTimingUnit == unit;
        return Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _selectedTimingUnit = unit),
            child: Container(
              alignment: Alignment.center,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF1A3A8F) : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                unit,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF6B7280),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );
}

  Widget _buildInlineFormInputField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
        const SizedBox(height: 6),
        SizedBox(
          height: 38,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w400),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFF1A3A8F), width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────────

class _TH extends StatelessWidget {
  final String text;
  final int flex;
  const _TH(this.text, {required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(text,
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280), letterSpacing: 0.6)),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.color, required this.bg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
