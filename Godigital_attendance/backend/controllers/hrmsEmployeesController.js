const db = require('../config/db');
const bcrypt = require('bcrypt');
const workingDays = require('../lib/workingDaysTemplates');

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

function modeColor(mode) {
  if (mode === 'Home') return 0xFF0B8B16;
  if (mode === 'Field') return 0xFF16B9C5;
  return 0xFF0668F6;
}

function formatSalary(value) {
  if (value === null || value === undefined || value === '') return 'Not Set';
  const amount = Number(value);
  if (!Number.isFinite(amount)) return 'Not Set';
  return '₹' + Math.round(amount).toLocaleString('en-US');
}

function parseSalary(value) {
  if (value === null || value === undefined || value === '' || value === 'Not Set') return null;
  const digits = String(value).replace(/[^0-9]/g, '');
  if (!digits) return null;
  return Number(digits);
}

function salaryCycle(body) {
  const salaryType = String(body.salaryType || body.salary_type || 'Standard').trim();
  if (!['Standard', 'Flexible'].includes(salaryType)) {
    return { error: 'salaryType must be Standard or Flexible' };
  }
  if (salaryType === 'Standard') return { salaryType: salaryType, cycleStartDay: null, cycleEndDay: null };
  const cycleStartDay = Number(body.flexibleCycleStartDay || body.flexible_cycle_start_day);
  const cycleEndDay = Number(body.flexibleCycleEndDay || body.flexible_cycle_end_day);
  if (!Number.isInteger(cycleStartDay) || cycleStartDay < 1 || cycleStartDay > 31 ||
      !Number.isInteger(cycleEndDay) || cycleEndDay < 1 || cycleEndDay > 31) {
    return { error: 'Flexible salary requires cycle start and end days from 1 to 31' };
  }
  return { salaryType: salaryType, cycleStartDay: cycleStartDay, cycleEndDay: cycleEndDay };
}

async function recordCompensation(profile, salary, adminId) {
  if (salary === null || salary === undefined) return;
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
  const [latest] = await db.query(`SELECT monthly_salary FROM hrms_employee_compensation WHERE profile_id = ? ORDER BY effective_from DESC, id DESC LIMIT 1`, [profile.id]);
  if (latest[0] && Number(latest[0].monthly_salary) === Number(salary)) return;
  await db.query(`INSERT INTO hrms_employee_compensation (profile_id, employee_user_id, monthly_salary, effective_from, created_by)
    VALUES (?, ?, ?, CURDATE(), ?)`, [profile.id, profile.employee_user_id || null, salary, adminId || null]);
}

function toUi(row) {
    return {
    id: row.id,
    name: row.full_name,
    employeeCode: row.employee_code,
    employeeId: row.employee_code,
    department: row.department,
    workMode: row.work_mode,
    employeeType: row.employee_type || 'Employee',
    workingDaysType: row.working_days_type || 'Standard Working Days',
    overtimeEligible: Boolean(Number(row.overtime_eligible || 0)),
    gender: row.gender || 'Male',
    salary: formatSalary(row.monthly_salary),
    monthlySalary: row.monthly_salary,
    salaryType: row.salary_type || 'Standard',
    flexibleCycleStartDay: row.flexible_cycle_start_day == null ? null : Number(row.flexible_cycle_start_day),
    flexibleCycleEndDay: row.flexible_cycle_end_day == null ? null : Number(row.flexible_cycle_end_day),
    status: row.employment_status,
    modeColor: modeColor(row.work_mode),
      email: row.email || '',
    username: row.username || '',
    passwordLastChangedAt: row.password_last_changed_at || null,
    employeeUserId: row.employee_user_id
  };
}

async function summary(req, res) {
  try {
    const [rows] = await db.query(
      "SELECT COUNT(*) AS total, SUM(p.employment_status = 'Active') AS active, SUM(p.employment_status = 'On Leave') AS onLeave, SUM(p.employment_status = 'Inactive') AS inactive FROM hrms_employee_profiles p INNER JOIN employee_users u ON u.id = p.employee_user_id WHERE u.is_active = 1"
    );
    const row = rows[0];
    return ok(res, {
      total: Number(row.total || 0),
      active: Number(row.active || 0),
      onLeave: Number(row.onLeave || 0),
      inactive: Number(row.inactive || 0)
    });
  } catch (error) {
    return fail(res, 500, error.message);
  }
}

