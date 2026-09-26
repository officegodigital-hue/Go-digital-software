const db = require('../config/db');
const staff = require('../lib/staffDirectory');
const policy = require('../lib/attendancePolicy');
const locationPolicy = require('../lib/attendanceLocationPolicy');

function ok(res, data, message) {
  message = message || 'OK';
  return res.json({ success: true, message: message, data: data });
}

function fail(res, status, message) {
  return res.status(status).json({ success: false, message: message });
}

function parseDateParam(value) {
  if (!value) return policy.todayIstDate();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(String(value))) return null;
  return String(value);
}

function sqlDate(value) {
  if (!value) return null;
  if (value instanceof Date) {
    const year = value.getFullYear();
    const month = String(value.getMonth() + 1).padStart(2, '0');
    const day = String(value.getDate()).padStart(2, '0');
    return year + '-' + month + '-' + day;
  }
  return String(value).slice(0, 10);
}

function sqlDateTime(value) {
  if (!value) return null;
  if (value instanceof Date) {
    const date = sqlDate(value);
    const hh = String(value.getHours()).padStart(2, '0');
    const mm = String(value.getMinutes()).padStart(2, '0');
    const ss = String(value.getSeconds()).padStart(2, '0');
    return date + ' ' + hh + ':' + mm + ':' + ss;
  }
  return String(value).slice(0, 19).replace('T', ' ');
}

function parseMonthParam(value) {
  if (!value) return policy.todayIstDate().slice(0, 7);
  if (!/^\d{4}-\d{2}$/.test(String(value))) return null;
  return String(value);
}

function shiftDurationMinutes(shiftStart, shiftEnd) {
  const toMinutes = function (value) {
    const parts = String(value || '').split(':').map(Number);
    return Number(parts[0] || 0) * 60 + Number(parts[1] || 0);
  };
  const start = toMinutes(shiftStart);
  let end = toMinutes(shiftEnd);
  if (end <= start) end += 24 * 60;
  return Math.max(0, end - start);
}

function workingDaysInMonth(month) {
  const parts = String(month).split('-').map(Number);
  const year = parts[0];
  const monthIndex = parts[1] - 1;
  const days = new Date(Date.UTC(year, monthIndex + 1, 0)).getUTCDate();
  let count = 0;
  for (let day = 1; day <= days; day += 1) {
    if (new Date(Date.UTC(year, monthIndex, day)).getUTCDay() !== 0) count += 1;
  }
  return count;
}

function normalizeMethod(value) {
  const method = String(value || 'mobile').toLowerCase();
  if (method === 'wifi' || method === 'office_wifi') return 'wifi';
  if (method === 'manual') return 'manual';
  return 'mobile';
}

function requireAdmin(req, res, next) {
  const userType = String((req.user && req.user.userType) || '').toLowerCase();
  if (userType !== 'admin') {
    return fail(res, 403, 'Admin access required');
  }
  return next();
}

async function breakMinutes(attendanceId) {
  try {
    const [rows] = await db.query(
      "SELECT COALESCE(SUM(duration_minutes), 0) AS minutes FROM attendance_breaks WHERE attendance_id = ? AND status IN ('completed', 'auto_closed')",
      [attendanceId]
    );
    return Number(rows[0].minutes || 0);
  } catch (error) {
    if (error.code === 'ER_NO_SUCH_TABLE') return 0;
    throw error;
  }
}

async function activeBreak(attendanceId) {
  const [rows] = await db.query(
    `SELECT id, started_at, exceeded_comment, exceeded_comment_at FROM attendance_breaks
     WHERE attendance_id = ? AND status = 'active'
     ORDER BY id DESC LIMIT 1`,
    [attendanceId]
  );
  return rows[0] || null;
}

async function recordAutomaticOvertime(employeeId, attendanceId, attendanceDate, workingMinutes) {
  await db.query(`CREATE TABLE IF NOT EXISTS hrms_overtime_entries (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, attendance_id BIGINT UNSIGNED NOT NULL,
    employee_user_id BIGINT UNSIGNED NOT NULL, attendance_date DATE NOT NULL,
    overtime_minutes INT UNSIGNED NOT NULL DEFAULT 0, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_overtime_attendance (attendance_id), KEY idx_overtime_employee_date (employee_user_id, attendance_date)
  )`);
  const [[profile]] = await db.query('SELECT gender, overtime_eligible FROM hrms_employee_profiles WHERE employee_user_id = ? LIMIT 1', [employeeId]);
  if (!profile || !Number(profile.overtime_eligible)) return;
  const schedules = await policy.getTimeSettings(db);
  const schedule = String(profile.gender).toLowerCase() === 'female' ? schedules.female : schedules.male;
  const requiredMinutes = shiftDurationMinutes(schedule.shiftStart, schedule.shiftEnd);
  const overtimeMinutes = Math.max(0, Number(workingMinutes || 0) - requiredMinutes);
  await db.query('INSERT INTO hrms_overtime_entries (attendance_id, employee_user_id, attendance_date, overtime_minutes) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE overtime_minutes = VALUES(overtime_minutes)', [attendanceId, employeeId, attendanceDate, overtimeMinutes]);
}

async function ensureOvertimeTable() {
  await db.query(`CREATE TABLE IF NOT EXISTS hrms_overtime_entries (id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, attendance_id BIGINT UNSIGNED NOT NULL, employee_user_id BIGINT UNSIGNED NOT NULL, attendance_date DATE NOT NULL, overtime_minutes INT UNSIGNED NOT NULL DEFAULT 0, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, UNIQUE KEY uq_overtime_attendance (attendance_id), KEY idx_overtime_employee_date (employee_user_id, attendance_date))`);
}

async function myOvertime(req, res) {
  try {
    await ensureOvertimeTable();
    const [rows] = await db.query(`SELECT DATE_FORMAT(o.attendance_date, '%d %b %Y') AS date_str, DATE_FORMAT(o.attendance_date, '%a') AS day_str, DATE_FORMAT(a.check_out_at, '%h:%i %p') AS actual_out, o.overtime_minutes, CONCAT(FLOOR(o.overtime_minutes / 60), 'h ', LPAD(MOD(o.overtime_minutes, 60), 2, '0'), 'm') AS hours_minutes FROM hrms_overtime_entries o LEFT JOIN attendance_records a ON a.id = o.attendance_id WHERE o.employee_user_id = ? AND o.overtime_minutes > 0 ORDER BY o.attendance_date DESC`, [req.user.id]);
    const minutes = rows.reduce((total, row) => total + Number(row.overtime_minutes || 0), 0);
    return ok(res, { rows: rows, metrics: { total_year: `${Math.floor(minutes / 60)}h ${minutes % 60}m`, this_month_hours: `${Math.floor(minutes / 60)}h ${minutes % 60}m`, this_month_detail: `${rows.length} automatic session(s)` } });
  } catch (error) { return fail(res, 500, error.message); }
}

