// routes/workspaceTasks.js — Employee Workspace data
// Mount in server.js:  app.use('/api/workspace-tasks', require('./routes/workspaceTasks'));
//
//   GET   /cards?employee=                       client + deadline cards (only the employee's own tasks)
//   GET   /my-tasks?employee=&client=&date=      rows for the My Tasks table
//   POST  /my-tasks/:id/sub-rows                 Ads Handler: add 1.1, 1.2 … under a main row
//   PATCH /my-tasks/:id                          edit a nested row (description / submit date only)
//   GET   /review?employee=&client=&date=        Task Review tab
//
// Row "state" (what the UI shows):
//   IDLE | IN PROGRESS | ON HOLD | IN REVIEW (completed, waiting) | REWORK | APPROVED | REJECTED
const express = require('express');
const router = express.Router();
const db = require('../config/db');
const { touchedOn, localDay, syncDayPlanStatus } = require('../lib/dayPlanSync');
const { ensureWorkspaceTaskSchemaOnce } = require('../lib/ensureWorkspaceTaskSchema');

// Make sure the nested-row / review columns exist before any query runs.
router.use(async (req, res, next) => {
  try {
    await ensureWorkspaceTaskSchemaOnce(db);
    next();
  } catch (err) {
    console.error('Workspace schema check failed:', err.message);
    res.status(500).json({ success: false, message: `Database setup failed: ${err.message}` });
  }
});

// direct: true  → tasks go straight to the employee's My Tasks once the admin
//                 assigns them (no Content Calendar preparation).
// Otherwise the Page / Ads Handler prepares the rows in the Content Calendar
// first and they appear after "Assign All".
const ROLES = [
  { key: 'designer', label: 'Designer', emp: 'designer', tasks: 'designer_tasks' },
  { key: 'videographer', label: 'Videographer', emp: 'videographer', tasks: 'videographer_tasks' },
  { key: 'video_editor', label: 'Video Editor', emp: 'video_editor', tasks: 'video_editor_task' },
  { key: 'website_designer', label: 'Website Designer', emp: 'website_designer', tasks: 'website_designer_tasks', rich: true },
  { key: 'ui_ux_designer', label: 'UI/UX Designer', emp: 'ui_ux_designer', tasks: 'ui_ux_tasks', direct: true },
  { key: 'developer', label: 'Developer', emp: 'developer', tasks: 'developer_tasks', direct: true },
  { key: 'ads_handling', label: 'Ads Handler', emp: 'ads_handling', tasks: 'ads_platform', direct: true, nested: true },
  { key: 'page_handling', label: 'Page Handler', emp: 'page_handling', tasks: 'pages_platform', direct: true },
];

const norm = (v) => String(v ?? '').trim().replace(/\s+/g, ' ').toLowerCase();
const upper = (v) => String(v ?? '').trim().toUpperCase();
const pad = (n) => String(n).padStart(2, '0');

// "Arun .", "ARUN", "arun" all match; a cell may list several people
// ("Arun, Priya" / "Arun & Priya").
const personKey = (v) => String(v ?? '').toLowerCase().replace(/[^a-z0-9]+/g, '');
function namesEmployee(cell, employee) {
  const me = personKey(employee);
  if (!me) return false;
  return String(cell ?? '')
    .split(/,|&|\/|\band\b/i)
    .some((part) => personKey(part) === me);
}

function dateKey(value) {
  if (!value) return '';
  if (value instanceof Date) {
    if (Number.isNaN(value.getTime())) return '';
    return `${value.getFullYear()}-${pad(value.getMonth() + 1)}-${pad(value.getDate())}`;
  }
  const s = String(value).trim();
  const dmy = s.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})/);
  if (dmy) return `${dmy[3]}-${pad(dmy[2])}-${pad(dmy[1])}`;
  return s.slice(0, 10);
}

function parseTasks(value) {
  return String(value || '')
    .split(',')
    .map((entry, taskIndex) => {
      const match = entry.trim().match(/^(.*?)\s*\((\d+)\)\s*$/);
      return {
        name: (match ? match[1] : entry).trim(),
        count: match ? Number(match[2]) : 1,
        taskIndex,
      };
    })
    .filter((t) => t.name && Number.isSafeInteger(t.count) && t.count > 0);
}

function employeeFrom(req) {
  return String(
    req.query.employee || req.body?.employee || req.user?.fullName || req.user?.full_name || '',
  ).trim();
}

function workingDuration(row) {
  if (!row.start_time) return Number(row.duration_secs) || 0;
  let total = 0;
  let activeStart = new Date(row.start_time);
  for (let i = 1; i <= 10; i += 1) {
    const hold = row[`hold_time_${i}`];
    const restart = row[`restart_time_${i}`];
    if (hold && activeStart) {
      const h = new Date(hold);
      if (h > activeStart) total += Math.floor((h - activeStart) / 1000);
      activeStart = null;
    }
    if (restart) activeStart = new Date(restart);
    else if (hold) { activeStart = null; break; }
  }
  if (activeStart) {
    const end = row.complete_time ? new Date(row.complete_time) : new Date();
    if (end > activeStart) total += Math.floor((end - activeStart) / 1000);
  }
  return total;
}

function rowState(row) {
  const status = upper(row.status || 'IDLE');
  const review = upper(row.review_status);
  if (review === 'APPROVED') return 'APPROVED';
  if (status === 'REWORK') return 'REWORK';
  // Rework requested: until the employee restarts it, it is still "REWORK"
  // even if an older screen saved the status back to IDLE.
  if (review === 'REWORK' && !['IN PROGRESS', 'ON HOLD'].includes(status)) return 'REWORK';
  if (status === 'COMPLETED') return review === 'REJECTED' ? 'REJECTED' : 'IN REVIEW';
  if (status === 'REJECTED') return 'REJECTED';
  return status || 'IDLE';
}

async function activeClientSet() {
  const [rows] = await db.query('SELECT company_name FROM clients WHERE is_active = 1');
  return new Set(rows.map((r) => norm(r.company_name)));
}

async function employeeIdFor(name) {
  const [rows] = await db.query(
    'SELECT id FROM employee_users WHERE LOWER(TRIM(full_name)) = LOWER(TRIM(?)) LIMIT 1',
    [name],
  );
  return rows[0]?.id ?? null;
}

// Every (assignment, role, task) where THIS employee is the person named for that role.
async function employeeAssignments(employee, clientName = null) {
  const params = [];
  let where = 'is_assigned = 1';
  if (clientName) {
    where += ' AND LOWER(TRIM(client_name)) = LOWER(TRIM(?))';
    params.push(clientName);
  }
  const [rows] = await db.query(
    `SELECT * FROM task_assignments WHERE ${where} ORDER BY id ASC`,
    params,
  );
  const active = await activeClientSet();
  const out = [];
  for (const assignment of rows) {
    if (!active.has(norm(assignment.client_name))) continue;
    for (const role of ROLES) {
      if (!namesEmployee(assignment[role.emp], employee)) continue;
      for (const task of parseTasks(assignment[role.tasks])) {
        out.push({ assignment, role, task });
      }
    }
  }
  return out;
}

const deadlineOf = (a) => dateKey(a.deadline || a.maintenance_date);

async function findTaskList(assignmentId, taskName, employee, employeeId) {
  const [rows] = await db.query(
    `SELECT id, no_of_rows, task_timing_id, submission_date
     FROM task_list
     WHERE task_assignment_id = ?
       AND LOWER(TRIM(deliverables)) = LOWER(TRIM(?))
       AND (employee_id = ? OR LOWER(TRIM(employee_name)) = LOWER(TRIM(?)))
     ORDER BY id DESC LIMIT 1`,
    [assignmentId, taskName, employeeId ?? -1, employee],
  );
  return rows[0] || null;
}

