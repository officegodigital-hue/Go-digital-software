import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/admin_attendance_models.dart';

class AttendanceExportService {
  const AttendanceExportService._();

  static Future<void> exportExcel({
    required List<AdminAttendanceRecord> records,
    required DateTime? fromDate,
    required DateTime? toDate,
  }) async {
    if (records.isEmpty) {
      throw const AttendanceExportException(
        'No attendance records are available to export.',
      );
    }

    final Excel workbook = Excel.createExcel();

    const String sheetName = 'Attendance';

    workbook.rename('Sheet1', sheetName);

    final Sheet sheet = workbook[sheetName];

    sheet.appendRow(<CellValue>[
      TextCellValue('Employee'),
      TextCellValue('Employee ID'),
      TextCellValue('Role'),
      TextCellValue('Date'),
      TextCellValue('Login Time'),
      TextCellValue('Logout Time'),
      TextCellValue('Work Hours'),
      TextCellValue('Extra Hours'),
      TextCellValue('Overtime'),
      TextCellValue('Status'),
    ]);

    for (final AdminAttendanceRecord record in records) {
      sheet.appendRow(<CellValue>[
        TextCellValue(record.employeeName),
        TextCellValue(record.employeeCode),
        TextCellValue(record.roleName),
        TextCellValue(_formatDate(record.attendanceDate)),
        TextCellValue(_formatTime(record.localCheckInAt)),
        TextCellValue(_formatTime(record.localCheckOutAt)),
        TextCellValue(record.workingTimeLabel),
        TextCellValue(record.extraHoursLabel),
        TextCellValue(record.overtimeLabel),
        TextCellValue(_titleCase(record.attendanceStatus)),
      ]);
    }

    final List<int>? encoded = workbook.encode();

    if (encoded == null || encoded.isEmpty) {
      throw const AttendanceExportException('Excel generation failed.');
    }

    await FileSaver.instance.saveFile(
      name: _buildFileName(
        prefix: 'attendance',
        fromDate: fromDate,
        toDate: toDate,
      ),
      bytes: Uint8List.fromList(encoded),
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }

  static Future<void> exportPdf({
    required List<AdminAttendanceRecord> records,
    required DateTime? fromDate,
    required DateTime? toDate,
  }) async {
    if (records.isEmpty) {
      throw const AttendanceExportException(
        'No attendance records are available to export.',
      );
    }

    final pw.Document document = pw.Document(
      title: 'Daily Attendance Log',
      author: 'GoDigital Admin',
      subject: 'Employee attendance report',
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        maxPages: 100,
        footer: (pw.Context context) {
          return pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          );
        },
        build: (pw.Context context) {
          return <pw.Widget>[
            pw.Text(
              'Daily Attendance Log',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Date Range: ${_formatDateRange(fromDate, toDate)}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 14),
            pw.TableHelper.fromTextArray(
              headers: const <String>[
                'Employee',
                'Employee ID',
                'Role',
                'Date',
                'Login',
                'Logout',
                'Work Hours',
                'Extra Hours',
                'Overtime',
                'Status',
              ],
              data: records
                  .map((AdminAttendanceRecord record) {
                    return <String>[
                      record.employeeName,
                      record.employeeCode,
                      record.roleName,
                      _formatDate(record.attendanceDate),
                      _formatTime(record.localCheckInAt),
                      _formatTime(record.localCheckOutAt),
                      record.workingTimeLabel,
                      record.extraHoursLabel,
                      record.overtimeLabel,
                      _titleCase(record.attendanceStatus),
                    ];
                  })
                  .toList(growable: false),
              headerStyle: pw.TextStyle(
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 7),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellPadding: const pw.EdgeInsets.all(4),
              border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.4),
              columnWidths: const <int, pw.TableColumnWidth>{
                0: pw.FlexColumnWidth(1.5),
                1: pw.FlexColumnWidth(0.9),
                2: pw.FlexColumnWidth(1.2),
                3: pw.FlexColumnWidth(0.9),
                4: pw.FlexColumnWidth(0.8),
                5: pw.FlexColumnWidth(0.8),
                6: pw.FlexColumnWidth(0.8),
                7: pw.FlexColumnWidth(0.8),
                8: pw.FlexColumnWidth(0.8),
                9: pw.FlexColumnWidth(0.8),
              },
            ),
          ];
        },
      ),
    );

    final Uint8List bytes = await document.save();

    if (bytes.isEmpty) {
      throw const AttendanceExportException('PDF generation failed.');
    }

    await FileSaver.instance.saveFile(
      name: _buildFileName(
        prefix: 'attendance',
        fromDate: fromDate,
        toDate: toDate,
      ),
      bytes: bytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );
  }

  static String _buildFileName({
    required String prefix,
    required DateTime? fromDate,
    required DateTime? toDate,
  }) {
    final String from = fromDate == null
        ? 'all'
        : _formatDateForFileName(fromDate);

    final String to = toDate == null ? 'dates' : _formatDateForFileName(toDate);

    return '${prefix}_${from}_to_$to';
  }

  static String _formatDateRange(DateTime? fromDate, DateTime? toDate) {
    if (fromDate == null && toDate == null) {
      return 'All Dates';
    }

    if (fromDate != null && toDate != null) {
      return '${_formatDate(fromDate)} - ${_formatDate(toDate)}';
    }

    if (fromDate != null) {
      return 'From ${_formatDate(fromDate)}';
    }

    return 'Until ${_formatDate(toDate)}';
  }

  static String _formatDate(DateTime? value) {
    if (value == null) {
      return '-';
    }

    final String day = value.day.toString().padLeft(2, '0');

    final String month = value.month.toString().padLeft(2, '0');

    return '$day-$month-${value.year}';
  }

  static String _formatDateForFileName(DateTime value) {
    final String day = value.day.toString().padLeft(2, '0');

    final String month = value.month.toString().padLeft(2, '0');

    return '${value.year}$month$day';
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

  static String _titleCase(String value) {
    final String normalized = value.trim().toLowerCase();

    if (normalized.isEmpty) {
      return 'Unknown';
    }

    return '${normalized[0].toUpperCase()}'
        '${normalized.substring(1)}';
  }
}

class AttendanceExportException implements Exception {
  const AttendanceExportException(this.message);

  final String message;

  @override
  String toString() {
    return message;
  }
}
