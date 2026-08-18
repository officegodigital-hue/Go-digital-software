import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models/admin_attendance_models.dart';
import '../../data/services/attendance_export_service.dart';
import '../controllers/admin_attendance_controller.dart';

class AdminDailyAttendanceScreen extends StatefulWidget {
  const AdminDailyAttendanceScreen({
    super.key,
    this.controller,
    this.onExportExcel,
    this.onExportPdf,
  });

  final AdminAttendanceController? controller;

  final Future<void> Function(List<AdminAttendanceRecord> records)?
  onExportExcel;

  final Future<void> Function(List<AdminAttendanceRecord> records)? onExportPdf;

  @override
  State<AdminDailyAttendanceScreen> createState() {
    return _AdminDailyAttendanceScreenState();
  }
}

class _AdminDailyAttendanceScreenState
    extends State<AdminDailyAttendanceScreen> {
        Timer? _refreshTimer;
  late final AdminAttendanceController _controller;
  late final bool _ownsController;

@override
void initState() {
  super.initState();

  _ownsController = widget.controller == null;
  _controller = widget.controller ?? AdminAttendanceController();

  _controller.addListener(_handleControllerChanged);

  WidgetsBinding.instance.addPostFrameCallback((_) {

    if (mounted) {

      _controller.initialize();

      _startAutoRefresh();

    }

  });
}
void _startAutoRefresh() {

  _refreshTimer = Timer.periodic(
    const Duration(seconds: 10),
    (Timer timer) {

      if (!mounted) {
        timer.cancel();
        return;
      }


      if (!_controller.isLoading) {

        _controller.loadFirstPage();

      }

    },
  );

}

@override
void dispose() {

  _refreshTimer?.cancel();

  _controller.removeListener(
    _handleControllerChanged,
  );


  if (_ownsController) {
    _controller.dispose();
  }


  super.dispose();

}

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pickDateRange() async {
    final DateTime today = DateTime.now();

    final DateTimeRange? result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year - 5),
      lastDate: DateTime(today.year + 2, 12, 31),
      initialDateRange: DateTimeRange(
        start: _controller.fromDate ?? DateTime(today.year, today.month, 1),
        end: _controller.toDate ?? today,
      ),
      helpText: 'Select attendance date range',
      saveText: 'Apply',
    );

    if (result == null || !mounted) {
      return;
    }

    await _controller.setDateRange(fromDate: result.start, toDate: result.end);
  }

  Future<void> _showFiltersDialog() async {
    final TextEditingController searchController = TextEditingController(
      text: _controller.searchQuery,
    );

    String attendanceStatus = _controller.attendanceStatus;

    String sessionStatus = _controller.sessionStatus;

    final bool? shouldApply = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Filters'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        labelText: 'Search employee',
                        hintText: 'Name, code, role or email',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: attendanceStatus,
                      decoration: const InputDecoration(
                        labelText: 'Attendance status',
                      ),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(
                          value: 'all',
                          child: Text('All Statuses'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'present',
                          child: Text('Present'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'late',
                          child: Text('Late'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'absent',
                          child: Text('Absent'),
                        ),
                      ],
                      onChanged: (String? value) {
                        if (value != null) {
                          setDialogState(() {
                            attendanceStatus = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: sessionStatus,
                      decoration: const InputDecoration(
                        labelText: 'Session status',
                      ),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(
                          value: 'all',
                          child: Text('All Sessions'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'active',
                          child: Text('Active'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'completed',
                          child: Text('Completed'),
                        ),
                      ],
                      onChanged: (String? value) {
                        if (value != null) {
                          setDialogState(() {
                            sessionStatus = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    searchController.clear();

                    setDialogState(() {
                      attendanceStatus = 'all';
                      sessionStatus = 'all';
                    });
                  },
                  child: const Text('Clear'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(false);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldApply != true || !mounted) {
      searchController.dispose();
      return;
    }

    await _controller.submitSearch(searchController.text);

    await _controller.setAttendanceStatus(attendanceStatus);

    await _controller.setSessionStatus(sessionStatus);

    searchController.dispose();
  }

  Future<void> _exportExcel() async {
    try {
      final List<AdminAttendanceRecord> records = await _controller
          .loadExportRecords();

      if (!mounted) {
        return;
      }

      if (records.isEmpty) {
        _showMessage(
          _controller.errorMessage ??
              'No attendance records are available to export.',
        );
        return;
      }

      if (widget.onExportExcel != null) {
        await widget.onExportExcel!(records);
      } else {
        await AttendanceExportService.exportExcel(
          records: records,
          fromDate: _controller.fromDate,
          toDate: _controller.toDate,
        );
      }

      if (mounted) {
        _showMessage('Attendance Excel file downloaded successfully.');
      }
    } catch (error) {
      if (mounted) {
        _showMessage('Excel export failed: $error');
      }
    }
  }

  Future<void> _exportPdf() async {
    try {
      final List<AdminAttendanceRecord> records = await _controller
          .loadExportRecords();

      if (!mounted) {
        return;
      }

      if (records.isEmpty) {
        _showMessage(
          _controller.errorMessage ??
              'No attendance records are available to export.',
        );
        return;
      }

      if (widget.onExportPdf != null) {
        await widget.onExportPdf!(records);
      } else {
        await AttendanceExportService.exportPdf(
          records: records,
          fromDate: _controller.fromDate,
          toDate: _controller.toDate,
        );
      }

      if (mounted) {
        _showMessage('Attendance PDF file downloaded successfully.');
      }
    } catch (error) {
      if (mounted) {
        _showMessage('PDF export failed: $error');
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
      );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildTopSection(constraints.maxWidth),
              const SizedBox(height: 14),
              _buildAttendanceTable(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopSection(double width) {
    final Widget heading = const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Daily Attendance Log',
          style: TextStyle(
            color: Color(0xFF222222),
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Monitor real-time employee presence and work hours.',
          style: TextStyle(
            color: Color(0xFF667085),
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );

    final Widget actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: <Widget>[
        FilledButton.icon(
          onPressed: _controller.isExporting ? null : _exportExcel,
          icon: const Icon(Icons.download_rounded, size: 16),
          label: const Text('Export Excel'),
        ),
        FilledButton.icon(
          onPressed: _controller.isExporting ? null : _exportPdf,
          icon: const Icon(Icons.download_rounded, size: 16),
          label: const Text('Export PDF'),
        ),
        OutlinedButton.icon(
          onPressed: _controller.isLoading ? null : _pickDateRange,
          icon: const Icon(Icons.calendar_month_outlined, size: 16),
          label: Text(_dateRangeLabel()),
        ),
        OutlinedButton.icon(
          onPressed: _controller.isLoading ? null : _showFiltersDialog,
          icon: const Icon(Icons.filter_alt_outlined, size: 16),
          label: const Text('Filters'),
        ),
      ],
    );

    if (width < 900) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[heading, const SizedBox(height: 12), actions],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: heading),
        const SizedBox(width: 16),
        actions,
      ],
    );
  }

  Widget _buildAttendanceTable() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD7DBE4)),
      ),
      child: Column(
        children: <Widget>[
          if (_controller.isLoading)
            const LinearProgressIndicator(minHeight: 2),
          if (_controller.hasError)
            _buildErrorState()
          else if (_controller.records.isEmpty)
            _buildEmptyState()
          else
            _buildTableContent(),
          if (!_controller.hasError && _controller.records.isNotEmpty)
            _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildTableContent() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 1100),
        child: DataTable(
          columnSpacing: 26,
          horizontalMargin: 14,
          headingRowHeight: 46,
          dataRowMinHeight: 58,
          dataRowMaxHeight: 68,
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF2F4FF)),
          headingTextStyle: const TextStyle(
            color: Color(0xFF2C3443),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
          dataTextStyle: const TextStyle(
            color: Color(0xFF2C3443),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
columns: const <DataColumn>[
DataColumn(label: Text('EMPLOYEE')),
DataColumn(label: Text('EMPLOYEE ID')),
DataColumn(label: Text('DATE')),
DataColumn(label: Text('LOGIN TIME')),
DataColumn(label: Text('BREAK TIME')),
DataColumn(label: Text('LOGOUT TIME')),
DataColumn(label: Text('WORK HOURS')),
DataColumn(label: Text('EXTRA HOURS')),
DataColumn(label: Text('OVERTIME')),
DataColumn(label: Text('STATUS')),
],
          rows: _controller.records.map((AdminAttendanceRecord record) {
            return DataRow(
              cells: <DataCell>[
  DataCell(_EmployeeCell(record: record)),

  DataCell(
    Text(record.employeeCode),
  ),

  DataCell(
    Text(
      _formatDate(record.attendanceDate),
    ),
  ),

  DataCell(
    Text(
      _formatTime(record.localCheckInAt),
    ),
  ),

  // ✅ ADD BREAK TIME HERE
  DataCell(
    Text(
      record.breakTimeLabel,
    ),
  ),

  DataCell(
    Text(
      _formatTime(record.localCheckOutAt),
    ),
  ),

  DataCell(
    Text(
      record.workingTimeLabel,
    ),
  ),

  DataCell(
    Text(
      record.extraHoursLabel,
    ),
  ),

  DataCell(
    Text(
      record.overtimeLabel,
    ),
  ),

 DataCell(
  _StatusChip(
    status: record.attendanceStatus,
  ),
),
],
              
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPagination() {
    final AdminAttendancePagination pagination = _controller.pagination;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFD7DBE4))),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'Showing page ${pagination.currentPage} of '
              '${pagination.totalPages} • '
              '${pagination.totalItems} entries',
              style: const TextStyle(color: Color(0xFF667085), fontSize: 11),
            ),
          ),
          IconButton(
            tooltip: 'Previous page',
            onPressed: pagination.hasPreviousPage && !_controller.isLoading
                ? _controller.goToPreviousPage
                : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            color: const Color(0xFF1233A6),
            child: Text(
              '${pagination.currentPage}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next page',
            onPressed: pagination.hasNextPage && !_controller.isLoading
                ? _controller.goToNextPage
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return SizedBox(
      height: 280,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.error_outline_rounded,
              size: 38,
              color: Color(0xFFB42318),
            ),
            const SizedBox(height: 10),
            Text(
              _controller.errorMessage ?? 'Unable to load attendance records.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _controller.loadFirstPage,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const SizedBox(
      height: 280,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.event_busy_outlined, size: 40, color: Color(0xFF667085)),
            SizedBox(height: 10),
            Text(
              'No attendance records found',
              style: TextStyle(
                color: Color(0xFF222222),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Try changing the date range or filters.',
              style: TextStyle(color: Color(0xFF667085), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  String _dateRangeLabel() {
    final DateTime? from = _controller.fromDate;
    final DateTime? to = _controller.toDate;

    if (from == null && to == null) {
      return 'All Dates';
    }

    if (from != null && to != null) {
      return '${_formatDate(from)} - ${_formatDate(to)}';
    }

    if (from != null) {
      return 'From ${_formatDate(from)}';
    }

    return 'Until ${_formatDate(to)}';
  }

  static String _formatDate(DateTime? value) {
    if (value == null) {
      return '-';
    }

    final String day = value.day.toString().padLeft(2, '0');

    final String month = value.month.toString().padLeft(2, '0');

    return '$day-$month-${value.year}';
  }

  static String _formatTime(DateTime? value) {
    if (value == null) {
      return '-';
    }

    final int hour = value.hour == 0
        ? 12
        : value.hour > 12
        ? value.hour - 12
        : value.hour;

    final String minute = value.minute.toString().padLeft(2, '0');

    final String period = value.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }
}

class _EmployeeCell extends StatelessWidget {
  const _EmployeeCell({required this.record});

  final AdminAttendanceRecord record;

  @override
  Widget build(BuildContext context) {

    final List<String> words = record.employeeName
        .trim()
        .split(RegExp(r'\s+'))
        .where((String value) => value.isNotEmpty)
        .toList();


    final String initials = words
        .take(2)
        .map((String value) => value.substring(0, 1).toUpperCase())
        .join();


    final Widget fallback = Container(
      color: const Color(0xFFE6E9F5),
      alignment: Alignment.center,
      child: Text(
        initials.isEmpty ? 'E' : initials,
        style: const TextStyle(
          color: Color(0xFF1233A6),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );


    final bool hasImage =
        record.profileImageUrl != null &&
        record.profileImageUrl!.trim().isNotEmpty;


    return SizedBox(
      width: 180,

      child: Row(
        children: <Widget>[


          ClipOval(
            child: SizedBox(

              width: 34,
              height: 34,


              child: hasImage

                  ? Image.network(

                      record.profileImageUrl!,

                      fit: BoxFit.cover,


                      errorBuilder:
                          (
                            BuildContext context,
                            Object error,
                            StackTrace? stackTrace,
                          ) {

                            return fallback;

                          },

                    )


                  : fallback,

            ),
          ),


          const SizedBox(width: 9),


          Expanded(

            child: Column(

              mainAxisAlignment:
                  MainAxisAlignment.center,


              crossAxisAlignment:
                  CrossAxisAlignment.start,


              children: <Widget>[


                Text(

                  record.employeeName,

                  maxLines: 1,

                  overflow:
                      TextOverflow.ellipsis,


                  style: const TextStyle(

                    color: Color(0xFF222222),

                    fontSize: 11,

                    fontWeight:
                        FontWeight.w700,

                  ),

                ),


                const SizedBox(height: 2),


                Text(

                  record.roleName,

                  maxLines: 1,

                  overflow:
                      TextOverflow.ellipsis,


                  style: const TextStyle(

                    color: Color(0xFF667085),

                    fontSize: 9,

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

class _StatusChip extends StatelessWidget {

  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final String normalized = status.trim().toLowerCase();

    Color textColor;
    Color backgroundColor;
    String label;

    switch (normalized) {
      case 'present':
        textColor = const Color(0xFF187A38);
        backgroundColor = const Color(0xFFDDF7E5);
        label = 'Present';
        break;
      case 'late':
        textColor = const Color(0xFF9A5B13);
        backgroundColor = const Color(0xFFFFEFD8);
        label = 'Late';
        break;
      case 'absent':
        textColor = const Color(0xFFB42318);
        backgroundColor = const Color(0xFFFFE5E5);
        label = 'Absent';
        break;
      default:
        textColor = const Color(0xFF667085);
        backgroundColor = const Color(0xFFF0F1F4);
        label = normalized.isEmpty
            ? 'Unknown'
            : '${normalized[0].toUpperCase()}'
                  '${normalized.substring(1)}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
