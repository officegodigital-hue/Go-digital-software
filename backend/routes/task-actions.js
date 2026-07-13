// ═══════════════════════════════════════════════════════════════════════════════
// routes/task-actions.js — CORRECTED
// ✅ Gets time_tracking_task_items_id and task_list_id from time_tracking_task_items
// ═══════════════════════════════════════════════════════════════════════════════

const express = require('express');
const router = express.Router();
const db = require('../config/db');

// ✅ Helper: Get tracking item details (includes both IDs)
async function getTrackingItemWithIds(trackingItemId) {
  const [rows] = await db.query(
    `SELECT id as time_tracking_task_items_id, task_list_id 
     FROM time_tracking_task_items 
     WHERE id = ?`,
    [trackingItemId]
  );

  if (rows.length === 0) {
    throw new Error(`Tracking item ${trackingItemId} not found`);
  }

  return {
    time_tracking_task_items_id: rows[0].time_tracking_task_items_id,
    task_list_id: rows[0].task_list_id,
  };
}

// ✅ Helper: Get or create action row
async function getOrCreateActionRow(trackingItemId) {
  // ✅ Get both IDs from time_tracking_task_items
  const { time_tracking_task_items_id, task_list_id } = await getTrackingItemWithIds(trackingItemId);

  // Check if action already exists
  const [existing] = await db.query(
    `SELECT * FROM task_action WHERE time_tracking_task_items_id = ?`,
    [time_tracking_task_items_id]
  );

  if (existing.length > 0) {
    return existing[0];
  }

  // ✅ Create with both IDs from tracking item
  const [result] = await db.query(
    `INSERT INTO task_action (time_tracking_task_items_id, task_list_id)
     VALUES (?, ?)`,
    [time_tracking_task_items_id, task_list_id]
  );

  const [rows] = await db.query(
    `SELECT * FROM task_action WHERE id = ?`,
    [result.insertId]
  );

  return rows[0];
}

