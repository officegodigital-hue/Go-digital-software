// routes/employees.js — Updated CRUD API with Role-Based Page Access & User Types
const express = require('express');
const router  = express.Router();
const bcrypt  = require('bcrypt');
const db      = require('../config/db');


// routes/employees.js — Place /user-roles routes at the TOP before /:id routes

// ═══════════════════════════════════════════════════════════════
// 1. USER ROLE MASTER ROUTES (MUST BE AT THE VERY TOP)
// ═══════════════════════════════════════════════════════════════
// GET /api/employees/user-roles


router.get('/user-roles', async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT id, role_name, role_key, user_type
      FROM user_roles
      ORDER BY user_type ASC, role_name ASC
    `);

    return res.json({
      success: true,
      data: rows
    });
  } catch (err) {
    console.error('GET /user-roles ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/employees
router.get('/', async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT id, full_name, initials, staff_id, email, username,
              role, user_type, is_main_admin, is_active, created_at
       FROM employee_users ORDER BY created_at DESC`
    );
    return res.json({ success: true, data: rows });
  } catch (err) {
    console.error('GET /employees ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/employees/:id
router.get('/:id', async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT id, first_name, middle_name, last_name, full_name, initials,
              staff_id, email, username, role, user_type, is_main_admin, is_active, created_at
       FROM employee_users WHERE id = ?`,
      [req.params.id]
    );
    if (rows.length === 0)
      return res.status(404).json({ success: false, message: 'Employee not found' });

    let employeeData = rows[0];

    const [accessRows] = await db.query(
      `SELECT allowed_pages FROM role_page_access WHERE employee_id = ?`,
      [req.params.id]
    );

    employeeData.allowed_pages = accessRows.length > 0 ? JSON.parse(accessRows[0].allowed_pages || '[]') : [];

    return res.json({ success: true, data: employeeData });
  } catch (err) {
    console.error('GET /employees/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});


// POST /api/employees/user-roles
router.post('/user-roles', async (req, res) => {
  try {
    const roleName = req.body.roleName || req.body.role_name;
    const userType = req.body.userType || req.body.user_type;

    if (!roleName || !userType) {
      return res.status(400).json({ success: false, message: 'Role name and user type are required' });
    }

    const trimmedRoleName = roleName.trim();
    const normalizedUserType = userType.toString().trim().toLowerCase();
    
    const roleKey = trimmedRoleName
      .replace(/([a-z])([A-Z])/g, '$1_$2')
      .replace(/[^a-zA-Z0-9]+/g, '_')
      .replace(/^_+|_+$/g, '')
      .toLowerCase();

    // Check duplicate
    const [existing] = await db.query(
      `SELECT id FROM user_roles WHERE role_key = ? AND user_type = ?`,
      [roleKey, normalizedUserType]
    );

    if (existing.length > 0) {
      return res.status(409).json({ success: false, message: 'Role already exists' });
    }

    const [result] = await db.query(
      `INSERT INTO user_roles (role_name, role_key, user_type) VALUES (?, ?, ?)`,
      [trimmedRoleName, roleKey, normalizedUserType]
    );

    return res.status(201).json({
      success: true,
      message: 'Role created successfully',
      data: { id: result.insertId, role_name: trimmedRoleName, role_key: roleKey, user_type: normalizedUserType }
    });
  } catch (err) {
    console.error('POST /employees/user-roles ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// PUT /api/employees/user-roles/:id
router.put('/user-roles/:id', async (req, res) => {
  try {
    const roleId = req.params.id;
    const roleName = req.body.roleName || req.body.role_name;
    const userType = req.body.userType || req.body.user_type;

    if (!roleName || !userType) {
      return res.status(400).json({ success: false, message: 'Role name and user type are required' });
    }

    const trimmedRoleName = roleName.trim();
    const normalizedUserType = userType.toString().trim().toLowerCase();
    
    const roleKey = trimmedRoleName
      .replace(/([a-z])([A-Z])/g, '$1_$2')
      .replace(/[^a-zA-Z0-9]+/g, '_')
      .replace(/^_+|_+$/g, '')
      .toLowerCase();

    await db.query(
      `UPDATE user_roles SET role_name = ?, role_key = ?, user_type = ? WHERE id = ?`,
      [trimmedRoleName, roleKey, normalizedUserType, roleId]
    );

    return res.status(200).json({ success: true, message: 'Role updated successfully' });
  } catch (err) {
    console.error('PUT /employees/user-roles/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
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
    firstName, middleName = '', lastName, staffId, 
    email, username, password, role, // 🟢 Role variable here
    userType = 'employee', isMainAdmin = 0, allowedPages = [] 
  } = req.body;

  if (!firstName || !lastName || !staffId || !email || !username || !password || !role)
    return res.status(400).json({ success: false, message: 'All fields are required' });

  // const fullName = `${firstName} ${middleName}`.trim();

  const fullName = [
  firstName,
  middleName,
  lastName
]
.filter(name => name && name.trim() !== '')
// .where(name => name && name.trim() !== '')
.join(' ');

  const initials = (firstName[0] + (lastName[0] || '')).toUpperCase();

  try {
    const [result] = await db.query(
      `INSERT INTO employee_users
         (first_name, middle_name, last_name, full_name, initials,
          staff_id, email, username, password, role, user_type, is_main_admin, is_active)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)`,
      [firstName, middleName, lastName, fullName, initials,
       staffId, email, username, password, role, userType, isMainAdmin ? 1 : 0] // 🟢 Role inserted here
    );

    const newEmpId = result.insertId;

    if (allowedPages && allowedPages.length > 0) {
      await db.query(
        `INSERT INTO role_page_access (employee_id, allowed_pages) VALUES (?, ?)`,
        [newEmpId, JSON.stringify(allowedPages)]
      );
    }

    return res.status(201).json({ success: true, message: 'User created successfully' });
  } catch (err) {
    console.error('POST /employees ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// PUT /api/employees/:id — Update Employee & Cascade Name Changes to Task Assignments, Task List, Day Planner & Notifications
router.put('/:id', async (req, res) => {
  const { 
    firstName, middleName = '', lastName, staffId, 
    email, username, role, userType = 'employee', 
    isMainAdmin = 0, allowedPages = [], password 
  } = req.body;

  const empId = req.params.id;

  const fullName = [firstName, middleName, lastName]
    .filter(name => name && name.trim() !== '')
    .join(' ');

  const initials = (firstName[0] + (lastName[0] || '')).toUpperCase();

  try {
    // 1. Fetch old employee details to get their previous name
    const [oldEmpRows] = await db.query('SELECT full_name FROM employee_users WHERE id = ?', [empId]);
    const oldFullName = oldEmpRows.length > 0 ? oldEmpRows[0].full_name : null;

    // 2. Update employee_users table
    if (password && password.trim() !== '') {
      await db.query(
        `UPDATE employee_users SET
           first_name=?, middle_name=?, last_name=?, full_name=?, initials=?,
           staff_id=?, email=?, username=?, password=?, role=?, user_type=?, is_main_admin=?
         WHERE id=?`,
        [firstName, middleName, lastName, fullName, initials, staffId, email, username, password, role, userType, isMainAdmin ? 1 : 0, empId]
      );
    } else {
      await db.query(
        `UPDATE employee_users SET
           first_name=?, middle_name=?, last_name=?, full_name=?, initials=?,
           staff_id=?, email=?, username=?, role=?, user_type=?, is_main_admin=?
         WHERE id=?`,
        [firstName, middleName, lastName, fullName, initials, staffId, email, username, role, userType, isMainAdmin ? 1 : 0, empId]
      );
    }

    // 3. 🟢 CASCADE NAME CHANGE: If employee name changed, update task_assignments, task_list, day_plan_rows, and notifications tables instantly
    if (oldFullName && oldFullName.trim().toUpperCase() !== fullName.trim().toUpperCase()) {
      const targetOldName = oldFullName.trim();
      const targetNewName = fullName.trim();

      // Update task_list records
      await db.query(
        `UPDATE task_list SET employee_name = ? WHERE UPPER(TRIM(employee_name)) = UPPER(TRIM(?))`,
        [targetNewName, targetOldName]
      );

      // Update day_plan_rows records
      await db.query(
        `UPDATE day_plan_rows SET employee_name = ? WHERE UPPER(TRIM(employee_name)) = UPPER(TRIM(?))`,
        [targetNewName, targetOldName]
      );

      // 🟢 Update notifications table (sender_name & recipient_name)
      await db.query(
        `UPDATE notifications SET sender_name = ? WHERE UPPER(TRIM(sender_name)) = UPPER(TRIM(?))`,
        [targetNewName, targetOldName]
      );
      await db.query(
        `UPDATE notifications SET recipient_name = ? WHERE UPPER(TRIM(recipient_name)) = UPPER(TRIM(?))`,
        [targetNewName, targetOldName]
      );

      // 🟢 Update task_planner tables (employee_name, sender/receiver names)
      await db.query(
        `UPDATE task_planner SET employee_name = ? WHERE UPPER(TRIM(employee_name)) = UPPER(TRIM(?))`,
        [targetNewName.toUpperCase(), targetOldName.toUpperCase()]
      );
      await db.query(
        `UPDATE task_planner_shares SET sender_employee_name = ? WHERE UPPER(TRIM(sender_employee_name)) = UPPER(TRIM(?))`,
        [targetNewName.toUpperCase(), targetOldName.toUpperCase()]
      );
      await db.query(
        `UPDATE task_planner_shares SET receiver_employee_name = ? WHERE UPPER(TRIM(receiver_employee_name)) = UPPER(TRIM(?))`,
        [targetNewName, targetOldName]
      );

      // 🟢 Update videographer_planner tables
      await db.query(
        `UPDATE videographer_planner SET employee_name = ? WHERE UPPER(TRIM(employee_name)) = UPPER(TRIM(?))`,
        [targetNewName.toUpperCase(), targetOldName.toUpperCase()]
      );
      await db.query(
        `UPDATE videographer_planner_shares SET sender_employee_name = ? WHERE UPPER(TRIM(sender_employee_name)) = UPPER(TRIM(?))`,
        [targetNewName.toUpperCase(), targetOldName.toUpperCase()]
      );
      await db.query(
        `UPDATE videographer_planner_shares SET receiver_employee_name = ? WHERE UPPER(TRIM(receiver_employee_name)) = UPPER(TRIM(?))`,
        [targetNewName, targetOldName]
      );

      // Update role columns in task_assignments table
      const roleColumns = [
        'designer', 'videographer', 'video_editor', 
        'ui_ux_designer', 'developer', 'ads_handling', 
        'page_handling', 'website_designer'
      ];

      for (const col of roleColumns) {
        await db.query(
          `UPDATE task_assignments SET ${col} = ? WHERE UPPER(TRIM(${col})) = UPPER(TRIM(?))`,
          [targetNewName, targetOldName]
        );
      }
    }

    // 4. Update Page Access
    const [existingAccess] = await db.query(`SELECT id FROM role_page_access WHERE employee_id = ?`, [empId]);
    const pagesJson = JSON.stringify(allowedPages || []);

    if (existingAccess.length > 0) {
      await db.query(`UPDATE role_page_access SET allowed_pages = ? WHERE employee_id = ?`, [pagesJson, empId]);
    } else if (allowedPages && allowedPages.length > 0) {
      await db.query(`INSERT INTO role_page_access (employee_id, allowed_pages) VALUES (?, ?)`, [empId, pagesJson]);
    }

    return res.json({ success: true, message: 'User updated successfully' });
  } catch (err) {
    console.error('PUT /employees/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// DELETE /api/employees/:id
router.delete('/:id', async (req, res) => {
  const empId = req.params.id;
  try {
    // Delete associated permissions first to prevent foreign key constraint restriction
    await db.query('DELETE FROM role_page_access WHERE employee_id = ?', [empId]);
    
    // Then delete the employee user
    const [result] = await db.query('DELETE FROM employee_users WHERE id = ?', [empId]);
    
    if (result.affectedRows === 0)
      return res.status(404).json({ success: false, message: 'Employee not found' });
    
    return res.json({ success: true, message: 'Employee deleted successfully' });
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

    return res.json({
      success: true,
      message: 'Employee status updated successfully',
    });

  } catch (err) {
    console.error('PATCH /employees/:id ERROR:', err.message);

    return res.status(500).json({
      success: false,
      message: err.message,
    });
  }
});







module.exports = router;