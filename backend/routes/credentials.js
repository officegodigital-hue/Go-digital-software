
'use strict';

// routes/credentials.js
// Shared Admin / Employee credential CRUD.
//
// Features:
// - Create credentials and record Created History
// - Update credentials and record Edited History
// - Record which user made each change
// - Never expose password values in audit history
// - Automatically restore a credential for ALL employees
//   who previously hid it when Admin makes a real update
// - Allow permanent deletion by Admin only
//
// IMPORTANT:
// Employee deletion history must be preserved separately in
// employee_credential_hide_history before restoration.

const express = require('express');
const router = express.Router();
const db = require('../config/db');
const { authenticateToken } = require('./auth');

// All credential endpoints require authentication.
router.use(authenticateToken);

// --------------------------------------------------
// HELPERS
// --------------------------------------------------

function isAdmin(user) {
  return String(user?.userType || '').toLowerCase() === 'admin';
}

function requireAdmin(req, res, next) {
  if (!isAdmin(req.user)) {
    return res.status(403).json({
      success: false,
      message: 'Only Admin can permanently delete credentials'
    });
  }

  next();
}

function validId(value) {
  const id = Number(value);

  return Number.isSafeInteger(id) && id > 0
    ? id
    : null;
}

function requiredString(value) {
  return typeof value === 'string'
    ? value.trim()
    : '';
}

const SELECT_FIELDS = `
  id,
  client_id,
  username,
  password,
  platform,
  contact_number,
  email,
  updated_at
`;

// --------------------------------------------------
// GET ALL CREDENTIALS
// GET /api/credentials?clientId=5
// --------------------------------------------------

router.get('/', async (req, res) => {
  const clientId = req.query.clientId
    ? validId(req.query.clientId)
    : null;

  if (req.query.clientId && !clientId) {
    return res.status(400).json({
      success: false,
      message: 'Invalid client ID'
    });
  }

  try {
    let rows;

    if (clientId) {
      [rows] = await db.query(
        `SELECT ${SELECT_FIELDS}
         FROM client_credentials
         WHERE client_id = ?
         ORDER BY id ASC`,
        [clientId]
      );
    } else {
      [rows] = await db.query(
        `SELECT ${SELECT_FIELDS}
         FROM client_credentials
         ORDER BY id ASC`
      );
    }

    return res.json({
      success: true,
      data: rows
    });
  } catch (error) {
    console.error('GET credentials:', error);

    return res.status(500).json({
      success: false,
      message: 'Unable to load credentials'
    });
  }
});

// --------------------------------------------------
// GET SINGLE CREDENTIAL
// GET /api/credentials/:id
// --------------------------------------------------

router.get('/:id', async (req, res) => {
  const id = validId(req.params.id);

  if (!id) {
    return res.status(400).json({
      success: false,
      message: 'Invalid credential ID'
    });
  }

  try {
    const [rows] = await db.query(
      `SELECT ${SELECT_FIELDS}
       FROM client_credentials
       WHERE id = ?`,
      [id]
    );

    if (!rows.length) {
      return res.status(404).json({
        success: false,
        message: 'Credential not found'
      });
    }

    return res.json({
      success: true,
      data: rows[0]
    });
  } catch (error) {
    console.error('GET credential:', error);

    return res.status(500).json({
      success: false,
      message: 'Unable to load credential'
    });
  }
});

// --------------------------------------------------
// CREATE CREDENTIAL
// POST /api/credentials
// --------------------------------------------------

router.post('/', async (req, res) => {
  const clientId = validId(req.body.clientId);
  const username = requiredString(req.body.username);
  const password = req.body.password;
  const platform = requiredString(req.body.platform);
  const contactNumber = requiredString(req.body.contactNumber);
  const email = requiredString(req.body.email);

  if (
    !clientId ||
    !username ||
    typeof password !== 'string' ||
    !password ||
    !platform
  ) {
    return res.status(400).json({
      success: false,
      message:
        'clientId, username, password and platform are required'
    });
  }

  let connection;

  try {
    connection = await db.getConnection();

    await connection.beginTransaction();

    // Insert credential.
    const [result] = await connection.query(
      `INSERT INTO client_credentials
       (
         client_id,
         username,
         password,
         platform,
         contact_number,
         email
       )
       VALUES (?, ?, ?, ?, ?, ?)`,
      [
        clientId,
        username,
        password,
        platform,
        contactNumber,
        email
      ]
    );

    const credentialId = result.insertId;

    // Save Created History.
    // Never include password values in history.
    await connection.query(
      `INSERT INTO client_credential_audit_logs
       (
         client_id,
         credential_id,
         actor_user_id,
         action_type,
         changes_json
       )
       VALUES (?, ?, ?, 'CREATED', ?)`,
      [
        clientId,
        credentialId,
        req.user.id,
        JSON.stringify({
          platform
        })
      ]
    );

    await connection.commit();

    return res.status(201).json({
      success: true,
      message: 'Credential added and creation history recorded',
      data: {
        id: credentialId,
        client_id: clientId,
        username,
        password,
        platform,
        contact_number: contactNumber,
        email
      }
    });
  } catch (error) {
    if (connection) {
      try {
        await connection.rollback();
      } catch (rollbackError) {
        console.error('Create rollback failed:', rollbackError);
      }
    }

    console.error('POST credential:', error);

    if (error.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({
        success: false,
        message:
          `"${platform}" has already been added for this client`
      });
    }

    return res.status(500).json({
      success: false,
      message: 'Unable to add credential'
    });
  } finally {
    if (connection) {
      connection.release();
    }
  }
});

