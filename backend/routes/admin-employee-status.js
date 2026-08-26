// routes/admin-employee-status.js — all employees' current tasks, for the admin
// "Employee Status" ledger screen.
const express = require('express');
const router  = express.Router();
const db      = require('../config/db');

function formatDuration(seconds) {
    if (!seconds) return '0 mins';

    const hrs = Math.floor(seconds / 3600);
    const mins = Math.floor((seconds % 3600) / 60);

    if (hrs > 0 && mins > 0) return `${hrs} hrs ${mins} mins`;
    if (hrs > 0) return `${hrs} hrs`;
    return `${mins} mins`;
}

// GET /api/admin/employee-status
// GET /api/admin/employee-status
router.get('/employee-status', async (req, res) => {
  try {
    const [rows] = await db.query(`
    SELECT
    tl.id AS task_list_id,
    tl.client_name,
    tl.employee_name,
    tl.deliverables AS task,
    tl.duration AS estimated_duration,
    tl.submission_date,
    tl.no_of_rows,

    COALESCE((
        SELECT SUM(duration_secs)
        FROM time_tracking_task_items
        WHERE task_list_id = tl.id
    ),0) AS total_duration_secs,

    COALESCE((
        SELECT COUNT(*)
        FROM time_tracking_task_items
        WHERE task_list_id = tl.id
        AND UPPER(status) = 'COMPLETED'
    ), 0) AS completed_rows,

    COALESCE((
        SELECT COUNT(*)
        FROM time_tracking_task_items
        WHERE task_list_id = tl.id
        AND (UPPER(status) = 'HOLD' OR UPPER(status) = 'ON HOLD')
    ), 0) AS hold_rows,

    COALESCE((
    SELECT COUNT(*)
    FROM time_tracking_task_items
    WHERE task_list_id = tl.id
    AND UPPER(status) = 'REJECTED'
), 0) AS rejected_rows,

    COALESCE((
        SELECT COUNT(*)
        FROM time_tracking_task_items
        WHERE task_list_id = tl.id
        AND (UPPER(status) = 'PROCESSING' OR UPPER(status) = 'IN PROGRESS' OR UPPER(status) = 'RUNNING')
    ), 0) AS processing_rows,

    COALESCE((
        SELECT COUNT(*)
        FROM time_tracking_task_items
        WHERE task_list_id = tl.id
        AND (
            UPPER(status) = 'NOT START'
            OR UPPER(status) = 'IDLE'
            OR UPPER(status) = 'NOT STARTED'
            OR status IS NULL
            OR TRIM(status) = ''
        )
    ), 0) AS not_started_rows

FROM task_list tl
INNER JOIN clients c 
    ON TRIM(LOWER(tl.client_name)) = TRIM(LOWER(c.company_name))
WHERE c.is_active = 1
ORDER BY tl.submission_date ASC;
    `);

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const data = rows.map((r) => {
      let daysLeft = null;
      if (r.submission_date) {
        const due = new Date(r.submission_date);
        if (!isNaN(due)) {
          due.setHours(0, 0, 0, 0);
          daysLeft = Math.round((due - today) / 86400000);
        }
      }

      let priority = 'LOW';
      if (daysLeft !== null) {
        if (daysLeft <= 0) priority = 'URGENT';
        else if (daysLeft <= 2) priority = 'HIGH';
        else if (daysLeft <= 5) priority = 'MEDIUM';
      }

      let duration = r.estimated_duration;
      if (r.completed_rows > 0 || r.total_duration_secs > 0) {
        duration = formatDuration(r.total_duration_secs);
      }

      // Fallback: If no tracking items exist yet in the table, set all rows as 'Not Started'
      let notStarted = r.not_started_rows;
      const totalTracked = r.completed_rows + r.hold_rows + r.processing_rows + r.not_started_rows + r.rejected_rows;
      if (totalTracked === 0 && r.no_of_rows > 0) {
        notStarted = r.no_of_rows;
      }

      return {
        taskListId: r.task_list_id,
        clientName: r.client_name,
        employeeName: r.employee_name || 'Unassigned',
        task: r.task,
        duration,
        submissionDate: r.submission_date,
        daysLeft,
        priority,
        completedRows: r.completed_rows || 0,
        holdRows: r.hold_rows || 0,
        rejectedRows: r.rejected_rows || 0,
        processingRows: r.processing_rows || 0,
        notStartedRows: notStarted,
        totalRows: r.no_of_rows || 1,
      };
    });

    return res.json({ success: true, data });
  } catch (err) {
    console.error('GET /admin/employee-status ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/admin/employee-status/:taskListId/details
router.get('/employee-status/:taskListId/details', async (req, res) => {
  try {
    const { taskListId } = req.params;

    if (!taskListId || isNaN(Number(taskListId))) {
      return res.status(400).json({
        success: false,
        message: 'Invalid task list ID',
      });
    }

    const [rows] = await db.query(
      `
      SELECT
        id,
        task_list_id,
        task_timing_id,
        s_no,
        submit_date,
        task_description,
        duration_secs,
        comment,
        performance,
        status,
        created_at,
        updated_at,
        start_time,
        complete_time,
        reject_time,
        hold_time_1,
        hold_time_2,
        hold_time_3,
        hold_time_4,
        hold_time_5,
        hold_time_6,
        hold_time_7,
        hold_time_8,
        hold_time_9,
        hold_time_10,
        restart_time_1,
        restart_time_2,
        restart_time_3,
        restart_time_4,
        restart_time_5,
        restart_time_6,
        restart_time_7,
        restart_time_8,
        restart_time_9,
        restart_time_10
      FROM time_tracking_task_items
      WHERE task_list_id = ?
      ORDER BY s_no ASC
      `,
      [Number(taskListId)]
    );

    return res.json({
      success: true,
      data: rows,
    });

  } catch (err) {
    console.error(
      'GET /admin/employee-status/:taskListId/details ERROR:',
      err
    );

    return res.status(500).json({
      success: false,
      message: err.message,
    });
  }
});

module.exports = router;