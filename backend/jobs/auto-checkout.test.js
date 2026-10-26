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
