const assert = require('node:assert/strict');
const { test } = require('node:test');
const express = require('express');
const jwt = require('jsonwebtoken');
const { Server } = require('socket.io');
const WebSocket = require('ws');
const mysql = require('mysql2/promise');

const clockFields = Array.from({ length: 10 }, (_, i) =>
  `hold_time_${i + 1} DATETIME, restart_time_${i + 1} DATETIME`).join(', ');
const deliverables = Array.from({ length: 6 }, (_, i) =>
  `complete_deliverables_${i + 1} INT, balanced_deliverables_${i + 1} INT`).join(', ');

async function seed(db) {
  for (const sql of [
    "CREATE TABLE scheduled_meetings (id INT AUTO_INCREMENT PRIMARY KEY, title VARCHAR(255), meeting_time VARCHAR(255), meeting_link TEXT, host_name VARCHAR(255), attendees LONGTEXT, `groups` LONGTEXT, status ENUM('Active','Completed','Rejected') DEFAULT 'Active', created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)",
    'CREATE TABLE chat_groups (id INT AUTO_INCREMENT PRIMARY KEY, group_name VARCHAR(255), members LONGTEXT, created_by VARCHAR(255), admins LONGTEXT)',
    'CREATE TABLE notifications (id INT AUTO_INCREMENT PRIMARY KEY, sender_name VARCHAR(255), recipient_name VARCHAR(255), message TEXT, is_group TINYINT, is_seen TINYINT)',
    'CREATE TABLE employee_users (id INT PRIMARY KEY, full_name VARCHAR(255), role VARCHAR(50))',
    `CREATE TABLE task_list (id INT PRIMARY KEY, employee_id INT, employee_name VARCHAR(255), client_name VARCHAR(100), employee_role VARCHAR(50), deliverables VARCHAR(255), ${deliverables})`,
    `CREATE TABLE time_tracking_task_items (id INT PRIMARY KEY, task_list_id INT, status VARCHAR(20), review_status VARCHAR(20), comment TEXT, performance VARCHAR(20), duration_secs INT DEFAULT 0, start_time DATETIME, complete_time DATETIME, reject_time DATETIME, submit_date DATE, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, ${clockFields})`,
    `CREATE TABLE day_plan_rows (id INT PRIMARY KEY, employee_name VARCHAR(255), plan_date DATE, client_name VARCHAR(100), today_plan TEXT, report_type VARCHAR(20), status VARCHAR(20), total_working_secs INT, ${deliverables})`,
    'CREATE TABLE content_calendar (id INT PRIMARY KEY, client_name VARCHAR(100), deliverable VARCHAR(255), task_item_id INT, source_assignment_id INT, source_role VARCHAR(50), source_task_index INT, source_active TINYINT, is_emergency TINYINT, cc_handoff_at DATETIME, cc_prepared_by_id INT, cc_prepared_by_name VARCHAR(255), cc_status VARCHAR(20), cc_last_activity_at DATETIME)',
    'CREATE TABLE manager_review (id INT AUTO_INCREMENT PRIMARY KEY, tracking_item_id INT, manager_action VARCHAR(50), reviewed_at DATETIME)',
    'CREATE TABLE live_tracking_history (id INT AUTO_INCREMENT PRIMARY KEY, task_list_id INT, tracking_item_id INT, employee_name VARCHAR(255), client_name VARCHAR(100), task VARCHAR(255), status VARCHAR(20), started_at DATETIME, ended_at DATETIME, duration_secs INT, manager_action VARCHAR(50), manager_comment TEXT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)',
    "INSERT INTO employee_users VALUES (1,'Organizer','Manager'),(2,'Ravi','Developer'),(3,'Meera','Developer'),(4,'Asha','Developer'),(5,'Organizer','Developer')",
    "INSERT INTO chat_groups (group_name, members, created_by, admins) VALUES ('Design','[\"Ravi\",\"Meera\"]','Organizer','[\"Organizer\"]'), ('Product','[\"Ravi\",\"Asha\"]','Organizer','[\"Organizer\"]')",
    "INSERT INTO task_list (id,employee_id,employee_name,client_name,deliverables) VALUES (20,2,'Ravi','Portal','Implementation')",
    "INSERT INTO time_tracking_task_items (id,task_list_id,status) VALUES (21,20,'IDLE'), (22,20,'IDLE')",
    "INSERT INTO day_plan_rows (id,employee_name,plan_date,client_name,today_plan,report_type) VALUES (1,'Ravi',CURDATE(),'Portal','[Task Row #21]','Morning'), (2,'Ravi',CURDATE(),'Portal','[Task Row #22]','Morning')",
    "INSERT INTO scheduled_meetings (title, meeting_time, host_name, attendees, `groups`, status) VALUES ('Legacy future','2035-07-15 9:00 AM','Organizer','[\"Meera\"]','[]','Active')",
  ]) await db.query(sql);
}