async function list(req, res) {
  try {
    await db.query(`CREATE TABLE IF NOT EXISTS hrms_password_change_log (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, employee_user_id BIGINT UNSIGNED NOT NULL,
      changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, changed_by VARCHAR(30) NOT NULL DEFAULT 'employee',
      KEY password_changed_employee (employee_user_id, changed_at)
    )`);
    const search = String(req.query.search || req.query.query || '').trim();
    const department = String(req.query.department || '').trim();
    const status = String(req.query.status || '').trim();
    const workMode = String(req.query.workMode || req.query.work_mode || '').trim();
    const page = Math.max(1, Number(req.query.page || 1));
    const limit = Math.min(50, Math.max(1, Number(req.query.limit || 6)));
    // Deleted employees are safely deactivated, not hard-deleted, so their
    // historical attendance and payroll records remain intact. They are not
    // part of active Employee Management or dashboard lists.
    const where = ["u.user_type = 'employee'", 'u.is_active = 1'];
    const params = [];

    if (search) {
      where.push('(full_name LIKE ? OR employee_code LIKE ? OR email LIKE ?)');
      const like = '%' + search + '%';
      params.push(like, like, like);
    }
    if (department && department !== 'All Departments') {
      where.push('department = ?');
      params.push(department);
    }
    if (status && status !== 'All Status') {
      where.push('employment_status = ?');
      params.push(status);
    }
    if (workMode && workMode !== 'All Work Modes') {
      where.push('work_mode = ?');
      params.push(workMode);
    }

    const clause = where.length ? 'WHERE ' + where.join(' AND ') : '';
    const [countRows] = await db.query('SELECT COUNT(*) AS total FROM hrms_employee_profiles p INNER JOIN employee_users u ON u.id = p.employee_user_id ' + clause.replace(/\b(full_name|employee_code|email|department|employment_status|work_mode)\b/g, 'p.$1'), params);
    const total = Number(countRows[0].total || 0);
    const totalPages = Math.max(1, Math.ceil(total / limit));
    const safePage = Math.min(page, totalPages);
    const offset = (safePage - 1) * limit;

    const [rows] = await db.query(
      "SELECT p.*, u.username AS username, COALESCE((SELECT t.name FROM hrms_employee_working_day_assignments a JOIN hrms_working_day_templates t ON t.id = a.template_id WHERE a.profile_id = p.id AND a.effective_from <= CURDATE() AND (a.effective_to IS NULL OR a.effective_to >= CURDATE()) ORDER BY a.effective_from DESC, a.id DESC LIMIT 1), 'Standard Working Days') AS working_days_type, (SELECT MAX(changed_at) FROM hrms_password_change_log l WHERE l.employee_user_id = p.employee_user_id) AS password_last_changed_at FROM hrms_employee_profiles p LEFT JOIN employee_users u ON u.id = p.employee_user_id " + clause.replace(/\b(full_name|employee_code|email|department|employment_status|work_mode)\b/g, 'p.$1') + ' ORDER BY p.full_name ASC LIMIT ? OFFSET ?',
      params.concat([limit, offset])
    );
    const [allRows] = await db.query("SELECT p.employment_status FROM hrms_employee_profiles p INNER JOIN employee_users u ON u.id = p.employee_user_id WHERE u.user_type = 'employee' AND u.is_active = 1");
    // Roles are managed in the main admin area while older HRMS records keep
    // their designation in `department`.  Combining both sources keeps this
    // filter current as soon as an admin creates a role or employee.
   const [departmentRows] = await db.query(
  "SELECT DISTINCT CONVERT(role_name USING utf8mb4) COLLATE utf8mb4_unicode_ci AS name " +
  "FROM user_roles WHERE TRIM(COALESCE(role_name, '')) <> '' " +
  "UNION " +
  "SELECT DISTINCT CONVERT(role USING utf8mb4) COLLATE utf8mb4_unicode_ci AS name " +
  "FROM employee_users WHERE TRIM(COALESCE(role, '')) <> '' " +
  "UNION " +
  "SELECT DISTINCT CONVERT(department USING utf8mb4) COLLATE utf8mb4_unicode_ci AS name " +
  "FROM hrms_employee_profiles WHERE TRIM(COALESCE(department, '')) <> '' " +
  "ORDER BY name ASC"
);
    const [employeeTypeRows] = await db.query(
      "SELECT DISTINCT employee_type AS name FROM hrms_employee_profiles WHERE TRIM(COALESCE(employee_type, '')) <> '' ORDER BY name ASC"
    );
    const [[codeRow]] = await db.query(
      "SELECT COALESCE(MAX(CAST(SUBSTRING(employee_code, 4) AS UNSIGNED)), 1000) AS max_code FROM hrms_employee_profiles WHERE employee_code REGEXP '^EMP[0-9]+$'"
    );

    return ok(res, {
      items: rows.map(toUi),
      page: safePage,
      limit: limit,
      total: total,
      totalPages: totalPages,
      departments: departmentRows.map(function (row) { return row.name; }),
      employeeTypes: Array.from(new Set(['Employee', 'Labour'].concat(employeeTypeRows.map(function (row) { return row.name; })))),
      nextEmployeeCode: 'EMP' + String(Number(codeRow && codeRow.max_code || 1000) + 1).padStart(4, '0'),
      kpis: {
        total: allRows.length,
        active: allRows.filter(function (r) { return r.employment_status === 'Active'; }).length,
        onLeave: allRows.filter(function (r) { return r.employment_status === 'On Leave'; }).length,
        inactive: allRows.filter(function (r) { return r.employment_status === 'Inactive'; }).length
      }
    });
  } catch (error) {
    return fail(res, 500, error.message);
  }
}

