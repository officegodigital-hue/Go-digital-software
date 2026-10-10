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
      case 'EL':
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
  final int absent;
  final String absentDeduction;
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
    required this.absent,
    required this.absentDeduction,
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
  final bool expanded;
  final VoidCallback? onToggleExpanded;

  const AttendanceGrid({
    super.key,
    required this.days,
    required this.dayLabels,
    required this.rows,
    this.showSummary = true,
    this.expanded = false,
    this.onToggleExpanded,
  });

  @override
  State<AttendanceGrid> createState() => _AttendanceGridState();
}

class _AttendanceGridState extends State<AttendanceGrid> {
  static const int _daysPerWindow = 7;
  static const double _rowHeight = 52;
  static const double _headerHeight = 60;
  static const double _dayColWidth = 58;
  static const double _dayColWidthMax = 96;
  static const double _frozenWidth = 280;
  static const _summaryWidths = [
    78.0,
    78.0,
    78.0,
    78.0,
    78.0,
    78.0,
    78.0,
    78.0,
  ];
  final _calendarController = ScrollController();
  int _windowStart = 0;

  int get _windowEnd => widget.showSummary
      ? (_windowStart + _daysPerWindow).clamp(0, widget.days.length)
      : widget.days.length;

  List<int> get _visibleDayIndexes => List<int>.generate(
    _windowEnd - (widget.showSummary ? _windowStart : 0),
    (index) => (widget.showSummary ? _windowStart : 0) + index,
  );

  int get _lastWindowStart => (widget.days.length - _daysPerWindow)
      .clamp(0, widget.days.length)
      .toInt();

