// routes/task-list.js — Task List (per-client task allocations)
const express = require('express');
const router  = express.Router();
const db      = require('../config/db');
 
// GET /api/task-list — all entries
router.get('/', async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT tl.*, tm.task_name AS task_master_name, tt.timing AS timing_string
      FROM task_list tl
      LEFT JOIN task_master tm ON tm.id = tl.task_master_id
      LEFT JOIN task_timings tt ON tt.id = tl.task_timing_id
      ORDER BY tl.id DESC
    `);
    return res.json({ success: true, data: rows });
  } catch (err) {
    console.error('GET /task-list ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/task-list/by-assignment/:taskAssignmentId/:deliverables
router.get('/by-assignment/:taskAssignmentId/:deliverables', async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT * FROM task_list WHERE task_assignment_id = ? AND deliverables = ? LIMIT 1`,
      [req.params.taskAssignmentId, req.params.deliverables]
    );
    return res.json({ success: true, data: rows[0] || null });
  } catch (err) {
    console.error('GET /task-list/by-assignment ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

router.post('/find-or-create', async (req, res) => {
  const {
    taskAssignmentId, clientName, deliverables, submissionDate, noOfRows,
    employeeId, employeeName,
  } = req.body;

  let formattedSubmissionDate = null;

if (submissionDate) {
    formattedSubmissionDate = submissionDate.toString().split('T')[0];
}

  if (!taskAssignmentId || !clientName || !deliverables)
    return res.status(400).json({ success: false, message: 'taskAssignmentId, clientName and deliverables are required' });

  try {
    const [existing] = await db.query(
      `SELECT * FROM task_list WHERE task_assignment_id = ? AND deliverables = ? LIMIT 1`,
      [taskAssignmentId, deliverables]
    );

    if (existing.length > 0) {
      const updates = [];
      const values = [];

      if (noOfRows !== undefined && noOfRows !== existing[0].no_of_rows) {
        updates.push('no_of_rows = ?');
        values.push(noOfRows);
        existing[0].no_of_rows = noOfRows;
      }

      if (employeeName !== undefined) {
        updates.push('employee_id = ?', 'employee_name = ?');
        values.push(employeeId || null, employeeName || null);
        existing[0].employee_id = employeeId || null;
        existing[0].employee_name = employeeName || null;
      }

      if (existing[0].task_master_id === null) {
        const [masterRows] = await db.query(
          `SELECT id FROM task_master WHERE LOWER(task_name) = LOWER(?) LIMIT 1`,
          [deliverables]
        );
        if (masterRows.length > 0) {
          updates.push('task_master_id = ?');
          values.push(masterRows[0].id);
          existing[0].task_master_id = masterRows[0].id;
        }
      }

      if (existing[0].task_timing_id === null) {
        let timingId = null;
        let timingStr = null;

        if (existing[0].task_master_id !== null) {
          const [t] = await db.query(
            `SELECT id, timing FROM task_timings WHERE task_master_id = ? LIMIT 1`,
            [existing[0].task_master_id]
          );
          if (t.length > 0) { timingId = t[0].id; timingStr = t[0].timing; }
        }
        if (timingId === null) {
          const [t2] = await db.query(
            `SELECT id, timing FROM task_timings WHERE LOWER(task_name) = LOWER(?) LIMIT 1`,
            [deliverables]
          );
          if (t2.length > 0) { timingId = t2[0].id; timingStr = t2[0].timing; }
        }
        if (timingId !== null) {
          updates.push('task_timing_id = ?', 'duration = ?');
          values.push(timingId, timingStr);
          existing[0].task_timing_id = timingId;
          existing[0].duration = timingStr;
        }
      }

      if (updates.length > 0) {
        values.push(existing[0].id);
        await db.query(`UPDATE task_list SET ${updates.join(', ')} WHERE id = ?`, values);
      }

      return res.json({ success: true, message: 'Existing task list entry found', data: existing[0] });
    }

    const [masterRows] = await db.query(
      `SELECT id FROM task_master WHERE LOWER(task_name) = LOWER(?) LIMIT 1`,
      [deliverables]
    );
    const resolvedTaskMasterId = masterRows.length > 0 ? masterRows[0].id : null;

    let resolvedTaskTimingId = null;
    let resolvedDuration = null;

    if (resolvedTaskMasterId !== null) {
      const [timingRows] = await db.query(
        `SELECT id, timing FROM task_timings WHERE task_master_id = ? LIMIT 1`,
        [resolvedTaskMasterId]
      );
      if (timingRows.length > 0) {
        resolvedTaskTimingId = timingRows[0].id;
        resolvedDuration = timingRows[0].timing;
      }
    }

    if (resolvedTaskTimingId === null) {
      const [timingRowsByName] = await db.query(
        `SELECT id, timing FROM task_timings WHERE LOWER(task_name) = LOWER(?) LIMIT 1`,
        [deliverables]
      );
      if (timingRowsByName.length > 0) {
        resolvedTaskTimingId = timingRowsByName[0].id;
        resolvedDuration = timingRowsByName[0].timing;
      }
    }

    const [result] = await db.query(
      `INSERT INTO task_list
        (task_assignment_id, employee_id, employee_name, task_master_id, task_timing_id, client_name, deliverables, duration, submission_date, no_of_rows)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        taskAssignmentId, employeeId || null, employeeName || null,
        resolvedTaskMasterId, resolvedTaskTimingId,
        // clientName, deliverables, resolvedDuration, submissionDate || null, noOfRows || 1,
        
        clientName, deliverables, resolvedDuration, formattedSubmissionDate, noOfRows || 1,
      ]
    );

    const [rows] = await db.query(`SELECT * FROM task_list WHERE id = ?`, [result.insertId]);
    return res.status(201).json({ success: true, message: 'Task list entry created', data: rows[0] });
  } catch (err) {
    console.error('POST /task-list/find-or-create ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/task-list/backfill-all
router.post('/backfill-all', async (req, res) => {
  try {
    const [nullMasterRows] = await db.query(
      `SELECT id, deliverables FROM task_list WHERE task_master_id IS NULL`
    );

    let masterUpdated = 0;
    for (const row of nullMasterRows) {
      const [masterMatch] = await db.query(
        `SELECT id FROM task_master WHERE LOWER(task_name) = LOWER(?) LIMIT 1`,
        [row.deliverables]
      );
      if (masterMatch.length > 0) {
        await db.query(`UPDATE task_list SET task_master_id = ? WHERE id = ?`, [masterMatch[0].id, row.id]);
        masterUpdated++;
      }
    }

    const [nullTimingRows] = await db.query(
      `SELECT id, task_master_id, deliverables FROM task_list WHERE task_timing_id IS NULL`
    );

    let timingUpdated = 0;
    for (const row of nullTimingRows) {
      let timingMatch = null;

      if (row.task_master_id !== null) {
        const [t] = await db.query(
          `SELECT id, timing FROM task_timings WHERE task_master_id = ? LIMIT 1`,
          [row.task_master_id]
        );
        if (t.length > 0) timingMatch = t[0];
      }
      if (!timingMatch) {
        const [t2] = await db.query(
          `SELECT id, timing FROM task_timings WHERE LOWER(task_name) = LOWER(?) LIMIT 1`,
          [row.deliverables]
        );
        if (t2.length > 0) timingMatch = t2[0];
      }

      if (timingMatch) {
        await db.query(
          `UPDATE task_list SET task_timing_id = ?, duration = ? WHERE id = ?`,
          [timingMatch.id, timingMatch.timing, row.id]
        );
        timingUpdated++;
      }
    }

    return res.json({
      success: true,
      message: `Backfill complete: ${masterUpdated} task_master_id rows fixed, ${timingUpdated} task_timing_id rows fixed.`,
    });
  } catch (err) {
    console.error('POST /task-list/backfill-all ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/task-list/client/:clientName
router.get('/client/:clientName', async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT tl.*, tm.task_name AS task_master_name, tt.timing AS timing_string
      FROM task_list tl
      LEFT JOIN task_master tm ON tm.id = tl.task_master_id
      LEFT JOIN task_timings tt ON tt.id = tl.task_timing_id
      WHERE tl.client_name = ?
      ORDER BY tl.id ASC
    `, [req.params.clientName]);
    return res.json({ success: true, data: rows });
  } catch (err) {
    console.error('GET /task-list/client ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// PUT /api/task-list/:id — update allocation
router.put('/:id', async (req, res) => {
  const { taskAssignmentId, taskMasterId, taskTimingId, clientName, deliverables, duration, submissionDate, noOfRows } = req.body;

  let formattedSubmissionDate = null;

if (submissionDate) {
    formattedSubmissionDate = submissionDate.toString().split('T')[0];
}

  try {
    const [existing] = await db.query(`SELECT * FROM task_list WHERE id = ?`, [req.params.id]);
    if (existing.length === 0)
      return res.status(404).json({ success: false, message: 'Task list entry not found' });

    const cur = existing[0];

    await db.query(
      `UPDATE task_list SET
        task_assignment_id = ?, task_master_id = ?, task_timing_id = ?, client_name = ?, deliverables = ?,
        duration = ?, submission_date = ?, no_of_rows = ?
       WHERE id = ?`,
      [
        taskAssignmentId !== undefined ? taskAssignmentId : cur.task_assignment_id,
        taskMasterId !== undefined ? taskMasterId : cur.task_master_id,
        taskTimingId !== undefined ? taskTimingId : cur.task_timing_id,
        clientName !== undefined ? clientName : cur.client_name,
        deliverables !== undefined ? deliverables : cur.deliverables,
        duration !== undefined ? duration : cur.duration,
        // submissionDate !== undefined ? submissionDate : cur.submission_date,
        submissionDate ? submissionDate.toString().split('T')[0] : cur.submission_date,
        noOfRows !== undefined ? noOfRows : cur.no_of_rows,
        req.params.id,
      ]
    );
    return res.json({ success: true, message: 'Task list entry updated' });
  } catch (err) {
    console.error('PUT /task-list/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// PATCH /api/task-list/:id/rows
router.patch('/:id/rows', async (req, res) => {
  const { noOfRows } = req.body;
  if (noOfRows === undefined)
    return res.status(400).json({ success: false, message: 'noOfRows is required' });

  try {
    const [result] = await db.query(`UPDATE task_list SET no_of_rows = ? WHERE id = ?`, [noOfRows, req.params.id]);
    if (result.affectedRows === 0)
      return res.status(404).json({ success: false, message: 'Task list entry not found' });
    return res.json({ success: true, message: 'Row count updated' });
  } catch (err) {
    console.error('PATCH /task-list/:id/rows ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// DELETE /api/task-list/:id
router.delete('/:id', async (req, res) => {
  try {
    const [result] = await db.query(`DELETE FROM task_list WHERE id = ?`, [req.params.id]);
    if (result.affectedRows === 0)
      return res.status(404).json({ success: false, message: 'Task list entry not found' });
    return res.json({ success: true, message: 'Task list entry deleted' });
  } catch (err) {
    console.error('DELETE /task-list/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/task-list — all entries with completed count
router.get('/status', async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT tl.*, 
             tm.task_name AS task_master_name, 
             tt.timing AS timing_string,
             (
               SELECT COUNT(*) 
               FROM time_tracking_task_items ti 
               WHERE ti.task_list_id = tl.id AND ti.status = 'COMPLETED'
             ) AS completed_count
      FROM task_list tl
      LEFT JOIN task_master tm ON tm.id = tl.task_master_id
      LEFT JOIN task_timings tt ON tt.id = tl.task_timing_id
      ORDER BY tl.id DESC
    `);
    return res.json({ success: true, data: rows });
  } catch (err) {
    console.error('GET /task-list ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});


module.exports = router;