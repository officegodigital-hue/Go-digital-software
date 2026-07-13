// routes/notifications.js — per-person inbox: only messages this employee
// sent or received show up, ever. Nobody else's conversations leak through.
const express = require('express');
const router  = express.Router();
const db      = require('../config/db');

// Small internal helper other route files can call to drop a notification
// in without duplicating this logic (used by tracking-items.js on complete,
// and manager-review.js on review actions).
async function createNotification({ senderName, recipientName, message }) {
  await db.query(
    `INSERT INTO notifications (sender_name, recipient_name, message) VALUES (?, ?, ?)`,
    [senderName, recipientName, message]
  );
}

function formatTime(dateVal) {
  if (!dateVal) return '';
  const d = new Date(dateVal);
  const now = new Date();
  const diffMins = Math.round((now - d) / 60000);
  if (diffMins < 5) return 'Just Now';
  let hours = d.getHours();
  const minutes = d.getMinutes().toString().padStart(2, '0');
  const ampm = hours >= 12 ? 'pm' : 'am';
  hours = hours % 12 || 12;
  return `${hours}.${minutes}${ampm}`;
}

// GET /api/notifications/:employeeName — every message this person sent or
// received. `type`/`otherParty` are computed relative to THIS person, so the
// exact same row would show as SENT for the sender and RECEIVED for the
// recipient — nobody sees the other side's unrelated conversations.
router.get('/:employeeName', async (req, res) => {
  const { employeeName } = req.params;
  try {
    const [rows] = await db.query(
      `SELECT * FROM notifications
       WHERE sender_name = ? OR recipient_name = ?
       ORDER BY created_at DESC`,
      [employeeName, employeeName]
    );

    const data = rows.map((r) => {
      const isSentByMe = r.sender_name === employeeName;
      return {
        id: r.id,
        otherParty: isSentByMe ? r.recipient_name : r.sender_name,
        message: r.message,
        time: formatTime(r.created_at),
        type: isSentByMe ? 'SENT' : 'RECEIVED',
        isSeen: !!r.is_seen,
        isFavorite: !!r.is_favorite,
        isArchived: !!r.is_archived,
      };
    });

    return res.json({ success: true, data });
  } catch (err) {
    console.error('GET /notifications/:employeeName ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// PATCH /api/notifications/:id — toggle isFavorite / isSeen / isArchived.
// Send only the field(s) you want changed.
router.patch('/:id', async (req, res) => {
  const { id } = req.params;
  const { isFavorite, isSeen, isArchived } = req.body;

  if (isFavorite === undefined && isSeen === undefined && isArchived === undefined) {
    return res.status(400).json({ success: false, message: 'Nothing to update' });
  }

  try {
    const updates = [];
    const values = [];
    if (isFavorite !== undefined) { updates.push('is_favorite = ?'); values.push(isFavorite ? 1 : 0); }
    if (isSeen !== undefined)     { updates.push('is_seen = ?');     values.push(isSeen ? 1 : 0); }
    if (isArchived !== undefined) { updates.push('is_archived = ?'); values.push(isArchived ? 1 : 0); }
    values.push(id);

    const [result] = await db.query(
      `UPDATE notifications SET ${updates.join(', ')} WHERE id = ?`,
      values
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: 'Notification not found' });
    }
    return res.json({ success: true, message: 'Notification updated' });
  } catch (err) {
    console.error('PATCH /notifications/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// DELETE /api/notifications/:id
router.delete('/:id', async (req, res) => {
  try {
    const [result] = await db.query(`DELETE FROM notifications WHERE id = ?`, [req.params.id]);
    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: 'Notification not found' });
    }
    return res.json({ success: true, message: 'Notification deleted' });
  } catch (err) {
    console.error('DELETE /notifications/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
module.exports.createNotification = createNotification;