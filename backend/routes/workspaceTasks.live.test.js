const assert = require('node:assert/strict');
const fs = require('node:fs');
const { test } = require('node:test');
const vm = require('node:vm');
const { additionalMeetingSeconds } = require('../lib/meetingWorkTime');

test('workspace live-all and running share task data and account for meeting overlap', async () => {
  const routes = new Map();
  const router = {
    get(path, handler) { routes.set(path, handler); },
    post() {}, put() {}, patch() {}, delete() {}, use() {},
  };
  const now = new Date('2026-11-25T05:30:00Z');
  class FixedDate extends Date {
    constructor(...args) { super(...(args.length ? args : [now])); }
    static now() { return now.getTime(); }
  }
  const db = {
    async query(sql) {
      if (sql.includes('FROM tech_task_sessions')) {
        return [[{ task_id: 7, title: 'Task', project_name: 'Project',
          status: 'IN PROGRESS', started_at: new Date(now - 20000), ended_at: null }]];
      }
      return [[]];
    },
  };
  const state = { exports: {} };
  vm.runInNewContext(fs.readFileSync(require.resolve('./workspaceTasks'), 'utf8'), {
    module: state, Date: FixedDate, process: { env: {} }, console,
    require(name) {
      if (name === 'express') return { Router: () => router };
      if (name === '../config/db') return db;
      if (name === '../lib/meetingWorkTime') return { additionalMeetingSeconds };
      if (name === '../lib/meetingSync') {
        return { async meetingWork() {
          return { intervals: [[now - 30000, Number(now)]], runningUntil: Number(now) + 10000 };
        } };
      }
      return {};
    },
  });

  async function get(path) {
    let json;
    await routes.get(path)({ query: { employee: 'Employee', date: '2026-11-25' } }, {
      status(code) { assert.equal(code, 200); return this; },
      json(body) { json = body; },
    });
    assert.equal(json.success, true);
    return json;
  }

  const day = await get('/live-all');
  assert.equal(day.totalSecs, 20);
  assert.equal(day.data[0].title, 'Task');
  const running = await get('/running');
  assert.equal(running.totalSecs, 20);
  assert.equal(running.workingSecsWithMeetings, 30);
  assert.equal(running.running.task, 'Task');
});