async function detail(req, res) {
  try {
    const id = Number(req.params.id);
    const [[profile]] = await db.query(
      `SELECT p.*, u.username,
       COALESCE((SELECT t.name FROM hrms_employee_working_day_assignments a
         JOIN hrms_working_day_templates t ON t.id = a.template_id
         WHERE a.profile_id = p.id AND a.effective_from <= CURDATE()
           AND (a.effective_to IS NULL OR a.effective_to >= CURDATE())
         ORDER BY a.effective_from DESC, a.id DESC LIMIT 1), 'Standard Working Days') AS working_days_type
       FROM hrms_employee_profiles p
       LEFT JOIN employee_users u ON u.id = p.employee_user_id WHERE p.id = ?`,
      [id]
    );
    if (!profile) return fail(res, 404, 'Employee not found');
    const employeeId = Number(profile.employee_user_id || 0);
    const [[attendance]] = await db.query(
      `SELECT
        SUM(CASE WHEN check_in_at IS NOT NULL AND attendance_status <> 'absent' THEN 1 ELSE 0 END) AS present,
        SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END) AS late,
        SUM(CASE WHEN attendance_status = 'absent' THEN 1 ELSE 0 END) AS absent
       FROM attendance_records WHERE employee_id = ?
         AND attendance_date >= DATE_FORMAT(CURDATE(), '%Y-%m-01')
         AND attendance_date < DATE_ADD(DATE_FORMAT(CURDATE(), '%Y-%m-01'), INTERVAL 1 MONTH)`,
      [employeeId]
    );
    const [[leave]] = await db.query(
      `SELECT COUNT(*) AS total, SUM(status = 'approved') AS approved, SUM(status = 'pending') AS pending
       FROM employee_leaves WHERE employee_id = ?
         AND from_date >= DATE_FORMAT(CURDATE(), '%Y-%m-01')`,
      [employeeId]
    );
    const [[payroll]] = await db.query(
      `SELECT working_days, paid_days, lop_days, deductions, late_deductions,
              absent_deductions, net_pay, status
       FROM hrms_payroll_items WHERE profile_id = ?
       ORDER BY pay_year DESC, pay_month DESC LIMIT 1`,
      [id]
    );
    const [attendanceRows] = await db.query(
      `SELECT DATE_FORMAT(a.attendance_date, '%a, %d %b') AS date,
              DATE_FORMAT(a.check_in_at, '%h:%i %p') AS check_in,
              DATE_FORMAT(a.check_out_at, '%h:%i %p') AS check_out,
              CONCAT(FLOOR(COALESCE(a.working_minutes, 0) / 60), 'h ',
                     LPAD(MOD(COALESCE(a.working_minutes, 0), 60), 2, '0'), 'm') AS worked,
              DATE_FORMAT(MIN(b.started_at), '%h:%i %p') AS break_start,
              DATE_FORMAT(MAX(b.ended_at), '%h:%i %p') AS break_end,
              CONCAT(FLOOR(COALESCE(SUM(b.duration_minutes), 0) / 60), 'h ',
                     LPAD(MOD(COALESCE(SUM(b.duration_minutes), 0), 60), 2, '0'), 'm') AS break_duration,
              CASE WHEN a.attendance_status = 'absent' THEN 'Absent'
                   WHEN a.attendance_status = 'on_leave' THEN 'On leave'
                   WHEN a.attendance_status = 'half_leave' THEN 'Half leave'
                   WHEN a.is_late = 1 THEN 'Late' ELSE 'Present' END AS status,
              CASE WHEN a.attendance_status = 'absent' THEN 'Yes' ELSE 'No' END AS lop,
              COALESCE(a.check_in_method, '-') AS method,
              a.clock_out_reason,
              a.tracking_stop_reason
       FROM attendance_records a
       LEFT JOIN attendance_breaks b ON b.attendance_id = a.id
         AND b.status IN ('completed', 'auto_closed')
       WHERE a.employee_id = ?
         AND a.attendance_date >= DATE_FORMAT(CURDATE(), '%Y-%m-01')
         AND a.attendance_date < DATE_ADD(DATE_FORMAT(CURDATE(), '%Y-%m-01'), INTERVAL 1 MONTH)
       GROUP BY a.id, a.attendance_date, a.check_in_at, a.check_out_at,
                a.working_minutes, a.attendance_status, a.is_late, a.check_in_method
       ORDER BY a.attendance_date ASC`,
      [employeeId]
    );
    const [leaveRows] = await db.query(
      `SELECT leave_type, duration_type, DATE_FORMAT(from_date, '%d %b %Y') AS from_date,
              DATE_FORMAT(to_date, '%d %b %Y') AS to_date, days_count, reason, status
       FROM employee_leaves
       WHERE employee_id = ? AND from_date < DATE_ADD(DATE_FORMAT(CURDATE(), '%Y-%m-01'), INTERVAL 1 MONTH)
         AND to_date >= DATE_FORMAT(CURDATE(), '%Y-%m-01')
       ORDER BY from_date DESC`,
      [employeeId]
    );
    const [permissionRows] = await db.query(
      `SELECT request_type, DATE_FORMAT(request_date, '%d %b %Y') AS request_date,
              TIME_FORMAT(permission_start_time, '%h:%i %p') AS start_time,
              TIME_FORMAT(permission_end_time, '%h:%i %p') AS end_time, reason, status
       FROM attendance_permission_requests
       WHERE employee_id = ? AND request_date >= DATE_FORMAT(CURDATE(), '%Y-%m-01')
         AND request_date < DATE_ADD(DATE_FORMAT(CURDATE(), '%Y-%m-01'), INTERVAL 1 MONTH)
       ORDER BY request_date DESC`,
      [employeeId]
    );
    const [payrollHistoryRows] = await db.query(
      `SELECT pay_year, pay_month, monthly_salary, working_days, paid_days, lop_days,
              late_deductions, absent_deductions, deductions, net_pay, status
       FROM hrms_payroll_items WHERE profile_id = ?
       ORDER BY pay_year DESC, pay_month DESC LIMIT 6`,
      [id]
    );
    return ok(res, {
      employee: toUi(profile),
      attendance: {
        present: Number(attendance.present || 0), late: Number(attendance.late || 0), absent: Number(attendance.absent || 0),
      },
      leave: { total: Number(leave.total || 0), approved: Number(leave.approved || 0), pending: Number(leave.pending || 0) },
      payroll: payroll ? {
        workingDays: Number(payroll.working_days || 0), paidDays: Number(payroll.paid_days || 0),
        lopDays: Number(payroll.lop_days || 0),
        lateDeduction: Number(payroll.late_deductions || payroll.deductions || 0),
        absentDeduction: Number(payroll.absent_deductions || 0),
        totalDeduction: Number(payroll.late_deductions || payroll.deductions || 0) + Number(payroll.absent_deductions || 0),
        netPay: Number(payroll.net_pay || 0), status: payroll.status,
      } : null,
      attendanceRows: attendanceRows.map(function (row) {
        return Object.assign({}, row, {
          check_in: row.check_in || '-', check_out: row.check_out || '-',
          break_start: row.break_start || '-', break_end: row.break_end || '-'
        });
      }),
      leaveRows: leaveRows,
      permissionRows: permissionRows,
      payrollHistory: payrollHistoryRows.map(function (row) {
        const late = Number(row.late_deductions || row.deductions || 0);
        const absent = Number(row.absent_deductions || 0);
        return {
          month: new Date(Number(row.pay_year), Number(row.pay_month) - 1, 1).toLocaleString('en-US', { month: 'long', year: 'numeric' }),
          salary: Number(row.monthly_salary || 0), workingDays: Number(row.working_days || 0),
          paidDays: Number(row.paid_days || 0), lopDays: Number(row.lop_days || 0),
          lateDeduction: late, absentDeduction: absent, totalDeduction: late + absent,
          netPay: Number(row.net_pay || 0), status: row.status
        };
      })
    });
  } catch (error) {
    return fail(res, 500, error.message);
  }
}

