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
  final int earnedLeave;
  final int approvedLeave;
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
    required this.earnedLeave,
    required this.approvedLeave,
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
  final bool showSummary;

  const AttendanceGrid({
    super.key,
    required this.days,
    required this.dayLabels,
    required this.rows,
    this.showSummary = true,
  });

  @override
  State<AttendanceGrid> createState() => _AttendanceGridState();
}

class _AttendanceGridState extends State<AttendanceGrid> {
  static const double _rowHeight = 40;
  static const double _headerHeight = 60;
  static const double _dayColWidth = 24;
  static const double _dayColWidthMax = 44;
  static const _summaryWidths = [40.0, 34.0, 44.0, 38.0, 42.0, 45.0, 58.0, 45.0];
  final _calendarController = ScrollController();

  @override
  void dispose() {
    _calendarController.dispose();
    super.dispose();
  }

  // Any leftover width — after the frozen name/designation columns and
  // (when shown) the summary panel take their share — is handed back to the
  // day columns, which stretch evenly (up to a sensible cap) to fill it.
  // That keeps the three sections visually balanced instead of leaving dead
  // space on one side while the calendar looks cramped on the other. Only
  // when there truly isn't enough room even at the minimum width does the
  // calendar fall back to a visible scrollbar.
  //
  // The header row (employee/day/summary column titles) sits outside the
  // vertical scroll entirely, so it stays fixed in place while only the
  // employee rows underneath scroll. When the calendar section itself needs
  // horizontal scrolling, its header and body share one ScrollController so
  // they stay aligned — the header's own scroll is disabled so only the body
  // can be dragged.
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      const frozenWidth = 212.0;
      final summaryWidth =
          widget.showSummary ? _summaryWidths.reduce((a, b) => a + b) : 0.0;
      final availableForCalendar =
          (constraints.maxWidth - frozenWidth - summaryWidth)
              .clamp(0.0, double.infinity);
      final baseDayColsWidth = widget.days.length * _dayColWidth;

      final stretchColWidth = widget.days.isEmpty
          ? _dayColWidth
          : availableForCalendar / widget.days.length;
      final canStretchToFit = stretchColWidth >= _dayColWidth;
      final needsScroll = !canStretchToFit && baseDayColsWidth > availableForCalendar;
      final colWidth = needsScroll
          ? _dayColWidth
          : (canStretchToFit
              ? stretchColWidth.clamp(_dayColWidth, _dayColWidthMax)
              : _dayColWidth);

      Widget calendarHeader = _calendarHeaderRow(colWidth);
      Widget calendarBody = _calendarBodyColumn(colWidth);
      if (needsScroll) {
        calendarHeader = SizedBox(
          width: availableForCalendar,
          child: SingleChildScrollView(
            controller: _calendarController,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: calendarHeader,
          ),
        );
        calendarBody = SizedBox(
          width: availableForCalendar,
          child: Scrollbar(
            controller: _calendarController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _calendarController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: calendarBody,
            ),
          ),
        );
      }

      return Column(
        children: [
          SizedBox(
            height: _headerHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _frozenHeaderRow(),
                calendarHeader,
                if (widget.showSummary) _summaryHeaderRow(),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _frozenBodyColumn(),
                    calendarBody,
                    if (widget.showSummary) _summaryBodyColumn(),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _frozenHeaderRow() => const SizedBox(
        width: 212,
        child: Row(
          children: [
            _HeaderCell(text: 'Employee Name', width: 112),
            _HeaderCell(text: 'Designation', width: 100),
          ],
        ),
      );

  Widget _frozenBodyColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in widget.rows)
          SizedBox(
            height: _rowHeight,
            width: 212,
            child: Row(
              children: [
                _BodyCell(
                  width: 112,
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
                  width: 100,
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
    );
  }

  /// [colWidth] lets each day column stretch to fill freed-up space when the
  /// summary panel is hidden; it defaults to the compact fixed width.
  Widget _calendarHeaderRow(double colWidth) {
    final dayColsWidth = widget.days.length * colWidth;
    return SizedBox(
      width: dayColsWidth,
      child: Row(
        children: [
          for (var i = 0; i < widget.days.length; i++)
            _HeaderCell(
              width: colWidth,
              text: '${widget.days[i]}\n${widget.dayLabels[i]}',
              dense: true,
            ),
        ],
      ),
    );
  }

  Widget _calendarBodyColumn(double colWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in widget.rows)
          SizedBox(
            height: _rowHeight,
            child: Row(
              children: [
                for (final mark in row.days)
                  _BodyCell(
                    width: colWidth,
                    child: _MarkChip(mark: mark),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  static const _summaryLabels = ['Present', 'Late', 'Leave', 'Half\nLeave', 'Earned\nLeave', 'Salary\nPer\nMonth', 'Absent\nDeduction', 'Updated\nSalary'];
  static const _summaryColors = [HrmsColors.success, HrmsColors.warning, HrmsColors.accentPurple, HrmsColors.accentPurple, HrmsColors.info, Color(0xFF07186F), Color(0xFF07186F), Color(0xFF07186F)];
  static const _summaryPanelWidth = 346.0;

  Widget _summaryHeaderRow() => SizedBox(
        width: _summaryPanelWidth,
        child: Row(children: [
          for (var i = 0; i < _summaryLabels.length; i++)
            _HeaderCell(width: _summaryWidths[i], text: _summaryLabels[i], dense: true, color: _summaryColors[i]),
        ]),
      );

  Widget _summaryBodyColumn() {
    return Column(children: [
      for (final row in widget.rows)
        SizedBox(height: _rowHeight, width: _summaryPanelWidth, child: Row(children: [
          _BodyCell(width: _summaryWidths[0], child: Center(child: _statText('${row.present}', HrmsColors.success))),
          _BodyCell(width: _summaryWidths[1], child: Center(child: _statText('${row.late}', HrmsColors.warning))),
          _BodyCell(width: _summaryWidths[2], child: Center(child: _statText('${row.approvedLeave}', HrmsColors.accentPurple))),
          _BodyCell(width: _summaryWidths[3], child: Center(child: _statText('${row.halfLeave}', HrmsColors.accentPurple))),
          _BodyCell(width: _summaryWidths[4], child: Center(child: _statText('${row.earnedLeave}', HrmsColors.info))),
          _BodyCell(width: _summaryWidths[5], child: Center(child: Text(row.salaryPerMonth, maxLines: 1, style: _moneyStyle))),
          _BodyCell(width: _summaryWidths[6], child: Center(child: Text(row.totalSalaryAfterLeaves, maxLines: 1, style: _moneyStyle))),
          _BodyCell(width: _summaryWidths[7], child: Center(child: Text(row.updatedSalary, maxLines: 1, style: _moneyStyle))),
        ])),
    ]);
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
