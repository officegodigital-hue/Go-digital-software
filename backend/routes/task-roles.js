// ═══════════════════════════════════════════════════════════════════════════════
// routes/task-roles.js — Task Roles API (CORRECTED - WITH INSERT)
// ═══════════════════════════════════════════════════════════════════════════════
// CORRECTED DESIGN:
// - GET: Query task_roles table (not task_master)
// - POST: INSERT into task_roles table
// - task_roles stores: role_key + role_name
// - task_master stores: id + task_name + role_key

const express = require('express');
const router = express.Router();
const db = require('../config/db');

// ── HARDCODED ROLE MAPPING (for reference/fallback) ─────────────────────────
const roleMapping = {
  'ads_handler_task': 'Ads Handler Tasks',
  'page_handler_task': 'Page Handler Tasks',
  'graphic_designer_task': 'Graphic Designer Tasks',
  'ui_ux_designer_task': 'UI/UX Designer Tasks',
  'videographer_task': 'Videographer Tasks',
  'developer_task': 'Developer Tasks',
};

// GET /api/task-roles — Fetch all roles from task_roles TABLE
// ✅ Query task_roles table directly (not task_master)
router.get('/', async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT role_key, role_name FROM task_roles ORDER BY role_key ASC`
    );

    return res.json({
      success: true,
      data: rows
    });

  } catch (err) {
    console.error('❌ GET /api/task-roles ERROR:', err.message);
    return res.status(500).json({
      success: false,
      message: err.message
    });
  }
});

// POST /api/task-roles — INSERT new role into task_roles TABLE
// ✅ Actually saves to database
router.post('/', async (req, res) => {
  const { role_name, role_key } = req.body;

  // ✅ Validate input
  if (!role_name || !role_key) {
    return res.status(400).json({
      success: false,
      message: 'role_name and role_key are required'
    });
  }

  try {
    // ✅ Check if role already exists
    const [exists] = await db.query(
      `SELECT role_key FROM task_roles WHERE role_key = ?`,
      [role_key]
    );

    if (exists.length > 0) {
      return res.status(409).json({
        success: false,
        message: `Role "${role_key}" already exists`
      });
    }

    // ✅ INSERT into task_roles table
    await db.query(
      `INSERT INTO task_roles (role_key, role_name) VALUES (?, ?)`,
      [role_key, role_name]
    );

    return res.status(201).json({
      success: true,
      message: 'Role created successfully',
      data: {
        role_key,
        role_name
      }
    });

  } catch (err) {
    console.error('❌ POST /api/task-roles ERROR:', err.message);

    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({
        success: false,
        message: 'This role already exists'
      });
    }

    return res.status(500).json({
      success: false,
      message: err.message
    });
  }
});

module.exports = router;