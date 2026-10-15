// routes/tracking-items.js — Time Tracking Task Items (per-row S.NO data)
// ✅ task_action table removed. Every start/hold/restart/complete/reject
// timestamp now lives directly as a column on time_tracking_task_items.
const express = require('express');
const router  = express.Router();
const db      = require('../config/db');
const { createNotification } = require('./notifications');
const { autoHoldForEmployee } = require('../lib/autoHold');
const { syncDayPlanForItem } = require('../lib/dayPlanSync');

// Helper to broadcast task updates via Socket.io
// Broadcast task updates via Socket.io — after the Day Planner status for
// that employee/client has been brought up to date, so every page that
// refreshes on 'task_updated' sees the same state.
const emitTaskUpdate = (req, trackingItemId, action) => {
  syncDayPlanForItem(trackingItemId).finally(() => {
    try {
      const io = req.app.get('io');
      if (io) {
        io.emit('task_updated', {
          type: 'TRACKING_ITEM_UPDATE',
          trackingItemId: trackingItemId,
          action: action
        });
      }
    } catch (socketErr) {
      console.error('Socket emit error:', socketErr);
    }
  });
};

async function logLiveTrackingHistory(db, trackingItemId, actionStatus) {
  try {
    // 1. Fetch tracking item & task list details
    const [rows] = await db.query(`
      SELECT 
        tti.id AS tracking_item_id,
        tti.task_list_id,
        tti.start_time,
        COALESCE(tti.complete_time, tti.reject_time) AS ended_at,
        tti.duration_secs,
        tti.status,
        tti.comment,
        tti.performance,
        tl.employee_name,
        tl.client_name,
        tl.deliverables AS task
      FROM time_tracking_task_items tti
      INNER JOIN task_list tl ON tl.id = tti.task_list_id
      WHERE tti.id = ?
    `, [trackingItemId]);

    if (rows.length === 0) return;
    const item = rows[0];

    // 2. Check if an entry already exists for this tracking item today
    const [existing] = await db.query(`
      SELECT id FROM live_tracking_history 
      WHERE tracking_item_id = ? AND DATE(created_at) = CURDATE()
    `, [trackingItemId]);

    if (existing.length > 0) {
      // Update existing record for today
      await db.query(`
        UPDATE live_tracking_history 
        SET status = ?, started_at = ?, ended_at = ?, duration_secs = ?, manager_action = ?, manager_comment = ?
        WHERE id = ?
      `, [
        item.status,
        item.start_time,
        item.ended_at,
        item.duration_secs,
        item.performance || 'ACTION',
        item.comment || '',
        existing[0].id
      ]);
    } else {
      // Insert new record into live_tracking_history for today
      await db.query(`
        INSERT INTO live_tracking_history 
        (task_list_id, tracking_item_id, employee_name, client_name, task, status, started_at, ended_at, duration_secs, manager_action, manager_comment)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `, [
        item.task_list_id,
        item.tracking_item_id,
        item.employee_name,
        item.client_name,
        item.task,
        item.status,
        item.start_time,
        item.ended_at,
        item.duration_secs,
        item.performance || 'ACTION',
        item.comment || ''
      ]);
    }
  } catch (err) {
    console.error('❌ logLiveTrackingHistory error:', err.message);
  }
}

function calculateWorkingDuration(row, customEndTime = null) {
  if (!row.start_time) return 0;

  let totalSeconds = 0;
  let activeStart = new Date(row.start_time);

  for (let i = 1; i <= 10; i++) {
    const hold = row[`hold_time_${i}`];
    const restart = row[`restart_time_${i}`];

    // START / RESTART → HOLD
    if (hold && activeStart) {
      const holdTime = new Date(hold);

      if (holdTime > activeStart) {
        totalSeconds += Math.floor(
          (holdTime - activeStart) / 1000
        );
      }

      activeStart = null;
    }

    // HOLD → RESTART
    if (restart) {
      activeStart = new Date(restart);
    } else if (hold) {
      // Still on HOLD
      activeStart = null;
      break;
    }
  }

  // Last RESTART → COMPLETE / REJECT
  if (activeStart) {
    const end = customEndTime
      ? new Date(customEndTime)
      : row.complete_time
        ? new Date(row.complete_time)
        : row.reject_time
          ? new Date(row.reject_time)
          : new Date();

    if (end > activeStart) {
      totalSeconds += Math.floor(
        (end - activeStart) / 1000
      );
    }
  }

  return totalSeconds;
}


function timingToMinutes(timing) {
  const parts = String(timing || '').trim().split(/\s+/);
  if (parts.length < 2) return 0;
  const value = parseInt(parts[0], 10) || 0;
  const unit = parts[1].toLowerCase();
  if (unit.startsWith('min')) return value;
  if (unit.startsWith('hr') || unit.startsWith('hour')) return value * 60;
  if (unit.startsWith('day')) return value * 1440;
  return 0;
}

