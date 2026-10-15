
'use strict';

// routes/credential_history.js
//
// ADMIN CLIENT CREDENTIAL HISTORY
//
// Features:
// 1. Created History
// 2. Edited History
// 3. Employee Deleted (Hidden) History
// 4. Shows who performed each action
// 5. Preserves deletion history after Admin restoration
// 6. Never exposes credential passwords in history
// 7. Admin-only access

const express = require('express');
const router = express.Router();

const db = require('../config/db');
const { authenticateToken } = require('./auth');

// --------------------------------------------------
// AUTHENTICATION
// --------------------------------------------------

router.use(authenticateToken);

// --------------------------------------------------
// ADMIN AUTHORIZATION
// --------------------------------------------------

router.use((req, res, next) => {
  const userType = String(
    req.user?.userType || ''
  ).toLowerCase();

  if (userType !== 'admin') {
    return res.status(403).json({
      success: false,
      message: 'Admin access required'
    });
  }

  next();
});

// --------------------------------------------------
// HELPERS
// --------------------------------------------------

function validId(value) {
  const id = Number(value);

  return Number.isSafeInteger(id) && id > 0
    ? id
    : null;
}

// Parse JSON changes if the database driver returns
// a JSON string instead of an object.
//
// Password values are never returned in history.
function parseChanges(value) {
  if (value === null || value === undefined) {
    return {};
  }

  let changes = value;

  if (typeof changes === 'string') {
    try {
      changes = JSON.parse(changes);
    } catch (error) {
      console.error('Invalid history JSON:', error.message);
      return {};
    }
  }

  if (
    !changes ||
    typeof changes !== 'object' ||
    Array.isArray(changes)
  ) {
    return {};
  }

  const safeChanges = { ...changes };

  if (Object.prototype.hasOwnProperty.call(
    safeChanges,
    'password'
  )) {
    safeChanges.password = {
      changed: true
    };
  }

  return safeChanges;
}

// --------------------------------------------------
// GET CREDENTIAL HISTORY
//
// GET /api/credential-history/:credentialId
//
// Response:
// {
//   success: true,
//   data: {
//     creations: [],
//     edits: [],
//     deletions: []
//   }
// }
// --------------------------------------------------

router.get('/:credentialId', async (req, res) => {
  const credentialId = validId(
    req.params.credentialId
  );

  if (!credentialId) {
    return res.status(400).json({
      success: false,
      message: 'Invalid credential ID'
    });
  }

  try {
    // ----------------------------------------------
    // 1. CREATED HISTORY
    // ----------------------------------------------

    const [creationRows] = await db.query(
      `SELECT
          a.id,
          a.credential_id,
          a.client_id,
          a.action_type,
          a.changes_json,
          a.created_at,

          u.full_name AS actor_name,
          u.user_type AS actor_type

       FROM client_credential_audit_logs a

       LEFT JOIN employee_users u
         ON u.id = a.actor_user_id

       WHERE a.credential_id = ?
         AND a.action_type = 'CREATED'

       ORDER BY
         a.created_at ASC,
         a.id ASC`,
      [credentialId]
    );

    const creations = creationRows.map((row) => ({
      ...row,
      changes_json: parseChanges(row.changes_json)
    }));

    // ----------------------------------------------
    // 2. EDITED HISTORY
    // ----------------------------------------------

    const [editRows] = await db.query(
      `SELECT
          a.id,
          a.credential_id,
          a.client_id,
          a.action_type,
          a.changes_json,
          a.created_at,

          u.full_name AS actor_name,
          u.user_type AS actor_type

       FROM client_credential_audit_logs a

       LEFT JOIN employee_users u
         ON u.id = a.actor_user_id

       WHERE a.credential_id = ?
         AND a.action_type = 'EDIT'

       ORDER BY
         a.created_at DESC,
         a.id DESC`,
      [credentialId]
    );

    const edits = editRows.map((row) => ({
      ...row,
      changes_json: parseChanges(row.changes_json)
    }));

    // ----------------------------------------------
    // 3. EMPLOYEE DELETED HISTORY
    // ----------------------------------------------
    //
    // IMPORTANT:
    //
    // employee_hidden_credentials stores only
    // the CURRENT hidden status.
    //
    // When Admin updates a credential, the current
    // hidden records are removed so the credential
    // becomes visible to all employees again.
    //
    // Therefore, Deleted History must be read from:
    //
    // employee_credential_hide_history
    //
    // This table permanently stores each hide event.
    // ----------------------------------------------

    const [deletionRows] = await db.query(
      `SELECT
          h.id,
          h.credential_id,
          h.employee_id,
          h.reason,
          h.hidden_at,

          u.full_name AS actor_name,
          u.user_type AS actor_type

       FROM employee_credential_hide_history h

       LEFT JOIN employee_users u
         ON u.id = h.employee_id

       WHERE h.credential_id = ?

       ORDER BY
         h.hidden_at DESC,
         h.id DESC`,
      [credentialId]
    );

    const deletions = deletionRows.map((row) => ({
      ...row,
      action_type: 'DELETED'
    }));

    // ----------------------------------------------
    // RESPONSE
    // ----------------------------------------------

    return res.status(200).json({
      success: true,
      data: {
        creations,
        edits,
        deletions
      }
    });

  } catch (error) {
    console.error(
      'GET credential history:',
      error
    );

    return res.status(500).json({
      success: false,
      message: 'Unable to load credential history'
    });
  }
});

module.exports = router;
