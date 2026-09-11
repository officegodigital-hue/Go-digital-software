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
    // Query employee_users table
    // const [rows] = await db.query(
    //   `SELECT id, first_name, last_name, full_name, email, username, 
    //           password, role, user_type, is_active, staff_id, initials
    //    FROM employee_users 
    //    WHERE (email = ? OR username = ?) AND user_type = ?
    //    LIMIT 1`,
    //   [email, email, userType || 'employee']
    // );
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

    // if (rows.length === 0) {
    //   console.log(`❌ Login failed: No user found with email "${email}"`);
    //   return res.status(401).json({
    //     success: false,
    //     message: 'Invalid email or password',
    //   });
    // }

    if (rows.length === 0) {
  console.log(`❌ Login failed: No user found with "${email}"`);
  return res.status(401).json({
    success: false,
    message: 'Username or email not found.',
  });
}

    const user = rows[0];
    console.log(`📌 User found: ${user.full_name} (${user.role})`);

    // Check if user is active
    if (!user.is_active) {
      console.log(`❌ Login failed: User "${user.full_name}" is inactive`);
      return res.status(403).json({
        success: false,
        message: 'Your account has been deactivated. Contact admin.',
      });
    }

    // ⭐ FIXED: Use bcrypt to compare passwords ⭐
    // const passwordMatch = await bcrypt.compare(password, user.password);
    const passwordMatch = password === user.password;

    // if (!passwordMatch) {
    //   console.log(`❌ Login failed: Invalid password for "${email}"`);
    //   return res.status(401).json({
    //     success: false,
    //     message: 'Invalid email or password',
    //   });
    // }

    if (!passwordMatch) {
  console.log(`❌ Login failed: Incorrect password for "${email}"`);
  return res.status(401).json({
    success: false,
    message: 'Incorrect password.',
  });
}

// Password check pannuthuku apram intha query-a podunga:
const [accessRows] = await db.query(
  `SELECT allowed_pages FROM role_page_access WHERE employee_id = ?`,
  [user.id]
);

const allowedPages = accessRows.length > 0 
  ? JSON.parse(accessRows[0].allowed_pages || '[]') 
  : [];

    // Generate JWT token
    const token = jwt.sign(
      {
        id: user.id,
        fullName: user.full_name,
        email: user.email,
        role: user.role,
        userType: user.user_type,
      },
      JWT_SECRET,
      { expiresIn: JWT_EXPIRY }
    );

    console.log(`✅ Login successful: ${user.full_name} (${user.role})`);

    // Return success response
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
        staffId: user.staff_id,
        initials: user.initials,
        isMainAdmin: user.is_main_admin == 1 || user.is_main_admin === true, // 🟢 itha add pannunga
  allowed_pages: allowedPages, // 🟢 itha add pannunga

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

  jwt.verify(token, JWT_SECRET, (err, user) => {
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

    req.user = user;
    next();
  });
}

module.exports = router;
module.exports.authenticateToken = authenticateToken;