async function computePerformance(taskListId, durationSecs) {
  try {
    const [[list]] = await db.query(
      `SELECT tl.deliverables, tt.timing
       FROM task_list tl
       LEFT JOIN task_timings tt ON tt.id = tl.task_timing_id
       WHERE tl.id = ?`,
      [taskListId]
    );
    if (!list) return 'N/A';
    let timing = list.timing;
    if (!timing) {
      const [[match]] = await db.query(
        `SELECT timing FROM task_timings WHERE LOWER(TRIM(task_name)) = LOWER(TRIM(?)) LIMIT 1`,
        [list.deliverables]
      );
      timing = match?.timing;
    }
    const expected = timingToMinutes(timing);
    if (!expected) return 'N/A';
    const actual = Math.floor((Number(durationSecs) || 0) / 60);
    if (actual === expected) return 'Achieved';
    return actual < expected ? 'Before In' : 'Delay Out';
  } catch (err) {
    console.error('computePerformance:', err.message);
    return 'N/A';
  }
}

// ── Day Planner: one row per task row ───────────────────────────────────────
// A task can only start once it is in today's Day Planner. If it isn't, the
// client is told (409 DAY_PLAN_CONFIRM_REQUIRED) and asks the employee; when
// they confirm, the row "[Task Row #id] …" is added and the task starts.
async function ensureTaskInDayPlan(connection, target, confirmed) {
  const employeeName = String(target.employee_name || '').trim();
  if (!employeeName) return;
  const marker = `[Task Row #${target.id}]`;
  const [existing] = await connection.query(
    `SELECT id FROM day_plan_rows
     WHERE LOWER(TRIM(employee_name)) = LOWER(TRIM(?)) AND plan_date = CURDATE()
       AND today_plan LIKE ? LIMIT 1`,
    [employeeName, `%${marker}%`],
  );
  if (existing.length) return;

  const [[info]] = await connection.query(
    `SELECT tl.client_name, tl.deliverables, tti.s_no, tti.sub_no, tti.hook_headline,
            COALESCE(ta.deadline, ta.maintenance_date, tl.submission_date, tti.submit_date) AS due
     FROM time_tracking_task_items tti
     JOIN task_list tl ON tl.id = tti.task_list_id
     LEFT JOIN task_assignments ta ON ta.id = tl.task_assignment_id
     WHERE tti.id = ?`,
    [target.id],
  );
  const rowNo = Number(info?.sub_no) > 0 ? `${info.s_no}.${info.sub_no}` : `${info?.s_no ?? ''}`;
  const title = `${info?.deliverables || 'Task'} · Row ${rowNo}`;
  if (!confirmed) {
    const error = new Error(`"${title}" (${info?.client_name || ''}) is not in today's Day Planner. Add it and start?`);
    error.statusCode = 409;
    error.code = 'DAY_PLAN_CONFIRM_REQUIRED';
    error.task = { title, client: info?.client_name || '' };
    throw error;
  }
  const [[role]] = await connection.query(
    `SELECT role FROM employee_users WHERE LOWER(TRIM(full_name)) = LOWER(TRIM(?)) LIMIT 1`,
    [employeeName],
  );
  const [[submitted]] = await connection.query(
    `SELECT MAX(is_submitted) AS s FROM day_plan_rows
     WHERE LOWER(TRIM(employee_name)) = LOWER(TRIM(?)) AND plan_date = CURDATE()`,
    [employeeName],
  );
  const headline = String(info?.hook_headline || '').trim();
  await connection.query(
    `INSERT INTO day_plan_rows
       (employee_name, employee_role, plan_date, report_type, client_name,
        maintenance_date, today_plan, status, is_submitted)
     VALUES (?, ?, CURDATE(), 'Morning', ?, ?, ?, 'PROCESSING', ?)`,
    [
      employeeName,
      role?.role || null,
      info?.client_name || null,
      info?.due || null,
      `${marker} ${title}${headline ? ` — ${headline}` : ''}`,
      Number(submitted?.s) === 1 ? 1 : 0,
    ],
  );
}

async function requireCalendarSheetHandoff(connection, trackingItemId) {
  const [rows] = await connection.query(
    `SELECT cc.cc_handoff_at, cc.source_active, cc.is_emergency
     FROM content_calendar cc
     WHERE cc.task_item_id = ? AND cc.source_assignment_id IS NOT NULL
     ORDER BY cc.id DESC`,
    [trackingItemId],
  );
  const blocked = rows.some(
    (row) => Number(row.source_active) === 1 &&
      !row.cc_handoff_at &&
      Number(row.is_emergency) !== 1,
  );
  if (blocked) {
    const error = new Error('The Page/Ads Handler must finish and share this content sheet before work can start');
    error.statusCode = 409;
    throw error;
  }
}

async function autoHoldOtherEmployeeTasks(connection, target, targetId, reason = '') {
  const employeeId = Number(target.employee_id) || null;
  const employeeName = String(target.employee_name || '').trim();
  if (!employeeId && !employeeName) {
    const error = new Error('The assigned employee could not be identified for exclusive task timing');
    error.statusCode = 409;
    throw error;
  }
  // Serialise starts for the same employee.
  if (employeeId) {
    await connection.query(`SELECT id FROM employee_users WHERE id = ? FOR UPDATE`, [employeeId]);
  } else {
    await connection.query(
      `SELECT id FROM employee_users WHERE LOWER(TRIM(full_name)) = LOWER(TRIM(?)) LIMIT 1 FOR UPDATE`,
      [employeeName],
    );
  }
  // Holds any other running task AND any running Content Calendar category,
  // after the employee gives a reason (409 AUTO_HOLD_REASON_REQUIRED otherwise).
  return autoHoldForEmployee(
    connection,
    { employeeId, employeeName, excludeTaskId: targetId },
    reason,
  );
}

