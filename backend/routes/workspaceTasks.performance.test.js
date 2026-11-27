const assert = require('node:assert/strict');
const fs = require('node:fs');
const { test } = require('node:test');
const vm = require('node:vm');
const performanceWork = require('../lib/performanceWork');
const employmentDates = require('../lib/employmentDates');

test('performance joins attendance, overlapping workspace sessions and permitted admin work', async () => {
  const date = '2026-11-27';
  const at = (time) => new Date(`${date}T${time}+05:30`);
  class FixedDate extends Date {
    constructor(...args) { super(...(args.length ? args : [at('16:00:00')])); }
    static now() { return +at('16:00:00'); }
  }
  const user = (id, name, main = 0) => ({
    id, full_name: name, is_active: 1, is_main_admin: main, user_type: main ? 'admin' : 'employee',
  });
  const employees = [user(1, 'Employee'), user(2, 'Admin', 1), user(3, 'Other employee')];
  const dateWithTime = (time) => `${date} ${time}`;
  const db = {
    async query(sql, params) {
      if (sql.includes('FROM employee_users u')) return [employees];
      if (sql.includes('FROM employee_users WHERE id')) return [[employees.find((row) => row.id === params[0])]];
      if (sql.includes('FROM employee_application_access')) {
        return [[{ employee_id: 1, application: 'task_manager', access_type: 'admin', allowed_pages: '["/invoice","/client-history"]' }]];
      }
      const isToday = params?.some((value) => String(value).includes(date) || +value === +at('00:00:00'));
      if (sql.includes('FROM attendance_records') && isToday) {
        return [[{ id: 77, employee_id: 1, day: date, check_in_at: dateWithTime('09:00:00'), check_out_at: null }]];
      }
      if (sql.includes('FROM attendance_breaks')) {
        return [[{ attendance_id: 77, status: 'completed', duration_minutes: 60,
          started_at: dateWithTime('12:00:00'), ended_at: dateWithTime('13:00:00') }]];
      }
      if (sql.includes('FROM time_tracking_task_items') && isToday) {
        return [[{ id: 11, tl_employee_id: 1, status: 'COMPLETED', client_name: 'Archived Client',
          deliverables: 'Poster', expected_timing: '4 hrs', submit_date: '2026-11-28',
          start_time: at('08:00:00'), complete_time: at('11:00:00'), duration_secs: 10800 }]];
      }
      if (sql.includes('FROM tech_tasks t') && isToday) {
        return [[{ id: 22, assigned_to_id: 1, status: 'IN REVIEW', title: 'Deployment',
          task_date: '2026-11-26', project: 'Tech Project', started_at: at('10:00:00'),
          first_start_at: at('10:00:00'), ended_at: at('14:00:00'), completed_at: at('14:00:00'), end_reason: 'completed' }]];
      }
      if (sql.includes('FROM invoices') && isToday) {
        return [[{ id: 31, created_by: 1, client_name: 'Example', created_at: at('15:00:00') },
          { id: 32, created_by: 3, client_name: 'Example', created_at: at('15:00:00') }]];
      }
      if (sql.startsWith('SHOW COLUMNS FROM clients')) return [[{}, {}]];
      if (sql.includes('onboarding_completed_at >=') && isToday) {
        return [[{ id: 41, created_by: 1, client_name: 'Example', created_at: at('15:00:00') }]];
      }
      if (sql.includes('company_name AS client_name') && isToday) {
        return [[{ id: 41, created_by: 1, client_name: 'Example', created_at: at('14:00:00') }]];
      }
      return [[]];
    },
  };
  const router = () => ({
    routes: new Map(),
    get(path, ...handlers) { this.routes.set(path, handlers); },
    post() {}, put() {}, patch() {}, delete() {}, use() {},
  });
  const state = { exports: {} };
  vm.runInNewContext(fs.readFileSync(require.resolve('./workspaceTasks'), 'utf8'), {
    module: state, Date: FixedDate, process: { env: {} }, console,
    require(name) {
      if (name === 'express') return { Router: router };
      if (name === '../config/db') return db;
      if (name === '../lib/performanceWork') return performanceWork;
      if (name === '../lib/employmentDates') return employmentDates;
      return {};
    },
  });

  async function get(path, userId, query = {}) {
    let status = 200;
    let body;
    const handlers = state.exports.performance.routes.get(path);
    const req = { user: { id: userId }, query: { date, ...query } };
    const res = { status(code) { status = code; return this; }, json(value) { body = value; } };
    async function invoke(index) { await handlers[index](req, res, () => invoke(index + 1)); }
    await invoke(0);
    return { status, data: body.data };
  }

  const { data: own } = await get('/me', 1, { employeeId: 3 });
  assert.equal(own.workingHours.availableSecs, 6 * 3600);
  assert.equal(own.workingHours.productiveSecs, 4 * 3600);
  assert.equal(own.workingHours.productivityPct, 66.7);
  assert.equal(own.attendance[0].live, true);
  assert.equal(own.attendance[0].checkOut, null);
  assert.deepEqual(Array.from(own.sources, ({ label, completed }) => [label, completed]), [
    ['Employee Workspace', 1], ['Tech Workspace', 1], ['Invoices', 1], ['Client Onboarding', 1],
  ]);
  assert.match(own.performance.parts.find((part) => part.key === 'productivity').improvement, /timer/);
  assert.equal((await get('/overview', 1)).status, 403);
  assert.equal((await get('/detail', 1, { employeeId: 3 })).status, 403);
  const { data: overview } = await get('/overview', 2);
  const { data: detail } = await get('/detail', 2, { employeeId: 1 });
  assert.equal(overview.employees.find((row) => row.id === 1).performancePct, own.performance.score);
  assert.equal(overview.employees.find((row) => row.id === 3).totalTasks, 0);
  assert.equal(detail.performance.score, own.performance.score);
  assert.equal(detail.summary.early, 1);
  assert.equal(detail.summary.late, 1);
  assert.equal(detail.summary.beforeIn, 1);
});
