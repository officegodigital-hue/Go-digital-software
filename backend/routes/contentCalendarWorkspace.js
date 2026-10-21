const express = require('express');
const db = require('../config/db');
const { authenticateToken } = require('./auth');
const { buildTemplate, parseUpload, planUpdates, toCsv } = require('../lib/contentCalendarExcel');
const { autoHoldForEmployee } = require('../lib/autoHold');
const { syncDayPlanStatus } = require('../lib/dayPlanSync');

const router = express.Router();
// File downloads open in a new browser tab, which cannot send the
// Authorization header — accept ?access_token= for those GET requests.
router.use((req, res, next) => {
  if (!req.headers.authorization && req.method === 'GET' && req.query.access_token) {
    req.headers.authorization = `Bearer ${req.query.access_token}`;
  }
  next();
});
router.use(authenticateToken);
const { ensureWorkspaceTaskSchemaOnce } = require('../lib/ensureWorkspaceTaskSchema');
router.use(async (req, res, next) => {
  try {
    await ensureWorkspaceTaskSchemaOnce(db);
    next();
  } catch (err) {
    res.status(500).json({ success: false, message: `Database setup failed: ${err.message}` });
  }
});
const editableFields = {
  hook_headline: 'hook_headline',
  description_points: 'description',
  caption: 'caption',
  cta: 'cta',
  publish_date: 'publish_date',
  submit_date: 'submit_date',
  notes: 'notes',
  description_rich: 'description_rich',
};
const assignedTaskRoles = [
  { role: 'designer', label: 'Designer', employee: 'designer', tasks: 'designer_tasks' },
  { role: 'videographer', label: 'Videographer', employee: 'videographer', tasks: 'videographer_tasks' },
  { role: 'video_editor', label: 'Video Editor', employee: 'video_editor', tasks: 'video_editor_task' },
  // UI/UX Designer and Developer tasks go straight to the employee's My Tasks.
  { role: 'website_designer', label: 'Website Designer', employee: 'website_designer', tasks: 'website_designer_tasks' },
];

function numericId(value) {
  const id = Number(value);
  return Number.isSafeInteger(id) && id > 0 ? id : null;
}

function normalizedRole(value) {
  return String(value || '').trim().toLowerCase().replace(/[\s-]+/g, '_');
}

function isContentHandler(user) {
  return ['page_handler', 'ads_handler'].includes(normalizedRole(user?.role)) ||
    ['page_handler', 'ads_handler'].includes(normalizedRole(user?.userType));
}

function requireContentHandler(req, res) {
  if (isContentHandler(req.user)) return true;
  res.status(403).json({
    success: false,
    message: 'Content Calendar is available to Page Handlers and Ads Handlers only',
  });
  return false;
}

function sourceKey(assignmentId, role, taskIndex) {
  return `${assignmentId}:${role}:${taskIndex}`;
}

function sourceRowKey(assignmentId, role, taskIndex, rowNumber) {
  return `${sourceKey(assignmentId, role, taskIndex)}:${rowNumber}`;
}

function isOnLeaveSql() {
  return `SELECT EXISTS(
    SELECT 1 FROM employee_leaves
    WHERE employee_id = ? AND status = 'APPROVED'
      AND CURDATE() BETWEEN from_date AND to_date
  ) AS is_on_leave`;
}

function sendTaskUpdated(req, calendarId, status) {
  // Day Planner status first, then tell every page to refresh.
  syncDayPlanStatus(req.user?.fullName)
    .catch((err) => console.error('Day plan sync:', err.message))
    .finally(() => {
      req.app.get('io')?.emit('task_updated', {
        type: 'CONTENT_CALENDAR_UPDATE',
        calendarId,
        status,
      });
    });
}

async function getCalendarRow(connection, calendarId, lock = false) {
  const [rows] = await connection.query(
    `SELECT * FROM content_calendar WHERE id = ?${lock ? ' FOR UPDATE' : ''}`,
    [calendarId],
  );
  return rows[0] || null;
}

async function dayPlanSubmitted(connection, employeeName) {
  const [rows] = await connection.query(
    `SELECT id FROM day_plan_rows
     WHERE employee_name = ? AND plan_date = CURDATE()
       AND report_type = 'Morning' AND is_submitted = 1
     LIMIT 1`,
    [employeeName],
  );
  return rows.length > 0;
}

// Day Planner words for a calendar status.
function planStatus(status) {
  const s = String(status || '').toUpperCase();
  if (s === 'IN PROGRESS') return 'PROCESSING';
  if (s === 'ON HOLD') return 'HOLD';
  if (s === 'COMPLETED') return 'COMPLETE';
  if (s === 'IDLE') return 'NOT START';
  return s || 'NOT START';
}

// day_plan_rows.maintenance_date is a short text column: always send YYYY-MM-DD
// (a JS Date would be written as a long datetime and fail with "Data too long").
function planDateKey(value) {
  if (!value) return null;
  const d = value instanceof Date ? value : new Date(value);
  if (!Number.isNaN(d.getTime()) && value instanceof Date) {
    const p = (n) => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
  }
  const s = String(value).trim();
  const m = s.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (m) return `${m[1]}-${m[2]}-${m[3]}`;
  if (!Number.isNaN(d.getTime())) {
    const p = (n) => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
  }
  return s.slice(0, 10);
}

async function ensureCalendarDayPlan(connection, row, user, status, insertAlways = false) {
  const employeeName = String(user.fullName || '').trim();
  const marker = `[Calendar Row #${row.id}]`;
  const [plans] = await connection.query(
    `SELECT id, is_submitted
     FROM day_plan_rows
     WHERE employee_name = ? AND plan_date = CURDATE()
       AND report_type = 'Morning' AND today_plan LIKE ?
     ORDER BY id DESC LIMIT 1 FOR UPDATE`,
    [employeeName, `%${marker}%`],
  );
  // Work is allowed after the Day Planner is submitted (that is the normal
  // flow now), so a submitted plan no longer blocks start / hold / complete.

  if (plans.length) {
    await connection.query(
      `UPDATE day_plan_rows SET status = ? WHERE id = ?`,
      [planStatus(status), plans[0].id],
    );
    return;
  }
  if (status !== 'IN PROGRESS' && !insertAlways) return;

  const role = normalizedRole(user.role || user.userType);
  const roleLabel = role === 'ads_handler' ? 'Ads Handler' : 'Page Handler';
  const [[day]] = await connection.query(
    `SELECT COALESCE(MAX(is_submitted), 0) AS s FROM day_plan_rows
     WHERE employee_name = ? AND plan_date = CURDATE() AND report_type = 'Morning'`,
    [employeeName],
  );
  const plan = `${marker} Prepare ${row.deliverable}: ${row.hook_headline || row.deliverable}` +
    (row.sheet_row_count ? ` (${row.sheet_row_count} rows)` : ` (Row ${row.s_no})`);
  await connection.query(
    `INSERT INTO day_plan_rows
       (employee_name, employee_role, plan_date, report_type, client_name,
        maintenance_date, today_plan, status, is_submitted)
     VALUES (?, ?, CURDATE(), 'Morning', ?, ?, ?, ?, ?)`,
    [
      employeeName,
      roleLabel,
      row.client_name,
      planDateKey(row.submit_date),
      plan,
      planStatus(status),
      day?.s ? 1 : 0,
    ],
  );
}

async function syncAssignedTaskDetails(connection, calendarId) {
  const [rows] = await connection.query(
    `SELECT task_item_id, deliverable, hook_headline, description, caption, cta,
            submit_date, publish_date, notes, description_rich, cc_handoff_at
     FROM content_calendar WHERE id = ?`,
    [calendarId],
  );
  const row = rows[0];
  const taskItemId = numericId(row?.task_item_id);
  if (!taskItemId) return;
  if (row.cc_handoff_at) {
    // Already shared: push the corrected content into the employee's row.
    await connection.query(
      `UPDATE time_tracking_task_items
       SET task_description = ?, submit_date = ?, hook_headline = ?,
           description_points = ?, caption = ?, cta = ?, publish_date = ?,
           notes = ?, description_rich = ?
       WHERE id = ?`,
      [
        employeeTaskDescription(row), row.submit_date || null, row.hook_headline || '',
        row.description || '', row.caption || '', row.cta || '', row.publish_date || null,
        row.notes || '', row.description_rich || null, taskItemId,
      ],
    );
    return;
  }
  await connection.query(
    `UPDATE time_tracking_task_items
     SET task_description = ?, submit_date = ?
     WHERE id = ?`,
    [employeeTaskDescription(row), row.submit_date || null, taskItemId],
  );
}

async function findEmployee(connection, employeeId, employeeName) {
  const [rows] = employeeId
    ? await connection.query(
        `SELECT id, full_name FROM employee_users
         WHERE id = ? AND is_active = 1 LIMIT 1`,
        [employeeId],
      )
    : await connection.query(
        `SELECT id, full_name FROM employee_users
         WHERE LOWER(TRIM(full_name)) = LOWER(TRIM(?)) AND is_active = 1 LIMIT 1`,
        [employeeName],
      );
  return rows[0] || null;
}

function employeeTaskDescription(row) {
  return [
    row.hook_headline || row.deliverable,
    row.description,
    row.caption && `Caption: ${row.caption}`,
    row.cta && `CTA: ${row.cta}`,
  ].filter(Boolean).join('\n');
}

function normalizeTaskName(value) {
  return String(value || '').trim().replace(/\s+/g, ' ').toLowerCase();
}

function parseAssignedTasks(value) {
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
    .filter((task) => Number.isSafeInteger(task.count) && task.count >= 0);
}

