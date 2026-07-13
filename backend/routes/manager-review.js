// routes/manager-review.js — work submitted by employees (status = COMPLETED),
// awaiting a manager's Approve / Rework / Reject decision + comment.
// Manager decisions live in their own `manager_review` table, one row per
// tracking item, rather than as extra columns on time_tracking_task_items.
const express = require('express');
const router  = express.Router();
const db      = require('../config/db');
const { createNotification } = require('./notifications');

// GET /api/manager-review — every tracking row currently COMPLETED, across
// all employees/clients, with the manager's current action/comment on it
// (LEFT JOIN so rows with no review yet still show up, defaulting to 'ACTION').
router.get('/', async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT
        tti.id AS tracking_item_id,
        tl.client_name,
        tl.employee_name,
        tl.deliverables AS task,
        tl.duration,
        tti.status,
        mr.manager_action,
        mr.manager_comment
      FROM time_tracking_task_items tti
      JOIN task_list tl ON tl.id = tti.task_list_id
      LEFT JOIN manager_review mr ON mr.tracking_item_id = tti.id
      WHERE tti.status = 'COMPLETED'
      ORDER BY tti.updated_at DESC
    `);

    return res.json({ success: true, data: rows });
  } catch (err) {
    console.error('GET /manager-review ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// PATCH /api/manager-review/:trackingItemId — find-or-create the review row
// for this tracking item, then update action and/or comment on it. Either
// field can be sent alone (the dropdown fires with just { action }, the
// comment field debounces and fires with just { comment }).
router.patch('/:trackingItemId', async (req, res) => {
  const { trackingItemId } = req.params;
  const { action, comment } = req.body;

  if (action === undefined && comment === undefined) {
    return res.status(400).json({ success: false, message: 'action or comment is required' });
  }

  try {
    // Confirm the tracking item actually exists before attaching a review to it.
    const [trackingRows] = await db.query(
      `SELECT id FROM time_tracking_task_items WHERE id = ?`,
      [trackingItemId]
    );
    if (trackingRows.length === 0) {
      return res.status(404).json({ success: false, message: 'Tracking item not found' });
    }

    const [existing] = await db.query(
      `SELECT * FROM manager_review WHERE tracking_item_id = ?`,
      [trackingItemId]
    );

    if (existing.length > 0) {
      const updates = ['reviewed_at = NOW()'];
      const values = [];
      if (action !== undefined) { updates.push('manager_action = ?'); values.push(action); }
      if (comment !== undefined) { updates.push('manager_comment = ?'); values.push(comment); }
      values.push(existing[0].id);

      await db.query(`UPDATE manager_review SET ${updates.join(', ')} WHERE id = ?`, values);
    } else {
      await db.query(
        `INSERT INTO manager_review (tracking_item_id, manager_action, manager_comment, reviewed_at)
         VALUES (?, ?, ?, NOW())`,
        [trackingItemId, action ?? 'ACTION', comment ?? null]
      );
    }

    const [rows] = await db.query(
      `SELECT * FROM manager_review WHERE tracking_item_id = ?`,
      [trackingItemId]
    );

    // FIX: this is the missing piece — when the manager actually sets a
    // decision (APPROVED/REWORK/REJECTED, not just typing a comment), the
    // employee who did the work gets a real notification about it.
    if (action !== undefined && action !== 'ACTION') {
      try {
        const [taskInfo] = await db.query(
          `SELECT tl.employee_name, tl.deliverables
           FROM time_tracking_task_items tti
           JOIN task_list tl ON tl.id = tti.task_list_id
           WHERE tti.id = ?`,
          [trackingItemId]
        );
        if (taskInfo.length > 0 && taskInfo[0].employee_name) {
          const commentSuffix = comment ? ` ${comment}` : '';
          await createNotification({
            senderName: 'Manager',
            recipientName: taskInfo[0].employee_name,
            message: `Your task "${taskInfo[0].deliverables}" has been marked ${action}.${commentSuffix}`,
          });
        }
      } catch (notifyErr) {
        console.error('⚠️ manager-review notification failed (non-fatal):', notifyErr.message);
      }
    }

    return res.json({ success: true, message: 'Review updated', data: rows[0] });
  } catch (err) {
    console.error('PATCH /manager-review/:trackingItemId ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;