const PayrollSalaryMasterService =
  require(
    '../services/payrollSalaryMaster.service',
  );


const asyncHandler =
  require(
    '../utils/asyncHandler',
  );


const {
  sendSuccess,
} =
require(
  '../utils/apiResponse',
);





const getSalaryMasters =

asyncHandler(
async(req,res)=>{


const result =
await PayrollSalaryMasterService
.getSalaryMasters({

companyId:
req.auth.companyId,

branchId:
req.auth.branchId,


page:
req.query.page || 1,


limit:
req.query.limit || 10,


search:
req.query.search || '',


status:
req.query.status || 'active',


});



return sendSuccess(
res,
{

message:
'Salary masters fetched successfully',


data:
result.data,


pagination:
result.pagination,


},
);



});







const getSalaryMasterById =

asyncHandler(
async(req,res)=>{


const data =
await PayrollSalaryMasterService
.getSalaryMasterById(
req.params.salaryMasterId,
);



return sendSuccess(
res,
{

message:
'Salary master fetched successfully',

data,

},
);


});







const createSalaryMaster =

asyncHandler(
async(req,res)=>{


const data =
await PayrollSalaryMasterService
.createSalaryMaster(
{

...req.body,


companyId:
req.auth.companyId,


branchId:
req.auth.branchId,


},
);



return sendSuccess(
res,
{

message:
'Salary master created successfully',

data,

},
);


});








const updateSalaryMaster =

asyncHandler(
async(req,res)=>{


const data =
await PayrollSalaryMasterService
.updateSalaryMaster(

req.params.salaryMasterId,

req.body,

);



return sendSuccess(
res,
{

message:
'Salary master updated successfully',

data,

},
);



});









const deleteSalaryMaster =

asyncHandler(
async(req,res)=>{


const data =
await PayrollSalaryMasterService
.deleteSalaryMaster(

req.params.salaryMasterId,

);



return sendSuccess(
res,
{

message:
'Salary master deleted successfully',

data,

},
);



});







module.exports = {


getSalaryMasters,


getSalaryMasterById,


createSalaryMaster,


updateSalaryMaster,


deleteSalaryMaster,


};