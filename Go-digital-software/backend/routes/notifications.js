const express = require('express');
const router  = express.Router();
const db      = require('../config/db');

async function createNotification({ senderName, recipientName, message }) {
  await db.query(
    `INSERT INTO notifications (sender_name, recipient_name, message) VALUES (?, ?, ?)`,
    [senderName, recipientName, message]
  );
}

// function formatTime(dateVal) {
//   if (!dateVal) return '';
//   const created = new Date(dateVal);
//   const now = new Date();
//   const diffMins = Math.floor((now.getTime() - created.getTime()) / 60000);

//   if (diffMins < 1) return 'Just Now';
//   if (diffMins < 60) return `${diffMins} min ago`;

//   return created.toLocaleTimeString('en-IN', {
//     timeZone: 'Asia/Kolkata',
//     hour: 'numeric',
//     minute: '2-digit',
//     hour12: true,
//   });
// }

function formatTime(dateVal) {
  if (!dateVal) return '';
  const created = new Date(dateVal);
  const now = new Date();

  // Reset hours to compare calendar dates
  const createdDateOnly = new Date(created.getFullYear(), created.getMonth(), created.getDate());
  const nowDateOnly = new Date(now.getFullYear(), now.getMonth(), now.getDate());

  const diffDays = Math.floor((nowDateOnly.getTime() - createdDateOnly.getTime()) / (1000 * 60 * 60 * 24));

  if (diffDays === 0) {
    // Today: show time like WhatsApp (e.g., "10:30 am")
    return created.toLocaleTimeString('en-IN', {
      timeZone: 'Asia/Kolkata',
      hour: 'numeric',
      minute: '2-digit',
      hour12: true,
    });
  } else if (diffDays === 1) {
    return 'Yesterday';
  } else if (diffDays < 7) {
    // Within a week: show day name (e.g., "Monday")
    return created.toLocaleDateString('en-IN', { timeZone: 'Asia/Kolkata', weekday: 'long' });
  } else {
    // Older: show full date (e.g., "03/08/2026")
    const dd = created.getDate().toString().padStart(2, '0');
    const mm = (created.getMonth() + 1).toString().padStart(2, '0');
    const yy = created.getFullYear();
    return `${dd}/${mm}/${yy}`;
  }
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
    if (mode === 'everyone') {
      // Completely remove row from database for both users
      const [result] = await db.query(`DELETE FROM notifications WHERE id = ?`, [req.params.id]);
      if (result.affectedRows === 0) {
        return res.status(404).json({ success: false, message: 'Notification not found' });
      }
      return res.json({ success: true, message: 'Deleted for everyone' });
    } else {
     
      const [result] = await db.query(`DELETE FROM notifications WHERE id = ?`, [req.params.id]);
      return res.json({ success: true, message: 'Deleted for me' });
    }
  } catch (err) {
    console.error('DELETE /notifications/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/notifications/send
router.post('/send', async (req, res) => {
  const { senderName, recipientName, message } = req.body;

  if (!recipientName || !message) {
    return res.status(400).json({ success: false, message: 'Recipient name and message are required' });
  }

  try {
    await createNotification({
      senderName: senderName || 'Admin',
      recipientName: recipientName,
      message: message,
    });

    // Real-time socket broadcast (optional, unga project setup-ku etha maari)
    const io = req.app.get('io');
    if (io) {
      io.emit('task_updated', { type: 'NOTIFICATION_SENT', recipient: recipientName });
    }

    return res.status(201).json({ success: true, message: 'Notification sent successfully' });
  } catch (err) {
    console.error('POST /notifications/send ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});


module.exports = router;
module.exports.createNotification = createNotification;