async function overtimeHistory(req, res) {
  try {
    await ensureOvertimeTable();
    const [rows] = await db.query(`SELECT DATE_FORMAT(attendance_date, '%Y-%m-%d') AS attendance_date, overtime_minutes FROM hrms_overtime_entries WHERE employee_user_id = ? AND overtime_minutes > 0 ORDER BY attendance_date DESC`, [Number(req.params.employeeId)]);
    return ok(res, rows);
  } catch (error) { return fail(res, 500, error.message); }
}

function timeSeconds(value) {
  const parts = String(value || '').split(':').map(Number);
  return (parts[0] || 0) * 3600 + (parts[1] || 0) * 60 + (parts[2] || 0);
}

async function lunchWindowFor(employeeId) {
  const [[row]] = await db.query(
    `SELECT s.labour_lunch_start, s.labour_lunch_end,
            s.employee_lunch_start, s.employee_lunch_end, p.employee_type
     FROM hrms_tracking_settings s
     LEFT JOIN hrms_employee_profiles p ON p.employee_user_id = ?
     WHERE s.id = 1`,
    [employeeId]
  );
  const labour = row && String(row.employee_type) === 'Labour';
  return {
    start: String(labour ? row && row.labour_lunch_start : row && row.employee_lunch_start || '12:30:00'),
    end: String(labour ? row && row.labour_lunch_end : row && row.employee_lunch_end || '13:00:00'),
  };
}

async function persistedWorkedMinutes(record) {
  const stored = Number(record && record.working_minutes || 0);
  if (!record || !record.check_in_at || !record.check_out_at || stored > 0) return stored;
  const completedBreakMinutes = await breakMinutes(record.id);
  return Math.max(0,
    policy.minutesBetween(sqlDateTime(record.check_in_at), sqlDateTime(record.check_out_at)) - completedBreakMinutes);
}

async function getRecord(employeeId, date, executor = db, lock = false) {
  const [rows] = await executor.query(
    'SELECT * FROM attendance_records WHERE employee_id = ? AND attendance_date = ? LIMIT 1' + (lock ? ' FOR UPDATE' : ''),
    [employeeId, date]
  );
  return rows[0] || null;
}

function computeStatus(record) {
  if (!record || !record.check_in_at) {
    return record && record.attendance_status === 'on_leave' ? 'on_leave' : 'absent';
  }
  if (record.attendance_status === 'absent') return 'absent';
  const worked = Number(record.working_minutes || 0);
  if (record.check_out_at && policy.isEarlyExit(worked)) return 'early_exit';
  if (record.is_late) return 'late';
  return 'present';
}

function capitalize(value) {
  const text = String(value || '');
  return text.charAt(0).toUpperCase() + text.slice(1);
}

function serializeRecord(row, person) {
  const worked = Number(row.working_minutes || 0);
  return {
    id: row.id,
    employeeId: row.employee_id,
    employeeName: person ? person.full_name : null,
    staffId: person ? person.staff_id : null,
    role: person ? person.role : null,
    date: sqlDate(row.attendance_date),
    checkIn: policy.formatDisplayTime(sqlDateTime(row.check_in_at)),
    checkOut: policy.formatDisplayTime(sqlDateTime(row.check_out_at)),
    checkInAt: sqlDateTime(row.check_in_at),
    checkOutAt: sqlDateTime(row.check_out_at),
    method: row.check_in_method,
    isLate: Boolean(Number(row.is_late)),
    workingMinutes: worked,
    status: policy.displayStatus({
      status: row.attendance_status,
      isLate: Number(row.is_late),
      checkInAt: row.check_in_at,
      checkOutAt: row.check_out_at
    })
  };
}

