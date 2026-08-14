const db = require("../config/db");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");

const createToken = (user) => {
  return jwt.sign(
    {
      id: user.id,
      email: user.email,
      role: user.role,
    },
    process.env.JWT_SECRET,
    { expiresIn: "7d" }
  );
};

// Signup API
exports.signup = async (req, res) => {
  try {
    const {
      full_name,
      email,
      password,
      employee_id,
      department,
      phone,
      role,
    } = req.body;

    if (!full_name || !email || !password) {
      return res.status(400).json({
        success: false,
        message: "Full name, email and password are required",
      });
    }

    const [existingUser] = await db.query(
      "SELECT id FROM users WHERE email = ?",
      [email]
    );

    if (existingUser.length > 0) {
      return res.status(409).json({
        success: false,
        message: "Email already exists",
      });
    }

    const password_hash = await bcrypt.hash(password, 10);
    const userRole = role || "admin";

    const [result] = await db.query(
      `INSERT INTO users 
      (full_name, email, password_hash, employee_id, department, phone, role)
      VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [
        full_name,
        email,
        password_hash,
        employee_id || null,
        department || null,
        phone || null,
        userRole,
      ]
    );

    res.status(201).json({
      success: true,
      message: "Account created successfully",
      user_id: result.insertId,
    });
  } catch (error) {
    console.error("Signup Error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
    });
  }
};

// Login API
exports.login = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: "Email and password are required",
      });
    }

    const [users] = await db.query(
      "SELECT * FROM users WHERE email = ? AND status = 'active'",
      [email]
    );

    if (users.length === 0) {
      return res.status(401).json({
        success: false,
        message: "Invalid email or password",
      });
    }

    const user = users[0];

    const isMatch = await bcrypt.compare(password, user.password_hash);

    if (!isMatch) {
      return res.status(401).json({
        success: false,
        message: "Invalid email or password",
      });
    }

    const token = createToken(user);

    res.json({
      success: true,
      message: "Login successful",
      token,
      user: {
        id: user.id,
        full_name: user.full_name,
        email: user.email,
        role: user.role,
        department: user.department,
        employee_id: user.employee_id,
      },
    });
  } catch (error) {
    console.error("Login Error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
    });
  }
};

// Logged in user details
exports.me = async (req, res) => {
  try {
    const [users] = await db.query(
      `SELECT id, full_name, email, role, department, employee_id, phone, profile_image 
       FROM users WHERE id = ?`,
      [req.user.id]
    );

    if (users.length === 0) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    res.json({
      success: true,
      user: users[0],
    });
  } catch (error) {
    console.error("Me Error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
    });
  }
};