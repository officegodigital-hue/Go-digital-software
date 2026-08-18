import 'package:flutter/material.dart';

import '../../data/models/payroll_employee_model.dart';



class PayrollEmployeeTile extends StatelessWidget {


  final PayrollEmployeeModel employee;


  final VoidCallback onView;

  final VoidCallback onEdit;

  final VoidCallback onDownload;

  final VoidCallback onSend;

  final VoidCallback onHistory;




  const PayrollEmployeeTile({


    super.key,


    required this.employee,


    required this.onView,


    required this.onEdit,


    required this.onDownload,


    required this.onSend,


    required this.onHistory,


  });





  @override
  Widget build(BuildContext context) {


    return Container(


      margin:
      const EdgeInsets.only(bottom:15),


      padding:
      const EdgeInsets.all(18),



      decoration:BoxDecoration(


        color:Colors.white,


        borderRadius:
        BorderRadius.circular(18),



        boxShadow:[


          const BoxShadow(

            color:Colors.black12,

            blurRadius:8,

          )

        ]

      ),





      child:Row(


        children:[



          CircleAvatar(


            radius:28,


            backgroundColor:
            const Color(0xff00263D),



            child:Text(


              employee.name.isNotEmpty

                  ? employee.name[0].toUpperCase()

                  : "E",



              style:

              const TextStyle(

                color:Colors.white,

                fontSize:22,

                fontWeight:FontWeight.bold,

              ),


            ),



          ),





          const SizedBox(width:15),





          Expanded(


            child:Column(


              crossAxisAlignment:
              CrossAxisAlignment.start,



              children:[



                Text(


                  employee.name,


                  style:

                  const TextStyle(

                    fontSize:20,

                    fontWeight:FontWeight.bold,

                  ),



                ),





                const SizedBox(height:5),





                Text(


                  "${employee.code} • ${employee.department}",


                  style:

                  const TextStyle(

                    color:Colors.grey,

                  ),


                ),





                Text(

                  employee.designation,

                ),





                const SizedBox(height:8),





                Row(


                  children:[



                    Text(


                      "₹${employee.salary.toStringAsFixed(0)}",



                      style:

                      const TextStyle(

                        fontSize:18,

                        fontWeight:FontWeight.bold,

                      ),


                    ),





                    const SizedBox(width:15),





                    Container(


                      padding:

                      const EdgeInsets.symmetric(

                        horizontal:10,

                        vertical:5,

                      ),



                      decoration:

                      BoxDecoration(


                        color:


                        employee.sent

                            ? Colors.green.shade100

                            : Colors.orange.shade100,



                        borderRadius:

                        BorderRadius.circular(20),


                      ),





                      child:Text(


                        employee.sent

                            ? "Sent"

                            : "Not Sent",



                        style:

                        TextStyle(


                          color:


                          employee.sent

                              ? Colors.green

                              : Colors.orange,



                        ),



                      ),



                    )



                  ],



                )



              ]


            )


          ),






          Column(


            children:[



              actionButton(

                Icons.visibility,

                Colors.blue,

                "View Payslip",

                onView,

              ),





              actionButton(

                Icons.history,

                Colors.blueGrey,

                "Payslip History",

                onHistory,

              ),





              actionButton(

                Icons.edit,

                Colors.orange,

                "Edit Payslip",

                onEdit,

              ),





              actionButton(

                Icons.download,

                Colors.green,

                "Download",

                onDownload,

              ),





              actionButton(

                Icons.send,

                Colors.purple,

                "Send Payslip",

                onSend,

              ),



            ],


          )




        ],



      ),



    );



  }






  Widget actionButton(

      IconData icon,

      Color color,

      String tooltip,

      VoidCallback action,

      ){



    return IconButton(


      tooltip:tooltip,


      icon:


      Icon(

        icon,

        color:color,

      ),



      onPressed:action,


    );

  }




}