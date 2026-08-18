class PayrollEmployeeModel {


final int id;

final String name;

final String code;

final String department;

final String designation;

final double salary;

final bool sent;



PayrollEmployeeModel({

required this.id,

required this.name,

required this.code,

required this.department,

required this.designation,

required this.salary,

this.sent=false,

});



factory PayrollEmployeeModel.fromJson(
Map<String,dynamic> json
){


return PayrollEmployeeModel(

id: json["id"],

name: json["name"] ?? "",

code: json["employee_code"] ?? "",

department: json["department"] ?? "",

designation: json["designation"] ?? "",

salary:
double.tryParse(
json["salary"].toString()
) ?? 0,

sent:
json["sent"] ?? false,

);


}



Map<String,dynamic> toJson(){

return {


"id":id,

"name":name,

"employee_code":code,

"department":department,

"designation":designation,

"salary":salary,

"sent":sent


};

}


}