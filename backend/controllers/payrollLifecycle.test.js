const { test } = require('node:test');
const assert = require('node:assert/strict');
let fixture;
const query = async (sql, params) => {
  if (/hrms_payroll_policy/.test(sql)) return [[{ weekly_off_days: '[0]', deduct_explicit_absence: 1, missing_attendance_is_absent: 1 }]];
  if (/FROM hrms_employee_profiles p JOIN employee_users/.test(sql)) return [[fixture.profile]];
  if (/FROM employee_employment_periods/.test(sql)) return [fixture.periods];
  if (/FROM hrms_employee_compensation/.test(sql)) return [fixture.compensations || [{profile_id:1,employee_user_id:7,monthly_salary:27000}]];
  if (/FROM attendance_records/.test(sql)) return [fixture.attendance || []];
  if (/FROM employee_leaves/.test(sql)) {fixture.leaveBounds=params;return [fixture.leaves || []];}
  if (/FROM hrms_payroll_items/.test(sql)) return [fixture.saved ? [fixture.saved] : []];
  if (/FROM hrms_payroll_custom_cycles/.test(sql)) return [fixture.custom ? [fixture.custom] : []];
  throw new Error('Unexpected SQL: '+sql);
};
require.cache[require.resolve('../config/db')] = { exports: { query } };
require.cache[require.resolve('../lib/calendarOverrides')] = { exports: { effectiveOverrides: async () => new Map([[7, new Map(fixture.holidays || [])]]) } };
const { computeRows } = require('./hrmsPayrollController');
function reset() {
  fixture = { profile: {id:1,employee_user_id:7,full_name:'Former Employee',employment_status:'Inactive',is_active:0,monthly_salary:27000,salary_type:'standard'},
    periods: [{ employee_user_id:7,started_on:'2026-10-01',ended_on:'2026-10-15' }] };
}
async function calculate(year=2026, month=10) { return computeRows(year,month,'2026-12-01',{skipSetup:true}); }
test('mid-cycle exit pays eligible days and never treats later dates as absence', async () => {
  reset();
  fixture.attendance = Array.from({length:15},(_,i) => ({employee_id:7,attendance_date:`2026-10-${String(i+1).padStart(2,'0')}`,attendance_status:'present',check_in_at:'09:00'}));
  const [item] = await calculate();
  assert.equal(item.workingDays,27); assert.equal(item.eligibleWorkingDays,13);
  assert.equal(item.absentDays,0); assert.equal(item.netPay,13000);
  assert.equal(item.settlement,true);
});
test('unpaid leave applies before exit; future leave cannot deduct', async () => {
  reset();
  fixture.attendance = Array.from({length:15},(_,i) => ({employee_id:7,attendance_date:`2026-10-${String(i+1).padStart(2,'0')}`,attendance_status:'present'})).filter(r=>r.attendance_date!=='2026-10-05');
  fixture.leaves = [{employee_id:7,from_date:'2026-10-05',to_date:'2026-10-05',is_lop:1,duration_type:'Half Day'}, {employee_id:7,from_date:'2026-10-20',to_date:'2026-10-21',is_lop:1}];
  const [item] = await calculate();
  assert.equal(item.lopDays,0.5); assert.equal(item.netPay,12500);
});
test('paid leave and holidays retain existing policy treatment', async () => {
  reset(); fixture.holidays=[['2026-10-02',{status:'Holiday'}]];
  fixture.leaves=[{employee_id:7,from_date:'2026-10-01',to_date:'2026-10-15',is_lop:0}];
  const [item]=await calculate();
  assert.equal(item.workingDays,26); assert.equal(item.eligibleWorkingDays,12);
  assert.equal(item.lopDays,0); assert.equal(item.netPay,12461.54);
});
test('flexible cycle keeps full denominator and cuts salary at exit', async () => {
  reset(); Object.assign(fixture.profile,{salary_type:'flexible',salary_cycle_start_day:26,salary_cycle_end_day:25});
  fixture.periods[0].ended_on='2026-10-28';
  fixture.leaves=[{employee_id:7,from_date:'2026-10-26',to_date:'2026-10-28',is_lop:0}];
  const [item]=await calculate(2026,11);
  assert.equal(item.periodStart,'2026-10-26'); assert.equal(item.periodEnd,'2026-11-25');
  assert.equal(item.workingDays,27); assert.equal(item.netPay,3000);
});
test('paid snapshots remain unchanged and differences are flagged', async () => {
  reset(); fixture.saved={id:88,profile_id:1,employee_user_id:7,status:'paid',monthly_salary:27000,working_days:27,paid_days:27,net_pay:27000,deductions:0,period_start:'2026-10-01',period_end:'2026-10-31'};
  const [item]=await calculate();
  assert.equal(item.netPay,27000); assert.equal(item.paidAdjustmentRequired,true);
  assert.equal(item.status,'Paid');
});
test('inactive employees disappear from later recurring cycles but retain saved history', async () => {
  reset(); assert.deepEqual(await calculate(2026,11),[]);
  fixture.saved={id:88,profile_id:1,employee_user_id:7,status:'paid',monthly_salary:27000,working_days:25,net_pay:27000};
  assert.equal((await calculate(2026,11))[0].id,88);
});
test('unknown legacy exit dates block automatic payment', async () => {
  reset(); fixture.periods=[];
  const [item]=await calculate(); assert.equal(item.exitDateRequired,true); assert.ok(item.integrityError);
});
test('reactivation does not create attendance or salary in the inactive gap', async () => {
  reset(); fixture.profile.is_active=1;
  fixture.periods=[{employee_user_id:7,started_on:'2026-10-01',ended_on:'2026-10-05'},{employee_user_id:7,started_on:'2026-10-26',ended_on:null}];
  fixture.leaves=[{employee_id:7,from_date:'2026-10-01',to_date:'2026-10-31',is_lop:0}];
  const [item]=await calculate(); assert.equal(item.eligibleWorkingDays,10); assert.equal(item.netPay,10000);
});
test('custom cycles load leave and calendar inputs across their entire range',async()=>{
  reset();fixture.custom={profile_id:1,period_start:'2026-08-15',period_end:'2026-10-15'};
  fixture.periods=[{employee_user_id:7,started_on:'2026-08-15',ended_on:'2026-10-15'}];
  fixture.leaves=[{employee_id:7,from_date:'2026-08-20',to_date:'2026-08-20',is_lop:1},
    {employee_id:7,from_date:'2026-08-15',to_date:'2026-10-15',is_lop:0}];
  const [item]=await calculate();assert.equal(item.lopDays,1);
  assert.ok(fixture.leaveBounds[0]>='2026-10-15');assert.ok(fixture.leaveBounds[1]<='2026-08-15');
});
test('a salary increase after departure does not change the final daily rate',async()=>{
  reset();fixture.compensations=[{profile_id:1,employee_user_id:7,monthly_salary:27000,effective_from:'2026-01-01'},
    {profile_id:1,employee_user_id:7,monthly_salary:54000,effective_from:'2026-10-20'}];
  const [item]=await calculate();assert.equal(item.monthlySalary,27000);assert.equal(item.dailyRate,1000);
});
