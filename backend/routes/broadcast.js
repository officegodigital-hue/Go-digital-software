// routes/broadcast.js
const express = require('express');
const router = express.Router();
const db = require('../config/db');

router.get('/settings', async (req, res) => {
  try {
    const [rows] = await db.query('SELECT * FROM broadcast_settings ORDER BY id DESC LIMIT 1');
    if (rows.length === 0) {
      return res.json({ 
        isActive: true, 
        id: 0, // 🟢 Default ID
        newClientEnabled: true, 
        inactiveClientEnabled: true, 
        message: '', 
        severity: 'Warning', 
        targetEmployeeId: null 
      });
    }
    const setting = rows[0];
    return res.json({
      isActive: setting.is_active == 1,
      id: setting.id, // 🟢 Database ID-ai anuppuvathu mukkiyam
      newClientEnabled: setting.new_client_enabled == 1,
      inactiveClientEnabled: setting.inactive_client_enabled == 1,
      message: setting.message || '',
      severity: setting.severity || 'Warning',
      targetEmployeeId: setting.target_employee_id
    });
  } catch (err) {
    console.error('GET /broadcast/settings ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

router.post('/send', async (req, res) => {
  const { isActive, newClientEnabled, inactiveClientEnabled, message, severity, targetEmployeeId } = req.body;

  try {
    const [result] = await db.query(
      `INSERT INTO broadcast_settings (is_active, new_client_enabled, inactive_client_enabled, message, severity, target_employee_id) 
       VALUES (?, ?, ?, ?, ?, ?)`,
      [isActive ? 1 : 0, newClientEnabled ? 1 : 0, inactiveClientEnabled ? 1 : 0, message, severity, targetEmployeeId || null]
    );

    return res.json({ success: true, message: 'Settings saved successfully', broadcastId: result.insertId });
  } catch (err) {
    console.error('POST /broadcast/send ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;