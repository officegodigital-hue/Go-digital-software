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
  const digits = String(value).replace(/[^0-9]/g, '');
  if (!digits) return 'Not Set';
  return '₹' + Number(digits).toLocaleString('en-IN');
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

    const weeklyOff = jsWeeklyOff(req.query.weeklyOff || 7);
    const totalDays = daysInMonth(year, month);
    const start = ymd(year, month, 1);
    const end = ymd(year, month, totalDays);
    const today = policy.todayIstDate();

    // employee_users is the source of truth for who is an active employee.
    // HRMS profile data enriches the row, but a stale profile status must not
    // hide a valid employee account from the attendance dashboard.
    const [profiles] = await db.query(`
      SELECT
        profile.id,
        employee.id AS employee_user_id,
        employee.full_name,
        COALESCE(NULLIF(profile.department, ''), employee.role, 'Not Set') AS department,
        COALESCE(profile.monthly_salary, 0) AS monthly_salary
      FROM employee_users AS employee
      LEFT JOIN hrms_employee_profiles AS profile
        ON profile.employee_user_id = employee.id
      WHERE employee.user_type = 'employee'
        AND employee.is_active = 1
      ORDER BY employee.full_name ASC
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
          `SELECT employee_id, duration_type,
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
      while (date <= row.to_date) {
        const key = row.employee_id + '|' + date;
        leaveMap.set(key, row.duration_type === 'Half Day' ? 'HL' : 'LV');
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
      let unexcused = 0;
      let workingDays = 0;

      for (let day = 1; day <= totalDays; day += 1) {
        const date = ymd(year, month, day);
        const weekday = utcWeekday(year, month, day);
        if (weekday === weeklyOff) {
          days.push('OFF');
          continue;
        }
        const userId = profile.employee_user_id;
        const key = userId ? userId + '|' + date : '';
        const record = key ? recordMap.get(key) : null;
        const leaveType = key ? leaveMap.get(key) : null;

        // Future dates stay blank, except for leave that is already approved.
        if (date > today && !leaveType) {
          days.push('');
          continue;
        }

        workingDays += 1;

        // A recorded clock-in is the final decision for that date. Leave is
        // shown only when the employee has no attendance record.
        if (record && record.check_in_at) {
          if (Number(record.is_late)) {
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
          if (leaveType === 'HL') halfLeave += 1;
          if (date <= today) {
            unexcused += 1;
            absentDays += 1;
          }
        } else {
          // A missing record is unrecorded during development, not absent.
          days.push('–');
        }
      }

      const salaryNumber = Number(profile.monthly_salary || 0);
      const paidDays = present + late;
      const afterLeaves = workingDays
        ? Math.round((paidDays / workingDays) * (salaryNumber || 0))
        : 0;

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
        salary: formatSalary(profile.monthly_salary),
        daysPaid: String(paidDays),
        afterLeaves: salaryNumber ? formatSalary(afterLeaves) : '–',
        updatedSalary: formatSalary(profile.monthly_salary),
      };
    });

    return ok(res, {
      year: year,
      month: month,
      daysInMonth: totalDays,
      timezone: policy.TIME_ZONE,
      kpis: {
        totalEmployees: profiles.length,
        present: presentDays,
        absent: absentDays,
        late: lateDays,
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