async function syncAssignedTasksToCalendar(clientName) {
  let connection;
  try {
    connection = await db.getConnection();
    await connection.beginTransaction();
    const [assignments] = await connection.query(
      `SELECT * FROM task_assignments
       WHERE LOWER(TRIM(client_name)) = LOWER(TRIM(?)) AND is_assigned = 1`,
      [clientName],
    );
    const [clients] = await connection.query(
      `SELECT id FROM clients
       WHERE LOWER(TRIM(company_name)) = LOWER(TRIM(?)) LIMIT 1`,
      [clientName],
    );
    const clientId = clients[0]?.id ?? null;
    if (assignments.length && !clientId) {
      throw new Error(`No client record matches "${clientName}"`);
    }
    const names = new Set();
    const assignmentIds = assignments.map((assignment) => assignment.id);
    const desiredRows = [];

    for (const assignment of assignments) {
      for (const role of assignedTaskRoles) {
        const employeeName = String(assignment[role.employee] || '').trim();
        if (!employeeName || employeeName.toUpperCase() === 'NONE') continue;
        names.add(normalizeTaskName(employeeName));

        const tasks = parseAssignedTasks(assignment[role.tasks]);
        for (let taskIndex = 0; taskIndex < tasks.length; taskIndex += 1) {
          if (!tasks[taskIndex].name || tasks[taskIndex].count <= 0) continue;
          desiredRows.push({
            assignment,
            role,
            task: tasks[taskIndex],
            taskIndex,
            employeeName,
          });
        }
      }
    }

    const employees = names.size
      ? await connection.query('SELECT id, full_name FROM employee_users')
      : [[], []];
    const employeeIds = new Map(
      employees[0].map((employee) => [normalizeTaskName(employee.full_name), employee.id]),
    );
    const taskLists = assignmentIds.length
      ? await connection.query(
          `SELECT tl.id, tl.task_assignment_id, tl.deliverables, tl.no_of_rows,
                  tti.id AS tracking_item_id, tti.s_no
           FROM task_list tl
           LEFT JOIN time_tracking_task_items tti ON tti.task_list_id = tl.id
           WHERE tl.task_assignment_id IN (?)`,
          [assignmentIds],
        )
      : [[], []];
    const [existingCalendarRows] = assignmentIds.length
      ? await connection.query(
          `SELECT source_assignment_id, source_role, source_task_index,
                  source_row_number, task_item_id, is_emergency, source_active
           FROM content_calendar
           WHERE source_assignment_id IN (?)`,
          [assignmentIds],
        )
      : [[], []];
    const taskListRows = new Map();
    for (const item of taskLists[0]) {
      const key = `${item.task_assignment_id}:${normalizeTaskName(item.deliverables)}`;
      const group = taskListRows.get(key) || { count: 0, trackingItems: new Map() };
      group.count = Math.max(group.count, Number(item.no_of_rows) || 0);
      if (item.tracking_item_id && item.s_no != null) {
        group.trackingItems.set(Number(item.s_no), item.tracking_item_id);
      }
      taskListRows.set(key, group);
    }

    const existingTaskItems = new Map();
    const excludedRows = new Map();
    for (const row of existingCalendarRows) {
      const groupKey = sourceKey(
        row.source_assignment_id,
        row.source_role,
        row.source_task_index,
      );
      const rowKey = sourceRowKey(
        row.source_assignment_id,
        row.source_role,
        row.source_task_index,
        row.source_row_number,
      );
      if (row.task_item_id) existingTaskItems.set(rowKey, row.task_item_id);
      if (Number(row.is_emergency) === 1 && Number(row.source_active) === 0) {
        const excluded = excludedRows.get(groupKey) || new Set();
        excluded.add(Number(row.source_row_number));
        excludedRows.set(groupKey, excluded);
      }
    }

    const values = [];
    for (const source of desiredRows) {
      const key = `${source.assignment.id}:${normalizeTaskName(source.task.name)}`;
      const taskList = taskListRows.get(key);
      if (source.task.count === 0) continue;
      const groupKey = sourceKey(source.assignment.id, source.role.role, source.taskIndex);
      const excluded = excludedRows.get(groupKey) || new Set();
      const rowCount = Math.max(taskList?.count || 0, source.task.count);
      const sourceRowCount = rowCount + excluded.size;
      const assignedToId = employeeIds.get(normalizeTaskName(source.employeeName)) ?? null;
      for (let rowNumber = 1; rowNumber <= sourceRowCount; rowNumber += 1) {
        if (excluded.has(rowNumber)) continue;
        values.push([
          clientId,
          clientName,
          rowNumber,
          source.task.name,
          '',
          source.assignment.deadline || source.assignment.maintenance_date || null,
          assignedToId,
          source.employeeName,
          source.assignment.assigned_by_name || 'Task Assignment',
          existingTaskItems.get(sourceRowKey(
            source.assignment.id,
            source.role.role,
            source.taskIndex,
            rowNumber,
          )) ?? taskList?.trackingItems.get(rowNumber) ?? null,
          source.assignment.id,
          source.role.role,
          source.taskIndex,
          rowNumber,
        ]);
      }
    }

    await connection.query(
      `UPDATE content_calendar SET source_active = 0
       WHERE LOWER(TRIM(client_name)) = LOWER(TRIM(?))
         AND source_assignment_id IS NOT NULL`,
      [clientName],
    );

    const columns = [
      'client_id', 'client_name', 's_no', 'deliverable', 'hook_headline',
      'submit_date', 'assigned_to_id', 'assigned_to_name', 'assigned_by_name',
      'task_item_id', 'source_assignment_id', 'source_role',
      'source_task_index', 'source_row_number',
    ];
    const placeholders = `(${columns.map(() => '?').join(', ')})`;
    for (let offset = 0; offset < values.length; offset += 200) {
      const batch = values.slice(offset, offset + 200);
      await connection.query(
        `INSERT INTO content_calendar (${columns.join(', ')}, source_active)
         VALUES ${batch.map(() => `${placeholders.slice(0, -1)}, 1)`).join(', ')}
         ON DUPLICATE KEY UPDATE
           client_id = VALUES(client_id),
           client_name = VALUES(client_name),
           s_no = VALUES(s_no),
           deliverable = VALUES(deliverable),
           hook_headline = IF(hook_headline = deliverable, VALUES(hook_headline), hook_headline),
           submit_date = IF(cc_submit_edited = 1, submit_date, VALUES(submit_date)),
           assigned_to_id = IF(is_emergency = 1 OR cc_reassigned = 1, assigned_to_id, VALUES(assigned_to_id)),
           assigned_to_name = IF(is_emergency = 1 OR cc_reassigned = 1, assigned_to_name, VALUES(assigned_to_name)),
           assigned_by_name = VALUES(assigned_by_name),
           task_item_id = COALESCE(VALUES(task_item_id), task_item_id),
           source_active = 1`,
        batch.flat(),
      );
    }
    await connection.commit();
  } catch (error) {
    if (connection) await connection.rollback();
    throw error;
  } finally {
    connection?.release();
  }
}

// Rows a Page / Ads Handler adds with "Add content" (not from the admin's
// Task Assignment) are ADDITIONAL work for the employee they assign: keep
// them in their own additional list per client + deliverable + submit date,
// so they show in Employee Workspace with the "ADDITIONAL TASK" tag (and never
// mix into an admin-assigned list of the same deliverable).
async function getOrCreateTaskList(connection, row, employee) {
  const due = row.submit_date || null;
  const [taskLists] = await connection.query(
    `SELECT id FROM task_list
     WHERE LOWER(TRIM(client_name)) = LOWER(TRIM(?)) AND employee_id = ?
       AND LOWER(TRIM(deliverables)) = LOWER(TRIM(?))
       AND task_assignment_id IS NULL AND additional_task_id IS NOT NULL
       AND (DATE(submission_date) <=> DATE(COALESCE(?, CURDATE())))
     ORDER BY id DESC LIMIT 1 FOR UPDATE`,
    [row.client_name, employee.id, row.deliverable, due],
  );
  if (taskLists.length) return taskLists[0].id;

  const [result] = await connection.query(
    `INSERT INTO task_list
       (client_name, employee_id, employee_name, deliverables, submission_date, no_of_rows)
     VALUES (?, ?, ?, ?, COALESCE(?, CURDATE()), 0)`,
    [row.client_name, employee.id, employee.full_name, row.deliverable, due],
  );
  await connection.query(
    'UPDATE task_list SET additional_task_id = ? WHERE id = ?',
    [result.insertId, result.insertId],
  );
  return result.insertId;
}

async function assignCalendarRow(
  connection,
  row,
  employee,
  assignedById,
  assignedByName,
  emergencyReason = null,
  preferredTaskListId = null,
) {
  let taskItemId = numericId(row.task_item_id);
  const taskDescription = employeeTaskDescription(row);
  let existingItem = null;

  if (taskItemId) {
    const [items] = await connection.query(
      `SELECT tti.id, tti.task_list_id, tl.employee_id
       FROM time_tracking_task_items tti
       LEFT JOIN task_list tl ON tl.id = tti.task_list_id
       WHERE tti.id = ? FOR UPDATE`,
      [taskItemId],
    );
    if (!items.length) taskItemId = null;
    else existingItem = items[0];
  }

  const taskListId = preferredTaskListId ||
    (!existingItem || Number(existingItem.employee_id) !== Number(employee.id)
      ? await getOrCreateTaskList(connection, row, employee)
      : existingItem.task_list_id);

  if (!taskItemId) {
    const [result] = await connection.query(
      `INSERT INTO time_tracking_task_items
       (task_list_id, s_no, submit_date, task_description, duration_secs, status)
       VALUES (?, ?, ?, ?, 0, 'IDLE')`,
      [taskListId, row.s_no || 1, row.submit_date || null, taskDescription],
    );
    taskItemId = result.insertId;
  } else {
    await connection.query(
      `UPDATE time_tracking_task_items
       SET task_list_id = ?, submit_date = ?, task_description = ?,
           status = 'IDLE', start_time = NULL, complete_time = NULL,
           duration_secs = 0
       WHERE id = ?`,
      [taskListId, row.submit_date || null, taskDescription, taskItemId],
    );
  }

  // Same details the employee sees for admin-assigned rows (headline, caption …)
  // + who gave it (shown as "By VIJI (Page Handler)" on the workspace card).
  await connection.query(
    `UPDATE time_tracking_task_items
     SET content_calendar_assigned = 1, content_calendar_assigned_to = ?,
         cc_assigned_to_id = ?, cc_assigned_by_name = ?, cc_assigned_at = NOW(),
         hook_headline = ?, description_points = ?, caption = ?, cta = ?,
         publish_date = ?, notes = ?, description_rich = ?
     WHERE id = ?`,
    [
      employee.full_name,
      employee.id,
      assignedByName,
      row.hook_headline || '',
      row.description || '',
      row.caption || '',
      row.cta || '',
      row.publish_date || null,
      row.notes || '',
      row.description_rich || null,
      taskItemId,
    ],
  );
  await connection.query(
    `UPDATE task_list SET no_of_rows = (
       SELECT COUNT(*) FROM time_tracking_task_items
       WHERE task_list_id = ? AND parent_item_id IS NULL)
     WHERE id = ?`,
    [taskListId, taskListId],
  );

  await connection.query(
    `UPDATE content_calendar
     SET assigned_to_id = ?, assigned_to_name = ?, assigned_by_id = ?,
         assigned_by_name = ?, task_item_id = ?, is_emergency = ?,
         cc_emergency_reason = ?
     WHERE id = ?`,
    [
      employee.id,
      employee.full_name,
      assignedById,
      assignedByName,
      taskItemId,
      emergencyReason === null ? 0 : 1,
      emergencyReason,
      row.id,
    ],
  );

  await connection.query(
    `INSERT INTO notifications (sender_name, recipient_name, message)
     VALUES (?, ?, ?)`,
    [
      assignedByName,
      employee.full_name,
      `New ${row.deliverable} content deliverable assigned: "${row.hook_headline || row.deliverable}" for ${row.client_name}.`,
    ],
  );

  return taskItemId;
}

