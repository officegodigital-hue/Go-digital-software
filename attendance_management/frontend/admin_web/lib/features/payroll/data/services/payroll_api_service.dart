import 'dart:convert';
import 'package:http/http.dart' as http;


class PayrollApiService {


  static const String baseUrl =
      "http://localhost:3000/api/v1/admin/payroll";



  Map<String,String> _headers(String token){

    return {

      "Authorization":
      "Bearer $token",

      "Content-Type":
      "application/json",

    };

  }





  // ================================
  // GET PAYROLL RUNS
  // ================================

  Future<Map<String,dynamic>> getPayrollRuns(
      String token
      ) async {


    final response =
    await http.get(

      Uri.parse(
        "$baseUrl/runs",
      ),

      headers:
      _headers(token),

    );


    return _handleResponse(
        response,
        "Payroll runs loading failed"
    );

  }





  // ================================
  // GENERATE PAYROLL
  // ================================

  Future<Map<String,dynamic>> generatePayroll(

      String token,

      int month,

      int year,

      ) async {



    final response =
    await http.post(

      Uri.parse(
        "$baseUrl/generate",
      ),

      headers:
      _headers(token),


      body:

      jsonEncode({

        "payroll_month":
        month,

        "payroll_year":
        year,

      }),

    );



    return _handleResponse(
        response,
        "Payroll generation failed"
    );


  }







  // ================================
  // PAYROLL DETAILS
  // ================================


  Future<Map<String,dynamic>> getPayrollDetails(

      String token,

      int id,

      ) async {


    final response =
    await http.get(

      Uri.parse(
          "$baseUrl/runs/$id"
      ),

      headers:
      _headers(token),

    );



    return _handleResponse(

        response,

        "Payroll details loading failed"

    );


  }







  // ================================
  // EMPLOYEE PAYSLIP
  // ================================


  Future<Map<String,dynamic>> getPayslip(

      String token,

      int employeeId,

      ) async {


    final response =
    await http.get(


      Uri.parse(

        "$baseUrl/payslip/$employeeId"

      ),


      headers:
      _headers(token),


    );



    return _handleResponse(

        response,

        "Payslip loading failed"

    );


  }








  // ================================
  // DELETE PAYROLL
  // ================================


  Future<Map<String,dynamic>> deletePayroll(

      String token,

      int id,

      ) async {


    final response =
    await http.delete(


      Uri.parse(

        "$baseUrl/runs/$id"

      ),


      headers:
      _headers(token),


    );



    return _handleResponse(

        response,

        "Payroll delete failed"

    );


  }








  // ================================
  // RESPONSE HANDLER
  // ================================


  Map<String,dynamic> _handleResponse(

      http.Response response,

      String errorMessage,

      ){



    if(response.body.isNotEmpty){


      final data =
      jsonDecode(response.body);



      if(response.statusCode >=200 &&
          response.statusCode <300){


        return data;

      }



      throw Exception(

        data["message"] ??
            errorMessage,

      );


    }



    throw Exception(errorMessage);


  }



}