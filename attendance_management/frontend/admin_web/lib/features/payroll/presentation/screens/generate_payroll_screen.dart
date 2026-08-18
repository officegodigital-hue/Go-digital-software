import 'package:flutter/material.dart';

import '../../data/repositories/payroll_repository.dart';
import '../../data/services/payroll_api_service.dart';



class GeneratePayrollScreen extends StatefulWidget {


  final String token;


  const GeneratePayrollScreen({

    super.key,

    required this.token,

  });



  @override
  State<GeneratePayrollScreen> createState() =>
      _GeneratePayrollScreenState();

}






class _GeneratePayrollScreenState
    extends State<GeneratePayrollScreen>{



  late PayrollRepository repository;



  Map<String,dynamic>? selectedEmployee;



  final List<Map<String,dynamic>> employees = [


    {
      "id":1,
      "name":"Krishnaraj B",
      "code":"90046034",
      "department":"Sales",
      "salary":35000
    },


    {
      "id":2,
      "name":"Ravi Kumar",
      "code":"90046035",
      "department":"HR",
      "salary":42000
    },


  ];





  final TextEditingController basicController =
  TextEditingController();


  final TextEditingController hraController =
  TextEditingController();


  final TextEditingController allowanceController =
  TextEditingController();


  final TextEditingController pfController =
  TextEditingController();


  final TextEditingController taxController =
  TextEditingController();





  final int month =
      DateTime.now().month;


  final int year =
      DateTime.now().year;







  @override
  void initState(){

    super.initState();


    repository =
        PayrollRepository(

          PayrollApiService(),

        );

  }






  @override
  void dispose(){


    basicController.dispose();

    hraController.dispose();

    allowanceController.dispose();

    pfController.dispose();

    taxController.dispose();


    super.dispose();


  }









  double get netSalary{


    final double basic =
        double.tryParse(
            basicController.text
        ) ?? 0;



    final double hra =
        double.tryParse(
            hraController.text
        ) ?? 0;



    final double allowance =
        double.tryParse(
            allowanceController.text
        ) ?? 0;



    final double pf =
        double.tryParse(
            pfController.text
        ) ?? 0;



    final double tax =
        double.tryParse(
            taxController.text
        ) ?? 0;




    return
      basic +
          hra +
          allowance -
          pf -
          tax;


  }









  void selectEmployee(
      Map<String,dynamic>? employee
      ){


    setState((){


      selectedEmployee =
          employee;



      if(employee != null){


        basicController.text =
            employee["salary"].toString();


      }



    });


  }










  Future<void> generate() async{



    if(selectedEmployee == null){


      showMessage(
          "Please select employee"
      );


      return;


    }






    try{


      final result =
      await repository.generatePayroll(


          widget.token,


          month,


          year



      );





      if(result["success"] == true){



        if(!mounted)return;



        showMessage(
            "Payslip generated successfully"
        );



        Navigator.pop(context);



      }



    }

    catch(error){


      if(!mounted)return;



      showMessage(
          error.toString()
      );


    }



  }









  void showMessage(String message){



    ScaffoldMessenger.of(context)
        .showSnackBar(

      SnackBar(

        content:
        Text(message),

      ),

    );


  }










  @override
  Widget build(BuildContext context){



    return Scaffold(



      backgroundColor:
      const Color(0xffF5F7FB),




      appBar:

      AppBar(


        backgroundColor:
        const Color(0xff00263D),


        title:

        const Text(

          "Generate New Payslip",

          style:

          TextStyle(

              color:Colors.white

          ),

        ),

      ),






      body:

      SingleChildScrollView(


        padding:
        const EdgeInsets.all(20),



        child:

        Column(


          children:[





            cardSection(

                "Employee Details",


                Column(

                  children:[



                    DropdownButtonFormField<Map<String,dynamic>>(



                      decoration:
                      inputDecoration(
                          "Select Employee"
                      ),



                      initialValue:
                      selectedEmployee,




                      items:

                      employees.map((employee){



                        return DropdownMenuItem<

                            Map<String,dynamic>>(


                          value:
                          employee,


                          child:

                          Text(

                              employee["name"]

                          ),


                        );


                      }).toList(),




                      onChanged:
                      selectEmployee,


                    ),





                    const SizedBox(
                        height:15
                    ),





                    Text(

                      "Month : $month/$year",

                      style:

                      const TextStyle(

                          fontWeight:
                          FontWeight.bold

                      ),

                    )



                  ],

                )

            ),







            cardSection(

                "Earnings & Allowances",


                Column(

                  children:[



                    field(
                        "Basic Salary",
                        basicController
                    ),



                    field(
                        "HRA",
                        hraController
                    ),



                    field(
                        "Other Allowance",
                        allowanceController
                    ),



                  ],

                )

            ),







            cardSection(

                "Deductions",


                Column(

                  children:[


                    field(
                        "PF",
                        pfController
                    ),



                    field(
                        "Income Tax",
                        taxController
                    ),



                  ],

                )

            ),









            Container(


              padding:
              const EdgeInsets.all(20),



              decoration:
              BoxDecoration(


                color:
                Colors.white,


                borderRadius:
                BorderRadius.circular(16),


              ),




              child:

              Column(

                children:[



                  const Text(

                    "Net Payable",

                    style:

                    TextStyle(

                        fontSize:18,

                        fontWeight:
                        FontWeight.bold

                    ),

                  ),




                  const SizedBox(
                      height:10
                  ),




                  Text(

                    "₹ ${netSalary.toStringAsFixed(0)}",


                    style:

                    const TextStyle(

                        fontSize:30,

                        fontWeight:
                        FontWeight.bold,

                        color:
                        Colors.blue

                    ),


                  )



                ],


              ),



            ),







            const SizedBox(
                height:25
            ),







            SizedBox(

              width:
              double.infinity,


              height:
              55,



              child:

              ElevatedButton.icon(



                icon:

                const Icon(
                    Icons.save
                ),



                label:

                const Text(
                    "Generate Payslip"
                ),




                style:

                ElevatedButton.styleFrom(


                  backgroundColor:
                  const Color(0xff243BFF),


                  foregroundColor:
                  Colors.white,



                  shape:

                  RoundedRectangleBorder(

                    borderRadius:
                    BorderRadius.circular(12),

                  ),


                ),



                onPressed:
                generate,


              ),

            )




          ],

        ),


      ),


    );



  }









  Widget cardSection(

      String title,

      Widget child

      ){



    return Container(


      margin:

      const EdgeInsets.only(
          bottom:18
      ),


      padding:

      const EdgeInsets.all(18),


      decoration:

      BoxDecoration(


          color:
          Colors.white,


          borderRadius:
          BorderRadius.circular(16)

      ),



      child:

      Column(

        crossAxisAlignment:
        CrossAxisAlignment.start,


        children:[



          Text(

            title,


            style:

            const TextStyle(

                fontSize:18,

                fontWeight:
                FontWeight.bold

            ),


          ),




          const SizedBox(
              height:15
          ),




          child



        ],


      ),


    );



  }









  Widget field(

      String label,

      TextEditingController controller

      ){



    return Padding(


      padding:

      const EdgeInsets.only(
          bottom:12
      ),



      child:

      TextField(



        controller:
        controller,



        keyboardType:
        TextInputType.number,



        onChanged:(value){


          setState((){});


        },



        decoration:

        inputDecoration(label),



      ),



    );


  }








  InputDecoration inputDecoration(
      String label
      ){


    return InputDecoration(


      labelText:
      label,


      border:

      OutlineInputBorder(

        borderRadius:
        BorderRadius.circular(10),

      ),


    );


  }



}