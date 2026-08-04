// routes/tracking-items.js — Time Tracking Task Items (per-row S.NO data)
// ✅ task_action table removed. Every start/hold/restart/complete/reject
// timestamp now lives directly as a column on time_tracking_task_items.
const express = require('express');
const router  = express.Router();
const db      = require('../config/db');
const { createNotification } = require('./notifications');

// Helper to broadcast task updates via Socket.io
const emitTaskUpdate = (req, trackingItemId, action) => {
  try {
    const io = req.app.get('io');
    if (io) {
      io.emit('task_updated', {
        type: 'TRACKING_ITEM_UPDATE',
        trackingItemId: trackingItemId,
        action: action
      });
      console.log('📡 Broadcasted task_updated for tracking item:', trackingItemId);
    }
  } catch (socketErr) {
    console.error('Socket emit error:', socketErr);
  }
};

function calculateWorkingDuration(row) {

  if (!row.start_time || !row.complete_time) {
    return 0;
  }

  const start = new Date(row.start_time);
  const complete = new Date(row.complete_time);

  let totalSeconds =
    Math.floor((complete - start) / 1000);

  let holdSeconds = 0;

  for (let i = 1; i <= 10; i++) {

    const hold = row[`hold_time_${i}`];
    const restart = row[`restart_time_${i}`];

    if (hold && restart) {

      holdSeconds += Math.floor(
        (new Date(restart) - new Date(hold)) / 1000
      );

    }

  }

  totalSeconds -= holdSeconds;

  if (totalSeconds < 0)
    totalSeconds = 0;

  return totalSeconds;
}

