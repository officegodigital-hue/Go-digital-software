import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_saver/file_saver.dart';

import '../../data/models/payslip_model.dart';
import '../../data/services/payslip/payslip_pdf_service.dart';



class PayslipPreviewScreen extends StatelessWidget {


  final PayslipModel employee;



  const PayslipPreviewScreen({

    super.key,

    required this.employee,

  });





Future<void> downloadPayslip() async {


  Uint8List pdf =
      await PayslipPdfService.generatePdf(employee);



  await FileSaver.instance.saveFile(

    name:
    "${employee.employeeName}_${employee.month}_${employee.year}_Payslip",


    bytes:pdf,


    mimeType:
    MimeType.pdf,

  );

}





@override
Widget build(BuildContext context){


return Scaffold(


backgroundColor:
Colors.white,



appBar:AppBar(


backgroundColor:
const Color(0xff00263D),


title:
const Text(
"Payslip Preview"
),



actions:[


IconButton(

icon:
const Icon(Icons.download),


onPressed:
downloadPayslip,

)

],


),





body:

SingleChildScrollView(


padding:
const EdgeInsets.all(20),



child:

Center(


child:

Container(


width:
750,


padding:
const EdgeInsets.all(15),



decoration:

BoxDecoration(

border:

Border.all(

color:
Colors.black,

)

),




child:Column(


children:[



Align(

alignment:
Alignment.centerLeft,


child:

Image.asset(

"assets/images/godigital.png",

height:70,

),


),




const SizedBox(height:30),





Container(


width:
double.infinity,


color:
const Color(0xff416995),


padding:
const EdgeInsets.all(10),



child:

Text(


"Salary Slip For The Month - ${employee.month} ${employee.year}",


textAlign:
TextAlign.center,



style:

const TextStyle(

color:
Colors.white,

fontWeight:
FontWeight.bold,

),

),


),




employeeDetails(),



bankDetails(),



salaryDetails(),




const SizedBox(height:20),




Row(


mainAxisAlignment:
MainAxisAlignment.spaceBetween,



children:[



const Expanded(


child:

Text(

"This is a system generated Pay slip and hence company signature is not required",

style:

TextStyle(

fontSize:9,

fontStyle:
FontStyle.italic,

),

),

),




Image.asset(

"assets/images/roundseal.PNG",

height:70,

)



],



)



],



),


),


),


),


);



}








Widget employeeDetails(){


return buildTable([


[

"Employee Name",

employee.employeeName,

"Department",

employee.department

],


[

"Employee Code",

employee.employeeCode,

"Designation",

employee.designation

],



[

"D.O.J",

employee.doj,

"Grade",

employee.grade

],



[

"Location",

employee.location,

"Monthly CTC",

employee.netPayable.toStringAsFixed(0)

],



]);

}



Widget bankDetails(){


return buildTable([


[

"Bank A/C Number",

employee.bankAccount,

"Aadhar No",

employee.aadhar

],



[

"PAN NO",

employee.pan,

"Net Days Payable",

"28"

],



[

"PF No",

"-",

"LOP Days",

"0"

],



[

"UAN NO",

employee.uan,

"ESIC",

"0"

],



]);

}



Widget salaryDetails(){


return Column(

children:[



buildTable([


[

"Earnings",

"Amt(INR)",

"Deductions",

"Amt(INR)"

]

],header:true),




buildTable([


[

"Basic Salary",

employee.basicSalary.toStringAsFixed(0),

"PF Employee Contribution",

employee.pf.toStringAsFixed(0)

],



[

"HRA",

employee.hra.toStringAsFixed(0),

"ESIC",

employee.esic.toStringAsFixed(0)

],



[

"Attire Allowance",

employee.attireAllowance.toStringAsFixed(0),

"Professional Tax",

employee.professionalTax.toStringAsFixed(0)

],



[

"Other Allowance",

employee.otherAllowance.toStringAsFixed(0),

"Income Tax",

employee.incomeTax.toStringAsFixed(0)

],



[

"OT Allowance",

employee.otAllowance.toStringAsFixed(0),

"",

""

],



[

"Bonus",

employee.bonus.toStringAsFixed(0),

"",

""

],



]),




totalRow(

"Total Earnings(A)",

employee.grossEarnings.toStringAsFixed(0),

"Total Deduction(B)",

employee.totalDeduction.toStringAsFixed(0),

),




totalRow(

"",

"",

"Net Payable(A-B)",

employee.netPayable.toStringAsFixed(0),

),



],


);



}







Widget buildTable(

List<List<dynamic>> rows,

{

bool header=false

}

){


return Table(


border:

TableBorder.all(

color:
Colors.black,

width:
0.5,

),



children:

rows.map((row){


return TableRow(


decoration:

header

?

const BoxDecoration(

color:
Color(0xffB7D0EA)

)

:

null,



children:

row.map((cell){



return Padding(

padding:
const EdgeInsets.all(5),


child:

Text(

cell.toString(),

style:

const TextStyle(

fontSize:10,

),

),

);



}).toList(),



);


}).toList(),



);



}






Widget totalRow(

String a,

String b,

String c,

String d

){


return buildTable([


[

a,

b,

c,

d

]


]);



}



}