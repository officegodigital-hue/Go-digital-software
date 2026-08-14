const express = require('express');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');

const router = express.Router();
const db = require('../config/db');

// ADMIN LOGIN ONLY
// POST /api/auth/login
router.post('/login', async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({
      success: false,
      message: 'Email and password are required',
    });
  }

  try {
    const [rows] = await db.query(
      `
      SELECT *
      FROM users
      WHERE email = ?
      LIMIT 1
      `,
      [email]
    );

    if (rows.length === 0) {
      return res.status(401).json({
        success: false,
        message: 'Invalid email or password',
      });
    }

    const user = rows[0];

    let passwordMatch = false;

    if (user.password_hash && user.password_hash.startsWith('$2')) {
      passwordMatch = await bcrypt.compare(password, user.password_hash);
    } else {
      passwordMatch = password === user.password_hash;
    }

    if (!passwordMatch) {
      return res.status(401).json({
        success: false,
        message: 'Invalid email or password',
      });
    }

    const token = jwt.sign(
      {
        id: user.id,
        email: user.email,

        // Important for admin protected routes
        role: 'admin',
        userType: 'admin',
        user_type: 'admin',
        isAdmin: true,
        is_admin: 1,
      },
      process.env.JWT_SECRET || 'godigital_secret',
      { expiresIn: '7d' }
    );

    return res.json({
      success: true,
      message: 'Login successful',
      token,
      user: {
        id: user.id,
        fullName: user.full_name,
        email: user.email,
        employeeId: user.employee_id,
        department: user.department,
        phone: user.phone,

        role: 'admin',
        userType: 'admin',
        isAdmin: true,
      },
    });
  } catch (err) {
    console.error('LOGIN ERROR:', err.message);

    return res.status(500).json({
      success: false,
      message: err.message,
    });
  }
});

module.exports = router;