// function calculateWorkingDuration(row, customEndTime = null) {
//   if (!row.start_time) {
//     return 0;
//   }

//   const start = new Date(row.start_time);
//   const end = customEndTime ? new Date(customEndTime) : (row.complete_time ? new Date(row.complete_time) : new Date());

//   let totalSeconds = Math.floor((end - start) / 1000);
//   let holdSeconds = 0;

//   for (let i = 1; i <= 10; i++) {
//     const hold = row[`hold_time_${i}`];
//     const restart = row[`restart_time_${i}`];

//     if (hold) {
//       const holdTime = new Date(hold);
//       const restartTime = restart ? new Date(restart) : (customEndTime ? new Date(customEndTime) : new Date());
//       if (restartTime > holdTime) {
//         holdSeconds += Math.floor((restartTime - holdTime) / 1000);
//       }
//     }
//   }

//   totalSeconds -= holdSeconds;
//   if (totalSeconds < 0) totalSeconds = 0;

//   return totalSeconds;
// }

async function updateDayPlannerWorkingHours(employeeName) {
  try {
    const today = new Date().toISOString().split("T")[0];

    const [rows] = await db.query(
      `SELECT SUM(tti.duration_secs) AS total_secs
       FROM time_tracking_task_items tti
       INNER JOIN task_list tl
          ON tl.id = tti.task_list_id
       WHERE tl.employee_name = ?
       AND DATE(COALESCE(tti.complete_time, tti.submit_date, tti.created_at)) = ?`,
      [employeeName, today]
    );

    const totalSecs = rows[0]?.total_secs || 0;

    await db.query(
      `UPDATE day_plan_rows
       SET total_working_secs = ?
       WHERE employee_name = ?
       AND plan_date = ?`,
      [totalSecs, employeeName, today]
    );

    console.log(
      `Updated Day Planner Working Hours : ${employeeName} = ${totalSecs}s`
    );

  } catch (err) {
    console.error("updateDayPlannerWorkingHours:", err.message);
  }
}

async function updateDayPlannerDeliverables(taskListId) {
  try {

    const [[task]] = await db.query(`
      SELECT
        employee_name,
        client_name,
        employee_role
      FROM task_list
      WHERE id = ?
    `,[taskListId]);

    if (!task) return;

    // இதுல task_list table ல இருந்து latest deliverables
    const [[deliverable]] = await db.query(`
      SELECT
        complete_deliverables_1,
        balanced_deliverables_1,
        complete_deliverables_2,
        balanced_deliverables_2,
        complete_deliverables_3,
        balanced_deliverables_3,
        complete_deliverables_4,
        balanced_deliverables_4,
        complete_deliverables_5,
        balanced_deliverables_5,
        complete_deliverables_6,
        balanced_deliverables_6
      FROM task_list
      WHERE id = ?
    `,[taskListId]);

    await db.query(`
      UPDATE day_plan_rows
      SET
        complete_deliverables_1=?,
        balanced_deliverables_1=?,
        complete_deliverables_2=?,
        balanced_deliverables_2=?,
        complete_deliverables_3=?,
        balanced_deliverables_3=?,
        complete_deliverables_4=?,
        balanced_deliverables_4=?,
        complete_deliverables_5=?,
        balanced_deliverables_5=?,
        complete_deliverables_6=?,
        balanced_deliverables_6=?
      WHERE employee_name=?
      AND client_name=?
      AND plan_date=CURDATE()
    `,[
      deliverable.complete_deliverables_1,
      deliverable.balanced_deliverables_1,
      deliverable.complete_deliverables_2,
      deliverable.balanced_deliverables_2,
      deliverable.complete_deliverables_3,
      deliverable.balanced_deliverables_3,
      deliverable.complete_deliverables_4,
      deliverable.balanced_deliverables_4,
      deliverable.complete_deliverables_5,
      deliverable.balanced_deliverables_5,
      deliverable.complete_deliverables_6,
      deliverable.balanced_deliverables_6,
      task.employee_name,
      task.client_name
    ]);

  } catch(err){
    console.error(err);
  }
}

