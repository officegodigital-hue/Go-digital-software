// lib/attendanceProfileSync.js
//
// One employee, two apps:
//   Admin Panel (Task Manager)  → employee_users          (add / edit / active)
//   Attendance (HRMS Employees)  → hrms_employee_profiles  (work mode, salary …)
//
// The Admin Panel is where employees are ADDED. Its "Attendance Details"
// section saves the attendance-only fields (work location, salary, salary
// cycle) into the attendance profile, and Active / Inactive is kept the same
// in both places whichever page changes it.
//
// Salary fields are saved through the Attendance controller itself
// (hrmsEmployeesController.update) so its own rules / formatting are used.
// If that is not possible, the known columns are written directly.
const db = require('../config/db');

let hrms = null;
try {
  hrms = require('../controllers/hrmsEmployeesController');
} catch (_) {
  hrms = null;
}

let colCache = null;
async function profileColumns() {
  if (!colCache) {
    const [rows] = await db.query(
      `SELECT COLUMN_NAME AS c FROM information_schema.COLUMNS
       WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'hrms_employee_profiles'`,
    );
    colCache = new Set(rows.map((r) => r.c));
  }
  return colCache;
}

const SALARY_COLS = ['monthly_salary', 'salary', 'base_salary', 'salary_amount', 'gross_salary'];
const TYPE_COLS = ['salary_type', 'salary_cycle_type', 'cycle_type'];
const START_COLS = ['salary_start_day', 'salary_cycle_start_day', 'cycle_start_day'];
const END_COLS = ['salary_end_day', 'salary_cycle_end_day', 'cycle_end_day'];
const pick = (cols, list) => list.find((c) => cols.has(c)) || null;

const WORK_MODES = ['Office', 'Home', 'Hybrid'];
function normWorkMode(v) {
  const s = String(v || '').trim().toLowerCase();
  if (s.startsWith('home') || s === 'wfh' || s === 'remote') return 'Home';
  if (s.startsWith('hyb')) return 'Hybrid';
  if (s.startsWith('off')) return 'Office';
  return null;
}

/** Attendance details for one employee user (for the Admin Panel form). */
async function readAttendanceDetails(employeeUserId) {
  const [[p]] = await db.query(
    'SELECT * FROM hrms_employee_profiles WHERE employee_user_id = ? LIMIT 1',
    [employeeUserId],
  );
  if (!p) return null;
  const cols = await profileColumns();
  const val = (list) => {
    const c = pick(cols, list);
    return c ? p[c] : null;
  };
  const salaryRaw = val(SALARY_COLS);
  const salaryDigits = salaryRaw == null ? '' : String(salaryRaw).replace(/[^0-9.]/g, '');
  return {
    profile_id: p.id,
    work_mode: p.work_mode || 'Office',
    employment_status: p.employment_status || 'Active',
    department: p.department || '',
    monthly_salary: salaryDigits && Number(salaryDigits) > 0 ? String(Math.round(Number(salaryDigits))) : '',
    salary_type: String(val(TYPE_COLS) || 'standard').toLowerCase() === 'flexible' ? 'flexible' : 'standard',
    salary_start_day: val(START_COLS) ?? null,
    salary_end_day: val(END_COLS) ?? null,
  };
}

/** Make sure an attendance profile exists for this employee user. */
async function ensureProfile(employeeUserId, { staffId, fullName, email, role }) {
  const [[p]] = await db.query(
    'SELECT id FROM hrms_employee_profiles WHERE employee_user_id = ? LIMIT 1',
    [employeeUserId],
  );
  if (p) return p.id;
  const [ins] = await db.query(
    `INSERT INTO hrms_employee_profiles
       (employee_user_id, employee_code, full_name, email, department, work_mode, employment_status)
     VALUES (?, ?, ?, ?, ?, 'Office', 'Active')`,
    [employeeUserId, staffId || null, fullName || '', email || null, role || null],
  );
  return ins.insertId;
}

// Call an Express handler (req, res) and wait for its JSON answer.
function callHandler(fn, req) {
  return new Promise((resolve) => {
    let done = false;
    const finish = (status, body) => {
      if (!done) {
        done = true;
        resolve({ status, body });
      }
    };
    const res = {
      statusCode: 200,
      status(code) { this.statusCode = code; return this; },
      json(body) { finish(this.statusCode, body); return this; },
      send(body) { finish(this.statusCode, body); return this; },
      end() { finish(this.statusCode); return this; },
      setHeader() { return this; },
      set() { return this; },
      type() { return this; },
    };
    try {
      Promise.resolve(fn(req, res, (err) => finish(500, { message: err?.message || 'next()' })))
        .catch((err) => finish(500, { message: err.message }));
    } catch (err) {
      finish(500, { message: err.message });
    }
    setTimeout(() => finish(504, { message: 'timeout' }), 15000);
  });
}

