import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../data/services/payroll_api_service.dart';


class PayrollEmployeeDetailsScreen extends StatefulWidget {

  final int payrollId;
  final String token;


  const PayrollEmployeeDetailsScreen({
    super.key,
    required this.payrollId,
    required this.token,
  });


  @override
  State<PayrollEmployeeDetailsScreen> createState() =>
      _PayrollEmployeeDetailsScreenState();

}



class _PayrollEmployeeDetailsScreenState
    extends State<PayrollEmployeeDetailsScreen> {


  final PayrollApiService api =
      PayrollApiService();


  bool loading = false;


  Map<String,dynamic>? payslip;



  @override
  void initState(){

    super.initState();

    loadPayslip();

  }





  Future<void> loadPayslip() async {


    try{


      setState(() {

        loading=true;

      });



      final response =
      await api.getPayslip(
          widget.token,
          widget.payrollId
      );



      setState(() {


        payslip =
        response['data'] ?? {};


      });



    }
    catch(e){


      ScaffoldMessenger.of(context)
          .showSnackBar(

        SnackBar(
            content:
            Text(
                e.toString()
            )
        ),

      );


    }
    finally{


      if(mounted){

        setState(() {

          loading=false;

        });

      }

    }


  }







  Future<void> downloadPdf() async {


    final pdf =
    pw.Document();



    pdf.addPage(

      pw.Page(

        build:(context){

          return pw.Column(

            crossAxisAlignment:
            pw.CrossAxisAlignment.start,


            children:[


              pw.Text(
                "Salary Slip",
                style:
                pw.TextStyle(
                    fontSize:20
                ),
              ),


              pw.SizedBox(height:20),


              pw.Text(
                "Employee Name : ${payslip?['employee_name'] ?? ''}",
              ),


              pw.Text(
                "Employee Code : ${payslip?['employee_code'] ?? ''}",
              ),


              pw.Text(
                "Department : ${payslip?['department'] ?? ''}",
              ),


              pw.Text(
                "Designation : ${payslip?['designation'] ?? ''}",
              ),


              pw.SizedBox(height:20),


              pw.Text(
                "Basic Salary : ₹${payslip?['basic_salary'] ?? 0}",
              ),


              pw.Text(
                "Allowance : ₹${payslip?['allowances'] ?? 0}",
              ),


              pw.Text(
                "Deduction : ₹${payslip?['deductions'] ?? 0}",
              ),


              pw.SizedBox(height:10),


              pw.Text(
                "Net Salary : ₹${payslip?['net_salary'] ?? 0}",
              ),



            ],

          );

        },

      ),

    );



    await Printing.layoutPdf(

      onLayout:(format)=>pdf.save(),

    );


  }








  Future<void> deletePayslip() async {


    final confirm =
    await showDialog<bool>(

        context:context,

        builder:(context){

          return AlertDialog(

            title:
            const Text(
                "Delete Payroll"
            ),


            content:
            const Text(
                "Are you sure?"
            ),


            actions:[


              TextButton(

                onPressed:(){

                  Navigator.pop(
                      context,
                      false
                  );

                },

                child:
                const Text(
                    "Cancel"
                ),

              ),



              ElevatedButton(

                onPressed:(){

                  Navigator.pop(
                      context,
                      true
                  );

                },

                child:
                const Text(
                    "Delete"
                ),

              )

            ],

          );

        }

    );



    if(confirm != true){

      return;

    }



    // connect your delete API here
    // when payroll id delete API required


    ScaffoldMessenger.of(context)
        .showSnackBar(

      const SnackBar(
          content:
          Text(
              "Delete API connected"
          )
      ),

    );


  }









  @override
  Widget build(BuildContext context){


    return Scaffold(


      appBar: AppBar(

        title:
        Text(
          "Payroll Payslip",
        ),

        backgroundColor:
        const Color(0xff00263D),

      ),



      body:


      loading


          ?


      const Center(

          child:
          CircularProgressIndicator()

      )



          :


      payslip == null


          ?


      const Center(

        child:
        Text(
            "No Payslip Found"
        ),

      )



          :


      SingleChildScrollView(


        padding:
        const EdgeInsets.all(20),


        child:


        Card(


          elevation:5,


          child:

          Padding(

            padding:
            const EdgeInsets.all(20),


            child:

            Column(

              crossAxisAlignment:
              CrossAxisAlignment.start,


              children:[



                Text(

                  payslip?['employee_name']
                      ??
                      "Employee",

                  style:
                  const TextStyle(

                    fontSize:22,

                    fontWeight:
                    FontWeight.bold,

                  ),

                ),



                const Divider(),



                Text(
                    "Employee Code : ${payslip?['employee_code'] ?? '-'}"
                ),


                Text(
                    "Department : ${payslip?['department'] ?? '-'}"
                ),


                Text(
                    "Designation : ${payslip?['designation'] ?? '-'}"
                ),



                const SizedBox(height:20),



                Text(
                    "Basic Salary : ₹${payslip?['basic_salary'] ?? 0}"
                ),


                Text(
                    "Allowance : ₹${payslip?['allowances'] ?? 0}"
                ),


                Text(
                    "Deduction : ₹${payslip?['deductions'] ?? 0}"
                ),



                const SizedBox(height:10),



                Text(

                  "Net Salary : ₹${payslip?['net_salary'] ?? 0}",


                  style:
                  const TextStyle(

                    fontSize:20,

                    fontWeight:
                    FontWeight.bold,

                  ),

                ),



                const SizedBox(height:25),



                Wrap(

                  spacing:10,


                  children:[



                    ElevatedButton.icon(

                      icon:
                      const Icon(
                          Icons.download
                      ),

                      label:
                      const Text(
                          "Download PDF"
                      ),


                      onPressed:
                      downloadPdf,

                    ),




                    ElevatedButton.icon(

                      icon:
                      const Icon(
                          Icons.edit
                      ),

                      label:
                      const Text(
                          "Edit"
                      ),


                      onPressed:(){},


                    ),




                    ElevatedButton.icon(

                      icon:
                      const Icon(
                          Icons.delete
                      ),

                      label:
                      const Text(
                          "Delete"
                      ),


                      onPressed:
                      deletePayslip,


                    ),



                  ],


                )


              ],


            ),

          ),


        ),


      ),


    );


  }


}