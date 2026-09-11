// routes/credentials.js — Client Credentials CRUD API (v3: unique client_id + platform)
const express = require('express');
const router  = express.Router();
const db      = require('../config/db');

// GET /api/credentials?clientId=5 — list credentials, optionally filtered by client
router.get('/', async (req, res) => {
  try {
    const { clientId } = req.query;
    let rows;
    if (clientId) {
      [rows] = await db.query(
        `SELECT id, client_id, username, password, platform, contact_number, email, updated_at
         FROM client_credentials WHERE client_id = ? ORDER BY id ASC`,
        [clientId]
      );
    } else {
      [rows] = await db.query(
        `SELECT id, client_id, username, password, platform, contact_number, email, updated_at
         FROM client_credentials ORDER BY id ASC`
      );
    }
    return res.json({ success: true, data: rows });
  } catch (err) {
    console.error('GET /credentials ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/credentials/:id
router.get('/:id', async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT id, client_id, username, password, platform, contact_number, email, updated_at
       FROM client_credentials WHERE id = ?`,
      [req.params.id]
    );
    if (rows.length === 0)
      return res.status(404).json({ success: false, message: 'Credential not found' });
    return res.json({ success: true, data: rows[0] });
  } catch (err) {
    console.error('GET /credentials/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/credentials — create new credential, linked to a client
// Body: { clientId, username, password, platform, contactNumber, email }
// NOTE: (clientId, platform) must be unique — see migration SQL
router.post('/', async (req, res) => {
  const { clientId, username, password, platform, contactNumber, email } = req.body;

  if (!clientId || !username || !password || !platform)
    return res.status(400).json({ success: false, message: 'clientId, username, password and platform are required' });

  try {
    const [result] = await db.query(
      `INSERT INTO client_credentials (client_id, username, password, platform, contact_number, email)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [clientId, username, password, platform, contactNumber || '', email || '']
    );
    return res.status(201).json({
      success: true,
      message: 'Credential added',
      data: {
        id: result.insertId, client_id: clientId, username, password, platform,
        contact_number: contactNumber || '', email: email || '',
      },
    });
  } catch (err) {
    console.error('POST /credentials ERROR:', err.message);
    if (err.code === 'ER_DUP_ENTRY')
      return res.status(409).json({ success: false, message: `"${platform}" has already been added for this client` });
    return res.status(500).json({ success: false, message: err.message });
  }
});

// PUT /api/credentials/:id — update existing credential
// Body: { username, password, platform, contactNumber, email }
router.put('/:id', async (req, res) => {
  const { username, password, platform, contactNumber, email } = req.body;

  if (!username || !password || !platform)
    return res.status(400).json({ success: false, message: 'username, password and platform are required' });

  try {
    const [result] = await db.query(
      `UPDATE client_credentials
       SET username = ?, password = ?, platform = ?, contact_number = ?, email = ?
       WHERE id = ?`,
      [username, password, platform, contactNumber || '', email || '', req.params.id]
    );
    if (result.affectedRows === 0)
      return res.status(404).json({ success: false, message: 'Credential not found' });
    return res.json({ success: true, message: 'Credential updated' });
  } catch (err) {
    console.error('PUT /credentials/:id ERROR:', err.message);
    if (err.code === 'ER_DUP_ENTRY')
      return res.status(409).json({ success: false, message: `"${platform}" has already been added for this client` });
    return res.status(500).json({ success: false, message: err.message });
  }
});

// DELETE /api/credentials/:id
router.delete('/:id', async (req, res) => {
  try {
    const [result] = await db.query(`DELETE FROM client_credentials WHERE id = ?`, [req.params.id]);
    if (result.affectedRows === 0)
      return res.status(404).json({ success: false, message: 'Credential not found' });
    return res.json({ success: true, message: 'Credential deleted' });
  } catch (err) {
    console.error('DELETE /credentials/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;