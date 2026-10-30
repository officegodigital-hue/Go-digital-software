const {test}=require('node:test');
const assert=require('node:assert/strict');
const users=[{id:7,full_name:'Former Employee',is_active:0},{id:8,full_name:'Active Employee',is_active:1}];
require.cache[require.resolve('../config/db')]={exports:{query:async(sql,args)=>[args.length ? users.filter(u=>u.id===Number(args[0])) : users]}};
const {checkBody,liveWriteGuard}=require('./employeeEligibility');
test('live assignments reject inactive employee IDs, names and multi-person role cells',async()=>{
  await assert.rejects(checkBody({employeeId:7}),/Inactive employees/);
  await assert.rejects(checkBody({designer:'FORMER . EMPLOYEE'}),/Inactive employees/);
  await assert.rejects(checkBody({developer:'Active Employee / Former Employee'}),/Inactive employees/);
  await assert.rejects(checkBody({members:['Active Employee','Former Employee']}),/Inactive employees/);
  await checkBody({employeeId:8,designer:'Active Employee'});
});
test('historical reads remain available while live writes enforce eligibility',async()=>{
  let called=false;
  await liveWriteGuard({method:'GET',path:'/tasks',body:{employeeId:7}}, {},()=>{called=true;});
  assert.ok(called);
  let status;
  await liveWriteGuard({method:'POST',path:'/tasks',body:{employeeId:7}}, {status(code){status=code;return this;},json(){}},()=>assert.fail('Inactive employee must not be assigned'));
  assert.equal(status,409);
});