async function dashboard(req, res) {
  try {
    const date = parseDateParam(req.query.date);
    if (!date) return fail(res, 400, 'date must be YYYY-MM-DD');

    const employees = await staff.listActiveStaff(db);
    const totalEmployees = employees.length;
    const ids = employees.map(function (row) { return row.id; });

    const [records] = ids.length
      ? await db.query('SELECT * FROM attendance_records WHERE attendance_date = ? AND employee_id IN (?)', [date, ids])
      : [[]];

    const recordByEmployee = new Map(records.map(function (row) { return [row.employee_id, row]; }));

    const [approvedLeave] = ids.length
      ? await db.query(
        "SELECT employee_id FROM attendance_permission_requests WHERE request_date = ? AND status = 'approved' AND request_type IN ('leave', 'risk_leave') AND employee_id IN (?)",
        [date, ids]
      )
      : [[]];
    const onLeave = new Set(approvedLeave.map(function (row) { return row.employee_id; }));

    let presentToday = 0;
    let lateLogins = 0;
    let absent = 0;
    let wifi = 0;
    const byRole = new Map();

    employees.forEach(function (person) {
      const roleName = person.role || 'Unassigned';
      if (!byRole.has(roleName)) byRole.set(roleName, { name: roleName, total: 0, present: 0 });
      const bucket = byRole.get(roleName);
      bucket.total += 1;

      const record = recordByEmployee.get(person.id);
      const checkedIn = Boolean(record && record.check_in_at);
      const markedAbsent = Boolean(record && record.attendance_status === 'absent');
      if (record && record.check_in_method === 'wifi') wifi += 1;
      if (checkedIn && Number(record.is_late) && !markedAbsent) lateLogins += 1;
      if (markedAbsent) {
        absent += 1;
      } else if (checkedIn && !Number(record.is_late)) {
        presentToday += 1;
        bucket.present += 1;
      } else if (checkedIn && Number(record.is_late)) {
        bucket.present += 1;
      } else if (!onLeave.has(person.id)) {
        absent += 1;
      }
    });

    const [pendingRows] = await db.query("SELECT COUNT(*) AS total FROM attendance_permission_requests WHERE status = 'pending'");
    const pendingRow = pendingRows[0];

    const weekDays = policy.weekdaysForDate(date);
    const weekly = [];
    for (var i = 0; i < weekDays.length; i++) {
      const day = weekDays[i];
      const [dayRows] = await db.query(
        'SELECT COUNT(DISTINCT CASE WHEN check_in_at IS NOT NULL THEN employee_id END) AS punched FROM attendance_records WHERE attendance_date = ?',
        [day]
      );
      const punched = Number(dayRows[0].punched || 0);
      weekly.push({
        day: policy.weekdayShort(day),
        date: day,
        presentPercent: totalEmployees ? Math.round((punched / totalEmployees) * 100) : 0
      });
    }

    const [activityPunches] = await db.query(
      'SELECT r.employee_id, s.' + staff.quote(staff.STAFF.name) + ' AS full_name, r.check_in_at, r.check_out_at, r.is_late, r.attendance_status, r.check_in_method FROM attendance_records r JOIN ' +
      staff.staffFrom() + ' s ON s.' + staff.quote(staff.STAFF.id) + ' = r.employee_id WHERE r.attendance_date = ? ORDER BY COALESCE(r.check_out_at, r.check_in_at) DESC LIMIT 20',
      [date]
    );

    const activity = [];
    activityPunches.forEach(function (row) {
      if (row.check_out_at) {
        activity.push({
          name: row.full_name,
          action: 'logged Out',
          time: policy.formatDisplayTime(row.check_out_at),
          status: 'Log Out'
        });
      }
      if (row.check_in_at) {
        const wifiLabel = row.check_in_method === 'wifi' ? ' (WIFI)' : '';
        const lateLabel = row.attendance_status === 'absent' ? ' (Absent)' : (Number(row.is_late) ? ' (Late)' : wifiLabel);
        activity.push({
          name: row.full_name,
          action: 'logged in' + lateLabel,
          time: policy.formatDisplayTime(row.check_in_at),
          status: 'Log In'
        });
      }
    });

    const [pendingPermissions] = await db.query(
      'SELECT p.id, p.request_type, p.request_date, p.status, p.reason, s.' + staff.quote(staff.STAFF.name) +
      ' AS full_name FROM attendance_permission_requests p JOIN ' + staff.staffFrom() +
      ' s ON s.' + staff.quote(staff.STAFF.id) + ' = p.employee_id ORDER BY p.created_at DESC LIMIT 20'
    );

    const [recentPermissions] = await db.query(
      'SELECT p.request_type, p.status, p.created_at, s.' + staff.quote(staff.STAFF.name) +
      ' AS full_name FROM attendance_permission_requests p JOIN ' + staff.staffFrom() +
      ' s ON s.' + staff.quote(staff.STAFF.id) + ' = p.employee_id ORDER BY p.created_at DESC LIMIT 8'
    );

    recentPermissions.forEach(function (row) {
      activity.push({
        name: row.full_name,
        action: 'requested ' + String(row.request_type).replace(/_/g, ' '),
        time: policy.formatDisplayTime(row.created_at),
        status: row.status === 'pending' ? 'Pending' : String(row.status)
      });
    });

    const departments = [];
    byRole.forEach(function (row) {
      departments.push({
        name: row.name,
        percentage: row.total ? Math.round((row.present / row.total) * 100) : 0
      });
    });

    return ok(res, {
      date: date,
      timezone: policy.TIME_ZONE,
      shift: {
        start: policy.SHIFT_START,
        end: policy.SHIFT_END,
        requiredHours: policy.REQUIRED_MINUTES / 60,
        lateAfter: policy.LATE_AFTER,
        absentAfter: policy.ABSENT_AFTER
      },
      metrics: {
        totalEmployees: totalEmployees,
        presentToday: presentToday,
        lateLogins: lateLogins,
        absent: absent,
        wifi: wifi,
        permissionPending: Number(pendingRow.total || 0)
      },
      weekly: weekly,
      departments: departments,
      activity: activity.slice(0, 12),
      pendingPermissions: pendingPermissions.map(function (row) {
        return {
          employee: row.full_name,
          type: String(row.request_type).replace(/_/g, ' '),
          date: row.request_date,
          status: capitalize(row.status)
        };
      }),
      log: records.map(function (row) {
        const person = employees.find(function (p) { return p.id === row.employee_id; });
        return serializeRecord(row, person);
      })
    });
  } catch (error) {
    console.error('GET /attendance/dashboard', error);
    return fail(res, 500, error.message);
  }
}

async function clockLogs(req, res) {
  try {
    const view = req.query.view === 'day' ? 'day' : 'month';
    let start, end;
    if (view === 'day') {
      const date = parseDateParam(req.query.date);
      if (!date) return fail(res, 400, 'date must be YYYY-MM-DD');
      start = date;
      end = date;
    } else {
      const month = parseMonthParam(req.query.month);
      if (!month) return fail(res, 400, 'month must be YYYY-MM');
      const parts = month.split('-').map(Number);
      const daysInMonth = new Date(Date.UTC(parts[0], parts[1], 0)).getUTCDate();
      start = month + '-01';
      end = month + '-' + String(daysInMonth).padStart(2, '0');
    }

    const employees = await staff.listActiveStaff(db);
    const employeeIdFilter = req.query.employeeId ? Number(req.query.employeeId) : null;
    const scopedEmployees = employeeIdFilter
      ? employees.filter(function (person) { return person.id === employeeIdFilter; })
      : employees;
    const ids = scopedEmployees.map(function (person) { return person.id; });

    const [records] = ids.length
      ? await db.query(
          'SELECT * FROM attendance_records WHERE attendance_date BETWEEN ? AND ? AND employee_id IN (?) ORDER BY attendance_date DESC, check_in_at DESC',
          [start, end, ids]
        )
      : [[]];

    await ensureOvertimeTable();
    const [overtimeRows] = ids.length
      ? await db.query('SELECT employee_user_id, DATE_FORMAT(attendance_date, \'%Y-%m-%d\') AS attendance_date, overtime_minutes FROM hrms_overtime_entries WHERE attendance_date BETWEEN ? AND ? AND employee_user_id IN (?)', [start, end, ids])
      : [[]];
    const overtimeMap = new Map(overtimeRows.map((row) => [String(row.employee_user_id) + '|' + row.attendance_date, Number(row.overtime_minutes || 0)]));
    const items = records
      .filter(function (row) { return row.check_in_at; })
      .map(function (row) {
        const person = scopedEmployees.find(function (p) { return p.id === row.employee_id; });
        const item = serializeRecord(row, person);
        item.overtimeMinutes = overtimeMap.get(String(row.employee_id) + '|' + item.date) || 0;
        return item;
      });

    return ok(res, {
      view: view,
      start: start,
      end: end,
      employees: scopedEmployees.map(function (person) {
        return {
          id: person.id,
          employeeId: person.id,
          employeeName: person.full_name,
          staffId: person.staff_id,
          role: person.role
        };
      }),
      items: items
    });
  } catch (error) {
    console.error('GET /attendance/clock-logs', error);
    return fail(res, 500, error.message);
  }
}

