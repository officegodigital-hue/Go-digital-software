import 'package:flutter/material.dart';

import '../../data/models/payslip_history_model.dart';



class EmployeePayslipHistoryScreen extends StatefulWidget {


  final String employeeName;


  const EmployeePayslipHistoryScreen({

    super.key,

    required this.employeeName,

  });



  @override
  State<EmployeePayslipHistoryScreen> createState()
      => _EmployeePayslipHistoryScreenState();

}




class _EmployeePayslipHistoryScreenState
    extends State<EmployeePayslipHistoryScreen>{



  final List<PayslipHistoryModel> history = [



    PayslipHistoryModel(

      id:1,

      employeeId:1,

      employeeName:"Krishnaraj B",

      employeeCode:"90046034",

      department:"Sales",

      designation:"BDM",

      month:"February",

      year:"2026",

      basicSalary:20000,

      hra:6552,

      allowance:8448,

      deduction:0,

      netSalary:35000,

      isSent:true,

    ),




    PayslipHistoryModel(

      id:2,

      employeeId:1,

      employeeName:"Krishnaraj B",

      employeeCode:"90046034",

      department:"Sales",

      designation:"BDM",

      month:"March",

      year:"2026",

      basicSalary:20000,

      hra:6552,

      allowance:8448,

      deduction:0,

      netSalary:35000,

      isSent:true,

    ),




    PayslipHistoryModel(

      id:3,

      employeeId:1,

      employeeName:"Krishnaraj B",

      employeeCode:"90046034",

      department:"Sales",

      designation:"BDM",

      month:"August",

      year:"2026",

      basicSalary:20000,

      hra:6552,

      allowance:8448,

      deduction:0,

      netSalary:35000,

      isSent:false,

    ),


  ];





  @override
  Widget build(BuildContext context){


    return Scaffold(


      backgroundColor:
      const Color(0xffF5F7FB),



      appBar: AppBar(

        backgroundColor:
        const Color(0xff00263D),


        title:Text(

          "${widget.employeeName} Payslip History",

        ),

      ),





      body:ListView.builder(


        padding:
        const EdgeInsets.all(20),


        itemCount:
        history.length,


        itemBuilder:(context,index){



          final item = history[index];



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

                BoxShadow(

                  color:Colors.black12,

                  blurRadius:8,

                )

              ]

            ),




            child:Row(


              children:[



                CircleAvatar(


                  radius:25,


                  backgroundColor:
                  const Color(0xff00263D),



                  child:Text(

                    item.employeeName
                        .substring(0,1)
                        .toUpperCase(),


                    style:
                    const TextStyle(

                      color:Colors.white,

                      fontSize:20,

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

                        "${item.month} ${item.year}",


                        style:
                        const TextStyle(

                          fontSize:20,

                          fontWeight:
                          FontWeight.bold,

                        ),

                      ),



                      const SizedBox(height:5),




                      Text(

                        "${item.employeeCode} • ${item.department}",

                      ),




                      Text(

                        item.designation,

                      ),





                      const SizedBox(height:8),





                      Text(

                        "₹${item.netSalary}",


                        style:
                        const TextStyle(

                          fontSize:18,

                          fontWeight:
                          FontWeight.bold,

                        ),

                      ),





                      const SizedBox(height:8),





                      Container(


                        padding:
                        const EdgeInsets.symmetric(

                          horizontal:12,

                          vertical:5,

                        ),



                        decoration:
                        BoxDecoration(


                          color:item.isSent

                              ? Colors.green.shade100

                              : Colors.orange.shade100,


                          borderRadius:
                          BorderRadius.circular(20),

                        ),




                        child:Text(

                          item.isSent

                              ? "Sent"

                              : "Not Sent",


                          style:TextStyle(

                            color:item.isSent

                                ? Colors.green

                                : Colors.orange,

                          ),

                        ),


                      )



                    ],

                  ),

                ),





                Column(


                  children:[



                    IconButton(

                      icon:
                      const Icon(

                        Icons.visibility,

                        color:Colors.blue,

                      ),


                      onPressed:(){



                      },

                    ),





                    IconButton(

                      icon:
                      const Icon(

                        Icons.download,

                        color:Colors.green,

                      ),


                      onPressed:(){



                      },

                    ),



                  ],

                )



              ],

            ),

          );



        },

      ),


    );


  }



}