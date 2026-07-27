const express = require('express');
const router  = express.Router();
const db      = require('../config/db');

async function createNotification({ senderName, recipientName, message }) {
  await db.query(
    `INSERT INTO notifications (sender_name, recipient_name, message) VALUES (?, ?, ?)`,
    [senderName, recipientName, message]
  );
}

function formatTime(dateVal) {
  if (!dateVal) return '';
  const created = new Date(dateVal);
  const now = new Date();
  const diffMins = Math.floor((now.getTime() - created.getTime()) / 60000);

  if (diffMins < 1) return 'Just Now';
  if (diffMins < 60) return `${diffMins} min ago`;

  return created.toLocaleTimeString('en-IN', {
    timeZone: 'Asia/Kolkata',
    hour: 'numeric',
    minute: '2-digit',
    hour12: true,
  });
}

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
        senderName: r.sender_name,
        recipientName: r.recipient_name,
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
    if (isSeen !== undefined)      { updates.push('is_seen = ?');      values.push(isSeen ? 1 : 0); }
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

router.delete('/:id', async (req, res) => {
  const { mode } = req.query; // 'everyone' or 'me'
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