const db = require('../config/db');
const policy = require('../lib/attendancePolicy');
const { effectiveOverrides } = require('../lib/calendarOverrides');

function ok(res, data, message) {
  return res.json({ success: true, message: message || 'OK', data: data });
}

function fail(res, status, message) {
  return res.status(status).json({ success: false, message: message });
}

function requireAdmin(req, res, next) {
  const userType = String((req.user && req.user.userType) || '').toLowerCase();
  if (userType !== 'admin') {
    return fail(res, 403, 'Admin access required');
  }
  return next();
}

const MONTHS = ['January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'];

const DEFAULT_POLICY = { weeklyOffDays: [0], deductExplicitAbsence: true, missingAttendanceIsAbsent: false };

async function ensurePolicyTable() {
  await db.query(`CREATE TABLE IF NOT EXISTS hrms_payroll_policy (
    id TINYINT UNSIGNED NOT NULL PRIMARY KEY,
    weekly_off_days JSON NOT NULL,
    deduct_explicit_absence TINYINT(1) NOT NULL DEFAULT 1,
    missing_attendance_is_absent TINYINT(1) NOT NULL DEFAULT 0,
    updated_by BIGINT UNSIGNED NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  )`);
  try { await db.query('ALTER TABLE hrms_payroll_policy ADD COLUMN updated_by BIGINT UNSIGNED NULL'); } catch (_) {}
  try { await db.query('ALTER TABLE hrms_payroll_policy ADD COLUMN updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP'); } catch (_) {}
  await db.query(`INSERT IGNORE INTO hrms_payroll_policy (id, weekly_off_days, deduct_explicit_absence, missing_attendance_is_absent) VALUES (1, '[0]', 1, 0)`);
}

async function payrollPolicy() {
  await ensurePolicyTable();
  const [rows] = await db.query('SELECT * FROM hrms_payroll_policy WHERE id = 1');
  const row = rows[0] || {};
  let weeklyOffDays = DEFAULT_POLICY.weeklyOffDays;
  try { weeklyOffDays = JSON.parse(row.weekly_off_days || '[0]'); } catch (_) {}
  return {
    weeklyOffDays: Array.isArray(weeklyOffDays) ? weeklyOffDays.map(Number).filter((day) => day >= 0 && day <= 6) : [0],
    deductExplicitAbsence: Boolean(Number(row.deduct_explicit_absence ?? 1)),
    missingAttendanceIsAbsent: Boolean(Number(row.missing_attendance_is_absent ?? 0)),
  };
}

function formatSalary(value) {
  if (value === null || value === undefined || value === '') return 'Not Set';
  const amount = Number(value);
  if (!Number.isFinite(amount)) return 'Not Set';
  return '₹' + amount.toLocaleString('en-IN', {
    minimumFractionDigits: Number.isInteger(amount) ? 0 : 2,
    maximumFractionDigits: 2,
  });
}

function pad(value) {
  return String(value).padStart(2, '0');
}

function ymd(year, month, day) {
  return year + '-' + pad(month) + '-' + pad(day);
}

function utcWeekday(year, month, day) {
  return new Date(Date.UTC(year, month - 1, day)).getUTCDay();
}

function daysInMonth(year, month) {
  return new Date(Date.UTC(year, month, 0)).getUTCDate();
}

function isoDate(value) {
  if (!value) return '';
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return value.toISOString().slice(0, 10);
  }
  const match = String(value).match(/(\d{4}-\d{2}-\d{2})/);
  return match ? match[1] : '';
}

function nextDate(dateStr) {
  if (!dateStr) return '';
  const d = new Date(dateStr + 'T00:00:00Z');
  d.setUTCDate(d.getUTCDate() + 1);
  return d.toISOString().slice(0, 10);
}

function parseMonth(req) {
  const today = policy.todayIstDate();
  const [ty, tm] = today.split('-').map(Number);
  const body = req.body || {};
  const year = Number(req.query.year || body.year || ty);
  const month = Number(req.query.month || body.month || tm);
  if (!year || month < 1 || month > 12) {
    return { error: 'year and month (1-12) are required' };
  }
  return { year: year, month: month, today: today };
}

