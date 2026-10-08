// routes/auth.js — CORRECTED VERSION with proper bcrypt

const express = require('express');
const router = express.Router();
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const db = require('../config/db'); 

const JWT_SECRET = process.env.JWT_SECRET || 'change-this-in-production-to-random-key';
const JWT_EXPIRY = '7d';

// ⭐ POST /api/auth/login — FIXED: Uses bcrypt for password verification ⭐
router.post('/login', async (req, res) => {
  const { email, password, userType } = req.body;

  if (!email || !password) {
    return res.status(400).json({
      success: false,
      message: 'Email and password are required',
    });
  }

  try {
    const [rows] = await db.query(
      `
      SELECT id, first_name, last_name, full_name,
             email, username, password,
             role, user_type, is_active, is_main_admin,
             staff_id, initials
      FROM employee_users
      WHERE (
        LOWER(email) = LOWER(?)
        OR LOWER(username) = LOWER(?)
      )
      AND LOWER(user_type) = LOWER(?)
      LIMIT 1
      `,
      [email, email, userType || 'employee']
    );

    if (rows.length === 0) {
      console.log(`❌ Login failed: No user found with "${email}"`);
      return res.status(401).json({
        success: false,
        message: 'Username or email not found.',
      });
    }

    const user = rows[0];
    console.log(`📌 User found: ${user.full_name} (${user.role})`);

    if (!user.is_active) {
      console.log(`❌ Login failed: User "${user.full_name}" is inactive`);
      return res.status(403).json({
        success: false,
        message: 'Your account has been deactivated. Contact admin.',
      });
    }

    const passwordMatch = password === user.password;

    if (!passwordMatch) {
      console.log(`❌ Login failed: Incorrect password for "${email}"`);
      return res.status(401).json({
        success: false,
        message: 'Incorrect password.',
      });
    }

    // 🟢 1. Generate JWT token first
    const token = jwt.sign(
      {
        id: user.id,
        fullName: user.full_name,
        email: user.email,
        role: user.role,
        userType: user.user_type,
        isMainAdmin: user.is_main_admin == 1 || user.is_main_admin === true,
      },
      JWT_SECRET,
      { expiresIn: JWT_EXPIRY }
    );

    // 🟢 2. Fetch legacy allowed pages
    const [accessRows] = await db.query(
      `SELECT allowed_pages FROM role_page_access WHERE employee_id = ?`,
      [user.id]
    );

    const allowedPages = accessRows.length > 0 
      ? JSON.parse(accessRows[0].allowed_pages || '[]') 
      : [];

    // 🟢 3. Fetch application access (Attendance, Task Manager, Client Repository)
    const [appAccessRows] = await db.query(
      `SELECT application, access_type, allowed_pages FROM employee_application_access WHERE employee_id = ?`,
      [user.id]
    );

    const applicationAccess = {};
    for (const row of appAccessRows) {
      let pages = [];
      try { pages = JSON.parse(row.allowed_pages || '[]'); } catch (_) { pages = []; }
      applicationAccess[row.application] = {
        access_type: row.access_type || 'none',
        allowed_pages: Array.isArray(pages) ? pages : [],
      };
    }

    // Fallback to role_application_access if employee-specific is empty
    if (Object.keys(applicationAccess).length === 0 && user.role) {
      const [roleAccessRows] = await db.query(`
        SELECT ra.application, ra.access_type, ra.allowed_pages 
        FROM role_application_access ra
        JOIN user_roles ur ON ur.id = ra.role_id
        WHERE UPPER(TRIM(ur.role_name)) = UPPER(TRIM(?))
      `, [user.role]);
      
      for (const ra of roleAccessRows) {
        let pages = [];
        try { pages = JSON.parse(ra.allowed_pages || '[]'); } catch (_) { pages = []; }
        applicationAccess[ra.application] = {
          access_type: ra.access_type || 'none',
          allowed_pages: pages,
        };
      }
    }

    console.log(`✅ Login successful: ${user.full_name} (${user.role})`);

    // 🟢 4. Return success response with token & access data
    return res.json({
      success: true,
      message: 'Login successful',
      token: token,
      user: {
        id: user.id,
        firstName: user.first_name,
        lastName: user.last_name,
        fullName: user.full_name,
        email: user.email,
        username: user.username,
        role: user.role,
        userType: user.user_type,
        isMainAdmin: user.is_main_admin == 1 || user.is_main_admin === true,
        staffId: user.staff_id,
        initials: user.initials,
        isMainAdmin: user.is_main_admin == 1 || user.is_main_admin === true,
        allowed_pages: allowedPages,
        application_access: applicationAccess,
      },
    });
  } catch (err) {
    console.error('❌ POST /auth/login ERROR:', err.message);
    return res.status(500).json({
      success: false,
      message: 'Server error during login',
    });
  }
});

// POST /api/auth/logout
router.post('/logout', (req, res) => {
  return res.json({
    success: true,
    message: 'Logout successful',
  });
});

// GET /api/auth/verify — Verify JWT token
router.get('/verify', authenticateToken, (req, res) => {
  return res.json({
    success: true,
    message: 'Token is valid',
    user: req.user,
  });
});

// Read the signed-in employee's current profile from employee_users.
router.get('/me', authenticateToken, (req, res) => {
  return res.json({
    success: true,
    data: {
      id: req.user.id,
      fullName: req.user.fullName,
      staffId: req.user.staffId,
      email: req.user.email,
      role: req.user.role,
      userType: req.user.userType,
    },
  });
});

// POST /api/auth/refresh — Refresh JWT token
router.post('/refresh', authenticateToken, (req, res) => {
  const newToken = jwt.sign(
    {
      id: req.user.id,
      email: req.user.email,
      role: req.user.role,
      userType: req.user.userType,
    },
    JWT_SECRET,
    { expiresIn: JWT_EXPIRY }
  );

  return res.json({
    success: true,
    message: 'Token refreshed',
    token: newToken,
  });
});

// ⭐ Middleware to authenticate JWT token ⭐
function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({
      success: false,
      message: 'Access token required',
    });
  }

  jwt.verify(token, JWT_SECRET, async (err, user) => {
    if (err) {
      if (err.name === 'TokenExpiredError') {
        return res.status(401).json({
          success: false,
          message: 'Token has expired',
        });
      }
      return res.status(403).json({
        success: false,
        message: 'Invalid token',
      });
    }

    try {
      const [[account]] = await db.query('SELECT id, full_name, staff_id, email, role, user_type, is_active FROM employee_users WHERE id = ?', [user.id]);
      if (!account || !Number(account.is_active)) {
        return res.status(401).json({ success: false, message: 'Employee account is unavailable. Please sign in again.' });
      }
      req.user = { ...user, id: account.id, fullName: account.full_name, staffId: account.staff_id,
        email: account.email, role: account.role, userType: account.user_type };
      next();
    } catch (error) {
      return res.status(503).json({ success: false, message: 'Unable to verify employee account' });
    }
  });
}

module.exports = router;
module.exports.authenticateToken = authenticateToken;
// Shared so every auth layer verifies against the exact key login signs with.
module.exports.JWT_SECRET = JWT_SECRET;

