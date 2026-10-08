import 'package:flutter/material.dart';

const _gridLine = Color(0xFFE2E8F2);
const _todayBg = Color(0xFFEEF4FF);
const _chipBlue = Color(0xFF0767F2);

class AttendanceDayMark {
  final String code;
  const AttendanceDayMark(this.code);

  // Fixed system codes that always have a specific meaning.
  static const _systemCodes = {'P', 'A', 'LT', 'H', 'HL', 'OFF', 'L', 'LV'};

  bool get _isLeave =>
      !_systemCodes.contains(code) || code == 'L' || code == 'LV' || code == 'HL' || code == 'H';

  Color get color {
    switch (code) {
      case 'P':   return const Color(0xFF078C42);
      case 'A':   return const Color(0xFFD62545);
      case 'LT':  return const Color(0xFFE8770C);
      case 'OFF': return const Color(0xFF9CA3AF);
      default:    return _isLeave ? const Color(0xFF7C3CF2) : const Color(0xFF9CA3AF);
    }
  }

  Color get chipBg {
    switch (code) {
      case 'P':   return const Color(0xFFE8F7EE);
      case 'A':   return const Color(0xFFFFF0F2);
      case 'LT':  return const Color(0xFFFFF4E8);
      case 'OFF': return const Color(0xFFF1F3F8);
      default:    return _isLeave ? const Color(0xFFF2ECFF) : Colors.transparent;
    }
  }
}

class AttendanceRowData {
  final String employeeId;
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
    this.employeeId = '',
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

class AttendanceGrid extends StatelessWidget {
  final List<int> days;
  final List<String> dayLabels;
  final List<AttendanceRowData> rows;
  final bool showSummary;
  final int? todayIndex;
  final void Function(AttendanceRowData row, int dayIndex)? onCellTap;

  const AttendanceGrid({
    super.key,
    required this.days,
    required this.dayLabels,
    required this.rows,
    this.showSummary = true,
    this.todayIndex,
    this.onCellTap,
  });

  // Layout constants
  static const double _headH  = 54;
  static const double _rowH   = 50;
  static const double _frozenW = 230;
  static const double _minDayW = 38;
  static const double _maxDayW = 80;

  // Summary columns
  static const List<double> _sW = [80, 64, 64, 96, 110, 120, 146, 120];
  static const List<String> _sLabel = [
    'Present', 'Late', 'Leave', 'Half Leave',
    'Earned Leave', 'Salary / Month', 'Absent / Deduction', 'Updated Salary',
  ];
  static const List<Color> _sColor = [
    Color(0xFF078C42), Color(0xFFE8770C),
    Color(0xFF7C3CF2), Color(0xFF7C3CF2),
    _chipBlue,
    Color(0xFF07186F), Color(0xFF07186F), Color(0xFF07186F),
  ];

