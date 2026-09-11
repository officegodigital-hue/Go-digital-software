import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/attendance_api.dart';

class EmployeeAttendance extends StatefulWidget {
  const EmployeeAttendance({super.key});

  @override
  State<EmployeeAttendance> createState() => _EmployeeAttendanceState();
}

class _EmployeeAttendanceState extends State<EmployeeAttendance> {
  DateTime selectedDate = DateTime.now();
  bool loading = true;
  String? error;
  Map<String, dynamic> data = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await AttendanceApi.myHistory(selectedDate);
      if (!mounted) return;
      setState(() {
        data = result;
        loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        error = err.toString().replaceFirst('Exception: ', '');
        loading = false;
      });
    }
  }

  Map<String, dynamic> get _summary =>
      Map<String, dynamic>.from(data['summary'] as Map? ?? {});

  List<Map<String, dynamic>> _maps(String key) {
    final raw = data[key];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Attendance',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.blue),
            onPressed: () async {
              try {
                await AttendanceApi.downloadMyExport(selectedDate);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Attendance report downloaded')),
                );
              } catch (err) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(err.toString())),
                );
              }
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Attendance Summary',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Your attendance records and details',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2024),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                selectedDate =
                                    DateTime(picked.year, picked.month);
                                await _load();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today,
                                      size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat('MMM yyyy').format(selectedDate),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          _buildSummaryCard(
                            icon: Icons.check_circle,
                            label: 'PRESENT',
                            value: '${_summary['present'] ?? 0}',
                            color: Colors.green,
                          ),
                          const SizedBox(width: 16),
                          _buildSummaryCard(
                            icon: Icons.remove_circle,
                            label: 'ABSENT',
                            value: '${_summary['absent'] ?? 0}',
                            color: Colors.red,
                          ),
                          const SizedBox(width: 16),
                          _buildSummaryCard(
                            icon: Icons.schedule,
                            label: 'LATE',
                            value: '${_summary['late'] ?? 0}',
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 16),
                          _buildSummaryCard(
                            icon: Icons.logout,
                            label: 'EARLY EXIT',
                            value: '${_summary['earlyExit'] ?? 0}',
                            color: Colors.blue,
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Recent Attendance',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 20),
                            ..._maps('records').map((row) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text('${row['date'] ?? ''}'),
                                    ),
                                    Expanded(
                                      child: Text('${row['checkIn'] ?? ''}'),
                                    ),
                                    Expanded(
                                      child: Text('${row['checkOut'] ?? ''}'),
                                    ),
                                    Expanded(
                                      child: Text('${row['status'] ?? ''}'),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Pending Requests',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    final type = await showDialog<String>(
                                      context: context,
                                      builder: (context) {
                                        final reason = TextEditingController();
                                        String selected = 'late_entry';
                                        return AlertDialog(
                                          title: const Text('New request'),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              DropdownButtonFormField<String>(
                                                value: selected,
                                                items: const [
                                                  DropdownMenuItem(
                                                    value: 'late_entry',
                                                    child: Text('Late Entry'),
                                                  ),
                                                  DropdownMenuItem(
                                                    value: 'early_exit',
                                                    child: Text('Early Exit'),
                                                  ),
                                                  DropdownMenuItem(
                                                    value: 'leave',
                                                    child: Text('Leave'),
                                                  ),
                                                ],
                                                onChanged: (value) {
                                                  selected = value ?? selected;
                                                },
                                              ),
                                              TextField(
                                                controller: reason,
                                                decoration:
                                                    const InputDecoration(
                                                  labelText: 'Reason',
                                                ),
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () => Navigator.pop(
                                                context,
                                                '$selected|${reason.text}',
                                              ),
                                              child: const Text('Submit'),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                    if (type == null || !context.mounted) {
                                      return;
                                    }
                                    final parts = type.split('|');
                                    try {
                                      await AttendanceApi.createRequest(
                                        type: parts.first,
                                        date: DateTime.now(),
                                        reason: parts.length > 1
                                            ? parts.last
                                            : '',
                                      );
                                      await _load();
                                    } catch (err) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(content: Text('$err')),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('New Request'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ..._maps('requests').map((req) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  '${req['type']}  ${req['date']}  ${req['reason']}  ${req['status']}',
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}