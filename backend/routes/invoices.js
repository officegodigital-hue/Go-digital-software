// routes/invoices.js — Invoices CRUD API (with line items)
const express = require('express');
const router  = express.Router();
const db      = require('../config/db');
 
// GET /api/invoices/next-number — generates the next INV-YYYY-#### number
// router.get('/next-number', async (req, res) => {
//   try {
//     const [rows] = await db.query(`SELECT COUNT(*) AS cnt FROM invoices`);
//     const nextSeq = rows[0].cnt + 842; // mirrors existing INV-2023-0842 style numbering
//     const year = new Date().getFullYear();
//     const invoiceNo = `INV-${year}-${String(nextSeq).padStart(4, '0')}`;
//     return res.json({ success: true, data: { invoiceNo } });
//   } catch (err) {
//     console.error('GET /invoices/next-number ERROR:', err.message);
//     return res.status(500).json({ success: false, message: err.message });
//   }
// });

router.get('/next-number', async (req, res) => {
  try {

    const now = new Date();

    const yyyy = now.getFullYear();
    const mm = String(now.getMonth() + 1).padStart(2, '0');
    const dd = String(now.getDate()).padStart(2, '0');

    const datePart = `${yyyy}${mm}${dd}`;

    const [rows] = await db.query(
      `SELECT invoice_no
       FROM invoices
       WHERE invoice_no LIKE ?
       ORDER BY id DESC
       LIMIT 1`,
      [`INV-${datePart}%`]
    );

    let nextSequence = 301;

    if (rows.length > 0) {
      const lastInvoiceNo = rows[0].invoice_no;

      // INV-20260708301
      const lastSequence = parseInt(lastInvoiceNo.substring(12));

      if (!isNaN(lastSequence)) {
        nextSequence = lastSequence + 1;
      }
    }

    const invoiceNo = `INV-${datePart}${nextSequence}`;

    return res.json({
      success: true,
      data: {
        invoiceNo,
      },
    });

  } catch (err) {
    console.error('GET /invoices/next-number ERROR:', err.message);

    return res.status(500).json({
      success: false,
      message: err.message,
    });
  }
});