  double get _sumW => showSummary ? _sW.fold(0.0, (a, b) => a + b) : 0.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, box) {
      // Compute day column width to fill available space
      final calW = (box.maxWidth - _frozenW - _sumW).clamp(0.0, double.infinity);
      final dayW = days.isEmpty
          ? _minDayW
          : (calW / days.length).clamp(_minDayW, _maxDayW);

      return Column(
        children: [
          // ── FROZEN HEADER (never scrolls) ───────────────────────────────
          SizedBox(
            height: _headH,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _hCell('Employee / Designation', '', _frozenW,
                    align: Alignment.centerLeft, hpad: 14),
                for (var i = 0; i < days.length; i++)
                  _hCell('${days[i]}', dayLabels[i], dayW,
                      today: todayIndex == i),
                if (showSummary)
                  for (var i = 0; i < _sLabel.length; i++)
                    _hCell(_sLabel[i], 'Monthly', _sW[i], color: _sColor[i]),
              ],
            ),
          ),
          // ── SCROLLABLE BODY ─────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Column(
                children: [
                  for (final row in rows)
                    SizedBox(
                      height: _rowH,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _empCell(row, _frozenW),
                          for (var i = 0; i < row.days.length; i++)
                            _dayCell(dayW, row.days[i],
                                today: todayIndex == i,
                                onTap: onCellTap != null
                                    ? () => onCellTap!(row, i)
                                    : null),
                          if (showSummary) ...[
                            _bCell(_sW[0], _stat('${row.present}',        _sColor[0])),
                            _bCell(_sW[1], _stat('${row.late}',           _sColor[1])),
                            _bCell(_sW[2], _stat('${row.approvedLeave}',  _sColor[2])),
                            _bCell(_sW[3], _stat('${row.halfLeave}',      _sColor[3])),
                            _bCell(_sW[4], _stat('${row.earnedLeave}',    _sColor[4])),
                            _bCell(_sW[5], _money(row.salaryPerMonth)),
                            _bCell(_sW[6], _money(row.totalSalaryAfterLeaves)),
                            _bCell(_sW[7], _money(row.updatedSalary)),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  // ── Cell builders ─────────────────────────────────────────────────────────

  Widget _hCell(String label, String sub, double w, {
    Color? color, bool today = false,
    Alignment align = Alignment.center, double hpad = 6,
  }) {
    final fg = today ? _chipBlue : (color ?? const Color(0xFF07186F));
    return Container(
      width: w,
      alignment: align,
      padding: EdgeInsets.symmetric(horizontal: hpad),
      decoration: BoxDecoration(
        color: today ? _todayBg : const Color(0xFFF6F8FE),
        border: const Border(
          right: BorderSide(color: _gridLine, width: .7),
          bottom: BorderSide(color: _gridLine, width: .7),
        ),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: fg)),
        if (sub.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(sub,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 9, color: Color(0xFF8599C4))),
        ],
      ]),
    );
  }

  Widget _empCell(AttendanceRowData row, double w) => Container(
    width: w,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: const BoxDecoration(
      border: Border(
        right: BorderSide(color: _gridLine, width: .7),
        bottom: BorderSide(color: _gridLine, width: .7),
      ),
    ),
    alignment: Alignment.centerLeft,
    child: Row(children: [
      _Avatar(name: row.name),
      const SizedBox(width: 10),
      Expanded(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(row.name,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF07186F), fontSize: 13)),
          const SizedBox(height: 3),
          Text(
            row.employeeId.isNotEmpty
                ? '${row.designation} · ${row.employeeId}'
                : row.designation,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF53688F), fontSize: 10)),
        ],
      )),
    ]),
  );

  Widget _dayCell(double w, AttendanceDayMark mark, {
    bool today = false, VoidCallback? onTap,
  }) =>
      InkWell(
        onTap: onTap,
        child: Container(
          width: w,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: today ? _todayBg : null,
            border: const Border(
              right: BorderSide(color: _gridLine, width: .7),
              bottom: BorderSide(color: _gridLine, width: .7),
            ),
          ),
          child: _MarkChip(mark: mark),
        ),
      );

  Widget _bCell(double w, Widget child) => Container(
    width: w,
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: 6),
    decoration: const BoxDecoration(
      border: Border(
        right: BorderSide(color: _gridLine, width: .7),
        bottom: BorderSide(color: _gridLine, width: .7),
      ),
    ),
    child: child,
  );

  Widget _stat(String v, Color c) => Text(v,
      style: TextStyle(color: c, fontSize: 14, fontWeight: FontWeight.w700));

  Widget _money(String v) => Text(v,
      maxLines: 1,
      style: const TextStyle(
          color: Color(0xFF07186F), fontSize: 11, fontWeight: FontWeight.w600));
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});

  String get _initials {
    final parts = name.trim().split(' ').where((w) => w.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) => Container(
    width: 34, height: 34,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: const Color(0xFFEDF3FF),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(_initials,
        style: const TextStyle(
            color: _chipBlue, fontSize: 13, fontWeight: FontWeight.w700)),
  );
}

// ── Mark chip ─────────────────────────────────────────────────────────────────

class _MarkChip extends StatelessWidget {
  final AttendanceDayMark mark;
  const _MarkChip({required this.mark});

  @override
  Widget build(BuildContext context) {
    if (mark.code.isEmpty) {
      return const Text('–',
          style: TextStyle(color: Color(0xFFB0BCCC), fontSize: 13));
    }
    final label = mark.code == 'LV' ? 'L' : mark.code;
    return Container(
      constraints: const BoxConstraints(minWidth: 24),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: mark.chipBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: mark.color, fontWeight: FontWeight.w800, fontSize: 11)),
    );
  }
}