async function create(req, res) {
  let connection;
  let createdUserId = null;
  let createdProfileId = null;
  try {
    const body = req.body || {};
    const name = String(body.name || body.full_name || '').trim();
    const code = String(body.employeeCode || body.employee_code || body.id || '').trim();
    const department = String(body.department || 'Engineering').trim();
    const workMode = String(body.workMode || body.work_mode || 'Office').trim();
    const employeeType = String(body.employeeType || body.employee_type || 'Employee').trim();
    const overtimeEligible = body.overtimeEligible || body.overtime_eligible ? 1 : 0;
    if (!employeeType || employeeType.length > 100) return fail(res, 400, 'Employee type is required and must be 100 characters or fewer');
    const gender = String(body.gender || 'Male').trim();
    if (!['Male', 'Female'].includes(gender)) return fail(res, 400, 'Gender must be Male or Female');
    const status = String(body.status || body.employment_status || 'Active').trim();
    const salary = parseSalary(body.salary || body.monthly_salary);
    const cycle = salaryCycle(body);
    if (cycle.error) return fail(res, 400, cycle.error);
    const username = String(body.username || '').trim();
    const password = String(body.password || '');
    const email = String(body.email || '').trim() || null;
    if (!name || !code) return fail(res, 400, 'name and employeeCode are required');
    if (!username || !email || password.length < 8) return fail(res, 400, 'username, email and a password of at least 8 characters are required');

    // Reject duplicates before writing anything. This prevents the old
    // behaviour where the login row was created before profile validation.
    const [duplicates] = await db.query(`
      SELECT
        EXISTS(SELECT 1 FROM employee_users WHERE LOWER(username) = LOWER(?) OR LOWER(email) = LOWER(?)) AS login_duplicate,
        EXISTS(SELECT 1 FROM hrms_employee_profiles WHERE employee_code = ?) AS code_duplicate,
        EXISTS(SELECT 1 FROM employee_users WHERE staff_id = ?) AS staff_duplicate`,
      [username, email, code, code]);
    if (duplicates[0] && Number(duplicates[0].login_duplicate)) {
      const [existing] = await db.query('SELECT username, email FROM employee_users WHERE LOWER(username) = LOWER(?) OR LOWER(email) = LOWER(?) LIMIT 1', [username, email]);
      if (existing[0] && String(existing[0].username).toLowerCase() === username.toLowerCase()) return fail(res, 409, 'Username already exists');
      return fail(res, 409, 'Email already exists');
    }
    if (duplicates[0] && (Number(duplicates[0].code_duplicate) || Number(duplicates[0].staff_duplicate))) return fail(res, 409, 'Employee ID already exists');

    const hashedPassword = await bcrypt.hash(password, 10);
    connection = await db.getConnection();
    await connection.beginTransaction();
    const [userResult] = await connection.query(
      'INSERT INTO employee_users (first_name, last_name, full_name, email, username, password, role, user_type, is_active, staff_id, initials) VALUES (?, ?, ?, ?, ?, ?, ?, \'employee\', 1, ?, ?)',
      [name.split(/\s+/)[0], name.split(/\s+/).slice(1).join(' '), name, email, username, hashedPassword, department, code, name.split(/\s+/).map(function (part) { return part[0]; }).join('').slice(0, 3).toUpperCase()]
    );
    createdUserId = userResult.insertId;
    const [result] = await connection.query(
      'INSERT INTO hrms_employee_profiles (employee_user_id, employee_code, full_name, email, department, work_mode, employee_type, overtime_eligible, gender, employment_status, monthly_salary, salary_type, flexible_cycle_start_day, flexible_cycle_end_day) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [userResult.insertId, code, name, email, department, workMode, employeeType, overtimeEligible, gender, status, salary, cycle.salaryType, cycle.cycleStartDay, cycle.cycleEndDay]
    );
    createdProfileId = result.insertId;
    const [rows] = await connection.query('SELECT * FROM hrms_employee_profiles WHERE id = ?', [result.insertId]);
    // Keep user/profile creation atomic. Working-day assignment is retained
    // after commit because its helper owns its own connection; any failure is
    // surfaced to the caller and can be safely retried without another login.
    await connection.commit();
    connection.release();
    connection = null;
    // A template selected while creating a new employee is effective
    // immediately. Future-dated assignments remain supported for edits.
    const creationWorkingDays = Object.assign({}, body, {
      effectiveFrom: body.effectiveFrom || new Date().toISOString().slice(0, 10)
    });
    await workingDays.assign(result.insertId, creationWorkingDays, req.user && req.user.id);
    await recordCompensation(rows[0], salary, req.user && req.user.id);
    return ok(res, { employee: toUi(rows[0]), credentials: { username: username, email: email, password: password } }, 'Employee added');
  } catch (error) {
    if (connection) {
      try { await connection.rollback(); } catch (_) {}
      connection.release();
    }
    // The working-days helper currently uses the pool directly. If it fails
    // after the user/profile transaction committed, remove only the rows just
    // created by this request so the API still has all-or-nothing semantics.
    if (!connection && createdUserId && createdProfileId) {
      try {
        await db.query('DELETE FROM hrms_employee_working_day_assignments WHERE profile_id = ?', [createdProfileId]);
        await db.query('DELETE FROM hrms_employee_profiles WHERE id = ? AND employee_user_id = ?', [createdProfileId, createdUserId]);
        await db.query('DELETE FROM employee_users WHERE id = ?', [createdUserId]);
      } catch (_) {}
    }
    if (error.code === 'ER_DUP_ENTRY') {
      const message = String(error.sqlMessage || error.message || '').toLowerCase();
      if (message.includes('username')) return fail(res, 409, 'Username already exists');
      if (message.includes('email')) return fail(res, 409, 'Email already exists');
      if (message.includes('employee_code')) return fail(res, 409, 'Employee ID already exists');
      return fail(res, 409, 'An employee login or ID already exists');
    }
    return fail(res, 500, error.message);
  }
}

