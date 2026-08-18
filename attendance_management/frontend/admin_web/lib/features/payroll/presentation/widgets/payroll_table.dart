import 'package:flutter/material.dart';

import '../../data/models/payroll_model.dart';



class PayrollTable extends StatelessWidget {


final List<PayrollModel> payrolls;


const PayrollTable({

super.key,

required this.payrolls

});



@override
Widget build(BuildContext context){


return DataTable(


columns:[


const DataColumn(
label:Text("Month")
),


const DataColumn(
label:Text("Year")
),


const DataColumn(
label:Text("Employees")
),


const DataColumn(
label:Text("Net Salary")
),


const DataColumn(
label:Text("Status")
),


],



rows:

payrolls.map((p){


return DataRow(

cells:[


DataCell(
Text(
"${p.payrollMonth}"
)
),


DataCell(
Text(
"${p.payrollYear}"
)
),


DataCell(
Text(
"${p.totalEmployees}"
)
),


DataCell(
Text(
"₹${p.netPayable}"
)
),


DataCell(
Chip(
label:
Text(
p.status
)
)
),


]


);


}).toList(),


);



}


}