// GET /api/tracking-items/by-task-list/:taskListId — all rows for ONE task_list entry
// All action timestamps are plain columns on this table now, so no JOIN is needed.
router.get('/by-task-list/:taskListId', async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT * FROM time_tracking_task_items WHERE task_list_id = ? ORDER BY s_no ASC`,
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
  let formattedSubmitDate = null;

  if (submitDate) {
    formattedSubmitDate = submitDate.toString().split("T")[0];
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
       WHERE task_list_id = ? AND s_no = ?`,
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
           submit_date = ?,
           task_description = ?,
           duration_secs = ?,
           comment = ?,
           performance = ?,
           status = ?
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
  try {
    const [result] = await db.query(
      // `UPDATE time_tracking_task_items SET start_time = NOW(), status = 'IN PROGRESS' WHERE id = ?`,
      `UPDATE time_tracking_task_items
SET
start_time = IFNULL(start_time, NOW()),
status='IN PROGRESS'
WHERE id=?`,
      [id]
    );
    if (result.affectedRows === 0)
      return res.status(404).json({ success: false, message: 'Tracking item not found' });

    const [rows] = await db.query(`SELECT * FROM time_tracking_task_items WHERE id = ?`, [id]);
    emitTaskUpdate(req, id, 'IN PROGRESS');
    return res.json({ success: true, message: 'Task started', data: rows[0] });
  } catch (err) {
    console.error('POST /tracking-items/:id/start ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/tracking-items/:id/hold — fills the next empty hold_time_N (1-10)
router.post('/:id/hold', async (req, res) => {
  const { id } = req.params;
  try {
    const [rows] = await db.query(`SELECT * FROM time_tracking_task_items WHERE id = ?`, [id]);
    if (rows.length === 0)
      return res.status(404).json({ success: false, message: 'Tracking item not found' });

    const row = rows[0];
    let slot = null;
    for (let i = 1; i <= 10; i++) {
      if (row[`hold_time_${i}`] === null) { slot = i; break; }
    }
    if (!slot) {
      return res.status(400).json({ success: false, message: 'Maximum 10 holds reached' });
    }

    await db.query(
      `UPDATE time_tracking_task_items SET hold_time_${slot} = NOW(), status = 'ON HOLD' WHERE id = ?`,
      [id]
    );

    const [updated] = await db.query(`SELECT * FROM time_tracking_task_items WHERE id = ?`, [id]);
    emitTaskUpdate(req, id, 'ON HOLD');
    return res.json({ success: true, message: `Task on hold (slot ${slot})`, data: updated[0] });
  } catch (err) {
    console.error('POST /tracking-items/:id/hold ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/tracking-items/:id/restart — fills the next empty restart_time_N (1-10)
router.post('/:id/restart', async (req, res) => {
  const { id } = req.params;
  try {
    const [rows] = await db.query(`SELECT * FROM time_tracking_task_items WHERE id = ?`, [id]);
    if (rows.length === 0)
      return res.status(404).json({ success: false, message: 'Tracking item not found' });

    const row = rows[0];
    let slot = null;
    for (let i = 1; i <= 10; i++) {
      if (row[`restart_time_${i}`] === null) { slot = i; break; }
    }
    if (!slot) {
      return res.status(400).json({ success: false, message: 'Maximum 10 restarts reached' });
    }

    await db.query(
      `UPDATE time_tracking_task_items SET restart_time_${slot} = NOW(), status = 'IN PROGRESS' WHERE id = ?`,
      [id]
    );

    const [updated] = await db.query(`SELECT * FROM time_tracking_task_items WHERE id = ?`, [id]);
    emitTaskUpdate(req, id, 'IN PROGRESS');
    return res.json({ success: true, message: `Task restarted (slot ${slot})`, data: updated[0] });
  } catch (err) {
    console.error('POST /tracking-items/:id/restart ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  } 
});

// POST /api/tracking-items/:id/complete
// POST /api/tracking-items/:id/complete
router.post('/:id/complete', async (req, res) => {
  const { id } = req.params;
  const { performance } = req.body;

  try {

    // 1. Update task as completed
    const [result] = await db.query(
      `UPDATE time_tracking_task_items
       SET
       complete_time = IFNULL(complete_time, NOW()),
       status = 'COMPLETED',
       performance = ?
       WHERE id = ?`,
      [performance || 'N/A', id]
    );


    if (result.affectedRows === 0) {
      return res.status(404).json({
        success: false,
        message: 'Tracking item not found'
      });
    }


    // 2. Get completed task data
    const [rows] = await db.query(
      `SELECT * 
       FROM time_tracking_task_items 
       WHERE id = ?`,
      [id]
    );


    const row = rows[0];


    // 3. Calculate working duration
    const durationSecs = calculateWorkingDuration(row);


    // 4. Save calculated duration
    await db.query(
      `UPDATE time_tracking_task_items
       SET duration_secs = ?
       WHERE id = ?`,
      [durationSecs, id]
    );



    // 5. Create notification for admin
    try {

      const [taskInfo] = await db.query(
        `SELECT 
            tl.employee_name,
            tl.deliverables
         FROM task_list tl
         WHERE tl.id = ?`,
        [row.task_list_id]
      );


      if (taskInfo.length > 0 && taskInfo[0].employee_name) {


        // Get all admins
        const [admins] = await db.query(
          `SELECT full_name
           FROM employees
           WHERE role = 'admin'`
        );


        // Send notification to every admin
        for (const admin of admins) {

          await createNotification({

            senderName: taskInfo[0].employee_name,

            recipientName: admin.full_name,

            message:
              `Task "${taskInfo[0].deliverables}" has been submitted for review.`

          });

        }

      }


    } catch (notifyErr) {

      console.error(
        '⚠️ complete notification failed (non-fatal):',
        notifyErr.message
      );

    }

emitTaskUpdate(req, id, 'COMPLETED');

    return res.json({

      success: true,

      message: 'Task completed',

      data: {
        ...row,
        durationSecs
      }

    });


  } catch (err) {

    console.error(
      'POST /tracking-items/:id/complete ERROR:',
      err.message
    );


    return res.status(500).json({

      success: false,

      message: err.message

    });

  }

});

// POST /api/tracking-items/:id/reject
router.post('/:id/reject', async (req, res) => {
  const { id } = req.params;
  try {

    const [result] = await db.query(
      `UPDATE time_tracking_task_items SET reject_time = IFNULL(reject_time,NOW()), status = 'REJECTED' WHERE id = ?`,
      [id]
    );
    if (result.affectedRows === 0)
      return res.status(404).json({ success: false, message: 'Tracking item not found' });

    const [rows] = await db.query(`SELECT * FROM time_tracking_task_items WHERE id = ?`, [id]);
     const row = rows[0];
     const durationSecs = calculateWorkingDuration(row);


    emitTaskUpdate(req, id, 'REJECTED');
    return res.json({ success: true, message: 'Task rejected', data: rows[0] });
  } catch (err) {
    console.error('POST /tracking-items/:id/reject ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// DELETE /api/tracking-items/:id
router.delete('/:id', async (req, res) => {
  try {

    console.log("submitDate:", submitDate);
console.log("formattedSubmitDate:", formattedSubmitDate);

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

module.exports = router;