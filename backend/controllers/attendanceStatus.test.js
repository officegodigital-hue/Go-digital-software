const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const policy = require('../lib/attendancePolicy');

function correctionController(query) {
  const module = {exports: {}};
  vm.runInNewContext(fs.readFileSync(require.resolve('./attendanceController'), 'utf8'), {
    module, console, Date, Map, Set,
    require: path => {
      if (path === '../config/db') return {query};
      if (path === '../lib/attendancePolicy') return policy;
      return {};
    },
  });
  return module.exports;
}

test('correction times keep the recorded wall-clock time and date when serialized', async () => {
  const controller = correctionController(async sql => {
    if (sql.includes('FROM hrms_attendance_correction_requests r')) return [[{
      id: 1, attendance_date: new Date(2026, 9, 24),
      check_in_at: new Date(2026, 9, 24, 9, 32),
      check_out_at: new Date(2026, 9, 24, 18, 44),
      requested_check_in_at: new Date(2026, 9, 24, 9, 30),
      requested_check_out_at: null, created_at: new Date(2026, 9, 25, 0, 10),
    }]];
    return [[]];
  });
  let body;
  await controller.listCorrectionRequests({}, {json: result => {body = result;}});
  const item = JSON.parse(JSON.stringify(body)).data.items[0];
  assert.equal(item.attendance_date, '2026-10-24');
  assert.equal(item.check_in_at, '2026-10-24 09:32:00');
  assert.equal(item.check_out_at, '2026-10-24 18:44:00');
  assert.equal(item.requested_check_in_at, '2026-10-24 09:30:00');
  assert.equal(item.requested_check_out_at, null);
  assert.equal(item.created_at, '2026-10-25 00:10:00');
});

test('approved correction saves the requested time unchanged and deducts breaks', async () => {
  let saved;
  const controller = correctionController(async (sql, params) => {
    if (sql.startsWith('SELECT * FROM hrms_attendance_correction_requests')) return [[{
      attendance_id: 5, request_type: 'incorrect_time', status: 'pending',
      requested_check_in_at: new Date(2026, 9, 24, 9, 30),
      requested_check_out_at: new Date(2026, 9, 24, 18, 30),
    }]];
    if (sql.startsWith('SELECT check_in_at')) return [[{attendance_date: '2026-10-24'}]];
    if (sql.startsWith('SELECT shift_start')) return [[{
      shift_start: '09:30:00', shift_end: '18:30:00', late_after: '10:00:00',
    }]];
    if (sql.startsWith('SELECT required_work_minutes')) return [[{required_work_minutes: 540}]];
    if (sql.includes('SUM(duration_minutes)')) return [[{minutes: 60}]];
    if (sql.startsWith('UPDATE attendance_records SET check_in_at')) saved = params;
    return [[]];
  });
  await controller.approveCorrectionRequest({params: {id: 1}, user: {id: 9}}, {
    json: () => {}, status: code => {throw new Error(`Unexpected HTTP ${code}`);},
  });
  assert.equal(saved[0], '2026-10-24 09:30:00');
  assert.equal(saved[1], '2026-10-24 18:30:00');
  assert.equal(saved[2], 'present');
  assert.equal(saved[5], 480);
});

test('Clock Logs reloads shift settings and keeps break deductions separate from departure status', async () => {
  let end = '18:30:00';
  const record = {
    id: 1, employee_id: 7, attendance_date: '2026-10-24',
    check_in_at: new Date(2026, 9, 24, 9, 30),
    check_out_at: new Date(2026, 9, 24, 18, 30),
    working_minutes: 480, attendance_status: 'early_exit', is_late: 1,
  };
  const db = { query: async sql => {
    if (sql.startsWith('SELECT shift_start')) return [[{
      shift_start: '09:30:00', shift_end: end, late_after: '10:00:00',
      absent_after: '12:00:00', break_minutes: 60, break_grace_minutes: 5,
    }]];
    if (sql.startsWith('SELECT required_work_minutes')) return [[{required_work_minutes: 540}]];
    if (sql.startsWith('SELECT * FROM attendance_records')) return [[record]];
    if (sql.startsWith('SELECT attendance_id, id, started_at')) return [[{
      attendance_id: 1, id: 2, started_at: '2026-10-24 13:00:00',
      ended_at: '2026-10-24 14:00:00', duration_minutes: 60, status: 'completed',
    }]];
    return [[]];
  }};
  const module = {exports: {}};
  vm.runInNewContext(fs.readFileSync(require.resolve('./attendanceController'), 'utf8'), {
    module, console, Date, Map, Set,
    require: path => {
      if (path === '../config/db') return db;
      if (path === '../lib/attendancePolicy') return policy;
      if (path === '../lib/staffDirectory') return {
        listHistoricalStaff: async () => [{id: 7, full_name: 'Employee', staff_id: '7', is_active: 1}],
      };
      return {};
    },
  });
  const req = {query: {view: 'day', date: '2026-10-24'}};
  let body;
  const res = {json: value => { body = value; }, status: code => {
    throw new Error(`Unexpected HTTP ${code}`);
  }};
  await module.exports.clockLogs(req, res);
  assert.equal(body.data.items[0].status, 'Present');
  assert.equal(body.data.items[0].isLate, false);
  assert.equal(body.data.items[0].workingMinutes, 480);
  assert.equal(body.data.items[0].breakMinutes, 60);
  end = '19:00:00';
  await module.exports.clockLogs(req, res);
  assert.equal(body.data.items[0].status, 'Early Exit');
  assert.equal(body.data.items[0].workingMinutes, 480);
});
