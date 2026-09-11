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

// 🟢 Intha function-ai mattum unga file-oda mela add pannikonga (or replace pannikonga)
async function fetchAssignedTaskAssignments() {
    const [rows] = await db.query(`
      SELECT
        ta.id AS task_assignment_id,
        ta.client_name,
        ta.deliverables,
        ta.maintenance_date,
        ta.deadline AS submission_date,
        ta.is_assigned
      FROM task_assignments ta
      INNER JOIN clients c 
        ON TRIM(LOWER(ta.client_name)) = TRIM(LOWER(c.company_name))
      WHERE c.is_active = 1 
        AND ta.is_assigned = 1
      ORDER BY ta.created_at DESC;
    `);

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    return rows.map((r) => {
      let subDate = r.submission_date ? new Date(r.submission_date) : null;
      let calculatedStatus = 'In Progress';

      if (subDate) {
        subDate.setHours(0, 0, 0, 0);
        if (subDate < today) {
          calculatedStatus = 'Completed';
        } else {
          calculatedStatus = 'In Progress';
        }
      }

      return {
        taskListId: r.task_assignment_id,
        clientName: r.client_name,
        task: r.deliverables || '—',
        maintenanceDate: r.maintenance_date || '—',
        submissionDate: r.submission_date,
        status: calculatedStatus,
      };
    });
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

// router.get('/admin-employee-status', async (req, res) => {
//   try {
//     const [rows] = await db.query(`
//       SELECT
//         ta.id AS task_assignment_id,
//         ta.client_name,
//         ta.deliverables,
//         ta.maintenance_date,
//         ta.deadline AS submission_date,
//         ta.is_assigned
//       FROM task_assignments ta
//       INNER JOIN clients c 
//         ON TRIM(LOWER(ta.client_name)) = TRIM(LOWER(c.company_name))
//       WHERE c.is_active = 1 
//         AND ta.is_assigned = 1
//       ORDER BY ta.created_at DESC;
//     `);

//     const today = new Date();
//     today.setHours(0, 0, 0, 0);

//     const data = rows.map((r) => {
//       let subDate = r.submission_date ? new Date(r.submission_date) : null;
//       let calculatedStatus = 'In Progress';

//       if (subDate) {
//         subDate.setHours(0, 0, 0, 0);
//         if (subDate < today) {
//           calculatedStatus = 'Completed';
//         } else {
//           calculatedStatus = 'In Progress';
//         }
//       }

//       return {
//         taskListId: r.task_assignment_id,
//         clientName: r.client_name,
//         task: r.deliverables || '—',
//         maintenanceDate: r.maintenance_date || '—',
//         submissionDate: r.submission_date,
//         status: calculatedStatus,
//       };
//     });

//     return res.json({ success: true, data });
//   } catch (err) {
//     console.error('GET /admin/admin-employee-status ERROR:', err.message);
//     return res.status(500).json({ success: false, message: err.message });
//   }
// });

// Detailed view route for the selected task assignment

// GET /api/admin-employee-status (Alternative route path matching)
router.get('/admin-employee-status', async (req, res) => {
  try {
    const data = await fetchAssignedTaskAssignments();
    return res.json({ success: true, data });
  } catch (err) {
    console.error('GET /admin/admin-employee-status ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// 🟢 Handles GET /api/admin/employee-status/:id/details (Matched with Frontend URL)
router.get('/employee-status/:id/details', async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT * FROM task_assignments WHERE id = ?`,
      [req.params.id]
    );
    return res.json({ success: true, data: rows[0] || {} });
  } catch (err) {
    console.error('GET /admin/employee-status/:id/details ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/admin/employee-status/client/:clientName/details
router.get('/employee-status/client/:clientName/details', async (req, res) => {
  try {
    const clientName = decodeURIComponent(req.params.clientName);

    // ============================================================
    // 1. Get all assigned task assignment rows for this client
    // ============================================================
    const [assignments] = await db.query(
      `
      SELECT
        id,
        client_name,
        deliverables,
        deadline,
        maintenance_date,

        ads_handling,
        ads_platform,

        page_handling,
        pages_platform,

        designer,
        designer_tasks,

        videographer,
        videographer_tasks,

        video_editor,
        video_editor_task,

        ui_ux_designer,
        ui_ux_tasks,

        developer,
        developer_tasks,

        website_designer,
        website_designer_tasks

      FROM task_assignments
      WHERE TRIM(LOWER(client_name)) = TRIM(LOWER(?))
        AND is_assigned = 1
      ORDER BY created_at DESC
      `,
      [clientName]
    );

    const roleMappings = [
      {
        role: 'Ads Handler',
        employeeField: 'ads_handling',
        taskField: 'ads_platform',
      },
      {
        role: 'Page Handler',
        employeeField: 'page_handling',
        taskField: 'pages_platform',
      },
      {
        role: 'Designer',
        employeeField: 'designer',
        taskField: 'designer_tasks',
      },
      {
        role: 'Videographer',
        employeeField: 'videographer',
        taskField: 'videographer_tasks',
      },
      {
        role: 'Video Editor',
        employeeField: 'video_editor',
        taskField: 'video_editor_task',
      },
      {
        role: 'UI/UX Designer',
        employeeField: 'ui_ux_designer',
        taskField: 'ui_ux_tasks',
      },
      {
        role: 'Developer',
        employeeField: 'developer',
        taskField: 'developer_tasks',
      },
      {
        role: 'Website Designer',
        employeeField: 'website_designer',
        taskField: 'website_designer_tasks',
      },
    ];

    const roleDetails = [];

    // ============================================================
    // 2. Each role + employee + assigned task
    // ============================================================
    for (const assignment of assignments) {
      for (const mapping of roleMappings) {
        const employeeName =
            assignment[mapping.employeeField]?.toString().trim();

        const assignedTask =
            assignment[mapping.taskField]?.toString().trim();

        // Skip empty / NONE employee
        if (
          !employeeName ||
          employeeName.toUpperCase() === 'NONE'
        ) {
          continue;
        }

        // ========================================================
        // 3. Find matching task_list row
        // ========================================================
        const [taskListRows] = await db.query(
          `
          SELECT
            id,
            no_of_rows
          FROM task_list
          WHERE task_assignment_id = ?
            AND employee_name = ?
            AND client_name = ?
          ORDER BY id DESC
          `,
          [
            assignment.id,
            employeeName,
            assignment.client_name,
          ]
        );

        let totalTasks = 0;
        let completedTasks = 0;
        let processingTasks = 0;
        let holdTasks = 0;
        let rejectedTasks = 0;
        let notStartedTasks = 0;

        // ========================================================
        // 4. Calculate tracking status
        // ========================================================
        for (const taskList of taskListRows) {
          totalTasks += Number(taskList.no_of_rows || 0);

          const [trackingRows] = await db.query(
            `
            SELECT
              COUNT(*) AS total_count,

              SUM(
                CASE
                  WHEN UPPER(status) = 'COMPLETED'
                  THEN 1 ELSE 0
                END
              ) AS completed_count,

              SUM(
                CASE
                  WHEN UPPER(status) IN (
                    'PROCESSING',
                    'IN PROGRESS',
                    'RUNNING'
                  )
                  THEN 1 ELSE 0
                END
              ) AS processing_count,

              SUM(
                CASE
                  WHEN UPPER(status) IN (
                    'HOLD',
                    'ON HOLD'
                  )
                  THEN 1 ELSE 0
                END
              ) AS hold_count,

              SUM(
                CASE
                  WHEN UPPER(status) = 'REJECTED'
                  THEN 1 ELSE 0
                END
              ) AS rejected_count

            FROM time_tracking_task_items
            WHERE task_list_id = ?
            `,
            [taskList.id]
          );

          finalStats = trackingRows[0];

          const trackedTotal =
            Number(finalStats.total_count || 0);

          completedTasks +=
            Number(finalStats.completed_count || 0);

          processingTasks +=
            Number(finalStats.processing_count || 0);

          holdTasks +=
            Number(finalStats.hold_count || 0);

          rejectedTasks +=
            Number(finalStats.rejected_count || 0);

          // If no tracking rows created yet
          if (trackedTotal === 0) {
            notStartedTasks += Number(taskList.no_of_rows || 0);
          } else {
            notStartedTasks += Math.max(
              0,
              Number(taskList.no_of_rows || 0) - trackedTotal
            );
          }
        }

        // If task_list is not yet created
        if (totalTasks === 0) {
          totalTasks = 1;
          notStartedTasks = 1;
        }

        roleDetails.push({
          taskAssignmentId: assignment.id,

          clientName: assignment.client_name,
          deliverables: assignment.deliverables,

          role: mapping.role,
          employeeName: employeeName,
          task: assignedTask || assignment.deliverables || '—',

          totalTasks,
          completedTasks,
          processingTasks,
          holdTasks,
          rejectedTasks,
          notStartedTasks,

          deadline: assignment.deadline,
          maintenanceDate: assignment.maintenance_date,
        });
      }
    }

    return res.json({
      success: true,
      clientName,
      data: roleDetails,
    });

  } catch (err) {
    console.error(
      'GET /admin/employee-status/client/:clientName/details ERROR:',
      err
    );

    return res.status(500).json({
      success: false,
      message: err.message,
    });
  }
});

module.exports = router;