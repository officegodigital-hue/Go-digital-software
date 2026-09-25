const db = require('../config/db');
const policy = require('../lib/attendancePolicy');

function ok(res, data) {
  return res.json({ success: true, message: 'OK', data });
}

function fail(res, status, message) {
  return res.status(status).json({ success: false, message });
}

function pad(v) { return String(v).padStart(2, '0'); }
function ymd(y, m, d) { return y + '-' + pad(m) + '-' + pad(d); }
function daysInMonth(y, m) { return new Date(Date.UTC(y, m, 0)).getUTCDate(); }

function isoDate(value) {
  if (!value) return '';
  if (value instanceof Date && !Number.isNaN(value.getTime()))
    return value.toISOString().slice(0, 10);
  const match = String(value).match(/(\d{4}-\d{2}-\d{2})/);
  return match ? match[1] : '';
}

function formatTime(value) {
  if (!value) return null;
  const s = String(value);
  // datetime string from DB: "2026-09-12 09:51:00"
  const m = s.match(/(\d{2}):(\d{2})(?::\d{2})?/);
  if (!m) return null;
  let h = parseInt(m[1], 10);
  const min = m[2];
  const ampm = h >= 12 ? 'PM' : 'AM';
  if (h > 12) h -= 12;
  if (h === 0) h = 12;
  return h + ':' + min + ' ' + ampm;
}

function formatSalary(value) {
  if (!value) return '–';
  const n = Number(value);
  if (!n) return '–';
  return '₹' + n.toLocaleString('en-IN');
}

function workedMinutes(record) {
  if (!record || !record.check_in_at) return 0;
  // Use stored working_minutes first (set at checkout) — most accurate
  const stored = Number(record.working_minutes || 0);
  if (stored > 0) return stored;
  // Fall back to calculating from timestamps when stored value is missing
  if (!record.check_out_at) return 0;
  try {
    return Math.max(0, policy.minutesBetween
      ? policy.minutesBetween(String(record.check_in_at), String(record.check_out_at))
      : Math.round((new Date(record.check_out_at) - new Date(record.check_in_at)) / 60000));
  } catch (_) { return 0; }
}

function formatWorked(minutes) {
  if (!minutes) return '0h 00m';
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return h + 'h ' + pad(m) + 'm';
}

function displayType(requestType) {
  const v = String(requestType || '').toLowerCase();
  if (v === 'casual_leave') return 'Casual Leave';
  if (v === 'earned_leave') return 'Earned Leave';
  if (v === 'optional_holiday') return 'Optional Holiday';
  if (v === 'annual_leave' || v === 'leave') return 'Annual Leave';
  if (v === 'sick_leave') return 'Sick Leave';
  if (v === 'personal_leave' || v === 'risk_leave') return 'Personal Leave';
  if (v === 'permission') return 'Permission';
  if (v === 'extra_hours') return 'Extra Hours';
  if (v === 'late_entry') return 'Late Entry';
  if (v === 'early_exit') return 'Early Exit';
  return String(requestType || '').replace(/_/g, ' ');
}

const LEAVE_TYPES = ['leave', 'risk_leave', 'annual_leave', 'sick_leave', 'personal_leave', 'casual_leave', 'earned_leave', 'optional_holiday'];
const DEFAULT_WEEKLY_OFF = [0]; // Sunday

async function getPayrollPolicy() {
  try {
    const [rows] = await db.query('SELECT * FROM hrms_payroll_policy WHERE id = 1');
    const row = rows[0] || {};
    let weeklyOffDays = DEFAULT_WEEKLY_OFF;
    try { weeklyOffDays = JSON.parse(row.weekly_off_days || '[0]'); } catch (_) {}
    return {
      weeklyOffDays: Array.isArray(weeklyOffDays) ? weeklyOffDays.map(Number) : DEFAULT_WEEKLY_OFF,
      deductApprovedLeave: Boolean(Number(row.deduct_approved_leave ?? 1)),
      deductExplicitAbsence: Boolean(Number(row.deduct_explicit_absence ?? 1)),
      missingAttendanceIsAbsent: Boolean(Number(row.missing_attendance_is_absent ?? 0)),
      salaryDayDivisor: Math.max(1, Number(row.salary_day_divisor || 26)),
    };
  } catch (_) {
    return { weeklyOffDays: DEFAULT_WEEKLY_OFF, deductApprovedLeave: true, deductExplicitAbsence: true, missingAttendanceIsAbsent: false, salaryDayDivisor: 26 };
  }
}

