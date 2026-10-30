const {test}=require('node:test');
const assert=require('node:assert/strict');
let calls=[],failWrite=false,active=1,lastExit='2026-10-14',writes=[];
async function query(sql,params) {
  calls.push(sql);
  writes.push({sql,params});
  if (/SELECT last_working_date FROM employee_exits/.test(sql)) return [[{last_working_date:lastExit}]];
  if (/information_schema/.test(sql)) return [[]];
  if (/SELECT id, full_name/.test(sql)) return [[{id:7,full_name:'Former Employee',created_at:'2026-10-01',joining_date:'2026-10-01',is_active:active}]];
  if (/SELECT id FROM employee_exits/.test(sql)) return [[]];
  if (/SELECT \* FROM employee_employment_periods/.test(sql)) return [[{id:1,employee_user_id:7,started_on:'2026-10-01',ended_on:null}]];
  if (/SELECT \* FROM hrms_payroll_items/.test(sql)) return [[]];
  if (/FROM hrms_payroll_custom_cycles/.test(sql)) return [[]];
  if (/FROM employee_exit_exceptions/.test(sql)) return [[]];
  if (/UPDATE employee_users/.test(sql) && failWrite) throw new Error('simulated write failure');
  return [{insertId:9,affectedRows:1}];
}
const connection={query,beginTransaction:async()=>calls.push('BEGIN'),commit:async()=>calls.push('COMMIT'),rollback:async()=>calls.push('ROLLBACK'),release:()=>calls.push('RELEASE')};
require.cache[require.resolve('../config/db')]={exports:{query,getConnection:async()=>connection}};
require.cache[require.resolve('../controllers/hrmsPayrollController')]={exports:{ensureCustomCycleTable:async()=>{},computeRows:async()=>[{employeeUserId:7,periodStart:'2026-10-01',periodEnd:'2026-10-31',monthlySalary:27000}]}};
const lifecycle=require('./employeeLifecycle');
const policy=require('./attendancePolicy');
policy.todayIstDate=()=> '2026-10-29';
test('exit automatically uses yesterday, requires reason, and rejects self-deactivation',async()=>{
  assert.equal((await lifecycle.preview(7,{reason:'Left'})).lastWorkingDate,'2026-10-28');
  assert.equal((await lifecycle.preview(7,{lastWorkingDate:'2020-01-01',reason:'Left'})).lastWorkingDate,'2026-10-28');
  await assert.rejects(lifecycle.preview(7,{lastWorkingDate:'2026-10-10',reason:''}),/reason/);
  await assert.rejects(lifecycle.deactivate(7,{lastWorkingDate:'2026-10-10',reason:'Left'},7),/own account/);
  policy.todayIstDate=()=> '2026-10-01';
  await assert.rejects(lifecycle.preview(7,{reason:'Left'}),/joining date/);
  policy.todayIstDate=()=> '2026-10-29';
});
test('failure rolls back account, profile, employment dates and audit together',async()=>{
  calls=[];failWrite=true;
  await assert.rejects(lifecycle.deactivate(7,{lastWorkingDate:'2026-10-10',reason:'Left'},1),/simulated/);
  assert.ok(calls.includes('ROLLBACK'));assert.ok(!calls.includes('COMMIT'));assert.equal(calls.at(-1),'RELEASE');
  const transactional=calls.slice(calls.indexOf('BEGIN'));
  assert.ok(!transactional.some(s=>/CREATE|ALTER/.test(s)));
});
test('exit commits identity, profile, employment dates and audit before disconnecting sockets',async()=>{
  calls=[];failWrite=false;let disconnected=false;
  const io={sockets:{sockets:new Map([['one',{data:{employeeId:7},emit:()=>{},disconnect:()=>{assert.ok(calls.includes('COMMIT'));disconnected=true;}}]])},emit:()=>{}};
  const result=await lifecycle.deactivate(7,{lastWorkingDate:'2026-10-10',reason:'Left'},1,io);
  assert.ok(!calls.some(s=>/employee_handover|task_list|task_assignments|content_calendar/.test(s)));
  assert.equal(result.lastWorkingDate,'2026-10-28');
  assert.equal(result.exitId,9);assert.ok(disconnected);
  assert.ok(calls.some(s=>/UPDATE employee_users SET is_active=0/.test(s)));
  assert.ok(calls.some(s=>/UPDATE hrms_employee_profiles/.test(s)));
  assert.ok(calls.some(s=>/INSERT INTO employee_lifecycle_audit/.test(s)));
});

test('automatic last working date handles month, year and leap-year boundaries',()=>{
  for (const [today, expected] of [['2026-11-01','2026-10-31'],['2026-01-01','2025-12-31'],['2024-03-01','2024-02-29']]) {
    policy.todayIstDate=()=>today;
    assert.equal(lifecycle.automaticLastWorkingDate(),expected);
  }
  policy.todayIstDate=()=> '2026-10-29';
});

test('reactivation stores today and preserves history even when a different date is sent',async()=>{
  active=0;failWrite=false;calls=[];writes=[];
  policy.todayIstDate=()=> '2026-10-29';
  try {
    for (const body of [{}, {startDate:'2026-10-20'}]) {
      const result=await lifecycle.reactivate(7,body,1);
      assert.equal(result.startDate,'2026-10-29');
    }
    const periods=writes.filter(w=>/INSERT INTO employee_employment_periods/.test(w.sql));
    assert.equal(periods.length,2);
    assert.ok(periods.every(w=>w.params[1]==='2026-10-29'));
    assert.ok(!calls.some(s=>/DELETE|UPDATE employee_employment_periods|UPDATE attendance_records|UPDATE hrms_payroll_items/.test(s)));
    lastExit='2026-10-29';
    await assert.rejects(lifecycle.reactivate(7,{},1),/follow the previous last working date/);
  } finally { active=1;lastExit='2026-10-14'; }
});