async function resetPassword(req, res) {
  try {
    const password = String((req.body && req.body.password) || '');
    if (password.length < 8) return fail(res, 400, 'Password must be at least 8 characters');
    const [rows] = await db.query('SELECT employee_user_id FROM hrms_employee_profiles WHERE id = ?', [Number(req.params.id)]);
    if (!rows[0] || !rows[0].employee_user_id) return fail(res, 404, 'Employee login not found');
    await db.query('UPDATE employee_users SET password = ? WHERE id = ?', [await bcrypt.hash(password, 10), rows[0].employee_user_id]);
    return ok(res, { password: password }, 'Password reset');
  } catch (error) { return fail(res, 500, error.message); }
}

// Repairs login accounts left without an HRMS profile by an interrupted
// employee creation. It deliberately reuses the existing user ID and never
// creates a second login account.
async function repairProfiles(req, res) {
  let connection;
  try {
    const requestedId = Number(req.body && (req.body.employeeUserId || req.body.employee_user_id));
    connection = await db.getConnection();
    await connection.beginTransaction();
    const params = requestedId ? [requestedId] : [];
    const [users] = await connection.query(`
      SELECT u.id, u.full_name, u.first_name, u.last_name, u.email, u.staff_id,
             u.role, u.is_active
      FROM employee_users u
      LEFT JOIN hrms_employee_profiles p ON p.employee_user_id = u.id
      WHERE LOWER(u.user_type) = 'employee' AND p.id IS NULL
        ${requestedId ? 'AND u.id = ?' : ''}
      FOR UPDATE`, params);
    const repaired = [];
    for (const user of users) {
      const code = String(user.staff_id || `EMP${String(user.id).padStart(4, '0')}`).trim();
      const [codeRows] = await connection.query('SELECT id FROM hrms_employee_profiles WHERE employee_code = ? LIMIT 1', [code]);
      if (codeRows.length) throw Object.assign(new Error(`Employee code ${code} is already used`), { code: 'ER_DUP_ENTRY' });
      const name = String(user.full_name || `${user.first_name || ''} ${user.last_name || ''}`).trim();
      const [result] = await connection.query(`INSERT INTO hrms_employee_profiles
        (employee_user_id, employee_code, full_name, email, department, work_mode, employee_type, employment_status)
        VALUES (?, ?, ?, ?, ?, 'Office', 'Employee', ?)` ,
        [user.id, code, name, user.email || null, user.role || 'Engineering', Number(user.is_active) ? 'Active' : 'Inactive']);
      repaired.push({ userId: user.id, profileId: result.insertId, employeeCode: code });
    }
    await connection.commit();
    connection.release();
    connection = null;
    return ok(res, { repaired: repaired, count: repaired.length }, repaired.length ? 'Employee profiles repaired' : 'No orphan employee profiles found');
  } catch (error) {
    if (connection) { try { await connection.rollback(); } catch (_) {} connection.release(); }
    if (error.code === 'ER_DUP_ENTRY') return fail(res, 409, error.message);
    return fail(res, 500, error.message);
  }
}