// ═══════════════════════════════════════════════════════════════════════════════
// GET /api/task-actions/by-tracking-item/:trackingItemId
// ═══════════════════════════════════════════════════════════════════════════════
router.get('/by-tracking-item/:trackingItemId', async (req, res) => {
  try {
    const { trackingItemId } = req.params;

    const [rows] = await db.query(
      `SELECT * FROM task_action WHERE time_tracking_task_items_id = ? LIMIT 1`,
      [trackingItemId]
    );

    return res.json({
      success: true,
      data: rows[0] || null,
    });
  } catch (err) {
    console.error('❌ GET /task-actions/by-tracking-item ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ═══════════════════════════════════════════════════════════════════════════════
// POST /api/task-actions/start
// ✅ Accepts: trackingItemId (gets IDs from time_tracking_task_items table)
// ═══════════════════════════════════════════════════════════════════════════════
router.post('/start', async (req, res) => {
  const { trackingItemId } = req.body;

  if (!trackingItemId) {
    return res.status(400).json({
      success: false,
      message: 'trackingItemId is required',
    });
  }

  try {
    // ✅ Get both IDs from time_tracking_task_items
    const action = await getOrCreateActionRow(trackingItemId);

    // Set start_time
    await db.query(
      `UPDATE task_action SET start_time = NOW() WHERE id = ?`,
      [action.id]
    );

    // Update tracking item status
    await db.query(
      `UPDATE time_tracking_task_items SET status = 'IN PROGRESS' WHERE id = ?`,
      [trackingItemId]
    );

    const [updated] = await db.query(
      `SELECT * FROM task_action WHERE id = ?`,
      [action.id]
    );

    return res.json({
      success: true,
      message: 'Task started',
      data: updated[0],
    });
  } catch (err) {
    console.error('❌ POST /task-actions/start ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ═══════════════════════════════════════════════════════════════════════════════
// POST /api/task-actions/hold
// ═══════════════════════════════════════════════════════════════════════════════
router.post('/hold', async (req, res) => {
  const { trackingItemId } = req.body;

  if (!trackingItemId) {
    return res.status(400).json({
      success: false,
      message: 'trackingItemId is required',
    });
  }

  try {
    // ✅ Get both IDs from time_tracking_task_items
    const action = await getOrCreateActionRow(trackingItemId);

    // Find next empty hold_time_N slot
    let slot = null;
    for (let i = 1; i <= 10; i++) {
      if (action[`hold_time_${i}`] === null) {
        slot = i;
        break;
      }
    }

    if (!slot) {
      return res.status(400).json({
        success: false,
        message: 'Maximum 10 holds reached',
      });
    }

    // Record hold time
    await db.query(
      `UPDATE task_action SET hold_time_${slot} = NOW() WHERE id = ?`,
      [action.id]
    );

    // Update tracking item status
    await db.query(
      `UPDATE time_tracking_task_items SET status = 'ON HOLD' WHERE id = ?`,
      [trackingItemId]
    );

    const [updated] = await db.query(
      `SELECT * FROM task_action WHERE id = ?`,
      [action.id]
    );

    return res.json({
      success: true,
      message: `Task on hold (slot ${slot})`,
      data: updated[0],
    });
  } catch (err) {
    console.error('❌ POST /task-actions/hold ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ═══════════════════════════════════════════════════════════════════════════════
// POST /api/task-actions/restart
// ═══════════════════════════════════════════════════════════════════════════════
router.post('/restart', async (req, res) => {
  const { trackingItemId } = req.body;

  if (!trackingItemId) {
    return res.status(400).json({
      success: false,
      message: 'trackingItemId is required',
    });
  }

  try {
    // ✅ Get both IDs from time_tracking_task_items
    const action = await getOrCreateActionRow(trackingItemId);

    // Find next empty restart_time_N slot
    let slot = null;
    for (let i = 1; i <= 10; i++) {
      if (action[`restart_time_${i}`] === null) {
        slot = i;
        break;
      }
    }

    if (!slot) {
      return res.status(400).json({
        success: false,
        message: 'Maximum 10 restarts reached',
      });
    }

    // Record restart time
    await db.query(
      `UPDATE task_action SET restart_time_${slot} = NOW() WHERE id = ?`,
      [action.id]
    );

    // Update tracking item status
    await db.query(
      `UPDATE time_tracking_task_items SET status = 'IN PROGRESS' WHERE id = ?`,
      [trackingItemId]
    );

    const [updated] = await db.query(
      `SELECT * FROM task_action WHERE id = ?`,
      [action.id]
    );

    return res.json({
      success: true,
      message: `Task restarted (slot ${slot})`,
      data: updated[0],
    });
  } catch (err) {
    console.error('❌ POST /task-actions/restart ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ═══════════════════════════════════════════════════════════════════════════════
// POST /api/task-actions/complete
// ═══════════════════════════════════════════════════════════════════════════════
router.post('/complete', async (req, res) => {
  const { trackingItemId, performance, comment } = req.body;

  if (!trackingItemId) {
    return res.status(400).json({
      success: false,
      message: 'trackingItemId is required',
    });
  }

  try {
    // ✅ Get both IDs from time_tracking_task_items
    const action = await getOrCreateActionRow(trackingItemId);

    // Record completion
    await db.query(
      `UPDATE task_action SET complete_time = NOW() WHERE id = ?`,
      [action.id]
    );

    // Update tracking item status and performance
    await db.query(
      `UPDATE time_tracking_task_items 
       SET status = 'COMPLETED', performance = ? 
       WHERE id = ?`,
      [performance || 'N/A', trackingItemId]
    );

    const [updated] = await db.query(
      `SELECT * FROM task_action WHERE id = ?`,
      [action.id]
    );

    return res.json({
      success: true,
      message: 'Task completed',
      data: updated[0],
    });
  } catch (err) {
    console.error('❌ POST /task-actions/complete ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ═══════════════════════════════════════════════════════════════════════════════
// POST /api/task-actions/reject
// ═══════════════════════════════════════════════════════════════════════════════
router.post('/reject', async (req, res) => {
  const { trackingItemId, reason } = req.body;

  if (!trackingItemId) {
    return res.status(400).json({
      success: false,
      message: 'trackingItemId is required',
    });
  }

  try {
    // ✅ Get both IDs from time_tracking_task_items
    const action = await getOrCreateActionRow(trackingItemId);

    // Record rejection
    await db.query(
      `UPDATE task_action SET reject_time = NOW() WHERE id = ?`,
      [action.id]
    );

    // Update tracking item status
    await db.query(
      `UPDATE time_tracking_task_items SET status = 'REJECTED' WHERE id = ?`,
      [trackingItemId]
    );

    const [updated] = await db.query(
      `SELECT * FROM task_action WHERE id = ?`,
      [action.id]
    );

    return res.json({
      success: true,
      message: 'Task rejected',
      data: updated[0],
    });
  } catch (err) {
    console.error('❌ POST /task-actions/reject ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ═══════════════════════════════════════════════════════════════════════════════
// GET /api/task-actions/:actionId
// Get complete action details
// ═══════════════════════════════════════════════════════════════════════════════
router.get('/:actionId', async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT ta.*, 
              tti.s_no, tti.task_description, tti.submit_date,
              tl.client_name, tl.deliverables
       FROM task_action ta
       LEFT JOIN time_tracking_task_items tti ON ta.time_tracking_task_items_id = tti.id
       LEFT JOIN task_list tl ON ta.task_list_id = tl.id
       WHERE ta.id = ?`,
      [req.params.actionId]
    );

    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Not found' });
    }

    return res.json({ success: true, data: rows[0] });
  } catch (err) {
    console.error('❌ GET /task-actions/:actionId ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;