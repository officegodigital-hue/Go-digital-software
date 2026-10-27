// routes/employees.js — Updated CRUD API with Role-Based Page Access & User Types
const express = require('express');
const router  = express.Router();
const db      = require('../config/db');
const { authenticateToken } = require('./auth');
const {
  passwordColumns,
  verifyPassword,
  decryptPassword,
  isBcryptHash,
  ensurePasswordSecurity,
} = require('../lib/passwordSecurity');

const MIN_PASSWORD = 6;
const badPassword = (p) =>
  p != null && String(p).trim() !== '' && String(p).length < MIN_PASSWORD;
const {
  readAttendanceDetails,
  saveAttendanceDetails,
  syncStatusFromAdmin,
} = require('../lib/attendanceProfileSync');

// Admin Panel → "Attendance Details" section (work location, salary, cycle).
function attendanceFromBody(body) {
  const a = body.attendance || {};
  return {
    workMode: a.workMode ?? body.workMode,
    salary: a.salary ?? body.attendanceSalary,
    salaryType: a.salaryType ?? body.salaryType,
    salaryStartDay: a.salaryStartDay ?? body.salaryStartDay,
    salaryEndDay: a.salaryEndDay ?? body.salaryEndDay,
  };
}


// routes/employees.js — Place /user-roles routes at the TOP before /:id routes

// ═══════════════════════════════════════════════════════════════
// 1. USER ROLE MASTER ROUTES (MUST BE AT THE VERY TOP)
// ═══════════════════════════════════════════════════════════════
// GET /api/employees/user-roles
// New employee create panrum pothu last staff_id-ai fetch panni increment panra logic
async function generateStaffId(db) {
  const [rows] = await db.query(
    `SELECT staff_id FROM employee_users WHERE staff_id REGEXP '^900' ORDER BY id DESC LIMIT 1`
  );
  
  if (rows.length === 0) {
    return '90046067'; // First default staff id
  }
  
  const lastStaffId = rows[0].staff_id;
  const numericPart = parseInt(lastStaffId, 10);
  
  if (isNaN(numericPart)) {
    return '90046067';
  }
  
  return (numericPart + 1).toString();
}

