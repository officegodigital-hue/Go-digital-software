const {test}=require('node:test');
const assert=require('node:assert/strict');
const {workedMinutes}=require('./dashboardWorkTime');
const row={id:1,check_in_at:'2026-10-24 09:30:00',check_out_at:'2026-10-24 18:30:00',working_minutes:30443};
test('monthly overview recomputes actual punches, ignoring inflated cached minutes',()=>{
 assert.equal(workedMinutes(row,[{status:'completed',duration_minutes:60}]),480);
 assert.equal(workedMinutes({...row,check_in_at:null},[]),0);
 assert.equal(workedMinutes({...row,admin_status_override:'absent'},[]),0);
});
test('open records count only when explicitly live, and breaks stop at session end',()=>{
 const open={...row,check_out_at:null};
 assert.equal(workedMinutes(open,[],'2026-10-24 12:30:00'),0);
 assert.equal(workedMinutes(open,[{started_at:'2026-10-24 12:00:00',status:'active'}],'2026-10-24 12:30:00',true),150);
 assert.equal(workedMinutes(open,[],'2026-10-26 12:30:00',true),0);
});
test('overnight and genuine overtime remain intact, malformed multi-day sessions do not inflate totals',()=>{
 assert.equal(workedMinutes({...row,check_in_at:'2026-10-24 21:30:00',check_out_at:'2026-10-25 06:30:00'},[]),540);
 assert.equal(workedMinutes({...row,check_out_at:'2026-10-24 23:59:00'},[]),869);
 assert.equal(workedMinutes({...row,check_out_at:'2026-10-26 18:30:00'},[]),0);
 assert.equal(workedMinutes({...row,check_out_at:'invalid'},[]),0);
});
test('22 completed nine-hour days less one-hour breaks add up to 176 hours',()=>{
 assert.equal(Array.from({length:22},()=>workedMinutes(row,[{status:'completed',duration_minutes:60}])).reduce((a,b)=>a+b,0),176*60);
});

test('monthly total posts today tomorrow while the session timer stays live',async()=>{
 const fs=require('node:fs');const vm=require('node:vm');const policy=require('./attendancePolicy');
 const today={id:2,attendance_date:'2026-10-24',check_in_at:'2026-10-24 09:30:00',check_out_at:null,working_minutes:30443};
 let date='2026-10-24';
 const yesterday={...row,id:1,attendance_date:'2026-10-23',check_in_at:'2026-10-23 09:30:00',check_out_at:'2026-10-23 18:30:00'};
 const query=async sql=>{
  if(sql.includes('attendance_date = ? LIMIT 1'))return [date === '2026-10-24' ? [today] : []];
  if(sql.includes('FROM attendance_records')&&sql.includes('LAST_DAY'))return [[yesterday,today,{...today,id:3,attendance_date:'2026-10-22',check_in_at:'2026-10-22 09:30:00'}]];
  if(sql.includes('SUM(duration_minutes)'))return [[{minutes:0}]];
  if(sql.includes('WHERE attendance_id IN'))return [[{attendance_id:1,duration_minutes:60,status:'completed',started_at:'2026-10-23 12:00:00',ended_at:'2026-10-23 13:00:00'}]];
  return [[]];
 };
 const module={exports:{}};
 vm.runInNewContext(fs.readFileSync(require.resolve('../controllers/attendanceController'),'utf8'),{module,console,Date,Map,Set,require:p=>{
  if(p==='../config/db')return {query};
  if(p==='../lib/attendancePolicy')return {...policy,getTimeSettings:async()=>({shiftStart:'09:30:00',shiftEnd:'18:30:00'}),todayIstDate:()=>date,nowIstDateTime:()=> date+' 12:30:00'};
  if(p==='../lib/dashboardWorkTime')return {workedMinutes};
  if(p==='../lib/staffDirectory')return {listActiveStaff:async()=>[{id:7}]};
  if(p==='../lib/calendarOverrides')return {effectiveOverrides:async()=>new Map()};
  return {};
 }});
 let result;
 await module.exports.employeeDashboard({user:{id:7},query:{month:'2026-10'}},{json:b=>{result=b;},status:c=>{throw Error('HTTP '+c);}});
 assert.equal(result.data.month_overview.work_time.actual_minutes,480);
 assert.equal(result.data.month_overview.work_time.is_live,false);
 assert.equal(result.data.session.worked_seconds,180*60);
 // Checking out today still leaves the monthly figure unchanged.
 today.check_out_at='2026-10-24 18:30:00';
 const dashboard=async()=>module.exports.employeeDashboard({user:{id:7},query:{month:'2026-10'}},{json:b=>{result=b;},status:c=>{throw Error('HTTP '+c);}});
 await dashboard();
 assert.equal(result.data.month_overview.work_time.actual_minutes,480);
 assert.equal(result.data.session.worked_seconds,540*60);
 // The completed day is included when the local calendar advances.
 date='2026-10-25';
 await dashboard();
 assert.equal(result.data.month_overview.work_time.actual_minutes,480+540);
});