// Returns { start: 'YYYY-MM-DD', end: 'YYYY-MM-DD' } for the pay period that
// covers the given calendar month, based on the employee's salary cycle.
// Standard: 1st → last day of the month.
// Flexible (e.g. startDay=26, endDay=25): for payroll month M, period is
//   (M-1)/startDay → M/endDay  (e.g. Jan payroll = Dec 26 → Jan 25).
function cycleRange(year, month, salaryType, startDay, endDay) {
  if (salaryType !== 'flexible' || !startDay || !endDay) {
    return { start: ymd(year, month, 1), end: ymd(year, month, daysInMonth(year, month)) };
  }
  const sd = Number(startDay);
  const ed = Number(endDay);
  // The cycle that *ends* in this calendar month
  let prevYear = year;
  let prevMonth = month - 1;
  if (prevMonth < 1) { prevMonth = 12; prevYear -= 1; }
  const maxPrev = daysInMonth(prevYear, prevMonth);
  const maxCurr = daysInMonth(year, month);
  const actualStart = ymd(prevYear, prevMonth, Math.min(sd, maxPrev));
  const actualEnd = ymd(year, month, Math.min(ed, maxCurr));
  return { start: actualStart, end: actualEnd };
}

async function ensurePayrollItemColumns() {
  try { await db.query("ALTER TABLE hrms_payroll_items ADD COLUMN period_start DATE NULL"); } catch (_) {}
  try { await db.query("ALTER TABLE hrms_payroll_items ADD COLUMN period_end DATE NULL"); } catch (_) {}
  try { await db.query("ALTER TABLE hrms_payroll_items ADD COLUMN daily_rate DECIMAL(12,2) NULL AFTER working_days"); } catch (_) {}
}
ensurePayrollItemColumns();

async function ensureCustomCycleTable() {
  await db.query(`CREATE TABLE IF NOT EXISTS hrms_payroll_custom_cycles (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    profile_id BIGINT UNSIGNED NOT NULL,
    pay_year SMALLINT UNSIGNED NOT NULL,
    pay_month TINYINT UNSIGNED NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    created_by BIGINT UNSIGNED NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY profile_month (profile_id, pay_year, pay_month)
  )`);
}

function monthOptions(today) {
  const [ty, tm] = today.split('-').map(Number);
  const items = [];
  for (let i = 0; i < 12; i += 1) {
    let month = tm - i;
    let year = ty;
    while (month < 1) {
      month += 12;
      year -= 1;
    }
    items.push({
      year: year,
      month: month,
      label: MONTHS[month - 1] + ' ' + year,
    });
  }
  return items;
}

