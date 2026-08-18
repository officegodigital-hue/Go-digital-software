import '../models/payroll_employee_model.dart';



class PayrollEmployeeRepository {



Future<List<PayrollEmployeeModel>> getEmployees() async {



await Future.delayed(
const Duration(milliseconds:500)
);



return [


PayrollEmployeeModel(

id:1,

name:"Krishnaraj B",

code:"90046034",

department:"Sales",

designation:"BDM",

salary:35000

),



PayrollEmployeeModel(

id:2,

name:"Arun Kumar",

code:"90046035",

department:"HR",

designation:"Manager",

salary:42000

),



PayrollEmployeeModel(

id:3,

name:"Rajesh",

code:"90046036",

department:"IT",

designation:"Developer",

salary:55000

)



];



}



}