async function myHistory(req, res) {
  try {
    const month = parseMonthParam(req.query.month);
    if (!month) return fail(res, 400, 'month must be YYYY-MM');
    const employeeId = req.user.id;
    const start = month + '-01';

    const [rows] = await db.query(
      'SELECT * FROM attendance_records WHERE employee_id = ? AND attendance_date >= ? AND attendance_date < DATE_ADD(?, INTERVAL 1 MONTH) ORDER BY attendance_date DESC',
      [employeeId, start, start]
    );

    let present = 0;
    let absentCount = 0;
    let late = 0;
    let earlyExit = 0;

    const calendarData = {};
    const records = rows.map(function (row) {
      const item = serializeRecord(row);
      if (item.status === 'Present') present += 1;
      if (item.status === 'Absent') absentCount += 1;
      if (item.status === 'Late') late += 1;
      if (item.status === 'Early Exit') earlyExit += 1;

      calendarData[item.date] = {
        status: item.status,
        checkIn: item.checkIn,
        checkOut: item.checkOut,
        isLate: item.isLate,
        workingMinutes: item.workingMinutes
      };

      return item;
    });

    const [permissions] = await db.query(
      'SELECT * FROM attendance_permission_requests WHERE employee_id = ? AND request_date >= ? AND request_date < DATE_ADD(?, INTERVAL 1 MONTH) ORDER BY created_at DESC',
      [employeeId, start, start]
    );

    return ok(res, {
      month: month,
      summary: { present: present, absent: absentCount, late: late, earlyExit: earlyExit },
      calendarData: calendarData,
      records: records,
      requests: permissions.map(function (row) {
        return {
          id: row.id,
          type: String(row.request_type).replace(/_/g, ' '),
          date: row.request_date,
          reason: row.reason,
          status: capitalize(row.status)
        };
      })
    });
  } catch (error) {
    console.error('GET /attendance/me', error);
    return fail(res, 500, error.message);
  }
}

async function employeeDashboard(req, res) {
  try {
    const employeeId = req.user.id;
    const date = policy.todayIstDate();
    const month = parseMonthParam(req.query.month);
    if (!month) return fail(res, 400, 'month must be YYYY-MM');

    const people = await staff.listActiveStaff(db);
    const person = people.find(function (item) {
      return String(item.id) === String(employeeId);
    });
    if (!person) return fail(res, 403, 'Employee account is not active');

    const record = await getRecord(employeeId, date);
    const checkedIn = Boolean(record && record.check_in_at && !record.check_out_at);
    const checkedOut = Boolean(record && record.check_out_at);
    await ensureReclockRequestColumns();
    const [reclockRows] = checkedOut
      ? await db.query(
          `SELECT id, status, reclocked_at FROM attendance_permission_requests
           WHERE employee_id = ? AND request_date = ? AND request_type = 'reclock_in'
           ORDER BY created_at DESC LIMIT 1`,
          [employeeId, date]
        )
      : [[]];
    const latestReclockRequest = reclockRows[0] || null;
    const currentBreak = checkedIn ? await activeBreak(record.id) : null;
    const [completedBreakRows] = record && record.check_in_at
      ? await db.query(
          `SELECT id FROM attendance_breaks
           WHERE attendance_id = ? AND status IN ('completed', 'auto_closed')
           ORDER BY id DESC LIMIT 1`,
          [record.id]
        )
      : [[]];
    const lunchWindow = await lunchWindowFor(employeeId);
    const activeBreakMinutes = currentBreak
      ? Math.max(0, policy.minutesBetween(sqlDateTime(currentBreak.started_at), policy.nowIstDateTime()))
      : 0;
    const breakCommentRequired = Boolean(currentBreak) &&
      timeSeconds(policy.partsInZone().time) >= timeSeconds(lunchWindow.end) &&
      !String(currentBreak.exceeded_comment || '').trim();

    const [monthRows] = await db.query(
      `SELECT id, employee_id, attendance_date, check_in_at, check_out_at, is_late, attendance_status
       FROM attendance_records
       WHERE employee_id = ?
         AND attendance_date >= ?
         AND attendance_date <= LAST_DAY(?)
       ORDER BY attendance_date ASC`,
      [employeeId, month + '-01', month + '-01']
    );

    const presentDays = monthRows.filter(function (row) {
      return Boolean(row.check_in_at) && String(row.attendance_status) !== 'absent';
    }).length;

    const lateDays = monthRows.filter(function (row) {
      return Boolean(Number(row.is_late)) && String(row.attendance_status) !== 'absent';
    }).length;

    const absentDays = monthRows.filter(function (row) {
      return String(row.attendance_status) === 'absent';
    }).length;

    const timeSettings = await policy.getTimeSettings(db);
    const dailyTargetMinutes = shiftDurationMinutes(timeSettings.shiftStart, timeSettings.shiftEnd);
    const monthlyWorkingDays = workingDaysInMonth(month);
    const targetMinutes = dailyTargetMinutes * monthlyWorkingDays;
    const completedMinutes = await Promise.all(monthRows.map(persistedWorkedMinutes));
    let actualMinutes = completedMinutes.reduce(function (sum, minutes) {
      return sum + minutes;
    }, 0);

    // Keep a date-keyed representation as well as the list. Older employee
    // clients use the keyed form, while newer ones use month_records.
    const calendarData = {};
    const monthRecords = monthRows.map(function (row) {
      const item = {
        id: row.id,
        work_date: sqlDate(row.attendance_date),
        clock_in_at: row.check_in_at ? sqlDateTime(row.check_in_at) : null,
        clock_out_at: row.check_out_at ? sqlDateTime(row.check_out_at) : null,
        is_late: Boolean(Number(row.is_late)),
        attendance_status: row.attendance_status || (row.check_in_at ? 'present' : 'absent'),
      };
      calendarData[item.work_date] = item;
      return item;
    });

    // Admin calendar holidays are shared data, unlike the former browser-only
    // calendar setting. They override an empty attendance day for employees.
    await db.query(`CREATE TABLE IF NOT EXISTS hrms_calendar_overrides (
      calendar_date DATE NOT NULL PRIMARY KEY,
      status ENUM('Working Day', 'Weekly Off', 'Holiday') NOT NULL,
      scope VARCHAR(40) NOT NULL DEFAULT 'All Employees',
      reason VARCHAR(255) NOT NULL,
      updated_by INT NULL,
      updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )`);
    const [calendarOverrides] = await db.query(
      `SELECT DATE_FORMAT(calendar_date, '%Y-%m-%d') AS work_date, status
       FROM hrms_calendar_overrides
       WHERE calendar_date >= ? AND calendar_date <= LAST_DAY(?)`,
      [month + '-01', month + '-01']
    );
    calendarOverrides.forEach(function (override) {
      if (override.status === 'Holiday' && !calendarData[override.work_date]) {
        calendarData[override.work_date] = {
          work_date: override.work_date,
          status: 'holiday',
          attendance_status: 'holiday',
          is_late: false,
          clock_in_at: null,
          check_in_at: null,
        };
      }
    });

    let workedSeconds = Number(record && record.working_minutes || 0) * 60;
    if (checkedIn) {
      const completedBreakMinutes = await breakMinutes(record.id);
      const liveMinutes = Math.max(0,
        policy.minutesBetween(sqlDateTime(record.check_in_at), policy.nowIstDateTime()) - completedBreakMinutes);
      workedSeconds = liveMinutes * 60;
      if (month === date.slice(0, 7)) actualMinutes += liveMinutes;
    }

    return ok(res, {
      employee: { id: person.id, name: person.full_name, staff_id: person.staff_id },
      date: date,
      status: checkedIn ? 'checked_in' : (checkedOut ? 'checked_out' : 'not_checked_in'),
      session: record && record.check_in_at ? {
        id: record.id,
        work_date: sqlDate(record.attendance_date),
        punch_in: sqlDateTime(record.check_in_at),
        punch_out: sqlDateTime(record.check_out_at),
        clock_in_at: sqlDateTime(record.check_in_at),
        clock_out_at: sqlDateTime(record.check_out_at),
        worked_seconds: workedSeconds,
        is_late: Boolean(Number(record.is_late))
      } : null,
      actions: {
        can_clock_in: !record || !record.check_in_at ||
          (checkedOut && latestReclockRequest &&
            latestReclockRequest.status === 'approved' && !latestReclockRequest.reclocked_at),
        can_clock_out: checkedIn,
        can_reclock_in_request: checkedOut &&
          (!latestReclockRequest ||
            latestReclockRequest.status === 'rejected' ||
            Boolean(latestReclockRequest.reclocked_at))
      },
      reclock_in_request: latestReclockRequest ? {
        id: latestReclockRequest.id,
        status: capitalize(latestReclockRequest.status),
        reclocked_at: sqlDateTime(latestReclockRequest.reclocked_at)
      } : null,
      active_break: currentBreak ? {
        id: currentBreak.id,
        started_at: sqlDateTime(currentBreak.started_at),
        lunch_start: lunchWindow.start,
        lunch_end: lunchWindow.end,
        elapsed_minutes: activeBreakMinutes,
        comment_required: breakCommentRequired
      } : null,
      break_completed: completedBreakRows.length > 0,
      month_overview: {
        month: month,
        present_days: presentDays,
        absent_days: absentDays,
        late_days: lateDays,
        work_time: {
          actual_minutes: actualMinutes,
          target_minutes: targetMinutes,
          daily_target_minutes: dailyTargetMinutes,
          working_days: monthlyWorkingDays,
          overtime_minutes: Math.max(0, actualMinutes - targetMinutes),
          remaining_minutes: Math.max(0, targetMinutes - actualMinutes),
          shift_start: timeSettings.shiftStart,
          shift_end: timeSettings.shiftEnd,
          is_live: checkedIn && month === date.slice(0, 7)
        }
      },
      month_records: monthRecords,
      calendarData: calendarData
    });
  } catch (error) {
    console.error('GET /attendance/dashboard (employee)', error);
    return fail(res, 500, error.message);
  }
}

