// routes/performance.js — Employee Performance Dashboard API
//
// One employee at a time. Two modes:
//   mode=daily   -> ?employeeName=...&date=YYYY-MM-DD
//   mode=monthly -> ?employeeName=...&fromDate=YYYY-MM-DD&toDate=YYYY-MM-DD
//
// Pulls every task_list row for that employee (their assigned clients +
// deliverables), joined to its time_tracking_task_items row for the actual
// status/duration/performance, and to task_master/task_roles so each task
// can be grouped by role (Designer, Videographer, etc.) automatically —
// no manual role mapping needed on the frontend.
//
// Status vocabulary used throughout (matches tracking-items.js):
//   IDLE        -> "Pending"     (not started yet)
//   IN PROGRESS -> "Processing"
//   ON HOLD     -> "On Hold"
//   COMPLETED   -> "Completed"
//   REJECTED    -> "Rejected"

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

function toISODate(value) {
  // Accepts 'YYYY-MM-DD' or 'DD/MM/YYYY'; returns 'YYYY-MM-DD' or null.
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

    // ------------------------------------------------------------
    // Employee basic info (for the header card on the frontend)
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
    // Every task_list row for this employee in range, with its
    // tracking item (status/duration/performance) and role info.
    // A task_list row with no tracking item yet still counts as
    // an assigned task (treated as IDLE / Pending).
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

    // ------------------------------------------------------------
    // Aggregate: overall status counts, per-client, per-role,
    // and a daily trend line (for monthly mode).
    // ------------------------------------------------------------
    const summary = { totalTasks: rows.length, totalDurationSecs: 0, ...emptyStatusCounts() };
    const clientsMap = new Map();
    const rolesMap = new Map();
    const trendMap = new Map(); // date -> status counts

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

      // ---- by role ----
      const roleKey = row.role_name || 'General';
      if (!rolesMap.has(roleKey)) {
        rolesMap.set(roleKey, { roleName: roleKey, totalTasks: 0, ...emptyStatusCounts() });
      }
      const roleEntry = rolesMap.get(roleKey);
      roleEntry.totalTasks += 1;
      roleEntry[status] += 1;

      // ---- daily trend (always built; frontend only needs it for monthly) ----
      const dayKey = row.activity_date
        ? new Date(row.activity_date).toISOString().slice(0, 10)
        : fromDate;
      if (!trendMap.has(dayKey)) {
        trendMap.set(dayKey, { date: dayKey, ...emptyStatusCounts() });
      }
      trendMap.get(dayKey)[status] += 1;
    }

    const clients = Array.from(clientsMap.values()).sort((a, b) => b.totalTasks - a.totalTasks);
    const roles = Array.from(rolesMap.values()).sort((a, b) => b.totalTasks - a.totalTasks);
    const trend = Array.from(trendMap.values()).sort((a, b) => a.date.localeCompare(b.date));

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
        summary: {
          totalTasks: summary.totalTasks,
          totalDuration: formatDuration(summary.totalDurationSecs),
          completed: summary.COMPLETED,
          processing: summary['IN PROGRESS'],
          onHold: summary['ON HOLD'],
          pending: summary.IDLE,
          rejected: summary.REJECTED,
        },
        clients,
        roles,
        trend,
      },
    });
  } catch (err) {
    console.error('GET /performance ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;