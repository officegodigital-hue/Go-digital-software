const { test } = require('node:test');
const assert = require('node:assert/strict');
const { validDate, employedOn, overlaps, finalPay, dateKey } = require('./employmentDates');
test('SQL DATE values retain their local calendar date',()=>{
  assert.equal(dateKey(new Date(2026,9,28,0,0,0)),'2026-10-28');
});
test('dates reject impossible dates and require YYYY-MM-DD', () => {
  assert.equal(validDate('2026-02-30'), false);
  assert.equal(validDate('2026-10-28'), true);
  assert.equal(validDate('28/10/2026'), false);
});
test('last working day is inclusive and rehire gap is excluded', () => {
  const periods = [{ started_on: '2026-10-01', ended_on: '2026-10-15' }, { started_on: '2026-10-25', ended_on: null }];
  assert.equal(employedOn(periods, '2026-10-15'), true);
  assert.equal(employedOn(periods, '2026-10-16'), false);
  assert.equal(employedOn(periods, '2026-10-24'), false);
  assert.equal(employedOn(periods, '2026-10-25'), true);
});
test('former employees remain eligible for overlapping historical cycles only', () => {
  const periods = [{ started_on: '2026-09-01', ended_on: '2026-10-15' }];
  assert.equal(overlaps(periods, '2026-10-01', '2026-10-31'), true);
  assert.equal(overlaps(periods, '2026-11-01', '2026-11-30'), false);
});
test('final salary uses full-cycle working-day denominator', () => {
  assert.deepEqual(finalPay(30000, 25, 15, 0), { dailyRate: 1200, deductions: 0, netPay: 18000 });
  assert.equal(finalPay(30000, 25, 15, 1.5).netPay, 16200);
  assert.equal(finalPay(30000, 25, 0, 0).netPay, 0);
  assert.equal(finalPay(30000, 0, 0, 0).netPay, 0);
});