async function checkInPolicy(req, res) {
  try {
    const rules = await locationPolicy.getCheckInPolicy(db, req.user && req.user.id);
    return ok(res, {
      workMode: rules.workMode,
      requiresLocation: rules.requiresLocation,
      radiusMeters: rules.radiusMeters
    });
  } catch (error) {
    if (error instanceof locationPolicy.LocationPolicyError) return fail(res, error.status, error.message);
    console.error('GET /attendance/check-in-policy', error);
    return fail(res, 500, 'Unable to load Clock In location policy. Please try again.');
  }
}

async function checkIn(req, res) {
  let connection;
  try {
    if (!req.user || !req.user.id) return fail(res, 401, 'Unauthorized');
    const employeeId = req.user.id;
    const date = policy.todayIstDate();
    const at = policy.nowIstDateTime();
    const method = normalizeMethod((req.body && (req.body.method || req.body.check_in_method)));
    const [[profile]] = await db.query(
      'SELECT gender FROM hrms_employee_profiles WHERE employee_user_id = ? LIMIT 1',
      [employeeId]
    );
    const gender = profile && profile.gender ? profile.gender : 'Male';
    const late = policy.isLateCheckIn(at, gender);
    const absent = policy.isAbsentCheckIn(at, gender);
    await ensureReclockRequestColumns();
    connection = await db.getConnection();
    await connection.beginTransaction();
    const rules = await locationPolicy.getCheckInPolicy(connection, employeeId, true);
    let hybridTrackingActive = false;
    if (rules.workMode === 'Hybrid') {
      const [tracking] = await connection.query(
        'SELECT id FROM hrms_field_tracking_sessions WHERE employee_user_id = ? AND is_active = 1 ORDER BY id DESC LIMIT 1',
        [employeeId]
      );
      hybridTrackingActive = tracking.length > 0;
    }
    if (rules.workMode === 'Field') {
      const [tracking] = await connection.query(
        'SELECT id FROM hrms_field_tracking_sessions WHERE employee_user_id = ? AND is_active = 1 ORDER BY id DESC LIMIT 1',
        [employeeId]
      );
      if (!tracking.length) {
        throw new locationPolicy.LocationPolicyError(403, 'Start live tracking before clocking in as a Field employee.');
      }
    }
    if (!(rules.workMode === 'Hybrid' && hybridTrackingActive)) {
      locationPolicy.validateCheckIn(rules, req.body || {});
    }
    const existing = await getRecord(employeeId, date, connection, true);
    let approvedReclock = false;
    if (existing && existing.check_in_at) {
      const [approvedRequests] = existing.check_out_at
        ? await connection.query(
            `SELECT id FROM attendance_permission_requests
             WHERE employee_id = ? AND request_date = ?
               AND request_type = 'reclock_in' AND status = 'approved'
               AND reclocked_at IS NULL
             ORDER BY reviewed_at DESC LIMIT 1`,
            [employeeId, date]
          )
        : [[]];
      approvedReclock = approvedRequests.length > 0;
      if (!approvedReclock) {
        throw new locationPolicy.LocationPolicyError(409, 'Already checked in today');
      }
    }

    const status = absent ? 'absent' : (late ? 'late' : 'present');
    if (approvedReclock) {
      // Preserve the original check-in time. The employee resumes the same
      // workday and the duration is calculated from that original timestamp.
      await connection.query(
        `UPDATE attendance_records
         SET check_out_at = NULL, working_minutes = 0, session_status = 'active'
         WHERE id = ?`,
        [existing.id]
      );
      await connection.query(
        `UPDATE attendance_permission_requests
         SET reclocked_at = ?
         WHERE employee_id = ? AND request_date = ?
           AND request_type = 'reclock_in' AND status = 'approved'
           AND reclocked_at IS NULL`,
        [at, employeeId, date]
      );
    } else if (existing) {
      await connection.query(
        "UPDATE attendance_records SET check_in_at = ?, check_in_method = ?, is_late = ?, attendance_status = ?, session_status = 'active' WHERE id = ?",
        [at, method, late ? 1 : 0, status, existing.id]
      );
    } else {
      await connection.query(
        "INSERT INTO attendance_records (employee_id, attendance_date, check_in_at, check_in_method, is_late, attendance_status, session_status) VALUES (?, ?, ?, ?, ?, ?, 'active')",
        [employeeId, date, at, method, late ? 1 : 0, status]
      );
    }

    if (rules.requiresLocation) {
      await connection.query(
        `INSERT INTO hrms_employee_location_status (employee_user_id, status)
         VALUES (?, ?)
         ON DUPLICATE KEY UPDATE status = VALUES(status), updated_at = CURRENT_TIMESTAMP`,
        [employeeId, rules.workMode.toLowerCase()]
      );
    }
    const record = await getRecord(employeeId, date, connection);
    await connection.commit();
    return ok(res, serializeRecord(record), 'Checked in');
  } catch (error) {
    if (connection) await connection.rollback();
    if (error instanceof locationPolicy.LocationPolicyError) return fail(res, error.status, error.message);
    console.error('POST /attendance/check-in', error);
    return fail(res, 500, 'Unable to save Clock In. Please try again.');
  } finally {
    if (connection) connection.release();
  }
}

