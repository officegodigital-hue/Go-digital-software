const express = require('express');
const router = express.Router();

const db = require('../config/db');
const { authenticateToken } = require('./auth');
const { getInvoiceAccess } = require('../lib/invoiceAccess');

// All endpoints require an authenticated employee.
router.use(authenticateToken);

async function requireMainAdmin(req, res, next) {
  try {
    const access = await getInvoiceAccess(req.user.id);

    if (!access.isMainAdmin) {
      return res.status(403).json({
        success: false,
        message: 'Only Main Admin can reassign invoices.',
      });
    }

    next();
  } catch (error) {
    console.error('Invoice Main Admin check:', error);
    res.status(500).json({
      success: false,
      message: 'Unable to verify Main Admin permission.',
    });
  }
}

// GET /api/invoices/eligible-assignees
router.get('/eligible-assignees', requireMainAdmin, async (req, res) => {
  try {
    const [employees] = await db.query(
      `SELECT id, full_name, role
       FROM employee_users
       WHERE is_active = 1
       ORDER BY full_name ASC, id ASC`
    );

    const eligible = [];

    for (const employee of employees) {
      const access = await getInvoiceAccess(employee.id);

      if (access.allowed) {
        eligible.push({
          id: employee.id,
          full_name: employee.full_name,
          role: employee.role,
        });
      }
    }

    return res.json({
      success: true,
      users: eligible,
    });
  } catch (error) {
    console.error('GET eligible-assignees:', error);
    return res.status(500).json({
      success: false,
      message: 'Unable to load eligible users.',
    });
  }
});

// PATCH /api/invoices/:id/assign
router.patch('/:id/assign', requireMainAdmin, async (req, res) => {
  const invoiceId = Number(req.params.id);
  const assignedTo = Number(req.body.assigned_to);

  if (
    !Number.isSafeInteger(invoiceId) ||
    invoiceId <= 0 ||
    !Number.isSafeInteger(assignedTo) ||
    assignedTo <= 0
  ) {
    return res.status(400).json({
      success: false,
      message: 'Valid invoice ID and assigned_to are required.',
    });
  }

  let connection;

  try {
    // Verify eligibility before opening the transaction.
    const access = await getInvoiceAccess(assignedTo);

    if (!access.allowed) {
      return res.status(400).json({
        success: false,
        message: 'Selected employee does not have Invoice access.',
      });
    }

    connection = await db.getConnection();
    await connection.beginTransaction();

    const [invoices] = await connection.query(
      `SELECT id, assigned_to
       FROM invoices
       WHERE id = ?
       FOR UPDATE`,
      [invoiceId]
    );

    if (invoices.length === 0) {
      await connection.rollback();

      return res.status(404).json({
        success: false,
        message: 'Invoice not found.',
      });
    }

    const previousAssignedTo = invoices[0].assigned_to;

    if (Number(previousAssignedTo) === assignedTo) {
      await connection.rollback();

      return res.json({
        success: true,
        message: 'Invoice is already assigned to this employee.',
        assigned_to: assignedTo,
      });
    }

    await connection.query(
      `UPDATE invoices
       SET assigned_to = ?
       WHERE id = ?`,
      [assignedTo, invoiceId]
    );

    await connection.query(
      `INSERT INTO invoice_assignment_history
       (invoice_id, previous_assigned_to, new_assigned_to, changed_by)
       VALUES (?, ?, ?, ?)`,
      [
        invoiceId,
        previousAssignedTo,
        assignedTo,
        req.user.id,
      ]
    );

    await connection.commit();

    return res.json({
      success: true,
      message: 'Invoice reassigned successfully.',
      invoice_id: invoiceId,
      assigned_to: assignedTo,
    });
  } catch (error) {
    if (connection) {
      try {
        await connection.rollback();
      } catch (_) {}
    }

    console.error('PATCH invoice assignment:', error);

    return res.status(500).json({
      success: false,
      message: 'Unable to reassign invoice.',
    });
  } finally {
    if (connection) {
      connection.release();
    }
  }
});

module.exports = router;
