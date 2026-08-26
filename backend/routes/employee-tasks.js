// routes/employee-tasks.js
// Handles:
//   GET  /api/employee-tasks/by-employee/:name  — fetch assigned tasks for an employee
//   GET  /api/employee-tasks/tracker            — get all tracker rows for an employee
//   POST /api/employee-tasks/tracker            — upsert a tracker row (auto-save)
//   PUT  /api/employee-tasks/tracker/:id        — update a specific tracker row
//   POST /api/employee-tasks/tracker/save-all   — bulk save multiple rows at once

const express = require('express');
const router  = express.Router();
const db      = require('../config/db');

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/employee-tasks/by-employee/:name
// Returns all task_assignments rows where this employee appears in any role column
// Flutter uses this to build the tab list + task cards
// ─────────────────────────────────────────────────────────────────────────────
// GET /api/employee-tasks/by-employee/:name
router.get('/by-employee/:name', async (req, res) => {
  const name = req.params.name.toUpperCase();

  try {
    // Find rows where employee appears in any role column and the client is ACTIVE (is_active = 1)
    const [rows] = await db.query(
      `SELECT
          ta.*,
          ta.deadline
       FROM task_assignments ta
       INNER JOIN clients c 
          ON TRIM(LOWER(ta.client_name)) = TRIM(LOWER(c.company_name))
       WHERE (
          UPPER(ta.designer)       LIKE ? OR
          UPPER(ta.videographer)   LIKE ? OR
          UPPER(ta.video_editor)   LIKE ? OR
          UPPER(ta.ads_handling)   LIKE ? OR
          UPPER(ta.page_handling)  LIKE ? OR
          UPPER(ta.ui_ux_designer) LIKE ? OR
          UPPER(ta.developer)      LIKE ? OR
          UPPER(ta.website_designer) LIKE ?
        )
          AND ta.is_assigned = 1
          AND c.is_active = 1
       ORDER BY ta.created_at DESC`,
      [
        `%${name}%`,
        `%${name}%`,
        `%${name}%`,
        `%${name}%`,
        `%${name}%`,
        `%${name}%`,
        `%${name}%`,
        `%${name}%`
      ]
    );

    for (const task of rows) {
      if (
        task.deliverables &&
        task.deliverables.toUpperCase().includes("PACKAGE")
      ) {
        continue;
      }
      
      // Skip if task already exists
      const [exists] = await db.query(
        `SELECT id
         FROM task_list
         WHERE task_assignment_id = ?
           AND deliverables = ?
         LIMIT 1`,
        [task.id, task.deliverables]
      );

      if (exists.length === 0) {
        await db.query(
          `INSERT INTO task_list
          (
            task_assignment_id,
            employee_id,
            employee_name,
            client_name,
            deliverables,
            duration,
            submission_date,
            no_of_rows
          )
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
          [
            task.id,
            null,
            name,
            task.client_name,
            task.deliverables,
            null,
            null,
            task.deadline,
            1
          ]
        );
      }
    }

    return res.json({ success: true, data: rows });
  } catch (err) {
    console.error('GET /by-employee ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// router.get('/by-employee/:name', async (req, res) => {
//   const name = req.params.name.toUpperCase();

//   try {
//     const [rows] = await db.query(
//       `SELECT
//           ta.*,
//           ta.designer_submit_date,
//           ta.videographer_submit_date,
//           ta.video_editor_submit_date,
//           ta.ads_submit_date,
//           ta.page_submit_date,
//           ta.ui_ux_submit_date,
//           ta.developer_submit_date
//        FROM task_assignments ta
//        WHERE (
//           UPPER(ta.designer)       LIKE ? OR
//           UPPER(ta.videographer)   LIKE ? OR
//           UPPER(ta.video_editor)   LIKE ? OR
//           UPPER(ta.ads_handling)   LIKE ? OR
//           UPPER(ta.page_handling)  LIKE ? OR
//           UPPER(ta.ui_ux_designer) LIKE ? OR
//           UPPER(ta.developer)      LIKE ?
//         )
//           AND ta.is_assigned = 1
//           AND ta.deliverables NOT LIKE '%Package%' -- 🟢 Intha line package names-ai filter pannidum
//        ORDER BY ta.created_at DESC`,
//       [
//         `%${name}%`,
//         `%${name}%`,
//         `%${name}%`,
//         `%${name}%`,
//         `%${name}%`,
//         `%${name}%`,
//         `%${name}%`
//       ]
//     );

//     // Baki loops and inserts...
//     for (const task of rows) {
//       const [exists] = await db.query(
//         `SELECT id FROM task_list WHERE task_assignment_id = ? AND deliverables = ? LIMIT 1`,
//         [task.id, task.deliverables]
//       );

//       if (exists.length === 0) {
//         await db.query(
//           `INSERT INTO task_list (task_assignment_id, employee_name, client_name, deliverables, no_of_rows) VALUES (?, ?, ?, ?, ?)`,
//           [task.id, name, task.client_name, task.deliverables, 1]
//         );
//       }
//     }

//     return res.json({ success: true, data: rows });
//   } catch (err) {
//     console.error('GET /by-employee ERROR:', err.message);
//     return res.status(500).json({ success: false, message: err.message });
//   }
// });

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/employee-tasks/tracker?employee=NAME&client=X&task=Y
// Returns saved tracker rows for an employee (optionally filtered)
// ─────────────────────────────────────────────────────────────────────────────
router.get('/tracker', async (req, res) => {
  const { employee, client, task } = req.query;

  if (!employee)
    return res.status(400).json({ success: false, message: 'employee query param required' });

  try {
    let sql = `SELECT * FROM task_tracker WHERE UPPER(employee_name) = ?`;
    const params = [employee.toUpperCase()];

    if (client) { sql += ` AND client_name = ?`; params.push(client); }
    if (task)   { sql += ` AND single_task = ?`;  params.push(task); }

    sql += ` ORDER BY client_name, single_task, row_index`;

    const [rows] = await db.query(sql, params);

    return res.json({ success: true, data: rows });
  } catch (err) {
    console.error('GET /tracker ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/employee-tasks/tracker
// UPSERT a single tracker row — called on every status change (auto-save)
// Body: {
//   employeeName, clientName, singleTask, taskType, assignedRole,
//   rowIndex, submitDate, taskDescription,
//   startTime, holdTimes, restartTimes, completedTime, rejectedTime,
//   totalDurationSecs, status, performance, comment,
//   isAdditional, deliverableName, durationLabel
// }
// ─────────────────────────────────────────────────────────────────────────────
router.post('/tracker', async (req, res) => {
  const {
    employeeName, clientName, singleTask, taskType = '', assignedRole = '',
    rowIndex = 0, submitDate = '', taskDescription = '',
    startTime = null, holdTimes = '[]', restartTimes = '[]',
    completedTime = null, rejectedTime = null,
    totalDurationSecs = 0, status = 'IDLE', performance = 'N/A',
    comment = '', isAdditional = false, deliverableName = '', durationLabel = '',
    taskAssignmentId = null,
  } = req.body;

  if (!employeeName || !clientName || !singleTask)
    return res.status(400).json({ success: false, message: 'employeeName, clientName and singleTask are required' });

  try {
    // UPSERT — insert or update on duplicate key (employee + client + task + row)
    const [result] = await db.query(
      `INSERT INTO task_tracker
         (task_assignment_id, employee_name, client_name, single_task, task_type, assigned_role,
          row_index, submit_date, task_description,
          start_time, hold_times, restart_times, completed_time, rejected_time,
          total_duration_secs, status, performance, comment,
          is_additional, deliverable_name, duration_label)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE
         task_type          = VALUES(task_type),
         assigned_role      = VALUES(assigned_role),
         submit_date        = VALUES(submit_date),
         task_description   = VALUES(task_description),
         start_time         = VALUES(start_time),
         hold_times         = VALUES(hold_times),
         restart_times      = VALUES(restart_times),
         completed_time     = VALUES(completed_time),
         rejected_time      = VALUES(rejected_time),
         total_duration_secs= VALUES(total_duration_secs),
         status             = VALUES(status),
         performance        = VALUES(performance),
         comment            = VALUES(comment),
         is_additional      = VALUES(is_additional),
         deliverable_name   = VALUES(deliverable_name),
         duration_label     = VALUES(duration_label),
         updated_at         = CURRENT_TIMESTAMP`,
      [
        taskAssignmentId, employeeName.toUpperCase(), clientName, singleTask, taskType, assignedRole,
        rowIndex, submitDate, taskDescription,
        startTime, holdTimes, restartTimes, completedTime, rejectedTime,
        totalDurationSecs, status, performance, comment,
        isAdditional ? 1 : 0, deliverableName, durationLabel,
      ]
    );
    const io = req.app.get("io");

io.emit("taskAssigned", {
  refresh: true,
});

    return res.status(201).json({
      success: true,
      message: 'Tracker row saved',
      data: { id: result.insertId || result.info },
    });
  } catch (err) {
    console.error('POST /tracker ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// PUT /api/employee-tasks/tracker/:id
// Update a specific tracker row by ID (used by manual Save button)
// ─────────────────────────────────────────────────────────────────────────────
router.put('/tracker/:id', async (req, res) => {
  const {
    submitDate, taskDescription, startTime, holdTimes, restartTimes,
    completedTime, rejectedTime, totalDurationSecs, status, performance, comment,
    deliverableName, durationLabel,
  } = req.body;

  try {
    const [result] = await db.query(
      `UPDATE task_tracker SET
         submit_date         = ?,
         task_description    = ?,
         start_time          = ?,
         hold_times          = ?,
         restart_times       = ?,
         completed_time      = ?,
         rejected_time       = ?,
         total_duration_secs = ?,
         status              = ?,
         performance         = ?,
         comment             = ?,
         deliverable_name    = ?,
         duration_label      = ?
       WHERE id = ?`,
      [
        submitDate, taskDescription, startTime, holdTimes, restartTimes,
        completedTime, rejectedTime, totalDurationSecs, status, performance, comment,
        deliverableName, durationLabel,
        req.params.id,
      ]
    );
    
    if (result.affectedRows === 0)
      return res.status(404).json({ success: false, message: 'Tracker row not found' });

 const io = req.app.get("io");

io.emit("taskAssigned", {
  refresh: true,
});

return res.json({
  success: true,
  message: "Tracker row updated",
});
 } catch (err) {
    console.error('PUT /tracker/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/employee-tasks/tracker/save-all
// Bulk save — called when user clicks the "Save" button in header
// Body: { rows: [ { ...same fields as POST /tracker } ] }
// ─────────────────────────────────────────────────────────────────────────────
router.post('/tracker/save-all', async (req, res) => {
  const { rows } = req.body;

  if (!Array.isArray(rows) || rows.length === 0)
    return res.status(400).json({ success: false, message: 'rows array is required' });

  const connection = await db.getConnection();
  try {
    await connection.beginTransaction();

    for (const row of rows) {
      const {
        employeeName, clientName, singleTask, taskType = '', assignedRole = '',
        rowIndex = 0, submitDate = '', taskDescription = '',
        startTime = null, holdTimes = '[]', restartTimes = '[]',
        completedTime = null, rejectedTime = null,
        totalDurationSecs = 0, status = 'IDLE', performance = 'N/A',
        comment = '', isAdditional = false, deliverableName = '', durationLabel = '',
        taskAssignmentId = null,
      } = row;

      await connection.query(
        `INSERT INTO task_tracker
           (task_assignment_id, employee_name, client_name, single_task, task_type, assigned_role,
            row_index, submit_date, task_description,
            start_time, hold_times, restart_times, completed_time, rejected_time,
            total_duration_secs, status, performance, comment,
            is_additional, deliverable_name, duration_label)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE
           submit_date         = VALUES(submit_date),
           task_description    = VALUES(task_description),
           start_time          = VALUES(start_time),
           hold_times          = VALUES(hold_times),
           restart_times       = VALUES(restart_times),
           completed_time      = VALUES(completed_time),
           rejected_time       = VALUES(rejected_time),
           total_duration_secs = VALUES(total_duration_secs),
           status              = VALUES(status),
           performance         = VALUES(performance),
           comment             = VALUES(comment),
           is_additional       = VALUES(is_additional),
           deliverable_name    = VALUES(deliverable_name),
           duration_label      = VALUES(duration_label),
           updated_at          = CURRENT_TIMESTAMP`,
        [
          taskAssignmentId, (employeeName || '').toUpperCase(), clientName, singleTask,
          taskType, assignedRole, rowIndex, submitDate, taskDescription,
          startTime, holdTimes, restartTimes, completedTime, rejectedTime,
          totalDurationSecs, status, performance, comment,
          isAdditional ? 1 : 0, deliverableName, durationLabel,
        ]
      );
    }


    await connection.commit();
const io = req.app.get("io");

io.emit("taskAssigned", {
  refresh: true,
});
    return res.json({ success: true, message: `${rows.length} row(s) saved successfully` });
  } catch (err) {
    await connection.rollback();
    console.error('POST /tracker/save-all ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  } finally {
    connection.release();
  }
});

// DELETE /api/employee-tasks/tracker/:id
router.delete('/tracker/:id', async (req, res) => {
  try {
    const [result] = await db.query(`DELETE FROM task_tracker WHERE id = ?`, [req.params.id]);
    if (result.affectedRows === 0)
      return res.status(404).json({ success: false, message: 'Not found' });
  const io = req.app.get("io");

io.emit("taskAssigned", {
  refresh: true,
});

return res.json({
  success: true,
  message: "Deleted",
});
} catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;