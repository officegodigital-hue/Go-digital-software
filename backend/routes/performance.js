// routes/performance.js — Employee Performance Dashboard API
//
// One employee at a time. Two modes:
//   mode=daily   -> ?employeeName=...&date=YYYY-MM-DD
//   mode=monthly -> ?employeeName=...&fromDate=YYYY-MM-DD&toDate=YYYY-MM-DD
//
// What this returns, in plain terms:
//   - summary          -> task counts for the selected period (Completed/
//                         Processing/On Hold/Pending/Rejected) + total time
//   - clientsAssignedCount -> how many clients this employee has EVER been
//                         assigned (all-time, not limited to the period)
//   - dayPlanner        -> did they submit their Day Planner for the
//                         selected day, or (monthly) which days they missed
//   - taskTypes         -> tasks grouped by deliverable name (e.g. "Poster
//                         Design", "Reel Editing") so you can see exactly
//                         how many posters / videos / etc. were completed
//   - approvalStats     -> from manager_review: how many of their submitted
//                         tasks were Approved / Rejected / sent for Rework /
//                         still waiting on the manager
//   - performanceHistory -> the last 15 completed/rejected tasks (all-time),
//                         each tagged On Time / Delayed by comparing actual
//                         time taken to the expected time in Task Master,
//                         plus an "Archived" flag for anything older than 30 days
//   - clients            -> assigned clients ACTIVE in this period, each with
//                         their task list and per-task status
//   - trend              -> completed-tasks-per-day, for the monthly chart

const express = require('express');
const router = express.Router();
const db = require('../config/db');

const STATUS_LABELS = {
  IDLE: 'PENDING',
  'IN PROGRESS': 'PROCESSING',
  'ON HOLD': 'ON HOLD',
  COMPLETED: 'COMPLETED',
  REJECTED: 'REJECTED',
};

function normalizedStatus(raw) {
  const s = (raw || 'IDLE').toString().trim().toUpperCase();
  return STATUS_LABELS[s] ? s : 'IDLE';
}

function emptyStatusCounts() {
  return { IDLE: 0, 'IN PROGRESS': 0, 'ON HOLD': 0, COMPLETED: 0, REJECTED: 0 };
}

function formatDuration(seconds) {
  seconds = Number(seconds) || 0;
  const hrs = Math.floor(seconds / 3600);
  const mins = Math.floor((seconds % 3600) / 60);
  if (hrs > 0 && mins > 0) return `${hrs}h ${mins}m`;
  if (hrs > 0) return `${hrs}h`;
  return `${mins}m`;
}

// Best-effort parser for whatever format Task Master's "timing" field was
// typed in — "2 hrs", "45 mins", "1.5 hr", "90" (assumed minutes), etc.
function parseTimingToSeconds(timing) {
  if (!timing) return null;
  const str = timing.toString().trim().toLowerCase();

  const hrMatch = str.match(/([\d.]+)\s*h/);
  const minMatch = str.match(/([\d.]+)\s*m/);

  if (hrMatch || minMatch) {
    const hrs = hrMatch ? parseFloat(hrMatch[1]) : 0;
    const mins = minMatch ? parseFloat(minMatch[1]) : 0;
    return Math.round(hrs * 3600 + mins * 60);
  }

  const plainNumber = parseFloat(str);
  if (!isNaN(plainNumber)) {
    return Math.round(plainNumber * 60); // assume minutes
  }

  return null;
}

function toISODate(value) {
  if (!value) return null;
  const str = String(value).trim();

  if (/^\d{4}-\d{2}-\d{2}$/.test(str)) return str;

  const slashParts = str.split('/');
  if (slashParts.length === 3) {
    const [dd, mm, yyyy] = slashParts;
    if (dd && mm && yyyy) {
      return `${yyyy.padStart(4, '0')}-${mm.padStart(2, '0')}-${dd.padStart(2, '0')}`;
    }
  }
  return null;
}