async function computeRows(year, month, today) {
  const configuredPolicy = await payrollPolicy();
  const weeklyOff = new Set(configuredPolicy.weeklyOffDays);
  // Standard month bounds (used for records query and compensation lookup)
  const totalDays = daysInMonth(year, month);
  const stdStart = ymd(year, month, 1);
  const stdEnd = ymd(year, month, totalDays);

  const [profiles] = await db.query(`
    SELECT p.*, COALESCE(NULLIF(p.department, ''), u.role, '') AS calendar_department
    FROM hrms_employee_profiles p JOIN employee_users u ON u.id = p.employee_user_id
    WHERE p.employment_status <> 'Inactive' AND u.is_active = 1
    ORDER BY p.full_name ASC
  `);

  // Compensation is versioned by immutable profile/user IDs. A name is display-only.
  await db.query(`CREATE TABLE IF NOT EXISTS hrms_employee_compensation (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    profile_id BIGINT UNSIGNED NULL,
    employee_user_id BIGINT UNSIGNED NULL,
    monthly_salary DECIMAL(12,2) NOT NULL,
    effective_from DATE NOT NULL,
    created_by BIGINT UNSIGNED NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY profile_effective (profile_id, effective_from),
    KEY user_effective (employee_user_id, effective_from)
  )`);
  try { await db.query('ALTER TABLE hrms_employee_compensation ADD COLUMN profile_id BIGINT UNSIGNED NULL AFTER id'); } catch (_) {}
  for (const profile of profiles) {
    if (profile.monthly_salary === null || profile.monthly_salary === undefined) continue;
    await db.query(`INSERT INTO hrms_employee_compensation (profile_id, employee_user_id, monthly_salary, effective_from)
      SELECT ?, ?, ?, COALESCE(DATE(created_at), ?)
      FROM hrms_employee_profiles WHERE id = ?
      AND NOT EXISTS (SELECT 1 FROM hrms_employee_compensation c WHERE c.profile_id = ?)
      LIMIT 1`, [profile.id, profile.employee_user_id || null, profile.monthly_salary, stdStart, profile.id, profile.id]);
  }
  const [compensations] = await db.query(`SELECT profile_id, employee_user_id, monthly_salary, effective_from
    FROM hrms_employee_compensation WHERE effective_from <= ? ORDER BY effective_from ASC, id ASC`, [stdEnd]);
  const compensationMap = new Map();
  compensations.forEach(function (row) {
    if (row.profile_id) compensationMap.set('profile:' + row.profile_id, row);
    if (row.employee_user_id) compensationMap.set('user:' + row.employee_user_id, row);
  });

  const userIds = profiles.map(function (row) { return row.employee_user_id; }).filter(Boolean);

  // Fetch records for the full possible flexible range (prev month day 1 → stdEnd)
  let prevYear = year; let prevMonth = month - 1;
  if (prevMonth < 1) { prevMonth = 12; prevYear -= 1; }
  const broadStart = ymd(prevYear, prevMonth, 1);
  const overridesByEmployee = await effectiveOverrides(broadStart, stdEnd, profiles);
  const [records] = userIds.length
    ? await db.query(
        `SELECT employee_id, DATE_FORMAT(attendance_date, '%Y-%m-%d') AS attendance_date,
                check_in_at, is_late, attendance_status
         FROM attendance_records
         WHERE attendance_date BETWEEN ? AND ?
           AND employee_id IN (?)`,
        [broadStart, stdEnd, userIds]
      )
    : [[]];

  // Fetch approved leaves from the leave system. Each row carries is_lop (per
  // leave type) and duration_type so half-day leaves deduct 0.5, not 1.0.
  const [leaves] = userIds.length
    ? await db.query(
        `SELECT el.employee_id,
                DATE_FORMAT(el.from_date, '%Y-%m-%d') AS from_date,
                DATE_FORMAT(el.to_date,   '%Y-%m-%d') AS to_date,
                el.duration_type,
                lt.is_lop
         FROM employee_leaves el
         LEFT JOIN hrms_leave_types lt ON lt.id = el.leave_type_id
         WHERE el.status = 'APPROVED'
           AND el.from_date <= ? AND el.to_date >= ?
           AND el.employee_id IN (?)`,
        [stdEnd, broadStart, userIds]
      )
    : [[]];

  const [savedRows] = await db.query(
    `SELECT * FROM hrms_payroll_items WHERE pay_year = ? AND pay_month = ?`,
    [year, month]
  );
  const savedMap = new Map();
  savedRows.forEach(function (row) {
    savedMap.set(Number(row.profile_id), row);
  });

  const recordMap = new Map();
  records.forEach(function (row) {
    recordMap.set(row.employee_id + '|' + isoDate(row.attendance_date), row);
  });
  // leaveMap: 'empId|YYYY-MM-DD' → { isLop: bool, isHalf: bool }. The
  // payroll treatment comes from the current Admin leave policy, never a
  // leave-name default. A legacy leave with no linked policy is reported as
  // paid until Admin maps it, so it cannot silently become a salary deduction.
  // Expand each leave record across all its calendar dates so the per-day loop
  // can look up any date cheaply.  Half-day leaves span exactly one date.
  const leaveMap = new Map();
  leaves.forEach(function (row) {
    const isLop = Number(row.is_lop) === 1;
    const isHalf = row.duration_type === 'Half Day';
    let date = isoDate(row.from_date);
    const end = isoDate(row.to_date);
    while (date && date <= end) {
      const key = row.employee_id + '|' + date;
      // First entry wins (multiple overlapping leaves are rejected at apply time)
      if (!leaveMap.has(key)) leaveMap.set(key, { isLop, isHalf });
      date = nextDate(date);
    }
  });

  // Load custom cycles for this pay period (overrides per-employee salary cycle)
  await ensureCustomCycleTable();
  const [customCycles] = await db.query(
    'SELECT profile_id, period_start, period_end FROM hrms_payroll_custom_cycles WHERE pay_year = ? AND pay_month = ?',
    [year, month]
  );
  const customCycleMap = new Map();
  customCycles.forEach(function (r) { customCycleMap.set(Number(r.profile_id), r); });

  return profiles.map(function (profile) {
    let workingDays = 0;
    let completedWorkingDays = 0;
    let present = 0;
    let late = 0;
    let leaveDays = 0;   // total approved leave days (all types)
    let lopLeaveDays = 0; // only LOP leave days — used for salary deduction
    let lopLeaveDaysToDate = 0;
    let paidLeaveDays = 0; // Admin policy marks these as paid
    let absent = 0;

    // Determine the date range for this employee's pay period
    const custom = customCycleMap.get(Number(profile.id));
    const range = custom
      ? { start: isoDate(custom.period_start), end: isoDate(custom.period_end) }
      : cycleRange(year, month, profile.salary_type, profile.salary_cycle_start_day, profile.salary_cycle_end_day);
    const cutoff = range.end < today ? range.end : today;

    // Enumerate all days in the pay period
    const rangeStart = new Date(range.start + 'T00:00:00Z');
    const rangeEnd = new Date(range.end + 'T00:00:00Z');
    for (let d = new Date(rangeStart); d <= rangeEnd; d.setUTCDate(d.getUTCDate() + 1)) {
      const dy = d.getUTCFullYear();
      const dm = d.getUTCMonth() + 1;
      const dd = d.getUTCDate();
      const date = ymd(dy, dm, dd);
      const override = overridesByEmployee.get(Number(profile.employee_user_id))?.get(date)?.status;
      const isWorkingDay = override === 'Working Day' || (!override && !weeklyOff.has(d.getUTCDay()));
      if (!isWorkingDay) continue;
      workingDays += 1;
      if (date > cutoff) continue;
      completedWorkingDays += 1;
      const userId = profile.employee_user_id;
      const key = userId ? userId + '|' + date : '';
      const record = key ? recordMap.get(key) : null;

      // 1. Safely read the status to ignore case (e.g., 'Absent' vs 'absent')
      const attStatus = record && record.attendance_status ? String(record.attendance_status).toLowerCase().trim() : '';

      if (attStatus === 'absent') {
        // An explicit absence is visible in the summary even when the policy
        // treats it as paid time.
        absent += 1;
      } else if (record && record.check_in_at) {
        // Punched in
        if (Number(record.is_late) || attStatus === 'late') late += 1;
        else present += 1;
      } else if (key && leaveMap.has(key)) {
        // Approved leave — half-day counts as 0.5, full day as 1.0
        const leaveInfo = leaveMap.get(key);
        const dayCount = leaveInfo.isHalf ? 0.5 : 1;
        leaveDays += dayCount;
        if (leaveInfo.isLop) {
          lopLeaveDays += dayCount;
          if (date <= today) lopLeaveDaysToDate += dayCount;
        }
        else paidLeaveDays += dayCount;
      } else if (configuredPolicy.missingAttendanceIsAbsent) {
        // Do not silently turn a missing record into an absence unless the
        // administrator has chosen that policy.
        absent += 1;
      }
    }

    const compensation = compensationMap.get('profile:' + profile.id) || compensationMap.get('user:' + profile.employee_user_id);
    const salaryNumber = Number(compensation ? compensation.monthly_salary : profile.monthly_salary || 0);

    // A payroll day is dynamic: monthly salary divided by the actual working
    // days of this employee's pay period (weekly offs and calendar holidays
    // excluded). It is never a fixed 26-day divisor.
    // Only leave types marked Unpaid (LOP) by Admin cause salary deduction.
    // Paid leave types remain visible, but never add to lopLeaveDays. The
    // per-type Admin leave policy is authoritative; the legacy global switch
    // must not override an individual type marked Paid or Unpaid (LOP).
    const unpaidLeaveDays = lopLeaveDays;
    const unpaidAbsenceDays = configuredPolicy.deductExplicitAbsence ? absent : 0;
    const lopDays = Math.min(workingDays, unpaidLeaveDays + unpaidAbsenceDays);
    const paidDays = Math.max(0, workingDays - lopDays);
    // Every record considered above is on or before the pay-period cutoff,
    // therefore explicit absence days are already an "as of today" value.
    const paidDaysToDate = Math.max(0, completedWorkingDays - lopLeaveDaysToDate - unpaidAbsenceDays);
    const dailyRate = salaryNumber && workingDays > 0 ? salaryNumber / workingDays : 0;
    const deductions = salaryNumber && lopDays > 0
      ? Math.min(salaryNumber, Math.ceil(lopDays * dailyRate))
      : 0;

    // Dynamic Net Pay
    const netPay = Math.max(0, salaryNumber - deductions);
    const earnedToDate = Math.max(0, Math.min(salaryNumber, paidDaysToDate * dailyRate));

    const saved = savedMap.get(Number(profile.id));
    // Only a *paid* row's inconsistency is an audit concern requiring a human
    // correction — that state is final and shouldn't be silently rewritten.
    // A pending/draft row with a stale employee_user_id (e.g. left over from
    // before other employees were added) is safe to self-heal the next time
    // payroll is generated, so it must not be flagged here.
    const salaryType = profile.salary_type || 'standard';
    const periodLabel = salaryType === 'flexible'
      ? range.start.slice(5).replace('-', '/') + ' – ' + range.end.slice(5).replace('-', '/')
      : null;

    if (saved && saved.status === 'paid' && (Number(saved.employee_user_id) !== Number(profile.employee_user_id) ||
        !(Number(saved.monthly_salary) > 0))) {
      return { id: saved.id, profileId: profile.id, employeeUserId: profile.employee_user_id,
        name: String(profile.full_name || '').trim(), employeeCode: profile.employee_code,
        department: profile.department, monthlySalary: salaryNumber || null, salary: formatSalary(salaryNumber || null),
        workingDays, completedWorkingDays, dailyRate, paidDays, paidDaysToDate, earnedToDate, lopDays, deductions: 0, deductionsLabel: 'Review required',
        netPay: 0, netPayLabel: 'Review required', status: 'Review required', paidAt: '',
        salaryType, periodStart: range.start, periodEnd: range.end, periodLabel,
        integrityError: 'Saved payroll has inconsistent ownership or missing paid salary. An audited correction is required.' };
    }

    if (!salaryNumber) {
      return {
        id: saved ? saved.id : null, profileId: profile.id, employeeUserId: profile.employee_user_id,
        name: String(profile.full_name || '').trim(), employeeCode: profile.employee_code,
        department: profile.department, monthlySalary: null, salary: 'Not Set',
        workingDays: workingDays, completedWorkingDays, dailyRate, dailyRateLabel: '–', presentDays: present, lateDays: late, leaveDays: leaveDays, paidLeaveDays: paidLeaveDays, lopLeaveDays: lopLeaveDays, absentDays: absent,
        paidDays: paidDays, paidDaysToDate, earnedToDate: 0, earnedToDateLabel: '–', lopDays: lopDays, deductions: 0, deductionsLabel: '–', netPay: 0, netPayLabel: '–',
        status: 'Salary required', paidAt: '',
        salaryType, periodStart: range.start, periodEnd: range.end, periodLabel,
      };
    }

    if (saved && String(saved.status) === 'paid') {
      return {
        id: saved.id, profileId: profile.id, employeeUserId: profile.employee_user_id,
        name: String(profile.full_name || '').trim(), employeeCode: profile.employee_code,
        department: profile.department, monthlySalary: Number(saved.monthly_salary || 0), salary: formatSalary(saved.monthly_salary),
        workingDays: Number(saved.working_days || 0), completedWorkingDays, dailyRate: Number(saved.daily_rate || (Number(saved.working_days || 0) ? Number(saved.monthly_salary || 0) / Number(saved.working_days) : 0)), dailyRateLabel: formatSalary(saved.daily_rate || 0), presentDays: present, lateDays: late, leaveDays: leaveDays, paidLeaveDays: paidLeaveDays, lopLeaveDays: lopLeaveDays, absentDays: absent,
        paidDays: Number(saved.paid_days || 0), paidDaysToDate, earnedToDate: Number(saved.net_pay || 0), earnedToDateLabel: formatSalary(saved.net_pay), lopDays: Number(saved.lop_days || 0), deductions: Number(saved.deductions || 0),
        deductionsLabel: formatSalary(saved.deductions), netPay: Number(saved.net_pay || 0), netPayLabel: formatSalary(saved.net_pay),
        status: 'Paid', paidAt: saved.paid_at ? isoDate(saved.paid_at) : '',
        salaryType, periodStart: isoDate(saved.period_start) || range.start, periodEnd: isoDate(saved.period_end) || range.end, periodLabel,
      };
    }

    const status = saved ? String(saved.status) : 'draft';

    return {
      id: saved ? saved.id : null,
      profileId: profile.id,
      employeeUserId: profile.employee_user_id,
      name: String(profile.full_name || '').trim(),
      employeeCode: profile.employee_code,
      department: profile.department,
      monthlySalary: salaryNumber || null,
      salary: formatSalary(salaryNumber),
      workingDays: workingDays,
      completedWorkingDays: completedWorkingDays,
      dailyRate: dailyRate,
      dailyRateLabel: formatSalary(dailyRate),
      presentDays: present,
      lateDays: late,
      leaveDays: leaveDays,       // all approved leave days (LOP + Non-LOP)
      paidLeaveDays: paidLeaveDays,
      lopLeaveDays: lopLeaveDays,  // only LOP leave days (used in deduction)
      absentDays: absent,
      paidDays: paidDays,
      paidDaysToDate: paidDaysToDate,
      earnedToDate: earnedToDate,
      earnedToDateLabel: salaryNumber ? formatSalary(earnedToDate) : '–',
      lopDays: lopDays,
      deductions: deductions,
      deductionsLabel: salaryNumber ? formatSalary(deductions) : '–',
      netPay: netPay,
      netPayLabel: salaryNumber ? formatSalary(netPay) : '–',
      status: status === 'paid' ? 'Paid' : status === 'pending' ? 'Pending' : 'Draft',
      paidAt: saved && saved.paid_at ? isoDate(saved.paid_at) : '',
      salaryType, periodStart: range.start, periodEnd: range.end, periodLabel,
    };
  });
}

