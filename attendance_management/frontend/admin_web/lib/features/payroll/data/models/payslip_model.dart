class PayslipModel {

  final int id;


  // Employee
  String employeeName;
  String employeeCode;
  String department;
  String designation;

  String doj;
  String grade;
  String location;


  // Bank
  String bankAccount;
  String aadhar;
  String pan;
  String uan;


  // Earnings
  double basicSalary;
  double hra;
  double attireAllowance;
  double otherAllowance;
  double otAllowance;
  double bonus;


  // Deduction
  double pf;
  double esic;
  double professionalTax;
  double incomeTax;


  // Period
  String month;
  String year;


  bool sent;



  PayslipModel({

    required this.id,

    required this.employeeName,
    required this.employeeCode,
    required this.department,
    required this.designation,

    required this.doj,
    required this.grade,
    required this.location,

    required this.bankAccount,
    required this.aadhar,
    required this.pan,
    required this.uan,


    required this.basicSalary,
    required this.hra,
    required this.attireAllowance,
    required this.otherAllowance,
    required this.otAllowance,
    required this.bonus,


    required this.pf,
    required this.esic,
    required this.professionalTax,
    required this.incomeTax,


    required this.month,
    required this.year,


    required this.sent,

  });



  double get grossEarnings {

    return

      basicSalary +
      hra +
      attireAllowance +
      otherAllowance +
      otAllowance +
      bonus;

  }



  double get totalDeduction {

    return

      pf +
      esic +
      professionalTax +
      incomeTax;

  }



  double get netPayable {

    return grossEarnings - totalDeduction;

  }


}