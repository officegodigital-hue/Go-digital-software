import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/payslip_model.dart';



class PayslipPdfService {



static Future<Uint8List> generatePdf(
    PayslipModel employee
) async {



final pdf = pw.Document();



// Load logo

final logoData =
await rootBundle.load(
"assets/images/godigital.png"
);


final logo =
pw.MemoryImage(
logoData.buffer.asUint8List()
);




// Load seal

final sealData =
await rootBundle.load(
"assets/images/roundseal.PNG"
);


final seal =
pw.MemoryImage(
sealData.buffer.asUint8List()
);





pdf.addPage(



pw.Page(



pageFormat:
PdfPageFormat.a4,



margin:
const pw.EdgeInsets.all(25),




build:(context){



return pw.Column(



crossAxisAlignment:
pw.CrossAxisAlignment.start,



children:[




// LOGO


pw.Align(

alignment:
pw.Alignment.centerLeft,


child:

pw.Image(

logo,

height:60,

),


),




pw.SizedBox(
height:30
),






// HEADER


pw.Container(


width:
double.infinity,


color:
PdfColors.blue900,


padding:
const pw.EdgeInsets.all(8),



child:

pw.Text(


"Salary Slip For The Month - ${employee.month} ${employee.year}",


textAlign:
pw.TextAlign.center,



style:

pw.TextStyle(

color:
PdfColors.white,

fontWeight:
pw.FontWeight.bold,

fontSize:12,

),



),


),






pw.SizedBox(
height:10
),






// EMPLOYEE TABLE


buildTable([



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


]),






pw.SizedBox(
height:10
),






// BANK TABLE


buildTable([



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



]),





pw.SizedBox(
height:10
),






// SALARY TABLE


buildTable([



[
"Earnings",
"Amt(INR)",
"Deductions",
"Amt(INR)"
]

],



header:true
),





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






// TOTALS


buildTable([


[
"Total Earnings(A)",
employee.grossEarnings.toStringAsFixed(0),
"Total Deduction(B)",
employee.totalDeduction.toStringAsFixed(0)
],



[
"",
"",
"Net Payable(A-B)",
employee.netPayable.toStringAsFixed(0)
],



]),






pw.SizedBox(
height:30
),





// FOOTER


pw.Row(


mainAxisAlignment:
pw.MainAxisAlignment.spaceBetween,



children:[



pw.Expanded(


child:

pw.Text(

"This is a system generated Pay slip and hence company signature is not required",

style:

const pw.TextStyle(

fontSize:8,

),

),


),





pw.Image(

seal,

height:60,

),



],



),




],



);



},



),



);





return pdf.save();



}









static pw.Table buildTable(

List<List<dynamic>> data,

{

bool header=false,

}

){



return pw.TableHelper.fromTextArray(


data:data,


border:
pw.TableBorder.all(


color:
PdfColors.black,

width:0.5,

),



headerDecoration:

header

?

const pw.BoxDecoration(

color:
PdfColors.lightBlue100,

)

:

null,



cellStyle:

const pw.TextStyle(

fontSize:8,

),



);



}



}