import 'package:flutter/material.dart';


class CreatePayslipScreen extends StatefulWidget {


final String token;


const CreatePayslipScreen({

super.key,

required this.token,

});



@override
State<CreatePayslipScreen> createState()
=> _CreatePayslipScreenState();


}



class _CreatePayslipScreenState 
extends State<CreatePayslipScreen>{



String selectedMonth="August 2026";


List<Map<String,dynamic>> employees=[


{
"id":1,
"name":"Krishnaraj B",
"code":"90046034",
"department":"Sales",
"basic":20000,
"allowance":15000,
"selected":false
},


{
"id":2,
"name":"Arun Kumar",
"code":"90046035",
"department":"HR",
"basic":25000,
"allowance":17000,
"selected":false
},


{
"id":3,
"name":"Rajesh",
"code":"90046036",
"department":"IT",
"basic":30000,
"allowance":25000,
"selected":false
}


];





@override
Widget build(BuildContext context){


return Scaffold(


backgroundColor:
const Color(0xffF5F7FB),



appBar:AppBar(

backgroundColor:
const Color(0xff00263D),

title:
const Text(
"Create Payslip"
),

),




body:

Padding(

padding:
const EdgeInsets.all(20),


child:

Column(

crossAxisAlignment:
CrossAxisAlignment.start,


children:[



const Text(

"Select Month",

style:

TextStyle(

fontSize:20,

fontWeight:
FontWeight.bold

)

),



const SizedBox(height:10),



DropdownButtonFormField<String>(

initialValue:selectedMonth,


items:[

"August 2026",
"September 2026",
"October 2026"

].map(

(e)=>

DropdownMenuItem(

value:e,

child:Text(e)

)

).toList(),



onChanged:(value){

setState((){

selectedMonth=value!;

});

},



decoration:

const InputDecoration(

border:
OutlineInputBorder()

),


),



const SizedBox(height:25),




Row(

mainAxisAlignment:
MainAxisAlignment.spaceBetween,


children:[



const Text(

"Select Employees",

style:

TextStyle(

fontSize:20,

fontWeight:
FontWeight.bold

)

),



TextButton(

child:
const Text(
"Select All"
),


onPressed:(){


setState((){


for(var e in employees){

e["selected"]=true;

}


});


},


)



]

),




Expanded(

child:

ListView.builder(

itemCount:
employees.length,


itemBuilder:(context,index){


final emp=employees[index];


return Card(


child:

CheckboxListTile(


value:
emp["selected"],



title:

Text(
emp["name"]
),



subtitle:

Text(

"${emp["code"]} • ${emp["department"]}"

),



secondary:

Column(

mainAxisAlignment:
MainAxisAlignment.center,


children:[


Text(
"₹${emp["basic"]+emp["allowance"]}"
)

]

),



onChanged:(value){


setState((){


emp["selected"]=value;


});


},



),


);



}


)

),





SizedBox(

width:
double.infinity,


child:

ElevatedButton.icon(

icon:
const Icon(Icons.save),


label:

const Text(

"Generate Payslips"

),



onPressed:(){



final selected=

employees.where(

(e)=>e["selected"]==true

).toList();



if(selected.isEmpty){


ScaffoldMessenger.of(context)
.showSnackBar(

const SnackBar(

content:

Text(
"Select employee first"
)

)

);


return;

}



showDialog(

context:context,

builder:(context)=>

AlertDialog(

title:

const Text(
"Success"
),


content:

Text(

"${selected.length} Payslip Generated"

),


actions:[

TextButton(

child:
const Text("OK"),

onPressed:(){

Navigator.pop(context);

}

)

]


)


);



},


)


)



]

)



)



);


}


}