/**
 * Save the Admin Panel "Attendance Details" for one employee user.
 * details = { workMode, salary, salaryType, salaryStartDay, salaryEndDay }
 * basics  = { staffId, fullName, email, role, isActive, user }
 */
async function saveAttendanceDetails(employeeUserId, details = {}, basics = {}) {
  const profileId = await ensureProfile(employeeUserId, basics);
  const [[current]] = await db.query('SELECT * FROM hrms_employee_profiles WHERE id = ?', [profileId]);
  const workMode = normWorkMode(details.workMode) || current?.work_mode || 'Office';
  let status = current?.employment_status || 'Active';
  if (basics.isActive === false) status = 'Inactive';
  else if (basics.isActive === true && status === 'Inactive') status = 'Active';

  const salary = details.salary == null ? '' : String(details.salary).replace(/[^0-9.]/g, '');
  const salaryType = String(details.salaryType || 'standard').toLowerCase() === 'flexible' ? 'flexible' : 'standard';
  const startDay = Number(details.salaryStartDay) || null;
  const endDay = Number(details.salaryEndDay) || null;

  // Names / code / department always follow the Admin Panel.
  await db.query(
    `UPDATE hrms_employee_profiles
     SET employee_code = COALESCE(?, employee_code), full_name = COALESCE(?, full_name),
         email = COALESCE(?, email), department = COALESCE(?, department),
         work_mode = ?, employment_status = ?
     WHERE id = ?`,
    [basics.staffId || null, basics.fullName || null, basics.email || null, basics.role || null,
      workMode, status, profileId],
  );

  // Salary through the Attendance controller (same rules as the Attendance page).
  let viaController = false;
  if (hrms && typeof hrms.update === 'function') {
    const out = await callHandler(hrms.update, {
      params: { id: String(profileId) },
      query: {},
      headers: {},
      user: basics.user || { userType: 'admin', user_type: 'admin', role: 'admin', fullName: 'Admin Panel' },
      body: {
        name: basics.fullName || current?.full_name || '',
        employeeCode: basics.staffId || current?.employee_code || '',
        department: basics.role || current?.department || '',
        workMode,
        status,
        salary,
        salaryType,
        ...(salaryType === 'flexible' ? { salaryStartDay: startDay || 26, salaryEndDay: endDay || 25 } : {}),
      },
    });
    viaController = out.status >= 200 && out.status < 300;
    if (!viaController) console.warn('Attendance controller update skipped:', out.status, out.body?.message);
  }

  if (!viaController) {
    const cols = await profileColumns();
    const sets = [];
    const vals = [];
    const add = (list, v) => {
      const c = pick(cols, list);
      if (c) { sets.push(`\`${c}\` = ?`); vals.push(v); }
    };
    add(SALARY_COLS, salary === '' ? null : salary);
    add(TYPE_COLS, salaryType);
    if (salaryType === 'flexible') {
      add(START_COLS, startDay || 26);
      add(END_COLS, endDay || 25);
    }
    if (sets.length) {
      await db.query(`UPDATE hrms_employee_profiles SET ${sets.join(', ')} WHERE id = ?`, [...vals, profileId]);
    }
  }
  return profileId;
}

/** Admin Panel Active / Inactive → attendance employment status. */
async function syncStatusFromAdmin(employeeUserId, isActive) {
  if (isActive) {
    await db.query(
      `UPDATE hrms_employee_profiles SET employment_status = 'Active'
       WHERE employee_user_id = ? AND employment_status = 'Inactive'`,
      [employeeUserId],
    );
  } else {
    await db.query(
      `UPDATE hrms_employee_profiles SET employment_status = 'Inactive' WHERE employee_user_id = ?`,
      [employeeUserId],
    );
  }
}

/** Attendance page status change → Admin Panel Active / Inactive. */
async function syncStatusFromProfile(profileId) {
  const [[p]] = await db.query(
    'SELECT employee_user_id, employment_status FROM hrms_employee_profiles WHERE id = ?',
    [profileId],
  );
  if (!p || !p.employee_user_id) return;
  const active = String(p.employment_status || '').toLowerCase() !== 'inactive' ? 1 : 0;
  await db.query('UPDATE employee_users SET is_active = ? WHERE id = ?', [active, p.employee_user_id]);
}

module.exports = {
  WORK_MODES,
  readAttendanceDetails,
  saveAttendanceDetails,
  syncStatusFromAdmin,
  syncStatusFromProfile,
};