test('meeting routes and task routes preserve independent tracking in MySQL', {
  skip: process.env.MEETING_MYSQL_TEST !== '1',
  timeout: 60000,
}, async (t) => {
  const options = {
    host: process.env.DB_HOST || '127.0.0.1',
    port: Number(process.env.DB_PORT || 3306),
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
  };
  const admin = await mysql.createConnection(options);
  const database = `codex_meeting_test_${process.pid}_${Date.now()}`;
  const db = mysql.createPool({ ...options, database });
  t.after(async () => {
    await db.end();
    await admin.query('DROP DATABASE IF EXISTS ??', [database]);
    await admin.end();
  });
  await admin.query('CREATE DATABASE ??', [database]);
  await seed(db);

  const dbModule = require.resolve('../config/db');
  require.cache[dbModule] = { exports: db };
  let now = Date.parse('2035-07-14T02:30:00Z');
  t.mock.method(Date, 'now', () => now);
  const sync = require('../lib/meetingSync');
  const scheduled = require.resolve('../jobs/meeting-scheduler');
  const chat = require.resolve('../routes/chat');
  const tracking = require('../routes/tracking-items');
  const users = ['Organizer', 'Ravi', 'Meera', 'Asha', 'Organizer'];
  const secret = 'meeting-integration-test';
  const tokens = users.map((fullName, index) => jwt.sign({ id: index + 1, fullName }, secret));
  const events = [];

  function connect(port, user) {
    return new Promise((resolve, reject) => {
      const socket = new WebSocket(`ws://127.0.0.1:${port}/socket.io/?EIO=4&transport=websocket`);
      socket.on('error', reject);
      socket.on('message', (data) => {
        const frame = data.toString();
        if (frame.startsWith('0')) socket.send('40' + JSON.stringify({ token: tokens[user - 1] }));
        if (frame === '2') socket.send('3');
        if (frame.startsWith('40')) resolve(socket);
        if (frame.startsWith('44')) reject(new Error(frame));
      });
    });
  }

  function waitForMeetingUpdate(socket, id, action) {
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        socket.off('message', receive);
        reject(new Error('No meeting update for ' + action));
      }, 5000);
      function receive(data) {
        const frame = data.toString();
        if (!frame.startsWith('42')) return;
        const [event, payload] = JSON.parse(frame.slice(2));
        if (event !== 'meeting_tracking_updated' || payload.meetingId !== id || payload.action !== action) return;
        socket.off('message', receive);
        clearTimeout(timer);
        resolve(payload);
      }
      socket.on('message', receive);
    });
  }

  async function boot() {
    delete require.cache[require.resolve('./ensureMeetingSchema')];
    delete require.cache[require.resolve('./meetingSync')];
    delete require.cache[scheduled];
    delete require.cache[chat];
    const app = express();
    app.use(express.json());
    app.use((req, res, next) => {
      try {
        req.user = jwt.verify(req.headers.authorization?.split(' ')[1], secret);
        next();
      } catch {
        res.sendStatus(401);
      }
    });
    app.use('/chat', require(chat));
    app.use('/tasks', tracking);
    const server = await new Promise((resolve) => {
      const listener = app.listen(0, '127.0.0.1', () => resolve(listener));
    });
    const io = new Server(server);
    io.use((socket, next) => {
      try {
        socket.data.user = jwt.verify(socket.handshake.auth.token, secret);
        next();
      } catch {
        next(new Error('Sign in to connect'));
      }
    });
    io.on('connection', (socket) => events.push(['connected', socket.data.user.id]));
    const emit = io.emit.bind(io);
    io.emit = (...event) => {
      events.push(event);
      return emit(...event);
    };
    app.set('io', io);
    server.meetingIo = io;
    await require(scheduled).refreshMeetingSchedules(io);
    t.after(() => { io.close(); });
    return server;
  }
  let server = await boot();

  async function request(path, { user = 1, method = 'GET', body, expected = 200 } = {}) {
    const response = await fetch(`http://127.0.0.1:${server.address().port}${path}`, {
      method, headers: { authorization: 'Bearer ' + tokens[user - 1], 'content-type': 'application/json' },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const result = await response.json();
    assert.equal(response.status, expected, JSON.stringify(result));
    return result;
  }

  const meetings = async (user) => (await request('/chat/meetings/scheduled', { user })).data;
  const live = async (user, date = '2035-07-14') =>
    (await request(`/chat/meetings/live/${users[user - 1]}?date=${date}`, { user })).data;
  const create = async (body) => (await request('/chat/meetings', {
    method: 'POST', expected: 201, body: { title: 'Planning', meetingLink: 'https://example.test/meeting', ...body },
  })).meetingId;
  const edit = (id, body, user = 1, expected = 200) => request(`/chat/meetings/${id}`, { method: 'PATCH', body, user, expected });

  assert.equal(sync.resolveSchedule({ startAt: '2035-07-14T03:30:00Z', durationMins: 30 }).startAt, '2035-07-14 09:00:00');
  for (const fields of [
    { startAt: '2035-02-30 09:00' }, { startAt: '2035-07-14 25:00' },
    { startAt: '2035-07-14 09:00', endAt: '2035-07-14 08:59' },
    { startAt: '2035-07-14 09:00', durationMins: 0 },
  ]) assert.throws(() => sync.resolveSchedule(fields), { statusCode: 400 });
  assert.equal((await meetings(3))[0].status, 'Scheduled');
  assert.equal((await live(3, '2035-07-15'))[0].scheduledStart, '2035-07-15 09:00:00');

  const organizerSocket = await connect(server.address().port, 1);
  const participantSocket = await connect(server.address().port, 3);
  t.after(() => { organizerSocket.terminate(); participantSocket.terminate(); });
  const shared = await create({ startAt: '2035-07-14 08:20', durationMins: 10, selectedPersons: ['Meera'] });
  assert.equal((await meetings(1)).find((row) => row.id === shared).can_manage, true);
  assert.equal((await meetings(3)).find((row) => row.id === shared).can_manage, false);
  await request(`/chat/meetings/${shared}/start`, { user: 3, method: 'POST', expected: 403 });
  const activate = waitForMeetingUpdate(participantSocket, shared, 'active');
  await request(`/chat/meetings/${shared}/start`, { method: 'POST' });
  await activate;
  assert.equal((await live(3)).find((row) => row.meetingId === shared).status, 'ACTIVE');
  const complete = waitForMeetingUpdate(participantSocket, shared, 'completed');
  await request(`/chat/meetings/${shared}/status`, { method: 'PATCH', body: { status: 'Completed' } });
  await complete;
  assert.equal((await live(3)).find((row) => row.meetingId === shared).status, 'COMPLETED');
  assert.ok(events.some(([event, id]) => event === 'connected' && id === 1));
  assert.ok(events.some(([event, id]) => event === 'connected' && id === 3));
  organizerSocket.terminate();
  participantSocket.terminate();

  const individual = await create({ startAt: '2035-07-14 08:30', durationMins: 45, selectedPersons: ['Meera'] });
  assert.equal((await live(3)).find((row) => row.meetingId === individual).status, 'SCHEDULED');
  assert.equal((await live(2)).length, 0);
  await request(`/chat/meetings/${individual}/complete`, { method: 'PATCH', expected: 409 });
  await request(`/chat/meetings/${individual}/start`, { user: 3, method: 'POST', expected: 403 });
  await request(`/chat/meetings/${individual}/start`, { method: 'POST' });
  assert.equal((await live(3)).find((row) => row.meetingId === individual).startedAt, '2035-07-14 08:00:00');
  await request(`/chat/meetings/${individual}/status`, { method: 'PATCH', body: { status: 'Rejected' } });
  assert.equal((await live(3)).find((row) => row.meetingId === individual).status, 'CANCELLED');
  assert.equal((await meetings(3)).find((meeting) => meeting.id === individual).status, 'Rejected');

  const group = await create({
    startAt: '2035-07-14 10:00', durationMins: 30,
    selectedPersons: ['Ravi', ' ravi '], selectedGroups: ['Design', 'Product'],
  });
  const ravi = (await live(2))[0];
  assert.equal(ravi.meetingId, group);
  assert.equal((await live(2)).length, 1);
  assert.equal((await live(4)).length, 1);
  await edit(group, { title: 'Rollback', groups: ['Missing'] }, 1, 400);
  assert.equal((await meetings(4)).find((meeting) => meeting.id === group).title, 'Planning');
  await edit(group, { title: 'Spoofed', requesterName: 'Organizer' }, 5, 403);
  await request('/chat/meetings/live/Ravi', { user: 3, expected: 403 });
  await edit(group, { startAt: '2035-07-15 10:00', durationMins: 20, groups: ['Design'], details: 'Updated' });
  assert.equal((await live(2)).length, 0);
  assert.equal((await live(2, '2035-07-15'))[0].scheduledEnd, '2035-07-15 10:20:00');
  assert.equal((await meetings(4)).some((meeting) => meeting.id === group), false);
  await request('/chat/groups/1', { method: 'PATCH', body: { groupName: 'Design Team', members: ['Ravi', 'Asha'] } });
  assert.equal((await meetings(3)).some((meeting) => meeting.id === group), false);
  assert.equal((await meetings(4)).find((meeting) => meeting.id === group).meeting_details, 'Updated');
  assert.equal((await live(4, '2035-07-15'))[0].details, 'Updated');

  now = Date.parse('2035-07-15T04:30:00Z');
  await require(scheduled).runMeetingScheduler(server.meetingIo);
  assert.equal((await live(2, '2035-07-15'))[0].status, 'SCHEDULED');
  assert.equal((await live(4, '2035-07-15'))[0].status, 'SCHEDULED');
  await request(`/chat/meetings/${group}/start`, { user: 2, method: 'POST', expected: 403 });
  await request(`/chat/meetings/${group}/start`, { method: 'POST' });
  assert.equal((await live(4, '2035-07-15'))[0].status, 'ACTIVE');
  now += 67000;
  const active = (await live(2, '2035-07-15'))[0];
  assert.equal(active.sessionId, ravi.sessionId);
  assert.equal(active.status, 'ACTIVE');
  assert.equal(active.startedAt, '2035-07-15 10:00:00');
  assert.equal(active.durationSecs, 67);
  for (const [action, body] of [
    ['start', {}], ['hold', { reason: 'Test hold' }], ['restart', {}], ['complete', { performance: 'GOOD' }],
  ]) {
    await request(`/tasks/21/${action}`, { user: 2, method: 'POST', body });
    assert.deepEqual((await live(2, '2035-07-15'))[0], active);
  }
  await request('/tasks/22/start', { user: 2, method: 'POST', body: {} });

  now += 60000;
  await edit(group, { attendees: [], groups: ['Product'] });
  // Ravi is still in Product, so swapping groups leaves his timer intact.
  assert.equal((await live(2, '2035-07-15'))[0].durationSecs, 127);
  await edit(group, { attendees: ['Asha'], groups: [] });
  assert.equal((await live(2, '2035-07-15'))[0].status, 'CANCELLED');
  now += 60000;
  await edit(group, { attendees: ['Ravi', 'Asha'] });
  const rejoined = (await live(2, '2035-07-15'))[0];
  assert.equal(rejoined.sessionId, active.sessionId);
  assert.equal(rejoined.startedAt, active.startedAt);
  assert.equal(rejoined.durationSecs, 127);

  // Boot a new route/scheduler instance against the same persistent database.
  await new Promise((resolve) => server.meetingIo.close(resolve));
  now += 60000;
  server = await boot();
  const afterRestart = (await live(2, '2035-07-15'))[0];
  assert.equal(afterRestart.durationSecs, 187);
  assert.deepEqual((await live(2, '2035-07-15'))[0], afterRestart);
  await request(`/chat/meetings/${group}/complete`, { method: 'PATCH' });
  const completed = (await live(2, '2035-07-15'))[0];
  assert.equal(completed.status, 'COMPLETED');
  assert.equal(completed.durationSecs, 187);
  const recorded = await require('./meetingSync').meetingWork(
    'Ravi', new Date('2035-07-14T18:30:00Z'), new Date(now), new Date('2035-07-15T18:30:00Z'),
  );
  assert.deepEqual(recorded.intervals, [
    [Date.parse('2035-07-15T04:30:00Z'), Date.parse('2035-07-15T04:32:07Z')],
    [Date.parse('2035-07-15T04:33:07Z'), Date.parse('2035-07-15T04:34:07Z')],
  ]);
  assert.equal(recorded.runningUntil, 0);
  assert.equal(completed.endedAt, '2035-07-15 10:04:07');
  const [[task]] = await db.query('SELECT status FROM time_tracking_task_items WHERE id = 22');
  assert.equal(task.status, 'IN PROGRESS');
  const [[history]] = await db.query('SELECT status FROM live_tracking_history WHERE tracking_item_id = 21');
  assert.equal(history.status, 'COMPLETED');

  const automatic = await create({ startAt: '2035-07-15 10:10', durationMins: 10, selectedGroups: ['Product'] });
  now = Date.parse('2035-07-15T04:42:00Z');
  const late = (await live(2, '2035-07-15')).find((row) => row.meetingId === automatic);
  assert.equal(late.status, 'SCHEDULED');
  await request(`/chat/meetings/${automatic}/start`, { method: 'POST' });
  await new Promise((resolve) => server.meetingIo.close(resolve));
  now = Date.parse('2035-07-15T04:55:00Z');
  server = await boot();
  const recovered = (await live(2, '2035-07-15')).find((row) => row.meetingId === automatic);
  assert.equal(recovered.status, 'COMPLETED');
  assert.equal(recovered.startedAt, '2035-07-15 10:12:00');
  assert.equal(recovered.endedAt, '2035-07-15 10:20:00');
  assert.equal(recovered.durationSecs, 480);
  assert.ok(events.some(([name, payload]) => name === 'meeting_tracking_updated' && payload.closed > 0));
  const [[duplicates]] = await db.query(
    'SELECT COUNT(*) AS n FROM meeting_tracking_sessions WHERE meeting_id = ? AND employee_name = ?', [group, 'Ravi'],
  );
  assert.equal(duplicates.n, 1);
});
