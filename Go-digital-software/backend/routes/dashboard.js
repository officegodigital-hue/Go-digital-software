// routes/dashboard.js — summary metrics + task-status table for an employee's dashboard
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

// GET /api/dashboard/summary/:employeeName
// Returns:
//   assignedClients      — distinct clients this employee has any task_list row for
//   activeClients        — distinct clients with at least one task not COMPLETED/REJECTED
//   taskPending          — count of tasks not yet COMPLETED (action required)
//   upcomingDeadlines    — tasks due within the next 3 days that aren't COMPLETED
//   tasks[]              — one row per task_list entry, for the "Task Status" table
// GET /api/dashboard/summary/:employeeName
// GET /api/dashboard/summary/:employeeName
router.get('/summary/:employeeName', async (req, res) => {
  const { employeeName } = req.params;
  if (!employeeName) {
    return res.status(400).json({ success: false, message: 'employeeName is required' });
  }

  try {
    const [summaryRows] = await db.query(
      `SELECT
          tl.id AS task_list_id,
          tl.client_name,
          tl.deliverables AS task,
          tl.duration AS estimated_duration,
          tl.submission_date,
          tl.no_of_rows,

          tti.id AS tracking_item_id,
          tti.status,

          (
              SELECT COALESCE(SUM(duration_secs), 0)
              FROM time_tracking_task_items t
              WHERE t.task_list_id = tl.id
          ) AS total_duration_secs,

          COALESCE(mr.manager_action,'ACTION') AS manager_action,

          (
              SELECT COUNT(*)
              FROM time_tracking_task_items t
              WHERE t.task_list_id = tl.id
                AND t.status = 'COMPLETED'
          ) AS completed_rows,

          (
              SELECT COUNT(*)
              FROM time_tracking_task_items t
              WHERE t.task_list_id = tl.id
                AND t.status = 'REJECTED'
          ) AS rejected_rows,

          c.is_active AS client_is_active

      FROM task_list tl

      INNER JOIN clients c 
          ON TRIM(LOWER(tl.client_name)) = TRIM(LOWER(c.company_name))

      LEFT JOIN time_tracking_task_items tti
      ON tti.id = (
          SELECT id
          FROM time_tracking_task_items t
          WHERE t.task_list_id = tl.id
          ORDER BY t.s_no DESC
          LIMIT 1
      )

      LEFT JOIN manager_review mr
          ON mr.tracking_item_id = tti.id

      WHERE tl.employee_name = ?
        AND c.is_active = 1`,
      [employeeName]
    );

    const [todayRows] = await db.query(
      `SELECT
          tl.id AS task_list_id,
          tl.client_name,
          tl.deliverables AS task,
          tl.duration AS estimated_duration,
          tl.submission_date,
          tti.updated_at,
          tti.id AS tracking_item_id,
          tti.status,
          COALESCE(mr.manager_action,'ACTION') AS manager_action
      FROM task_list tl
      INNER JOIN clients c 
          ON TRIM(LOWER(tl.client_name)) = TRIM(LOWER(c.company_name))
      LEFT JOIN time_tracking_task_items tti
      ON tti.id = (
          SELECT id
          FROM time_tracking_task_items t
          WHERE t.task_list_id = tl.id
          ORDER BY t.s_no DESC
          LIMIT 1
      )
      LEFT JOIN manager_review mr
      ON mr.tracking_item_id = tti.id
      WHERE tl.employee_name = ?
        AND c.is_active = 1
        AND DATE(tti.updated_at) = CURDATE()
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
    let review = 0;
    let rework = 0;
    let rejected = 0;
    let others = 0;
    let upcomingDeadlines = 0;

    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const threeDaysOut = new Date(today);
    threeDaysOut.setDate(threeDaysOut.getDate() + 3);

    const tasks = summaryRows.map((r) => {
      const status = r.status || 'IDLE';
      const isClientActive = r.client_is_active == 1 || r.client_is_active === true;

      if (isClientActive) {
        clientsSet.add(r.client_name);
      }

      const isOpen = ![
        'COMPLETED',
        'REJECTED'
      ].includes(status);

      if (isOpen && isClientActive) {
        activeClientsSet.add(r.client_name);
        activeTasks++;
      }

      if (
        status !== 'COMPLETED' &&
        status !== 'REJECTED' &&
        isClientActive
      ) {
        taskPending++;
      }

      if (status === 'ON HOLD' && isClientActive) {
        onHoldCount++;
      }

      if ((r.rejected_rows ?? 0) > 0 && isClientActive) {
        rejectedTasks++;
        rejectedClientsSet.add(r.client_name);
      }

      if (isClientActive) {
        if (status === 'COMPLETED') {
          if (r.manager_action === 'APPROVED') {
            approved++;
          } else if (r.manager_action === 'REWORK') {
            rework++;
          } else if (r.manager_action === 'REJECTED') {
            rejected++;
          } else {
            review++;
          }
        } else if (status !== 'REJECTED') {
          others++;
        }
      }

      if (
        r.submission_date &&
        r.submission_date !== '0000-00-00' &&
        isClientActive
      ) {
        let due;
        if (r.submission_date instanceof Date) {
            due = new Date(r.submission_date);
        } else {
            const parts = r.submission_date.split('-');
            if (parts.length === 3) {
                due = new Date(
                    Number(parts[0]),
                    Number(parts[1]) - 1,
                    Number(parts[2])
                );
            }
        }

        if (
            due &&
            !isNaN(due) &&
            due >= today &&
            due <= threeDaysOut &&
            status !== 'COMPLETED' &&
            status !== 'REJECTED'
        ) {
            upcomingDeadlines++;
        }
      }

      let reviewStatus = '-';
      let duration = r.estimated_duration;

      if (
        r.status === 'IN PROGRESS' ||
        r.status === 'COMPLETED'
      ) {
        duration = formatDuration(r.total_duration_secs);
      }

      if (status === 'COMPLETED') {
        switch (r.manager_action) {
          case 'APPROVED':
            reviewStatus = 'APPROVED';
            break;
          case 'REWORK':
            reviewStatus = 'REWORK';
            break;
          case 'REJECTED':
            reviewStatus = 'REJECTED';
            break;
          default:
            reviewStatus = 'REVIEW';
            break;
        }
      }

      return {
        taskListId: r.task_list_id,
        trackingItemId: r.tracking_item_id,
        clientName: r.client_name,
        task: r.task,
        duration: duration,
        submissionDate:
          !r.submission_date ||
          r.submission_date === '0000-00-00'
              ? null
              : r.submission_date,
        action: status,
        status: reviewStatus,
        completedRows: r.completed_rows || 0,
        totalRows: r.no_of_rows || 0,
        isClientActive: isClientActive,
      };
    });

    // 🟢 Filter out any inactive client tasks entirely from the task array sent to the UI table
    const activeTasksOnly = tasks.filter(t => t.isClientActive);

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
        tasks: activeTasksOnly, // Only active client rows sent to Task Status table
        productivity:{
          approved,
          rework,
          rejected,
          review,
          others,
        },
      },
    });
  } catch (err) {
    console.error('GET /dashboard/summary ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

router.get('/employee-status', async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT
        tl.id AS task_list_id,
        tl.client_name,
        tl.employee_name,
        tl.deliverables AS task,
        tl.duration,
        tl.submission_date,
        tl.no_of_rows,
        tti.status,
        (
          SELECT COUNT(*)
          FROM time_tracking_task_items
          WHERE task_list_id = tl.id AND status = 'COMPLETED'
        ) AS completed_rows
      FROM task_list tl
      LEFT JOIN time_tracking_task_items tti
        ON tti.task_list_id = tl.id AND tti.s_no = 1
      WHERE LOWER(TRIM(tl.client_name)) IN (
        SELECT LOWER(TRIM(company_name)) 
        FROM clients 
        WHERE is_active = 1
      )
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

      let priority = 'LOW';
      if (daysLeft !== null) {
        if (daysLeft <= 0) priority = 'URGENT';
        else if (daysLeft <= 2) priority = 'HIGH';
        else if (daysLeft <= 5) priority = 'MEDIUM';
      }

      return {
        taskListId: r.task_list_id,
        clientName: r.client_name,
        employeeName: r.employee_name || 'Unassigned',
        task: r.task,
        duration: r.duration || 'N/A',
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


// GET /api/dashboard/recent-notifications/:employeeName
router.get('/recent-notifications/:employeeName', async (req, res) => {
  const { employeeName } = req.params;

  try {
    const [rows] = await db.query(
      `
      SELECT
        id,
        sender_name,
        recipient_name,
        message,
        is_seen,
        created_at
      FROM notifications
      WHERE sender_name = ?
         OR recipient_name = ?
      ORDER BY created_at DESC
      LIMIT 3
      `,
      [employeeName, employeeName]
    );

    const notifications = rows.map((row) => {
      let preview = "Notification";
      let category = "General";

      try {
        const msg = JSON.parse(row.message);

        preview =
          msg.preview ||
          msg.message ||
          msg.title ||
          "Notification";

        const payload = msg.payload || {};

        const type = (payload.type || "").toUpperCase();

        switch (type) {
          case "TASK_ASSIGNED":
          case "TASK_ASSIGN":
            category = "Task Assigned";
            break;

          case "TASK_REVIEW":
          case "MANAGER_REVIEW":
            category = "Task Review";
            break;

          case "PLAN_SUBMITTED":
          case "DAY_PLAN_SUBMITTED":
            category = "Daily Planner";
            break;

          case "DAY_PLANNER_WARNING":
          case "DAY_PLANNER_ALERT":
          case "DAY_PLANNER_ADMIN_WARNING":
            category = "Warning & Alert";
            break;

          case "TASK_PLANNER_SHARE":
          case "VIDEOGRAPHER_SHARE":
            category = "Content Shared";
            break;
        }
      } catch (e) {
        preview = row.message;
      }

      return {
        id: row.id,
        sender: row.sender_name,
        recipient: row.recipient_name,
        preview,
        category,
        isSeen: row.is_seen,
        createdAt: row.created_at,
      };
    });

    res.json({
      success: true,
      data: notifications,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({
      success: false,
      message: err.message,
    });
  }
});

// GET /api/dashboard/admin-notifications
router.get("/admin-notifications", async (req, res) => {
  const [rows] = await db.query(`
      SELECT id,
             sender_name,
             recipient_name,
             message,
             is_seen,
             created_at
      FROM notifications
      ORDER BY created_at DESC
      LIMIT 4
  `);

  const notifications = rows.map((row) => {
    let preview = "Notification";
    let category = "General";

    try {
      const msg = JSON.parse(row.message);

      preview =
        msg.preview ||
        msg.message ||
        msg.title ||
        "Notification";

      const payload = msg.payload || {};
      const type = (payload.type || "").toUpperCase();

      switch (type) {
        case "TASK_ASSIGNED":
          category = "Task Assigned";
          break;

        case "TASK_REVIEW":
          category = "Task Review";
          break;

        case "PLAN_SUBMITTED":
          category = "Daily Planner";
          break;

        case "DAY_PLANNER_WARNING":
          category = "Warning & Alert";
          break;

        case "TASK_PLANNER_SHARE":
        case "VIDEOGRAPHER_SHARE":
          category = "Content Shared";
          break;
      }
    } catch (_) {
      preview = row.message;
    }

    return {
      id: row.id,
      sender: row.sender_name,
      recipient: row.recipient_name,
      preview,
      category,
      isSeen: row.is_seen,
      createdAt: row.created_at,
    };
  });

  res.json({
    success: true,
    data: notifications,
  });
});

// GET /api/dashboard/live-tracking-tasks/:employeeName?date=YYYY-MM-DD
// router.get('/live-tracking-tasks/:employeeName', async (req, res) => {
//   const { employeeName } = req.params;
//   const { date } = req.query; // optional date filter

//   if (!employeeName) {
//     return res.status(400).json({ success: false, message: 'employeeName is required' });
//   }

//   try {
//     const targetDate = date ? date : null;

//     const query = `
//       SELECT
//         tl.id AS task_list_id,
//         tl.client_name,
//         tl.deliverables AS task,
//         tti.duration AS estimated_duration,
//         tti.task_description,
//         tl.submission_date,
//         tti.id AS tracking_item_id,
//         tti.status,
//         tti.updated_at,
//         (
//           SELECT COALESCE(SUM(duration_secs), 0)
//           FROM time_tracking_task_items t
//           WHERE t.task_list_id = tl.id
//         ) AS total_duration_secs,
//         COALESCE(mr.manager_action, 'ACTION') AS manager_action,
//         mr.manager_comment
//       FROM task_list tl
//       JOIN time_tracking_task_items tti ON tti.task_list_id = tl.id
//       LEFT JOIN manager_review mr ON mr.tracking_item_id = tti.id
//       WHERE tl.employee_name = ?
//       AND ( ? IS NULL OR DATE(tti.updated_at) = ? )
//       ORDER BY tti.updated_at DESC
//     `;

//     const [rows] = await db.query(query, [employeeName, targetDate, targetDate]);

//     // 🟢 Calculate total working seconds for the selected date
//     let totalWorkingSecs = 0;

//     const data = rows.map((r) => {
//       const durSecs = r.total_duration_secs || 0;
//       totalWorkingSecs += durSecs; // Sum up all task durations

//       let durationStr = r.estimated_duration || 'N/A';
//       if (durSecs > 0) {
//         const hrs = Math.floor(durSecs / 3600);
//         const mins = Math.floor((durSecs % 3600) / 60);
//         durationStr = hrs > 0 ? `${hrs} hrs ${mins} mins` : `${mins} mins`;
//       }

//       return {
//         trackingItemId: r.tracking_item_id,
//         client_name: r.client_name,
//         employee_name: employeeName,
//         task: r.task,
//         duration: durationStr,
//         status: r.status || 'IDLE',
//         manager_action: r.manager_action,
//         manager_comment: r.manager_comment || '',
//         updated_at: r.updated_at
//       };
//     });

//     return res.json({ 
//       success: true, 
//       totalWorkingSecs, // Send total secs to frontend
//       data 
//     });
//   } catch (err) {
//     console.error('GET /dashboard/live-tracking-tasks ERROR:', err.message);
//     return res.status(500).json({ success: false, message: err.message });
//   }
// });

router.get('/live-tracking-tasks/:employeeName', async (req, res) => {
  const { employeeName } = req.params;
  const { date } = req.query;

  if (!employeeName) {
    return res.status(400).json({
      success: false,
      message: 'employeeName is required'
    });
  }

  try {
    const targetDate = date ? date : null;

    const query = `
      SELECT
        tl.id AS task_list_id,
        tl.client_name,
        tl.deliverables AS task,

        tti.duration_secs,
        tti.task_description,
        

        tl.submission_date,

        tti.id AS tracking_item_id,
        tti.status,
        
        tti.comment,
        tti.updated_at,

        COALESCE(mr.manager_action, 'ACTION') AS manager_action,
        mr.manager_comment

      FROM task_list tl

      JOIN time_tracking_task_items tti
        ON tti.task_list_id = tl.id

      LEFT JOIN manager_review mr
        ON mr.tracking_item_id = tti.id

      WHERE tl.employee_name = ?
        AND (? IS NULL OR DATE(tti.updated_at) = ?)

      ORDER BY tti.updated_at DESC
    `;

    const [rows] = await db.query(query, [
      employeeName,
      targetDate,
      targetDate
    ]);

    // Selected date total working time
    let totalWorkingSecs = 0;

    const data = rows.map((r) => {
      const durationSecs = Number(r.duration_secs) || 0;

      totalWorkingSecs += durationSecs;

      let durationStr = '0 mins';

      if (durationSecs > 0) {
        const hrs = Math.floor(durationSecs / 3600);
        const mins = Math.floor((durationSecs % 3600) / 60);

        if (hrs > 0 && mins > 0) {
          durationStr = `${hrs} hrs ${mins} mins`;
        } else if (hrs > 0) {
          durationStr = `${hrs} hrs`;
        } else {
          durationStr = `${mins} mins`;
        }
      }

      return {
        trackingItemId: r.tracking_item_id,

        client_name: r.client_name,

        employee_name: employeeName,

        // Task / deliverable
        task: r.task,

        // Task description
        task_description: r.task_description || '',

        // Actual tracking duration
        duration: durationStr,

        status: r.status || 'IDLE',

        manager_action: r.manager_action,

        manager_comment: r.manager_comment || '',

         comment: r.comment || '',
         
        updated_at: r.updated_at
      };
    });

    return res.json({
      success: true,
      totalWorkingSecs,
      data
    });

  } catch (err) {
    console.error(
      'GET /dashboard/live-tracking-tasks ERROR:',
      err
    );

    return res.status(500).json({
      success: false,
      message: err.message
    });
  }
});

module.exports = router;