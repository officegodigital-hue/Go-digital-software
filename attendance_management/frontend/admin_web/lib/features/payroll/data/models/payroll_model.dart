class PayrollModel {

  final int id;
  final int payrollMonth;
  final int payrollYear;
  final int totalEmployees;
  final double gross;
  final double deductions;
  final double netPayable;
  final String status;


  PayrollModel({

    required this.id,
    required this.payrollMonth,
    required this.payrollYear,
    required this.totalEmployees,
    required this.gross,
    required this.deductions,
    required this.netPayable,
    required this.status,

  });



  factory PayrollModel.fromJson(
      Map<String,dynamic> json
      ){

    return PayrollModel(

      id: json['id'] ?? 0,

      payrollMonth:
      json['payroll_month'] ?? 0,

      payrollYear:
      json['payroll_year'] ?? 0,


      totalEmployees:
      json['total_employees'] ?? 0,


      gross:
      double.parse(
        (json['total_gross_earnings'] ?? 0)
            .toString(),
      ),


      deductions:
      double.parse(
        (json['total_deductions'] ?? 0)
            .toString(),
      ),


      netPayable:
      double.parse(
        (json['total_net_payable'] ?? 0)
            .toString(),
      ),


      status:
      json['status'] ?? "",

    );

  }

}