async function deviceRequests(req, res) {
  try {
    await db.query(`CREATE TABLE IF NOT EXISTS hrms_device_change_requests (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, employee_user_id BIGINT UNSIGNED NOT NULL,
      proposed_device_hash CHAR(64) NOT NULL, proposed_device_label VARCHAR(180) NOT NULL DEFAULT 'New browser',
      reason VARCHAR(500) NULL, status ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
      requested_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, reviewed_at TIMESTAMP NULL, reviewed_by BIGINT UNSIGNED NULL,
      review_note VARCHAR(500) NULL, KEY device_request_status (status, requested_at)
    )`);
    const [rows] = await db.query(`SELECT r.id, r.employee_user_id, r.proposed_device_label, r.reason, r.status, r.requested_at,
      u.full_name, u.username, p.employee_code FROM hrms_device_change_requests r
      INNER JOIN employee_users u ON u.id = r.employee_user_id LEFT JOIN hrms_employee_profiles p ON p.employee_user_id = u.id
      WHERE r.status = 'pending' ORDER BY r.requested_at DESC`);
    return ok(res, { items: rows }, 'Device requests loaded');
  } catch (error) { return fail(res, 500, error.message); }
}

async function reviewDeviceRequest(req, res) {
  try {
    const id = Number(req.params.id);
    const approved = req.body && req.body.approved === true;
    const note = String((req.body && req.body.note) || '').slice(0, 500);
    const [rows] = await db.query("SELECT * FROM hrms_device_change_requests WHERE id = ? AND status = 'pending' FOR UPDATE", [id]);
    if (!rows.length) return fail(res, 404, 'Pending device request not found');
    const request = rows[0];
    if (approved) {
      await db.query(`INSERT INTO hrms_registered_devices (employee_user_id, device_hash, device_label, registered_at, last_seen_at)
        VALUES (?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        ON DUPLICATE KEY UPDATE device_hash = VALUES(device_hash), device_label = VALUES(device_label), registered_at = CURRENT_TIMESTAMP, last_seen_at = CURRENT_TIMESTAMP`,
        [request.employee_user_id, request.proposed_device_hash, request.proposed_device_label]);
    }
    await db.query("UPDATE hrms_device_change_requests SET status = ?, reviewed_at = CURRENT_TIMESTAMP, reviewed_by = ?, review_note = ? WHERE id = ?",
      [approved ? 'approved' : 'rejected', req.user.id, note || null, id]);
    return ok(res, { id: id, status: approved ? 'approved' : 'rejected' }, approved ? 'New browser approved. The employee can now sign in.' : 'Device request rejected.');
  } catch (error) { return fail(res, 500, error.message); }
}

