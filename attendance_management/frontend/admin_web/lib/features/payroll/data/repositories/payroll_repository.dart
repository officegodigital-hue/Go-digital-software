import '../services/payroll_api_service.dart';


class PayrollRepository {


  final PayrollApiService apiService;



  PayrollRepository(
      this.apiService
      );





  // =====================================
  // GET PAYROLL RUNS
  // =====================================

  Future<Map<String,dynamic>> getPayrollRuns(

      String token

      ) async {


    return await apiService.getPayrollRuns(
        token
    );


  }







  // =====================================
  // GENERATE PAYROLL
  // =====================================

  Future<Map<String,dynamic>> generatePayroll(

      String token,

      int month,

      int year

      ) async {


    return await apiService.generatePayroll(

        token,

        month,

        year

    );


  }








  // =====================================
  // GET PAYROLL DETAILS
  // =====================================

  Future<Map<String,dynamic>> getPayrollDetails(

      String token,

      int payrollId

      ) async {


    return await apiService.getPayrollDetails(

        token,

        payrollId

    );


  }








  // =====================================
  // GET EMPLOYEE PAYSLIP
  // =====================================

  Future<Map<String,dynamic>> getPayslip(

      String token,

      int employeeId

      ) async {


    return await apiService.getPayslip(

        token,

        employeeId

    );


  }








  // =====================================
  // DELETE PAYROLL
  // =====================================

  Future<Map<String,dynamic>> deletePayroll(

      String token,

      int payrollId

      ) async {


    return await apiService.deletePayroll(

        token,

        payrollId

    );


  }



}