router.get('/by-task-list/:taskListId', async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT * FROM time_tracking_task_items
       WHERE task_list_id = ? AND parent_item_id IS NULL
       ORDER BY s_no ASC`,
      [req.params.taskListId]
    );
    return res.json({ success: true, data: rows });
  } catch (err) {
    console.error('GET /tracking-items/by-task-list/:taskListId ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
}); 

// GET /api/tracking-items/by-task-list-ids?ids=1,2,3 — bulk fetch for restoring state on page load
router.get('/by-task-list-ids', async (req, res) => {
  const idsParam = req.query.ids;
  if (!idsParam) return res.json({ success: true, data: [] });

  const ids = idsParam.split(',').map((x) => parseInt(x, 10)).filter((x) => !isNaN(x));
  if (ids.length === 0) return res.json({ success: true, data: [] });

  try {
    const placeholders = ids.map(() => '?').join(',');
    const [rows] = await db.query(
      `SELECT * FROM time_tracking_task_items WHERE task_list_id IN (${placeholders}) ORDER BY task_list_id, s_no`,
      ids
    );
    return res.json({ success: true, data: rows });
  } catch (err) {
    console.error('GET /tracking-items/by-task-list-ids ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/tracking-items — create/update the row's basic fields
// (submit date, description, duration, comment, performance, status).
// Does NOT touch start/hold/restart/complete/reject — those go through the
// dedicated endpoints below so a row can't be accidentally reset mid-action.
router.post('/', async (req, res) => {
  const {
    taskListId,
    sNo,
    submitDate,
    taskDescription,
    durationSecs,
    comment,
    performance,
    status,
  } = req.body;

  if (!taskListId || sNo === undefined) {
    return res.status(400).json({
      success: false,
      message: "taskListId and sNo are required",
    });
  }

  // Convert ISO datetime to YYYY-MM-DD
  // let formattedSubmitDate = null;

  // if (submitDate) {
  //   formattedSubmitDate = submitDate.toString().split("T")[0];
  // }

  let formattedSubmitDate = null;

if (submitDate) {

  if (submitDate.includes('/')) {

    const [dd, mm, yyyy] = submitDate.split('/');

    formattedSubmitDate = `${yyyy}-${mm}-${dd}`;

  } else {

    formattedSubmitDate = submitDate.toString().split('T')[0];

  }

}

  console.log("======================================");
  console.log("submitDate:", submitDate);
  console.log("formattedSubmitDate:", formattedSubmitDate);
  console.log("======================================");

  try {
    // Get task timing id
    const [taskListRows] = await db.query(
      `SELECT task_timing_id FROM task_list WHERE id = ?`,
      [taskListId]
    );

    if (taskListRows.length === 0) {
      return res.status(404).json({
        success: false,
        message: "Task list entry not found",
      });
    }

    const taskTimingId = taskListRows[0].task_timing_id;

    // Check existing row
    const [existing] = await db.query(
      `SELECT id
       FROM time_tracking_task_items
       WHERE task_list_id = ? AND s_no = ? AND parent_item_id IS NULL`,
      [taskListId, sNo]
    );

    // =========================
    // UPDATE
    // =========================
    if (existing.length > 0) {

      const params = [
        taskTimingId,
        formattedSubmitDate,
        taskDescription || "",
        durationSecs || 0,
        comment || "",
        performance || "N/A",
        status || "IDLE",
        existing[0].id,
      ];

      console.log("UPDATE PARAMS:", params);

      const [updateResult] = await db.query(
        `UPDATE time_tracking_task_items
         SET
           task_timing_id = ?,
           submit_date = COALESCE(?, submit_date),
           task_description = ?,
           duration_secs = IF(status IN ('REWORK', 'COMPLETED') OR review_status IN ('REWORK', 'APPROVED', 'PENDING'), duration_secs, ?),
           comment = ?,
           performance = ?,
           status = IF(status IN ('REWORK', 'COMPLETED') OR review_status IN ('REWORK', 'APPROVED', 'PENDING'), status, ?)
         WHERE id = ?`,
        params
      );

      console.log("Updated Rows:", updateResult.affectedRows);

      return res.json({
        success: true,
        message: "Tracking item updated",
        data: {
          id: existing[0].id,
        },
      });
    }

    // =========================
    // INSERT
    // =========================

    const params = [
      taskListId,
      taskTimingId,
      sNo,
      formattedSubmitDate,
      taskDescription || "",
      durationSecs || 0,
      comment || "",
      performance || "N/A",
      status || "IDLE",
    ];

    console.log("INSERT PARAMS:", params);

    const [result] = await db.query(
      `INSERT INTO time_tracking_task_items
      (
        task_list_id,
        task_timing_id,
        s_no,
        submit_date,
        task_description,
        duration_secs,
        comment,
        performance,
        status
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      params
    );

    console.log("Inserted ID:", result.insertId);

    return res.status(201).json({
      success: true,
      message: "Tracking item created",
      data: {
        id: result.insertId,
      },
    });

  } catch (err) {

    console.error("========== TRACKING ITEMS ERROR ==========");
    console.error(err);
    console.error("SQL Message:", err.message);
    console.error("SQL Code:", err.code);
    console.error("SQL Errno:", err.errno);
    console.error("SQL State:", err.sqlState);
    console.error("==========================================");

    return res.status(500).json({
      success: false,
      message: err.message,
    });
  }
});

// ── ACTION ENDPOINTS — replace routes/task-actions.js entirely ─────────────
// All of these take { trackingItemId } (= time_tracking_task_items.id) and
// write straight onto that row.