async function update(req, res) {
  try {
    const id = Number(req.params.id);
    const body = req.body || {};
    const name = String(body.name || body.full_name || '').trim();
    const code = String(body.employeeCode || body.employee_code || body.id || '').trim();
    const department = String(body.department || '').trim();
    const workMode = String(body.workMode || body.work_mode || '').trim();
    const employeeType = String(body.employeeType || body.employee_type || 'Employee').trim();
    const overtimeEligible = body.overtimeEligible || body.overtime_eligible ? 1 : 0;
    if (!employeeType || employeeType.length > 100) return fail(res, 400, 'Employee type is required and must be 100 characters or fewer');
    const gender = String(body.gender || 'Male').trim();
    if (!['Male', 'Female'].includes(gender)) return fail(res, 400, 'Gender must be Male or Female');
    const status = String(body.status || body.employment_status || '').trim();
    const salary = parseSalary(body.salary || body.monthly_salary);
    const cycle = salaryCycle(body);
    if (cycle.error) return fail(res, 400, cycle.error);
    const email = String(body.email || '').trim() || null;
    const username = String(body.username || '').trim();
    const password = String(body.password || '');

    const [result] = await db.query(
      'UPDATE hrms_employee_profiles SET employee_code = ?, full_name = ?, email = ?, department = ?, work_mode = ?, employee_type = ?, overtime_eligible = ?, gender = ?, employment_status = ?, monthly_salary = ?, salary_type = ?, flexible_cycle_start_day = ?, flexible_cycle_end_day = ? WHERE id = ?',
      [code, name, email, department, workMode, employeeType, overtimeEligible, gender, status, salary, cycle.salaryType, cycle.cycleStartDay, cycle.cycleEndDay, id]
    );
    if (!result.affectedRows) return fail(res, 404, 'Employee not found');
    const [profileRows] = await db.query('SELECT employee_user_id FROM hrms_employee_profiles WHERE id = ?', [id]);
    const employeeUserId = profileRows[0] && profileRows[0].employee_user_id;
    if (employeeUserId) {
      if (password && password.length < 8) return fail(res, 400, 'New password must be at least 8 characters');
      const updates = ['full_name = ?', 'email = ?'];
      const values = [name, email];
      if (username) { updates.push('username = ?'); values.push(username); }
      if (password) { updates.push('password = ?'); values.push(await bcrypt.hash(password, 10)); }
      values.push(employeeUserId);
      await db.query('UPDATE employee_users SET ' + updates.join(', ') + ' WHERE id = ?', values);
    }
    const [rows] = await db.query('SELECT * FROM hrms_employee_profiles WHERE id = ?', [id]);
    const updateWorkingDays = Object.assign({}, body, {
      // Existing employee changes become effective tomorrow by default so
      // today's attendance/payroll results are never rewritten.
      effectiveFrom: body.effectiveFrom || new Date(Date.now() + 86400000).toISOString().slice(0, 10)
    });
    await workingDays.assign(id, updateWorkingDays, req.user && req.user.id);
    await recordCompensation(rows[0], salary, req.user && req.user.id);
    return ok(res, toUi(rows[0]), 'Employee updated');
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY') return fail(res, 409, 'Employee ID already exists');
    return fail(res, 500, error.message);
  }
}

