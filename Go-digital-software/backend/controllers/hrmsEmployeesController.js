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

    return ok(res, {
      items: rows.map(toUi),
      page: safePage,
      limit: limit,
      total: total,
      totalPages: totalPages,
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
    const status = String(body.status || body.employment_status || 'Active').trim();
    const salary = parseSalary(body.salary || body.monthly_salary);
    const email = String(body.email || '').trim() || null;
    if (!name || !code) return fail(res, 400, 'name and employeeCode are required');

    const [result] = await db.query(
      'INSERT INTO hrms_employee_profiles (employee_code, full_name, email, department, work_mode, employment_status, monthly_salary) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [code, name, email, department, workMode, status, salary]
    );
    const [rows] = await db.query('SELECT * FROM hrms_employee_profiles WHERE id = ?', [result.insertId]);
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

    const [result] = await db.query(
      'UPDATE hrms_employee_profiles SET employee_code = ?, full_name = ?, email = ?, department = ?, work_mode = ?, employment_status = ?, monthly_salary = ? WHERE id = ?',
      [code, name, email, department, workMode, status, salary, id]
    );
    if (!result.affectedRows) return fail(res, 404, 'Employee not found');
    const [rows] = await db.query('SELECT * FROM hrms_employee_profiles WHERE id = ?', [id]);
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
  update: update,
  updateStatus: updateStatus,
  remove: remove,
  exportCsv: exportCsv
};