// GET /api/invoices/metrics — totals for the summary cards
router.get('/metrics', async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT
         COALESCE(SUM(total_amount), 0) AS total_invoiced,
         COALESCE(SUM(paid_amount), 0)  AS collected_amount,
         COALESCE(SUM(balance_amount), 0) AS outstanding_balance
       FROM invoices`
    );
    return res.json({ success: true, data: rows[0] });
  } catch (err) {
    console.error('GET /invoices/metrics ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/invoices — list all invoices (without items, for table view)
router.get('/', async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT i.id, i.invoice_no, i.client_name, i.invoice_date, i.maintenance_date, i.include_gst,
              i.discount, i.subtotal, i.tax, i.total_amount, i.paid_amount, i.balance_amount,
              i.status, i.created_at, i.linked_quotation_id, i.linked_quotation_no,
              (SELECT ii.description FROM invoice_items ii
                WHERE ii.invoice_id = i.id ORDER BY ii.sort_order ASC, ii.id ASC LIMIT 1) AS package_type
       FROM invoices i INNER JOIN clients c
        ON TRIM(LOWER(i.client_name)) = TRIM(LOWER(c.company_name))
      WHERE c.is_active = 1
      ORDER BY i.id DESC`
    );
    return res.json({ success: true, data: rows });
  } catch (err) {
    console.error('GET /invoices ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/invoices/:id — single invoice with its items
router.get('/:id', async (req, res) => {
  try {
    const [iRows] = await db.query(`SELECT * FROM invoices WHERE id = ?`, [req.params.id]);
    if (iRows.length === 0)
      return res.status(404).json({ success: false, message: 'Invoice not found' });

    const [items] = await db.query(
      `SELECT 
 id,
 package_id,
 description,
 qty,
 rate,
 tax_percent,
 discount_amount,
 amount,
 paid_amount,
 pending_amount,
 sort_order
FROM invoice_items
WHERE invoice_id = ?
ORDER BY sort_order ASC, id ASC`,
      [req.params.id]
    );
    const [payments] = await db.query(
  `
  SELECT 
    id,
    invoice_id,
    paid_date,
    total_amount,
    paid_total_amount,
    paid_amount,
    balanced_amount,
    created_at
  FROM invoice_payments
  WHERE invoice_id = ?
  ORDER BY id DESC
  `,
  [req.params.id]
);

    return res.json({ success: true, data: { ...iRows[0], items, payments } });
  } catch (err) {
    console.error('GET /invoices/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/invoices — create invoice + line items
// Body: {
//   invoiceNo, clientName, invoiceDate, maintenanceDate, includeGST, discount, notes,
//   subtotal, tax, totalAmount, paidAmount, balanceAmount,
//   items: [{ packageId, description, qty, rate, amount, paidAmount, pendingAmount }]
// }
router.post('/', async (req, res) => {
  const {
    invoiceNo,
    clientName,
    invoiceDate,
    maintenanceDate,
    includeGST,
    discount,
    notes,
    subtotal,
    tax,
    totalAmount,
    paidAmount,
    balanceAmount,
    items,
  } = req.body;

  if (!invoiceNo || !clientName || !Array.isArray(items) || items.length === 0) {
    return res.status(400).json({
      success: false,
      message: 'invoiceNo, clientName and at least one item are required',
    });
  }

  // Auto Status
  const total = Number(totalAmount || 0);
  const paid = Number(paidAmount || 0);

  let status = 'DRAFT';
  if (paid <= 0) status = 'DRAFT';
  else if (paid >= total) status = 'PAID';
  else status = 'PARTIAL';

  const connection = await db.getConnection();

  try {
    await connection.beginTransaction();

    // ===========================
    // INSERT INVOICE
    // ===========================
    const [result] = await connection.query(
      `INSERT INTO invoices
      (
        invoice_no,
        client_name,
        invoice_date,
        maintenance_date,
        include_gst,
        discount,
        subtotal,
        tax,
        total_amount,
        paid_amount,
        balance_amount,
        status,
        notes
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        invoiceNo,
        clientName,
        invoiceDate || '',
        maintenanceDate || '',
        includeGST ? 1 : 0,
        discount || 0,
        subtotal || 0,
        tax || 0,
        total,
        paid,
        balanceAmount || 0,
        status,
        notes || '',
      ]
    );

    const invoiceId = result.insertId;

    // ===========================
    // INSERT ITEMS
    // ===========================
    for (let i = 0; i < items.length; i++) {
      const it = items[i];

      await connection.query(
        `INSERT INTO invoice_items
        (
            invoice_id,
            package_id,
            description,
            qty,
            rate,
            tax_percent,
            discount_amount,
            amount,
            paid_amount,
            pending_amount,
            sort_order
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
  invoiceId,
  it.packageId || null,
  it.description || '',
  it.qty || 1,
  it.rate || 0,
  it.tax || 0,
  it.discount || 0,
  it.amount || 0,
  it.paidAmount || 0,
  it.pendingAmount || 0,
  i,
]
      );
    }

    // ===========================
    // INSERT PAYMENT HISTORY
    // ===========================
    await connection.query(
      `INSERT INTO invoice_payments
      (
          invoice_id,
          paid_date,
          total_amount,
          paid_total_amount,
          paid_amount,
          balanced_amount
      )
      VALUES (?, ?, ?, ?, ?, ?)`,
      [
        invoiceId,
        invoiceDate || new Date(),
        total,
        paid,
        paid,
        balanceAmount || 0,
      ]
    );

    await connection.commit();

    return res.status(201).json({
      success: true,
      message: 'Invoice created successfully',
      data: {
        id: invoiceId,
        invoiceNo,
        status,
      },
    });

  } catch (err) {
    await connection.rollback();

    console.error('POST /invoices ERROR:', err.message);

    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({
        success: false,
        message: `Invoice "${invoiceNo}" already exists`,
      });
    }

    return res.status(500).json({
      success: false,
      message: err.message,
    });

  } finally {
    connection.release();
  }
});

// PUT /api/invoices/:id — update invoice + replace its line items
// PUT /api/invoices/:id
router.put('/:id', async (req, res) => {
  const {
    clientName,
    invoiceDate,
    maintenanceDate,
    includeGST,
    discount,
    notes,
    subtotal,
    tax,
    totalAmount,
    paidAmount,
    balanceAmount,
    items,
    status,
  } = req.body;

  if (!clientName || !Array.isArray(items) || items.length === 0) {
    return res.status(400).json({
      success: false,
      message: 'clientName and at least one item are required',
    });
  }

  const total = Number(totalAmount || 0);
  const paid = Number(paidAmount || 0);

  let derivedStatus = status;
  if (!derivedStatus) {
    if (paid <= 0) derivedStatus = 'DRAFT';
    else if (paid >= total) derivedStatus = 'PAID';
    else derivedStatus = 'PARTIAL';
  }

  const connection = await db.getConnection();

  try {
    await connection.beginTransaction();

    // Get previous paid amount
    const [[oldInvoice]] = await connection.query(
      `SELECT paid_amount FROM invoices WHERE id = ?`,
      [req.params.id]
    );

    if (!oldInvoice) {
      await connection.rollback();
      return res.status(404).json({
        success: false,
        message: 'Invoice not found',
      });
    }

    const oldPaid = Number(oldInvoice.paid_amount || 0);
    const newPayment = paid - oldPaid;

    // Update invoice
    const [result] = await connection.query(
      `UPDATE invoices
       SET
         client_name = ?,
         invoice_date = ?,
         maintenance_date = ?,
         include_gst = ?,
         discount = ?,
         subtotal = ?,
         tax = ?,
         total_amount = ?,
         paid_amount = ?,
         balance_amount = ?,
         status = ?,
         notes = ?
       WHERE id = ?`,
      [
        clientName,
        invoiceDate || '',
        maintenanceDate || '',
        includeGST ? 1 : 0,
        discount || 0,
        subtotal || 0,
        tax || 0,
        total,
        paid,
        balanceAmount || 0,
        derivedStatus,
        notes || '',
        req.params.id,
      ]
    );

    if (result.affectedRows === 0) {
      await connection.rollback();
      return res.status(404).json({
        success: false,
        message: 'Invoice not found',
      });
    }

    // Delete old items
    await connection.query(
      `DELETE FROM invoice_items WHERE invoice_id = ?`,
      [req.params.id]
    );

    // Insert updated items
    for (let i = 0; i < items.length; i++) {
      const it = items[i];

      await connection.query(
        `INSERT INTO invoice_items
        (
          invoice_id,
          package_id,
          description,
          qty,
          rate,
          tax_percent,
          discount_amount,
          amount,
          paid_amount,
          pending_amount,
          sort_order
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
  req.params.id,
  it.packageId || null,
  it.description || '',
  it.qty || 1,
  it.rate || 0,
  it.tax || 0,
  it.discount || 0,
  it.amount || 0,
  it.paidAmount || 0,
  it.pendingAmount || 0,
  i,
]
      );
    }

    // Insert payment history only if new payment received
    if (newPayment > 0) {
      await connection.query(
        `INSERT INTO invoice_payments
        (
          invoice_id,
          paid_date,
          total_amount,
          paid_total_amount,
          paid_amount,
          balanced_amount
        )
        VALUES (?, ?, ?, ?, ?, ?)`,
        [
          req.params.id,
          invoiceDate || new Date(),
          total,
          paid,
          newPayment,
          balanceAmount || 0,
        ]
      );
    }

    await connection.commit();

    return res.json({
      success: true,
      message: 'Invoice updated successfully',
      data: {
        status: derivedStatus,
      },
    });

  } catch (err) {
    await connection.rollback();
    console.error('PUT /invoices/:id ERROR:', err.message);

    return res.status(500).json({
      success: false,
      message: err.message,
    });

  } finally {
    connection.release();
  }
});

// PATCH /api/invoices/:id/status — update only the status (DRAFT/PARTIAL/PAID/OVERDUE)
router.patch('/:id/status', async (req, res) => {
  const { status } = req.body;
  const allowed = ['DRAFT', 'PARTIAL', 'PAID', 'OVERDUE'];

  if (!status || !allowed.includes(status.toUpperCase()))
    return res.status(400).json({ success: false, message: `status must be one of ${allowed.join(', ')}` });

  try {
    const [result] = await db.query(
      `UPDATE invoices SET status = ? WHERE id = ?`,
      [status.toUpperCase(), req.params.id]
    );
    if (result.affectedRows === 0)
      return res.status(404).json({ success: false, message: 'Invoice not found' });
    return res.json({ success: true, message: 'Status updated' });
  } catch (err) {
    console.error('PATCH /invoices/:id/status ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// DELETE /api/invoices/:id — delete invoice (cascades to items)
// DELETE /api/invoices/:id — delete invoice and cascade to items & payments
router.delete('/:id', async (req, res) => {
  const invoiceId = req.params.id;
  const connection = await db.getConnection();

  try {
    await connection.beginTransaction();

    // 1. Delete associated invoice items first
    await connection.query(
      `DELETE FROM invoice_items WHERE invoice_id = ?`,
      [invoiceId]
    );

    // 2. Delete associated invoice payment history records
    await connection.query(
      `DELETE FROM invoice_payments WHERE invoice_id = ?`,
      [invoiceId]
    );

    // 3. Delete the parent invoice record
    const [result] = await connection.query(
      `DELETE FROM invoices WHERE id = ?`,
      [invoiceId]
    );

    if (result.affectedRows === 0) {
      await connection.rollback();
      return res.status(404).json({ success: false, message: 'Invoice not found' });
    }

    await connection.commit();
    return res.json({ success: true, message: 'Invoice and related records deleted successfully' });

  } catch (err) {
    await connection.rollback();
    console.error('DELETE /invoices/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  } finally {
    connection.release();
  }
});

// GET /api/invoices/client-package/:clientName
router.get('/client-package/:clientName', async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT GROUP_CONCAT(ii.description SEPARATOR ', ') AS packages
      FROM invoices i
      JOIN invoice_items ii ON ii.invoice_id = i.id
      WHERE i.client_name = ?
    `, [req.params.clientName]);

    return res.json({
      success: true,
      packages: rows[0]?.packages ?? ''
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({
      success: false,
      message: err.message
    });
  }
});

// GET /api/invoices/client-details/:clientName
router.get('/client-details/:clientName', async (req, res) => {
  try {
    // ✅ FIX: Get the MOST RECENT invoice with PAID/PARTIAL status
    const [invoiceRows] = await db.query(
      `SELECT i.id, i.invoice_no, i.maintenance_date
       FROM invoices i
       WHERE i.client_name = ? AND i.status IN ('PAID', 'PARTIAL')
       ORDER BY i.created_at DESC 
       LIMIT 1`,
      [req.params.clientName]
    );

    if (invoiceRows.length === 0) {
      return res.json({
        success: true,
        data: { packages: '', maintenance_date: '' },
      });
    }

    const invoiceId = invoiceRows[0].id;
    const maintenanceDate = invoiceRows[0].maintenance_date || '';

    // ✅ Get the packages for this invoice
    const [itemRows] = await db.query(
      `SELECT GROUP_CONCAT(ii.description SEPARATOR ', ') AS packages
       FROM invoice_items ii
       WHERE ii.invoice_id = ?`,
      [invoiceId]
    );

    const packages = itemRows[0]?.packages || '';

    return res.json({
      success: true,
      data: {
        packages: packages,
        maintenance_date: maintenanceDate,
      },
    });
  } catch (err) {
    console.error('GET /client-details ERROR:', err.message);
    return res.status(500).json({ 
      success: false, 
      message: err.message 
    });
  }
});

module.exports = router;