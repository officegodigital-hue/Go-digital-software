class PayslipHistoryModel {

  final int id;

  final int employeeId;

  final String employeeName;

  final String employeeCode;

  final String department;

  final String designation;


  final String month;

  final String year;


  final double basicSalary;

  final double hra;

  final double allowance;

  final double deduction;


  final double netSalary;


  final bool isSent;



  PayslipHistoryModel({

    required this.id,

    required this.employeeId,

    required this.employeeName,

    required this.employeeCode,

    required this.department,

    required this.designation,


    required this.month,

    required this.year,


    required this.basicSalary,

    required this.hra,

    required this.allowance,

    required this.deduction,


    required this.netSalary,


    required this.isSent,

  });



  factory PayslipHistoryModel.fromJson(
      Map<String, dynamic> json) {

    return PayslipHistoryModel(

      id: json['id'] ?? 0,


      employeeId:
      json['employee_id'] ?? 0,


      employeeName:
      json['employee_name'] ?? '',


      employeeCode:
      json['employee_code'] ?? '',


      department:
      json['department'] ?? '',


      designation:
      json['designation'] ?? '',



      month:
      json['month'] ?? '',


      year:
      json['year'] ?? '',



      basicSalary:
      double.tryParse(
          json['basic_salary']
              .toString()
      ) ?? 0,


      hra:
      double.tryParse(
          json['hra']
              .toString()
      ) ?? 0,


      allowance:
      double.tryParse(
          json['allowance']
              .toString()
      ) ?? 0,



      deduction:
      double.tryParse(
          json['deduction']
              .toString()
      ) ?? 0,



      netSalary:
      double.tryParse(
          json['net_salary']
              .toString()
      ) ?? 0,



      isSent:
      json['is_sent'] ?? false,

    );

  }



  Map<String,dynamic> toJson(){

    return {

      "id": id,

      "employee_id": employeeId,

      "employee_name": employeeName,

      "employee_code": employeeCode,

      "department": department,

      "designation": designation,


      "month": month,

      "year": year,


      "basic_salary": basicSalary,

      "hra": hra,

      "allowance": allowance,

      "deduction": deduction,


      "net_salary": netSalary,


      "is_sent": isSent,

    };

  }



}