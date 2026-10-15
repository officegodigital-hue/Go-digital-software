
'use strict';

// routes/employee_credential_visibility.js
//
// EMPLOYEE CLIENT CREDENTIAL VISIBILITY
//
// Features:
// 1. Load credentials for a selected client.
// 2. Hide credentials only for the logged-in employee.
// 3. Never delete original client credentials.
// 4. Save permanent employee deletion history.
// 5. Support automatic restoration after Admin updates.
// 6. Allow employees to hide a restored credential again.

const express = require('express');
const router = express.Router();

const db = require('../config/db');
const { authenticateToken } = require('./auth');

// Require a valid login.
router.use(authenticateToken);

// --------------------------------------------------
// HELPERS
// --------------------------------------------------

function validId(value) {
  const id = Number(value);

  return Number.isSafeInteger(id) && id > 0
    ? id
    : null;
}

function getEmployeeId(req) {
  return validId(req.user?.id);
}

// --------------------------------------------------
// GET EMPLOYEE VISIBLE CREDENTIALS
//
// GET /api/employee-credential-visibility?clientId=5
//
// Loads credentials for a selected client,
// excluding only those hidden by this employee.
// --------------------------------------------------

router.get('/', async (req, res) => {
  const clientId = validId(req.query.clientId);
  const employeeId = getEmployeeId(req);

  if (!employeeId) {
    return res.status(401).json({
      success: false,
      message: 'Invalid employee session'
    });
  }

  if (!clientId) {
    return res.status(400).json({
      success: false,
      message: 'Valid clientId required'
    });
  }

  try {
    // Load the original client credentials.
    // Exclude credentials currently hidden by
    // this particular employee.
    const [rows] = await db.query(
      `SELECT
          cc.id,
          cc.client_id,
          cc.username,
          cc.password,
          cc.platform,
          cc.contact_number,
          cc.email,
          cc.updated_at

       FROM client_credentials cc

       WHERE cc.client_id = ?

         AND NOT EXISTS (
           SELECT 1
           FROM employee_hidden_credentials h
           WHERE h.credential_id = cc.id
             AND h.employee_id = ?
         )

       ORDER BY cc.id ASC`,
      [
        clientId,
        employeeId
      ]
    );

    return res.status(200).json({
      success: true,
      data: rows
    });

  } catch (error) {
    console.error(
      'GET employee credential visibility:',
      error
    );

    return res.status(500).json({
      success: false,
      message: 'Unable to load credentials'
    });
  }
});

// --------------------------------------------------
// EMPLOYEE PERSONAL HIDE
//
// POST /api/employee-credential-visibility/:id/hide
//
// Request body:
// {
//   "reason": "No longer required"
// }
//
// Hides a credential only for the logged-in employee.
// Original credential remains in client_credentials.
// Every successful new hide is saved in history.
// --------------------------------------------------

router.post('/:id/hide', async (req, res) => {
  const credentialId = validId(req.params.id);
  const employeeId = getEmployeeId(req);

  const reason =
    typeof req.body?.reason === 'string'
      ? req.body.reason.trim()
      : '';

  if (!employeeId) {
    return res.status(401).json({
      success: false,
      message: 'Invalid employee session'
    });
  }

  if (!credentialId) {
    return res.status(400).json({
      success: false,
      message: 'Invalid credential ID'
    });
  }

  if (reason.length < 3 || reason.length > 1000) {
    return res.status(400).json({
      success: false,
      message: 'Enter a reason (3–1000 characters)'
    });
  }

  let connection;

  try {
    connection = await db.getConnection();

    await connection.beginTransaction();

    // Lock the original credential.
    // This coordinates employee hiding with Admin updates.
    const [credentialRows] = await connection.query(
      `SELECT id
       FROM client_credentials
       WHERE id = ?
       FOR UPDATE`,
      [credentialId]
    );

    if (credentialRows.length === 0) {
      await connection.rollback();

      return res.status(404).json({
        success: false,
        message: 'Credential not found'
      });
    }

    // Check whether the employee already hid it.
    const [hiddenRows] = await connection.query(
      `SELECT id
       FROM employee_hidden_credentials
       WHERE employee_id = ?
         AND credential_id = ?`,
      [
        employeeId,
        credentialId
      ]
    );

    if (hiddenRows.length > 0) {
      await connection.rollback();

      return res.status(200).json({
        success: true,
        message:
          'Credential is already hidden from your account'
      });
    }

    // ----------------------------------------------
    // 1. SAVE CURRENT HIDDEN STATUS
    // ----------------------------------------------

    await connection.query(
      `INSERT INTO employee_hidden_credentials
       (
         employee_id,
         credential_id,
         reason
       )
       VALUES (?, ?, ?)`,
      [
        employeeId,
        credentialId,
        reason
      ]
    );

    // ----------------------------------------------
    // 2. SAVE PERMANENT DELETION HISTORY
    // ----------------------------------------------

    await connection.query(
      `INSERT INTO employee_credential_hide_history
       (
         employee_id,
         credential_id,
         reason
       )
       VALUES (?, ?, ?)`,
      [
        employeeId,
        credentialId,
        reason
      ]
    );

    // Save both operations together.
    await connection.commit();

    console.log(
      `[Employee Credential Hide] ` +
      `Employee ${employeeId} hid credential ${credentialId}`
    );

    return res.status(200).json({
      success: true,
      message: 'Credential hidden from your account only'
    });

  } catch (error) {
    if (connection) {
      try {
        await connection.rollback();
      } catch (rollbackError) {
        console.error(
          'Employee hide rollback failed:',
          rollbackError
        );
      }
    }

    console.error(
      'POST employee credential hide:',
      error
    );

    if (error.code === 'ER_DUP_ENTRY') {
      return res.status(200).json({
        success: true,
        message:
          'Credential is already hidden from your account'
      });
    }

    return res.status(500).json({
      success: false,
      message: 'Unable to hide credential'
    });

  } finally {
    if (connection) {
      connection.release();
    }
  }
});

module.exports = router;