async function rowsForClient(clientName) {
  const [rows] = await db.query(
    `SELECT
       cc.*,
       cc.description AS description_points,
       DATE_FORMAT(cc.publish_date, '%Y-%m-%d') AS publish_date,
       DATE_FORMAT(cc.submit_date, '%Y-%m-%d') AS submit_date,
       (SELECT DATE_FORMAT(COALESCE(sa.deadline, sa.maintenance_date), '%Y-%m-%d')
          FROM task_assignments sa WHERE sa.id = cc.source_assignment_id) AS source_deadline,
       cc.cc_status AS status,
       cc.cc_status,
       cc.cc_duration_secs,
       CASE
         WHEN cc.cc_status = 'IN PROGRESS' AND cc.cc_started_at IS NOT NULL
         THEN cc.cc_duration_secs + GREATEST(TIMESTAMPDIFF(SECOND, cc.cc_started_at, NOW()), 0)
         ELSE cc.cc_duration_secs
       END AS current_cc_secs,
       -- A row from the admin's Task Assignment only counts as assigned after
       -- the Page/Ads Handler prepares the sheet and presses Assign (handoff)
       -- or emergency-assigns it. assigned_to_id on those rows is just the
       -- employee it is FOR, not proof that it was handed over.
       CASE
         WHEN cc.source_assignment_id IS NOT NULL
           THEN IF(cc.cc_handoff_at IS NOT NULL OR cc.is_emergency = 1, 1, 0)
         WHEN cc.assigned_to_id IS NOT NULL THEN 1
         ELSE 0
       END AS content_calendar_assigned,
       cc.assigned_to_name AS cc_assigned_to_name,
       CASE
         WHEN cc.source_assignment_id IS NOT NULL THEN cc.assigned_to_name
         ELSE COALESCE((
         SELECT NULLIF(ta.page_handling, '')
         FROM task_assignments ta
         WHERE LOWER(TRIM(ta.client_name)) = LOWER(TRIM(cc.client_name))
           AND UPPER(TRIM(ta.deliverables)) = UPPER(TRIM(cc.deliverable))
           AND ta.is_assigned = 1
         ORDER BY ta.id DESC LIMIT 1
       ), (
         SELECT NULLIF(ta.ads_handling, '')
         FROM task_assignments ta
         WHERE LOWER(TRIM(ta.client_name)) = LOWER(TRIM(cc.client_name))
           AND UPPER(TRIM(ta.deliverables)) = UPPER(TRIM(cc.deliverable))
           AND ta.is_assigned = 1
         ORDER BY ta.id DESC LIMIT 1
       ), '')
       END AS allocated_employee,
       CASE
         WHEN cc.source_role = 'designer' THEN 'Designer'
         WHEN cc.source_role = 'videographer' THEN 'Videographer'
         WHEN cc.source_role = 'video_editor' THEN 'Video Editor'
         WHEN cc.source_role = 'ui_ux_designer' THEN 'UI/UX Designer'
         WHEN cc.source_role = 'developer' THEN 'Developer'
         WHEN cc.source_role = 'ads_handling' THEN 'Ads Handler'
         WHEN cc.source_role = 'page_handling' THEN 'Page Handler'
         WHEN cc.source_role = 'website_designer' THEN 'Website Designer'
         WHEN EXISTS (
           SELECT 1 FROM task_assignments ta
           WHERE LOWER(TRIM(ta.client_name)) = LOWER(TRIM(cc.client_name))
             AND UPPER(TRIM(ta.deliverables)) = UPPER(TRIM(cc.deliverable))
             AND ta.is_assigned = 1 AND NULLIF(ta.page_handling, '') IS NOT NULL
           ORDER BY ta.id DESC LIMIT 1
         ) THEN 'Page Handler'
         WHEN EXISTS (
           SELECT 1 FROM task_assignments ta
           WHERE LOWER(TRIM(ta.client_name)) = LOWER(TRIM(cc.client_name))
             AND UPPER(TRIM(ta.deliverables)) = UPPER(TRIM(cc.deliverable))
             AND ta.is_assigned = 1 AND NULLIF(ta.ads_handling, '') IS NOT NULL
           ORDER BY ta.id DESC LIMIT 1
         ) THEN 'Ads Handler'
         ELSE ''
       END AS allocated_role,
       tti.review_status,
       tti.status AS task_status,
       tti.duration_secs AS task_duration_secs,
       tti.start_time AS task_start_time,
       tti.complete_time AS task_complete_time,
       tti.comment AS task_comment,
       tti.performance AS task_performance,
       tti.employee_notes AS task_employee_notes,
       tti.hold_time_1, tti.hold_time_2, tti.hold_time_3, tti.hold_time_4, tti.hold_time_5,
       tti.hold_time_6, tti.hold_time_7, tti.hold_time_8, tti.hold_time_9, tti.hold_time_10,
       tti.restart_time_1, tti.restart_time_2, tti.restart_time_3, tti.restart_time_4, tti.restart_time_5,
       tti.restart_time_6, tti.restart_time_7, tti.restart_time_8, tti.restart_time_9, tti.restart_time_10,
       tl_task.employee_name AS task_employee_name,
       mr.manager_action AS task_review_action,
       mr.manager_comment AS task_review_comment
     FROM content_calendar cc
     LEFT JOIN time_tracking_task_items tti ON tti.id = cc.task_item_id
     LEFT JOIN task_list tl_task ON tl_task.id = tti.task_list_id
     LEFT JOIN manager_review mr ON mr.tracking_item_id = tti.id
     WHERE LOWER(TRIM(cc.client_name)) = LOWER(TRIM(?))
       AND (cc.source_assignment_id IS NULL OR cc.source_active = 1 OR cc.cc_reassigned = 1)
     ORDER BY cc.s_no ASC, cc.id ASC`,
    [clientName],
  );
  return rows;
}

router.get('/client-tasks/:clientName', async (req, res) => {
  if (!requireContentHandler(req, res)) return;
  const clientName = req.params.clientName.trim();
  if (!clientName) {
    return res.status(400).json({ success: false, message: 'clientName is required' });
  }
  try {
    await syncAssignedTasksToCalendar(clientName);
    return res.json({ success: true, data: await rowsForClient(clientName) });
  } catch (error) {
    console.error('GET /tasks/client-tasks/:clientName ERROR:', error.message);
    return res.status(500).json({ success: false, message: error.message });
  }
});

router.put('/content-calendar/edit-row/:id', async (req, res) => {
  if (!requireContentHandler(req, res)) return;
  const id = numericId(req.params.id);
  if (!id) return res.status(400).json({ success: false, message: 'A valid calendar row id is required' });

  const updates = Object.entries(editableFields)
    .filter(([key]) => Object.hasOwn(req.body, key))
    .map(([key, column]) => [column, req.body[key]]);
  if (!updates.length) return res.status(400).json({ success: false, message: 'No editable fields provided' });

  let connection;
  try {
    connection = await db.getConnection();
    await connection.beginTransaction();
    const [existing] = await connection.query(
      `SELECT cc.id, cc.cc_handoff_at, cc.deliverable, cc.client_name, cc.s_no,
              tti.status AS task_status, tti.review_status, tl.employee_name AS task_employee
       FROM content_calendar cc
       LEFT JOIN time_tracking_task_items tti ON tti.id = cc.task_item_id
       LEFT JOIN task_list tl ON tl.id = tti.task_list_id
       WHERE cc.id = ? FOR UPDATE`,
      [id],
    );
    if (!existing.length) {
      await connection.rollback();
      return res.status(404).json({ success: false, message: 'Calendar row not found' });
    }
    const current = existing[0];
    const sharedRow = Boolean(current.cc_handoff_at);
    if (sharedRow) {
      const taskStatus = String(current.task_status || '').toUpperCase();
      const review = String(current.review_status || '').toUpperCase();
      if (review === 'APPROVED') {
        await connection.rollback();
        return res.status(409).json({ success: false, message: 'This row is approved and can no longer be changed' });
      }
      if (taskStatus === 'COMPLETED') {
        await connection.rollback();
        return res.status(409).json({
          success: false,
          message: `${current.task_employee || 'The employee'} has completed this row. Send it for rework in Task Review before changing the content.`,
        });
      }
    }
    // A date picked by the handler wins over the admin assignment's deadline.
    const touchesDate = updates.some(([column]) => column === 'submit_date');
    const assignments = updates.map(([column]) => `\`${column}\` = ?`).join(', ') +
      (touchesDate ? ', cc_submit_edited = 1' : '');
    await connection.query(
      `UPDATE content_calendar SET ${assignments} WHERE id = ?`,
      [...updates.map(([, value]) => (value === '' ? null : value)), id],
    );
    await syncAssignedTaskDetails(connection, id);
    if (sharedRow && current.task_employee) {
      await connection.query(
        `INSERT INTO notifications (sender_name, recipient_name, message) VALUES (?, ?, ?)`,
        [
          req.user.fullName,
          current.task_employee,
          `Content updated for ${current.deliverable} row ${current.s_no} (${current.client_name}). Check My Tasks.`,
        ],
      );
    }
    await connection.commit();
    sendTaskUpdated(req, id, 'EDITED');
    return res.json({ success: true, message: 'Calendar row saved' });
  } catch (error) {
    if (connection) await connection.rollback();
    console.error('PUT /tasks/content-calendar/edit-row/:id ERROR:', error.message);
    return res.status(500).json({ success: false, message: error.message });
  } finally {
    connection?.release();
  }
});

