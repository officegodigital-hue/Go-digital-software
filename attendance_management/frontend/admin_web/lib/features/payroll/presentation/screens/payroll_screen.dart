import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:file_saver/file_saver.dart';



class PayslipScreen extends StatefulWidget {


  final Map<String,dynamic> payslip;


  const PayslipScreen({

    super.key,

    required this.payslip,

  });



  @override
  State<PayslipScreen> createState()
      => _PayslipScreenState();


}






class _PayslipScreenState
extends State<PayslipScreen>{



late Map<String,dynamic> data;





@override
void initState(){

super.initState();


data =
Map<String,dynamic>.from(
widget.payslip
);


}








Future<void> downloadPdf() async{


try{


final pdf =
pw.Document();





pdf.addPage(



pw.Page(


pageFormat:
PdfPageFormat.a4,



build:(context){



return pw.Column(



crossAxisAlignment:
pw.CrossAxisAlignment.start,



children:[



pw.Container(


width:
double.infinity,


padding:
const pw.EdgeInsets.all(20),



color:
PdfColors.blue900,



child:

pw.Text(

"GO DIGITAL\nSALARY SLIP",

style:

pw.TextStyle(

color:
PdfColors.white,

fontSize:
24,

fontWeight:
pw.FontWeight.bold

)

)

),




pw.SizedBox(
height:20
),




pdfText(
"Employee Name",
data["employee_name"] ?? "-"
),



pdfText(
"Employee Code",
data["employee_code"] ?? "-"
),



pdfText(
"Department",
data["department"] ?? "-"
),



pdfText(
"Designation",
data["designation"] ?? "-"
),





pw.SizedBox(
height:25
),






pw.TableHelper.fromTextArray(


headers:[

"Description",

"Amount"

],



data:[


[

"Basic Salary",

"₹ ${data["basic_salary"] ?? 0}"

],



[

"HRA",

"₹ ${data["hra"] ?? 0}"

],



[

"Allowance",

"₹ ${data["allowance"] ?? 0}"

],



[

"Deduction",

"₹ ${data["deduction"] ?? 0}"

],



[

"Net Salary",

"₹ ${data["net_salary"] ?? 0}"

],



]

),





pw.SizedBox(
height:30
),




pw.Align(

alignment:
pw.Alignment.centerRight,


child:

pw.Text(

"Authorized Signature"

)

)



]


);



}


)



);







Uint8List bytes =
await pdf.save();





await FileSaver.instance.saveFile(


name:

"Payslip_${data["employee_name"] ?? "Employee"}",



bytes:

bytes,



mimeType:

MimeType.pdf,



);






if(!mounted)return;



ScaffoldMessenger.of(context)
.showSnackBar(


const SnackBar(

content:

Text(
"Payslip downloaded successfully"
)

)


);



}

catch(e){


debugPrint(
e.toString()
);



}



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

"Payslip Preview",

style:

TextStyle(

color:
Colors.white

)

),


),





body:

SingleChildScrollView(



padding:
const EdgeInsets.all(20),



child:

Column(

children:[




employeeCard(),



const SizedBox(
height:20
),




salaryCard(),




const SizedBox(
height:30
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
Icons.download
),



label:

const Text(
"Download PDF"
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
BorderRadius.circular(12)

)

),



onPressed:

downloadPdf,



)



)



],


),



),



);



}









Widget employeeCard(){


return Card(


elevation:
5,


shape:

RoundedRectangleBorder(

borderRadius:
BorderRadius.circular(18)

),




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


data["employee_name"] ??
"Employee",


style:

const TextStyle(

fontSize:
26,

fontWeight:
FontWeight.bold

)


),




const Divider(),




detailRow(

"Employee Code",

data["employee_code"]

),



detailRow(

"Department",

data["department"]

),



detailRow(

"Designation",

data["designation"]

),



]


),



),



);



}









Widget salaryCard(){



return Card(



elevation:
5,



shape:

RoundedRectangleBorder(

borderRadius:
BorderRadius.circular(18)

),



child:

Padding(

padding:
const EdgeInsets.all(20),



child:

Column(

children:[



salaryRow(

"Basic Salary",

data["basic_salary"]

),




salaryRow(

"HRA",

data["hra"]

),





salaryRow(

"Allowance",

data["allowance"]

),





salaryRow(

"Deduction",

data["deduction"]

),




const Divider(),





salaryRow(

"Net Salary",

data["net_salary"]

),



]


),


),


);



}










Widget detailRow(

String title,

dynamic value

){



return Padding(

padding:

const EdgeInsets.symmetric(
vertical:6
),



child:

Row(

mainAxisAlignment:

MainAxisAlignment.spaceBetween,


children:[



Text(title),



Text(

value?.toString() ?? "-"

)



]


),


);



}








Widget salaryRow(

String title,

dynamic value

){



return Padding(

padding:

const EdgeInsets.symmetric(
vertical:8
),



child:

Row(

mainAxisAlignment:

MainAxisAlignment.spaceBetween,


children:[



Text(

title

),



Text(

"₹ ${value ?? 0}",

style:

const TextStyle(

fontWeight:
FontWeight.bold

)

)



]


),


);



}









pw.Widget pdfText(

String title,

dynamic value

){


return pw.Padding(


padding:

const pw.EdgeInsets.all(5),



child:

pw.Row(

children:[



pw.Expanded(

child:

pw.Text(title)

),




pw.Text(

value?.toString() ?? "-"

)



]


)



);



}


}