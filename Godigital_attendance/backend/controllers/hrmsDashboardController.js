const db = require('../config/db');
const policy = require('../lib/attendancePolicy');

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

function formatSalary(value) {
  if (value === null || value === undefined || value === '') return 'Not Set';
  const amount = Number(value);
  if (!Number.isFinite(amount)) return 'Not Set';
  return '₹' + Math.round(amount).toLocaleString('en-US');
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

function jsWeeklyOff(weeklyOff) {
  const value = Number(weeklyOff);
  if (value === 7) return 0;
  if (value >= 1 && value <= 6) return value;
  return 0;
}

function daysInMonth(year, month) {
  return new Date(Date.UTC(year, month, 0)).getUTCDate();
}

function nextDate(date) {
  const parts = String(date).split('-').map(Number);
  const value = new Date(Date.UTC(parts[0], parts[1] - 1, parts[2] + 1));
  return ymd(value.getUTCFullYear(), value.getUTCMonth() + 1, value.getUTCDate());
}

async function getPayrollPolicy() {
  await db.query(`CREATE TABLE IF NOT EXISTS hrms_payroll_policy (
    id TINYINT UNSIGNED NOT NULL PRIMARY KEY, weekly_off_days JSON NOT NULL,
    deduct_approved_leave TINYINT(1) NOT NULL DEFAULT 1,
    deduct_explicit_absence TINYINT(1) NOT NULL DEFAULT 1,
    missing_attendance_is_absent TINYINT(1) NOT NULL DEFAULT 0
  )`);
  try { await db.query('ALTER TABLE hrms_payroll_policy ADD COLUMN salary_day_divisor TINYINT UNSIGNED NOT NULL DEFAULT 26'); } catch (_) {}
  await db.query(`INSERT IGNORE INTO hrms_payroll_policy (id, weekly_off_days) VALUES (1, '[0]')`);
  const [rows] = await db.query('SELECT * FROM hrms_payroll_policy WHERE id = 1');
  const row = rows[0] || {};
  let days = [0];
  try { days = JSON.parse(row.weekly_off_days || '[0]'); } catch (_) {}
  return { weeklyOffDays: new Set(Array.isArray(days) ? days.map(Number) : [0]), deductLeave: Boolean(Number(row.deduct_approved_leave ?? 1)), deductAbsence: Boolean(Number(row.deduct_explicit_absence ?? 1)), missingIsAbsent: Boolean(Number(row.missing_attendance_is_absent ?? 0)), salaryDayDivisor: Math.max(1, Number(row.salary_day_divisor || 26)) };
}

async function timeSettings(req, res) {
  try {
    return ok(res, await policy.getTimeSettings(db));
  } catch (error) {
    console.error('GET /hrms/dashboard/time-settings', error);
    return fail(res, 500, error.message);
  }
}

async function updateTimeSettings(req, res) {
  try {
    return ok(res, await policy.updateTimeSettings(db, req.body || {}), 'Attendance time settings updated');
  } catch (error) {
    return fail(res, 400, error.message);
  }
}
async function monthView(req, res) {
  try {
    const year = Number(req.query.year);
    const month = Number(req.query.month);
    if (!year || month < 1 || month > 12) {
      return fail(res, 400, 'year and month (1-12) are required');
    }

    const payrollRules = await getPayrollPolicy();
    const weeklyOff = req.query.weeklyOff ? new Set([jsWeeklyOff(req.query.weeklyOff)]) : payrollRules.weeklyOffDays;
    const totalDays = daysInMonth(year, month);
    const start = ymd(year, month, 1);
    const end = ymd(year, month, totalDays);
    const today = policy.todayIstDate();

    // Use the same HRMS profile source as the Employee Management page so
    // dashboard totals cannot include stale/orphan employee login accounts.
    const [profiles] = await db.query(`
      SELECT
        profile.id,
        employee.id AS employee_user_id,
        employee.full_name,
        COALESCE(NULLIF(profile.department, ''), employee.role, 'Not Set') AS department,
        COALESCE(profile.monthly_salary, 0) AS monthly_salary
      FROM hrms_employee_profiles AS profile
      INNER JOIN employee_users AS employee
        ON profile.employee_user_id = employee.id
      WHERE employee.user_type = 'employee'
        AND employee.is_active = 1
        AND profile.employment_status <> 'Inactive'
      ORDER BY profile.full_name ASC
    `);

    const userIds = profiles
      .map(function (row) { return row.employee_user_id; })
      .filter(Boolean);

    const [records] = userIds.length
      ? await db.query(
          `SELECT * FROM attendance_records
           WHERE attendance_date BETWEEN ? AND ?
             AND employee_id IN (?)`,
          [start, end, userIds]
        )
      : [[]];

    const [leaves] = userIds.length
      ? await db.query(
          `SELECT employee_id, duration_type, leave_type,
                  DATE_FORMAT(from_date, '%Y-%m-%d') AS from_date,
                  DATE_FORMAT(to_date, '%Y-%m-%d') AS to_date
           FROM employee_leaves
           WHERE status = 'APPROVED'
             AND from_date <= ? AND to_date >= ?
             AND employee_id IN (?)`,
          [end, start, userIds]
        )
      : [[]];

    const recordMap = new Map();
    records.forEach(function (row) {
      const attendanceDate = row.attendance_date instanceof Date
        ? ymd(row.attendance_date.getFullYear(), row.attendance_date.getMonth() + 1, row.attendance_date.getDate())
        : String(row.attendance_date).slice(0, 10);
      const key = row.employee_id + '|' + attendanceDate;
      recordMap.set(key, row);
    });

    const leaveMap = new Map();
    leaves.forEach(function (row) {
      let date = row.from_date;
      const code = row.duration_type === 'Half Day' ? 'HL' : 'LV';
      while (date <= row.to_date) {
        const key = row.employee_id + '|' + date;
        leaveMap.set(key, { code: code, leaveType: row.leave_type });
        date = nextDate(date);
      }
    });

    let presentDays = 0;
    let absentDays = 0;
    let lateDays = 0;

    const employees = profiles.map(function (profile) {
      const days = [];
      let present = 0;
      let late = 0;
      let halfLeave = 0;
      let earnedLeave = 0;
      let approvedLeave = 0;
      let unexcused = 0;
      let workingDays = 0;

      for (let day = 1; day <= totalDays; day += 1) {
        const date = ymd(year, month, day);
        const weekday = utcWeekday(year, month, day);
        if (weeklyOff.has(weekday)) {
          days.push('OFF');
          continue;
        }
        const userId = profile.employee_user_id;
        const key = userId ? userId + '|' + date : '';
        const record = key ? recordMap.get(key) : null;
        const leaveInfo = key ? leaveMap.get(key) : null;
        const leaveType = leaveInfo ? leaveInfo.code : null;

        // Future dates stay blank, except for leave that is already approved.
        if (date > today && !leaveType) {
          days.push('');
          continue;
        }

        workingDays += 1;

        // A recorded clock-in is the final decision for that date. Leave is
        // shown only when the employee has no attendance record.
        if (record && record.check_in_at) {
          if (String(record.attendance_status) === 'absent' && payrollRules.deductAbsence) {
            days.push('A');
            unexcused += 1;
            absentDays += 1;
          } else if (Number(record.is_late)) {
            days.push('L');
            late += 1;
            lateDays += 1;
          } else {
            days.push('P');
            present += 1;
            presentDays += 1;
          }
        } else if (leaveType) {
          days.push(leaveType);
          approvedLeave += 1;
          if (leaveType === 'HL') halfLeave += 1;
          if (leaveInfo.leaveType === 'Earned Leave') earnedLeave += 1;
          if (date <= today && payrollRules.deductLeave) unexcused += leaveType === 'HL' ? 0.5 : 1;
        } else {
          // A missing record is unrecorded during development, not absent.
          days.push('–');
          if (date <= today && payrollRules.missingIsAbsent) { unexcused += 1; absentDays += 1; }
        }
      }

      const salaryNumber = Number(profile.monthly_salary || 0);
      const lopDays = Math.min(workingDays, unexcused);
      const paidDays = Math.max(0, workingDays - lopDays);
      const deduction = salaryNumber ? Math.min(salaryNumber, Math.ceil(lopDays * (salaryNumber / payrollRules.salaryDayDivisor))) : 0;
      const afterLeaves = Math.max(0, salaryNumber - deduction);

      return {
        id: profile.id,
        employeeUserId: profile.employee_user_id,
        name: profile.full_name,
        designation: profile.department,
        days: days,
        present: present,
        late: late,
        excused: halfLeave,
        unexcused: unexcused,
        halfLeave: halfLeave,
        earnedLeave: earnedLeave,
        approvedLeave: approvedLeave,
        salary: formatSalary(profile.monthly_salary),
        daysPaid: String(lopDays),
        afterLeaves: salaryNumber ? formatSalary(deduction) : '–',
        updatedSalary: salaryNumber ? formatSalary(afterLeaves) : '–',
      };
    });

    // Day-wise KPIs reflect *today* specifically (a live snapshot) rather
    // than a month-to-date total, independent of whichever month/year is
    // being browsed in the calendar below.
    const [todayYear, todayMonth, todayDay] = today.split('-').map(Number);
    const todayWeekday = utcWeekday(todayYear, todayMonth, todayDay);
    let todayPresent = 0;
    let todayAbsent = 0;
    let todayLate = 0;

    if (!weeklyOff.has(todayWeekday) && userIds.length) {
      const [todayRecords] = await db.query(
        `SELECT * FROM attendance_records WHERE attendance_date = ? AND employee_id IN (?)`,
        [today, userIds]
      );
      const [todayLeaves] = await db.query(
        `SELECT employee_id FROM employee_leaves
         WHERE status = 'APPROVED' AND from_date <= ? AND to_date >= ? AND employee_id IN (?)`,
        [today, today, userIds]
      );
      const todayRecordMap = new Map();
      todayRecords.forEach(function (row) { todayRecordMap.set(row.employee_id, row); });
      const todayLeaveSet = new Set(todayLeaves.map(function (row) { return row.employee_id; }));

      profiles.forEach(function (profile) {
        const userId = profile.employee_user_id;
        const record = userId ? todayRecordMap.get(userId) : null;
        if (record && record.check_in_at) {
          if (String(record.attendance_status) === 'absent' && payrollRules.deductAbsence) {
            todayAbsent += 1;
          } else if (Number(record.is_late)) {
            todayLate += 1;
          } else {
            todayPresent += 1;
          }
        } else if (!todayLeaveSet.has(userId) && payrollRules.missingIsAbsent) {
          todayAbsent += 1;
        }
      });
    }

    return ok(res, {
      year: year,
      month: month,
      daysInMonth: totalDays,
      timezone: policy.TIME_ZONE,
      payrollPolicy: { weeklyOffDays: [...payrollRules.weeklyOffDays], deductApprovedLeave: payrollRules.deductLeave, deductExplicitAbsence: payrollRules.deductAbsence, missingAttendanceIsAbsent: payrollRules.missingIsAbsent, salaryDayDivisor: payrollRules.salaryDayDivisor },
      kpis: {
        totalEmployees: profiles.length,
        present: todayPresent,
        absent: todayAbsent,
        late: todayLate,
      },
      employees: employees,
    });
  } catch (error) {
    console.error('GET /hrms/dashboard', error);
    return fail(res, 500, error.message);
  }
}

module.exports = {
  requireAdmin,
  monthView,
  timeSettings,
  updateTimeSettings,
};