function dateRangeArray(fromISO, toISO) {
  const dates = [];
  let cur = new Date(fromISO + 'T00:00:00');
  const end = new Date(toISO + 'T00:00:00');
  while (cur <= end) {
    dates.push(cur.toISOString().slice(0, 10));
    cur.setDate(cur.getDate() + 1);
  }
  return dates;
}

// GET /api/performance — main dashboard payload for one employee
router.get('/', async (req, res) => {
  try {
    const employeeName = (req.query.employeeName || '').trim();
    const mode = (req.query.mode || 'daily').trim().toLowerCase();

    if (!employeeName) {
      return res.status(400).json({ success: false, message: 'employeeName is required' });
    }
    if (!['daily', 'monthly'].includes(mode)) {
      return res.status(400).json({ success: false, message: 'mode must be daily or monthly' });
    }

    let fromDate, toDate;
    if (mode === 'daily') {
      fromDate = toDate = toISODate(req.query.date) || new Date().toISOString().slice(0, 10);
    } else {
      fromDate = toISODate(req.query.fromDate);
      toDate = toISODate(req.query.toDate);
      if (!fromDate || !toDate) {
        return res.status(400).json({ success: false, message: 'fromDate and toDate are required for monthly mode (YYYY-MM-DD)' });
      }
    }

    const todayISO = new Date().toISOString().slice(0, 10);

    // ------------------------------------------------------------
    // Employee basic info
    // ------------------------------------------------------------
    const [empRows] = await db.query(
      `SELECT id, full_name, initials, staff_id, role, user_type
       FROM employee_users
       WHERE TRIM(LOWER(full_name)) = TRIM(LOWER(?))
       LIMIT 1`,
      [employeeName]
    );
    const employee = empRows[0] || { full_name: employeeName };

    // ------------------------------------------------------------
    // How many clients this employee has EVER been assigned (all-time,
    // not limited to the selected period).
    // ------------------------------------------------------------
    const [clientCountRows] = await db.query(
      `SELECT COUNT(DISTINCT client_name) AS cnt
       FROM task_list
       WHERE TRIM(LOWER(employee_name)) = TRIM(LOWER(?))`,
      [employeeName]
    );
    const clientsAssignedCount = clientCountRows[0]?.cnt || 0;

    // ------------------------------------------------------------
    // Day Planner submission tracking
    // ------------------------------------------------------------
    let dayPlanner;
    if (mode === 'daily') {
      const [plannerRows] = await db.query(
        `SELECT report_type, is_submitted, submitted_at, status
         FROM day_plan_rows
         WHERE TRIM(LOWER(employee_name)) = TRIM(LOWER(?)) AND plan_date = ?
         ORDER BY report_type ASC`,
        [employeeName, fromDate]
      );
      const reports = plannerRows.map(r => ({
        reportType: r.report_type,
        submitted: !!r.is_submitted,
        submittedAt: r.submitted_at,
        status: r.status || '',
      }));
      dayPlanner = {
        mode: 'daily',
        date: fromDate,
        hasEntry: reports.length > 0,
        submitted: reports.some(r => r.submitted),
        reports,
      };
    } else {
      const [plannerRows] = await db.query(
        `SELECT plan_date, MAX(is_submitted) AS anySubmitted
         FROM day_plan_rows
         WHERE TRIM(LOWER(employee_name)) = TRIM(LOWER(?)) AND plan_date BETWEEN ? AND ?
         GROUP BY plan_date`,
        [employeeName, fromDate, toDate]
      );
      const submittedMap = new Map(
        plannerRows.map(r => [
          (r.plan_date instanceof Date ? r.plan_date.toISOString().slice(0, 10) : r.plan_date.toString()),
          !!r.anySubmitted,
        ])
      );

      const allDates = dateRangeArray(fromDate, toDate).filter(d => d <= todayISO);
      const days = allDates.map(d => ({ date: d, submitted: submittedMap.get(d) || false }));
      const submittedDays = days.filter(d => d.submitted).length;

      dayPlanner = {
        mode: 'monthly',
        totalDays: days.length,
        submittedDays,
        missedDays: days.length - submittedDays,
        days,
      };
    }

    // ------------------------------------------------------------
    // Every task_list row for this employee in range, with its
    // tracking item (status/duration/performance) and role/type info.
    // ------------------------------------------------------------
    const [rows] = await db.query(
      `
      SELECT
        tl.id            AS task_list_id,
        tl.client_name,
        tl.deliverables,
        tl.task_master_id,
        tm.role_key,
        COALESCE(tr.role_name, tm.role_key, 'General') AS role_name,
        tti.id           AS tracking_item_id,
        tti.status,
        tti.duration_secs,
        tti.performance,
        tti.task_description,
        COALESCE(tti.submit_date, tl.submission_date) AS activity_date
      FROM task_list tl
      LEFT JOIN task_master tm ON tm.id = tl.task_master_id
      LEFT JOIN task_roles tr ON tr.role_key = tm.role_key
      LEFT JOIN time_tracking_task_items tti ON tti.task_list_id = tl.id
      WHERE TRIM(LOWER(tl.employee_name)) = TRIM(LOWER(?))
        AND DATE(COALESCE(tti.submit_date, tl.submission_date)) BETWEEN ? AND ?
      ORDER BY activity_date DESC
      `,
      [employeeName, fromDate, toDate]
    );

    const summary = { totalTasks: rows.length, totalDurationSecs: 0, ...emptyStatusCounts() };
    const clientsMap = new Map();
    const taskTypesMap = new Map(); // by deliverable name — "how many posters, how many videos"
    const trendMap = new Map();

    for (const row of rows) {
      const status = normalizedStatus(row.status);
      const durationSecs = Number(row.duration_secs) || 0;

      summary[status] += 1;
      summary.totalDurationSecs += durationSecs;

      // ---- by client ----
      const clientKey = row.client_name || 'Unassigned';
      if (!clientsMap.has(clientKey)) {
        clientsMap.set(clientKey, { clientName: clientKey, totalTasks: 0, totalDurationSecs: 0, ...emptyStatusCounts(), tasks: [] });
      }
      const clientEntry = clientsMap.get(clientKey);
      clientEntry.totalTasks += 1;
      clientEntry.totalDurationSecs += durationSecs;
      clientEntry[status] += 1;
      clientEntry.tasks.push({
        taskListId: row.task_list_id,
        trackingItemId: row.tracking_item_id,
        deliverable: row.deliverables,
        roleName: row.role_name,
        status,
        statusLabel: STATUS_LABELS[status],
        durationSecs,
        duration: formatDuration(durationSecs),
        performance: row.performance || 'N/A',
        activityDate: row.activity_date,
      });

      // ---- by task type (deliverable name) ----
      const typeKey = row.deliverables || 'Other';
      if (!taskTypesMap.has(typeKey)) {
        taskTypesMap.set(typeKey, { deliverable: typeKey, roleName: row.role_name, totalTasks: 0, ...emptyStatusCounts() });
      }
      const typeEntry = taskTypesMap.get(typeKey);
      typeEntry.totalTasks += 1;
      typeEntry[status] += 1;

      // ---- daily trend ----
      const dayKey = row.activity_date ? new Date(row.activity_date).toISOString().slice(0, 10) : fromDate;
      if (!trendMap.has(dayKey)) {
        trendMap.set(dayKey, { date: dayKey, ...emptyStatusCounts() });
      }
      trendMap.get(dayKey)[status] += 1;
    }

    const clients = Array.from(clientsMap.values()).sort((a, b) => b.totalTasks - a.totalTasks);
    const taskTypes = Array.from(taskTypesMap.values()).sort((a, b) => b.totalTasks - a.totalTasks);
    const trend = Array.from(trendMap.values()).sort((a, b) => a.date.localeCompare(b.date));

    // ------------------------------------------------------------
    // Approval productivity — sourced from manager_review, for tasks
    // submitted (COMPLETED) inside the selected period.
    // ------------------------------------------------------------
    const [reviewRows] = await db.query(
      `
      SELECT COALESCE(mr.manager_action, 'ACTION') AS manager_action, COUNT(*) AS cnt
      FROM time_tracking_task_items tti
      JOIN task_list tl ON tl.id = tti.task_list_id
      LEFT JOIN manager_review mr ON mr.tracking_item_id = tti.id
      WHERE TRIM(LOWER(tl.employee_name)) = TRIM(LOWER(?))
        AND tti.status = 'COMPLETED'
        AND DATE(tti.submit_date) BETWEEN ? AND ?
      GROUP BY COALESCE(mr.manager_action, 'ACTION')
      `,
      [employeeName, fromDate, toDate]
    );
    const approvalStats = { approved: 0, rejected: 0, rework: 0, pendingReview: 0, totalReviewed: 0 };
    for (const r of reviewRows) {
      const action = (r.manager_action || 'ACTION').toUpperCase();
      const count = Number(r.cnt) || 0;
      approvalStats.totalReviewed += count;
      if (action === 'APPROVED') approvalStats.approved = count;
      else if (action === 'REJECTED') approvalStats.rejected = count;
      else if (action === 'REWORK') approvalStats.rework = count;
      else approvalStats.pendingReview = count;
    }

    // ------------------------------------------------------------
    // Performance history — last 15 completed/rejected tasks, ALL-TIME
    // (not limited to the selected period), tagged On Time / Delayed by
    // comparing actual duration to the expected Task Master timing, plus
    // an Archived flag for anything older than 30 days.
    // ------------------------------------------------------------
    const [historyRows] = await db.query(
      `
      SELECT
        tl.client_name, tl.deliverables,
        tti.status, tti.duration_secs, tti.performance, tti.submit_date,
        tt.timing AS expected_timing
      FROM task_list tl
      JOIN time_tracking_task_items tti ON tti.task_list_id = tl.id
      LEFT JOIN task_timings tt ON tt.task_master_id = tl.task_master_id
      WHERE TRIM(LOWER(tl.employee_name)) = TRIM(LOWER(?))
        AND tti.status IN ('COMPLETED', 'REJECTED')
      ORDER BY tti.submit_date DESC
      LIMIT 15
      `,
      [employeeName]
    );

    const now = new Date();
    const performanceHistory = historyRows.map(r => {
      const expectedSecs = parseTimingToSeconds(r.expected_timing);
      const actualSecs = Number(r.duration_secs) || 0;
      let timeliness = 'N/A';
      if (expectedSecs !== null && actualSecs > 0) {
        timeliness = actualSecs <= expectedSecs ? 'ON TIME' : 'DELAYED';
      }

      const submitDate = r.submit_date ? new Date(r.submit_date) : null;
      const ageDays = submitDate ? Math.floor((now - submitDate) / (1000 * 60 * 60 * 24)) : null;

      return {
        date: r.submit_date,
        client: r.client_name,
        deliverable: r.deliverables,
        status: r.status,
        duration: formatDuration(actualSecs),
        performance: r.performance || 'N/A',
        timeliness,
        archived: ageDays !== null && ageDays > 30,
      };
    });

    return res.json({
      success: true,
      data: {
        employee: {
          id: employee.id || null,
          fullName: employee.full_name || employeeName,
          initials: employee.initials || '',
          staffId: employee.staff_id || '',
          role: employee.role || '',
        },
        range: { mode, fromDate, toDate },
        clientsAssignedCount,
        dayPlanner,
        summary: {
          totalTasks: summary.totalTasks,
          totalDuration: formatDuration(summary.totalDurationSecs),
          completed: summary.COMPLETED,
          processing: summary['IN PROGRESS'],
          onHold: summary['ON HOLD'],
          pending: summary.IDLE,
          rejected: summary.REJECTED,
        },
        taskTypes,
        approvalStats,
        performanceHistory,
        clients,
        trend,
      },
    });
  } catch (err) {
    console.error('GET /performance ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;