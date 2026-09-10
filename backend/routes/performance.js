// routes/performance.js — Employee Performance & Productivity Dashboard API
//
// Two endpoints:
//
//   GET /api/performance/overview  -> lightweight performance summary for
//                                      EVERY employee at once (for the grid
//                                      of cards on first load — no manual
//                                      search needed before anything shows).
//
//   GET /api/performance/detail    -> full A-to-Z dashboard for ONE employee
//                                      (KPIs, working hours, task/role
//                                      breakdown, client tracking, Day
//                                      Planner consistency, manager review
//                                      productivity, timeline, trend).
//
// Both accept the same range params:
//   mode=daily   & date=YYYY-MM-DD
//   mode=monthly & fromDate=YYYY-MM-DD & toDate=YYYY-MM-DD
//
// Nothing here is invented/dummy — everything is derived from tables that
// already exist and are already written to by tracking-items.js,
// day-planner.js and manager-review.js:
//   task_list, time_tracking_task_items, task_master, task_roles,
//   day_plan_rows, manager_review, employee_users.

const express = require('express');
const router = express.Router();
const db = require('../config/db');

// ────────────────────────────────────────────────────────────────
// Shared helpers
// ────────────────────────────────────────────────────────────────
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

function pct(numerator, denominator) {
  if (!denominator) return 0;
  return Math.round((numerator / denominator) * 1000) / 10; // one decimal place
}

function formatHours(seconds) {
  seconds = Number(seconds) || 0;
  const hrs = Math.floor(seconds / 3600);
  const mins = Math.floor((seconds % 3600) / 60);
  if (hrs > 0 && mins > 0) return `${hrs}h ${mins}m`;
  if (hrs > 0) return `${hrs}h`;
  return `${mins}m`;
}

function toISODate(value) {
  if (!value) return null;
  const str = String(value).trim();
  if (/^\d{4}-\d{2}-\d{2}$/.test(str)) return str;
  const slashParts = str.split('/');
  if (slashParts.length === 3) {
    const [dd, mm, yyyy] = slashParts;
    if (dd && mm && yyyy) return `${yyyy.padStart(4, '0')}-${mm.padStart(2, '0')}-${dd.padStart(2, '0')}`;
  }
  return null;
}

function resolveRange(query) {
  const mode = (query.mode || 'daily').trim().toLowerCase();
  if (mode === 'daily') {
    const date = toISODate(query.date) || new Date().toISOString().slice(0, 10);
    return { mode, fromDate: date, toDate: date };
  }
  const fromDate = toISODate(query.fromDate);
  const toDate = toISODate(query.toDate);
  return { mode: 'monthly', fromDate, toDate };
}

function daysBetweenInclusive(fromDate, toDate) {
  const from = new Date(fromDate);
  const to = new Date(toDate);
  const diff = Math.round((to - from) / (1000 * 60 * 60 * 24)) + 1;
  return Math.max(1, diff);
}

// A single weighted formula used EVERYWHERE performance % is shown, so the
// number on the overview grid matches the number in the detail page.
//   40% task completion rate
//   25% manager-approval rate (of reviewed tasks)
//   20% Day Planner submission consistency
//   15% productivity (completed-task time vs total tracked time)
function calculatePerformanceScore({ totalTasks, completed, approved, rework, rejectedReview, plannerSubmittedDays, expectedDays, productiveSecs, totalTrackedSecs }) {
  const completionRate = totalTasks > 0 ? completed / totalTasks : 0;

  const reviewedTotal = approved + rework + rejectedReview;
  const approvalRate = reviewedTotal > 0 ? approved / reviewedTotal : (totalTasks > 0 ? 0.5 : 0); // neutral if nothing reviewed yet

  const plannerRate = expectedDays > 0 ? Math.min(1, plannerSubmittedDays / expectedDays) : 0;

  const productivityRate = totalTrackedSecs > 0 ? Math.min(1, productiveSecs / totalTrackedSecs) : (totalTasks > 0 ? 0.5 : 0);

  const score = (completionRate * 40) + (approvalRate * 25) + (plannerRate * 20) + (productivityRate * 15);
  return Math.max(0, Math.min(100, Math.round(score)));
}

function performanceGrade(score) {
  if (score >= 85) return 'Excellent';
  if (score >= 70) return 'Good';
  if (score >= 50) return 'Average';
  return 'Needs Improvement';
}