function toKpis(items) {
  const withSalary = items.filter(function (item) { return item.monthlySalary; });
  const totalPayroll = withSalary.reduce(function (sum, item) { return sum + item.netPay; }, 0);
  const paid = items.filter(function (item) { return item.status === 'Paid'; }).length;
  const pending = items.filter(function (item) { return item.status === 'Pending'; }).length;
  const draft = items.filter(function (item) { return item.status === 'Draft'; }).length;
  return {
    totalPayroll: totalPayroll,
    totalPayrollLabel: formatSalary(totalPayroll || null),
    employees: items.length,
    paid: paid,
    pending: pending,
    draft: draft,
  };
}

async function list(req, res) {
  try {
    const parsed = parseMonth(req);
    if (parsed.error) return fail(res, 400, parsed.error);
    const employee = String(req.query.employee || '').trim();
    const status = String(req.query.status || '').trim();
    const allItems = await computeRows(parsed.year, parsed.month, parsed.today);
    let items = allItems;
    if (employee && employee !== 'All Employees') {
      items = items.filter(function (item) { return item.name === employee; });
    }
    if (status && status !== 'All Status') {
      items = items.filter(function (item) { return item.status === status; });
    }
    const names = [...new Set(allItems.map(function (item) { return item.name; }))];
    return ok(res, {
      year: parsed.year,
      month: parsed.month,
      label: MONTHS[parsed.month - 1] + ' ' + parsed.year,
      months: monthOptions(parsed.today),
      timezone: policy.TIME_ZONE,
      policy: await payrollPolicy(),
      items: items,
      employees: names,
      kpis: toKpis(items),
    });
  } catch (error) {
    console.error('GET /hrms/payroll', error);
    return fail(res, 500, error.message);
  }
}

