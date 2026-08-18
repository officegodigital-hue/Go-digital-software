import 'package:flutter/material.dart';
import '../../data/models/payslip_model.dart';

class EditPayslipScreen extends StatefulWidget {
  final PayslipModel payslip;

  const EditPayslipScreen({
    super.key,
    required this.payslip,
  });

  @override
  State<EditPayslipScreen> createState() =>
      _EditPayslipScreenState();
}


class _EditPayslipScreenState extends State<EditPayslipScreen> {


  late TextEditingController basicController;
  late TextEditingController hraController;
  late TextEditingController attireController;
  late TextEditingController otherAllowanceController;
  late TextEditingController bonusController;

  late TextEditingController pfController;
  late TextEditingController esicController;
  late TextEditingController professionalTaxController;
  late TextEditingController incomeTaxController;


  late String month;
  late String year;



  @override
  void initState() {
    super.initState();


    final p = widget.payslip;


    basicController =
        TextEditingController(text: p.basicSalary.toString());


    hraController =
        TextEditingController(text: p.hra.toString());


    attireController =
        TextEditingController(text: p.attireAllowance.toString());


    otherAllowanceController =
        TextEditingController(text: p.otherAllowance.toString());


    bonusController =
        TextEditingController(text: p.bonus.toString());



    pfController =
        TextEditingController(text: p.pf.toString());


    esicController =
        TextEditingController(text: p.esic.toString());


    professionalTaxController =
        TextEditingController(
            text: p.professionalTax.toString()
        );


    incomeTaxController =
        TextEditingController(
            text: p.incomeTax.toString()
        );



    month = p.month;
    year = p.year;

  }



  double value(String text){

    return double.tryParse(text) ?? 0;

  }



  double get gross {


    return

      value(basicController.text)

          +

      value(hraController.text)

          +

      value(attireController.text)

          +

      value(otherAllowanceController.text)

          +

      value(bonusController.text);

  }



  double get deduction {


    return

      value(pfController.text)

          +

      value(esicController.text)

          +

      value(professionalTaxController.text)

          +

      value(incomeTaxController.text);


  }



  double get net => gross - deduction;



  @override
  Widget build(BuildContext context) {


    return Scaffold(

      backgroundColor:
      const Color(0xffF5F7FB),


      appBar: AppBar(

        backgroundColor:
        const Color(0xff00263D),

        title:
        const Text(
            "Edit Payslip"
        ),

      ),



      body: SingleChildScrollView(

        padding:
        const EdgeInsets.all(20),


        child: Column(

          crossAxisAlignment:
          CrossAxisAlignment.start,


          children: [



            Text(

              widget.payslip.employeeName,

              style:
              const TextStyle(

                fontSize:28,

                fontWeight:
                FontWeight.bold,

              ),

            ),



            const SizedBox(height:20),




            dropdown(

              "Month",

              month,

              [

                "January",
                "February",
                "March",
                "April",
                "May",
                "June",
                "July",
                "August",
                "September",
                "October",
                "November",
                "December"

              ],

                  (v){

                setState((){

                  month=v!;

                });

              },


            ),



            const SizedBox(height:15),



            dropdown(

              "Year",

              year,

              [

                "2025",
                "2026",
                "2027"

              ],

                  (v){

                setState((){

                  year=v!;

                });

              },


            ),



            const SizedBox(height:20),



            field(
                "Basic Salary",
                basicController
            ),


            field(
                "HRA",
                hraController
            ),


            field(
                "Attire Allowance",
                attireController
            ),


            field(
                "Other Allowance",
                otherAllowanceController
            ),


            field(
                "Bonus",
                bonusController
            ),



            const Divider(),



            field(
                "PF",
                pfController
            ),


            field(
                "ESIC",
                esicController
            ),


            field(
                "Professional Tax",
                professionalTaxController
            ),


            field(
                "Income Tax",
                incomeTaxController
            ),




            const SizedBox(height:20),



            Container(

              padding:
              const EdgeInsets.all(20),


              decoration:
              BoxDecoration(

                color:Colors.white,

                borderRadius:
                BorderRadius.circular(15),

              ),


              child:Column(

                children:[


                  amountRow(
                      "Gross Salary",
                      gross
                  ),


                  amountRow(
                      "Total Deduction",
                      deduction
                  ),


                  amountRow(
                      "Net Payable",
                      net
                  ),


                ],

              ),


            ),



            const SizedBox(height:30),



            SizedBox(

              width:
              double.infinity,


              child:
              ElevatedButton.icon(

                icon:
                const Icon(Icons.save),


                label:
                const Text(
                    "SAVE PAYSLIP"
                ),


                onPressed:(){


                  setState((){


                    widget.payslip.basicSalary =
                        value(basicController.text);


                    widget.payslip.hra =
                        value(hraController.text);


                    widget.payslip.attireAllowance =
                        value(attireController.text);


                    widget.payslip.otherAllowance =
                        value(otherAllowanceController.text);


                    widget.payslip.bonus =
                        value(bonusController.text);



                    widget.payslip.pf =
                        value(pfController.text);


                    widget.payslip.esic =
                        value(esicController.text);


                    widget.payslip.professionalTax =
                        value(professionalTaxController.text);


                    widget.payslip.incomeTax =
                        value(incomeTaxController.text);



                    widget.payslip.month =
                        month;


                    widget.payslip.year =
                        year;


                  });



                  Navigator.pop(context);


                },


              ),

            )



          ],


        ),

      ),


    );


  }






  Widget field(
      String title,
      TextEditingController controller
      ){


    return Padding(

      padding:
      const EdgeInsets.only(bottom:15),


      child:
      TextField(

        controller:controller,

        keyboardType:
        TextInputType.number,


        decoration:
        InputDecoration(

          labelText:title,

          border:
          const OutlineInputBorder(),

        ),


        onChanged:(v){

          setState((){});

        },


      ),

    );


  }






  Widget dropdown(

      String title,

      String value,

      List<String> items,

      Function(String?) change

      ){


    return DropdownButtonFormField<String>(


      initialValue:value,


      decoration:
      InputDecoration(

        labelText:title,

        border:
        const OutlineInputBorder(),

      ),



      items:
      items.map(

              (e)=>

              DropdownMenuItem(

                value:e,

                child:
                Text(e),

              )

      ).toList(),



      onChanged:
      change,


    );


  }






  Widget amountRow(
      String title,
      double amount
      ){


    return Padding(

      padding:
      const EdgeInsets.only(bottom:10),


      child:
      Row(

        mainAxisAlignment:
        MainAxisAlignment.spaceBetween,


        children:[


          Text(

            title,

            style:
            const TextStyle(

              fontSize:18,

              fontWeight:
              FontWeight.bold,

            ),

          ),



          Text(

            "₹${amount.toStringAsFixed(0)}",

            style:
            const TextStyle(

              fontSize:18,

              fontWeight:
              FontWeight.bold,

            ),

          )


        ],

      ),

    );


  }



}