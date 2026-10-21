// Content Calendar export — "GoDigital theme" (same style as the invoice
// ledger export): a blue & white Excel sheet (.xls, HTML table) or a plain
// .csv with the SAME columns. Both files import back with "Import Sheet":
// rows are matched by the ID column, so keep ID / S.No / Deliverable as they are.

import 'dart:convert';

class CalendarExportColumn {
  final String key;
  final String header;
  final bool locked;
  final bool date;
  final String align;
  final int width;
  const CalendarExportColumn(
    this.key,
    this.header, {
    this.locked = false,
    this.date = false,
    this.align = 'left',
    this.width = 140,
  });
}

/// Header names match the server's import (ID, S.No, Submit Date …).
const calendarExportColumns = <CalendarExportColumn>[
  CalendarExportColumn('s_no', 'S.No', locked: true, align: 'center', width: 50),
  CalendarExportColumn('id', 'ID', locked: true, align: 'center', width: 60),
  CalendarExportColumn('deliverable', 'Deliverable', locked: true, align: 'center', width: 120),
  CalendarExportColumn('submit_date', 'Submit Date', date: true, align: 'center', width: 100),
  CalendarExportColumn('hook_headline', 'Hook / Headline', width: 220),
  CalendarExportColumn('description_points', 'Description', width: 320),
  CalendarExportColumn('caption', 'Caption', width: 260),
  CalendarExportColumn('cta', 'CTA', width: 130),
  CalendarExportColumn('publish_date', 'Publish Date', date: true, align: 'center', width: 100),
  CalendarExportColumn('notes', 'Notes', width: 200),
];

String _s(dynamic v) {
  final s = v?.toString() ?? '';
  return s == 'null' ? '' : s;
}

String _value(Map<String, dynamic> row, String key) {
  if (key == 'description_points') {
    final d = _s(row['description_points']);
    return d.isNotEmpty ? d : _s(row['description']);
  }
  final v = _s(row[key]).trim();
  if (key == 'submit_date' || key == 'publish_date') {
    return v.length >= 10 ? v.substring(0, 10) : v;
  }
  return v;
}

String _status(Map<String, dynamic> row) {
  final s = _s(row['cc_status']).isNotEmpty ? _s(row['cc_status']) : _s(row['status']);
  return s.isEmpty ? 'IDLE' : s.toUpperCase();
}

String _esc(String text) => const HtmlEscape(HtmlEscapeMode.element)
    .convert(text)
    .replaceAll('\r\n', '\n')
    .replaceAll('\n', '<br style="mso-data-placement:same-cell;" />');

String _two(int n) => n.toString().padLeft(2, '0');
String _stamp(DateTime d) =>
    '${_two(d.day)}/${_two(d.month)}/${d.year} ${_two(d.hour)}:${_two(d.minute)}';

