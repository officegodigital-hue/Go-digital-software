const {test}=require('node:test');
const assert=require('node:assert/strict');
const jwt=require('jsonwebtoken');
const policy=require('../lib/attendancePolicy');
const {createApp}=require('./app');
test('extra hours saves valid SQL times, validates input and preserves minutes in totals',async()=>{
 const original=policy.getTimeSettings;
 policy.getTimeSettings=async()=>({shiftEnd:'18:30:00'});
 const inserts=[];
 const pool={execute:async(sql,params)=>{
  if(sql.includes('employee_users'))return [[{id:7,is_active:1}]];
  if(sql.includes('INSERT INTO employee_extra_hours')){inserts.push(params);return [{insertId:1}];}
  return [[{work_date:'2026-10-25',extra_minutes:'150',status:'PENDING'}]];
 }};
 const app=createApp({pool,jwtSecret:'test',clock:()=>new Date('2026-10-25T12:00:00Z')});
 const server=app.listen(0,'127.0.0.1');
 await new Promise(r=>server.once('listening',r));
 const url=`http://127.0.0.1:${server.address().port}/api/attendance/extra-hours`;
 const headers={Authorization:`Bearer ${jwt.sign({id:7},'test')}`,'Content-Type':'application/json'};
 try{
  for(const hours of ['2h 30m','2.5','30m']){
   const response=await fetch(url+'/log',{method:'POST',headers,body:JSON.stringify({work_date:'2026-10-25',hours_worked:hours,reason:'Tasks',actual_out:'Overtime Session'})});
   assert.equal(response.status,200);
  }
  assert.deepEqual(inserts.map(p=>p.slice(2,5)),[['18:30:00',null,150],['18:30:00',null,150],['18:30:00',null,30]]);
  for(const hours of ['garbage','-2','0','2h 90m','25h']){
   const response=await fetch(url+'/log',{method:'POST',headers,body:JSON.stringify({work_date:'2026-10-25',hours_worked:hours,reason:''})});
   assert.equal(response.status,400);
  }
  const invalid=await fetch(url+'/log',{method:'POST',headers,body:JSON.stringify({work_date:'2026-02-30',hours_worked:'2h',reason:''})});
  assert.equal(invalid.status,400);
  const data=await(await fetch(url+'/dashboard',{headers})).json();
  assert.equal(data.data.metrics.total_year,'2h 30m');
  assert.equal(data.data.metrics.this_month_hours,'2h 30m');
 }finally{policy.getTimeSettings=original;await new Promise(r=>server.close(r));}
});