async function getProfile(req, res) {
  try {
    const profileId = Number(req.params.id || req.params.profileId);
    // employeeUserId fallback: used when the person doesn't yet have an HRMS profile row
    const fallbackUserId = Number(req.query.employeeUserId || 0);
    if (!profileId && !fallbackUserId) return fail(res, 400, 'profileId or employeeUserId required');

    const today = policy.todayIstDate ? policy.todayIstDate() : new Date().toISOString().slice(0, 10);
    const [ty, tm] = today.split('-').map(Number);
    const year = Number(req.query.year || ty);
    const month = Number(req.query.month || tm);
    if (month < 1 || month > 12) return fail(res, 400, 'month must be 1–12');

    // 1 ─ Employee basic info — look up by profileId first, fall back to employee_user_id
    let profileRows;
    if (profileId) {
      [profileRows] = await db.query(
        `SELECT p.*, u.is_active FROM hrms_employee_profiles p
         LEFT JOIN employee_users u ON u.id = p.employee_user_id
         WHERE p.id = ? LIMIT 1`,
        [profileId]
      );
    } else {
      [profileRows] = await db.query(
        `SELECT p.*, u.is_active FROM hrms_employee_profiles p
         LEFT JOIN employee_users u ON u.id = p.employee_user_id
         WHERE p.employee_user_id = ? LIMIT 1`,
        [fallbackUserId]
      );
    }

    // If still not found, build a minimal profile from employee_users so the page
    // can at least show attendance data for any active staff member.
    let profile;
    if (!profileRows || !profileRows.length) {
      const lookupId = profileId || fallbackUserId;
      const [userRows] = await db.query(
        `SELECT id, full_name, staff_id, role, is_active FROM employee_users WHERE id = ? LIMIT 1`,
        [lookupId || fallbackUserId]
      );
      if (!userRows.length) return fail(res, 404, 'Employee not found');
      const u = userRows[0];
      profile = {
        id: null,
        full_name: u.full_name || '',
        employee_code: u.staff_id || '',
        department: u.role || '',
        work_mode: '',
        monthly_salary: null,
        employment_status: u.is_active ? 'Active' : 'Inactive',
        salary_type: 'standard',
        salary_cycle_start_day: null,
        salary_cycle_end_day: null,
        employee_user_id: u.id,
        is_active: u.is_active,
      };
    } else {
      profile = profileRows[0];
    }
    const employeeUserId = profile.employee_user_id;

    const monthlySalary = Number(profile.monthly_salary || 0);
    const periodStart = ymd(year, month, 1);
    const periodEnd = ymd(year, month, daysInMonth(year, month));

    // Broad start for flexible cycles (covers prev month)
    let prevYear = year, prevMonth = month - 1;
    if (prevMonth < 1) { prevMonth = 12; prevYear -= 1; }
    const broadStart = ymd(prevYear, prevMonth, 1);

    // 2 ─ Payroll policy
    const pol = await getPayrollPolicy();
    const weeklyOff = new Set(pol.weeklyOffDays);

    // 3 ─ Attendance records for the month
    const [records] = employeeUserId
      ? await db.query(
          `SELECT id, DATE_FORMAT(attendance_date,'%Y-%m-%d') AS attendance_date,
                  check_in_at, check_out_at, is_late, attendance_status, check_in_method,
                  working_minutes
           FROM attendance_records
           WHERE employee_id = ? AND attendance_date BETWEEN ? AND ?
           ORDER BY attendance_date ASC`,
          [employeeUserId, broadStart, periodEnd]
        )
      : [[]];

    // 4 ─ Break rows for those attendance records
    const recIds = records.map(r => r.id).filter(Boolean);
    const [breakRows] = recIds.length
      ? await db.query(
          `SELECT attendance_id, id, started_at, ended_at, duration_minutes,
                  allowed_minutes, overdue_minutes, reviewed_at, status
           FROM attendance_breaks
           WHERE attendance_id IN (?)
           ORDER BY attendance_id, started_at`,
          [recIds]
        )
      : [[]];

    const breaksByRecord = new Map();
    breakRows.forEach(br => {
      const key = Number(br.attendance_id);
      if (!breaksByRecord.has(key)) breaksByRecord.set(key, []);
      breaksByRecord.get(key).push(br);
    });

    const recordMap = new Map();
    records.forEach(r => recordMap.set(isoDate(r.attendance_date), r));

    // 5 ─ Leave / permission requests for the month + 5 previous months
    const historyStart = (() => {
      let y = year, m = month - 5;
      while (m < 1) { m += 12; y -= 1; }
      return ymd(y, m, 1);
    })();

    // from_date / to_date live in employee_leaves, linked via hrms_leave_approval_links
    const [leaveRows] = employeeUserId
      ? await db.query(
          `SELECT p.id, p.employee_id, p.request_type, p.request_date, p.reason, p.status,
                  p.reviewed_by, p.created_at,
                  DATE_FORMAT(COALESCE(el.from_date, p.request_date),'%Y-%m-%d') AS from_date,
                  DATE_FORMAT(COALESCE(el.to_date,   p.request_date),'%Y-%m-%d') AS to_date,
                  el.duration_type
           FROM attendance_permission_requests p
           LEFT JOIN hrms_leave_approval_links lnk ON lnk.approval_request_id = p.id
           LEFT JOIN employee_leaves el ON el.id = lnk.leave_id
           WHERE p.employee_id = ?
             AND COALESCE(el.from_date, p.request_date) BETWEEN ? AND ?
           ORDER BY COALESCE(el.from_date, p.request_date) DESC`,
          [employeeUserId, historyStart, periodEnd]
        )
      : [[]];

    // Build leave set for LOP calculation
    const leaveSet = new Set();
    leaveRows.filter(r => r.status === 'approved' && LEAVE_TYPES.includes(String(r.request_type).toLowerCase()))
      .forEach(r => {
        const from = isoDate(r.from_date || r.request_date);
        const to = isoDate(r.to_date || r.request_date);
        if (from && to) {
          let d = new Date(from + 'T00:00:00Z');
          const end = new Date(to + 'T00:00:00Z');
          while (d <= end) {
            leaveSet.add(d.toISOString().slice(0, 10));
            d.setUTCDate(d.getUTCDate() + 1);
          }
        }
      });

    // 6 ─ Permission set (approved permissions, not leave – for count)
    const permissionCount = leaveRows.filter(r =>
      String(r.request_type).toLowerCase() === 'permission' &&
      r.status === 'approved' &&
      isoDate(r.request_date || r.from_date) >= periodStart &&
      isoDate(r.request_date || r.from_date) <= periodEnd
    ).length;

    // 7 ─ Build daily attendance array (only month days)
    let workingDays = 0, presentCount = 0, lateCount = 0, absentCount = 0, leaveCount = 0, lopDays = 0;
    const cutoff = periodEnd < today ? periodEnd : today;

    const dailyAttendance = [];
    for (let day = 1; day <= daysInMonth(year, month); day++) {
      const date = ymd(year, month, day);
      const weekday = new Date(date + 'T00:00:00Z').getUTCDay();
      const isWeeklyOff = weeklyOff.has(weekday);

      const record = recordMap.get(date);
      const brks = record ? (breaksByRecord.get(Number(record.id)) || []) : [];

      // Break summary
      const completedBreaks = brks.filter(b => b.ended_at);
      const firstBreak = brks.length ? brks[0] : null;
      const lastBreak = completedBreaks.length ? completedBreaks[completedBreaks.length - 1] : null;
      const totalBreakMin = brks.reduce((s, b) => s + Number(b.duration_minutes || 0), 0);
      const totalOverdueMin = brks.reduce((s, b) => s + Number(b.overdue_minutes || 0), 0);
      const allowed = firstBreak ? Number(firstBreak.allowed_minutes || 60) : 60;

      let status = 'weekly_off';
      let isLop = false;

      if (!isWeeklyOff && date <= cutoff) {
        workingDays += 1;
        const attStatus = record && record.attendance_status ? String(record.attendance_status).toLowerCase().trim() : '';

        if (attStatus === 'absent') {
          status = 'absent';
          absentCount += 1;
          if (pol.deductExplicitAbsence) { lopDays += 1; isLop = true; }
        } else if (record && record.check_in_at) {
          if (Number(record.is_late) || attStatus === 'late') {
            status = 'late';
            lateCount += 1;
          } else if (record.check_out_at && policy.isEarlyExit && policy.isEarlyExit(workedMinutes(record))) {
            status = 'early_exit';
            presentCount += 1;
          } else {
            status = 'present';
            presentCount += 1;
          }
        } else if (leaveSet.has(date)) {
          status = 'leave';
          leaveCount += 1;
          if (pol.deductApprovedLeave) { lopDays += 1; isLop = true; }
        } else if (pol.missingAttendanceIsAbsent) {
          status = 'absent';
          absentCount += 1;
          if (pol.deductExplicitAbsence) { lopDays += 1; isLop = true; }
        } else {
          status = 'no_record';
        }
      }

      const wm = workedMinutes(record);
      dailyAttendance.push({
        date,
        weekday: ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'][weekday],
        isWeeklyOff,
        checkIn: record ? formatTime(record.check_in_at) : null,
        checkOut: record ? formatTime(record.check_out_at) : null,
        checkInRaw: record ? isoDate(record.attendance_date) : null,
        workedMinutes: wm,
        workedLabel: isWeeklyOff ? '–' : formatWorked(wm),
        breakStart: firstBreak ? formatTime(firstBreak.started_at) : null,
        breakEnd: lastBreak ? formatTime(lastBreak.ended_at) : null,
        breakMinutes: totalBreakMin,
        breakAllowed: allowed,
        breakOverdue: totalOverdueMin,
        breakLabel: totalBreakMin ? `${totalBreakMin}m` : null,
        status,
        isLop,
        method: record ? (record.check_in_method || null) : null,
      });
    }

    const paidDays = Math.max(0, workingDays - lopDays);
    const deductions = monthlySalary && lopDays > 0
      ? Math.min(monthlySalary, Math.ceil(lopDays * (monthlySalary / pol.salaryDayDivisor)))
      : 0;
    const netPay = Math.max(0, monthlySalary - deductions);

    // 8 ─ Payroll history (last 6 months)
    const [payrollItems] = await db.query(
      `SELECT id, pay_year, pay_month, monthly_salary, working_days, paid_days, lop_days,
              deductions, net_pay, status, paid_at,
              DATE_FORMAT(period_start,'%Y-%m-%d') AS period_start,
              DATE_FORMAT(period_end,'%Y-%m-%d') AS period_end
       FROM hrms_payroll_items
       WHERE profile_id = ?
       ORDER BY pay_year DESC, pay_month DESC
       LIMIT 6`,
      [profile.id || 0]
    );

    const MONTHS = ['January','February','March','April','May','June','July','August','September','October','November','December'];

    const payrollHistory = payrollItems.map(row => ({
      id: row.id,
      year: row.pay_year,
      month: row.pay_month,
      monthLabel: MONTHS[row.pay_month - 1] + ' ' + row.pay_year,
      monthlySalary: Number(row.monthly_salary || 0),
      salaryLabel: formatSalary(row.monthly_salary),
      workingDays: Number(row.working_days || 0),
      paidDays: Number(row.paid_days || 0),
      lopDays: Number(row.lop_days || 0),
      deductions: Number(row.deductions || 0),
      deductionsLabel: formatSalary(row.deductions),
      netPay: Number(row.net_pay || 0),
      netPayLabel: formatSalary(row.net_pay),
      status: String(row.status || 'draft'),
      paidAt: isoDate(row.paid_at),
      periodStart: row.period_start || '',
      periodEnd: row.period_end || '',
    }));

    // 9 ─ Leaves for response (filter to current month + history)
    const leaves = leaveRows.map(row => {
      const from = isoDate(row.from_date || row.request_date);
      const to = isoDate(row.to_date || row.request_date);
      let durationDays = 1;
      if (from && to) {
        durationDays = Math.max(1, Math.round((Date.parse(to + 'T00:00:00Z') - Date.parse(from + 'T00:00:00Z')) / 86400000) + 1);
      }
      const isPermission = String(row.request_type).toLowerCase() === 'permission';
      const isLopImpact = !isPermission && LEAVE_TYPES.includes(String(row.request_type).toLowerCase()) && pol.deductApprovedLeave && row.status === 'approved';
      return {
        id: row.id,
        type: displayType(row.request_type),
        typeRaw: row.request_type,
        isPermission,
        fromDate: from,
        toDate: to,
        durationDays,
        durationType: row.duration_type || null,
        reason: row.reason || '',
        status: row.status || 'pending',
        reviewedBy: row.reviewed_by || null,
        appliedOn: isoDate(row.created_at),
        isLopImpact,
      };
    });

    // 10 ─ Current month payroll row (if saved)
    const [currentPayroll] = await db.query(
      `SELECT status, net_pay FROM hrms_payroll_items WHERE profile_id = ? AND pay_year = ? AND pay_month = ? LIMIT 1`,
      [profile.id || 0, year, month]
    );
    const currentPayrollStatus = currentPayroll[0] ? String(currentPayroll[0].status) : 'draft';
    const currentNetPay = currentPayroll[0] ? Number(currentPayroll[0].net_pay || 0) : netPay;

    return ok(res, {
      employee: {
        id: profile.id,
        name: String(profile.full_name || '').trim(),
        employeeCode: profile.employee_code || '',
        department: profile.department || '',
        workMode: profile.work_mode || '',
        salary: formatSalary(profile.monthly_salary),
        monthlySalary,
        status: profile.employment_status || 'Active',
        salaryType: profile.salary_type || 'standard',
      },
      period: { year, month, periodStart, periodEnd, monthLabel: MONTHS[month - 1] + ' ' + year },
      summary: {
        workingDays,
        present: presentCount,
        late: lateCount,
        absent: absentCount,
        leaveDays: leaveCount,
        permissions: permissionCount,
        lopDays,
        paidDays,
        deductions,
        deductionsLabel: formatSalary(deductions),
        netPay: currentNetPay,
        netPayLabel: formatSalary(currentNetPay),
        payrollStatus: currentPayrollStatus,
      },
      dailyAttendance,
      leaves,
      payrollHistory,
    });
  } catch (error) {
    console.error('GET /hrms/employees/:profileId/profile', error);
    return fail(res, 500, error.message);
  }
}

module.exports = { getProfile };
