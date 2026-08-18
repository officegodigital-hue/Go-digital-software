import 'package:flutter/material.dart';

import '../../data/models/payslip_model.dart';

import 'edit_payslip_screen.dart';
import 'payslip_preview_screen.dart';
import 'employee_payslip_history_screen.dart';



class PayrollDetailsScreen extends StatefulWidget {


  final Map<String,dynamic> payroll;

  final String token;



  const PayrollDetailsScreen({

    super.key,

    required this.payroll,

    required this.token,

  });



  @override
  State<PayrollDetailsScreen> createState() =>
      _PayrollDetailsScreenState();

}





class _PayrollDetailsScreenState
extends State<PayrollDetailsScreen>{





List<PayslipModel> employees = [



PayslipModel(

id:1,

employeeName:"Krishnaraj B",

employeeCode:"90046034",

department:"Sales",

designation:"BDM",

doj:"16/11/2024",

grade:"G12",

location:"Chennai",

bankAccount:"924010054963636",

aadhar:"611191540567",

pan:"-",

uan:"-",


basicSalary:20000,

hra:6552,

attireAllowance:4300,

otherAllowance:4148,

otAllowance:0,

bonus:0,


pf:0,

esic:0,

professionalTax:0,

incomeTax:0,


month:"August",

year:"2026",

sent:false,

),





PayslipModel(

id:2,

employeeName:"Manoj Kumar",

employeeCode:"90046035",

department:"IT",

designation:"Developer",

doj:"10/01/2025",

grade:"G12",

location:"Chennai",

bankAccount:"-",

aadhar:"-",

pan:"-",

uan:"-",


basicSalary:30000,

hra:8000,

attireAllowance:4000,

otherAllowance:3000,

otAllowance:0,

bonus:0,


pf:0,

esic:0,

professionalTax:0,

incomeTax:0,


month:"August",

year:"2026",

sent:true,

),





PayslipModel(

id:3,

employeeName:"Arun Kumar",

employeeCode:"90046036",

department:"HR",

designation:"Manager",

doj:"05/03/2025",

grade:"G12",

location:"Chennai",

bankAccount:"-",

aadhar:"-",

pan:"-",

uan:"-",


basicSalary:35000,

hra:9000,

attireAllowance:5000,

otherAllowance:3000,

otAllowance:0,

bonus:0,


pf:0,

esic:0,

professionalTax:0,

incomeTax:0,


month:"August",

year:"2026",

sent:false,

),


];









@override
Widget build(BuildContext context){


return Scaffold(


backgroundColor:
const Color(0xffF5F7FB),



appBar:AppBar(

backgroundColor:
const Color(0xff00263D),


title:Text(

"Payroll ${widget.payroll["payroll_month"] ?? "August"}/${widget.payroll["payroll_year"] ?? "2026"}"

),


),




body:ListView(

padding:
const EdgeInsets.all(20),


children:[


const Text(

"Employee Payslips",

style:

TextStyle(

fontSize:26,

fontWeight:FontWeight.bold,

),

),



const SizedBox(height:20),




...employees.map(

(employee)=>employeeCard(employee)

)



],



),



);



}










Widget employeeCard(

PayslipModel employee

){



return Container(



margin:

const EdgeInsets.only(bottom:18),



padding:

const EdgeInsets.all(18),



decoration:

BoxDecoration(

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


child:

Text(

employee.employeeName[0],

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

employee.employeeName,

style:

const TextStyle(

fontSize:20,

fontWeight:FontWeight.bold,

),

),




Text(

"${employee.employeeCode} • ${employee.department}"

),




Text(

employee.designation,

),




const SizedBox(height:8),





Text(

"₹${employee.netPayable.toStringAsFixed(0)}",

style:

const TextStyle(

fontSize:20,

fontWeight:FontWeight.bold,

),

),





const SizedBox(height:8),




Row(

children:[


Text(

"${employee.month} ${employee.year}"

),



const SizedBox(width:10),




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

?

Colors.green.shade100

:

Colors.orange.shade100,


borderRadius:

BorderRadius.circular(20),

),



child:

Text(

employee.sent

?

"Sent"

:

"Not Sent",

style:

TextStyle(

color:

employee.sent

?

Colors.green

:

Colors.orange,

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
(){

Navigator.push(

context,

MaterialPageRoute(

builder:(context)=>

PayslipPreviewScreen(

employee: employee,

)

)

);

}
),




actionButton(

Icons.edit,

Colors.orange,

(){



Navigator.push(

context,

MaterialPageRoute(

builder:(context)=>

EditPayslipScreen(

payslip:employee,

)

)

);



}

),





actionButton(

Icons.download,

Colors.green,

(){


downloadPayslip(employee);


}

),





actionButton(

Icons.send,

Colors.purple,

(){


setState((){

employee.sent=true;

});


}

),






actionButton(

Icons.history,

Colors.blueGrey,

(){


Navigator.push(

context,

MaterialPageRoute(

builder:(context)=>

EmployeePayslipHistoryScreen(

employeeName:

employee.employeeName,

)

)

);



}

),






actionButton(

Icons.delete,

Colors.red,

(){


deleteEmployee(employee);


}

),



]


)



],



),



);



}









Widget actionButton(

IconData icon,

Color color,

VoidCallback action

){


return IconButton(

icon:

Icon(

icon,

color:color,

),


onPressed:action,


);



}









void downloadPayslip(

PayslipModel employee

){



ScaffoldMessenger.of(context)

.showSnackBar(

SnackBar(

content:

Text(

"Download ${employee.employeeName} Payslip"

),

)

);



}









void deleteEmployee(

PayslipModel employee

){



showDialog(

context:context,

builder:(context)=>AlertDialog(


title:

const Text(

"Delete Payslip"

),



content:

Text(

"Delete ${employee.employeeName}?"

),



actions:[


TextButton(

onPressed:(){

Navigator.pop(context);

},

child:

const Text(

"Cancel"

),

),



ElevatedButton(

onPressed:(){


setState((){

employees.remove(employee);

});


Navigator.pop(context);


},

child:

const Text(

"Delete"

),

)



],


)

);



}



}