async function checkOut(req, res) {
  try {
    const employeeId = req.user.id;
    const date = policy.todayIstDate();
    const at = policy.nowIstDateTime();
    const record = await getRecord(employeeId, date);
    if (!record || !record.check_in_at) return fail(res, 409, 'Check in before checking out');
    if (record.check_out_at) return fail(res, 409, 'Already checked out today');

    await db.query(
      `UPDATE attendance_breaks
       SET ended_at = ?, duration_minutes = GREATEST(0, TIMESTAMPDIFF(MINUTE, started_at, ?)), status = 'auto_closed'
       WHERE attendance_id = ? AND status = 'active'`,
      [at, at, record.id]
    );
    const breaks = await breakMinutes(record.id);
    const rawMinutes = policy.minutesBetween(sqlDateTime(record.check_in_at), at);
    const workingMinutes = Math.max(0, rawMinutes - breaks);
    const status = computeStatus({
      check_in_at: record.check_in_at,
      check_out_at: at,
      working_minutes: workingMinutes,
      is_late: record.is_late,
      attendance_status: record.attendance_status
    });

    await db.query(
      "UPDATE attendance_records SET check_out_at = ?, working_minutes = ?, attendance_status = ?, session_status = 'completed' WHERE id = ?",
      [at, workingMinutes, status, record.id]
    );
    await recordAutomaticOvertime(employeeId, record.id, date, workingMinutes);

    await db.query(
      `UPDATE hrms_field_tracking_sessions
       SET is_active = 0,
           stopped_at = ?
       WHERE employee_user_id = ?
         AND is_active = 1`,
      [at, employeeId]
    );

    const updated = await getRecord(employeeId, date);
    return ok(res, serializeRecord(updated), 'Checked out');
  } catch (error) {
    console.error('POST /attendance/check-out', error);
    return fail(res, 500, error.message);
  }
}

async function startBreak(req, res) {
  try {
    const record = await getRecord(req.user.id, policy.todayIstDate());
    if (!record || !record.check_in_at || record.check_out_at) {
      return fail(res, 409, 'Clock in before starting a break.');
    }
    const existing = await activeBreak(record.id);
    if (existing) return fail(res, 409, 'A break is already active.');
    const [completed] = await db.query(
      `SELECT id FROM attendance_breaks
       WHERE attendance_id = ? AND status IN ('completed', 'auto_closed')
       LIMIT 1`,
      [record.id]
    );
    if (completed.length) return fail(res, 409, 'Today\'s break is already completed.');
    const startedAt = policy.nowIstDateTime();
    const lunchWindow = await lunchWindowFor(req.user.id);
    const currentTime = policy.partsInZone().time;
    if (timeSeconds(currentTime) < timeSeconds(lunchWindow.start) ||
        timeSeconds(currentTime) >= timeSeconds(lunchWindow.end)) {
      return fail(res, 409, `Lunch is available from ${lunchWindow.start.slice(0, 5)} to ${lunchWindow.end.slice(0, 5)}.`);
    }
    const [result] = await db.query(
      `INSERT INTO attendance_breaks (attendance_id, started_at, status)
       VALUES (?, ?, 'active')`,
      [record.id, startedAt]
    );
    return ok(res, { id: result.insertId, started_at: startedAt }, 'Break started.');
  } catch (error) {
    console.error('POST /attendance/break-in', error);
    return fail(res, 500, 'Unable to start break.');
  }
}

