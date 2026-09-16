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
  // MySQL DECIMAL values commonly arrive as strings such as "20000.00".
  // Keep the decimal point while formatting, otherwise 20,000.00 becomes 20,00,000.
  const amount = Number(String(value).replace(/[₹\s,]/g, ''));
  if (!Number.isFinite(amount)) return 'Not Set';
  return '₹' + amount.toLocaleString('en-IN', { maximumFractionDigits: 2 });
}

function parseSalary(value) {
  if (value === null || value === undefined || value === '' || value === 'Not Set') return null;
  // Commas are thousands separators; retain a decimal point so a formatted
  // input such as "20,000.00" remains twenty thousand, not twenty lakhs.
  const normalized = String(value).replace(/[₹\s,]/g, '');
  if (!/^\d+(\.\d{1,2})?$/.test(normalized)) return null;
  const amount = Number(normalized);
  return Number.isFinite(amount) && amount >= 0 ? amount : null;
}

function loginDetails(body) {
  return {
    email: String(body.email || '').trim().toLowerCase(),
    username: String(body.username || '').trim(),
    password: String(body.password || '')
  };
}

function nameParts(name) {
  const parts = String(name).trim().split(/\s+/).filter(Boolean);
  return {
    firstName: parts.shift() || 'Employee',
    lastName: parts.join(' ')
  };
}

function initialsFor(name) {
  return String(name).trim().split(/\s+/).filter(Boolean).slice(0, 2)
    .map(function (part) { return part.charAt(0).toUpperCase(); }).join('') || 'E';
}

function validateLogin(details) {
  if (!details.email || !/^\S+@\S+\.\S+$/.test(details.email)) return 'A valid login email is required';
  if (!details.username) return 'A login username is required';
  if (details.password.length < 8) return 'Temporary password must contain at least 8 characters';
  return null;
}

