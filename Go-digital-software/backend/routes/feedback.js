// routes/feedback.js - Feedback Management API

const express = require('express');
const router = express.Router();
const db = require('../config/db');
const { authenticateToken } = require('./auth');

// ══════════════════════════════════════════════════════════════════════════
// GET /api/feedback - Get all feedback for logged-in employee
// ══════════════════════════════════════════════════════════════════════════
router.get('/', authenticateToken, async (req, res) => {
  try {
    const employeeId = req.user.id;

    console.log('[FEEDBACK] GET - Fetching feedback for employee ID:', employeeId);

    const [rows] = await db.query(
      `SELECT id, client_name, feedback_text, created_at, updated_at
       FROM feedback 
       WHERE employee_id = ?
       ORDER BY created_at DESC`,
      [employeeId]
    );

    console.log('[FEEDBACK] ✅ Found', rows.length, 'feedback records');

    return res.json({
      success: true,
      data: rows,
    });
  } catch (err) {
    console.error('[FEEDBACK] GET ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ══════════════════════════════════════════════════════════════════════════
// POST /api/feedback - Create new feedback
// ══════════════════════════════════════════════════════════════════════════
router.post('/', authenticateToken, async (req, res) => {
  try {
    const { clientName, feedback } = req.body;
    const employeeId = req.user.id;
    const employeeName = req.user.fullName;

    console.log('[FEEDBACK] POST - Creating feedback');
    console.log(`  Employee: ${employeeName} (ID: ${employeeId})`);
    console.log(`  Client: ${clientName}`);

    // Validation
    if (!clientName || !feedback || feedback.trim() === '') {
      return res.status(400).json({
        success: false,
        message: 'Client name and feedback are required',
      });
    }

    if (!employeeId || !employeeName) {
      console.error('[FEEDBACK] ❌ Missing user info:', { employeeId, employeeName });
      return res.status(401).json({
        success: false,
        message: 'Employee information not found in token',
      });
    }

    // Insert feedback
    const [result] = await db.query(
      `INSERT INTO feedback (employee_id, employee_name, client_name, feedback_text, created_at, updated_at)
       VALUES (?, ?, ?, ?, NOW(), NOW())`,
      [employeeId, employeeName, clientName.trim(), feedback.trim()]
    );

    console.log('[FEEDBACK] ✅ Feedback created with ID:', result.insertId);

    return res.status(201).json({
      success: true,
      message: 'Feedback saved successfully',
      data: {
        id: result.insertId,
        clientName: clientName,
        feedback: feedback,
        employeeName: employeeName,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      },
    });
  } catch (err) {
    console.error('[FEEDBACK] POST ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ══════════════════════════════════════════════════════════════════════════
// GET /api/feedback/:id - Get single feedback
// ══════════════════════════════════════════════════════════════════════════
router.get('/:id', authenticateToken, async (req, res) => {
  try {
    const employeeId = req.user.id;
    const feedbackId = req.params.id;

    console.log('[FEEDBACK] GET - Fetching feedback ID:', feedbackId);

    const [rows] = await db.query(
      `SELECT id, employee_id, employee_name, client_name, feedback_text, created_at, updated_at
       FROM feedback 
       WHERE id = ? AND employee_id = ?`,
      [feedbackId, employeeId]
    );

    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Feedback not found' });
    }

    return res.json({ success: true, data: rows[0] });
  } catch (err) {
    console.error('[FEEDBACK] GET /:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ══════════════════════════════════════════════════════════════════════════
// PUT /api/feedback/:id - Update feedback
// ══════════════════════════════════════════════════════════════════════════
router.put('/:id', authenticateToken, async (req, res) => {
  try {
    const employeeId = req.user.id;
    const feedbackId = req.params.id;
    const { clientName, feedback } = req.body;

    console.log('[FEEDBACK] PUT - Updating feedback ID:', feedbackId);

    // Validation
    if (!clientName || !feedback || feedback.trim() === '') {
      return res.status(400).json({
        success: false,
        message: 'Client name and feedback are required',
      });
    }

    // Verify ownership
    const [existing] = await db.query(
      `SELECT id FROM feedback WHERE id = ? AND employee_id = ?`,
      [feedbackId, employeeId]
    );

    if (existing.length === 0) {
      return res.status(404).json({ success: false, message: 'Feedback not found' });
    }

    // Update
    await db.query(
      `UPDATE feedback 
       SET client_name = ?, feedback_text = ?, updated_at = NOW()
       WHERE id = ? AND employee_id = ?`,
      [clientName.trim(), feedback.trim(), feedbackId, employeeId]
    );

    console.log('[FEEDBACK] ✅ Feedback updated');

    return res.json({
      success: true,
      message: 'Feedback updated successfully',
      data: { id: feedbackId, clientName, feedback },
    });
  } catch (err) {
    console.error('[FEEDBACK] PUT ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ══════════════════════════════════════════════════════════════════════════
// DELETE /api/feedback/:id - Delete feedback
// ══════════════════════════════════════════════════════════════════════════
router.delete('/:id', authenticateToken, async (req, res) => {
  try {
    const employeeId = req.user.id;
    const feedbackId = req.params.id;

    console.log('[FEEDBACK] DELETE - Deleting feedback ID:', feedbackId);

    const [result] = await db.query(
      `DELETE FROM feedback WHERE id = ? AND employee_id = ?`,
      [feedbackId, employeeId]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: 'Feedback not found' });
    }

    console.log('[FEEDBACK] ✅ Feedback deleted');

    return res.json({ success: true, message: 'Feedback deleted successfully' });
  } catch (err) {
    console.error('[FEEDBACK] DELETE ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;