// routes/task-master.js — Task Master API (Manage task roles and tasks)
const express = require('express');
const router = express.Router();
const db = require('../config/db');

// GET /api/task-master — Get all tasks grouped by role
router.get('/', async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT id, task_name, role_key, created_at
       FROM task_master
       ORDER BY role_key ASC, task_name ASC`
    );
    return res.json({ success: true, data: rows });
  } catch (err) {
    console.error('GET /task-master ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/task-master/:roleKey — Get tasks for a specific role
router.get('/:roleKey', async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT id, task_name, role_key
       FROM task_master
       WHERE role_key = ?
       ORDER BY task_name ASC`,
      [req.params.roleKey]
    );
    return res.json({ success: true, data: rows });
  } catch (err) {
    console.error('GET /task-master/:roleKey ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/task-master — Create new task
// Body: { task_name, role_key }
router.post('/', async (req, res) => {
  const { task_name, role_key } = req.body;

  if (!task_name || !role_key) {
    return res.status(400).json({ 
      success: false, 
      message: 'task_name and role_key are required' 
    });
  }

  try {
    const [result] = await db.query(
      `INSERT INTO task_master (task_name, role_key) VALUES (?, ?)`,
      [task_name, role_key]
    );

    return res.status(201).json({
      success: true,
      message: 'Task created successfully',
      data: { id: result.insertId, task_name, role_key },
    });
  } catch (err) {
    console.error('POST /task-master ERROR:', err.message);
    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ 
        success: false,  
        message: `Task "${task_name}" already exists for this role` 
      });
    }
    return res.status(500).json({ success: false, message: err.message });
  }
});

// PUT /api/task-master/:id — Update existing task
// Body: { task_name, role_key }
router.put('/:id', async (req, res) => {
  const { task_name, role_key } = req.body;

  if (!task_name || !role_key) {
    return res.status(400).json({ 
      success: false, 
      message: 'task_name and role_key are required' 
    });
  }

  try {
    const [result] = await db.query(
      `UPDATE task_master SET task_name = ?, role_key = ? WHERE id = ?`,
      [task_name, role_key, req.params.id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ 
        success: false, 
        message: 'Task not found' 
      });
    }

    return res.json({
      success: true,
      message: 'Task updated successfully',
      data: { id: req.params.id, task_name, role_key },
    });
  } catch (err) {
    console.error('PUT /task-master/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// DELETE /api/task-master/:id — Delete task
router.delete('/:id', async (req, res) => {
  try {
    const [result] = await db.query(
      `DELETE FROM task_master WHERE id = ?`,
      [req.params.id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ 
        success: false, 
        message: 'Task not found' 
      });
    }

    return res.json({
      success: true,
      message: 'Task deleted successfully',
    });
  } catch (err) {
    console.error('DELETE /task-master/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;