async function getPolicy(req, res) {
  try { return ok(res, await payrollPolicy()); } catch (error) { return fail(res, 500, error.message); }
}

async function savePolicy(req, res) {
  try {
    const body = req.body || {};
    const weekly = Array.isArray(body.weeklyOffDays) ? [...new Set(body.weeklyOffDays.map(Number).filter((day) => day >= 0 && day <= 6))] : null;
    if (!weekly) return fail(res, 400, 'weeklyOffDays must contain weekday numbers from 0 to 6');
    const values = [JSON.stringify(weekly), body.deductExplicitAbsence ? 1 : 0, body.missingAttendanceIsAbsent ? 1 : 0, req.user.id];
    await ensurePolicyTable();
    await db.query(`UPDATE hrms_payroll_policy SET weekly_off_days = ?, deduct_explicit_absence = ?, missing_attendance_is_absent = ?, updated_by = ? WHERE id = 1`, values);
    return ok(res, await payrollPolicy(), 'Payroll policy saved');
  } catch (error) { return fail(res, 500, error.message); }
}

async function generate(req, res) {
  try {
    const parsed = parseMonth(req);
    if (parsed.error) return fail(res, 400, parsed.error);
    const result = await generatePayrollRun(parsed.year, parsed.month, parsed.today);
    return ok(res, result, 'Payroll generated for ' + MONTHS[parsed.month - 1] + ' ' + parsed.year + '. ' + result.generatedCount + ' employee(s) included; ' + result.skippedCount + ' need compensation.');
  } catch (error) {
    console.error('POST /hrms/payroll/generate', error);
    return fail(res, 500, error.message);
  }
}