// POST /api/tracking-items/:id/start
router.post('/:id/start', async (req, res) => {
  const { id } = req.params;
  let connection;
  let autoHeldIds = [];
  try {
    connection = await db.getConnection();
    await connection.beginTransaction();
    const [targetRows] = await connection.query(
      `SELECT tti.*, tl.employee_id, tl.employee_name
       FROM time_tracking_task_items tti
       JOIN task_list tl ON tl.id = tti.task_list_id
       WHERE tti.id = ? FOR UPDATE`,
      [id],
    );
    if (!targetRows.length) {
      await connection.rollback();
      return res.status(404).json({ success: false, message: 'Tracking item not found' });
    }
    const target = targetRows[0];
    if (['COMPLETED', 'REJECTED'].includes(String(target.status).toUpperCase())) {
      await connection.rollback();
      return res.status(409).json({ success: false, message: 'A finished task cannot be started' });
    }
    if (String(target.review_status || '').toUpperCase() === 'APPROVED') {
      await connection.rollback();
      return res.status(409).json({ success: false, message: 'This task is approved and locked' });
    }
    if (['ON HOLD', 'REWORK'].includes(String(target.status).toUpperCase()) ||
        (String(target.review_status || '').toUpperCase() === 'REWORK' && target.start_time)) {
      await connection.rollback();
      return res.status(409).json({ success: false, message: 'Use RESTART for a held or rework task so the timer continues' });
    }

    await requireCalendarSheetHandoff(connection, target.id);
    await ensureTaskInDayPlan(connection, target, req.body?.day_planner_confirmed === true);
    autoHeldIds = await autoHoldOtherEmployeeTasks(connection, target, id, req.body?.auto_hold_reason);

    await connection.query(
      `UPDATE time_tracking_task_items
       SET start_time = IFNULL(start_time, NOW()), status = 'IN PROGRESS'
       WHERE id = ?`,
      [id],
    );
    await connection.commit();

    for (const autoHeldId of autoHeldIds) {
      await logLiveTrackingHistory(db, autoHeldId, 'ON HOLD');
      emitTaskUpdate(req, autoHeldId, 'ON HOLD');
    }
    await logLiveTrackingHistory(db, id, 'IN PROGRESS');

    const [rows] = await db.query(`SELECT * FROM time_tracking_task_items WHERE id = ?`, [id]);
    emitTaskUpdate(req, id, 'IN PROGRESS');
    return res.json({
      success: true,
      message: 'Task started',
      autoHeldTrackingItemIds: autoHeldIds,
      data: rows[0],
    });
  } catch (err) {
    if (connection) await connection.rollback();
    console.error('POST /tracking-items/:id/start ERROR:', err.message);
    return res.status(err.statusCode || 500).json({
      success: false, message: err.message, code: err.code, running: err.running, task: err.task,
    });
  } finally {
    connection?.release();
  }
});

// POST /api/tracking-items/:id/hold — fills the next empty hold_time_N (1-10)
// router.post('/:id/hold', async (req, res) => {
//   const { id } = req.params;
//   try {
//     const [rows] = await db.query(`SELECT * FROM time_tracking_task_items WHERE id = ?`, [id]);
//     if (rows.length === 0)
//       return res.status(404).json({ success: false, message: 'Tracking item not found' });

//     const row = rows[0];
//     let slot = null;
//     for (let i = 1; i <= 10; i++) {
//       if (row[`hold_time_${i}`] === null) { slot = i; break; }
//     }
//     if (!slot) {
//       return res.status(400).json({ success: false, message: 'Maximum 10 holds reached' });
//     }

//     await db.query(
//       `UPDATE time_tracking_task_items SET hold_time_${slot} = NOW(), status = 'ON HOLD' WHERE id = ?`,
//       [id]
//     );

//     const [updated] = await db.query(`SELECT * FROM time_tracking_task_items WHERE id = ?`, [id]);
//     emitTaskUpdate(req, id, 'ON HOLD');
//     return res.json({ success: true, message: `Task on hold (slot ${slot})`, data: updated[0] });
//   } catch (err) {
//     console.error('POST /tracking-items/:id/hold ERROR:', err.message);
//     return res.status(500).json({ success: false, message: err.message });
//   }
// });

