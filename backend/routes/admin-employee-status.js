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
router.get('/employee-status', async (req, res) => {
  try {
    // FIX: added a completed/total row count per task, pulled from
    // time_tracking_task_items — "5/12" means 5 of the 12 rows on that
    // task_list entry currently have status = COMPLETED.
    const [rows] = await db.query(`
     SELECT
    tl.id AS task_list_id,
    tl.client_name,
    tl.employee_name,
    tl.deliverables AS task,
    tl.duration AS estimated_duration,
    tl.submission_date,
    tl.no_of_rows,

    tti.status,

    COALESCE((
        SELECT SUM(duration_secs)
        FROM time_tracking_task_items
        WHERE task_list_id = tl.id
    ),0) AS total_duration_secs,

    (
        SELECT COUNT(*)
        FROM time_tracking_task_items
        WHERE task_list_id = tl.id
          AND status = 'COMPLETED'
    ) AS completed_rows

FROM task_list tl

LEFT JOIN time_tracking_task_items tti
ON tti.task_list_id = tl.id
AND tti.s_no = 1

ORDER BY tl.submission_date ASC
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

      // No priority column exists yet — derived from urgency of the deadline.
      let priority = 'LOW';
      if (daysLeft !== null) {
        if (daysLeft <= 0) priority = 'URGENT';
        else if (daysLeft <= 2) priority = 'HIGH';
        else if (daysLeft <= 5) priority = 'MEDIUM';
      }

      let duration = r.estimated_duration;

if (
    r.status === 'IN PROGRESS' ||
    r.status === 'COMPLETED'
) {
    duration = formatDuration(r.total_duration_secs);
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
    status: r.status || 'IDLE',
    completedRows: r.completed_rows || 0,
    totalRows: r.no_of_rows || 0,
};
    });

    return res.json({ success: true, data });
  } catch (err) {
    console.error('GET /admin/employee-status ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;