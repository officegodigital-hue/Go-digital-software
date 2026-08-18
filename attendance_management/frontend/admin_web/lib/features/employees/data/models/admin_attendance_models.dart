class AdminAttendancePage {
  final List<AdminAttendanceRecord> records;
  final Map<String, dynamic>? pagination;
  final Map<String, dynamic>? summary;

  AdminAttendancePage({
    required this.records,
    this.pagination,
    this.summary,
  });


  factory AdminAttendancePage.fromJson(
      Map<String, dynamic> json) {

    final List<dynamic> rawRecords =
        json['records'] ??
        json['attendance_records'] ??
        json['attendanceRecords'] ??
        [];


    return AdminAttendancePage(
      records: rawRecords
          .map(
            (e) => AdminAttendanceRecord.fromJson(
              Map<String,dynamic>.from(e),
            ),
          )
          .toList(),

      pagination:
          json['pagination'],

      summary:
          json['summary'],
    );
  }
}



class AdminAttendanceRecord {

  final int? id;
  final String employeeName;
  final String status;
  final String date;


  AdminAttendanceRecord({
    this.id,
    required this.employeeName,
    required this.status,
    required this.date,
  });



  factory AdminAttendanceRecord.fromJson(
      Map<String,dynamic> json) {

    return AdminAttendanceRecord(

      id: json['id'],

      employeeName:
          json['employee_name'] ??
          json['employeeName'] ??
          '',

      status:
          json['status'] ??
          'Unknown',

      date:
          json['date'] ??
          '',
    );
  }
}