// Page / Ads handler tasks: make sure the task_list + one tracking row per assigned count exist.
async function ensureHandlerRows(assignment, task, employee, employeeId) {
  let taskList = await findTaskList(assignment.id, task.name, employee, employeeId);
  const deadline = deadlineOf(assignment) || null;
  if (!taskList) {
    const [ins] = await db.query(
      `INSERT INTO task_list
         (task_assignment_id, employee_id, employee_name, client_name,
          deliverables, submission_date, no_of_rows)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [assignment.id, employeeId, employee, assignment.client_name, task.name, deadline, task.count],
    );
    taskList = { id: ins.insertId, no_of_rows: task.count, task_timing_id: null };
  }
  const needed = Math.max(task.count, Number(taskList.no_of_rows) || 0);
  const [existing] = await db.query(
    'SELECT s_no FROM time_tracking_task_items WHERE task_list_id = ? AND parent_item_id IS NULL',
    [taskList.id],
  );
  const have = new Set(existing.map((r) => Number(r.s_no)));
  for (let sNo = 1; sNo <= needed; sNo += 1) {
    if (have.has(sNo)) continue;
    await db.query(
      `INSERT INTO time_tracking_task_items
         (task_list_id, task_timing_id, s_no, sub_no, submit_date, task_description,
          duration_secs, comment, performance, status)
       VALUES (?, ?, ?, 0, ?, ?, 0, '', 'N/A', 'IDLE')`,
      [taskList.id, taskList.task_timing_id ?? null, sNo, deadline, task.name],
    );
  }
  return taskList;
}

const ROW_SELECT = `
  SELECT tti.*, tl.deliverables, tl.client_name, tl.employee_name,
         tl.submission_date AS tl_submission_date,
         ta.deadline AS ta_deadline, ta.maintenance_date AS ta_maintenance,
         mr.manager_action, mr.manager_comment, mr.reviewed_at
  FROM time_tracking_task_items tti
  JOIN task_list tl ON tl.id = tti.task_list_id
  LEFT JOIN task_assignments ta ON ta.id = tl.task_assignment_id
  LEFT JOIN manager_review mr ON mr.tracking_item_id = tti.id`;

// The client card / workspace date is the admin assignment's deadline, so
// filter rows by that (falling back to the list / row dates for additional
// tasks). Using only tti.submit_date hid rows saved by older screens.
const dueKey = (r) =>
  dateKey(r.ta_deadline || r.ta_maintenance || r.tl_submission_date || r.submit_date);

// Non-handler roles only see rows the Page/Ads Handler has prepared and assigned.
async function loadRows(taskListId, handedOffOnly) {
  const [rows] = await db.query(
    `${ROW_SELECT}
     WHERE tti.task_list_id = ?
       ${handedOffOnly ? 'AND (tti.content_calendar_assigned = 1 OR tti.parent_item_id IS NOT NULL)' : ''}
     ORDER BY tti.s_no ASC, tti.sub_no ASC, tti.id ASC`,
    [taskListId],
  );
  return rows;
}

const INHERITED = ['hook_headline', 'caption', 'cta', 'notes', 'publish_date'];

function shapeRows(rows) {
  const byId = new Map(rows.map((r) => [r.id, r]));
  return rows.map((r) => {
    const parent = r.parent_item_id ? byId.get(r.parent_item_id) : null;
    const pick = (field) => {
      const own = r[field];
      if (own !== null && own !== undefined && own !== '') return own;
      return parent ? parent[field] : own;
    };
    const subNo = Number(r.sub_no) || 0;
    const state = rowState(r);
    return {
      id: r.id,
      task_list_id: r.task_list_id,
      parent_item_id: r.parent_item_id,
      s_no: r.s_no,
      sub_no: subNo,
      display_no: subNo > 0 ? `${r.s_no}.${subNo}` : `${r.s_no}`,
      deliverable: r.deliverables,
      client_name: r.client_name,
      employee_name: r.employee_name || '',
      submit_date: dateKey(r.submit_date || r.tl_submission_date),
      publish_date: dateKey(pick('publish_date')),
      hook_headline: pick('hook_headline') || '',
      description_points: r.description_points || (subNo > 0 ? '' : (parent?.description_points || '')),
      caption: pick('caption') || '',
      cta: pick('cta') || '',
      notes: pick('notes') || '',
      employee_notes: r.employee_notes || '',
      description_rich: r.description_rich || '',
      task_description: r.task_description || '',
      comment: r.comment || '',
      performance: r.performance || 'N/A',
      status: upper(r.status || 'IDLE'),
      review_status: upper(r.review_status),
      state,
      current_secs: upper(r.status) === 'IN PROGRESS' ? workingDuration(r) : Number(r.duration_secs) || 0,
      start_time: r.start_time,
      complete_time: r.complete_time,
      manager_action: r.manager_action || 'ACTION',
      manager_comment: r.manager_comment || '',
      reviewed_at: r.reviewed_at,
    };
  });
}

function countStates(rows, assignedCount) {
  const counts = { approved: 0, in_review: 0, rework: 0, in_progress: 0, on_hold: 0, rejected: 0 };
  let topLevel = 0;
  let subRows = 0;
  for (const r of rows) {
    if (r.parent_item_id) subRows += 1; else topLevel += 1;
    const s = rowState(r);
    if (s === 'APPROVED') counts.approved += 1;
    else if (s === 'IN REVIEW') counts.in_review += 1;
    else if (s === 'REWORK') counts.rework += 1;
    else if (s === 'IN PROGRESS') counts.in_progress += 1;
    else if (s === 'ON HOLD') counts.on_hold += 1;
    else if (s === 'REJECTED') counts.rejected += 1;
  }
  const total = Math.max(assignedCount, topLevel) + subRows;
  const used = Object.values(counts).reduce((a, b) => a + b, 0);
  return { total, pending: Math.max(total - used, 0), ...counts };
}

async function additionalLists(employee, employeeId, clientName = null) {
  const params = [employeeId ?? -1, employee];
  let clientSql = '';
  if (clientName) {
    clientSql = 'AND LOWER(TRIM(client_name)) = LOWER(TRIM(?))';
    params.push(clientName);
  }
  const [rows] = await db.query(
    `SELECT id, client_name, deliverables, submission_date, no_of_rows
     FROM task_list
     WHERE additional_task_id IS NOT NULL
       AND (employee_id = ? OR LOWER(TRIM(employee_name)) = LOWER(TRIM(?)))
       ${clientSql}
     ORDER BY id ASC`,
    params,
  );
  const active = await activeClientSet();
  return rows.filter((r) => active.has(norm(r.client_name)));
}

// Rows moved to this employee from the Content Calendar "Edit" (they are not
// the role's named person on the admin assignment).
async function reassignedLists(employee, employeeId, coveredIds, clientName = null) {
  const params = [employeeId ?? -1, employee];
  let clientSql = '';
  if (clientName) {
    clientSql = 'AND LOWER(TRIM(tl.client_name)) = LOWER(TRIM(?))';
    params.push(clientName);
  }
  const [rows] = await db.query(
    `SELECT tl.id, tl.client_name, tl.deliverables, tl.no_of_rows,
            COALESCE(ta.deadline, ta.maintenance_date, tl.submission_date) AS due
     FROM task_list tl
     JOIN task_assignments ta ON ta.id = tl.task_assignment_id
     WHERE tl.additional_task_id IS NULL
       AND (tl.employee_id = ? OR LOWER(TRIM(tl.employee_name)) = LOWER(TRIM(?)))
       ${clientSql}
       AND EXISTS (SELECT 1 FROM time_tracking_task_items tti
                   WHERE tti.task_list_id = tl.id AND tti.content_calendar_assigned = 1)`,
    params,
  );
  const active = await activeClientSet();
  return rows.filter((r) => !coveredIds.has(r.id) && active.has(norm(r.client_name)));
}

const emit = (req, payload) => req.app.get('io')?.emit('task_updated', payload);

// ─────────────────────────────────────────────────────────────────────────────
// Everyone assigned on this client (+ deadline): role, person, and each task
// category with completed (approved) / total.
async function clientTeam(clientName, date = '') {
  const [assignments] = await db.query(
    `SELECT * FROM task_assignments
     WHERE is_assigned = 1 AND LOWER(TRIM(client_name)) = LOWER(TRIM(?))
     ORDER BY id ASC`,
    [clientName],
  );
  const idCache = new Map();
  const team = new Map();
  for (const assignment of assignments) {
    if (date && deadlineOf(assignment) !== date) continue;
    for (const role of ROLES) {
      const people = String(assignment[role.emp] || '')
        .split(/,|&/)
        .map((p) => p.trim())
        .filter((p) => p && p.toUpperCase() !== 'NONE');
      for (const person of people) {
        if (!idCache.has(personKey(person))) idCache.set(personKey(person), await employeeIdFor(person));
        const personId = idCache.get(personKey(person));
        const key = `${role.key}|${personKey(person)}`;
        const entry = team.get(key) || { role: role.label, role_key: role.key, employee: person, tasks: [] };
        for (const task of parseTasks(assignment[role.tasks])) {
          const list = await findTaskList(assignment.id, task.name, person, personId);
          const rows = list ? await loadRows(list.id, !role.direct) : [];
          const parents = rows.filter((r) => !r.parent_item_id);
          entry.tasks.push({
            name: task.name,
            completed: parents.filter((r) => rowState(r) === 'APPROVED').length,
            total: Math.max(task.count, parents.length),
          });
        }
        if (entry.tasks.length) team.set(key, entry);
      }
    }
  }
  return [...team.values()];
}

router.get('/cards', async (req, res) => {
  const employee = employeeFrom(req);
  if (!employee) return res.status(400).json({ success: false, message: 'employee is required' });
  try {
    const employeeId = await employeeIdFor(employee);
    const cards = new Map();
    const cardByAssignment = new Map(); // assignment id → card (Content Calendar)
    const cardFor = (client, date) => {
      const key = `${norm(client)}|${date}`;
      if (!cards.has(key)) {
        cards.set(key, { client_name: String(client).trim(), submission_date: date, tasks: [] });
      }
      return cards.get(key);
    };

    for (const { assignment, role, task } of await employeeAssignments(employee)) {
      const taskList = await findTaskList(assignment.id, task.name, employee, employeeId);
      const rows = taskList ? await loadRows(taskList.id, !role.direct) : [];
      const card = cardFor(assignment.client_name, deadlineOf(assignment));
      cardByAssignment.set(String(assignment.id), card);
      // Latest assignment time → the "NEW" ribbon on the card.
      const created = assignment.created_at ? new Date(assignment.created_at) : null;
      if (created && !Number.isNaN(created.getTime()) &&
          (!card.assigned_at || created > new Date(card.assigned_at))) {
        card.assigned_at = created.toISOString();
      }
      card.tasks.push({
        key: `${assignment.id}:${role.key}:${task.taskIndex}`,
        task_list_id: taskList?.id ?? null,
        name: task.name,
        role: role.label,
        role_key: role.key,
        is_additional: false,
        awaiting_handoff: !role.direct && rows.length === 0,
        ...countStates(rows, task.count),
      });
    }

    const coveredIds = new Set();
    for (const card of cards.values()) for (const t of card.tasks) if (t.task_list_id) coveredIds.add(t.task_list_id);
    for (const list of await reassignedLists(employee, employeeId, coveredIds)) {
      const rows = await loadRows(list.id, true);
      cardFor(list.client_name, dateKey(list.due)).tasks.push({
        key: `reassigned:${list.id}`,
        name: list.deliverables,
        role: 'Reassigned task',
        role_key: 'reassigned',
        is_additional: false,
        awaiting_handoff: false,
        ...countStates(rows, rows.length),
      });
    }

    for (const list of await additionalLists(employee, employeeId)) {
      const rows = await loadRows(list.id, false);
      cardFor(list.client_name, dateKey(list.submission_date)).tasks.push({
        key: `additional:${list.id}`,
        name: list.deliverables,
        role: 'Additional task',
        role_key: 'additional',
        is_additional: true,
        awaiting_handoff: false,
        ...countStates(rows, Number(list.no_of_rows) || 1),
      });
    }

    // Content Calendar categories this handler prepares count as one task
    // each — a running category makes the card PROCESSING, a held one HOLD.
    try {
      const sheets = await employeeSheets(employee, null, { includeStartable: true });
      for (const sh of sheets) {
        if (!sh.source_assignment_id) continue;
        const card = cardByAssignment.get(String(sh.source_assignment_id)) ||
          [...cards.values()].find((c) => norm(c.client_name) === norm(sh.client) &&
            c.submission_date === sh.due_date);
        if (!card) continue;
        const st = upper(sh.status);
        const done = st === 'ASSIGNED' || st === 'COMPLETED';
        card.tasks.push({
          key: sh.key,
          task_list_id: null,
          name: `Content Calendar · ${sh.deliverable}`,
          role: 'Content Calendar',
          role_key: 'content_calendar',
          is_additional: false,
          awaiting_handoff: false,
          total: 1,
          approved: done ? 1 : 0,
          in_progress: st === 'IN PROGRESS' ? 1 : 0,
          on_hold: st === 'ON HOLD' ? 1 : 0,
          in_review: 0,
          rework: 0,
          rejected: 0,
          pending: !done && st !== 'IN PROGRESS' && st !== 'ON HOLD' ? 1 : 0,
        });
      }
    } catch (err) {
      console.error('cards: content calendar summary failed:', err.message);
    }

    // Ads / Page Handler: how much team work on this client+date waits for them.
    const reviewerClients = new Set();
    for (const card of cards.values()) {
      if (!reviewerClients.has(norm(card.client_name))) {
        const ids = await reviewerAssignmentIds(employee, card.client_name);
        if (ids.length) reviewerClients.add(norm(card.client_name));
      }
    }
    for (const card of cards.values()) {
      card.to_review = 0;
      if (!reviewerClients.has(norm(card.client_name))) continue;
      const review = await buildReview(employee, card.client_name, card.submission_date);
      card.to_review = review.team.filter((r) => r.review_state === 'PENDING').length;
    }

    // Whole team on each card (all roles, people and categories).
    for (const card of cards.values()) {
      card.team = await clientTeam(card.client_name, card.submission_date);
    }

    const data = [...cards.values()].sort(
      (a, b) => a.client_name.localeCompare(b.client_name) ||
        a.submission_date.localeCompare(b.submission_date),
    );
    return res.json({ success: true, data });
  } catch (err) {
    console.error('GET /workspace-tasks/cards ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

async function buildMyTasks(employee, client, date) {
    const employeeId = await employeeIdFor(employee);
    const groups = [];
    const items = (await employeeAssignments(employee, client))
      .filter(({ assignment }) => !date || deadlineOf(assignment) === date);

    for (const { assignment, role, task } of items) {
      const taskList = role.direct
        ? await ensureHandlerRows(assignment, task, employee, employeeId)
        : await findTaskList(assignment.id, task.name, employee, employeeId);
      const rows = taskList ? shapeRows(await loadRows(taskList.id, !role.direct)) : [];
      groups.push({
        key: `${assignment.id}:${role.key}:${task.taskIndex}`,
        task_list_id: taskList?.id ?? null,
        assignment_id: assignment.id,
        role: role.key,
        role_label: role.label,
        deliverable: task.name,
        nested: Boolean(role.nested),
        rich: Boolean(role.rich),
        // Page / Ads Handler, Developer, UI/UX: the employee writes the
        // headline / description and sets the submit date themselves.
        editable_content: Boolean(role.direct),
        assigned_count: task.count,
        awaiting_handoff: !role.direct && rows.length === 0,
        submission_date: deadlineOf(assignment),
        rows,
      });
    }

    const covered = new Set(groups.map((g) => g.task_list_id).filter(Boolean));
    for (const list of await reassignedLists(employee, employeeId, covered, client)) {
      if (date && dateKey(list.due) !== date) continue;
      const [[src]] = await db.query(
        `SELECT source_role FROM content_calendar WHERE task_item_id IN
           (SELECT id FROM time_tracking_task_items WHERE task_list_id = ?) LIMIT 1`,
        [list.id],
      );
      groups.push({
        key: `reassigned:${list.id}`,
        task_list_id: list.id,
        assignment_id: null,
        role: src?.source_role || 'reassigned',
        role_label: 'Reassigned task',
        deliverable: list.deliverables,
        nested: false,
        rich: src?.source_role === 'website_designer',
        assigned_count: Number(list.no_of_rows) || 0,
        awaiting_handoff: false,
        submission_date: dateKey(list.due),
        rows: shapeRows(await loadRows(list.id, true)),
      });
    }

    for (const list of await additionalLists(employee, employeeId, client)) {
      if (date && dateKey(list.submission_date) !== date) continue;
      groups.push({
        key: `additional:${list.id}`,
        task_list_id: list.id,
        assignment_id: null,
        role: 'additional',
        role_label: 'Additional task',
        deliverable: list.deliverables,
        nested: false,
        assigned_count: Number(list.no_of_rows) || 1,
        awaiting_handoff: false,
        submission_date: dateKey(list.submission_date),
        rows: shapeRows(await loadRows(list.id, false)),
      });
    }
  return groups;
}

router.get('/my-tasks', async (req, res) => {
  const employee = employeeFrom(req);
  const client = String(req.query.client || '').trim();
  const date = dateKey(req.query.date);
  if (!employee || !client) {
    return res.status(400).json({ success: false, message: 'employee and client are required' });
  }
  try {
    return res.json({ success: true, data: await buildMyTasks(employee, client, date) });
  } catch (err) {
    console.error('GET /workspace-tasks/my-tasks ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

router.post('/my-tasks/:id/sub-rows', async (req, res) => {
  const employee = employeeFrom(req);
  try {
    const [[parent]] = await db.query(
      `SELECT tti.*, tl.task_assignment_id, tl.deliverables
       FROM time_tracking_task_items tti
       JOIN task_list tl ON tl.id = tti.task_list_id
       WHERE tti.id = ?`,
      [req.params.id],
    );
    if (!parent) return res.status(404).json({ success: false, message: 'Row not found' });
    if (parent.parent_item_id) {
      return res.status(400).json({ success: false, message: 'Add nested rows from the main row' });
    }
    const [[assignment]] = parent.task_assignment_id
      ? await db.query('SELECT ads_handling, ads_platform FROM task_assignments WHERE id = ?', [parent.task_assignment_id])
      : [[null]];
    const isAdsTask = assignment &&
      namesEmployee(assignment.ads_handling, employee) &&
      parseTasks(assignment.ads_platform).some((t) => norm(t.name) === norm(parent.deliverables));
    if (!isAdsTask) {
      return res.status(403).json({ success: false, message: 'Only the Ads Handler can add nested rows to this task' });
    }

    const [[{ nextSub }]] = await db.query(
      'SELECT COALESCE(MAX(sub_no), 0) + 1 AS nextSub FROM time_tracking_task_items WHERE parent_item_id = ?',
      [parent.id],
    );
    const [ins] = await db.query(
      `INSERT INTO time_tracking_task_items
         (task_list_id, parent_item_id, task_timing_id, s_no, sub_no, submit_date,
          task_description, hook_headline, description_points, caption, cta, notes,
          publish_date, duration_secs, comment, performance, status)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, '', ?, ?, ?, ?, 0, '', 'N/A', 'IDLE')`,
      [
        parent.task_list_id, parent.id, parent.task_timing_id ?? null, parent.s_no, nextSub,
        parent.submit_date, parent.task_description || parent.deliverables,
        parent.hook_headline ?? null, parent.caption ?? null, parent.cta ?? null,
        parent.notes ?? null, parent.publish_date ?? null,
      ],
    );
    emit(req, { type: 'WORKSPACE_SUB_ROW', trackingItemId: ins.insertId });
    return res.status(201).json({
      success: true,
      message: `Row ${parent.s_no}.${nextSub} added`,
      data: { id: ins.insertId, display_no: `${parent.s_no}.${nextSub}` },
    });
  } catch (err) {
    console.error('POST /workspace-tasks/my-tasks/:id/sub-rows ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// PATCH /my-tasks/:id
//   any row  : employee_notes (the employee's own notes)
//   nested   : description_points, submit_date
router.patch('/my-tasks/:id', async (req, res) => {
  try {
    const [[row]] = await db.query(
      `SELECT id, parent_item_id, review_status, content_calendar_assigned
       FROM time_tracking_task_items WHERE id = ?`,
      [req.params.id],
    );
    if (!row) return res.status(404).json({ success: false, message: 'Row not found' });
    if (upper(row.review_status) === 'APPROVED') {
      return res.status(409).json({ success: false, message: 'This row is approved and can no longer be changed' });
    }
    const sets = [];
    const values = [];
    if (Object.hasOwn(req.body, 'employee_notes')) {
      sets.push('employee_notes = ?');
      values.push(String(req.body.employee_notes ?? '').slice(0, 5000));
    }
    // Content prepared by the handler in the Content Calendar stays read-only;
    // rows the employee owns directly (and nested Ads rows) are editable.
    const contentFields = ['hook_headline', 'description_points', 'submit_date'].filter((k) => Object.hasOwn(req.body, k));
    if (contentFields.length && !row.parent_item_id && Number(row.content_calendar_assigned) === 1) {
      return res.status(403).json({
        success: false,
        message: 'This content was prepared in the Content Calendar — ask the Page / Ads Handler to correct it',
      });
    }
    if (Object.hasOwn(req.body, 'hook_headline')) {
      sets.push('hook_headline = ?');
      values.push(String(req.body.hook_headline ?? '').slice(0, 5000));
    }
    if (Object.hasOwn(req.body, 'description_points')) {
      const text = String(req.body.description_points ?? '');
      sets.push('description_points = ?', 'task_description = ?');
      values.push(text, text);
    }
    if (Object.hasOwn(req.body, 'submit_date')) {
      const d = dateKey(req.body.submit_date);
      if (!/^\d{4}-\d{2}-\d{2}$/.test(d)) {
        return res.status(400).json({ success: false, message: 'submit_date must be YYYY-MM-DD' });
      }
      sets.push('submit_date = ?');
      values.push(d);
    }
    if (!sets.length) return res.status(400).json({ success: false, message: 'Nothing to update' });
    await db.query(`UPDATE time_tracking_task_items SET ${sets.join(', ')} WHERE id = ?`, [...values, row.id]);
    emit(req, { type: 'WORKSPACE_ROW_EDIT', trackingItemId: row.id });
    return res.json({ success: true, message: 'Row updated' });
  } catch (err) {
    console.error('PATCH /workspace-tasks/my-tasks/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

function reviewState(r) {
  if (r.state === 'APPROVED') return 'APPROVED';
  if (r.state === 'REJECTED') return 'REJECTED';
  if (r.review_status === 'REWORK' || r.state === 'REWORK') return 'REWORK';
  return 'PENDING';
}

const REVIEW_WHERE = `(tti.status IN ('COMPLETED', 'REWORK')
  OR UPPER(COALESCE(tti.review_status, '')) IN ('APPROVED', 'REWORK', 'REJECTED', 'PENDING'))`;

// Roles whose holder may approve / rework / reject the team's work for a client.
const REVIEWER_ROLES = ['ads_handling', 'page_handling'];

// Assignments (for this client) where the employee is the Ads/Page Handler.
async function reviewerAssignmentIds(employee, client) {
  const params = [];
  let clientSql = '';
  if (client) {
    clientSql = 'AND LOWER(TRIM(client_name)) = LOWER(TRIM(?))';
    params.push(client);
  }
  const [rows] = await db.query(
    `SELECT id, ${REVIEWER_ROLES.join(', ')} FROM task_assignments WHERE is_assigned = 1 ${clientSql}`,
    params,
  );
  return rows
    .filter((a) => REVIEWER_ROLES.some((role) => namesEmployee(a[role], employee)))
    .map((a) => a.id);
}

// GET /review — { data: my own reviewed rows, team: rows I can review }
async function buildReview(employee, client, date) {
    const employeeId = await employeeIdFor(employee);
    const params = [employeeId ?? -1, employee];
    let clientSql = '';
    if (client) {
      clientSql = 'AND LOWER(TRIM(tl.client_name)) = LOWER(TRIM(?))';
      params.push(client);
    }
    const byDate = (r) => !date || dueKey(r) === date;

    const [rows] = await db.query(
      `${ROW_SELECT}
       WHERE ${REVIEW_WHERE}
         AND (tl.employee_id = ? OR LOWER(TRIM(tl.employee_name)) = LOWER(TRIM(?)))
         ${clientSql}
       ORDER BY COALESCE(tti.complete_time, tti.updated_at) DESC, tti.id DESC`,
      params,
    );
    const data = shapeRows(rows.filter(byDate)).map((r) => ({ ...r, review_state: reviewState(r) }));

    let team = [];
    const assignmentIds = await reviewerAssignmentIds(employee, client);
    if (assignmentIds.length) {
      const [teamRows] = await db.query(
        `${ROW_SELECT}
         WHERE ${REVIEW_WHERE}
           AND tl.task_assignment_id IN (?)
           AND NOT (tl.employee_id <=> ? OR LOWER(TRIM(tl.employee_name)) = LOWER(TRIM(?)))
         ORDER BY COALESCE(tti.complete_time, tti.updated_at) DESC, tti.id DESC`,
        [assignmentIds, employeeId ?? -1, employee],
      );
      team = shapeRows(teamRows.filter(byDate)).map((r) => ({
        ...r,
        review_state: reviewState(r),
        can_review: true,
      }));
    }
  return { data, team, is_reviewer: assignmentIds.length > 0 };
}

// GET /review — { data: my own reviewed rows, team: rows I can review }
router.get('/review', async (req, res) => {
  const employee = employeeFrom(req);
  const client = String(req.query.client || '').trim();
  const date = dateKey(req.query.date);
  if (!employee) return res.status(400).json({ success: false, message: 'employee is required' });
  try {
    return res.json({ success: true, ...(await buildReview(employee, client, date)) });
  } catch (err) {
    console.error('GET /workspace-tasks/review ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// POST /review/:id/decision { employee, action: APPROVED|REWORK|REJECTED, comment }
// Only the Ads/Page Handler of that task's client assignment may decide.
router.post('/review/:id/decision', async (req, res) => {
  const employee = employeeFrom(req);
  // PENDING puts a decided row back in the review queue.
  const action = upper(req.body.action) === 'PENDING' ? 'ACTION' : upper(req.body.action);
  const comment = String(req.body.comment ?? '').trim();
  if (!employee) return res.status(400).json({ success: false, message: 'employee is required' });
  if (!['APPROVED', 'REWORK', 'REJECTED', 'ACTION'].includes(action)) {
    return res.status(400).json({ success: false, message: 'action must be APPROVED, PENDING, REWORK or REJECTED' });
  }
  if ((action === 'REWORK' || action === 'REJECTED') && !comment) {
    return res.status(400).json({ success: false, message: 'Add a comment so the employee knows what to change' });
  }
  try {
    const [[item]] = await db.query(
      `SELECT tti.id, tti.status, tti.review_status, tl.task_assignment_id, tl.client_name
       FROM time_tracking_task_items tti
       JOIN task_list tl ON tl.id = tti.task_list_id
       WHERE tti.id = ?`,
      [req.params.id],
    );
    if (!item) return res.status(404).json({ success: false, message: 'Task row not found' });
    const allowed = await reviewerAssignmentIds(employee, item.client_name);
    if (!item.task_assignment_id || !allowed.includes(item.task_assignment_id)) {
      return res.status(403).json({ success: false, message: 'Only the Ads / Page Handler of this client can review this task' });
    }
    if (upper(item.review_status) === 'APPROVED') {
      return res.status(409).json({ success: false, message: 'This task is already approved and cannot be changed' });
    }
    const status = upper(item.status);
    if (status === 'REWORK') {
      if (action === 'REWORK') {
        return res.status(409).json({ success: false, message: 'Rework has already been requested for this task' });
      }
      // Rework not started yet → undo it so the new decision applies to the
      // completed work (the completion time comes back from the rework hold).
      const [[full]] = await db.query('SELECT * FROM time_tracking_task_items WHERE id = ?', [item.id]);
      let slot = null;
      for (let i = 10; i >= 1; i -= 1) {
        if (full[`hold_time_${i}`] && !full[`restart_time_${i}`]) { slot = i; break; }
      }
      await db.query(
        `UPDATE time_tracking_task_items
         SET status = 'COMPLETED',
             complete_time = ${slot ? `COALESCE(hold_time_${slot}, NOW())` : 'NOW()'}
             ${slot ? `, hold_time_${slot} = NULL` : ''}
         WHERE id = ?`,
        [item.id],
      );
    } else if (status !== 'COMPLETED') {
      return res.status(409).json({
        success: false,
        message: status === 'IN PROGRESS' || status === 'ON HOLD'
          ? 'The employee has already restarted this task — wait until they complete it again'
          : 'Only a completed task can be reviewed',
      });
    }
    const { recordReviewDecision } = require('./manager-review');
    await recordReviewDecision({ trackingItemId: item.id, action, comment, senderName: employee });
    req.app.get('io')?.emit('task_updated', { type: 'MANAGER_REVIEW', trackingItemId: item.id, action });
    return res.json({
      success: true,
      message: action === 'ACTION' ? 'Moved back to pending review' : `Marked ${action.toLowerCase()}`,
    });
  } catch (err) {
    console.error('POST /workspace-tasks/review/:id/decision ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// GET /counts?employee=&client=&date=
//   my_tasks.pending      rows still to do (not started / running / held / rework)
//   my_tasks.by_category  [{ name, pending }]
//   review.to_review      team rows waiting for MY decision (Ads/Page Handler)
//   review.my_in_review   my completed rows waiting for someone else
const OPEN_STATES = new Set(['IDLE', 'IN PROGRESS', 'ON HOLD', 'REWORK']);
async function buildCounts(employee, client, date) {
  const groups = await buildMyTasks(employee, client, date);
  const byCategory = [];
  let pending = 0;
  for (const g of groups) {
    const open = g.rows.filter((r) => OPEN_STATES.has(r.state)).length;
    pending += open;
    if (open) byCategory.push({ name: g.deliverable, pending: open });
  }
  const review = await buildReview(employee, client, date);
  return {
    my_tasks: { pending, by_category: byCategory },
    review: {
      is_reviewer: review.is_reviewer,
      to_review: review.team.filter((r) => r.review_state === 'PENDING').length,
      my_in_review: review.data.filter((r) => r.review_state === 'PENDING').length,
    },
  };
}

router.get('/counts', async (req, res) => {
  const employee = employeeFrom(req);
  const client = String(req.query.client || '').trim();
  const date = dateKey(req.query.date);
  if (!employee || !client) {
    return res.status(400).json({ success: false, message: 'employee and client are required' });
  }
  try {
    return res.json({ success: true, data: await buildCounts(employee, client, date) });
  } catch (err) {
    console.error('GET /workspace-tasks/counts ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ── Client team + group chat ─────────────────────────────────────────────────
// GET /team?client=  → everyone assigned on this client (any deadline)
router.get('/team', async (req, res) => {
  const client = String(req.query.client || '').trim();
  if (!client) return res.status(400).json({ success: false, message: 'client is required' });
  try {
    const team = await clientTeam(client);
    const members = new Map();
    for (const t of team) {
      const k = personKey(t.employee);
      const m = members.get(k) || { name: t.employee, roles: [] };
      if (!m.roles.includes(t.role)) m.roles.push(t.role);
      members.set(k, m);
    }
    return res.json({ success: true, data: { members: [...members.values()], team } });
  } catch (err) {
    console.error('GET /workspace-tasks/team ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

async function isClientMember(client, employee) {
  const team = await clientTeam(client);
  return team.some((t) => personKey(t.employee) === personKey(employee));
}

// GET /team/chat?client=  → client group messages (latest 300)
router.get('/team/chat', async (req, res) => {
  const client = String(req.query.client || '').trim();
  if (!client) return res.status(400).json({ success: false, message: 'client is required' });
  try {
    const [rows] = await db.query(
      `SELECT id, sender_name, message, created_at FROM workspace_client_chat
       WHERE LOWER(TRIM(client_name)) = LOWER(TRIM(?))
       ORDER BY id DESC LIMIT 300`,
      [client],
    );
    return res.json({ success: true, data: rows.reverse() });
  } catch (err) {
    console.error('GET /workspace-tasks/team/chat ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// POST /team/chat { client, employee, message } — members of the client only
router.post('/team/chat', async (req, res) => {
  const client = String(req.body.client || '').trim();
  const employee = employeeFrom(req);
  const message = String(req.body.message || '').trim().slice(0, 4000);
  if (!client || !employee || !message) {
    return res.status(400).json({ success: false, message: 'client, employee and message are required' });
  }
  try {
    if (!(await isClientMember(client, employee))) {
      return res.status(403).json({ success: false, message: 'Only employees assigned to this client can post in its group' });
    }
    const [ins] = await db.query(
      'INSERT INTO workspace_client_chat (client_name, sender_name, message) VALUES (?, ?, ?)',
      [client, employee, message],
    );
    req.app.get('io')?.emit('workspace_client_chat', { client, id: ins.insertId, sender: employee });
    return res.status(201).json({ success: true, data: { id: ins.insertId } });
  } catch (err) {
    console.error('POST /workspace-tasks/team/chat ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// GET /live — Live Tracking tab: my tracking rows + Content Calendar categories
// I am preparing (Page/Ads Handler), with running durations.
router.get('/live', async (req, res) => {
  const employee = employeeFrom(req);
  const client = String(req.query.client || '').trim();
  const date = dateKey(req.query.date);
  if (!employee || !client) {
    return res.status(400).json({ success: false, message: 'employee and client are required' });
  }
  try {
    const employeeId = await employeeIdFor(employee);
    const [rows] = await db.query(
      `${ROW_SELECT}
       WHERE (tl.employee_id = ? OR LOWER(TRIM(tl.employee_name)) = LOWER(TRIM(?)))
         AND LOWER(TRIM(tl.client_name)) = LOWER(TRIM(?))
         AND (tti.start_time IS NOT NULL OR tti.status <> 'IDLE')
       ORDER BY tti.s_no ASC, tti.sub_no ASC, tti.id ASC`,
      [employeeId ?? -1, employee, client],
    );
    const tasks = shapeRows(
      rows.filter((r) => !date || dueKey(r) === date),
    ).map((r) => ({
      kind: 'TASK',
      key: `task:${r.id}`,
      task_id: r.id,
      title: `${r.deliverable} · Row ${r.display_no}`,
      deliverable: r.deliverable,
      heading: r.hook_headline || r.task_description,
      status: r.state,
      duration_secs: r.current_secs,
      running: r.state === 'IN PROGRESS',
      started_at: r.start_time ?? null,
      completed_at: r.complete_time,
      submit_date: r.submit_date,
      review_action: r.manager_action,
      rows: 1,
    }));

    const [cc] = await db.query(
      `SELECT id, deliverable, source_assignment_id, source_role, source_task_index,
              source_row_number, submit_date, cc_status, cc_duration_secs, cc_started_at,
              cc_hold_reason, cc_last_activity_at, cc_handoff_at, assigned_to_name,
              cc_prepared_by_name
       FROM content_calendar
       WHERE LOWER(TRIM(client_name)) = LOWER(TRIM(?))
         AND source_assignment_id IS NOT NULL AND source_active = 1
         AND (cc_prepared_by_id = ? OR LOWER(TRIM(cc_prepared_by_name)) = LOWER(TRIM(?)))
       ORDER BY source_assignment_id, source_role, source_task_index, source_row_number`,
      [client, employeeId ?? -1, employee],
    );
    const sheets = new Map();
    for (const r of cc) {
      if (date && dateKey(r.submit_date) !== date) continue;
      const key = `${r.source_assignment_id}:${r.source_role}:${r.source_task_index}`;
      const sheet = sheets.get(key) || { rows: [], secs: 0, running: false, statuses: new Set() };
      sheet.rows.push(r);
      sheet.statuses.add(upper(r.cc_status || 'IDLE'));
      sheet.secs += Number(r.cc_duration_secs) || 0;
      if (r.cc_started_at && upper(r.cc_status) === 'IN PROGRESS') {
        sheet.running = true;
        sheet.secs += Math.max(Math.floor((Date.now() - new Date(r.cc_started_at)) / 1000), 0);
      }
      sheets.set(key, sheet);
    }
    const calendar = [...sheets.entries()].map(([key, sheet]) => {
      const first = sheet.rows[0];
      const statuses = sheet.statuses;
      const status = sheet.rows.every((r) => r.cc_handoff_at) ? 'ASSIGNED'
        : statuses.size === 1 ? [...statuses][0]
          : statuses.has('IN PROGRESS') ? 'IN PROGRESS'
            : statuses.has('ON HOLD') ? 'ON HOLD' : 'IN PROGRESS';
      return {
        kind: 'CONTENT_CALENDAR',
        key: `cc:${key}`,
        source_assignment_id: first.source_assignment_id,
        source_role: first.source_role,
        source_task_index: first.source_task_index,
        title: `Content Calendar · ${first.deliverable} (${sheet.rows.length} rows)`,
        deliverable: first.deliverable,
        heading: `Preparing for ${first.assigned_to_name || 'team'}`,
        status,
        duration_secs: sheet.secs,
        running: sheet.running,
        hold_reason: sheet.rows.find((r) => r.cc_hold_reason)?.cc_hold_reason || '',
        last_activity_at: sheet.rows.reduce(
          (m, r) => (r.cc_last_activity_at && (!m || r.cc_last_activity_at > m) ? r.cc_last_activity_at : m), null),
        submit_date: dateKey(first.submit_date),
        rows: sheet.rows.length,
      };
    });

    return res.json({ success: true, data: [...calendar, ...tasks] });
  } catch (err) {
    console.error('GET /workspace-tasks/live ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ── Employee-wide views (Day Planner actions, Live Tracking page, top bar) ──
function workIntervals(row, now = new Date()) {
  const out = [];
  if (!row.start_time) return out;
  let active = new Date(row.start_time);
  for (let i = 1; i <= 10; i += 1) {
    const hold = row[`hold_time_${i}`];
    const restart = row[`restart_time_${i}`];
    if (hold && active) {
      out.push([active, new Date(hold)]);
      active = null;
    }
    if (restart) active = new Date(restart);
    else if (hold) { active = null; break; }
  }
  if (active) out.push([active, row.complete_time ? new Date(row.complete_time) : now]);
  return out;
}

function secondsBetween(intervals, from, to) {
  let total = 0;
  for (const [a, b] of intervals) {
    const start = Math.max(a.getTime(), from.getTime());
    const end = Math.min(b.getTime(), to.getTime());
    if (end > start) total += Math.floor((end - start) / 1000);
  }
  return total;
}

function sessionStart(row) {
  let latest = row.start_time ? new Date(row.start_time) : null;
  for (let i = 1; i <= 10; i += 1) {
    const r = row[`restart_time_${i}`];
    if (r && (!latest || new Date(r) > latest)) latest = new Date(r);
  }
  return latest;
}

function dayBounds(day) {
  const [y, m, d] = day.split('-').map(Number);
  const from = new Date(y, m - 1, d, 0, 0, 0);
  const to = new Date(y, m - 1, d + 1, 0, 0, 0);
  return { from, to };
}

async function employeeTaskItems(employee, client = null) {
  const employeeId = await employeeIdFor(employee);
  const params = [employeeId ?? -1, employee];
  let clientSql = '';
  if (client) {
    clientSql = 'AND LOWER(TRIM(tl.client_name)) = LOWER(TRIM(?))';
    params.push(client);
  }
  const [rows] = await db.query(
    `${ROW_SELECT.replace('SELECT tti.*,', `SELECT tti.*,
       EXISTS (SELECT 1 FROM content_calendar ccx
               WHERE ccx.task_item_id = tti.id AND ccx.source_assignment_id IS NOT NULL
                 AND ccx.source_active = 1 AND ccx.cc_handoff_at IS NULL
                 AND COALESCE(ccx.is_emergency, 0) <> 1) AS awaiting_handoff,`)}
     WHERE (tl.employee_id = ? OR LOWER(TRIM(tl.employee_name)) = LOWER(TRIM(?)))
       ${clientSql}
     ORDER BY tl.client_name, tti.s_no, tti.sub_no, tti.id`,
    params,
  );
  const active = await activeClientSet();
  const live = rows.filter((r) => active.has(norm(r.client_name)));
  const shaped = shapeRows(live);
  return live.map((raw, i) => ({ raw, row: shaped[i] }));
}

function taskItem({ raw, row }) {
  return {
    kind: 'TASK',
    key: `task:${row.id}`,
    task_id: row.id,
    client: row.client_name,
    deliverable: row.deliverable,
    title: `${row.deliverable} · Row ${row.display_no}`,
    heading: row.hook_headline || row.task_description,
    status: row.state,
    duration_secs: row.current_secs,
    running: row.state === 'IN PROGRESS',
    session_started_at: row.state === 'IN PROGRESS' ? sessionStart(raw) : null,
    review_action: row.manager_action,
    comment: row.manager_comment || raw.comment || '',
    submit_date: row.submit_date,
    // Client card date (assignment deadline) — used to open the right card.
    due_date: dueKey(raw),
    section: 'My Tasks',
  };
}

async function employeeSheets(employee, client = null, { includeStartable = false } = {}) {
  const employeeId = await employeeIdFor(employee);
  const params = [employeeId ?? -1, employee];
  let clientSql = '';
  if (client) {
    clientSql = 'AND LOWER(TRIM(client_name)) = LOWER(TRIM(?))';
    params.push(client);
  }
  let startableSql = '';
  if (includeStartable) {
    const ids = await reviewerAssignmentIds(employee, client);
    if (ids.length) {
      startableSql = `OR (source_assignment_id IN (${ids.map(Number).join(',')})
                          AND cc_prepared_by_id IS NULL AND cc_handoff_at IS NULL
                          AND COALESCE(is_emergency, 0) <> 1)`;
    }
  }
  const [cc] = await db.query(
    `SELECT id, client_name, deliverable, source_assignment_id, source_role, source_task_index,
            source_row_number, submit_date, cc_status, cc_duration_secs, cc_started_at,
            cc_hold_reason, cc_last_activity_at, cc_handoff_at, assigned_to_name
     FROM content_calendar
     WHERE source_assignment_id IS NOT NULL AND source_active = 1
       AND ((cc_prepared_by_id = ? OR LOWER(TRIM(cc_prepared_by_name)) = LOWER(TRIM(?))) ${startableSql})
       ${clientSql}
     ORDER BY client_name, source_assignment_id, source_role, source_task_index, source_row_number`,
    params,
  );
  const active = await activeClientSet();
  return groupSheets(cc.filter((r) => active.has(norm(r.client_name))));
}

// Rows of content_calendar → one item per category sheet (or manual row).
function groupSheets(cc) {
  const sheets = new Map();
  for (const r of cc) {
    const key = r.source_assignment_id
      ? `${r.source_assignment_id}:${r.source_role}:${r.source_task_index}`
      : `row:${r.id}`;
    const sh = sheets.get(key) || { rows: [], banked: 0, runningFrom: null, statuses: new Set(), last: null };
    sh.rows.push(r);
    sh.statuses.add(upper(r.cc_status || 'IDLE'));
    sh.banked += Number(r.cc_duration_secs) || 0;
    if (r.cc_started_at && upper(r.cc_status) === 'IN PROGRESS') sh.runningFrom = new Date(r.cc_started_at);
    if (r.cc_last_activity_at && (!sh.last || r.cc_last_activity_at > sh.last)) sh.last = r.cc_last_activity_at;
    sheets.set(key, sh);
  }
  const now = Date.now();
  return [...sheets.entries()].map(([key, sh]) => {
    const first = sh.rows[0];
    const st = sh.statuses;
    const status = sh.rows.every((r) => r.cc_handoff_at) ? 'ASSIGNED'
      : st.size === 1 ? [...st][0]
        : st.has('IN PROGRESS') ? 'IN PROGRESS' : st.has('ON HOLD') ? 'ON HOLD' : 'IN PROGRESS';
    const runningSecs = sh.runningFrom ? Math.max(Math.floor((now - sh.runningFrom.getTime()) / 1000), 0) : 0;
    return {
      kind: 'CONTENT_CALENDAR',
      key: `cc:${key}`,
      calendar_ids: sh.rows.map((r) => r.id),
      client: first.client_name,
      deliverable: first.deliverable,
      title: `Content Calendar · ${first.deliverable} (${sh.rows.length} rows)`,
      heading: `Preparing for ${first.assigned_to_name || 'team'}`,
      status,
      duration_secs: sh.banked + runningSecs,
      banked_secs: sh.banked,
      running: Boolean(sh.runningFrom),
      session_started_at: sh.runningFrom,
      last_activity_at: sh.last,
      hold_reason: sh.rows.find((r) => r.cc_hold_reason)?.cc_hold_reason || '',
      source_assignment_id: first.source_assignment_id,
      source_role: first.source_role,
      source_task_index: first.source_task_index,
      submit_date: dateKey(first.submit_date),
      due_date: dateKey(first.submit_date),
      section: 'Content Calendar',
    };
  });
}

// GET /actionable?employee=&client=  → things the employee can act on now
router.get('/actionable', async (req, res) => {
  const employee = employeeFrom(req);
  const client = String(req.query.client || '').trim() || null;
  if (!employee) return res.status(400).json({ success: false, message: 'employee is required' });
  try {
    const open = new Set(['IDLE', 'IN PROGRESS', 'ON HOLD', 'REWORK']);
    const tasks = (await employeeTaskItems(employee, client))
      .filter(({ raw, row }) => open.has(row.state) && !(row.state === 'IDLE' && Number(raw.awaiting_handoff) === 1))
      .map(taskItem);
    const sheets = (await employeeSheets(employee, client, { includeStartable: true }))
      .filter((s) => ['IDLE', 'IN PROGRESS', 'ON HOLD'].includes(s.status));
    const rank = (i) => (i.status === 'IN PROGRESS' ? 0 : ['ON HOLD', 'REWORK'].includes(i.status) ? 1 : 2);
    const data = [...sheets, ...tasks].sort((a, b) => rank(a) - rank(b));
    return res.json({ success: true, data });
  } catch (err) {
    console.error('GET /workspace-tasks/actionable ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// GET /items-by-ref?employee=&refs=task:21,cc:45
// Day Planner rows carry "[Task Row #id]" / "[Calendar Row #id]" markers; this
// turns them into live items (status, timer, actions).
router.get('/items-by-ref', async (req, res) => {
  const employee = employeeFrom(req);
  const refs = String(req.query.refs || '').split(',').map((r) => r.trim()).filter(Boolean);
  if (!employee) return res.status(400).json({ success: false, message: 'employee is required' });
  try {
    const out = {};
    const taskIds = refs.filter((r) => r.startsWith('task:')).map((r) => Number(r.slice(5))).filter(Boolean);
    if (taskIds.length) {
      const wanted = new Set(taskIds);
      for (const entry of await employeeTaskItems(employee)) {
        if (wanted.has(entry.row.id)) out[`task:${entry.row.id}`] = taskItem(entry);
      }
    }
    const calIds = refs.filter((r) => r.startsWith('cc:')).map((r) => Number(r.slice(3))).filter(Boolean);
    for (const id of calIds) {
      const [[row]] = await db.query('SELECT * FROM content_calendar WHERE id = ?', [id]);
      if (!row) continue;
      const [group] = row.source_assignment_id
        ? await db.query(
            `SELECT * FROM content_calendar
             WHERE source_assignment_id = ? AND source_role = ? AND source_task_index = ?
               AND source_active = 1
             ORDER BY source_row_number`,
            [row.source_assignment_id, row.source_role, row.source_task_index],
          )
        : [[row]];
      const [item] = groupSheets(group.length ? group : [row]);
      if (item) out[`cc:${id}`] = item;
    }
    return res.json({ success: true, data: out });
  } catch (err) {
    console.error('GET /workspace-tasks/items-by-ref ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// GET /live-all?employee=&date=  → everything worked on that day, all clients
router.get('/live-all', async (req, res) => {
  const employee = employeeFrom(req);
  if (!employee) return res.status(400).json({ success: false, message: 'employee is required' });
  const day = dateKey(req.query.date) || localDay(new Date());
  const today = localDay(new Date());
  try {
    const { from, to } = dayBounds(day);
    const now = new Date();
    const tasks = (await employeeTaskItems(employee))
      .filter(({ raw, row }) => touchedOn(raw, day) ||
        (day === today && ['IN PROGRESS', 'ON HOLD', 'REWORK'].includes(row.state)))
      .map(({ raw, row }) => ({
        ...taskItem({ raw, row }),
        seconds_on_date: secondsBetween(workIntervals(raw, now), from, to < now ? to : now),
      }));
    const sheets = (await employeeSheets(employee))
      .filter((s) => (s.last_activity_at && localDay(new Date(s.last_activity_at)) === day) ||
        (day === today && ['IN PROGRESS', 'ON HOLD'].includes(s.status)))
      .map((s) => ({
        ...s,
        seconds_on_date: s.running && day === today
          ? Math.max(Math.floor((now - new Date(s.session_started_at)) / 1000), 0)
          : 0,
      }));
    const rank = (i) => (i.status === 'IN PROGRESS' ? 0 : ['ON HOLD', 'REWORK'].includes(i.status) ? 1 : 2);
    const data = [...sheets, ...tasks].sort((a, b) => rank(a) - rank(b) ||
      String(a.client).localeCompare(String(b.client)));
    const totalSecs = data.reduce((t, i) => t + (Number(i.seconds_on_date) || 0), 0);
    return res.json({ success: true, date: day, totalSecs, data });
  } catch (err) {
    console.error('GET /workspace-tasks/live-all ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// GET /running?employee=  → { running, totalSecs (today), serverNow } for the top bar
router.get('/running', async (req, res) => {
  const employee = employeeFrom(req);
  if (!employee) return res.status(400).json({ success: false, message: 'employee is required' });
  try {
    const now = new Date();
    const day = localDay(now);
    const { from } = dayBounds(day);
    const items = await employeeTaskItems(employee);
    let totalSecs = 0;
    let running = null;
    for (const { raw, row } of items) {
      if (!touchedOn(raw, day) && row.state !== 'IN PROGRESS') continue;
      totalSecs += secondsBetween(workIntervals(raw, now), from, now);
      if (row.state === 'IN PROGRESS' && !running) running = taskItem({ raw, row });
    }
    for (const sheet of await employeeSheets(employee)) {
      if (!sheet.running) continue;
      totalSecs += Math.max(Math.floor((now - new Date(sheet.session_started_at)) / 1000), 0);
      if (!running) running = sheet;
    }
    return res.json({
      success: true,
      serverNow: now.toISOString(),
      totalSecs,
      running: running && {
        ...running,
        task: running.title,
        trackingItemId: running.task_id ?? null,
        sessionStartedAt: running.session_started_at
          ? new Date(running.session_started_at).toISOString()
          : null,
        elapsedSecs: running.duration_secs,
      },
    });
  } catch (err) {
    console.error('GET /workspace-tasks/running ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// POST /day-plan/add { employee, task_id } — add ONE My Tasks row to today's
// Day Planner (row based, not category based). Safe to call twice.
router.post('/day-plan/add', async (req, res) => {
  const employee = employeeFrom(req);
  const taskId = Number(req.body?.task_id);
  if (!employee || !taskId) {
    return res.status(400).json({ success: false, message: 'employee and task_id are required' });
  }
  try {
    const [[row]] = await db.query(
      `SELECT tti.id, tl.employee_name, tl.employee_id
       FROM time_tracking_task_items tti JOIN task_list tl ON tl.id = tti.task_list_id
       WHERE tti.id = ?`,
      [taskId],
    );
    if (!row) return res.status(404).json({ success: false, message: 'Task row not found' });
    const employeeId = await employeeIdFor(employee);
    const mine = norm(row.employee_name) === norm(employee) ||
      (employeeId && Number(row.employee_id) === Number(employeeId));
    if (!mine) return res.status(403).json({ success: false, message: 'This row is not assigned to you' });

    const marker = `[Task Row #${taskId}]`;
    const [existing] = await db.query(
      `SELECT id FROM day_plan_rows
       WHERE LOWER(TRIM(employee_name)) = LOWER(TRIM(?)) AND plan_date = CURDATE()
         AND today_plan LIKE ? LIMIT 1`,
      [row.employee_name, `%${marker}%`],
    );
    if (existing.length) {
      return res.json({ success: true, added: false, message: 'Already in today’s Day Planner' });
    }
    const { ensureTaskInDayPlan } = require('./tracking-items');
    await ensureTaskInDayPlan(db, { id: taskId, employee_name: row.employee_name }, true);
    await syncDayPlanStatus(row.employee_name).catch(() => {});
    emit(req, { type: 'DAY_PLAN_UPDATED', trackingItemId: taskId });
    return res.json({ success: true, added: true, message: 'Added to today’s Day Planner' });
  } catch (err) {
    console.error('POST /workspace-tasks/day-plan/add ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// GET /day-plan/rows?employee=  → task row ids already in today's planner
router.get('/day-plan/rows', async (req, res) => {
  const employee = employeeFrom(req);
  if (!employee) return res.status(400).json({ success: false, message: 'employee is required' });
  try {
    const [rows] = await db.query(
      `SELECT today_plan FROM day_plan_rows
       WHERE LOWER(TRIM(employee_name)) = LOWER(TRIM(?)) AND plan_date = CURDATE()`,
      [employee],
    );
    const ids = new Set();
    const calendar = new Set();
    for (const r of rows) {
      for (const m of String(r.today_plan || '').matchAll(/\[Task Row #(\d+)\]/g)) ids.add(Number(m[1]));
      for (const m of String(r.today_plan || '').matchAll(/\[Calendar Row #(\d+)\]/g)) calendar.add(Number(m[1]));
    }
    return res.json({ success: true, data: [...ids], calendar: [...calendar] });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;