async function changeCalendarStatus(req, res, nextStatus) {
  if (!requireContentHandler(req, res)) return;
  const id = numericId(req.body.task_item_id);
  if (!id) return res.status(400).json({ success: false, message: 'A valid calendar row id is required' });
  if (nextStatus === 'IN PROGRESS' && req.body.day_planner_confirmed !== true) {
    return res.status(400).json({
      success: false,
      message: 'Confirm adding this row to today’s Day Planner before starting it',
    });
  }
  const reason = String(req.body.reason || '').trim();
  if (nextStatus === 'ON HOLD' && !reason) {
    return res.status(400).json({ success: false, message: 'Hold reason is required' });
  }

  let connection;
  try {
    connection = await db.getConnection();
    await connection.beginTransaction();
    const row = await getCalendarRow(connection, id, true);
    if (!row) {
      await connection.rollback();
      return res.status(404).json({ success: false, message: 'Calendar row not found' });
    }
    if (row.cc_handoff_at || (row.assigned_to_id && !row.source_assignment_id)) {
      await connection.rollback();
      return res.status(409).json({ success: false, message: 'This calendar row has already been shared' });
    }

    const status = String(row.cc_status || 'IDLE').toUpperCase();
    const employeeId = numericId(req.user.id);
    const employeeName = String(req.user.fullName || '').trim();
    if (!employeeId || !employeeName) {
      await connection.rollback();
      return res.status(401).json({ success: false, message: 'Your employee account could not be verified' });
    }
    if (row.cc_prepared_by_id && Number(row.cc_prepared_by_id) !== employeeId) {
      await connection.rollback();
      return res.status(403).json({
        success: false,
        message: `This row is owned by ${row.cc_prepared_by_name || 'another handler'}`,
      });
    }
    if (nextStatus === 'IN PROGRESS' && !['IDLE', 'ON HOLD'].includes(status)) {
      await connection.rollback();
      return res.status(409).json({ success: false, message: `Cannot start a row with status ${status}` });
    }
    if (nextStatus !== 'IN PROGRESS' &&
        (status !== 'IN PROGRESS' || Number(row.cc_prepared_by_id) !== employeeId)) {
      await connection.rollback();
      return res.status(409).json({ success: false, message: 'Only the owning handler can hold or complete an in-progress row' });
    }

    if (nextStatus === 'IN PROGRESS') {
      // Anything else running (task or category) is held — reason required.
      await autoHoldForEmployee(
        connection,
        {
          employeeId,
          employeeName,
          excludeSheet: row.source_assignment_id
            ? `${row.source_assignment_id}:${row.source_role}:${row.source_task_index}`
            : `row:${id}`,
        },
        req.body.auto_hold_reason,
      );
      await connection.query(
        `UPDATE content_calendar
         SET cc_status = 'IN PROGRESS', cc_started_at = NOW(), cc_hold_reason = NULL,
             cc_last_activity_at = NOW(),
             cc_prepared_by_id = ?, cc_prepared_by_name = ?
         WHERE id = ?`,
        [employeeId, employeeName, id],
      );
      await ensureCalendarDayPlan(connection, row, req.user, 'IN PROGRESS');
    } else if (nextStatus === 'ON HOLD') {
      await connection.query(
        `UPDATE content_calendar
         SET cc_duration_secs = cc_duration_secs + GREATEST(TIMESTAMPDIFF(SECOND, cc_started_at, NOW()), 0),
             cc_started_at = NULL, cc_status = 'ON HOLD', cc_hold_reason = ?,
             cc_last_activity_at = NOW()
         WHERE id = ?`,
        [reason, id],
      );
      await ensureCalendarDayPlan(connection, row, req.user, 'ON HOLD');
    } else {
      await connection.query(
        `UPDATE content_calendar
         SET cc_duration_secs = cc_duration_secs + GREATEST(TIMESTAMPDIFF(SECOND, cc_started_at, NOW()), 0),
             cc_started_at = NULL, cc_status = 'COMPLETED', cc_hold_reason = NULL,
             cc_last_activity_at = NOW()
         WHERE id = ?`,
        [id],
      );
      await ensureCalendarDayPlan(connection, row, req.user, 'COMPLETED');
    }
    await connection.commit();
    sendTaskUpdated(req, id, nextStatus);
    return res.json({ success: true, message: `Calendar row ${nextStatus.toLowerCase()}` });
  } catch (error) {
    if (connection) await connection.rollback();
    console.error(`POST /tasks/content-calendar/${nextStatus.toLowerCase()} ERROR:`, error.message);
    return res.status(error.statusCode || 500).json({
      success: false, message: error.message, code: error.code, running: error.running,
    });
  } finally {
    connection?.release();
  }
}

router.post('/content-calendar/start', (req, res) => changeCalendarStatus(req, res, 'IN PROGRESS'));
router.post('/content-calendar/hold', (req, res) => changeCalendarStatus(req, res, 'ON HOLD'));
router.post('/content-calendar/complete', (req, res) => changeCalendarStatus(req, res, 'COMPLETED'));

async function changeCalendarSheetStatus(req, res, nextStatus) {
  if (!requireContentHandler(req, res)) return;
  const assignmentId = numericId(req.body.source_assignment_id);
  const sourceRole = String(req.body.source_role || '').trim();
  const taskIndex = Number(req.body.source_task_index);
  if (
    !assignmentId ||
    !sourceRole ||
    !Number.isSafeInteger(taskIndex) ||
    taskIndex < 0
  ) {
    return res.status(400).json({
      success: false,
      message: 'A valid content deliverable sheet is required',
    });
  }
  if (
    nextStatus === 'IN PROGRESS' &&
    req.body.day_planner_confirmed !== true
  ) {
    return res.status(400).json({
      success: false,
      message: 'Confirm adding this sheet to today’s Day Planner before starting',
    });
  }

  const reason = String(req.body.reason || '').trim();
  if (nextStatus === 'ON HOLD' && !reason) {
    return res.status(400).json({
      success: false,
      message: 'Hold reason is required',
    });
  }

  let connection;
  try {
    connection = await db.getConnection();
    await connection.beginTransaction();
    const [rows] = await connection.query(
      `SELECT * FROM content_calendar
       WHERE source_assignment_id = ? AND source_role = ?
         AND source_task_index = ? AND source_active = 1
       ORDER BY source_row_number ASC FOR UPDATE`,
      [assignmentId, sourceRole, taskIndex],
    );
    if (!rows.length) {
      await connection.rollback();
      return res.status(404).json({
        success: false,
        message: 'No active rows found for this deliverable sheet',
      });
    }
    if (rows.some((row) => row.cc_handoff_at || Number(row.is_emergency))) {
      await connection.rollback();
      return res.status(409).json({
        success: false,
        message: 'This deliverable sheet has already been shared or changed',
      });
    }

    const employeeId = numericId(req.user.id);
    const employeeName = String(req.user.fullName || '').trim();
    if (!employeeId || !employeeName) {
      await connection.rollback();
      return res.status(401).json({
        success: false,
        message: 'Your employee account could not be verified',
      });
    }
    if (
      rows.some(
        (row) =>
          row.cc_prepared_by_id &&
          Number(row.cc_prepared_by_id) !== employeeId,
      )
    ) {
      await connection.rollback();
      return res.status(403).json({
        success: false,
        message: 'Another handler owns part of this sheet',
      });
    }

    const statuses = rows.map((row) =>
      String(row.cc_status || 'IDLE').toUpperCase(),
    );
    if (
      nextStatus === 'IN PROGRESS' &&
      statuses.some((status) => !['IDLE', 'ON HOLD'].includes(status))
    ) {
      await connection.rollback();
      return res.status(409).json({
        success: false,
        message: 'Only an unstarted or held sheet can be started',
      });
    }
    if (
      nextStatus !== 'IN PROGRESS' &&
      statuses.some((status) => status !== 'IN PROGRESS')
    ) {
      await connection.rollback();
      return res.status(409).json({
        success: false,
        message: 'The whole sheet must be running before it can be held or completed',
      });
    }

    const leader = rows[0];
    leader.sheet_row_count = rows.length;
    const groupWhere = `source_assignment_id = ? AND source_role = ?
      AND source_task_index = ? AND source_active = 1`;
    const groupParams = [assignmentId, sourceRole, taskIndex];

    if (nextStatus === 'IN PROGRESS') {

      // Anything else running (task or category) is held — reason required.
      await autoHoldForEmployee(
        connection,
        { employeeId, employeeName, excludeSheet: `${assignmentId}:${sourceRole}:${taskIndex}` },
        req.body.auto_hold_reason,
      );

      await connection.query(
        `UPDATE content_calendar
         SET cc_status = 'IN PROGRESS', cc_started_at = NULL,
             cc_hold_reason = NULL, cc_last_activity_at = NOW(),
             cc_prepared_by_id = ?, cc_prepared_by_name = ?
         WHERE ${groupWhere}`,
        [employeeId, employeeName, ...groupParams],
      );
      await connection.query(
        `UPDATE content_calendar SET cc_started_at = NOW()
         WHERE id = ?`,
        [leader.id],
      );
      await ensureCalendarDayPlan(connection, leader, req.user, 'IN PROGRESS');
    } else if (nextStatus === 'ON HOLD') {
      await connection.query(
        `UPDATE content_calendar
         SET cc_duration_secs = cc_duration_secs +
               GREATEST(TIMESTAMPDIFF(SECOND, cc_started_at, NOW()), 0),
             cc_started_at = NULL, cc_last_activity_at = NOW()
         WHERE id = ?`,
        [leader.id],
      );
      await connection.query(
        `UPDATE content_calendar
         SET cc_status = 'ON HOLD', cc_started_at = NULL,
             cc_hold_reason = ?, cc_last_activity_at = NOW()
         WHERE ${groupWhere}`,
        [reason, ...groupParams],
      );
      await ensureCalendarDayPlan(connection, leader, req.user, 'ON HOLD');
    } else {
      await connection.query(
        `UPDATE content_calendar
         SET cc_duration_secs = cc_duration_secs +
               GREATEST(TIMESTAMPDIFF(SECOND, cc_started_at, NOW()), 0),
             cc_started_at = NULL, cc_last_activity_at = NOW()
         WHERE id = ?`,
        [leader.id],
      );
      await connection.query(
        `UPDATE content_calendar
         SET cc_status = 'COMPLETED', cc_started_at = NULL,
             cc_hold_reason = NULL, cc_last_activity_at = NOW()
         WHERE ${groupWhere}`,
        groupParams,
      );
      await ensureCalendarDayPlan(connection, leader, req.user, 'COMPLETED');
    }

    await connection.commit();
    sendTaskUpdated(req, leader.id, `SHEET_${nextStatus}`);
    return res.json({
      success: true,
      message: `Deliverable sheet ${nextStatus.toLowerCase()}`,
      rowCount: rows.length,
    });
  } catch (error) {
    if (connection) await connection.rollback();
    console.error(
      `POST /tasks/content-calendar/sheet-${nextStatus.toLowerCase()} ERROR:`,
      error.message,
    );
    return res
      .status(error.statusCode || 500)
      .json({ success: false, message: error.message, code: error.code, running: error.running });
  } finally {
    connection?.release();
  }
}