async function endBreak(req, res) {
  try {
    const record = await getRecord(req.user.id, policy.todayIstDate());
    if (!record || !record.check_in_at || record.check_out_at) {
      return fail(res, 409, 'There is no active attendance session.');
    }
    const current = await activeBreak(record.id);
    if (!current) return fail(res, 409, 'There is no active break.');
    const endedAt = policy.nowIstDateTime();
    const minutes = Math.max(0, policy.minutesBetween(sqlDateTime(current.started_at), endedAt));
    await db.query(
      `UPDATE attendance_breaks
       SET ended_at = ?, duration_minutes = ?, status = 'completed'
       WHERE id = ? AND status = 'active'`,
      [endedAt, minutes, current.id]
    );
    return ok(res, { id: current.id, ended_at: endedAt, duration_minutes: minutes }, 'Break ended.');
  } catch (error) {
    console.error('POST /attendance/break-out', error);
    return fail(res, 500, 'Unable to end break.');
  }
}

async function submitExceededBreakComment(req, res) {
  try {
    const comment = String((req.body && req.body.comment) || '').trim();
    if (comment.length < 3 || comment.length > 1000) {
      return fail(res, 400, 'Enter a break reason between 3 and 1000 characters.');
    }
    const record = await getRecord(req.user.id, policy.todayIstDate());
    if (!record || !record.check_in_at || record.check_out_at) {
      return fail(res, 409, 'There is no active attendance session.');
    }
    const current = await activeBreak(record.id);
    if (!current) return fail(res, 409, 'There is no active break.');
    const lunchWindow = await lunchWindowFor(req.user.id);
    if (timeSeconds(policy.partsInZone().time) < timeSeconds(lunchWindow.end)) {
      return fail(res, 409, 'The fixed lunch end time has not been reached.');
    }
    await db.query(
      `UPDATE attendance_breaks
       SET exceeded_comment = ?, exceeded_comment_at = ?
       WHERE id = ? AND status = 'active'`,
      [comment, policy.nowIstDateTime(), current.id]
    );
    return ok(res, { break_id: current.id }, 'Your break explanation was sent to Admin.');
  } catch (error) {
    console.error('POST /attendance/break-exceeded-comment', error);
    return fail(res, 500, 'Unable to submit your break explanation.');
  }
}

async function heartbeat(req, res) {
  try {
    const employeeId = req.user.id;
    const record = await getRecord(employeeId, policy.todayIstDate());
    if (!record || !record.check_in_at || record.check_out_at) {
      return fail(res, 409, 'There is no active work session.');
    }
    const completedBreakMinutes = await breakMinutes(record.id);
    const workingMinutes = Math.max(0,
      policy.minutesBetween(sqlDateTime(record.check_in_at), policy.nowIstDateTime()) - completedBreakMinutes);
    await db.query(
      "UPDATE attendance_records SET working_minutes = ? WHERE id = ? AND check_out_at IS NULL",
      [workingMinutes, record.id]
    );
    return ok(res, { attendance_id: record.id, working_minutes: workingMinutes });
  } catch (error) {
    console.error('POST /attendance/heartbeat', error);
    return fail(res, 500, 'Unable to save current work time.');
  }
}

async function myPermissions(req, res) {
  try {
    const [rows] = await db.query(
      'SELECT * FROM attendance_permission_requests WHERE employee_id = ? ORDER BY created_at DESC LIMIT 50',
      [req.user.id]
    );
    return ok(res, rows.map(function (row) {
      return {
        id: row.id,
        type: String(row.request_type).replace(/_/g, ' '),
        date: row.request_date,
        start_time: row.permission_start_time || null,
        end_time: row.permission_end_time || null,
        reason: row.reason,
        status: capitalize(row.status)
      };
    }));
  } catch (error) {
    console.error('GET /attendance/permissions/mine', error);
    return fail(res, 500, error.message);
  }
}

async function ensurePermissionTimeColumns() {
  const [startColumns] = await db.query("SHOW COLUMNS FROM attendance_permission_requests LIKE 'permission_start_time'");
  if (!startColumns.length) {
    await db.query('ALTER TABLE attendance_permission_requests ADD COLUMN permission_start_time TIME NULL AFTER request_date');
  }
  const [endColumns] = await db.query("SHOW COLUMNS FROM attendance_permission_requests LIKE 'permission_end_time'");
  if (!endColumns.length) {
    await db.query('ALTER TABLE attendance_permission_requests ADD COLUMN permission_end_time TIME NULL AFTER permission_start_time');
  }
}

async function createPermission(req, res) {
  try {
    const type = String((req.body && (req.body.type || req.body.request_type)) || '').toLowerCase().replace(/\s+/g, '_');
    const allowed = { leave: 1, late_entry: 1, early_exit: 1, risk_leave: 1, permission: 1 };
    if (!allowed[type]) return fail(res, 400, 'type must be leave, late_entry, early_exit, risk_leave, or permission');
    const date = parseDateParam(req.body && (req.body.date || req.body.request_date));
    if (!date) return fail(res, 400, 'date must be YYYY-MM-DD');
    const reason = String((req.body && req.body.reason) || '').trim();
    const startTime = String((req.body && req.body.start_time) || '').trim();
    const endTime = String((req.body && req.body.end_time) || '').trim();
    if (type === 'permission' && (!/^\d{2}:\d{2}$/.test(startTime) || !/^\d{2}:\d{2}$/.test(endTime) || startTime >= endTime)) {
      return fail(res, 400, 'Permission start and end times are required, and the end time must be later');
    }

    await ensurePermissionTimeColumns();

    const [result] = await db.query(
      "INSERT INTO attendance_permission_requests (employee_id, request_type, request_date, permission_start_time, permission_end_time, reason, status) VALUES (?, ?, ?, ?, ?, ?, 'pending')",
      [req.user.id, type, date, type === 'permission' ? startTime + ':00' : null, type === 'permission' ? endTime + ':00' : null, reason || null]
    );
    return ok(res, { id: result.insertId, type: type, date: date, start_time: startTime || null, end_time: endTime || null, reason: reason, status: 'Pending' }, 'Request submitted');
  } catch (error) {
    console.error('POST /attendance/permissions', error);
    return fail(res, 500, error.message);
  }
}

