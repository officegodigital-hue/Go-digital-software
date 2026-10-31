'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const policy = require('../lib/attendancePolicy');

function loadJob(query, shiftEnd = '18:30:00') {
  const module = { exports: {} };
  vm.runInNewContext(fs.readFileSync(require.resolve('./auto-checkout'), 'utf8'), {
    module,
    console,
    Date,
    require: path => {
      if (path === '../config/db') return { query };
      if (path === '../lib/attendancePolicy') return {
        ...policy,
        todayIstDate: () => '2026-10-26',
        nowIstDateTime: () => '2026-10-26 23:59:00',
        getTimeSettings: async () => ({ shiftEnd }),
      };
      return require(path);
    },
  });
  return module.exports;
}

test('11:59 PM auto-close saves admin shift end but audits the real close time', async () => {
  const calls = [];
  const query = async (sql, params) => {
    calls.push({ sql, params });
    if (sql.includes('FROM attendance_records')) return [[{
      id: 12,
      employee_id: 7,
      check_in_at: '2026-10-26 09:30:00',
    }]];
    if (sql.includes('SUM(duration_minutes)')) return [[{ total: 60 }]];
    return [{ affectedRows: 1 }];
  };

  const result = await loadJob(query).runEndOfDayClose();
  assert.equal(result.closed, 1);

  const attendance = calls.find(call => call.sql.includes('UPDATE attendance_records'));
  assert.deepEqual(Array.from(attendance.params), ['2026-10-26 18:30:00', 480, 12]);

  const audit = calls.find(call => call.sql.includes('INSERT INTO hrms_attendance_checkout_audit'));
  assert.equal(audit.params[2], 'end_of_day_auto_close');
  assert.equal(audit.params[3], '2026-10-26 23:59:00');
});

test('11:59 PM auto-close follows a changed admin shift end', async () => {
  const calls = [];
  const query = async (sql, params) => {
    calls.push({ sql, params });
    if (sql.includes('FROM attendance_records')) return [[{
      id: 20,
      employee_id: 9,
      check_in_at: '2026-10-26 09:30:00',
    }]];
    if (sql.includes('SUM(duration_minutes)')) return [[{ total: 30 }]];
    return [{ affectedRows: 1 }];
  };

  await loadJob(query, '17:30:00').runEndOfDayClose();
  const attendance = calls.find(call => call.sql.includes('UPDATE attendance_records'));
  assert.deepEqual(Array.from(attendance.params), ['2026-10-26 17:30:00', 450, 20]);
});

test('other automatic checkout paths still use their actual event time', async () => {
  assert.equal(
    loadJob(async () => [[]]).shiftEndForDate('2026-10-26', '18:30:00', '2026-10-26 23:59:00'),
    '2026-10-26 18:30:00'
  );
  assert.equal(
    loadJob(async () => [[]]).shiftEndForDate('2026-10-26', 'invalid', '2026-10-26 23:59:00'),
    '2026-10-26 23:59:00'
  );
});

test('automatic checkout uses changed admin grace and GPS timeout instead of old defaults', async () => {
  const writes = [];
  const settings = { office_outside_radius_grace_minutes: 9, home_outside_radius_grace_minutes: 11,
    office_no_gps_timeout_minutes: 13, home_no_gps_timeout_minutes: 17 };
  const query = async (sql, params) => {
    if (sql.includes('FROM attendance_records')) return [[{ id: 12, employee_id: 7, work_mode: 'Office', check_in_at: '2026-10-26 09:00:00' }]];
    if (sql.includes('FROM hrms_tracking_settings')) return [[settings]];
    if (sql.includes('SELECT left_at')) return [[{ left_at: '2026-10-26 23:51:00' }]];
    if (sql.includes('SELECT recorded_at')) return [[{ recorded_at: '2026-10-26 23:50:00' }]];
    if (sql.includes('FROM attendance_breaks')) return [[]];
    if (sql.includes('SUM(duration_minutes)')) return [[{ total: 0 }]];
    writes.push({ sql, params });
    return [{ affectedRows: 1 }];
  };
  const job = loadJob(query);
  assert.equal((await job.runAutoCheckout()).checked, 0);
  settings.office_outside_radius_grace_minutes = 7;
  assert.equal((await job.runAutoCheckout()).checked, 1);
  assert.ok(writes.some(w => w.sql.includes('UPDATE attendance_records')));
  writes.length = 0;
  settings.office_outside_radius_grace_minutes = 100;
  settings.office_no_gps_timeout_minutes = 8;
  assert.equal((await job.runAutoCheckout()).checked, 1);
  assert.ok(writes.some(w => w.sql.includes('INSERT INTO hrms_attendance_checkout_audit') && w.params[2] === 'no_gps_auto_checkout'));
});

test('missing checkout configuration never silently uses five or thirty minutes', async () => {
  const query = async sql => {
    if (sql.includes('FROM attendance_records')) return [[{ id: 12, employee_id: 7, work_mode: 'Office' }]];
    if (sql.includes('FROM hrms_tracking_settings')) return [[{ office_outside_radius_grace_minutes: null }]];
    assert.fail('Unconfigured policy must not reach checkout writes');
  };
  await assert.rejects(loadJob(query).runAutoCheckout(), /Admin must configure/);
});
