// lib/autoHold.js — one running item per employee.
// Starting a task or a Content Calendar category puts whatever else the
// employee is running ON HOLD — but only after they give a reason.
//
// Throws { statusCode: 409, code: 'AUTO_HOLD_REASON_REQUIRED', running: [...] }
// when something is running and no reason was sent.

function workingSeconds(row) {
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

async function findRunning(connection, { employeeId, employeeName, excludeTaskId = null, excludeSheet = null }) {
  const byEmployee = employeeId
    ? 'tl.employee_id = ?'
    : 'LOWER(TRIM(tl.employee_name)) = LOWER(TRIM(?))';
  const [tasks] = await connection.query(
    `SELECT tti.*, tl.deliverables, tl.client_name
     FROM time_tracking_task_items tti
     JOIN task_list tl ON tl.id = tti.task_list_id
     WHERE tti.status = 'IN PROGRESS' AND ${byEmployee}
       ${excludeTaskId ? 'AND tti.id <> ?' : ''}
     FOR UPDATE`,
    excludeTaskId ? [employeeId || employeeName, excludeTaskId] : [employeeId || employeeName],
  );

  let sheets = [];
  if (employeeId) {
    const [ccRows] = await connection.query(
      `SELECT id, client_name, deliverable, source_assignment_id, source_role, source_task_index
       FROM content_calendar
       WHERE cc_prepared_by_id = ? AND cc_status = 'IN PROGRESS'
       FOR UPDATE`,
      [employeeId],
    );
    const groups = new Map();
    for (const r of ccRows) {
      const key = r.source_assignment_id
        ? `${r.source_assignment_id}:${r.source_role}:${r.source_task_index}`
        : `row:${r.id}`;
      if (excludeSheet && key === excludeSheet) continue;
      if (!groups.has(key)) groups.set(key, { key, rows: [], first: r });
      groups.get(key).rows.push(r);
    }
    sheets = [...groups.values()];
  }
  return { tasks, sheets };
}

function describeRunning({ tasks, sheets }) {
  return [
    ...tasks.map((t) => ({
      kind: 'TASK',
      id: t.id,
      title: `${t.deliverables} · Row ${t.s_no} · ${t.client_name}`,
    })),
    ...sheets.map((s) => ({
      kind: 'CONTENT_CALENDAR',
      key: s.key,
      title: `Content Calendar · ${s.first.deliverable} · ${s.first.client_name}`,
    })),
  ];
}

async function holdRunning(connection, running, reason, employeeName) {
  const heldTaskIds = [];
  for (const task of running.tasks) {
    let slot = null;
    for (let i = 1; i <= 10; i += 1) {
      if (task[`hold_time_${i}`] === null) { slot = i; break; }
    }
    if (slot === null) {
      const error = new Error(`"${task.deliverables}" has reached its maximum number of holds`);
      error.statusCode = 409;
      throw error;
    }
    await connection.query(
      `UPDATE time_tracking_task_items
       SET hold_time_${slot} = NOW(), status = 'ON HOLD',
           comment = CONCAT(COALESCE(comment, ''), IF(COALESCE(comment, '') = '', '', '\\n'),
                            'Hold reason (auto): ', ?)
       WHERE id = ?`,
      [reason, task.id],
    );
    const [[held]] = await connection.query(
      'SELECT * FROM time_tracking_task_items WHERE id = ?',
      [task.id],
    );
    await connection.query(
      'UPDATE time_tracking_task_items SET duration_secs = ? WHERE id = ?',
      [workingSeconds(held), task.id],
    );
    heldTaskIds.push(task.id);
  }

  for (const sheet of running.sheets) {
    const ids = sheet.rows.map((r) => r.id);
    // Bank the running time on whichever row holds the timer.
    await connection.query(
      `UPDATE content_calendar
       SET cc_duration_secs = cc_duration_secs +
             GREATEST(TIMESTAMPDIFF(SECOND, cc_started_at, NOW()), 0),
           cc_started_at = NULL
       WHERE id IN (?) AND cc_started_at IS NOT NULL`,
      [ids],
    );
    await connection.query(
      `UPDATE content_calendar
       SET cc_status = 'ON HOLD', cc_started_at = NULL,
           cc_hold_reason = ?, cc_last_activity_at = NOW()
       WHERE id IN (?)`,
      [`(auto) ${reason}`, ids],
    );
    if (employeeName) {
      for (const id of ids) {
        await connection.query(
          `UPDATE day_plan_rows SET status = 'ON HOLD'
           WHERE employee_name = ? AND plan_date = CURDATE()
             AND report_type = 'Morning' AND today_plan LIKE ?`,
          [employeeName, `%[Calendar Row #${id}]%`],
        );
      }
    }
  }
  return heldTaskIds;
}

// Main entry: find, require a reason, hold. Returns the held tracking-item ids.
async function autoHoldForEmployee(connection, options, reason) {
  const running = await findRunning(connection, options);
  if (!running.tasks.length && !running.sheets.length) return [];
  const why = String(reason || '').trim();
  if (!why) {
    const list = describeRunning(running);
    const error = new Error(
      `${list.map((r) => `"${r.title}"`).join(', ')} is running. ` +
      'Give a reason to put it on hold before starting this one.',
    );
    error.statusCode = 409;
    error.code = 'AUTO_HOLD_REASON_REQUIRED';
    error.running = list;
    throw error;
  }
  return holdRunning(connection, running, why, options.employeeName);
}

module.exports = { autoHoldForEmployee, workingSeconds };