// GET /api/employees/user-roles
router.get('/user-roles', async (req, res) => {
  try {
    const [roles] = await db.query(`
      SELECT id, role_name, role_key, user_type
      FROM user_roles
      ORDER BY role_name ASC
    `);

    for (const role of roles) {
      const [accessRows] = await db.query(`
        SELECT application, access_type, allowed_pages
        FROM role_application_access
        WHERE role_id = ?
        ORDER BY application ASC
      `, [role.id]);

      const applicationAccess = {};
      for (const row of accessRows) {
        let allowedPages = [];
        try { allowedPages = JSON.parse(row.allowed_pages || '[]'); } catch (_) { allowedPages = []; }
        applicationAccess[row.application] = {
          access_type: row.access_type || 'none',
          allowed_pages: Array.isArray(allowedPages) ? allowedPages : [],
        };
      }
      role.application_access = applicationAccess;
    }

    return res.json({ success: true, data: roles });
  } catch (err) {
    console.error('GET /user-roles ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// 🟢 2. Next Staff ID Route (MUST BE BEFORE /:id routes)
router.get('/next-staff-id', async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT staff_id FROM employee_users WHERE staff_id REGEXP '^900' ORDER BY id DESC LIMIT 1`
    );
    
    let nextStaffId = '90046067'; // Default start ID
    
    if (rows.length > 0) {
      const lastStaffId = rows[0].staff_id;
      const numericPart = parseInt(lastStaffId, 10);
      
      if (!isNaN(numericPart) && numericPart > 90046066) {
        nextStaffId = (numericPart + 1).toString();
      } else {
        nextStaffId = '90046067';
      }
    }

    return res.json({ success: true, staffId: nextStaffId });
  } catch (err) {
    console.error('GET /employees/next-staff-id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// routes/employees.js

router.get('/', async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT id, first_name, middle_name, last_name, full_name, initials,
             staff_id, email, username, role, user_type, is_main_admin,
             is_active, created_at, updated_at,
             date_of_birth, blood_group, date_of_joining, monthly_salary,
             office_location, branch, additional_details,
             mobile, phone_number, profile_photo_url,
             aadhar_number, pan_card_number,
             bank_account_name, bank_account_number, bank_ifsc_code, bank_name,
             permanent_address, temporary_address
      FROM employee_users
      ORDER BY created_at DESC
    `);

    for (const employee of rows) {
      const [accessRows] = await db.query(`
        SELECT application, access_type, allowed_pages
        FROM employee_application_access
        WHERE employee_id = ?
        ORDER BY application ASC
      `, [employee.id]);
      const applicationAccess = {};
      for (const row of accessRows) {
        let allowedPages = [];
        try { allowedPages = JSON.parse(row.allowed_pages || '[]'); } catch (_) { allowedPages = []; }
        applicationAccess[row.application] = {
          access_type: row.access_type || 'none',
          allowed_pages: Array.isArray(allowedPages) ? allowedPages : [],
        };
      }
      employee.application_access = applicationAccess;

      const [legacyRows] = await db.query(`SELECT allowed_pages FROM role_page_access WHERE employee_id = ? LIMIT 1`, [employee.id]);
      try { employee.allowed_pages = legacyRows.length ? JSON.parse(legacyRows[0].allowed_pages || '[]') : []; }
      catch (_) { employee.allowed_pages = []; }
    }

    return res.json({ success: true, data: rows });
  } catch (err) {
    console.error('GET /employees ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/employees/:id/password  — Main Admin only.
// Decrypts the stored copy so the Admin Panel can show the original
// password. The database itself only holds the hash + encrypted copy.
router.get('/:id/password', authenticateToken, async (req, res) => {
  try {
    const [[me]] = await db.query('SELECT is_main_admin FROM employee_users WHERE id = ?', [req.user.id]);
    if (!me || Number(me.is_main_admin) !== 1) {
      return res.status(403).json({ success: false, message: 'Only the Main Admin can view passwords' });
    }
    await ensurePasswordSecurity();
    const [[row]] = await db.query(
      'SELECT password, password_enc FROM employee_users WHERE id = ?',
      [req.params.id],
    );
    if (!row) return res.status(404).json({ success: false, message: 'Employee not found' });

    let plain = row.password_enc ? decryptPassword(row.password_enc) : null;
    if (plain == null && row.password && !isBcryptHash(row.password)) plain = row.password; // not converted yet
    if (plain == null) {
      return res.json({
        success: true,
        available: false,
        password: null,
        message: 'Original password is not available — set a new password to store it.',
      });
    }
    res.set('Cache-Control', 'no-store');
    return res.json({ success: true, available: true, password: plain });
  } catch (err) {
    console.error('GET /employees/:id/password ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// routes/employees.js — Update GET /:id route:

router.get('/:id', async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT id, first_name, middle_name, last_name, full_name, initials,
             staff_id, email, username, role, user_type, is_main_admin, is_active,
             avatar_color, profile_photo, profile_photo_url, mobile, phone_number,
             date_of_birth, blood_group, date_of_joining, monthly_salary,
             office_location, branch, additional_details,
             aadhar_number, pan_card_number,
             bank_account_name, bank_account_number, bank_ifsc_code, bank_name,
             permanent_address, temporary_address, created_at, updated_at
      FROM employee_users WHERE id = ?
    `, [req.params.id]);
    if (rows.length === 0) return res.status(404).json({ success: false, message: 'Employee not found' });

    const employeeData = rows[0];
    const [accessRows] = await db.query(`
      SELECT application, access_type, allowed_pages
      FROM employee_application_access
      WHERE employee_id = ?
    `, [req.params.id]);
    employeeData.application_access = {};
    for (const row of accessRows) {
      let allowedPages = [];
      try { allowedPages = JSON.parse(row.allowed_pages || '[]'); } catch (_) { allowedPages = []; }
      employeeData.application_access[row.application] = {
        access_type: row.access_type || 'none',
        allowed_pages: Array.isArray(allowedPages) ? allowedPages : [],
      };
    }

    const [legacyRows] = await db.query(`SELECT allowed_pages FROM role_page_access WHERE employee_id = ? LIMIT 1`, [req.params.id]);
    try { employeeData.allowed_pages = legacyRows.length ? JSON.parse(legacyRows[0].allowed_pages || '[]') : []; }
    catch (_) { employeeData.allowed_pages = []; }

    // Attendance Details (from the Attendance / HRMS profile).
    try { employeeData.attendance = await readAttendanceDetails(req.params.id); }
    catch (e) { employeeData.attendance = null; }

    return res.json({ success: true, data: employeeData });
  } catch (err) {
    console.error('GET /employees/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});


// POST /api/employees/user-roles
router.post('/user-roles', async (req, res) => {
  const roleName = req.body.roleName || req.body.role_name;
  const userType = req.body.userType || req.body.user_type || 'employee'; // 🟢 Capture userType
  const applicationAccess = req.body.applicationAccess || req.body.application_access || {};
  if (!roleName) return res.status(400).json({ success: false, message: 'Role name is required' });

  const trimmedRoleName = roleName.toString().trim();
  const roleKey = trimmedRoleName
    .replace(/([a-z])([A-Z])/g, '$1_$2')
    .replace(/[^a-zA-Z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .toLowerCase();

  const connection = await db.getConnection();
  try {
    await connection.beginTransaction();
    const [existing] = await connection.query(`SELECT id FROM user_roles WHERE role_key = ?`, [roleKey]);
    if (existing.length) {
      await connection.rollback();
      return res.status(409).json({ success: false, message: 'Role already exists' });
    }

    const [result] = await connection.query(
      `INSERT INTO user_roles (role_name, role_key, user_type) VALUES (?, ?, ?)`,
      [trimmedRoleName, roleKey, userType]
    );

    for (const app of ['attendance', 'task_manager', 'client_repository']) {
      const item = applicationAccess[app] || {};
      const accessType = ['none', 'employee', 'admin'].includes(item.accessType || item.access_type)
        ? (item.accessType || item.access_type) : 'none';
      const pages = Array.isArray(item.allowedPages) ? item.allowedPages : (Array.isArray(item.allowed_pages) ? item.allowed_pages : []);
      await connection.query(
        `INSERT INTO role_application_access (role_id, application, access_type, allowed_pages) VALUES (?, ?, ?, ?)`,
        [result.insertId, app, accessType, JSON.stringify(pages)]
      );
    }

    await connection.commit();
    return res.status(201).json({ success: true, message: 'Role created successfully', data: { id: result.insertId, role_name: trimmedRoleName, role_key: roleKey, user_type: userType } });
  } catch (err) {
    await connection.rollback();
    console.error('POST /employees/user-roles ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  } finally { connection.release(); }
});

router.put('/user-roles/:id', async (req, res) => {
  const roleId = req.params.id;
  const roleName = req.body.roleName || req.body.role_name;
  const userType = req.body.userType || req.body.user_type || 'employee'; // 🟢 Capture userType
  const applicationAccess = req.body.applicationAccess || req.body.application_access || {};
  if (!roleName) return res.status(400).json({ success: false, message: 'Role name is required' });

  const trimmedRoleName = roleName.toString().trim();
  const roleKey = trimmedRoleName
    .replace(/([a-z])([A-Z])/g, '$1_$2')
    .replace(/[^a-zA-Z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .toLowerCase();

  const connection = await db.getConnection();
  try {
    await connection.beginTransaction();
    const [existing] = await connection.query(`SELECT id FROM user_roles WHERE role_key = ? AND id <> ?`, [roleKey, roleId]);
    if (existing.length) {
      await connection.rollback();
      return res.status(409).json({ success: false, message: 'Another role already uses this name' });
    }
    const [result] = await connection.query(`UPDATE user_roles SET role_name = ?, role_key = ?, user_type = ? WHERE id = ?`, [trimmedRoleName, roleKey, userType, roleId]);
    if (!result.affectedRows) {
      await connection.rollback();
      return res.status(404).json({ success: false, message: 'Role not found' });
    }

    for (const app of ['attendance', 'task_manager', 'client_repository']) {
      const item = applicationAccess[app] || {};
      const accessType = ['none', 'employee', 'admin'].includes(item.accessType || item.access_type)
        ? (item.accessType || item.access_type) : 'none';
      const pages = Array.isArray(item.allowedPages) ? item.allowedPages : (Array.isArray(item.allowed_pages) ? item.allowed_pages : []);
      await connection.query(
        `INSERT INTO role_application_access (role_id, application, access_type, allowed_pages)
         VALUES (?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE access_type = VALUES(access_type), allowed_pages = VALUES(allowed_pages)`,
        [roleId, app, accessType, JSON.stringify(pages)]
      );
    }

    await connection.commit();
    return res.status(200).json({ success: true, message: 'Role updated successfully' });
  } catch (err) {
    await connection.rollback();
    console.error('PUT /employees/user-roles/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  } finally { connection.release(); }
});

// DELETE /api/employees/user-roles/:id
router.delete('/user-roles/:id', async (req, res) => {
  try {
    const roleId = req.params.id;
    await db.query(`DELETE FROM user_roles WHERE id = ?`, [roleId]);
    return res.status(200).json({ success: true, message: 'Role deleted successfully' });
  } catch (err) {
    console.error('DELETE /employees/user-roles/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/employees
// POST /api/employees — Create with Role and Permissions
router.post('/', async (req, res) => {
  const {
    firstName, middleName = '', lastName,
    email, username, password, role,
    userType = 'employee', isMainAdmin = 0, allowedPages = [], applicationAccess = {},
    phoneNumber = '', aadharNumber = '', panCardNumber = '',
    bankAccountName = '', bankAccountNumber = '', bankIfscCode = '', bankName = '',
    permanentAddress = '', temporaryAddress = '',
    dateOfBirth = null, bloodGroup = '', dateOfJoining = null,
    monthlySalary = null, officeLocation = '', branch = '', additionalDetails = ''
  } = req.body;

  if (!firstName || !lastName || !email || !username || !password || !role) {
    return res.status(400).json({ success: false, message: 'Required fields are missing' });
  }
  if (badPassword(password)) {
    return res.status(400).json({ success: false, message: `Password must be at least ${MIN_PASSWORD} characters` });
  }
  // bcrypt hash for login + encrypted copy for the Main Admin view.
  await ensurePasswordSecurity();
  const pw = await passwordColumns(password);

  const connection = await db.getConnection();
  try {
    await connection.beginTransaction();
    const staffId = req.body.staffId || await generateStaffId(connection);
    const fullName = [firstName, middleName, lastName].filter(v => v && v.trim()).join(' ');
    const initials = (firstName[0] + (lastName[0] || '')).toUpperCase();

    const [result] = await connection.query(`
      INSERT INTO employee_users
      (first_name, middle_name, last_name, full_name, initials,
       staff_id, email, username, password, role, user_type, is_main_admin, is_active,
       phone_number, aadhar_number, pan_card_number,
       bank_account_name, bank_account_number, bank_ifsc_code, bank_name,
       permanent_address, temporary_address, date_of_birth, blood_group,
       date_of_joining, monthly_salary, office_location, branch, additional_details)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `, [
      firstName, middleName, lastName, fullName, initials,
      staffId, email, username, pw.hash, role, userType, isMainAdmin ? 1 : 0,
      phoneNumber, aadharNumber, panCardNumber,
      bankAccountName, bankAccountNumber, bankIfscCode, bankName,
      permanentAddress, temporaryAddress, dateOfBirth || null, bloodGroup,
      dateOfJoining || null, monthlySalary === '' ? null : monthlySalary, officeLocation, branch, additionalDetails
    ]);

    const newEmpId = result.insertId;
    await connection.query('UPDATE employee_users SET password_enc = ? WHERE id = ?', [pw.enc, newEmpId]);
    // The employee is added ONCE here — the Attendance app uses this profile
    // (no separate "Add Employee" in Attendance).
    const attendance = attendanceFromBody(req.body);
    const mode = ['Office', 'Home', 'Hybrid'].includes(attendance.workMode) ? attendance.workMode : 'Office';
    await connection.query(`
      INSERT INTO hrms_employee_profiles
      (employee_user_id, employee_code, full_name, email, department, work_mode, employment_status)
      VALUES (?, ?, ?, ?, ?, ?, 'Active')
    `, [newEmpId, staffId, fullName, email, role, mode]);

    const legacyPages = Array.isArray(allowedPages) ? allowedPages : [];
    await connection.query(
      `INSERT INTO role_page_access (employee_id, allowed_pages) VALUES (?, ?)`,
      [newEmpId, JSON.stringify(legacyPages)]
    );

    let finalAppAccess = applicationAccess;
    if (!finalAppAccess || Object.keys(finalAppAccess).length === 0) {
      const [roleAccessRows] = await connection.query(`
        SELECT ra.application, ra.access_type, ra.allowed_pages 
        FROM role_application_access ra
        JOIN user_roles ur ON ur.id = ra.role_id
        WHERE UPPER(TRIM(ur.role_name)) = UPPER(TRIM(?))
      `, [role]);

      finalAppAccess = {};
      for (const ra of roleAccessRows) {
        let pages = [];
        try { pages = JSON.parse(ra.allowed_pages || '[]'); } catch (_) { pages = []; }
        finalAppAccess[ra.application] = {
          accessType: ra.access_type,
          allowedPages: pages
        };
      }
    }

    for (const app of ['attendance', 'task_manager', 'client_repository']) {
      const item = finalAppAccess[app] || {};
      const accessType = ['none', 'employee', 'admin'].includes(item.accessType || item.access_type)
        ? (item.accessType || item.access_type) : 'none';
      const pages = Array.isArray(item.allowedPages) ? item.allowedPages : (Array.isArray(item.allowed_pages) ? item.allowed_pages : []);
      await connection.query(
        `INSERT INTO employee_application_access (employee_id, application, access_type, allowed_pages) VALUES (?, ?, ?, ?)`,
        [newEmpId, app, accessType, JSON.stringify(pages)]
      );
    }

    await connection.commit();
    try {
      await saveAttendanceDetails(newEmpId, attendanceFromBody(req.body), {
        staffId, fullName, email, role, isActive: true, user: req.user,
      });
    } catch (e) {
      console.warn('POST /employees: attendance details not saved:', e.message);
    }
    return res.status(201).json({ success: true, message: 'User created successfully', staffId });
  } catch (err) {
    await connection.rollback();
    console.error('POST /employees ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  } finally { connection.release(); }
});


// PUT /api/employees/:id — Update Employee & Cascade Name Changes to Task Assignments, Task List, Day Planner & Notifications
router.put('/:id', async (req, res) => {
  const empId = req.params.id;
  const {
    firstName, middleName = '', lastName, staffId,
    email, username, role, userType = 'employee', isMainAdmin = 0,
    allowedPages = [], applicationAccess = {}, password,
    phoneNumber = '', aadharNumber = '', panCardNumber = '',
    bankAccountName = '', bankAccountNumber = '', bankIfscCode = '', bankName = '',
    permanentAddress = '', temporaryAddress = '',
    dateOfBirth = null, bloodGroup = '', dateOfJoining = null,
    monthlySalary = null, officeLocation = '', branch = '', additionalDetails = ''
  } = req.body;

  const fullName = [firstName, middleName, lastName].filter(v => v && v.trim()).join(' ');
  const initials = (firstName[0] + (lastName[0] || '')).toUpperCase();

  const connection = await db.getConnection();
  try {
    await connection.beginTransaction();

    const [oldEmpRows] = await connection.query('SELECT full_name FROM employee_users WHERE id = ?', [empId]);
    if (!oldEmpRows.length) {
      await connection.rollback();
      return res.status(404).json({ success: false, message: 'Employee not found' });
    }
    const oldFullName = oldEmpRows[0].full_name;

    const commonSql = `
      first_name=?, middle_name=?, last_name=?, full_name=?, initials=?,
      staff_id=?, email=?, username=?, role=?, user_type=?, is_main_admin=?,
      phone_number=?, aadhar_number=?, pan_card_number=?,
      bank_account_name=?, bank_account_number=?, bank_ifsc_code=?, bank_name=?,
      permanent_address=?, temporary_address=?, date_of_birth=?, blood_group=?,
      date_of_joining=?, monthly_salary=?, office_location=?, branch=?, additional_details=?`;
    const commonParams = [
      firstName, middleName, lastName, fullName, initials, staffId, email, username, role, userType, isMainAdmin ? 1 : 0,
      phoneNumber, aadharNumber, panCardNumber, bankAccountName, bankAccountNumber, bankIfscCode, bankName,
      permanentAddress, temporaryAddress, dateOfBirth || null, bloodGroup, dateOfJoining || null,
      monthlySalary === '' ? null : monthlySalary, officeLocation, branch, additionalDetails
    ];

    if (password && password.trim()) {
      if (badPassword(password)) {
        await connection.rollback();
        return res.status(400).json({ success: false, message: `Password must be at least ${MIN_PASSWORD} characters` });
      }
      await ensurePasswordSecurity();
      const pw = await passwordColumns(password);
      await connection.query(
        `UPDATE employee_users SET ${commonSql}, password=?, password_enc=? WHERE id=?`,
        [...commonParams, pw.hash, pw.enc, empId],
      );
    } else {
      await connection.query(`UPDATE employee_users SET ${commonSql} WHERE id=?`, [...commonParams, empId]);
    }

    await connection.query(`UPDATE hrms_employee_profiles SET full_name=?, employee_code=?, email=?, department=? WHERE employee_user_id=?`, [fullName, staffId, email, role, empId]);

    if (oldFullName && oldFullName.trim().toUpperCase() !== fullName.trim().toUpperCase()) {
      const targetOldName = oldFullName.trim();
      const targetNewName = fullName.trim();
      await connection.query(`UPDATE task_list SET employee_name=? WHERE UPPER(TRIM(employee_name))=UPPER(TRIM(?))`, [targetNewName, targetOldName]);
      await connection.query(`UPDATE day_plan_rows SET employee_name=? WHERE UPPER(TRIM(employee_name))=UPPER(TRIM(?))`, [targetNewName, targetOldName]);
      await connection.query(`UPDATE notifications SET sender_name=? WHERE UPPER(TRIM(sender_name))=UPPER(TRIM(?))`, [targetNewName, targetOldName]);
      await connection.query(`UPDATE notifications SET recipient_name=? WHERE UPPER(TRIM(recipient_name))=UPPER(TRIM(?))`, [targetNewName, targetOldName]);
      await connection.query(`UPDATE task_planner SET employee_name=? WHERE UPPER(TRIM(employee_name))=UPPER(TRIM(?))`, [targetNewName.toUpperCase(), targetOldName.toUpperCase()]);
      await connection.query(`UPDATE task_planner_shares SET sender_employee_name=? WHERE UPPER(TRIM(sender_employee_name))=UPPER(TRIM(?))`, [targetNewName.toUpperCase(), targetOldName.toUpperCase()]);
      await connection.query(`UPDATE task_planner_shares SET receiver_employee_name=? WHERE UPPER(TRIM(receiver_employee_name))=UPPER(TRIM(?))`, [targetNewName, targetOldName]);
      await connection.query(`UPDATE videographer_planner SET employee_name=? WHERE UPPER(TRIM(employee_name))=UPPER(TRIM(?))`, [targetNewName.toUpperCase(), targetOldName.toUpperCase()]);
      await connection.query(`UPDATE videographer_planner_shares SET sender_employee_name=? WHERE UPPER(TRIM(sender_employee_name))=UPPER(TRIM(?))`, [targetNewName.toUpperCase(), targetOldName.toUpperCase()]);
      await connection.query(`UPDATE videographer_planner_shares SET receiver_employee_name=? WHERE UPPER(TRIM(receiver_employee_name))=UPPER(TRIM(?))`, [targetNewName, targetOldName]);
      for (const col of ['designer','videographer','video_editor','ui_ux_designer','developer','ads_handling','page_handling','website_designer']) {
        await connection.query(`UPDATE task_assignments SET ${col}=? WHERE UPPER(TRIM(${col}))=UPPER(TRIM(?))`, [targetNewName, targetOldName]);
      }
    }

    const pagesJson = JSON.stringify(Array.isArray(allowedPages) ? allowedPages : []);
    const [existingAccess] = await connection.query(`SELECT id FROM role_page_access WHERE employee_id=?`, [empId]);
    if (existingAccess.length) await connection.query(`UPDATE role_page_access SET allowed_pages=? WHERE employee_id=?`, [pagesJson, empId]);
    else await connection.query(`INSERT INTO role_page_access (employee_id, allowed_pages) VALUES (?, ?)`, [empId, pagesJson]);

    let finalAppAccess = applicationAccess;
    if (!finalAppAccess || Object.keys(finalAppAccess).length === 0) {
      const [roleAccessRows] = await connection.query(`
        SELECT ra.application, ra.access_type, ra.allowed_pages 
        FROM role_application_access ra
        JOIN user_roles ur ON ur.id = ra.role_id
        WHERE UPPER(TRIM(ur.role_name)) = UPPER(TRIM(?))
      `, [role]);

      finalAppAccess = {};
      for (const ra of roleAccessRows) {
        let pages = [];
        try { pages = JSON.parse(ra.allowed_pages || '[]'); } catch (_) { pages = []; }
        finalAppAccess[ra.application] = {
          accessType: ra.access_type,
          allowedPages: pages
        };
      }
    }

    // 🟢 Clear existing effective access or update via ON DUPLICATE KEY
    for (const app of ['attendance','task_manager','client_repository']) {
      const item = finalAppAccess[app] || {};
      const accessType = ['none','employee','admin'].includes(item.accessType || item.access_type) ? (item.accessType || item.access_type) : 'none';
      const pages = Array.isArray(item.allowedPages) ? item.allowedPages : (Array.isArray(item.allowed_pages) ? item.allowed_pages : []);
      await connection.query(`
        INSERT INTO employee_application_access (employee_id, application, access_type, allowed_pages)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE access_type=VALUES(access_type), allowed_pages=VALUES(allowed_pages)
      `, [empId, app, accessType, JSON.stringify(pages)]);
    }

    await connection.commit();
    try {
      const [[st]] = await db.query('SELECT is_active FROM employee_users WHERE id = ?', [empId]);
      await saveAttendanceDetails(empId, attendanceFromBody(req.body), {
        staffId, fullName, email, role, isActive: Number(st?.is_active) === 1, user: req.user,
      });
    } catch (e) {
      console.warn('PUT /employees/:id: attendance details not saved:', e.message);
    }
    return res.json({ success: true, message: 'User updated successfully' });
  } catch (err) {
    await connection.rollback();
    console.error('PUT /employees/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  } finally {
    connection.release();
  }
});

// DELETE /api/employees/:id
router.delete('/:id', async (req, res) => {
  const empId = req.params.id;
  try {
    const [result] = await db.query('UPDATE employee_users SET is_active = 0 WHERE id = ?', [empId]);
    if (result.affectedRows === 0)
      return res.status(404).json({ success: false, message: 'Employee not found' });
    try { await syncStatusFromAdmin(empId, false); } catch (e) { console.warn('status sync:', e.message); }
    
    return res.json({ success: true, message: 'Employee deactivated; history retained' });
  } catch (err) {
    console.error('DELETE /employees/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// PATCH /api/employees/:id
router.patch('/:id', async (req, res) => {
  try {
    const empId = req.params.id;
    const { isActive } = req.body;

    const [result] = await db.query(
      `
      UPDATE employee_users
      SET is_active = ?
      WHERE id = ?
      `,
      [
        isActive ? 1 : 0,
        empId,
      ]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({
        success: false,
        message: 'Employee not found',
      });
    }

    // Same Active / Inactive in the Attendance app.
    try { await syncStatusFromAdmin(empId, !!isActive); } catch (e) { console.warn('status sync:', e.message); }

    return res.json({
      success: true,
      message: 'Employee status updated successfully',
    });

  } catch (err) {
    console.error('PATCH /employees/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// PUT /api/employees/:id/profile
router.put('/:id/profile', async (req, res) => {
  const empId = req.params.id;
  const { firstName, middleName = '', lastName, username, email, avatarColor, password, currentPassword, profilePhoto } = req.body;

  try {
    const fullName = [firstName, middleName, lastName]
      .filter(name => name && name.trim() !== '')
      .join(' ');

    const initials = (firstName[0] + (lastName[0] || '')).toUpperCase();

    const [oldEmpRows] = await db.query('SELECT full_name, profile_photo FROM employee_users WHERE id = ?', [empId]);
    if (oldEmpRows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Employee not found'
      });
    }

    const oldProfilePhoto = oldEmpRows[0].profile_photo;
    const oldFullName = oldEmpRows[0].full_name;

    if (password && password.trim() !== '') {
      // Changing your own password needs the current one.
      if (badPassword(password)) {
        return res.status(400).json({ success: false, message: `New password must be at least ${MIN_PASSWORD} characters` });
      }
      const [[cur]] = await db.query('SELECT password FROM employee_users WHERE id = ?', [empId]);
      const check = await verifyPassword(currentPassword || '', cur?.password);
      if (!check.ok) {
        return res.status(400).json({ success: false, message: 'Current password is incorrect' });
      }
      await ensurePasswordSecurity();
      const pw = await passwordColumns(password);
      await db.query(
        `UPDATE employee_users SET
           first_name = ?, middle_name = ?, last_name = ?, full_name = ?, initials = ?,
           username = ?, email = ?, avatar_color = ?, profile_photo = ?, password = ?, password_enc = ?
         WHERE id = ?`,
        [firstName, middleName, lastName, fullName, initials, username, email, avatarColor || '', profilePhoto === undefined ? oldProfilePhoto : profilePhoto, pw.hash, pw.enc, empId]
      );
    } else {
      await db.query(
        `UPDATE employee_users SET
           first_name = ?, middle_name = ?, last_name = ?, full_name = ?, initials = ?,
           username = ?, email = ?, avatar_color = ?, profile_photo = ?
         WHERE id = ?`,
        [firstName, middleName, lastName, fullName, initials, username, email, avatarColor || '', profilePhoto === undefined ? oldProfilePhoto : profilePhoto, empId]
      );
    }

    // Save the additional Profile Management fields.
    // Missing fields remain unchanged.
    const profileExtraFields = [
      ['phoneNumber', 'phone_number'],
      ['phoneNumber', 'mobile'],
      ['aadharNumber', 'aadhar_number'],
      ['panCardNumber', 'pan_card_number'],
      ['bankAccountName', 'bank_account_name'],
      ['bankAccountNumber', 'bank_account_number'],
      ['bankIfscCode', 'bank_ifsc_code'],
      ['bankName', 'bank_name'],
      ['permanentAddress', 'permanent_address'],
      ['temporaryAddress', 'temporary_address']
    ];

    const extraUpdates = [];
    const extraValues = [];

    for (const [requestField, databaseColumn] of profileExtraFields) {
      if (Object.prototype.hasOwnProperty.call(req.body, requestField)) {
        extraUpdates.push(`${databaseColumn} = ?`);
        extraValues.push(String(req.body[requestField] ?? '').trim());
      }
    }

    if (extraUpdates.length > 0) {
      await db.query(
        `UPDATE employee_users SET ${extraUpdates.join(', ')} WHERE id = ?`,
        [...extraValues, empId]
      );
    }
    await db.query(`UPDATE hrms_employee_profiles SET full_name = ?, email = ? WHERE employee_user_id = ?`, [fullName, email, empId]);

    if (oldFullName && oldFullName.trim().toUpperCase() !== fullName.trim().toUpperCase()) {
      const targetOldName = oldFullName.trim();
      const targetNewName = fullName.trim();

      await db.query(`UPDATE task_list SET employee_name = ? WHERE UPPER(TRIM(employee_name)) = UPPER(TRIM(?))`, [targetNewName, targetOldName]);
      await db.query(`UPDATE day_plan_rows SET employee_name = ? WHERE UPPER(TRIM(employee_name)) = UPPER(TRIM(?))`, [targetNewName, targetOldName]);

      const roleColumns = [
        'designer', 'videographer', 'video_editor', 
        'ui_ux_designer', 'developer', 'ads_handling', 
        'page_handling', 'website_designer'
      ];

      for (const col of roleColumns) {
        await db.query(`UPDATE task_assignments SET ${col} = ? WHERE UPPER(TRIM(${col})) = UPPER(TRIM(?))`, [targetNewName, targetOldName]);
      }
    }

    return res.json({ success: true, message: 'Profile updated successfully' });
  } catch (err) {
    console.error('PUT /employees/:id/profile ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ═══════════════════════════════════════════════════════════════
// ROLE APPLICATION ACCESS ROUTES (For AccessMasterScreen)
// ═══════════════════════════════════════════════════════════════

router.get('/role-access/:id', async (req, res) => {
  try {
    const roleId = req.params.id;
    const [rows] = await db.query(`
      SELECT application, access_type, allowed_pages
      FROM role_application_access
      WHERE role_id = ?
    `, [roleId]);

    const accessList = rows.map(row => {
      let allowedPages = [];
      try { allowedPages = JSON.parse(row.allowed_pages || '[]'); } catch (_) { allowedPages = []; }
      return {
        application: row.application,
        access_type: row.access_type,
        allowed_pages: allowedPages
      };
    });

    return res.json({ success: true, data: accessList });
  } catch (err) {
    console.error('GET /employees/role-access/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// PUT /api/employees/role-access/:id
router.put('/role-access/:id', async (req, res) => {
  const roleId = req.params.id;
  const applications = req.body.applications || [];

  const connection = await db.getConnection();
  try {
    await connection.beginTransaction();

    // 1. Update role_application_access table
    for (const appItem of applications) {
      const appName = appItem.application;
      const accessType = ['none', 'employee', 'admin'].includes(appItem.accessType || appItem.access_type)
        ? (appItem.accessType || appItem.access_type) : 'none';
      const pages = Array.isArray(appItem.allowedPages) 
        ? appItem.allowedPages 
        : (Array.isArray(appItem.allowed_pages) ? appItem.allowed_pages : []);

      await connection.query(`
        INSERT INTO role_application_access (role_id, application, access_type, allowed_pages)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE access_type = VALUES(access_type), allowed_pages = VALUES(allowed_pages)
      `, [roleId, appName, accessType, JSON.stringify(pages)]);
    }

    // 2. 🟢 AUTO-SYNC: Fetch role name and update all employees belonging to this role instantly!
    const [roleRows] = await connection.query('SELECT role_name FROM user_roles WHERE id = ?', [roleId]);
    if (roleRows.length > 0) {
      const roleName = roleRows[0].role_name;
      const [employees] = await connection.query('SELECT id FROM employee_users WHERE UPPER(TRIM(role)) = UPPER(TRIM(?))', [roleName]);

      for (const emp of employees) {
        for (const appItem of applications) {
          const appName = appItem.application;
          const accessType = ['none', 'employee', 'admin'].includes(appItem.accessType || appItem.access_type)
            ? (appItem.accessType || appItem.access_type) : 'none';
          const pages = Array.isArray(appItem.allowedPages) ? appItem.allowedPages : (Array.isArray(appItem.allowed_pages) ? appItem.allowed_pages : []);

          await connection.query(`
            INSERT INTO employee_application_access (employee_id, application, access_type, allowed_pages)
            VALUES (?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE access_type = VALUES(access_type), allowed_pages = VALUES(allowed_pages)
          `, [emp.id, appName, accessType, JSON.stringify(pages)]);
        }
      }
    }

    await connection.commit();
    return res.json({ success: true, message: 'Role access updated and synced to all employees successfully' });
  } catch (err) {
    await connection.rollback();
    console.error('PUT /employees/role-access/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  } finally {
    connection.release();
  }
});

module.exports = router;