// A completed same-day attendance session can be reopened only after an Admin
// approves this request.  The saved timestamps are included in the request
// reason so the existing Approvals screen can show the full context without a
// second approval UI or a schema change.
async function createReclockInRequest(req, res) {
  try {
    const employeeId = req.user.id;
    const date = policy.todayIstDate();
    const reason = String((req.body && req.body.reason) || '').trim();
    if (reason.length < 3 || reason.length > 350) {
      return fail(res, 400, 'Enter a reason between 3 and 350 characters.');
    }
    await ensureReclockRequestColumns();
    const record = await getRecord(employeeId, date);
    if (!record || !record.check_in_at || !record.check_out_at) {
      return fail(res, 409, 'A completed Clock Out is required before requesting another Clock In.');
    }
    const [pending] = await db.query(
      `SELECT id FROM attendance_permission_requests
       WHERE employee_id = ? AND request_date = ? AND request_type = 'reclock_in' AND status = 'pending'
       LIMIT 1`,
      [employeeId, date]
    );
    if (pending.length) return fail(res, 409, 'Your Clock In request is already awaiting Admin approval.');

    const details = [
      reason,
      '',
      'Original Clock In: ' + sqlDateTime(record.check_in_at),
      'Original Clock Out: ' + sqlDateTime(record.check_out_at),
      'Attendance date: ' + date
    ].join('\n');
    const [result] = await db.query(
      `INSERT INTO attendance_permission_requests
       (employee_id, request_type, request_date, reason, status)
       VALUES (?, 'reclock_in', ?, ?, 'pending')`,
      [employeeId, date, details]
    );
    return ok(res, { id: result.insertId, date: date, status: 'Pending' }, 'Clock In request sent to Admin.');
  } catch (error) {
    console.error('POST /attendance/reclock-in-request', error);
    return fail(res, 500, 'Unable to send Clock In request. Please try again.');
  }
}

async function ensureReclockRequestColumns(connection) {
  const client = connection || db;
  const [columns] = await client.query(
    "SHOW COLUMNS FROM attendance_permission_requests LIKE 'reclocked_at'"
  );
  if (!columns.length) {
    await client.query(
      'ALTER TABLE attendance_permission_requests ADD COLUMN reclocked_at DATETIME NULL AFTER reviewed_at'
    );
  }
}

async function adminPermissions(req, res) {
  try {
    const status = String(req.query.status || '').toLowerCase();
    const params = [];
    let where = '1=1';
    if (status && status !== 'all') {
      where += ' AND p.status = ?';
      params.push(status);
    }
    const [rows] = await db.query(
      'SELECT p.*, s.' + staff.quote(staff.STAFF.name) + ' AS full_name FROM attendance_permission_requests p JOIN ' +
      staff.staffFrom() + ' s ON s.' + staff.quote(staff.STAFF.id) + ' = p.employee_id WHERE ' + where +
      ' ORDER BY p.created_at DESC LIMIT 100',
      params
    );
    return ok(res, rows.map(function (row) {
      return {
        id: row.id,
        employee: row.full_name,
        type: String(row.request_type).replace(/_/g, ' '),
        date: row.request_date,
        reason: row.reason,
        status: capitalize(row.status)
      };
    }));
  } catch (error) {
    console.error('GET /attendance/permissions', error);
    return fail(res, 500, error.message);
  }
}

async function reviewPermission(req, res) {
  try {
    const id = Number(req.params.id);
    const status = String((req.body && req.body.status) || '').toLowerCase();
    if (status !== 'approved' && status !== 'rejected') return fail(res, 400, 'status must be approved or rejected');
    const at = policy.nowIstDateTime();
    const [result] = await db.query(
      "UPDATE attendance_permission_requests SET status = ?, reviewed_by = ?, reviewed_at = ? WHERE id = ? AND status = 'pending'",
      [status, req.user.id, at, id]
    );
    if (!result.affectedRows) return fail(res, 404, 'Pending request not found');
    return ok(res, { id: id, status: capitalize(status) }, 'Request updated');
  } catch (error) {
    console.error('PATCH /attendance/permissions/:id', error);
    return fail(res, 500, error.message);
  }
}

async function exportCsv(req, res) {
  try {
    const date = parseDateParam(req.query.date);
    if (!date) return fail(res, 400, 'date must be YYYY-MM-DD');
    const employees = await staff.listActiveStaff(db);
    const [records] = await db.query('SELECT * FROM attendance_records WHERE attendance_date = ?', [date]);
    const byId = new Map(records.map(function (row) { return [row.employee_id, row]; }));
    const lines = ['Employee,Staff ID,Role,Check In,Check Out,Method,Status,Working Minutes'];
    employees.forEach(function (person) {
      const row = byId.get(person.id);
      const item = row ? serializeRecord(row, person) : {
        checkIn: '-', checkOut: '-', method: '', status: 'Absent', workingMinutes: 0
      };
      const cols = [person.full_name, person.staff_id, person.role, item.checkIn, item.checkOut, item.method || '', item.status, item.workingMinutes];
      lines.push(cols.map(function (value) {
        return '"' + String(value == null ? '' : value).replace(/"/g, '""') + '"';
      }).join(','));
    });
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', 'attachment; filename="attendance-' + date + '.csv"');
    return res.send(lines.join('\n'));
  } catch (error) {
    console.error('GET /attendance/export', error);
    return fail(res, 500, error.message);
  }
}

async function myExport(req, res) {
  try {
    const month = parseMonthParam(req.query.month);
    if (!month) return fail(res, 400, 'month must be YYYY-MM');
    const [rows] = await db.query(
      'SELECT * FROM attendance_records WHERE employee_id = ? AND attendance_date >= ? AND attendance_date < DATE_ADD(?, INTERVAL 1 MONTH) ORDER BY attendance_date ASC',
      [req.user.id, month + '-01', month + '-01']
    );
    const lines = ['Date,Check In,Check Out,Status'];
    rows.forEach(function (row) {
      const item = serializeRecord(row);
      lines.push([item.date, item.checkIn, item.checkOut, item.status].join(','));
    });
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', 'attachment; filename="my-attendance-' + month + '.csv"');
    return res.send(lines.join('\n'));
  } catch (error) {
    console.error('GET /attendance/me/export', error);
    return fail(res, 500, error.message);
  }
}

module.exports = {
  requireAdmin: requireAdmin,
  dashboard: dashboard,
  clockLogs: clockLogs,
  myOvertime: myOvertime,
  overtimeHistory: overtimeHistory,
  employeeDashboard: employeeDashboard,
  myHistory: myHistory,
  checkInPolicy: checkInPolicy,
  checkIn: checkIn,
  checkOut: checkOut,
  startBreak: startBreak,
  endBreak: endBreak,
  submitExceededBreakComment: submitExceededBreakComment,
  heartbeat: heartbeat,
  myPermissions: myPermissions,
  createPermission: createPermission,
  createReclockInRequest: createReclockInRequest,
  adminPermissions: adminPermissions,
  reviewPermission: reviewPermission,
  exportCsv: exportCsv,
  myExport: myExport
};