// ════════════════════════════════════════════════════════════════
// GET /api/performance/overview — ALL employees at once
// ════════════════════════════════════════════════════════════════
router.get('/overview', async (req, res) => {
  try {
    const { mode, fromDate, toDate } = resolveRange(req.query);
    if (!fromDate || !toDate) {
      return res.status(400).json({ success: false, message: 'Invalid or missing date range' });
    }
    const expectedDays = daysBetweenInclusive(fromDate, toDate);

    // 1) All active employees
    const [employees] = await db.query(
      `SELECT id, full_name, initials, staff_id, role, user_type
       FROM employee_users
       WHERE is_active = 1
       ORDER BY full_name ASC`
    );

    // 2) Task + tracking aggregation per employee, in range (one query, no N+1)
    const [taskRows] = await db.query(
      `
      SELECT
        tl.employee_name,
        tl.client_name,
        tti.status,
        tti.duration_secs,
        tti.start_time,
        tti.complete_time
      FROM task_list tl
      LEFT JOIN time_tracking_task_items tti ON tti.task_list_id = tl.id
      WHERE DATE(COALESCE(tti.submit_date, tl.submission_date)) BETWEEN ? AND ?
      `,
      [fromDate, toDate]
    );

    // 3) Day planner submissions per employee, in range
    const [plannerRows] = await db.query(
      `SELECT employee_name, plan_date, report_type, is_submitted, total_working_secs
       FROM day_plan_rows
       WHERE plan_date BETWEEN ? AND ?`,
      [fromDate, toDate]
    );

    // 4) Manager review decisions per employee, in range (via tracking item -> task_list)
    const [reviewRows] = await db.query(
      `
      SELECT tl.employee_name, mr.manager_action
      FROM manager_review mr
      JOIN time_tracking_task_items tti ON tti.id = mr.tracking_item_id
      JOIN task_list tl ON tl.id = tti.task_list_id
      WHERE DATE(mr.reviewed_at) BETWEEN ? AND ?
      `,
      [fromDate, toDate]
    );

    // ---- fold into per-employee accumulators ----
    const byEmployee = new Map();
    const ensure = (name) => {
      if (!byEmployee.has(name)) {
        byEmployee.set(name, {
          clients: new Set(),
          totalTasks: 0,
          totalTrackedSecs: 0,
          productiveSecs: 0,
          ...emptyStatusCounts(),
          plannerDaySet: new Set(),
          approved: 0,
          rework: 0,
          rejectedReview: 0,
          pendingReview: 0,
        });
      }
      return byEmployee.get(name);
    };

    for (const row of taskRows) {
      const name = row.employee_name;
      if (!name) continue;
      const acc = ensure(name);
      const status = normalizedStatus(row.status);
      const secs = Number(row.duration_secs) || 0;

      acc.totalTasks += 1;
      acc[status] += 1;
      acc.totalTrackedSecs += secs;
      if (status === 'COMPLETED') acc.productiveSecs += secs;
      if (row.client_name) acc.clients.add(row.client_name);
    }

    for (const row of plannerRows) {
      if (!row.employee_name || !row.is_submitted) continue;
      ensure(row.employee_name).plannerDaySet.add(row.plan_date.toString());
    }

    for (const row of reviewRows) {
      if (!row.employee_name) continue;
      const acc = ensure(row.employee_name);
      const action = (row.manager_action || 'ACTION').toUpperCase();
      if (action === 'APPROVED') acc.approved += 1;
      else if (action === 'REWORK') acc.rework += 1;
      else if (action === 'REJECTED') acc.rejectedReview += 1;
      else acc.pendingReview += 1;
    }

    // ---- build response per employee ----
    const data = employees.map((emp) => {
      const acc = byEmployee.get(emp.full_name) || ensure(emp.full_name);

      const performancePct = calculatePerformanceScore({
        totalTasks: acc.totalTasks,
        completed: acc.COMPLETED,
        approved: acc.approved,
        rework: acc.rework,
        rejectedReview: acc.rejectedReview,
        plannerSubmittedDays: acc.plannerDaySet.size,
        expectedDays,
        productiveSecs: acc.productiveSecs,
        totalTrackedSecs: acc.totalTrackedSecs,
      });

      return {
        id: emp.id,
        fullName: emp.full_name,
        initials: emp.initials || '',
        staffId: emp.staff_id || '',
        role: emp.role || '',
        totalClients: acc.clients.size,
        totalTasks: acc.totalTasks,
        completed: acc.COMPLETED,
        processing: acc['IN PROGRESS'],
        onHold: acc['ON HOLD'],
        pending: acc.IDLE,
        rejected: acc.REJECTED,
        completedPct: pct(acc.COMPLETED, acc.totalTasks),
        pendingPct: pct(acc.IDLE, acc.totalTasks),
        processingPct: pct(acc['IN PROGRESS'], acc.totalTasks),
        rejectedPct: pct(acc.REJECTED, acc.totalTasks),
        workingHours: formatHours(acc.totalTrackedSecs),
        workingSecs: acc.totalTrackedSecs,
        productivityPct: pct(acc.productiveSecs, acc.totalTrackedSecs || acc.productiveSecs),
        plannerSubmittedDays: acc.plannerDaySet.size,
        expectedDays,
        performancePct,
        performanceGrade: performanceGrade(performancePct),
      };
    });

    return res.json({ success: true, data: { range: { mode, fromDate, toDate }, employees: data } });
  } catch (err) {
    console.error('GET /performance/overview ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ════════════════════════════════════════════════════════════════
// GET /api/performance/detail — full A-to-Z dashboard for ONE employee
// ════════════════════════════════════════════════════════════════
router.get('/detail', async (req, res) => {
  try {
    const employeeName = (req.query.employeeName || '').trim();
    if (!employeeName) {
      return res.status(400).json({ success: false, message: 'employeeName is required' });
    }
    const { mode, fromDate, toDate } = resolveRange(req.query);
    if (!fromDate || !toDate) {
      return res.status(400).json({ success: false, message: 'Invalid or missing date range' });
    }
    const expectedDays = daysBetweenInclusive(fromDate, toDate);

    // ---- employee basic info ----
    const [empRows] = await db.query(
      `SELECT id, full_name, initials, staff_id, role, user_type
       FROM employee_users
       WHERE TRIM(LOWER(full_name)) = TRIM(LOWER(?))
       LIMIT 1`,
      [employeeName]
    );
    const employee = empRows[0] || { full_name: employeeName };

    // ---- every task_list row for this employee in range, with role + tracking + review ----
    const [rows] = await db.query(
      `
      SELECT
        tl.id            AS task_list_id,
        tl.client_name,
        tl.deliverables,
        tm.role_key,
        COALESCE(tr.role_name, tm.role_key, 'General') AS role_name,
        tti.id           AS tracking_item_id,
        tti.status,
        tti.duration_secs,
        tti.performance,
        tti.start_time,
        tti.complete_time,
        tti.reject_time,
        COALESCE(tti.submit_date, tl.submission_date) AS activity_date,
        mr.manager_action,
        mr.manager_comment,
        mr.reviewed_at
      FROM task_list tl
      LEFT JOIN task_master tm ON tm.id = tl.task_master_id
      LEFT JOIN task_roles tr ON tr.role_key = tm.role_key
      LEFT JOIN time_tracking_task_items tti ON tti.task_list_id = tl.id
      LEFT JOIN manager_review mr ON mr.tracking_item_id = tti.id
      WHERE TRIM(LOWER(tl.employee_name)) = TRIM(LOWER(?))
        AND DATE(COALESCE(tti.submit_date, tl.submission_date)) BETWEEN ? AND ?
      ORDER BY activity_date DESC
      `,
      [employeeName, fromDate, toDate]
    );

    // ---- day planner rows for this employee in range ----
    const [plannerRows] = await db.query(
      `SELECT plan_date, report_type, is_submitted, submitted_at, total_working_secs
       FROM day_plan_rows
       WHERE TRIM(LOWER(employee_name)) = TRIM(LOWER(?))
         AND plan_date BETWEEN ? AND ?
       ORDER BY plan_date ASC`,
      [employeeName, fromDate, toDate]
    );

    // ============================================================
    // Aggregate: summary, clients, roles, trend, timeline, planner
    // ============================================================
    const summaryCounts = { totalTasks: rows.length, totalTrackedSecs: 0, productiveSecs: 0, ...emptyStatusCounts() };
    const clientsMap = new Map();
    const rolesMap = new Map();
    const trendMap = new Map(); // date -> { COMPLETED, IN PROGRESS, ON HOLD, IDLE, REJECTED }
    const timeline = [];
    const review = { approved: 0, rework: 0, rejected: 0, pending: 0 };
    let idleSecsFromHold = 0;

    for (const row of rows) {
      const status = normalizedStatus(row.status);
      const secs = Number(row.duration_secs) || 0;

      summaryCounts[status] += 1;
      summaryCounts.totalTrackedSecs += secs;
      if (status === 'COMPLETED') summaryCounts.productiveSecs += secs;

      // idle/hold time = elapsed wall-clock time minus actual worked seconds
      if (row.start_time && (row.complete_time || row.reject_time)) {
        const end = new Date(row.complete_time || row.reject_time);
        const start = new Date(row.start_time);
        const elapsed = Math.max(0, Math.floor((end - start) / 1000));
        idleSecsFromHold += Math.max(0, elapsed - secs);
      }

      // ---- clients ----
      const clientKey = row.client_name || 'Unassigned';
      if (!clientsMap.has(clientKey)) {
        clientsMap.set(clientKey, { clientName: clientKey, totalTasks: 0, totalDurationSecs: 0, ...emptyStatusCounts(), lastActivity: null, tasks: [] });
      }
      const clientEntry = clientsMap.get(clientKey);
      clientEntry.totalTasks += 1;
      clientEntry.totalDurationSecs += secs;
      clientEntry[status] += 1;
      if (!clientEntry.lastActivity || (row.activity_date && new Date(row.activity_date) > new Date(clientEntry.lastActivity))) {
        clientEntry.lastActivity = row.activity_date;
      }

      const reviewStatus = row.manager_action && row.manager_action !== 'ACTION' ? row.manager_action : (row.tracking_item_id ? 'PENDING REVIEW' : '—');

      clientEntry.tasks.push({
        taskListId: row.task_list_id,
        trackingItemId: row.tracking_item_id,
        deliverable: row.deliverables,
        roleName: row.role_name,
        status,
        statusLabel: STATUS_LABELS[status],
        durationSecs: secs,
        duration: formatHours(secs),
        performance: row.performance || 'N/A',
        startTime: row.start_time,
        completedTime: row.complete_time,
        activityDate: row.activity_date,
        reviewStatus,
        reviewComment: row.manager_comment || '',
      });

      // ---- roles ----
      const roleKey = row.role_name || 'General';
      if (!rolesMap.has(roleKey)) rolesMap.set(roleKey, { roleName: roleKey, totalTasks: 0, ...emptyStatusCounts() });
      const roleEntry = rolesMap.get(roleKey);
      roleEntry.totalTasks += 1;
      roleEntry[status] += 1;

      // ---- trend ----
      const dayKey = row.activity_date ? new Date(row.activity_date).toISOString().slice(0, 10) : fromDate;
      if (!trendMap.has(dayKey)) trendMap.set(dayKey, { date: dayKey, ...emptyStatusCounts() });
      trendMap.get(dayKey)[status] += 1;

      // ---- manager review counts ----
      if (row.tracking_item_id) {
        const action = (row.manager_action || 'ACTION').toUpperCase();
        if (action === 'APPROVED') review.approved += 1;
        else if (action === 'REWORK') review.rework += 1;
        else if (action === 'REJECTED') review.rejected += 1;
        else review.pending += 1;
      }

      // ---- timeline events ----
      if (row.start_time) timeline.push({ date: row.start_time, type: 'TASK_STARTED', label: `Started "${row.deliverables}" (${row.client_name})` });
      if (row.complete_time) timeline.push({ date: row.complete_time, type: 'TASK_COMPLETED', label: `Completed "${row.deliverables}" (${row.client_name})` });
      if (row.reject_time) timeline.push({ date: row.reject_time, type: 'TASK_REJECTED', label: `Rejected "${row.deliverables}" (${row.client_name})` });
      if (row.reviewed_at && row.manager_action && row.manager_action !== 'ACTION') {
        timeline.push({ date: row.reviewed_at, type: `MANAGER_${row.manager_action}`, label: `Manager ${row.manager_action.toLowerCase()} "${row.deliverables}"` });
      }
    }

    // ---- day planner performance ----
    const plannerByDate = new Map();
    for (const p of plannerRows) {
      const dateKey = p.plan_date.toString();
      if (!plannerByDate.has(dateKey)) plannerByDate.set(dateKey, { date: dateKey, morningSubmitted: false, eveningSubmitted: false, workingSecs: 0 });
      const entry = plannerByDate.get(dateKey);
      if (p.report_type === 'Morning' && p.is_submitted) entry.morningSubmitted = true;
      if (p.report_type === 'Evening' && p.is_submitted) entry.eveningSubmitted = true;
      entry.workingSecs = Math.max(entry.workingSecs, Number(p.total_working_secs) || 0);
      if (p.is_submitted && p.submitted_at) {
        timeline.push({
          date: p.submitted_at,
          type: 'PLANNER_SUBMITTED',
          label: `Submitted ${p.report_type} Day Planner`,
        });
      }
    }
    const plannerDays = Array.from(plannerByDate.values()).sort((a, b) => a.date.localeCompare(b.date));
    const plannerSubmittedDays = plannerDays.filter((d) => d.morningSubmitted || d.eveningSubmitted).length;
    const morningSubmittedCount = plannerDays.filter((d) => d.morningSubmitted).length;
    const eveningSubmittedCount = plannerDays.filter((d) => d.eveningSubmitted).length;

    // ---- performance score ----
    const performancePct = calculatePerformanceScore({
      totalTasks: summaryCounts.totalTasks,
      completed: summaryCounts.COMPLETED,
      approved: review.approved,
      rework: review.rework,
      rejectedReview: review.rejected,
      plannerSubmittedDays,
      expectedDays,
      productiveSecs: summaryCounts.productiveSecs,
      totalTrackedSecs: summaryCounts.totalTrackedSecs,
    });

    // ---- performance trend (per day in range, using each day's own mini-score) ----
    const trend = Array.from(trendMap.values())
      .sort((a, b) => a.date.localeCompare(b.date))
      .map((day) => {
        const dayTotal = day.IDLE + day['IN PROGRESS'] + day['ON HOLD'] + day.COMPLETED + day.REJECTED;
        return {
          date: day.date,
          completed: day.COMPLETED,
          processing: day['IN PROGRESS'],
          onHold: day['ON HOLD'],
          pending: day.IDLE,
          rejected: day.REJECTED,
          dayPerformancePct: pct(day.COMPLETED, dayTotal),
        };
      });

    timeline.sort((a, b) => new Date(b.date) - new Date(a.date));

    const clients = Array.from(clientsMap.values())
      .map((c) => ({ ...c, completionPct: pct(c.COMPLETED, c.totalTasks), totalDuration: formatHours(c.totalDurationSecs) }))
      .sort((a, b) => b.totalTasks - a.totalTasks);

    const roles = Array.from(rolesMap.values()).sort((a, b) => b.totalTasks - a.totalTasks);

    const reviewedTotal = review.approved + review.rework + review.rejected;

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
        range: { mode, fromDate, toDate, expectedDays },
        performance: { score: performancePct, grade: performanceGrade(performancePct) },
        summary: {
          totalClients: clientsMap.size,
          totalTasks: summaryCounts.totalTasks,
          completed: summaryCounts.COMPLETED,
          processing: summaryCounts['IN PROGRESS'],
          onHold: summaryCounts['ON HOLD'],
          pending: summaryCounts.IDLE,
          rejected: summaryCounts.REJECTED,
          completedPct: pct(summaryCounts.COMPLETED, summaryCounts.totalTasks),
          processingPct: pct(summaryCounts['IN PROGRESS'], summaryCounts.totalTasks),
          onHoldPct: pct(summaryCounts['ON HOLD'], summaryCounts.totalTasks),
          pendingPct: pct(summaryCounts.IDLE, summaryCounts.totalTasks),
          rejectedPct: pct(summaryCounts.REJECTED, summaryCounts.totalTasks),
        },
        workingHours: {
          totalSecs: summaryCounts.totalTrackedSecs,
          total: formatHours(summaryCounts.totalTrackedSecs),
          productiveSecs: summaryCounts.productiveSecs,
          productive: formatHours(summaryCounts.productiveSecs),
          idleSecs: idleSecsFromHold,
          idle: formatHours(idleSecsFromHold),
          avgDailySecs: Math.round(summaryCounts.totalTrackedSecs / expectedDays),
          avgDaily: formatHours(Math.round(summaryCounts.totalTrackedSecs / expectedDays)),
          avgTaskSecs: summaryCounts.totalTasks > 0 ? Math.round(summaryCounts.totalTrackedSecs / summaryCounts.totalTasks) : 0,
          avgTask: formatHours(summaryCounts.totalTasks > 0 ? Math.round(summaryCounts.totalTrackedSecs / summaryCounts.totalTasks) : 0),
          productivityPct: pct(summaryCounts.productiveSecs, summaryCounts.totalTrackedSecs || summaryCounts.productiveSecs),
        },
        managerReview: {
          approved: review.approved,
          rework: review.rework,
          rejected: review.rejected,
          pendingReview: review.pending,
          approvalRatePct: pct(review.approved, reviewedTotal),
        },
        dayPlanner: {
          expectedDays,
          submittedDays: plannerSubmittedDays,
          missedDays: Math.max(0, expectedDays - plannerSubmittedDays),
          consistencyPct: pct(plannerSubmittedDays, expectedDays),
          morningSubmittedCount,
          eveningSubmittedCount,
          days: plannerDays,
        },
        roles,
        clients,
        trend,
        timeline: timeline.slice(0, 100),
      },
    });
  } catch (err) {
    console.error('GET /performance/detail ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;