// routes/performance.js
const express = require('express');
const router = express.Router();
const db = require('../config/db');

// GET /api/performance/analytics
router.get('/analytics', async (req, res) => {
  try {

    // ===========================
    // Total Clients
    // ===========================
    const [clientRows] = await db.query(`
      SELECT COUNT(*) AS total_clients
      FROM clients
    `);

    const totalClients = Number(clientRows[0]?.total_clients || 0);

    // ===========================
    // Active Employees Count
    // ===========================
    const [employeeCountRows] = await db.query(`
      SELECT COUNT(DISTINCT employee_name) AS total_employees
      FROM task_list
      WHERE employee_name IS NOT NULL
        AND employee_name <> ''
    `);

    const activeEmployeesCount = Number(
      employeeCountRows[0]?.total_employees || 0
    );

    // ===========================
    // Top Performing Employees
    // ===========================
    const [employeeRows] = await db.query(`
      SELECT
          tl.employee_name,
          COUNT(tti.id) AS total_tasks,
          SUM(CASE WHEN tti.status='COMPLETED' THEN 1 ELSE 0 END) AS completed_count
      FROM task_list tl
      LEFT JOIN time_tracking_task_items tti
             ON tti.task_list_id = tl.id
      WHERE tl.employee_name IS NOT NULL
        AND tl.employee_name <> ''
      GROUP BY tl.employee_name
      ORDER BY completed_count DESC,total_tasks DESC
      LIMIT 10
    `);

    const topEmployees = employeeRows.map(emp => {

      const total = Number(emp.total_tasks || 0);

      const completed = Number(emp.completed_count || 0);

      const score =
          total > 0
              ? Math.round((completed / total) * 100)
              : 0;

      return {
        name: emp.employee_name,
        percent: score
      };
    });

    // ===========================
    // Productivity
    // ===========================
    const [reviewRows] = await db.query(`
      SELECT
        SUM(CASE WHEN manager_action='APPROVED' THEN 1 ELSE 0 END) approved,
        SUM(CASE WHEN manager_action='REWORK' THEN 1 ELSE 0 END) rework,
        SUM(CASE WHEN manager_action='REJECTED' THEN 1 ELSE 0 END) rejected,
        SUM(
            CASE
                WHEN manager_action='ACTION'
                  OR manager_action IS NULL
                THEN 1
                ELSE 0
            END
        ) review_pending
      FROM manager_review
    `);

    const prod = reviewRows[0] || {};

    const approved = Number(prod.approved || 0);
    const rework = Number(prod.rework || 0);
    const rejected = Number(prod.rejected || 0);
    const reviewPending = Number(prod.review_pending || 0);

    const totalReviews =
        approved +
        rework +
        rejected +
        reviewPending;

    const reviewTotal =
        totalReviews == 0 ? 1 : totalReviews;

    const productivity = {
      approved,
      rework,
      rejected,
      review: reviewPending,

      ratios: {
        approved: Number((approved / reviewTotal).toFixed(2)),
        rework: Number((rework / reviewTotal).toFixed(2)),
        rejected: Number((rejected / reviewTotal).toFixed(2)),
        review: Number((reviewPending / reviewTotal).toFixed(2))
      }
    };

    // ===========================
    // Task Status
    // ===========================
    const [statusRows] = await db.query(`
      SELECT

        SUM(
            CASE
                WHEN status='COMPLETED'
                THEN 1
                ELSE 0
            END
        ) completed,

        SUM(
            CASE
                WHEN status IN ('PENDING','PROCESSING','IN PROGRESS')
                THEN 1
                ELSE 0
            END
        ) pending,

        SUM(
            CASE
                WHEN status IN ('HOLD','ON HOLD')
                THEN 1
                ELSE 0
            END
        ) on_hold,

        COUNT(*) total_tasks

      FROM time_tracking_task_items
    `);

    const st = statusRows[0] || {};

    const completed = Number(st.completed || 0);
    const pending = Number(st.pending || 0);
    const hold = Number(st.on_hold || 0);

    const totalTasks =
        Number(st.total_tasks || 0) == 0
            ? 1
            : Number(st.total_tasks);

    const taskStatusDistribution = {

      completedPercent:
          Math.round((completed / totalTasks) * 100),

      pendingPercent:
          Math.round((pending / totalTasks) * 100),

      holdPercent:
          Math.round((hold / totalTasks) * 100)
    };

    // ===========================
    // Client Performance
    // ===========================
    const [clientPerfRows] = await db.query(`
      SELECT

        tl.client_name,

        COUNT(tti.id) total_items,

        SUM(
            CASE
                WHEN tti.status='COMPLETED'
                THEN 1
                ELSE 0
            END
        ) completed_items

      FROM task_list tl

      LEFT JOIN time_tracking_task_items tti
             ON tti.task_list_id = tl.id

      GROUP BY tl.client_name

      ORDER BY completed_items DESC

      LIMIT 5
    `);

    const clientPerformances =
        clientPerfRows.map(c => {

          const total =
              Number(c.total_items || 0);

          const completed =
              Number(c.completed_items || 0);

          const score =
              total > 0
                  ? Math.round((completed / total) * 100)
                  : 0;

          return {
            name: c.client_name || "Client",
            score
          };
        });

    // ===========================
// Revenue (Invoice Total)
// ===========================
const [revenueRows] = await db.query(`
    SELECT
        COALESCE(SUM(total_amount), 0) AS totalRevenue
    FROM invoices
`);

const estimatedRevenue =
    Number(revenueRows[0]?.totalRevenue || 0);

// ===========================
// Overall Efficiency
// ===========================
const efficiencyPercent =
    Math.round(
        (completed / totalTasks) * 100
    );

    // ===========================
    // Response
    // ===========================
    return res.json({

      success: true,

      data: {

        clientsCount: totalClients,

        employeesCount: activeEmployeesCount,

        efficiencyPercent,

        estimatedRevenue: estimatedRevenue,

        productivity,

        topEmployees,

        taskStatusDistribution,

        clientPerformances

      }

    });

  } catch (err) {

    console.error("Performance Analytics Error:", err);

    return res.status(500).json({
      success: false,
      message: err.message
    });

  }
});


