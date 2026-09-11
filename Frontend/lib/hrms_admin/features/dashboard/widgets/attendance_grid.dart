import 'package:flutter/material.dart';
import 'package:hrms_design_system/hrms_design_system.dart';

const _gridLine = Color(0xFFE2E8F2);

/// One day's attendance mark, matching the enum values in hrms_models'
/// AttendanceStatus (kept as short display codes here: P/A/L/E/U/HL/OFF).
class AttendanceDayMark {
  final String code; // P, A, L, E, U, LV, HL, OFF
  const AttendanceDayMark(this.code);

  Color get color {
    switch (code) {
      case 'P':
        return HrmsColors.success;
      case 'A':
        return HrmsColors.danger;
      case 'L':
        return HrmsColors.warning;
      case 'E':
        return HrmsColors.info;
      case 'U':
        return HrmsColors.accentPurple;
      case 'HL':
      case 'LV':
        return HrmsColors.accentPurple;
      default:
        return HrmsColors.textMuted; // OFF
    }
  }
}

class AttendanceRowData {
  final String name;
  final String designation;
  final List<AttendanceDayMark> days;
  final int present;
  final int late;
  final int excused;
  final int unexcused;
  final int halfLeave;
  final String salaryPerMonth;
  final String totalSalaryAfterLeaves;
  final String updatedSalary;

  const AttendanceRowData({
    required this.name,
    required this.designation,
    required this.days,
    required this.present,
    required this.late,
    required this.excused,
    required this.unexcused,
    required this.halfLeave,
    required this.salaryPerMonth,
    required this.totalSalaryAfterLeaves,
    required this.updatedSalary,
  });
}

/// Horizontally scrollable attendance grid with frozen Employee Name and
/// Designation columns, per HRMS_PROJECT_BLUEPRINT.md, Section 3.
///
/// Vertical scrolling moves the frozen and scrollable halves together
/// (they share one outer scroll); horizontal scrolling only affects the
/// day/summary columns on the right.
class AttendanceGrid extends StatefulWidget {
  final List<int> days; // e.g. 1..31
  final List<String> dayLabels; // e.g. Fri, Sat, Sun...
  final List<AttendanceRowData> rows;

  const AttendanceGrid({
    super.key,
    required this.days,
    required this.dayLabels,
    required this.rows,
  });

  @override
  State<AttendanceGrid> createState() => _AttendanceGridState();
}

class _AttendanceGridState extends State<AttendanceGrid> {
  static const double _rowHeight = 40;
  static const double _headerHeight = 60;
  static const double _dayColWidth = 34;
  static const _summaryWidths = [45.0, 39.0, 42.0, 47.0, 61.0, 47.0];
  final _calendarController = ScrollController();

  @override
  void dispose() {
    _calendarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _frozenColumns(),
            Expanded(
              child: Scrollbar(
                controller: _calendarController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _calendarController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: _calendarColumns(),
                ),
              ),
            ),
            _summaryColumns(),
          ],
        ),
      ),
    );
  }

  Widget _frozenColumns() {
    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: _headerHeight,
            width: 230,
            child: Row(
              children: const [
                _HeaderCell(text: 'Employee Name', width: 120),
                _HeaderCell(text: 'Designation', width: 110),
              ],
            ),
          ),
          for (final row in widget.rows)
            SizedBox(
              height: _rowHeight,
              width: 230,
              child: Row(
                children: [
                  _BodyCell(
                    width: 120,
                    child: Text(
                      row.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF07186F),
                        fontSize: 11,
                      ),
                    ),
                  ),
                  _BodyCell(
                    width: 110,
                    child: Text(
                      row.designation,
                      style: const TextStyle(
                          color: Color(0xFF53688F), fontSize: 9),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Only the date-by-date calendar moves horizontally. Employee details on
  /// the left and attendance/payroll totals on the right stay visible.
  Widget _calendarColumns() {
    final dayColsWidth = widget.days.length * _dayColWidth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: _headerHeight,
          width: dayColsWidth,
          child: Row(
            children: [
              for (var i = 0; i < widget.days.length; i++)
                _HeaderCell(
                  width: _dayColWidth,
                  text: '${widget.days[i]}\n${widget.dayLabels[i]}',
                  dense: true,
                ),
            ],
          ),
        ),
        for (final row in widget.rows)
          SizedBox(
            height: _rowHeight,
            child: Row(
              children: [
                for (final mark in row.days)
                  _BodyCell(
                    width: _dayColWidth,
                    child: _MarkChip(mark: mark),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _summaryColumns() {
    const labels = ['Present', 'Late', 'Half\nLeave', 'Salary\nPer\nMonth', 'Total Salary\nAfter Leaves', 'Updated\nSalary'];
    const colors = [HrmsColors.success, HrmsColors.warning, HrmsColors.accentPurple, Color(0xFF07186F), Color(0xFF07186F), Color(0xFF07186F)];
    const width = 281.0;
    return Container(
      child: Column(children: [
        SizedBox(height: _headerHeight, width: width, child: Row(children: [for (var i = 0; i < labels.length; i++) _HeaderCell(width: _summaryWidths[i], text: labels[i], dense: true, color: colors[i])])),
        for (final row in widget.rows)
          SizedBox(height: _rowHeight, width: width, child: Row(children: [
            _BodyCell(width: _summaryWidths[0], child: Center(child: _statText('${row.present}', HrmsColors.success))),
            _BodyCell(width: _summaryWidths[1], child: Center(child: _statText('${row.late}', HrmsColors.warning))),
            _BodyCell(width: _summaryWidths[2], child: Center(child: _statText('${row.halfLeave}', HrmsColors.accentPurple))),
            _BodyCell(width: _summaryWidths[3], child: Center(child: Text(row.salaryPerMonth, maxLines: 1, style: _moneyStyle))),
            _BodyCell(width: _summaryWidths[4], child: Center(child: Text(row.totalSalaryAfterLeaves, maxLines: 1, style: _moneyStyle))),
            _BodyCell(width: _summaryWidths[5], child: Center(child: Text(row.updatedSalary, maxLines: 1, style: _moneyStyle))),
          ])),
      ]),
    );
  }

  Widget _statText(String value, Color color) {
    return Text(value,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700));
  }

  static const _moneyStyle = TextStyle(
    color: Color(0xFF07186F),
    fontSize: 8,
    fontWeight: FontWeight.w600,
  );
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final double width;
  final bool dense;
  final Color? color;

  const _HeaderCell(
      {required this.text, required this.width, this.dense = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: _gridLine, width: .7),
          bottom: BorderSide(color: _gridLine, width: .7),
        ),
      ),
      child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: dense ? 9 : 10,
            color: color ?? const Color(0xFF07186F),
          ),
      ),
    );
  }
}

class _BodyCell extends StatelessWidget {
  final Widget child;
  final double width;

  const _BodyCell({required this.child, required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: _gridLine, width: .7),
          bottom: BorderSide(color: _gridLine, width: .7),
        ),
      ),
      child: child,
    );
  }
}

class _MarkChip extends StatelessWidget {
  final AttendanceDayMark mark;
  const _MarkChip({required this.mark});

  @override
  Widget build(BuildContext context) {
    if (mark.code == 'OFF') {
      return const Center(
        child: Text('OFF',
            style: TextStyle(color: HrmsColors.textMuted, fontSize: 8)),
      );
    }
    return Center(
      child: Text(
        mark.code == 'LV' ? 'L' : mark.code,
        style: TextStyle(
          color: mark.color,
          fontWeight: FontWeight.w800,
          fontSize: 10,
        ),
      ),
    );
  }
}