function toUi(row) {
  return {
    id: row.id,
    name: row.full_name,
    employeeCode: row.employee_code,
    employeeId: row.employee_code,
    department: row.department,
    workMode: row.work_mode,
    salary: formatSalary(row.monthly_salary),
    monthlySalary: row.monthly_salary,
    status: row.employment_status,
    modeColor: modeColor(row.work_mode),
    email: row.email || '',
    employeeUserId: row.employee_user_id,
    fieldTrackingEnabled: Number(row.field_tracking_enabled) === 1
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
    const where = [];
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
    const [countRows] = await db.query('SELECT COUNT(*) AS total FROM hrms_employee_profiles ' + clause, params);
    const total = Number(countRows[0].total || 0);
    const totalPages = Math.max(1, Math.ceil(total / limit));
    const safePage = Math.min(page, totalPages);
    const offset = (safePage - 1) * limit;

    const [rows] = await db.query(
      'SELECT * FROM hrms_employee_profiles ' + clause + ' ORDER BY full_name ASC LIMIT ? OFFSET ?',
      params.concat([limit, offset])
    );
    const [allRows] = await db.query('SELECT employment_status FROM hrms_employee_profiles');
    // Roles are managed in the main admin area while older HRMS records keep
    // their designation in `department`.  Combining both sources keeps this
    // filter current as soon as an admin creates a role or employee.
    const [departmentRows] = await db.query(
      "SELECT DISTINCT role_name AS name FROM user_roles WHERE TRIM(COALESCE(role_name, '')) <> '' " +
      "UNION SELECT DISTINCT role AS name FROM employee_users WHERE TRIM(COALESCE(role, '')) <> '' " +
      "UNION SELECT DISTINCT department AS name FROM hrms_employee_profiles WHERE TRIM(COALESCE(department, '')) <> '' " +
      'ORDER BY name ASC'
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
  let connection;
  try {
    const body = req.body || {};
    const name = String(body.name || body.full_name || '').trim();
    const code = String(body.employeeCode || body.employee_code || body.id || '').trim();
    const department = String(body.department || 'Engineering').trim();
    const workMode = String(body.workMode || body.work_mode || 'Office').trim();
    const status = String(body.status || body.employment_status || 'Active').trim();
    const salary = parseSalary(body.salary || body.monthly_salary);
    const fieldTrackingEnabled = body.fieldTrackingEnabled === true || body.field_tracking_enabled === true || Number(body.fieldTrackingEnabled ?? body.field_tracking_enabled) === 1;
    const login = loginDetails(body);
    if (!name || !code) return fail(res, 400, 'Name and employee ID are required');
    const loginError = validateLogin(login);
    if (loginError) return fail(res, 400, loginError);

    connection = await db.getConnection();
    await connection.beginTransaction();
    const names = nameParts(name);
    const passwordHash = await bcrypt.hash(login.password, 12);
    const [userResult] = await connection.query(
      'INSERT INTO employee_users (first_name, last_name, full_name, email, username, password, role, user_type, is_active, staff_id, initials) VALUES (?, ?, ?, ?, ?, ?, ?, \'employee\', 1, ?, ?)',
      [names.firstName, names.lastName, name, login.email, login.username, passwordHash, department || 'Employee', code, initialsFor(name)]
    );

    const [result] = await connection.query(
      'INSERT INTO hrms_employee_profiles (employee_user_id, employee_code, full_name, email, department, work_mode, employment_status, field_tracking_enabled, monthly_salary) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [userResult.insertId, code, name, login.email, department, workMode, status, fieldTrackingEnabled ? 1 : 0, salary]
    );
    await connection.commit();
    const [rows] = await db.query('SELECT * FROM hrms_employee_profiles WHERE id = ?', [result.insertId]);
    return ok(res, toUi(rows[0]), 'Employee and login account added');
  } catch (error) {
    if (connection) await connection.rollback();
    if (error.code === 'ER_DUP_ENTRY') return fail(res, 409, 'Employee ID, login email, or username already exists');
    return fail(res, 500, error.message);
  } finally {
    if (connection) connection.release();
  }
}

async function createRole(req, res) {
  try {
    const role = String((req.body && (req.body.role || req.body.role_name)) || '').trim();
    if (!role) return fail(res, 400, 'Role name is required');
    if (role.length > 100) return fail(res, 400, 'Role name must be 100 characters or fewer');
    const [result] = await db.query(
      'INSERT INTO user_roles (role_name) VALUES (?) ON DUPLICATE KEY UPDATE role_name = VALUES(role_name)',
      [role]
    );
    return ok(res, { id: result.insertId || null, role: role }, 'Role saved');
  } catch (error) {
    return fail(res, 500, error.message);
  }
}

async function update(req, res) {
  let connection;
  try {
    const id = Number(req.params.id);
    const body = req.body || {};
    const name = String(body.name || body.full_name || '').trim();
    const code = String(body.employeeCode || body.employee_code || body.id || '').trim();
    const department = String(body.department || '').trim();
    const workMode = String(body.workMode || body.work_mode || '').trim();
    const status = String(body.status || body.employment_status || '').trim();
    const salary = parseSalary(body.salary || body.monthly_salary);
    const fieldTrackingEnabled = body.fieldTrackingEnabled === true || body.field_tracking_enabled === true || Number(body.fieldTrackingEnabled ?? body.field_tracking_enabled) === 1;
    const login = loginDetails(body);
    const hasLoginInput = Boolean(login.email || login.username || login.password);

    connection = await db.getConnection();
    await connection.beginTransaction();
    const [existingRows] = await connection.query('SELECT * FROM hrms_employee_profiles WHERE id = ? FOR UPDATE', [id]);
    if (!existingRows.length) {
      await connection.rollback();
      return fail(res, 404, 'Employee not found');
    }
    const existing = existingRows[0];
    let employeeUserId = existing.employee_user_id;
    let profileEmail = existing.email;

    if (hasLoginInput) {
      if (employeeUserId) {
        await connection.rollback();
        return fail(res, 400, 'This employee already has a login account');
      }
      const loginError = validateLogin(login);
      if (loginError) {
        await connection.rollback();
        return fail(res, 400, loginError);
      }
      const names = nameParts(name);
      const passwordHash = await bcrypt.hash(login.password, 12);
      const [userResult] = await connection.query(
        'INSERT INTO employee_users (first_name, last_name, full_name, email, username, password, role, user_type, is_active, staff_id, initials) VALUES (?, ?, ?, ?, ?, ?, ?, \'employee\', 1, ?, ?)',
        [names.firstName, names.lastName, name, login.email, login.username, passwordHash, department || 'Employee', code, initialsFor(name)]
      );
      employeeUserId = userResult.insertId;
      profileEmail = login.email;
    }

    const [result] = await connection.query(
      'UPDATE hrms_employee_profiles SET employee_user_id = ?, employee_code = ?, full_name = ?, email = ?, department = ?, work_mode = ?, employment_status = ?, field_tracking_enabled = ?, monthly_salary = ? WHERE id = ?',
      [employeeUserId, code, name, profileEmail, department, workMode, status, fieldTrackingEnabled ? 1 : 0, salary, id]
    );
    await connection.commit();
    const [rows] = await db.query('SELECT * FROM hrms_employee_profiles WHERE id = ?', [id]);
    return ok(res, toUi(rows[0]), hasLoginInput ? 'Employee updated and login account created' : 'Employee updated');
  } catch (error) {
    if (connection) await connection.rollback();
    if (error.code === 'ER_DUP_ENTRY') return fail(res, 409, 'Employee ID, login email, or username already exists');
    return fail(res, 500, error.message);
  } finally {
    if (connection) connection.release();
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

async function resetPassword(req, res) {
  try {
    const id = Number(req.params.id);
    const password = String((req.body && req.body.password) || '');
    if (password.length < 8) {
      return fail(res, 400, 'Temporary password must contain at least 8 characters');
    }
    const [profiles] = await db.query(
      'SELECT employee_user_id FROM hrms_employee_profiles WHERE id = ? LIMIT 1',
      [id]
    );
    if (!profiles.length) return fail(res, 404, 'Employee not found');
    if (!profiles[0].employee_user_id) {
      return fail(res, 400, 'This employee does not have a login account yet');
    }
    const passwordHash = await bcrypt.hash(password, 12);
    await db.query(
      'UPDATE employee_users SET password = ? WHERE id = ?',
      [passwordHash, profiles[0].employee_user_id]
    );
    return ok(res, { id: id }, 'Password reset successfully');
  } catch (error) {
    return fail(res, 500, error.message);
  }
}

async function remove(req, res) {
  try {
    const id = Number(req.params.id);
    const [result] = await db.query('DELETE FROM hrms_employee_profiles WHERE id = ?', [id]);
    if (!result.affectedRows) return fail(res, 404, 'Employee not found');
    return ok(res, { id: id }, 'Employee deleted');
  } catch (error) {
    return fail(res, 500, error.message);
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
  createRole: createRole,
  update: update,
  updateStatus: updateStatus,
  resetPassword: resetPassword,
  remove: remove,
  exportCsv: exportCsv
};