// --------------------------------------------------
// UPDATE CREDENTIAL
// PUT /api/credentials/:id
//
// Admin update:
// - Save actual changes
// - Record Edited History
// - Restore credential for ALL employees who hid it
//
// Employee update:
// - Save actual changes
// - Record Edited History
// - Do not restore other employees' hidden credentials
// --------------------------------------------------

router.put('/:id', async (req, res) => {
  const id = validId(req.params.id);

  const username = requiredString(req.body.username);
  const password = req.body.password;
  const platform = requiredString(req.body.platform);
  const contactNumber = requiredString(req.body.contactNumber);
  const email = requiredString(req.body.email);

  if (!id) {
    return res.status(400).json({
      success: false,
      message: 'Invalid credential ID'
    });
  }

  if (
    !username ||
    typeof password !== 'string' ||
    !password ||
    !platform
  ) {
    return res.status(400).json({
      success: false,
      message: 'username, password and platform are required'
    });
  }

  let connection;

  try {
    connection = await db.getConnection();

    await connection.beginTransaction();

    // Lock the credential during update.
    const [rows] = await connection.query(
      `SELECT ${SELECT_FIELDS}
       FROM client_credentials
       WHERE id = ?
       FOR UPDATE`,
      [id]
    );

    if (!rows.length) {
      await connection.rollback();

      return res.status(404).json({
        success: false,
        message: 'Credential not found'
      });
    }

    const previous = rows[0];

    // ------------------------------------------
    // DETECT ACTUAL CHANGES
    // ------------------------------------------

    const changes = {};

    function recordChange(field, oldValue, newValue) {
      const before = String(oldValue ?? '');
      const after = String(newValue ?? '');

      if (before !== after) {
        changes[field] = {
          old: before,
          new: after
        };
      }
    }

    recordChange(
      'username',
      previous.username,
      username
    );

    recordChange(
      'platform',
      previous.platform,
      platform
    );

    recordChange(
      'contact_number',
      previous.contact_number,
      contactNumber
    );

    recordChange(
      'email',
      previous.email,
      email
    );

    // Password change is recorded without revealing
    // either the previous or new password.
    if (String(previous.password) !== String(password)) {
      changes.password = {
        changed: true
      };
    }

    // ------------------------------------------
    // NO CHANGES
    // ------------------------------------------

    if (Object.keys(changes).length === 0) {
      await connection.commit();

      return res.json({
        success: true,
        message: 'No changes detected',
        restoredEmployees: 0
      });
    }

    // ------------------------------------------
    // UPDATE CREDENTIAL
    // ------------------------------------------

    await connection.query(
      `UPDATE client_credentials
       SET
         username = ?,
         password = ?,
         platform = ?,
         contact_number = ?,
         email = ?
       WHERE id = ?`,
      [
        username,
        password,
        platform,
        contactNumber,
        email,
        id
      ]
    );

    // ------------------------------------------
    // RECORD EDITED HISTORY
    // ------------------------------------------

    await connection.query(
      `INSERT INTO client_credential_audit_logs
       (
         client_id,
         credential_id,
         actor_user_id,
         action_type,
         changes_json
       )
       VALUES (?, ?, ?, 'EDIT', ?)`,
      [
        previous.client_id,
        id,
        req.user.id,
        JSON.stringify(changes)
      ]
    );

    // ------------------------------------------
    // NEW FEATURE:
    // RESTORE FOR ALL EMPLOYEES AFTER ADMIN EDIT
    // ------------------------------------------

    let restoredEmployees = 0;

    if (isAdmin(req.user)) {
      // employee_hidden_credentials represents only
      // the CURRENT hidden status.
      //
      // Historical deletion records must already be
      // preserved in employee_credential_hide_history.

      const [restoreResult] = await connection.query(
        `DELETE FROM employee_hidden_credentials
         WHERE credential_id = ?`,
        [id]
      );

      restoredEmployees = restoreResult.affectedRows;

      console.log(
        `[Credential Restore] Admin ${req.user.id} updated ` +
        `credential ${id}. Restored for ` +
        `${restoredEmployees} employee(s).`
      );
    }

    // All changes succeed or fail together.
    await connection.commit();

    return res.json({
      success: true,
      message: isAdmin(req.user)
        ? 'Credential updated and restored for employees'
        : 'Credential updated and edit history recorded',
      restoredEmployees
    });
  } catch (error) {
    if (connection) {
      try {
        await connection.rollback();
      } catch (rollbackError) {
        console.error('Update rollback failed:', rollbackError);
      }
    }

    console.error('PUT credential:', error);

    if (error.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({
        success: false,
        message:
          `"${platform}" has already been added for this client`
      });
    }

    return res.status(500).json({
      success: false,
      message: 'Unable to update credential'
    });
  } finally {
    if (connection) {
      connection.release();
    }
  }
});

// --------------------------------------------------
// DELETE CREDENTIAL PERMANENTLY
// DELETE /api/credentials/:id
//
// ADMIN ONLY
//
// Employee personal deletion must use:
// POST /api/employee-credential-visibility/:id/hide
// --------------------------------------------------

router.delete(
  '/:id',
  requireAdmin,
  async (req, res) => {
    const id = validId(req.params.id);

    if (!id) {
      return res.status(400).json({
        success: false,
        message: 'Invalid credential ID'
      });
    }

    try {
      const [result] = await db.query(
        `DELETE FROM client_credentials
         WHERE id = ?`,
        [id]
      );

      if (result.affectedRows === 0) {
        return res.status(404).json({
          success: false,
          message: 'Credential not found'
        });
      }

      return res.json({
        success: true,
        message: 'Credential deleted permanently by Admin'
      });
    } catch (error) {
      console.error('DELETE credential:', error);

      return res.status(500).json({
        success: false,
        message: 'Unable to delete credential'
      });
    }
  }
);

module.exports = router;
