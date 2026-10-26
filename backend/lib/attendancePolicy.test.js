const { test } = require('node:test');
const assert = require('node:assert/strict');
const policy = require('./attendancePolicy');
const rules = {shiftStart:'09:30:00', shiftEnd:'18:30:00', lateAfter:'10:00:00', requiredWorkMinutes:540};
const row = (start,end,extra={}) => ({attendanceDate:'2026-10-24',checkInAt:`2026-10-24 ${start}`,checkOutAt:end?`2026-10-24 ${end}`:null,...extra});

test('screenshot: proper checkouts are present; departure at 18:25 is early',()=>{
  for(const [start,end,status] of [['09:32:00','18:44:00','Present'],['09:32:00','19:18:00','Present'],['09:29:00','19:46:00','Present'],['09:27:00','18:25:00','Early Exit']])
    assert.equal(policy.displayStatus(row(start,end,{status:'early_exit'}),rules),status);
});
test('break deductions do not turn proper checkouts into early departures',()=>{
  assert.equal(policy.displayStatus(row('09:30:00','18:30:00',{workingMinutes:480,status:'early_exit'}),rules),'Present');
  assert.equal(policy.displayStatus(row('09:00:00','18:29:00',{workingMinutes:569}),rules),'Early Exit');
});
test('late arrival follows current settings instead of stored flags',()=>{
  assert.equal(policy.displayStatus(row('09:32:00','18:44:00',{isLate:1,status:'late'}),rules),'Present');
  assert.equal(policy.displayStatus(row('09:32:00','18:44:00',{isLate:0}),{...rules,lateAfter:'09:30:00'}),'Late');
  assert.equal(policy.displayStatus(row('10:01:00',null),rules),'Late');
  assert.equal(policy.displayStatus(row('10:00:00',null),rules),'Present');
});
test('database Date values match SQL timestamps',()=>{
  assert.equal(policy.minutesBetween(new Date(2026,9,24,9,32),new Date(2026,9,24,18,44)),552);
  assert.equal(policy.displayStatus({checkInAt:new Date(2026,9,24,9,32),checkOutAt:new Date(2026,9,24,18,44)},rules),'Present');
});
test('overnight shifts compare checkout with the following morning',()=>{
  const overnight={...rules,shiftStart:'22:00:00',shiftEnd:'06:00:00',lateAfter:'22:15:00'};
  assert.equal(policy.displayStatus({...row('22:00:00',null),checkOutAt:'2026-10-25 06:00:00'},overnight),'Present');
  assert.equal(policy.displayStatus({...row('22:00:00',null),checkOutAt:'2026-10-25 05:59:00'},overnight),'Early Exit');
  assert.equal(policy.displayStatus({checkInAt:'2026-10-25 00:10:00',checkOutAt:'2026-10-25 06:00:00'},overnight),'Late');
});
test('manual corrections, missing attendance and leave retain their meaning',()=>{
  assert.equal(policy.displayStatus(row('09:30:00','12:00:00',{adminOverride:'present'}),rules),'Present');
  assert.equal(policy.displayStatus(row('09:30:00','19:00:00',{adminOverride:'absent'}),rules),'Absent');
  assert.equal(policy.displayStatus({},rules),'Absent');
  assert.equal(policy.displayStatus({status:'on_leave'},rules),'On Leave');
});
test('settings reload dynamically, preserve zero-minute breaks and isolate requests',async()=>{
  let end='18:30:00';
  const db={query:async sql=>{
    if(sql.startsWith('SELECT shift_start'))return [[{shift_start:'09:30:00',shift_end:end,late_after:'10:00:00',absent_after:'12:00:00',break_minutes:0}]];
    if(sql.startsWith('SELECT required_work_minutes'))return [[{required_work_minutes:540}]];
    return [[]];
  }};
  const first=await policy.getTimeSettings(db);
  assert.equal(first.breakMinutes,0);
  assert.equal(policy.displayStatus(row('09:32:00','18:44:00'),first),'Present');
  end='19:00:00';const next=await policy.getTimeSettings(db);
  assert.equal(policy.displayStatus(row('09:32:00','18:44:00'),next),'Early Exit');
  assert.equal(policy.displayStatus(row('09:32:00','18:44:00'),first),'Present');
});