async function updateStatus(req, res) {
  try {
    const id = Number(req.params.id);
    const status = String((req.body && req.body.status) || '').trim();
    if (['Active', 'On Leave', 'Inactive'].indexOf(status) === -1) {
      return fail(res, 400, 'status must be Active, On Leave, or Inactive');
    }
    const [result] = await db.query('UPDATE hrms_employee_profiles SET employment_status = ? WHERE id = ?', [status, id]);
    if (!result.affectedRows) return fail(res, 404, 'Employee not found');
    const [rows] = await db.query('SELECT * FROM hrms_employee_profiles WHERE id = ?', [id]);
    return ok(res, toUi(rows[0]), 'Status updated');
  } catch (error) {
    return fail(res, 500, error.message);
  }
}

async function remove(req, res) {
  const connection = await db.getConnection();
  try {
    const id = Number(req.params.id);
    await connection.beginTransaction();
    const [profiles] = await connection.query('SELECT employee_user_id FROM hrms_employee_profiles WHERE id = ? FOR UPDATE', [id]);
    if (!profiles.length) { await connection.rollback(); return fail(res, 404, 'Employee not found'); }
    const userId = profiles[0].employee_user_id;
    // This is an intentional hard delete: remove the employee profile and
    // login account rather than merely hiding/deactivating the employee.
    // The transaction prevents a half-deleted employee if either statement
    // fails.
    await connection.query('DELETE FROM hrms_employee_profiles WHERE id = ?', [id]);
    if (userId) await connection.query('DELETE FROM employee_users WHERE id = ?', [userId]);
    await connection.commit();
    return ok(res, { id: id }, 'Employee permanently deleted');
  } catch (error) {
    await connection.rollback();
    return fail(res, 500, error.message);
  } finally {
    connection.release();
  }
}

async function exportCsv(req, res) {
  try {
    const [rows] = await db.query(
      'SELECT p.* FROM hrms_employee_profiles p INNER JOIN employee_users u ON u.id = p.employee_user_id WHERE u.is_active = 1 ORDER BY p.full_name ASC'
    );
    const lines = ['Employee,Employee ID,Department,Work Mode,Monthly Salary,Status'];
    rows.forEach(function (row) {
      const item = toUi(row);
      lines.push([item.name, item.employeeCode, item.department, item.workMode, item.salary, item.status]
        .map(function (v) { return '"' + String(v).replace(/"/g, '""') + '"'; }).join(','));
    });
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', 'attachment; filename="employees.csv"');
    return res.send(lines.join('\n'));
  } catch (error) {
    return fail(res, 500, error.message);
  }
}

module.exports = {
  requireAdmin: requireAdmin,
  summary: summary,
  detail: detail,
  list: list,
  create: create,
  repairProfiles: repairProfiles,
  resetPassword: resetPassword,
  deviceRequests: deviceRequests,
  reviewDeviceRequest: reviewDeviceRequest,
  update: update,
  updateStatus: updateStatus,
  remove: remove,
  exportCsv: exportCsv
};
