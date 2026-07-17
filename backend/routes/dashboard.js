// routes/dashboard.js — summary metrics + task-status table for an employee's dashboard
const express = require('express');
const router  = express.Router();
const db      = require('../config/db');

// GET /api/dashboard/summary/:employeeName
// Returns:
//   assignedClients      — distinct clients this employee has any task_list row for
//   activeClients        — distinct clients with at least one task not COMPLETED/REJECTED
//   taskPending          — count of tasks not yet COMPLETED (action required)
//   upcomingDeadlines    — tasks due within the next 3 days that aren't COMPLETED
//   tasks[]              — one row per task_list entry, for the "Task Status" table
router.get('/summary/:employeeName', async (req, res) => {
  const { employeeName } = req.params;
  if (!employeeName) {
    return res.status(400).json({ success: false, message: 'employeeName is required' });
  }

  try {
    // s_no = 1 is treated as the row that represents this task's overall
    // status for the dashboard card (the detailed per-row breakdown still
    // lives in the Assigned Tasks screen).
   const [summaryRows] = await db.query(
`SELECT
    tl.id AS task_list_id,
    tl.client_name,
    tl.deliverables AS task,
    tl.duration,
    tl.submission_date,
    tti.id AS tracking_item_id,
    tti.status
FROM task_list tl
LEFT JOIN time_tracking_task_items tti
ON tti.task_list_id=tl.id
AND tti.s_no=1
WHERE tl.employee_name=?`,
[employeeName]
);

const [todayRows] = await db.query(
`SELECT
    tl.id AS task_list_id,
    tl.client_name,
    tl.deliverables AS task,
    tl.duration,
    tl.submission_date,
    tti.updated_at,
    tti.id AS tracking_item_id,
    tti.status,
    COALESCE(mr.manager_action,'ACTION') AS manager_action
FROM task_list tl
LEFT JOIN time_tracking_task_items tti
ON tti.task_list_id=tl.id
AND tti.s_no=1
LEFT JOIN manager_review mr
ON mr.tracking_item_id=tti.id
WHERE tl.employee_name=?
AND DATE(tti.updated_at)=CURDATE()
ORDER BY tti.updated_at DESC
LIMIT 6`,
[employeeName]
);

    const clientsSet = new Set();
    const activeClientsSet = new Set();
    const rejectedClientsSet = new Set();
    let activeTasks = 0;
    let taskPending = 0;
    let onHoldCount = 0;
    let rejectedTasks = 0;
    let approved = 0;
let rework = 0;
let rejected = 0;
    let upcomingDeadlines = 0;

    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const threeDaysOut = new Date(today);
    threeDaysOut.setDate(threeDaysOut.getDate() + 3);

    const tasks = summaryRows.map((r) => {
      const status = r.status || 'IDLE';
      clientsSet.add(r.client_name);

      const isOpen = status !== 'COMPLETED' && status !== 'REJECTED';
      if (isOpen) {
        activeClientsSet.add(r.client_name);
        activeTasks++;
      }
      if (status === 'IN PROGRESS' || status === 'ON HOLD') {
        taskPending++;
      }
      if (status === 'ON HOLD') {
        onHoldCount++;
      }
      if (status === 'REJECTED') {
        rejectedTasks++;
        rejectedClientsSet.add(r.client_name);
      }
      if (r.manager_action === 'APPROVED') {
    approved++;
}

if (r.manager_action === 'REWORK') {
    rework++;
}

if (r.manager_action === 'REJECTED') {
    rejected++;
}

      if (r.submission_date) {
        const due = new Date(r.submission_date);
        if (!isNaN(due) && due >= today && due <= threeDaysOut && status !== 'COMPLETED') {
          upcomingDeadlines++;
        }
      }

      return {
        taskListId: r.task_list_id,
        trackingItemId: r.tracking_item_id,
        clientName: r.client_name,
        task: r.task,
        duration: r.duration || 'N/A',
        submissionDate: r.submission_date,
        action: status,
        // Mirrors the original hardcoded UI: only a COMPLETED action shows
        // a REVIEW badge in the STATUS column, everything else shows '-'.
        status: status === 'COMPLETED' ? 'REVIEW' : '-',
      };
    });

    return res.json({
      success: true,
      data: {
        assignedClients: clientsSet.size,
        activeClients: activeClientsSet.size,
        activeTasks,
        taskPending,
        onHoldCount,
        rejectedTasks,
        rejectedClients: rejectedClientsSet.size,
        upcomingDeadlines,
        tasks,
        productivity:{
    approved,
    rework,
    rejected
},
      },
    });
  } catch (err) {
    console.error('GET /dashboard/summary ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;