async function generatePayrollRun(year, month, today) {
    // Heal stale employee_user_id on ALL non-paid rows before computing anything.
    // This runs unconditionally so employees with no salary set are also corrected,
    // preventing permanent "Review required" on pending rows with wrong ownership.
    await db.query(`
      UPDATE hrms_payroll_items pi
      JOIN hrms_employee_profiles ep ON ep.id = pi.profile_id
      SET pi.employee_user_id = ep.employee_user_id
      WHERE pi.status != 'paid'
        AND (pi.employee_user_id IS NULL OR pi.employee_user_id != ep.employee_user_id)
    `);
    // Reset any 'paid' row that has no salary — these are audit anomalies that
    // block the employee indefinitely and must be reopened so payroll can regenerate.
    await db.query(`
      UPDATE hrms_payroll_items
      SET status = 'pending', paid_at = NULL
      WHERE status = 'paid' AND (monthly_salary IS NULL OR monthly_salary <= 0)
    `);

    const allItems = await computeRows(year, month, today);
    const items = allItems.filter(function (item) { return Number(item.monthlySalary) > 0 && !item.integrityError && item.employeeUserId; });
    for (const item of items) {
      if (item.status === 'Paid') continue;
      await db.query(
        `INSERT INTO hrms_payroll_items
          (profile_id, employee_user_id, pay_year, pay_month, monthly_salary,
           working_days, daily_rate, paid_days, lop_days, deductions, net_pay, status, period_start, period_end)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?, ?)
         ON DUPLICATE KEY UPDATE
           employee_user_id = IF(status = 'paid', employee_user_id, VALUES(employee_user_id)),
           monthly_salary = IF(status = 'paid', monthly_salary, VALUES(monthly_salary)),
           working_days = IF(status = 'paid', working_days, VALUES(working_days)),
           daily_rate = IF(status = 'paid', daily_rate, VALUES(daily_rate)),
           paid_days = IF(status = 'paid', paid_days, VALUES(paid_days)),
           lop_days = IF(status = 'paid', lop_days, VALUES(lop_days)),
           deductions = IF(status = 'paid', deductions, VALUES(deductions)),
           net_pay = IF(status = 'paid', net_pay, VALUES(net_pay)),
           status = IF(status = 'paid', 'paid', 'pending'),
           period_start = IF(status = 'paid', period_start, VALUES(period_start)),
           period_end = IF(status = 'paid', period_end, VALUES(period_end))`,
        [
          item.profileId,
          item.employeeUserId || null,
          year,
          month,
          item.monthlySalary,
          item.workingDays,
          item.dailyRate,
          item.paidDays,
          item.lopDays,
          item.deductions,
          item.netPay,
          item.periodStart || null,
          item.periodEnd || null,
        ]
      );
    }
    const refreshed = await computeRows(year, month, today);
    return {
      year: year,
      month: month,
      items: refreshed,
      kpis: toKpis(refreshed),
      generatedCount: items.filter(item => item.status !== 'Paid').length,
      retainedPaidCount: items.filter(item => item.status === 'Paid').length,
      reviewCount: allItems.filter(item => item.integrityError).length,
      skippedCount: allItems.length - items.length,
    };
}