  @override
  void didUpdateWidget(covariant AttendanceGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_windowStart > _lastWindowStart) _windowStart = _lastWindowStart;
  }

  @override
  void dispose() {
    _calendarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final summaryWidth = widget.showSummary
            ? _summaryWidths.reduce((a, b) => a + b)
            : 0.0;
        final availableForCalendar =
            (constraints.maxWidth - _frozenWidth - summaryWidth).clamp(
              0.0,
              double.infinity,
            );
        final visibleIndexes = _visibleDayIndexes;
        final baseDayColsWidth = visibleIndexes.length * _dayColWidth;

        final stretchColWidth = visibleIndexes.isEmpty
            ? _dayColWidth
            : availableForCalendar / visibleIndexes.length;
        final canStretchToFit = stretchColWidth >= _dayColWidth;
        final needsScroll =
            widget.showSummary &&
            !canStretchToFit &&
            baseDayColsWidth > availableForCalendar;
        // With the payroll summary hidden, every date is intentionally
        // visible at once. Let the date cells shrink to share the available
        // table width instead of putting the calendar in a horizontal scroll.
        final colWidth = widget.showSummary
            ? (needsScroll
                  ? _dayColWidth
                  : (canStretchToFit
                        ? stretchColWidth.clamp(_dayColWidth, _dayColWidthMax)
                        : _dayColWidth))
            : (visibleIndexes.isEmpty
                  ? _dayColWidth
                  : availableForCalendar / visibleIndexes.length);

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
            child: SingleChildScrollView(
              controller: _calendarController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: calendarBody,
            ),
          );
        }

        final tableBody = IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _frozenBodyColumn(),
              calendarBody,
              if (widget.showSummary) _summaryBodyColumn(),
            ],
          ),
        );

        return Column(
          mainAxisSize: widget.expanded ? MainAxisSize.min : MainAxisSize.max,
          children: [
            _dayWindowNavigator(),
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
            if (widget.expanded)
              tableBody
            else
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: tableBody,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _dayWindowNavigator() {
    if (!widget.showSummary) {
      return Container(
        height: 44,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFF),
          border: Border(bottom: BorderSide(color: _gridLine)),
        ),
        child: Text(
          'All ${widget.days.length} days',
          style: const TextStyle(
            color: Color(0xFF07186F),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }
    final hasPrevious = _windowStart > 0;
    final hasNext = _windowEnd < widget.days.length;
    final firstDay = widget.days.isEmpty ? 0 : widget.days[_windowStart];
    final lastDay = widget.days.isEmpty ? 0 : widget.days[_windowEnd - 1];
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFF),
        border: Border(bottom: BorderSide(color: _gridLine)),
      ),
      child: Row(
        children: [
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Previous 7 days',
                onPressed: hasPrevious
                    ? () => setState(() {
                        _windowStart = (_windowStart - _daysPerWindow).clamp(
                          0,
                          widget.days.length,
                        );
                      })
                    : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Text(
                'Days $firstDay–$lastDay of ${widget.days.length}',
                style: const TextStyle(
                  color: Color(0xFF07186F),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              IconButton(
                tooltip: 'Next 7 days',
                onPressed: hasNext
                    ? () => setState(() {
                        _windowStart = (_windowStart + _daysPerWindow)
                            .clamp(0, _lastWindowStart)
                            .toInt();
                      })
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const Spacer(),
          if (widget.onToggleExpanded != null)
            TextButton.icon(
              onPressed: widget.onToggleExpanded,
              icon: Icon(
                widget.expanded
                    ? Icons.unfold_less_rounded
                    : Icons.unfold_more_rounded,
                size: 17,
              ),
              label: Text(widget.expanded ? 'Collapse list' : 'Expand list'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0767F2),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _frozenHeaderRow() => const SizedBox(
    width: _frozenWidth,
    child: Row(
      children: [
        _HeaderCell(text: 'Employee Name', width: 170),
        _HeaderCell(text: 'Designation', width: 110),
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
            width: _frozenWidth,
            child: Row(
              children: [
                _BodyCell(
                  width: 170,
                  child: Text(
                    row.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF07186F),
                      fontSize: 12,
                    ),
                  ),
                ),
                _BodyCell(
                  width: 110,
                  child: Text(
                    row.designation,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF53688F),
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _calendarHeaderRow(double colWidth) {
    final visibleIndexes = _visibleDayIndexes;
    final dayColsWidth = visibleIndexes.length * colWidth;
    return SizedBox(
      width: dayColsWidth,
      child: Row(
        children: [
          for (final index in visibleIndexes)
            _HeaderCell(
              width: colWidth,
              text: '${widget.days[index]}\n${widget.dayLabels[index]}',
              dense: true,
            ),
        ],
      ),
    );
  }

  Widget _calendarBodyColumn(double colWidth) {
    final visibleIndexes = _visibleDayIndexes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in widget.rows)
          SizedBox(
            height: _rowHeight,
            child: Row(
              children: [
                for (final index in visibleIndexes)
                  _BodyCell(
                    width: colWidth,
                    child: _MarkChip(
                      mark: index < row.days.length
                          ? row.days[index]
                          : const AttendanceDayMark(''),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  static const _summaryLabels = [
    'Present',
    'Late',
    'Leave',
    'Half\nLeave',
    'Earned\nLeave',
    'Salary\nPer\nMonth',
    'Absent\nDeduction',
    'Updated\nSalary',
  ];
  static const _summaryColors = [
    HrmsColors.success,
    HrmsColors.warning,
    HrmsColors.accentPurple,
    HrmsColors.accentPurple,
    HrmsColors.info,
    Color(0xFF07186F),
    HrmsColors.danger,
    Color(0xFF07186F),
  ];
  static const _summaryPanelWidth = 624.0;

  Widget _summaryHeaderRow() => SizedBox(
    width: _summaryPanelWidth,
    child: Row(
      children: [
        for (var i = 0; i < _summaryLabels.length; i++)
          _HeaderCell(
            width: _summaryWidths[i],
            text: _summaryLabels[i],
            dense: true,
            color: _summaryColors[i],
          ),
      ],
    ),
  );

  Widget _summaryBodyColumn() {
    return Column(
      children: [
        for (final row in widget.rows)
          SizedBox(
            height: _rowHeight,
            width: _summaryPanelWidth,
            child: Row(
              children: [
                _BodyCell(
                  width: _summaryWidths[0],
                  child: Center(
                    child: _statText('${row.present}', HrmsColors.success),
                  ),
                ),
                _BodyCell(
                  width: _summaryWidths[1],
                  child: Center(
                    child: _statText('${row.late}', HrmsColors.warning),
                  ),
                ),
                _BodyCell(
                  width: _summaryWidths[2],
                  child: Center(
                    child: _statText(
                      '${row.approvedLeave}',
                      HrmsColors.accentPurple,
                    ),
                  ),
                ),
                _BodyCell(
                  width: _summaryWidths[3],
                  child: Center(
                    child: _statText(
                      '${row.halfLeave}',
                      HrmsColors.accentPurple,
                    ),
                  ),
                ),
                _BodyCell(
                  width: _summaryWidths[4],
                  child: Center(
                    child: _statText('${row.earnedLeave}', HrmsColors.info),
                  ),
                ),
                _BodyCell(
                  width: _summaryWidths[5],
                  child: Center(
                    child: Text(
                      row.salaryPerMonth,
                      maxLines: 1,
                      style: _moneyStyle,
                    ),
                  ),
                ),
                _BodyCell(
                  width: _summaryWidths[6],
                  child: Center(
                    child: Text(
                      '${row.absent} ${row.absentDeduction}',
                      maxLines: 1,
                      style: _moneyStyle.copyWith(color: HrmsColors.danger),
                    ),
                  ),
                ),
                _BodyCell(
                  width: _summaryWidths[7],
                  child: Center(
                    child: Text(
                      row.updatedSalary,
                      maxLines: 1,
                      style: _moneyStyle,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _statText(String value, Color color) {
    return Text(
      value,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
    );
  }

  static const _moneyStyle = TextStyle(
    color: Color(0xFF07186F),
    fontSize: 10,
    fontWeight: FontWeight.w600,
  );
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final double width;
  final bool dense;
  final Color? color;

  const _HeaderCell({
    required this.text,
    required this.width,
    this.dense = false,
    this.color,
  });

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
        child: Text(
          'OFF',
          style: TextStyle(color: HrmsColors.textMuted, fontSize: 8),
        ),
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