router.post('/content-calendar/sheet-start', (req, res) =>
  changeCalendarSheetStatus(req, res, 'IN PROGRESS'),
);
router.post('/content-calendar/sheet-hold', (req, res) =>
  changeCalendarSheetStatus(req, res, 'ON HOLD'),
);
router.post('/content-calendar/sheet-complete', (req, res) =>
  changeCalendarSheetStatus(req, res, 'COMPLETED'),
);

async function sourceTaskList(connection, row) {
  const [taskLists] = await connection.query(
    `SELECT id, no_of_rows
     FROM task_list
     WHERE task_assignment_id = ? AND employee_id = ?
       AND LOWER(TRIM(deliverables)) = LOWER(TRIM(?))
     ORDER BY id DESC LIMIT 1 FOR UPDATE`,
    [row.source_assignment_id, row.assigned_to_id, row.deliverable],
  );
  if (taskLists.length) return taskLists[0];

  const [result] = await connection.query(
    `INSERT INTO task_list
       (task_assignment_id, employee_id, employee_name, client_name,
        deliverables, submission_date, no_of_rows)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [
      row.source_assignment_id,
      row.assigned_to_id,
      row.assigned_to_name,
      row.client_name,
      row.deliverable,
      row.submit_date || null,
      Math.max(Number(row.source_row_number) || 1, 1),
    ],
  );
  return { id: result.insertId, no_of_rows: Math.max(Number(row.source_row_number) || 1, 1) };
}

function decrementAssignedTask(value, taskIndex) {
  const entries = String(value || '').split(',');
  const entry = entries[taskIndex];
  if (entry === undefined) return null;
  const match = entry.trim().match(/^(.*?)\s*\((\d+)\)\s*$/);
  if (!match) {
    entries[taskIndex] = '';
    return entries.join(', ');
  }
  const count = Number(match[2]);
  const name = match[1].trim();
  entries[taskIndex] = count <= 1 ? '' : `${name} (${count - 1})`;
  return entries.join(', ');
}

async function assignEmergencySourceRow(connection, row, employee, reason, assignedBy) {
  const role = assignedTaskRoles.find((item) => item.role === row.source_role);
  if (!role || !row.source_assignment_id) {
    throw new Error('The assigned task source is unavailable');
  }
  if (row.cc_handoff_at || row.is_emergency) {
    const error = new Error('This row has already been shared or moved');
    error.statusCode = 409;
    throw error;
  }

  const taskList = await sourceTaskList(connection, row);
  let taskItemId = numericId(row.task_item_id);
  if (!taskItemId) {
    const [result] = await connection.query(
      `INSERT INTO time_tracking_task_items
         (task_list_id, s_no, submit_date, task_description, duration_secs, status)
       VALUES (?, ?, ?, ?, 0, 'IDLE')`,
      [
        taskList.id,
        row.source_row_number,
        row.submit_date || null,
        employeeTaskDescription(row),
      ],
    );
    taskItemId = result.insertId;
  }

  const [items] = await connection.query(
    `SELECT id, status FROM time_tracking_task_items WHERE id = ? FOR UPDATE`,
    [taskItemId],
  );
  if (!items.length) {
    const error = new Error('The allocated tracking row is unavailable');
    error.statusCode = 409;
    throw error;
  }
  if (['IN PROGRESS', 'ON HOLD', 'COMPLETED', 'REJECTED'].includes(String(items[0].status).toUpperCase())) {
    const error = new Error('This employee has already started this row; hold or review it before emergency reassignment');
    error.statusCode = 409;
    throw error;
  }

  const [result] = await connection.query(
    `INSERT INTO task_list
       (employee_id, employee_name, client_name, deliverables,
        submission_date, no_of_rows)
     VALUES (?, ?, ?, ?, ?, 1)`,
    [
      employee.id,
      employee.full_name,
      row.client_name,
      row.deliverable,
      row.submit_date || null,
    ],
  );
  const additionalTaskListId = result.insertId;
  await connection.query(
    `UPDATE task_list SET additional_task_id = ? WHERE id = ?`,
    [additionalTaskListId, additionalTaskListId],
  );

  await connection.query(
    `UPDATE time_tracking_task_items
     SET task_list_id = ?, s_no = 1, submit_date = ?, task_description = ?,
         status = 'IDLE', start_time = NULL, complete_time = NULL, reject_time = NULL,
         duration_secs = 0, comment = ?, description_rich = ?
     WHERE id = ?`,
    [
      additionalTaskListId,
      row.submit_date || null,
      employeeTaskDescription(row),
      `Emergency assignment: ${reason}`,
      row.description_rich || null,
      taskItemId,
    ],
  );
  await connection.query(
    `UPDATE task_list SET no_of_rows = GREATEST(COALESCE(no_of_rows, 1) - 1, 0)
     WHERE id = ?`,
    [taskList.id],
  );
  const [assignmentRows] = await connection.query(
    `SELECT \`${role.tasks}\` AS task_text
     FROM task_assignments WHERE id = ? FOR UPDATE`,
    [row.source_assignment_id],
  );
  const taskCount = decrementAssignedTask(
    assignmentRows[0]?.task_text,
    Number(row.source_task_index),
  );
  if (taskCount !== null) {
    await connection.query(
      `UPDATE task_assignments SET \`${role.tasks}\` = ? WHERE id = ?`,
      [taskCount, row.source_assignment_id],
    );
  }

  const wasPreparing = String(row.cc_status || '').toUpperCase() === 'IN PROGRESS';
  await connection.query(
    `UPDATE content_calendar
     SET task_item_id = ?, assigned_to_id = ?, assigned_to_name = ?,
         assigned_by_id = ?, assigned_by_name = ?, is_emergency = 1,
         cc_emergency_reason = ?, cc_handoff_at = NOW(), source_active = 0,
         cc_status = ?, cc_started_at = NULL, cc_last_activity_at = NOW(),
         cc_hold_reason = ?
     WHERE id = ?`,
    [
      taskItemId,
      employee.id,
      employee.full_name,
      assignedBy.id,
      assignedBy.fullName,
      reason,
      wasPreparing ? 'ON HOLD' : row.cc_status,
      wasPreparing ? 'Stopped because this row was moved to an emergency task' : row.cc_hold_reason,
      row.id,
    ],
  );
  if (Number(row.cc_duration_secs) > 0 || row.cc_started_at) {
    const [remainingRows] = await connection.query(
      `SELECT id FROM content_calendar
       WHERE source_assignment_id = ? AND source_role = ?
         AND source_task_index = ? AND source_active = 1
       ORDER BY source_row_number ASC LIMIT 1 FOR UPDATE`,
      [row.source_assignment_id, row.source_role, row.source_task_index],
    );
    if (remainingRows.length) {
      await connection.query(
        `UPDATE content_calendar
         SET cc_duration_secs = cc_duration_secs + ?,
             cc_started_at = CASE
               WHEN ? = 1 THEN COALESCE(cc_started_at, ?)
               ELSE cc_started_at
             END,
             cc_last_activity_at = NOW()
         WHERE id = ?`,
        [
          Number(row.cc_duration_secs) || 0,
          wasPreparing ? 1 : 0,
          row.cc_started_at,
          remainingRows[0].id,
        ],
      );
      if (wasPreparing) {
        await connection.query(
          `UPDATE day_plan_rows
           SET today_plan = REPLACE(
                 today_plan, ?, ?
               )
           WHERE employee_name = ? AND plan_date = CURDATE()
             AND report_type = 'Morning'`,
          [
            `[Calendar Row #${row.id}]`,
            `[Calendar Row #${remainingRows[0].id}]`,
            row.cc_prepared_by_name,
          ],
        );
      }
    }
  }
  await connection.query(
    `INSERT INTO notifications (sender_name, recipient_name, message)
     VALUES (?, ?, ?)`,
    [
      assignedBy.fullName,
      employee.full_name,
      `Emergency ${row.deliverable} task for ${row.client_name}: "${row.hook_headline || row.deliverable}". Reason: ${reason}`,
    ],
  );
  return taskItemId;
}