/// Bytes of the themed Excel sheet (UTF-8 with BOM). Save as `.xls`.
List<int> buildCalendarXls({
  required String clientName,
  required String deliverable,
  required List<Map<String, dynamic>> rows,
  String cardDate = '',
  String exportedBy = '',
}) {
  final cols = calendarExportColumns.length + 1; // + Status
  final b = StringBuffer();
  b.writeln('''<html xmlns:o="urn:schemas-microsoft-com:office:office"
 xmlns:x="urn:schemas-microsoft-com:office:excel"
 xmlns="http://www.w3.org/TR/REC-html40">
<head>
<meta charset="utf-8">
<!--[if gte mso 9]><xml><x:ExcelWorkbook><x:ExcelWorksheets><x:ExcelWorksheet>
<x:Name>Content Calendar</x:Name><x:WorksheetOptions><x:DisplayGridlines/>
<x:FreezePanes/><x:FrozenNoSplit/><x:SplitHorizontal>5</x:SplitHorizontal>
<x:TopRowBottomPane>5</x:TopRowBottomPane><x:ActivePane>2</x:ActivePane>
</x:WorksheetOptions></x:ExcelWorksheet></x:ExcelWorksheets></x:ExcelWorkbook></xml><![endif]-->
<style>
  body { font-family: 'Segoe UI', Arial, sans-serif; margin: 20px; }
  table { border-collapse: collapse; }
  .header-title { font-size: 16px; font-weight: bold; color: #FFFFFF; background-color: #0052CC; text-align: center; padding: 12px; height: 34px; }
  .header-sub { font-size: 11px; color: #475569; text-align: center; background-color: #F8FAFC; padding: 6px; font-weight: bold; }
  .header-help { font-size: 10px; color: #0A3D91; background-color: #EFF5FF; font-style: italic; padding: 6px; text-align: left; }
  th { background-color: #0052CC; color: #FFFFFF; font-weight: bold; font-size: 11px; padding: 10px; border: 1px solid #4B83E3; text-align: center; vertical-align: middle; }
  th.key { background-color: #0A3D91; }
  td { font-size: 11px; padding: 8px 10px; border: 1px solid #D7E2F2; color: #172033; vertical-align: top; mso-number-format: "\\@"; }
  td.key { background-color: #E3ECFB; color: #475569; font-weight: bold; text-align: center; }
  tr.stripe td { background-color: #F7FAFF; }
  tr.stripe td.key { background-color: #E3ECFB; }
  .center { text-align: center; }
  .bold { font-weight: bold; }
  .hook { font-weight: bold; color: #0052CC; }
  .status { font-weight: bold; text-align: center; }
  .status-idle { background-color: #F1F5F9; color: #475569; }
  .status-progress { background-color: #DBEAFE; color: #1D4ED8; }
  .status-hold { background-color: #FEF3C7; color: #D97706; }
  .status-done { background-color: #DCFCE7; color: #16A34A; }
</style>
</head>
<body>
<table>''');
  for (final c in calendarExportColumns) {
    b.writeln('<col width="${c.width}">');
  }
  b.writeln('<col width="100">');
  b.writeln(
      '<tr><td colspan="$cols" class="header-title">GO DIGITAL - CONTENT CALENDAR</td></tr>');
  final parts = <String>[
    'Client: ${_esc(clientName)}',
    if (cardDate.isNotEmpty) 'Card: ${_esc(cardDate)}',
    'Category: ${_esc(deliverable)}',
    '${rows.length} row${rows.length == 1 ? '' : 's'}',
    'Generated On: ${_stamp(DateTime.now())}${exportedBy.isEmpty ? '' : ' by ${_esc(exportedBy)}'}',
  ];
  b.writeln('<tr><td colspan="$cols" class="header-sub">${parts.join(' &nbsp;·&nbsp; ')}</td></tr>');
  b.writeln('<tr><td colspan="$cols" class="header-help">How to edit: change only the WHITE columns '
      '(Submit Date, Hook / Headline, Description, Caption, CTA, Publish Date, Notes). '
      'Keep S.No, ID and Deliverable as they are. Dates as YYYY-MM-DD. '
      'Save the file, then in the app open the same card + category and press "Import Sheet".</td></tr>');
  b.write('<tr>');
  for (final c in calendarExportColumns) {
    b.write('<th${c.locked ? ' class="key"' : ''}>${_esc(c.header)}</th>');
  }
  b.writeln('<th class="key">Status</th></tr>');

  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    b.write(i.isOdd ? '<tr class="stripe">' : '<tr>');
    for (final c in calendarExportColumns) {
      final v = _value(row, c.key);
      final cls = c.locked
          ? 'key'
          : c.key == 'hook_headline'
              ? 'hook'
              : c.align == 'center'
                  ? 'center'
                  : '';
      b.write('<td${cls.isEmpty ? '' : ' class="$cls"'}>${_esc(v)}</td>');
    }
    final st = _status(row);
    final stClass = switch (st) {
      'IN PROGRESS' => 'status-progress',
      'ON HOLD' => 'status-hold',
      'COMPLETED' || 'APPROVED' || 'ASSIGNED' => 'status-done',
      _ => 'status-idle',
    };
    b.writeln('<td class="status $stClass">${_esc(st)}</td></tr>');
  }
  b.writeln('</table>\n</body>\n</html>');
  return [0xEF, 0xBB, 0xBF, ...utf8.encode(b.toString())];
}

String _csvCell(String v) =>
    RegExp(r'[",\r\n]').hasMatch(v) ? '"${v.replaceAll('"', '""')}"' : v;

/// Same columns as the Excel sheet. UTF-8 with BOM so Excel shows Tamil / emoji.
List<int> buildCalendarCsv(List<Map<String, dynamic>> rows) {
  final lines = <String>[
    [for (final c in calendarExportColumns) _csvCell(c.header), 'Status'].join(','),
    for (final row in rows)
      [
        for (final c in calendarExportColumns) _csvCell(_value(row, c.key)),
        _csvCell(_status(row)),
      ].join(','),
  ];
  return [0xEF, 0xBB, 0xBF, ...utf8.encode('${lines.join('\r\n')}\r\n')];
}

/// "GODIGITAL_CREATIVE-POSTER_2026-09-21_20261020-1605.xls"
String calendarExportFileName(String client, String deliverable, String cardDate, String ext) {
  final now = DateTime.now();
  String clean(String s) => s.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-');
  final stamp = '${now.year}${_two(now.month)}${_two(now.day)}-${_two(now.hour)}${_two(now.minute)}';
  return [
    clean(client),
    clean(deliverable),
    if (cardDate.isNotEmpty) cardDate,
    stamp,
  ].where((p) => p.isNotEmpty).join('_') + '.$ext';
}