async function markPaid(req, res) {
  try {
    const id = Number(req.params.id);
    const status = String((req.body && req.body.status) || 'paid').toLowerCase();
    if (status !== 'paid' && status !== 'pending') {
      return fail(res, 400, 'status must be paid or pending');
    }
    const at = status === 'paid' ? policy.nowIstDateTime() : null;
    const [[payroll]] = await db.query(`SELECT p.id, p.monthly_salary FROM hrms_payroll_items p
      JOIN hrms_employee_profiles e ON e.id = p.profile_id AND e.employee_user_id = p.employee_user_id
      JOIN employee_users u ON u.id = e.employee_user_id WHERE p.id = ?`, [id]);
    if (!payroll) return fail(res, 404, 'Payroll row not found. Generate payroll for this month first.');
    if (Number(payroll.monthly_salary) <= 0) return fail(res, 400, 'Compensation must be configured before payroll can be paid.');
    const [result] = await db.query(
      `UPDATE hrms_payroll_items
       SET status = ?, paid_at = ?
       WHERE id = ?`,
      [status, at, id]
    );
    if (!result.affectedRows) {
      return fail(res, 404, 'Payroll row not found. Generate payroll for this month first.');
    }
    const [rows] = await db.query('SELECT * FROM hrms_payroll_items WHERE id = ?', [id]);
    return ok(res, rows[0] || {}, 'Marked ' + status);
  } catch (error) {
    console.error('PATCH /hrms/payroll/:id', error);
    return fail(res, 500, error.message);
  }
}