async function shareSheetRoute(req, res) {
  if (!requireContentHandler(req, res)) return;
  const assignmentId = numericId(req.body.source_assignment_id);
  const sourceRole = String(req.body.source_role || '').trim();
  const taskIndex = Number(req.body.source_task_index);
  if (!assignmentId || !sourceRole || !Number.isSafeInteger(taskIndex) || taskIndex < 0) {
    return res.status(400).json({ success: false, message: 'A valid source task sheet is required' });
  }

  let connection;
  try {
    connection = await db.getConnection();
    await connection.beginTransaction();
    const [rows] = await connection.query(
      `SELECT * FROM content_calendar
       WHERE source_assignment_id = ? AND source_role = ?
         AND source_task_index = ? AND source_active = 1
       ORDER BY source_row_number ASC FOR UPDATE`,
      [assignmentId, sourceRole, taskIndex],
    );
    if (!rows.length) {
      await connection.rollback();
      return res.status(404).json({ success: false, message: 'No active rows found for this sheet' });
    }
    if (rows.some((row) => row.cc_handoff_at || row.is_emergency)) {
      await connection.rollback();
      return res.status(409).json({ success: false, message: 'This sheet has already been shared or changed' });
    }
    if (rows.some((row) => String(row.cc_status).toUpperCase() !== 'COMPLETED')) {
      await connection.rollback();
      return res.status(409).json({ success: false, message: 'Complete every row before sharing this sheet' });
    }
    if (rows.some((row) => Number(row.cc_prepared_by_id) !== Number(req.user.id))) {
      await connection.rollback();
      return res.status(403).json({ success: false, message: 'Only the handler who prepared every row can share this sheet' });
    }
    const employeeId = numericId(rows[0].assigned_to_id);
    const employeeName = String(rows[0].assigned_to_name || '').trim();
    if (!employeeId || rows.some((row) => Number(row.assigned_to_id) !== employeeId)) {
      await connection.rollback();
      return res.status(409).json({ success: false, message: 'This sheet does not have one allocated employee' });
    }
    const employee = await findEmployee(connection, employeeId, employeeName);
    if (!employee) {
      await connection.rollback();
      return res.status(404).json({ success: false, message: 'The allocated employee is unavailable' });
    }
    const [leaveRows] = await connection.query(isOnLeaveSql(), [employee.id]);
    if (Number(leaveRows[0]?.is_on_leave) === 1) {
      await connection.rollback();
      return res.status(409).json({ success: false, message: `${employee.full_name} is on approved leave today` });
    }

    const taskList = await sourceTaskList(connection, rows[0]);
    const rowCount = rows.length;
    for (let rowIndex = 0; rowIndex < rows.length; rowIndex += 1) {
      const row = rows[rowIndex];
      const taskRowNumber = rowIndex + 1;
      let taskItemId = numericId(row.task_item_id);
      if (!taskItemId) {
        const [created] = await connection.query(
          `INSERT INTO time_tracking_task_items
             (task_list_id, s_no, submit_date, task_description, duration_secs, status)
           VALUES (?, ?, ?, ?, 0, 'IDLE')`,
          [
            taskList.id,
            taskRowNumber,
            row.submit_date || null,
            employeeTaskDescription(row),
          ],
        );
        taskItemId = created.insertId;
      }
      await connection.query(
        `UPDATE time_tracking_task_items
         SET task_list_id = ?, submit_date = ?, task_description = ?,
             s_no = ?,
             content_calendar_assigned = 1, content_calendar_assigned_to = ?,
             hook_headline = ?, description_points = ?, caption = ?, cta = ?,
             publish_date = ?, cc_assigned_to_id = ?, cc_assigned_by_name = ?,
             cc_assigned_at = NOW(), notes = ?, description_rich = ?
         WHERE id = ?`,
        [
          taskList.id,
          row.submit_date || null,
          employeeTaskDescription(row),
          taskRowNumber,
          employee.full_name,
          row.hook_headline || '',
          row.description || '',
          row.caption || '',
          row.cta || '',
          row.publish_date || null,
          employee.id,
          req.user.fullName,
          row.notes || '',
          row.description_rich || null,
          taskItemId,
        ],
      );
      await connection.query(
        `UPDATE content_calendar SET task_item_id = ? WHERE id = ?`,
        [taskItemId, row.id],
      );
    }
    await connection.query(
      `UPDATE task_list SET no_of_rows = ?
       WHERE id = ?`,
      [rowCount, taskList.id],
    );
    await connection.query(
      `UPDATE content_calendar
       SET cc_handoff_at = NOW(), assigned_by_id = ?, assigned_by_name = ?
           , cc_last_activity_at = NOW()
       WHERE source_assignment_id = ? AND source_role = ?
         AND source_task_index = ? AND source_active = 1`,
      [req.user.id, req.user.fullName, assignmentId, sourceRole, taskIndex],
    );
    await connection.query(
      `INSERT INTO notifications (sender_name, recipient_name, message)
       VALUES (?, ?, ?)`,
      [
        req.user.fullName,
        employee.full_name,
        `Prepared ${rows.length} ${rows[0].deliverable} rows for ${rows[0].client_name} are ready in your assigned tasks.`,
      ],
    );
    await connection.commit();
    req.app.get('io')?.emit('calendar:assigned', {
      client_id: rows[0].client_id,
      deliverable: rows[0].deliverable,
      assigned_to_name: employee.full_name,
    });
    sendTaskUpdated(req, rows[0].id, 'SHEET_ASSIGNED');
    return res.json({ success: true, message: `Shared ${rows.length} rows with ${employee.full_name}` });
  } catch (error) {
    if (connection) await connection.rollback();
    console.error('POST /tasks/content-calendar/assign-sheet ERROR:', error.message);
    return res.status(error.statusCode || 500).json({ success: false, message: error.message });
  } finally {
    connection?.release();
  }
}

async function assignRoute(req, res, emergency = false) {
  if (!requireContentHandler(req, res)) return;
  const id = numericId(req.body.task_item_id);
  const employeeName = String(req.body.assigned_to_name || '').trim();
  const employeeId = numericId(req.body.assigned_to_id);
  const reason = String(req.body.reason || '').trim();
  if (!id) return res.status(400).json({ success: false, message: 'A valid calendar row id is required' });
  if (!employeeId && !employeeName) return res.status(400).json({ success: false, message: 'Select an employee' });
  if (emergency && !reason) return res.status(400).json({ success: false, message: 'Emergency reason is required' });

  let connection;
  try {
    connection = await db.getConnection();
    await connection.beginTransaction();
    const row = await getCalendarRow(connection, id, true);
    if (!row) {
      await connection.rollback();
      return res.status(404).json({ success: false, message: 'Calendar row not found' });
    }
    if (!emergency && String(row.cc_status).toUpperCase() !== 'COMPLETED') {
      await connection.rollback();
      return res.status(409).json({ success: false, message: 'Complete the calendar row before assigning it' });
    }
    if (!emergency && row.assigned_to_id) {
      await connection.rollback();
      return res.status(409).json({ success: false, message: 'This calendar row is already assigned' });
    }

    const employee = await findEmployee(connection, employeeId, employeeName);
    if (!employee) {
      await connection.rollback();
      return res.status(404).json({ success: false, message: 'The selected employee is unavailable' });
    }
    const [leaveRows] = await connection.query(
      `SELECT EXISTS(
         SELECT 1 FROM employee_leaves
         WHERE employee_id = ? AND status = 'APPROVED'
           AND CURDATE() BETWEEN from_date AND to_date
       ) AS is_on_leave`,
      [employee.id],
    );
    if (Number(leaveRows[0]?.is_on_leave) === 1) {
      await connection.rollback();
      return res.status(409).json({ success: false, message: 'The selected employee is on approved leave today' });
    }
    if (row.source_assignment_id) {
      if (!emergency) {
        await connection.rollback();
        return res.status(409).json({
          success: false,
          message: 'Share a source task as a complete sheet after every row is prepared',
        });
      }
      const taskItemId = await assignEmergencySourceRow(
        connection,
        row,
        employee,
        reason,
        { id: req.user.id, fullName: req.user.fullName },
      );
      await connection.commit();
      req.app.get('io')?.emit('calendar:assigned', {
        client_id: row.client_id,
        deliverable: row.deliverable,
        hook_headline: row.hook_headline,
        assigned_to_name: employee.full_name,
      });
      sendTaskUpdated(req, id, 'EMERGENCY_ASSIGNED');
      return res.json({
        success: true,
        message: 'Calendar row moved to Additional Tasks',
        task_item_id: taskItemId,
      });
    }
    const assignedByName = req.user.fullName;
    const assignedById = numericId(req.user.id);
    const taskItemId = await assignCalendarRow(
      connection,
      row,
      employee,
      assignedById,
      assignedByName,
      emergency ? reason : null,
      null,
    );
    await connection.commit();

    req.app.get('io')?.emit('calendar:assigned', {
      client_id: row.client_id,
      deliverable: row.deliverable,
      hook_headline: row.hook_headline,
      assigned_to_name: employee.full_name,
    });
    sendTaskUpdated(req, id, 'ASSIGNED');
    return res.json({
      success: true,
      message: emergency ? 'Calendar row emergency-assigned' : 'Calendar row assigned',
      task_item_id: taskItemId,
    });
  } catch (error) {
    if (connection) await connection.rollback();
    console.error(`POST /tasks/content-calendar/${emergency ? 'emergency-assign' : 'assign-row'} ERROR:`, error.message);
    return res.status(500).json({ success: false, message: error.message });
  } finally {
    connection?.release();
  }
}

