const db = require('../config/db');

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
  const digits = String(value).replace(/[^0-9]/g, '');
  if (!digits) return 'Not Set';
  return '₹' + Number(digits).toLocaleString('en-IN');
}

function parseSalary(value) {
  if (value === null || value === undefined || value === '' || value === 'Not Set') return null;
  const digits = String(value).replace(/[^0-9]/g, '');
  if (!digits) return null;
  return Number(digits);
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
    salary: formatSalary(row.monthly_salary),
    monthlySalary: row.monthly_salary,
    status: row.employment_status,
    modeColor: modeColor(row.work_mode),
    email: row.email || '',
    employeeUserId: row.employee_user_id,
    salaryType: row.salary_type || 'standard',
    salaryStartDay: row.salary_cycle_start_day !== null && row.salary_cycle_start_day !== undefined ? Number(row.salary_cycle_start_day) : null,
    salaryEndDay: row.salary_cycle_end_day !== null && row.salary_cycle_end_day !== undefined ? Number(row.salary_cycle_end_day) : null,
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

async function ensureSalaryCycleColumns() {
  try { await db.query("ALTER TABLE hrms_employee_profiles ADD COLUMN salary_type ENUM('standard','flexible') NOT NULL DEFAULT 'standard'"); } catch (_) {}
  try { await db.query('ALTER TABLE hrms_employee_profiles ADD COLUMN salary_cycle_start_day TINYINT UNSIGNED NULL'); } catch (_) {}
  try { await db.query('ALTER TABLE hrms_employee_profiles ADD COLUMN salary_cycle_end_day TINYINT UNSIGNED NULL'); } catch (_) {}
}
ensureSalaryCycleColumns();

async function create(req, res) {
  try {
    const body = req.body || {};
    const name = String(body.name || body.full_name || '').trim();
    const code = String(body.employeeCode || body.employee_code || body.id || '').trim();
    const department = String(body.department || 'Engineering').trim();
    const workMode = String(body.workMode || body.work_mode || 'Office').trim();
    const status = String(body.status || body.employment_status || 'Active').trim();
    const salary = parseSalary(body.salary || body.monthly_salary);
    const email = String(body.email || '').trim() || null;
    const salaryType = body.salaryType === 'flexible' ? 'flexible' : 'standard';
    const startDay = salaryType === 'flexible' && body.salaryStartDay ? Math.max(1, Math.min(28, Number(body.salaryStartDay))) : null;
    const endDay = salaryType === 'flexible' && body.salaryEndDay ? Math.max(1, Math.min(28, Number(body.salaryEndDay))) : null;
    if (!name || !code) return fail(res, 400, 'name and employeeCode are required');

    const [result] = await db.query(
      'INSERT INTO hrms_employee_profiles (employee_code, full_name, email, department, work_mode, employment_status, monthly_salary, salary_type, salary_cycle_start_day, salary_cycle_end_day) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [code, name, email, department, workMode, status, salary, salaryType, startDay, endDay]
    );
    const [rows] = await db.query('SELECT * FROM hrms_employee_profiles WHERE id = ?', [result.insertId]);
    await recordCompensation(rows[0], salary, req.user && req.user.id);
    return ok(res, toUi(rows[0]), 'Employee added');
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY') return fail(res, 409, 'Employee ID already exists');
    return fail(res, 500, error.message);
  }
}

async function update(req, res) {
  try {
    const id = Number(req.params.id);
    const body = req.body || {};
    const name = String(body.name || body.full_name || '').trim();
    const code = String(body.employeeCode || body.employee_code || body.id || '').trim();
    const department = String(body.department || '').trim();
    const workMode = String(body.workMode || body.work_mode || '').trim();
    const status = String(body.status || body.employment_status || '').trim();
    const salary = parseSalary(body.salary || body.monthly_salary);
    const email = String(body.email || '').trim() || null;
    const salaryType = body.salaryType === 'flexible' ? 'flexible' : 'standard';
    const startDay = salaryType === 'flexible' && body.salaryStartDay ? Math.max(1, Math.min(28, Number(body.salaryStartDay))) : null;
    const endDay = salaryType === 'flexible' && body.salaryEndDay ? Math.max(1, Math.min(28, Number(body.salaryEndDay))) : null;

    const [result] = await db.query(
      'UPDATE hrms_employee_profiles SET employee_code = ?, full_name = ?, email = ?, department = ?, work_mode = ?, employment_status = ?, monthly_salary = ?, salary_type = ?, salary_cycle_start_day = ?, salary_cycle_end_day = ? WHERE id = ?',
      [code, name, email, department, workMode, status, salary, salaryType, startDay, endDay, id]
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
  try {
    const id = Number(req.params.id);
    const [result] = await db.query("UPDATE hrms_employee_profiles SET employment_status = 'Inactive' WHERE id = ?", [id]);
    if (!result.affectedRows) return fail(res, 404, 'Employee not found');
    return ok(res, { id: id }, 'Employee deactivated; history retained');
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
  update: update,
  updateStatus: updateStatus,
  remove: remove,
  exportCsv: exportCsv
};