async function getCustomCycle(req, res) {
  try {
    const profileId = Number(req.params.profileId);
    const parsed = parseMonth(req);
    if (parsed.error) return fail(res, 400, parsed.error);
    await ensureCustomCycleTable();
    const [rows] = await db.query(
      'SELECT * FROM hrms_payroll_custom_cycles WHERE profile_id = ? AND pay_year = ? AND pay_month = ?',
      [profileId, parsed.year, parsed.month]
    );
    return ok(res, rows[0] ? {
      profileId: profileId,
      year: parsed.year,
      month: parsed.month,
      periodStart: isoDate(rows[0].period_start),
      periodEnd: isoDate(rows[0].period_end),
    } : null);
  } catch (error) {
    return fail(res, 500, error.message);
  }
}

async function setCustomCycle(req, res) {
  try {
    const profileId = Number(req.params.profileId);
    const parsed = parseMonth(req);
    if (parsed.error) return fail(res, 400, parsed.error);
    const body = req.body || {};
    const periodStart = String(body.periodStart || '').trim();
    const periodEnd = String(body.periodEnd || '').trim();
    if (!periodStart || !periodEnd) return fail(res, 400, 'periodStart and periodEnd are required');
    await ensureCustomCycleTable();
    await db.query(
      `INSERT INTO hrms_payroll_custom_cycles (profile_id, pay_year, pay_month, period_start, period_end, created_by)
       VALUES (?, ?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE period_start = VALUES(period_start), period_end = VALUES(period_end), created_by = VALUES(created_by)`,
      [profileId, parsed.year, parsed.month, periodStart, periodEnd, req.user && req.user.id]
    );
    return ok(res, { profileId, year: parsed.year, month: parsed.month, periodStart, periodEnd }, 'Custom cycle saved');
  } catch (error) {
    return fail(res, 500, error.message);
  }
}

module.exports = {
  requireAdmin,
  list,
  generate,
  markPaid,
  getPolicy,
  savePolicy,
  computeRows,
  payrollPolicy,
  generatePayrollRun,
  getCustomCycle,
  setCustomCycle,
};