// POST /tasks/content-calendar/reassign-row
// "Edit" on an already-assigned Content Calendar row: move that one row to a
// different employee.
//   normal    → only while the current employee has not started it
//   emergency → reason required; works for held / rework rows too (the new
//               employee gets it as an Additional Task with a fresh timer)
async function reassignRowRoute(req, res) {
  if (!requireContentHandler(req, res)) return;
  const id = numericId(req.body.task_item_id);
  const employeeId = numericId(req.body.assigned_to_id);
  const employeeName = String(req.body.assigned_to_name || '').trim();
  const emergency = req.body.emergency === true;
  const reason = String(req.body.reason || '').trim();
  if (!id) return res.status(400).json({ success: false, message: 'A valid calendar row id is required' });
  if (!employeeId && !employeeName) return res.status(400).json({ success: false, message: 'Select an employee' });
  if (emergency && !reason) return res.status(400).json({ success: false, message: 'Emergency reason is required' });

  let connection;
  try {
    connection = await db.getConnection();
    await connection.beginTransaction();
    const row = await getCalendarRow(connection, id, true);
    if (!row) {
      await connection.rollback();
      return res.status(404).json({ success: false, message: 'Calendar row not found' });
    }
    if (!row.cc_handoff_at || !numericId(row.task_item_id)) {
      await connection.rollback();
      return res.status(409).json({ success: false, message: 'This row has not been assigned yet — use Assign All or Emergency assign' });
    }
    const [[item]] = await connection.query(
      `SELECT tti.*, tl.employee_id AS current_employee_id, tl.employee_name AS current_employee_name,
              tl.id AS current_list_id
       FROM time_tracking_task_items tti
       JOIN task_list tl ON tl.id = tti.task_list_id
       WHERE tti.id = ? FOR UPDATE`,
      [row.task_item_id],
    );
    if (!item) {
      await connection.rollback();
      return res.status(404).json({ success: false, message: 'The assigned task row is unavailable' });
    }
    const status = String(item.status || 'IDLE').toUpperCase();
    const review = String(item.review_status || '').toUpperCase();
    if (review === 'APPROVED') {
      await connection.rollback();
      return res.status(409).json({ success: false, message: 'This row is approved and cannot be moved' });
    }
    if (status === 'COMPLETED') {
      await connection.rollback();
      return res.status(409).json({ success: false, message: 'This row is waiting for review — approve or send it for rework first' });
    }
    if (status === 'IN PROGRESS') {
      await connection.rollback();
      return res.status(409).json({ success: false, message: `${item.current_employee_name} is working on this row now — ask them to hold it first` });
    }
    const started = Boolean(item.start_time) || status !== 'IDLE';
    if (started && !emergency) {
      await connection.rollback();
      return res.status(409).json({
        success: false,
        message: `${item.current_employee_name} has already started this row. Use Emergency reassign with a reason.`,
      });
    }

    const employee = await findEmployee(connection, employeeId, employeeName);
    if (!employee) {
      await connection.rollback();
      return res.status(404).json({ success: false, message: 'The selected employee is unavailable' });
    }
    if (Number(employee.id) === Number(item.current_employee_id)) {
      await connection.rollback();
      return res.status(400).json({ success: false, message: `This row is already assigned to ${employee.full_name}` });
    }
    const [leaveRows] = await connection.query(isOnLeaveSql(), [employee.id]);
    if (Number(leaveRows[0]?.is_on_leave) === 1) {
      await connection.rollback();
      return res.status(409).json({ success: false, message: `${employee.full_name} is on approved leave today` });
    }

    let targetListId;
    if (emergency) {
      const [ins] = await connection.query(
        `INSERT INTO task_list
           (employee_id, employee_name, client_name, deliverables, submission_date, no_of_rows)
         VALUES (?, ?, ?, ?, ?, 0)`,
        [employee.id, employee.full_name, row.client_name, row.deliverable, row.submit_date || null],
      );
      targetListId = ins.insertId;
      await connection.query('UPDATE task_list SET additional_task_id = ? WHERE id = ?', [targetListId, targetListId]);
    } else {
      const [lists] = await connection.query(
        `SELECT id FROM task_list
         WHERE task_assignment_id = ? AND employee_id = ? AND additional_task_id IS NULL
           AND LOWER(TRIM(deliverables)) = LOWER(TRIM(?))
         ORDER BY id DESC LIMIT 1 FOR UPDATE`,
        [row.source_assignment_id, employee.id, row.deliverable],
      );
      if (lists.length) {
        targetListId = lists[0].id;
      } else {
        const [ins] = await connection.query(
          `INSERT INTO task_list
             (task_assignment_id, employee_id, employee_name, client_name, deliverables,
              submission_date, no_of_rows)
           VALUES (?, ?, ?, ?, ?, ?, 0)`,
          [row.source_assignment_id, employee.id, employee.full_name, row.client_name,
            row.deliverable, row.submit_date || null],
        );
        targetListId = ins.insertId;
      }
    }

    const [[{ nextSno }]] = await connection.query(
      `SELECT COALESCE(MAX(s_no), 0) + 1 AS nextSno FROM time_tracking_task_items
       WHERE task_list_id = ? AND parent_item_id IS NULL`,
      [targetListId],
    );
    const resetTimes = Array.from({ length: 10 }, (_, i) => `hold_time_${i + 1} = NULL, restart_time_${i + 1} = NULL`).join(', ');
    const note = emergency
      ? `Emergency reassigned from ${item.current_employee_name} to ${employee.full_name}: ${reason}`
      : `Reassigned from ${item.current_employee_name} to ${employee.full_name}`;
    await connection.query(
      `UPDATE time_tracking_task_items
       SET task_list_id = ?, s_no = ?, sub_no = 0, status = 'IDLE', review_status = NULL,
           start_time = NULL, complete_time = NULL, reject_time = NULL, duration_secs = 0,
           ${resetTimes},
           content_calendar_assigned = 1, content_calendar_assigned_to = ?, cc_assigned_to_id = ?,
           comment = CONCAT(COALESCE(comment, ''), IF(COALESCE(comment, '') = '', '', '\n'), ?)
       WHERE id = ?`,
      [targetListId, nextSno, employee.full_name, employee.id, note, item.id],
    );
    await connection.query('DELETE FROM manager_review WHERE tracking_item_id = ?', [item.id]);
    await connection.query(
      'UPDATE task_list SET no_of_rows = GREATEST(COALESCE(no_of_rows, 1) - 1, 0) WHERE id = ?',
      [item.current_list_id],
    );
    await connection.query(
      'UPDATE task_list SET no_of_rows = COALESCE(no_of_rows, 0) + 1 WHERE id = ?',
      [targetListId],
    );
    await connection.query(
      `UPDATE content_calendar
       SET assigned_to_id = ?, assigned_to_name = ?, assigned_by_id = ?, assigned_by_name = ?,
           cc_reassigned = 1, cc_emergency_reason = ?, cc_last_activity_at = NOW()
       WHERE id = ?`,
      [employee.id, employee.full_name, req.user.id, req.user.fullName, emergency ? reason : null, row.id],
    );
    const label = `${row.deliverable} row ${row.source_row_number || row.s_no} for ${row.client_name}`;
    await connection.query(
      `INSERT INTO notifications (sender_name, recipient_name, message) VALUES (?, ?, ?), (?, ?, ?)`,
      [
        req.user.fullName, employee.full_name,
        `${emergency ? 'Emergency task' : 'New task'}: ${label} has been assigned to you.${emergency ? ` Reason: ${reason}` : ''}`,
        req.user.fullName, item.current_employee_name,
        `${label} has been moved to ${employee.full_name}.`,
      ],
    );
    await connection.commit();
    sendTaskUpdated(req, row.id, emergency ? 'EMERGENCY_REASSIGNED' : 'REASSIGNED');
    req.app.get('io')?.emit('calendar:assigned', {
      client_id: row.client_id,
      deliverable: row.deliverable,
      assigned_to_name: employee.full_name,
    });
    return res.json({ success: true, message: `Row moved to ${employee.full_name}` });
  } catch (error) {
    if (connection) await connection.rollback();
    console.error('POST /tasks/content-calendar/reassign-row ERROR:', error.message);
    return res.status(error.statusCode || 500).json({ success: false, message: error.message });
  } finally {
    connection?.release();
  }
}

router.post('/content-calendar/reassign-row', reassignRowRoute);

// ── Handler-written content rows ─────────────────────────────────────────────
// GET /tasks/content-calendar/deliverable-options/:clientName
// Category names for "Add content": the client's assigned deliverables
// (ads first for an Ads Handler, pages for a Page Handler) + existing
// calendar categories.
router.get('/content-calendar/deliverable-options/:clientName', async (req, res) => {
  if (!requireContentHandler(req, res)) return;
  const clientName = String(req.params.clientName || '').trim();
  try {
    const [assignments] = await db.query(
      `SELECT * FROM task_assignments
       WHERE LOWER(TRIM(client_name)) = LOWER(TRIM(?)) AND is_assigned = 1`,
      [clientName],
    );
    const role = normalizedRole(req.user?.role || req.user?.userType);
    const columns = [
      ['ads_platform', 'Ads'],
      ['pages_platform', 'Page'],
      ['designer_tasks', 'Designer'],
      ['video_editor_task', 'Video Editor'],
      ['videographer_tasks', 'Videographer'],
      ['website_designer_tasks', 'Website Designer'],
    ];
    if (role === 'page_handler') columns.unshift(columns.splice(1, 1)[0]);
    const seen = new Set();
    const options = [];
    const add = (name, group) => {
      const clean = String(name || '').trim();
      if (!clean || seen.has(clean.toUpperCase())) return;
      seen.add(clean.toUpperCase());
      options.push({ name: clean, group });
    };
    for (const [column, group] of columns) {
      for (const a of assignments) {
        for (const task of parseAssignedTasks(a[column])) add(task.name, group);
      }
    }
    const [existing] = await db.query(
      `SELECT DISTINCT deliverable FROM content_calendar
       WHERE LOWER(TRIM(client_name)) = LOWER(TRIM(?))`,
      [clientName],
    );
    for (const r of existing) add(r.deliverable, 'Calendar');
    return res.json({ success: true, data: options });
  } catch (error) {
    console.error('GET /tasks/content-calendar/deliverable-options ERROR:', error.message);
    return res.status(500).json({ success: false, message: error.message });
  }
});

// POST /tasks/content-calendar/add-row { client_name, deliverable, submit_date?, count? }
// Adds blank row(s) the handler fills in, same card format as other rows.
router.post('/content-calendar/add-row', async (req, res) => {
  if (!requireContentHandler(req, res)) return;
  const clientName = String(req.body.client_name || '').trim();
  const deliverable = String(req.body.deliverable || '').trim();
  const count = Math.min(Math.max(Number(req.body.count) || 1, 1), 50);
  const submitDate = /^\d{4}-\d{2}-\d{2}$/.test(String(req.body.submit_date || '').slice(0, 10))
    ? String(req.body.submit_date).slice(0, 10)
    : null;
  if (!clientName || !deliverable) {
    return res.status(400).json({ success: false, message: 'client_name and deliverable are required' });
  }
  let connection;
  try {
    connection = await db.getConnection();
    await connection.beginTransaction();
    const [clients] = await connection.query(
      'SELECT id, company_name FROM clients WHERE LOWER(TRIM(company_name)) = LOWER(TRIM(?)) LIMIT 1',
      [clientName],
    );
    if (!clients.length) {
      await connection.rollback();
      return res.status(404).json({ success: false, message: 'Client not found' });
    }
    const [[{ nextNo }]] = await connection.query(
      `SELECT COALESCE(MAX(s_no), 0) + 1 AS nextNo FROM content_calendar
       WHERE LOWER(TRIM(client_name)) = LOWER(TRIM(?))
         AND UPPER(TRIM(deliverable)) = UPPER(TRIM(?)) FOR UPDATE`,
      [clientName, deliverable],
    );
    const ids = [];
    for (let i = 0; i < count; i += 1) {
      const [ins] = await connection.query(
        `INSERT INTO content_calendar
           (client_id, client_name, s_no, deliverable, hook_headline, submit_date, assigned_by_name)
         VALUES (?, ?, ?, ?, '', ?, ?)`,
        [clients[0].id, clients[0].company_name, nextNo + i, deliverable, submitDate, req.user.fullName],
      );
      ids.push(ins.insertId);
    }
    await connection.commit();
    sendTaskUpdated(req, ids[0], 'ROW_ADDED');
    return res.status(201).json({ success: true, message: `${count} ${deliverable} row(s) added`, ids });
  } catch (error) {
    if (connection) await connection.rollback();
    console.error('POST /tasks/content-calendar/add-row ERROR:', error.message);
    return res.status(500).json({ success: false, message: error.message });
  } finally {
    connection?.release();
  }
});