// POST /api/tracking-items/:id/hold
router.post('/:id/hold', async (req, res) => {
  const { id } = req.params;
  const reason = String(req.body.reason || '').trim();
  if (!reason) {
    return res.status(400).json({ success: false, message: 'Hold reason is required' });
  }
  try {
    const [rows] = await db.query(`SELECT * FROM time_tracking_task_items WHERE id = ?`, [id]);
    if (rows.length === 0)
      return res.status(404).json({ success: false, message: 'Tracking item not found' });

    const row = rows[0];
    if (String(row.status).toUpperCase() !== 'IN PROGRESS') {
      return res.status(409).json({ success: false, message: 'Only an in-progress task can be put on hold' });
    }
    let slot = null;
    for (let i = 1; i <= 10; i++) {
      if (row[`hold_time_${i}`] === null) { slot = i; break; }
    }
    if (!slot) {
      return res.status(400).json({ success: false, message: 'Maximum 10 holds reached' });
    }

    // 1. Update hold time and status
    await db.query(
      `UPDATE time_tracking_task_items
       SET hold_time_${slot} = NOW(), status = 'ON HOLD',
           comment = IF(
             ? = '',
             comment,
             CONCAT(COALESCE(comment, ''), IF(COALESCE(comment, '') = '', '', '\\n'),
                    'Hold reason: ', ?)
           )
       WHERE id = ?`,
      [reason, reason, id]
    );

    // 2. Fetch updated row and calculate working duration so far
    const [updatedRows] = await db.query(`SELECT * FROM time_tracking_task_items WHERE id = ?`, [id]);
    const updatedRow = updatedRows[0];
    const durationSecs = calculateWorkingDuration(updatedRow);

    // 3. Save duration_secs immediately
    await db.query(
      `UPDATE time_tracking_task_items SET duration_secs = ? WHERE id = ?`,
      [durationSecs, id]
    );

    // 4. Get employee name
const [[task]] = await db.query(
  `SELECT employee_name
   FROM task_list
   WHERE id = ?`,
  [updatedRow.task_list_id]
);

// 5. Update Day Planner working hours
  if (task) {
   await updateDayPlannerWorkingHours(task.employee_name);
   await updateDayPlannerDeliverables(updatedRow.task_list_id);
}

// 🟢 Auto-save to live tracking history
    await logLiveTrackingHistory(db, id, 'ON HOLD');

    emitTaskUpdate(req, id, 'ON HOLD');
    return res.json({ success: true, message: `Task on hold (slot ${slot})`, data: { ...updatedRow, durationSecs } });
  } catch (err) {
    console.error('POST /tracking-items/:id/hold ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/tracking-items/:id/complete
// Completing sends the row to Task Review (review_status = PENDING).
// It only counts as finished once a manager approves it.
router.post('/:id/complete', async (req, res) => {
  const { id } = req.params;

  try {
    const [[current]] = await db.query(
      `SELECT id, status, review_status FROM time_tracking_task_items WHERE id = ?`,
      [id]
    );
    if (!current) {
      return res.status(404).json({ success: false, message: 'Tracking item not found' });
    }
    if (String(current.review_status || '').toUpperCase() === 'APPROVED') {
      return res.status(409).json({ success: false, message: 'This task is approved and locked' });
    }
    if (String(current.status).toUpperCase() !== 'IN PROGRESS') {
      return res.status(409).json({ success: false, message: 'Only an in-progress task can be completed' });
    }

    await db.query(
      `UPDATE time_tracking_task_items
       SET complete_time = IFNULL(complete_time, NOW()),
           status = 'COMPLETED',
           review_status = 'PENDING'
       WHERE id = ?`,
      [id]
    );

    const [rows] = await db.query(`SELECT * FROM time_tracking_task_items WHERE id = ?`, [id]);
    const row = rows[0];
    const durationSecs = calculateWorkingDuration(row, row.complete_time);
    const performance = req.body.performance || await computePerformance(row.task_list_id, durationSecs);

    await db.query(
      `UPDATE time_tracking_task_items SET duration_secs = ?, performance = ? WHERE id = ?`,
      [durationSecs, performance, id]
    );

    // Put (or put back) the row in the manager's review queue.
    const [review] = await db.query(
      `SELECT id FROM manager_review WHERE tracking_item_id = ?`,
      [id]
    );
    if (review.length) {
      await db.query(
        `UPDATE manager_review SET manager_action = 'ACTION', reviewed_at = NOW() WHERE id = ?`,
        [review[0].id]
      );
    } else {
      await db.query(
        `INSERT INTO manager_review (tracking_item_id, manager_action, reviewed_at)
         VALUES (?, 'ACTION', NOW())`,
        [id]
      );
    }

    const [[task]] = await db.query(
      `SELECT employee_name FROM task_list WHERE id = ?`,
      [row.task_list_id]
    );
    if (task) {
      await updateDayPlannerWorkingHours(task.employee_name);
      await updateDayPlannerDeliverables(row.task_list_id);
    }

    await logLiveTrackingHistory(db, id, 'COMPLETED');

    emitTaskUpdate(req, id, 'COMPLETED');
    return res.json({
      success: true,
      message: 'Task completed and sent for review',
      data: { ...row, durationSecs, performance, review_status: 'PENDING' },
    });
  } catch (err) {
    console.error('POST /tracking-items/:id/complete ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/tracking-items/:id/reject
router.post('/:id/reject', async (req, res) => {
  const { id } = req.params;
  try {
    const [result] = await db.query(
      `UPDATE time_tracking_task_items SET reject_time = IFNULL(reject_time, NOW()), status = 'REJECTED' WHERE id = ?`,
      [id]
    );
    if (result.affectedRows === 0)
      return res.status(404).json({ success: false, message: 'Tracking item not found' });

    const [rows] = await db.query(`SELECT * FROM time_tracking_task_items WHERE id = ?`, [id]);
    const row = rows[0];
    const durationSecs = calculateWorkingDuration(row, row.reject_time);

    await db.query(
      `UPDATE time_tracking_task_items SET duration_secs = ? WHERE id = ?`,
      [durationSecs, id]
    );

    const [[task]] = await db.query(
  `SELECT employee_name
   FROM task_list
   WHERE id=?`,
  [row.task_list_id]
);

await updateDayPlannerWorkingHours(task.employee_name);
await updateDayPlannerDeliverables(row.task_list_id);

    emitTaskUpdate(req, id, 'REJECTED');
    return res.json({ success: true, message: 'Task rejected', data: { ...row, durationSecs } });
  } catch (err) {
    console.error('POST /tracking-items/:id/reject ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/tracking-items/:id/restart — fills the next empty restart_time_N (1-10)
router.post('/:id/restart', async (req, res) => {
  const { id } = req.params;
  let connection;
  let autoHeldIds = [];
  try {
    connection = await db.getConnection();
    await connection.beginTransaction();
    const [rows] = await connection.query(
      `SELECT tti.*, tl.employee_id, tl.employee_name
       FROM time_tracking_task_items tti
       JOIN task_list tl ON tl.id = tti.task_list_id
       WHERE tti.id = ? FOR UPDATE`,
      [id],
    );
    if (!rows.length) {
      await connection.rollback();
      return res.status(404).json({ success: false, message: 'Tracking item not found' });
    }

    const row = rows[0];
    const currentStatus = String(row.status || '').toUpperCase();
    const reviewNow = String(row.review_status || '').toUpperCase();
    // Rejected work can be redone too (RESTART continues the same timer).
    const isRejected = currentStatus === 'REJECTED' ||
      (reviewNow === 'REJECTED' && ['COMPLETED', 'REWORK'].includes(currentStatus));
    const isRework = isRejected || currentStatus === 'REWORK' ||
      (reviewNow === 'REWORK' && currentStatus !== 'IN PROGRESS');
    if (currentStatus !== 'ON HOLD' && !isRework) {
      await connection.rollback();
      return res.status(409).json({ success: false, message: 'Only a held, rework or rejected task can be restarted' });
    }
    // Older rejected rows still hold their completion time: park it in a hold
    // slot so the restart pairs with it and the worked time keeps counting.
    if (['COMPLETED', 'REJECTED'].includes(currentStatus) && row.complete_time) {
      let holdSlot = null;
      for (let i = 1; i <= 10; i++) {
        if (row[`hold_time_${i}`] === null) { holdSlot = i; break; }
      }
      if (holdSlot) {
        await connection.query(
          `UPDATE time_tracking_task_items SET hold_time_${holdSlot} = complete_time WHERE id = ?`,
          [id],
        );
        row[`hold_time_${holdSlot}`] = row.complete_time;
      }
    }
    if (String(row.review_status || '').toUpperCase() === 'APPROVED') {
      await connection.rollback();
      return res.status(409).json({ success: false, message: 'This task is approved and locked' });
    }
    await requireCalendarSheetHandoff(connection, row.id);
    await ensureTaskInDayPlan(connection, row, req.body?.day_planner_confirmed === true);
    autoHeldIds = await autoHoldOtherEmployeeTasks(connection, row, id, req.body?.auto_hold_reason);

    let slot = null;
    for (let i = 1; i <= 10; i++) {
      if (row[`restart_time_${i}`] === null) { slot = i; break; }
    }
    if (!slot) {
      await connection.rollback();
      return res.status(400).json({ success: false, message: 'Maximum 10 restarts reached' });
    }

    await connection.query(
      `UPDATE time_tracking_task_items
       SET restart_time_${slot} = NOW(), status = 'IN PROGRESS',
           start_time = IFNULL(start_time, NOW()), complete_time = NULL
       WHERE id = ?`,
      [id]
    );

    await connection.commit();
    for (const autoHeldId of autoHeldIds) {
      await logLiveTrackingHistory(db, autoHeldId, 'ON HOLD');
      emitTaskUpdate(req, autoHeldId, 'ON HOLD');
    }
    const [updated] = await db.query(
      `SELECT * FROM time_tracking_task_items WHERE id = ?`,
      [id],
    );
    await updateDayPlannerWorkingHours(row.employee_name);
    await updateDayPlannerDeliverables(row.task_list_id);
    await logLiveTrackingHistory(db, id, 'IN PROGRESS');
    emitTaskUpdate(req, id, 'IN PROGRESS');
    return res.json({
      success: true,
      message: `Task restarted (slot ${slot})`,
      autoHeldTrackingItemIds: autoHeldIds,
      data: updated[0],
    });
  } catch (err) {
    if (connection) await connection.rollback();
    console.error('POST /tracking-items/:id/restart ERROR:', err.message);
    return res.status(err.statusCode || 500).json({
      success: false, message: err.message, code: err.code, running: err.running, task: err.task,
    });
  } finally {
    connection?.release();
  }
});

// POST /api/tracking-items/:id/complete
// POST /api/tracking-items/:id/complete
// router.post('/:id/complete', async (req, res) => {
//   const { id } = req.params;
//   const { performance } = req.body;

//   try {

//     // 1. Update task as completed
//     const [result] = await db.query(
//       `UPDATE time_tracking_task_items
//        SET
//        complete_time = IFNULL(complete_time, NOW()),
//        status = 'COMPLETED',
//        performance = ?
//        WHERE id = ?`,
//       [performance || 'N/A', id]
//     );


//     if (result.affectedRows === 0) {
//       return res.status(404).json({
//         success: false,
//         message: 'Tracking item not found'
//       });
//     }


//     // 2. Get completed task data
//     const [rows] = await db.query(
//       `SELECT * 
//        FROM time_tracking_task_items 
//        WHERE id = ?`,
//       [id]
//     );


//     const row = rows[0];


//     // 3. Calculate working duration
//     const durationSecs = calculateWorkingDuration(row);


//     // 4. Save calculated duration
//     await db.query(
//       `UPDATE time_tracking_task_items
//        SET duration_secs = ?
//        WHERE id = ?`,
//       [durationSecs, id]
//     );



//     // 5. Create notification for admin
//     try {

//       const [taskInfo] = await db.query(
//         `SELECT 
//             tl.employee_name,
//             tl.deliverables
//          FROM task_list tl
//          WHERE tl.id = ?`,
//         [row.task_list_id]
//       );


//       if (taskInfo.length > 0 && taskInfo[0].employee_name) {


//         // Get all admins
//         const [admins] = await db.query(
//           `SELECT full_name
//            FROM employees
//            WHERE role = 'admin'`
//         );


//         // Send notification to every admin
//         for (const admin of admins) {

//           await createNotification({

//             senderName: taskInfo[0].employee_name,

//             recipientName: admin.full_name,

//             message:
//               `Task "${taskInfo[0].deliverables}" has been submitted for review.`

//           });

//         }

//       }


//     } catch (notifyErr) {

//       console.error(
//         '⚠️ complete notification failed (non-fatal):',
//         notifyErr.message
//       );

//     }

// emitTaskUpdate(req, id, 'COMPLETED');

//     return res.json({

//       success: true,

//       message: 'Task completed',

//       data: {
//         ...row,
//         durationSecs
//       }

//     });


//   } catch (err) {

//     console.error(
//       'POST /tracking-items/:id/complete ERROR:',
//       err.message
//     );


//     return res.status(500).json({

//       success: false,

//       message: err.message

//     });

//   }

// });

// POST /api/tracking-items/:id/reject
// router.post('/:id/reject', async (req, res) => {
//   const { id } = req.params;
//   try {

//     const [result] = await db.query(
//       `UPDATE time_tracking_task_items SET reject_time = IFNULL(reject_time,NOW()), status = 'REJECTED' WHERE id = ?`,
//       [id]
//     );
//     if (result.affectedRows === 0)
//       return res.status(404).json({ success: false, message: 'Tracking item not found' });

//     const [rows] = await db.query(`SELECT * FROM time_tracking_task_items WHERE id = ?`, [id]);
//      const row = rows[0];
//      const durationSecs = calculateWorkingDuration(row);


//     emitTaskUpdate(req, id, 'REJECTED');
//     return res.json({ success: true, message: 'Task rejected', data: rows[0] });
//   } catch (err) {
//     console.error('POST /tracking-items/:id/reject ERROR:', err.message);
//     return res.status(500).json({ success: false, message: err.message });
//   }
// });

// DELETE /api/tracking-items/:id
router.delete('/:id', async (req, res) => {
  try {

 
    const [result] = await db.query(`DELETE FROM time_tracking_task_items WHERE id = ?`, [req.params.id]);
    if (result.affectedRows === 0)
      return res.status(404).json({ success: false, message: 'Tracking item not found' });
    emitTaskUpdate(req, req.params.id, 'DELETED');
    return res.json({ success: true, message: 'Tracking item deleted' });
  } catch (err) {
    console.error('DELETE /tracking-items/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});


router.post('/recalculate-completed-durations', async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT *
      FROM time_tracking_task_items
      WHERE status IN ('COMPLETED', 'REJECTED')
        AND start_time IS NOT NULL
    `);

    let updated = 0;

    for (const row of rows) {
      const endTime =
        row.complete_time ||
        row.reject_time ||
        null;

      const durationSecs = calculateWorkingDuration(
        row,
        endTime
      );

      await db.query(
        `UPDATE time_tracking_task_items
         SET duration_secs = ?
         WHERE id = ?`,
        [durationSecs, row.id]
      );

      console.log(
        `ID ${row.id}: duration_secs = ${durationSecs}`
      );

      updated++;
    }

    return res.json({
      success: true,
      message: 'Completed durations recalculated successfully',
      totalUpdated: updated
    });

  } catch (err) {
    console.error(
      'RECALCULATE COMPLETED DURATIONS ERROR:',
      err
    );

    return res.status(500).json({
      success: false,
      message: err.message
    });
  }
});


// GET /api/tracking-items/history/:employeeName
router.get('/history/:employeeName', async (req, res) => {
  const { employeeName } = req.params;

  try {
    const [rows] = await db.query(
      `
      SELECT
        tti.*,
        tl.client_name,
        tl.deliverables,
        tl.id AS task_list_id
      FROM time_tracking_task_items tti
      INNER JOIN task_list tl ON tl.id = tti.task_list_id
      WHERE tl.employee_name = ?
        AND UPPER(tti.status) IN ('COMPLETED', 'REJECTED')
      ORDER BY tti.id DESC
      `,
      [employeeName]
    );

    return res.json({ success: true, data: rows });
  } catch (err) {
    console.error('GET /tracking-items/history/:employeeName ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
module.exports.ensureTaskInDayPlan = ensureTaskInDayPlan;