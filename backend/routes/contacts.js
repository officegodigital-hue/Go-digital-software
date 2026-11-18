// routes/contacts.js
// Phone-number lookup by display name, used by the chat "call" button.
const express = require('express');
const router = express.Router();
const db = require('../config/db');
const { authenticateToken } = require('./auth');

router.get('/phone', authenticateToken, async (req, res) => {
  try {
    const name = String(req.query.name || '').trim();
    if (!name) return res.json({ success: true, phone: null });

    // Employees first (they have mobile + phone_number), then admins in users.
    const [emp] = await db.query(
      "SELECT COALESCE(NULLIF(mobile, ''), NULLIF(phone_number, '')) AS phone FROM employee_users WHERE full_name = ? LIMIT 1",
      [name],
    );
    let phone = emp[0]?.phone || null;
    if (!phone) {
      const [adm] = await db.query('SELECT mobile AS phone FROM users WHERE name = ? LIMIT 1', [name]);
      phone = adm[0]?.phone || null;
    }
    return res.json({ success: true, phone: phone || null });
  } catch (error) {
    console.error('contact phone lookup error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to look up the phone number.' });
  }
});

module.exports = router;