// DELETE /tasks/content-calendar/row/:id — only a handler-added row that has
// not been started or assigned.
router.delete('/content-calendar/row/:id', async (req, res) => {
  if (!requireContentHandler(req, res)) return;
  const id = numericId(req.params.id);
  if (!id) return res.status(400).json({ success: false, message: 'A valid calendar row id is required' });
  try {
    const [[row]] = await db.query('SELECT * FROM content_calendar WHERE id = ?', [id]);
    if (!row) return res.status(404).json({ success: false, message: 'Calendar row not found' });
    if (row.source_assignment_id) {
      return res.status(409).json({ success: false, message: 'Rows from the admin assignment cannot be deleted here' });
    }
    if (row.assigned_to_id || row.task_item_id || !['', 'IDLE'].includes(String(row.cc_status || '').toUpperCase())) {
      return res.status(409).json({ success: false, message: 'This row has already been started or assigned' });
    }
    await db.query('DELETE FROM content_calendar WHERE id = ?', [id]);
    sendTaskUpdated(req, id, 'ROW_DELETED');
    return res.json({ success: true, message: 'Row removed' });
  } catch (error) {
    console.error('DELETE /tasks/content-calendar/row/:id ERROR:', error.message);
    return res.status(500).json({ success: false, message: error.message });
  }
});

router.post('/content-calendar/assign-sheet', shareSheetRoute);
router.post('/content-calendar/assign-row', (req, res) => assignRoute(req, res));
router.post('/content-calendar/emergency-assign', (req, res) => assignRoute(req, res, true));

router.get('/check-leave/:employeeName', async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT EXISTS(
         SELECT 1
         FROM employee_users eu
         JOIN employee_leaves el ON el.employee_id = eu.id
         WHERE LOWER(TRIM(eu.full_name)) = LOWER(TRIM(?))
           AND el.status = 'APPROVED'
           AND CURDATE() BETWEEN el.from_date AND el.to_date
       ) AS is_on_leave`,
      [req.params.employeeName],
    );
    return res.json({ success: true, is_on_leave: Number(rows[0]?.is_on_leave) === 1 });
  } catch (error) {
    console.error('GET /tasks/check-leave/:employeeName ERROR:', error.message);
    return res.status(500).json({ success: false, message: error.message });
  }
});

router.get('/content-calendar/export', async (req, res) => {
  const clientName = String(req.query.client || '').trim();
  const deliverable = String(req.query.deliverable || '').trim();
  if (!clientName || !deliverable) {
    return res.status(400).json({ success: false, message: 'client and deliverable are required' });
  }
  // Only the rows of the card + category open on screen (ids from the app).
  const ids = parseIds(req.query.ids);
  const cardDate = String(req.query.date || '').trim().slice(0, 10);
  try {
    const [rows] = await db.query(
      `SELECT id, deliverable, s_no, submit_date, hook_headline, description AS description_points,
              caption, cta, publish_date, notes
       FROM content_calendar
       WHERE LOWER(TRIM(client_name)) = LOWER(TRIM(?))
         AND UPPER(TRIM(deliverable)) = UPPER(TRIM(?))
         ${ids.length ? 'AND id IN (?)' : ''}
       ORDER BY s_no ASC, id ASC`,
      ids.length ? [clientName, deliverable, ids] : [clientName, deliverable],
    );
    const safeName = `${clientName}-${deliverable}${cardDate ? `-${cardDate}` : ''}`
      .replace(/[^a-z0-9_-]+/gi, '-');
    if (String(req.query.format || 'xlsx').toLowerCase() === 'csv') {
      res.setHeader('Content-Type', 'text/csv; charset=utf-8');
      res.setHeader('Content-Disposition', `attachment; filename="${safeName}-content-calendar.csv"`);
      return res.send(toCsv(rows));
    }
    // Styled blue & white template — opens in Google Sheets / Excel.
    const buffer = await buildTemplate({
      clientName,
      deliverable,
      rows,
      exportedBy: req.user?.fullName || '',
      cardDate,
    });
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', `attachment; filename="${safeName}-content-calendar.xlsx"`);
    return res.send(buffer);
  } catch (error) {
    console.error('GET /tasks/content-calendar/export ERROR:', error.message);
    return res.status(500).json({ success: false, message: error.message });
  }
});

// "12,13,14" or [12,13,14] → [12, 13, 14]
function parseIds(value) {
  const list = Array.isArray(value) ? value : String(value ?? '').split(',');
  return [...new Set(list.map((v) => Number(v)).filter((n) => Number.isSafeInteger(n) && n > 0))];
}

// Upload (.xlsx as base64, or .csv text) → { updates, skipped, columns }
// body.ids = rows of the card open on screen; other rows in the file are skipped.
async function importPlan(clientName, deliverable, body) {
  const ids = parseIds(body.ids);
  const [rows] = await db.query(
    `SELECT id, deliverable, s_no, submit_date, hook_headline, description, caption, cta,
            publish_date, notes
     FROM content_calendar
     WHERE LOWER(TRIM(client_name)) = LOWER(TRIM(?))
       AND UPPER(TRIM(deliverable)) = UPPER(TRIM(?))
       ${ids.length ? 'AND id IN (?)' : ''}`,
    ids.length ? [clientName, deliverable, ids] : [clientName, deliverable],
  );
  if (!rows.length) return { error: `No ${deliverable} rows for ${clientName} in this card` };
  const parsed = await parseUpload({ csv: body.csv, html: body.html, xlsx_base64: body.xlsx_base64 });
  return planUpdates(parsed, rows);
}

const hasUpload = (b) => typeof b.csv === 'string' || typeof b.html === 'string' || typeof b.xlsx_base64 === 'string';

router.post('/content-calendar/import-preview', async (req, res) => {
  const clientName = String(req.body.client_name || '').trim();
  const deliverable = String(req.body.deliverable || '').trim();
  if (!clientName || !deliverable || !hasUpload(req.body)) {
    return res.status(400).json({ success: false, message: 'client_name, deliverable and a file are required' });
  }
  try {
    const plan = await importPlan(clientName, deliverable, req.body);
    if (plan.error) return res.status(400).json({ success: false, message: plan.error });
    return res.json({
      success: true,
      update_count: plan.updates.length,
      skipped: plan.skipped,
      columns: plan.columns,
      changes: plan.updates.slice(0, 50).map((u) => ({ id: u.id, fields: Object.keys(u.fields) })),
    });
  } catch (error) {
    console.error('POST /tasks/content-calendar/import-preview ERROR:', error.message);
    return res.status(500).json({ success: false, message: `Could not read the file: ${error.message}` });
  }
});

router.post('/content-calendar/import', async (req, res) => {
  const clientName = String(req.body.client_name || '').trim();
  const deliverable = String(req.body.deliverable || '').trim();
  if (!clientName || !deliverable || !hasUpload(req.body)) {
    return res.status(400).json({ success: false, message: 'client_name, deliverable and a file are required' });
  }

  let connection;
  try {
    const plan = await importPlan(clientName, deliverable, req.body);
    if (plan.error) return res.status(400).json({ success: false, message: plan.error });
    connection = await db.getConnection();
    await connection.beginTransaction();
    for (const update of plan.updates) {
      const [existing] = await connection.query(
        `SELECT id FROM content_calendar
         WHERE id = ? AND LOWER(TRIM(client_name)) = LOWER(TRIM(?))
           AND UPPER(TRIM(deliverable)) = UPPER(TRIM(?))
         FOR UPDATE`,
        [update.id, clientName, deliverable],
      );
      if (!existing.length) throw new Error(`Calendar row ${update.id} no longer exists`);
      const fields = Object.entries(update.fields)
        .map(([key, value]) => [editableFields[key], value]);
      const sets = fields.map(([column]) => `\`${column}\` = ?`).join(', ') +
        (fields.some(([column]) => column === 'submit_date') ? ', cc_submit_edited = 1' : '');
      await connection.query(
        `UPDATE content_calendar SET ${sets}
         WHERE id = ? AND LOWER(TRIM(client_name)) = LOWER(TRIM(?))
           AND UPPER(TRIM(deliverable)) = UPPER(TRIM(?))`,
        [...fields.map(([, value]) => value), update.id, clientName, deliverable],
      );
      await syncAssignedTaskDetails(connection, update.id);
    }
    await connection.commit();
    req.app.get('io')?.emit('task_updated', { type: 'CONTENT_CALENDAR_IMPORT', clientName, deliverable });
    return res.json({
      success: true,
      applied_count: plan.updates.length,
      skipped: plan.skipped,
    });
  } catch (error) {
    if (connection) await connection.rollback();
    console.error('POST /tasks/content-calendar/import ERROR:', error.message);
    return res.status(500).json({ success: false, message: error.message });
  } finally {
    connection?.release();
  }
});

// POST /tasks/content-calendar/add-to-planner { calendar_id }
// Adds this Content Calendar category (or manual row) to today's Day Planner
// without starting it. Safe to call twice.
router.post('/content-calendar/add-to-planner', async (req, res) => {
  const id = numericId(req.body?.calendar_id);
  const employeeName = String(req.user?.fullName || '').trim();
  if (!id || !employeeName) {
    return res.status(400).json({ success: false, message: 'calendar_id is required' });
  }
  try {
    const row = await getCalendarRow(db, id);
    if (!row) return res.status(404).json({ success: false, message: 'Calendar row not found' });
    let leader = row;
    if (row.source_assignment_id) {
      const [group] = await db.query(
        `SELECT * FROM content_calendar
         WHERE source_assignment_id = ? AND source_role = ?
           AND source_task_index = ? AND source_active = 1
         ORDER BY source_row_number ASC`,
        [row.source_assignment_id, row.source_role, row.source_task_index],
      );
      if (group.length) {
        leader = group[0];
        leader.sheet_row_count = group.length;
      }
    }
    const [existing] = await db.query(
      `SELECT id FROM day_plan_rows
       WHERE employee_name = ? AND plan_date = CURDATE() AND report_type = 'Morning'
         AND today_plan LIKE ? LIMIT 1`,
      [employeeName, `%[Calendar Row #${leader.id}]%`],
    );
    if (existing.length) {
      return res.json({ success: true, added: false, calendar_id: leader.id, message: 'Already in today’s Day Planner' });
    }
    await ensureCalendarDayPlan(db, leader, req.user, String(leader.cc_status || 'IDLE').toUpperCase(), true);
    sendTaskUpdated(req, leader.id, leader.cc_status || 'IDLE');
    return res.json({ success: true, added: true, calendar_id: leader.id, message: 'Added to today’s Day Planner' });
  } catch (err) {
    console.error('POST /tasks/content-calendar/add-to-planner ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