// GET /api/performance/dashboard-analytics?range=week
router.get('/dashboard-analytics', async (req, res) => {
  try {

    const range = (req.query.range || "week").toLowerCase();

    let whereClause = "";

    switch (range) {
      case "today":
        whereClause = "WHERE DATE(mr.created_at) = CURDATE()";
        break;

      case "month":
        whereClause =
          "WHERE mr.created_at >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)";
        break;

      case "week":
      default:
        whereClause =
          "WHERE mr.created_at >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)";
        break;
    }

    // ==========================
    // Employee Performance
    // ==========================
    const [employeeRows] = await db.query(`
      SELECT
          tl.employee_name,

          SUM(CASE
                WHEN mr.manager_action='APPROVED'
                THEN 1 ELSE 0
              END) approved,

          SUM(CASE
                WHEN mr.manager_action='REWORK'
                THEN 1 ELSE 0
              END) rework,

          SUM(CASE
                WHEN mr.manager_action='REJECTED'
                THEN 1 ELSE 0
              END) rejected,

          SUM(CASE
                WHEN mr.manager_action='ACTION'
                  OR mr.manager_action IS NULL
                THEN 1 ELSE 0
              END) review

      FROM manager_review mr

      INNER JOIN task_list tl
          ON tl.id = mr.task_list_id

      ${whereClause}

      WHERE tl.employee_name IS NOT NULL
        AND tl.employee_name <> ''

      GROUP BY tl.employee_name

      ORDER BY approved DESC
    `);

    const employeePerformance = employeeRows.map(row => ({
      name: row.employee_name,
      approved: Number(row.approved || 0),
      rework: Number(row.rework || 0),
      review: Number(row.review || 0),
      rejected: Number(row.rejected || 0),
    }));


    // ==========================
    // Client Performance
    // ==========================
    const [clientRows] = await db.query(`
      SELECT
          tl.client_name,

          SUM(CASE
                WHEN mr.manager_action='APPROVED'
                THEN 1 ELSE 0
              END) approved,

          SUM(CASE
                WHEN mr.manager_action='REWORK'
                THEN 1 ELSE 0
              END) rework,

          SUM(CASE
                WHEN mr.manager_action='REJECTED'
                THEN 1 ELSE 0
              END) rejected,

          SUM(CASE
                WHEN mr.manager_action='ACTION'
                  OR mr.manager_action IS NULL
                THEN 1 ELSE 0
              END) review

      FROM manager_review mr

      INNER JOIN task_list tl
          ON tl.id = mr.task_list_id

      ${whereClause}

      GROUP BY tl.client_name

      ORDER BY approved DESC
    `);

    const clientPerformance = clientRows.map(row => ({
      name: row.client_name,
      approved: Number(row.approved || 0),
      rework: Number(row.rework || 0),
      review: Number(row.review || 0),
      rejected: Number(row.rejected || 0),
    }));


    return res.json({
      success: true,
      data: {
        employeePerformance,
        clientPerformance
      }
    });

  } catch (err) {

    console.error("Dashboard Analytics Error:", err);

    return res.status(500).json({
      success: false,
      message: err.message
    });

  }
});

module.exports = router;