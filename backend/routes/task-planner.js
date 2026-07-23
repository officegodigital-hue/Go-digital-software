// routes/task-planner.js
//
// task_planner        — stores row structure (id, employee_name, content_type, content)
// task_planner_shares — every Share click INSERTs a brand-new row, NEVER updates
//
const express = require('express');
const router  = express.Router();
const db      = require('../config/db');

const { createNotification } = require('./notifications');

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/task-planner?employee=NAME
// Returns all planner section rows for this employee
// ─────────────────────────────────────────────────────────────────────────────
router.get('/', async (req, res) => {
  const { employee } = req.query;
  if (!employee)
    return res.status(400).json({ success: false, message: 'employee query param required' });

  try {
    const [rows] = await db.query(
      `SELECT * FROM task_planner
       WHERE UPPER(employee_name) = ?
       ORDER BY created_at ASC`,
      [employee.toUpperCase()]
    );
    return res.json({ success: true, data: rows });
  } catch (err) {
    console.error('GET /task-planner ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/task-planner/shares?employee=NAME
// Returns full share history for this employee (newest first)
// Each row = one share event (INSERT-only, nothing ever updated here)
// ─────────────────────────────────────────────────────────────────────────────
router.get('/shares', async (req, res) => {
  const { employee } = req.query;
  if (!employee)
    return res.status(400).json({ success: false, message: 'employee query param required' });

  try {
    const [rows] = await db.query(
      `SELECT
         s.*,
         tp.content_type AS section_content_type
       FROM task_planner_shares s
       LEFT JOIN task_planner tp ON tp.id = s.planner_id
       WHERE UPPER(s.sender_employee_name) = ?
       ORDER BY s.shared_at DESC`,
      [employee.toUpperCase()]
    );
    return res.json({ success: true, data: rows });
  } catch (err) {
    console.error('GET /task-planner/shares ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/task-planner — create a new planner section row
// ─────────────────────────────────────────────────────────────────────────────
router.post('/', async (req, res) => {
  const { employeeName, contentType, content = '' } = req.body;
  if (!employeeName || !contentType)
    return res.status(400).json({ success: false, message: 'employeeName and contentType required' });

  try {
    const [result] = await db.query(
      `INSERT INTO task_planner (employee_name, content_type, content)
       VALUES (?, ?, ?)`,
      [employeeName.toUpperCase(), contentType, content]
    );
    return res.status(201).json({
      success: true,
      message: 'Row created',
      data: { id: result.insertId },
    });
  } catch (err) {
    console.error('POST /task-planner ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// PUT /api/task-planner/:id
// Only used to update content_type label if user edits it
// ─────────────────────────────────────────────────────────────────────────────
router.put('/:id', async (req, res) => {
  const { contentType, content } = req.body;
  try {
    const [result] = await db.query(
      `UPDATE task_planner SET content_type = ?, content = ? WHERE id = ?`,
      [contentType || '', content || '', req.params.id]
    );
    if (result.affectedRows === 0)
      return res.status(404).json({ success: false, message: 'Row not found' });
    return res.json({ success: true, message: 'Updated' });
  } catch (err) {
    console.error('PUT /task-planner/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /api/task-planner/:id/share
//
// Called on every Share button click.
// ALWAYS INSERTs a brand-new row into task_planner_shares.
// NEVER updates any existing share record.
// Also clears the content field on the main task_planner row.
//
// Body fields:
//   senderEmployeeName  — full name of logged-in employee (who is sharing)
//   senderEmployeeId    — DB id of logged-in employee
//   contentType         — the content type label
//   content             — the actual content being shared
//   receiverEmployeeName — full name of the employee being shared to
//   receiverEmployeeId  — DB id of the employee being shared to
//   receiverRole        — role label (Designer, Page Handler, etc.)
//   receiverShort       — short initials (D, PH, etc.)
// ─────────────────────────────────────────────────────────────────────────────
router.patch('/:id/share', async (req, res) => {
  const {
    senderEmployeeName,
    senderEmployeeId,
    contentType,
    content,
    receiverEmployeeName,
    receiverEmployeeId,
    receiverRole,
    receiverShort,
  } = req.body;

  // Validate required fields
  if (!senderEmployeeName || !receiverEmployeeName || !receiverRole) {
    return res.status(400).json({
      success: false,
      message: 'senderEmployeeName, receiverEmployeeName and receiverRole are required',
    });
  }

  if (!content || content.trim() === '') {
    return res.status(400).json({
      success: false,
      message: 'content cannot be empty',
    });
  }

  const connection = await db.getConnection();
  try {
    await connection.beginTransaction();

    // ── Step 1: INSERT a brand-new share record ────────────────────────────
    // This is the ONLY write to task_planner_shares.
    // Every share = 1 new INSERT row. Nothing here is ever updated.
    const [insertResult] = await connection.query(
      `INSERT INTO task_planner_shares (
         planner_id,
         sender_employee_name,
         sender_employee_id,
         content_type,
         content,
         receiver_employee_name,
         receiver_employee_id,
         receiver_role,
         receiver_short
       ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        req.params.id,
        senderEmployeeName.toUpperCase(),
        senderEmployeeId   || null,
        contentType        || '',
        content,
        receiverEmployeeName,
        receiverEmployeeId || null,
        receiverRole,
        receiverShort      || '',
      ]
    );

    // ── Step 2: Clear content on the main row (ready for next share) ───────
    await connection.query(
      `UPDATE task_planner SET content = '' WHERE id = ?`,
      [req.params.id]
    );

    await connection.commit();

await createNotification({
  senderName: senderEmployeeName,
  recipientName: receiverEmployeeName,
  message: JSON.stringify({
    preview: `Task Planner shared by ${senderEmployeeName}`,
    payload: {
      type: "TASK_PLANNER_SHARE",
      sender: senderEmployeeName,
      contentType: contentType,
      content: content,
    }
  }),
});

    return res.json({
      success: true,
      message: 'Share saved as new record',
      data: { shareId: insertResult.insertId },
    });
  } catch (err) {
    await connection.rollback();
    console.error('PATCH /task-planner/:id/share ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  } finally {
    connection.release();
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /api/task-planner/:id/reset — clears content field only
// ─────────────────────────────────────────────────────────────────────────────
router.patch('/:id/reset', async (req, res) => {
  try {
    await db.query(
      `UPDATE task_planner SET content = '' WHERE id = ?`,
      [req.params.id]
    );
    return res.json({ success: true, message: 'Row reset' });
  } catch (err) {
    console.error('PATCH /task-planner/:id/reset ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// DELETE /api/task-planner/:id
// Deletes the section; CASCADE removes all its share history automatically
// ─────────────────────────────────────────────────────────────────────────────
router.delete('/:id', async (req, res) => {
  try {
    const [result] = await db.query(
      `DELETE FROM task_planner WHERE id = ?`, [req.params.id]
    );
    if (result.affectedRows === 0)
      return res.status(404).json({ success: false, message: 'Row not found' });
    return res.json({ success: true, message: 'Deleted' });
  } catch (err) {
    console.error('DELETE /task-planner/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;