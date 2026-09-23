const db = require('../config/db');
const bcrypt = require('bcrypt');

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
    employeeUserId: row.employee_user_id
  };
}

async function summary(req, res) {
  try {
    const [rows] = await db.query(
      "SELECT COUNT(*) AS total, SUM(employment_status = 'Active') AS active, SUM(employment_status = 'On Leave') AS onLeave, SUM(employment_status = 'Inactive') AS inactive FROM hrms_employee_profiles"
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
    const search = String(req.query.search || req.query.query || '').trim();
    const department = String(req.query.department || '').trim();
    const status = String(req.query.status || '').trim();
    const workMode = String(req.query.workMode || req.query.work_mode || '').trim();
    const page = Math.max(1, Number(req.query.page || 1));
    const limit = Math.min(50, Math.max(1, Number(req.query.limit || 6)));
    const where = ["u.user_type = 'employee'"];
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
      'SELECT p.*, u.username AS username FROM hrms_employee_profiles p LEFT JOIN employee_users u ON u.id = p.employee_user_id ' + clause.replace(/\b(full_name|employee_code|email|department|employment_status|work_mode)\b/g, 'p.$1') + ' ORDER BY p.full_name ASC LIMIT ? OFFSET ?',
      params.concat([limit, offset])
    );
    const [allRows] = await db.query("SELECT p.employment_status FROM hrms_employee_profiles p INNER JOIN employee_users u ON u.id = p.employee_user_id WHERE u.user_type = 'employee'");
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

    return ok(res, {
      items: rows.map(toUi),
      page: safePage,
      limit: limit,
      total: total,
      totalPages: totalPages,
      departments: departmentRows.map(function (row) { return row.name; }),
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

async function create(req, res) {
  try {
    const body = req.body || {};
    const name = String(body.name || body.full_name || '').trim();
    const code = String(body.employeeCode || body.employee_code || body.id || '').trim();
    const department = String(body.department || 'Engineering').trim();
    const workMode = String(body.workMode || body.work_mode || 'Office').trim();
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

    const hashedPassword = await bcrypt.hash(password, 10);
    const [userResult] = await db.query(
      'INSERT INTO employee_users (first_name, last_name, full_name, email, username, password, role, user_type, is_active, staff_id, initials) VALUES (?, ?, ?, ?, ?, ?, ?, \'employee\', 1, ?, ?)',
      [name.split(/\s+/)[0], name.split(/\s+/).slice(1).join(' '), name, email, username, hashedPassword, department, code, name.split(/\s+/).map(function (part) { return part[0]; }).join('').slice(0, 3).toUpperCase()]
    );
    const [result] = await db.query(
      'INSERT INTO hrms_employee_profiles (employee_user_id, employee_code, full_name, email, department, work_mode, gender, employment_status, monthly_salary, salary_type, flexible_cycle_start_day, flexible_cycle_end_day) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [userResult.insertId, code, name, email, department, workMode, gender, status, salary, cycle.salaryType, cycle.cycleStartDay, cycle.cycleEndDay]
    );
    const [rows] = await db.query('SELECT * FROM hrms_employee_profiles WHERE id = ?', [result.insertId]);
    await recordCompensation(rows[0], salary, req.user && req.user.id);
    return ok(res, { employee: toUi(rows[0]), credentials: { username: username, email: email, password: password } }, 'Employee added');
  } catch (error) {
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

async function update(req, res) {
  try {
    const id = Number(req.params.id);
    const body = req.body || {};
    const name = String(body.name || body.full_name || '').trim();
    const code = String(body.employeeCode || body.employee_code || body.id || '').trim();
    const department = String(body.department || '').trim();
    const workMode = String(body.workMode || body.work_mode || '').trim();
    const gender = String(body.gender || 'Male').trim();
    if (!['Male', 'Female'].includes(gender)) return fail(res, 400, 'Gender must be Male or Female');
    const status = String(body.status || body.employment_status || '').trim();
    const salary = parseSalary(body.salary || body.monthly_salary);
    const cycle = salaryCycle(body);
    if (cycle.error) return fail(res, 400, cycle.error);
    const email = String(body.email || '').trim() || null;

    const [result] = await db.query(
      'UPDATE hrms_employee_profiles SET employee_code = ?, full_name = ?, email = ?, department = ?, work_mode = ?, gender = ?, employment_status = ?, monthly_salary = ?, salary_type = ?, flexible_cycle_start_day = ?, flexible_cycle_end_day = ? WHERE id = ?',
      [code, name, email, department, workMode, gender, status, salary, cycle.salaryType, cycle.cycleStartDay, cycle.cycleEndDay, id]
    );
    if (!result.affectedRows) return fail(res, 404, 'Employee not found');
    const [rows] = await db.query('SELECT * FROM hrms_employee_profiles WHERE id = ?', [id]);
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
    await connection.query('DELETE FROM hrms_employee_compensation WHERE profile_id = ?', [id]).catch(() => {});
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
    const [rows] = await db.query('SELECT * FROM hrms_employee_profiles ORDER BY full_name ASC');
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
  list: list,
  create: create,
  resetPassword: resetPassword,
  update: update,
  updateStatus: updateStatus,
  remove: remove,
  exportCsv: exportCsv
};
