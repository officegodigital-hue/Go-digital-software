const {test}=require('node:test');const assert=require('node:assert/strict');const fs=require('node:fs');const vm=require('node:vm');
const policy=require('../lib/attendancePolicy');
function load(name,deps){const module={exports:{}};vm.runInNewContext(fs.readFileSync(require.resolve('./'+name),'utf8'),{module,console,Date,Map,Set,Buffer,process:{env:{}},require:p=>deps[p]||{}});return module.exports;}
function response(){return {code:200,body:null,status(c){this.code=c;return this;},json(b){this.body=b;return this;},set(){return this;},type(){return this;},send(b){this.body=b;return this;}};}
for(const status of ['approved','rejected'])test(`admin ${status} decision updates linked employee leave`,async()=>{
 const calls=[];let reconciled=0;
 const item={id:8,employee_id:7,request_type:'casual_leave',status:'pending',request_date:'2026-10-26'};
 const controller=load('hrmsApprovalsController',{
  '../config/db':{query:async(sql,params)=>{
   calls.push({sql,params});
   if(sql.includes('SELECT p.*, h.'))return [[item]];
   if(sql.includes('UPDATE attendance_permission_requests'))return [{affectedRows:1}];
   if(sql.includes('SELECT l.*'))return [[{id:9}]];
   if(sql.includes('SELECT p.id'))return [[{...item,status}]];
   return [[]];
  }},
  '../lib/attendancePolicy':policy,
  '../lib/staffDirectory':{STAFF:{name:'full_name',id:'id',staffCode:'staff_id'},quote:x=>x,staffFrom:()=> 'employee_users'},
  '../lib/leaveSystem':{reconcileApprovedAbsences:async()=>{reconciled++;}},
 });
 const res=response();await controller.review({params:{id:8},user:{id:1},body:{status}},res);
 assert.equal(res.code,200);assert.equal(res.body.success,true);
 const linked=calls.find(c=>c.sql.includes('UPDATE employee_leaves l'));
 assert.equal(linked.params[0],status==='approved'?'APPROVED':'DENIED');
 assert.equal(linked.params[1],8);assert.equal(reconciled,status==='approved'?1:0);
});
test('payslip download reads the shared admin approval and scopes to employee',async()=>{
 let approval='pending';let params;let generated=0;
 const controller=load('hrmsPayslipController',{
  '../config/db':{query:async(sql,p)=>{
   if(sql.includes('SELECT p.*, a.status')){params=p;return [[{request_status:approval,pay_month:10,pay_year:2026}]];}
   return [[]];
  }},
  '../lib/payslipPdf':{buildPayslipPdf:async()=>{generated++;return Buffer.from('%PDF-test');}},
 });
 const req={params:{payrollId:10},user:{id:7}};
 let res=response();await controller.download(req,res);assert.equal(res.code,403);assert.equal(generated,0);
 approval='approved';res=response();await controller.download(req,res);assert.equal(res.code,200);assert.equal(generated,1);
 assert.deepEqual(Array.from(params),[10,7]);
});
