// routes/quotations.js — Quotations CRUD API (with notes support)
const express = require('express');
const router  = express.Router();
const db      = require('../config/db');
const { authenticateToken } = require('./auth');


// GET /api/quotations/next-number — generates the next QT-YYYY-### number
router.get('/next-number', async (req, res) => {
  try {

    const now = new Date();

    const yyyy = now.getFullYear();
    const mm = String(now.getMonth() + 1).padStart(2, '0');
    const dd = String(now.getDate()).padStart(2, '0');

    const datePart = `${yyyy}${mm}${dd}`;

    // quotations count
    const [rows] = await db.query(
      `SELECT COUNT(*) AS total
       FROM quotations
       WHERE quotation_no LIKE ?`,
      [`QT-${datePart}%`]
    );

    // quotation = 301
    const nextNumber = 301 + rows[0].total;

    const quotationNo = `QT-${datePart}${nextNumber}`;

    return res.json({
      success: true,
      data: {
        quotationNo,
      },
    });

  } catch (err) {
    console.error(err);

    return res.status(500).json({
      success: false,
      message: err.message,
    });
  }
});

// GET /api/quotations — list all quotations with role-based filtering and creator details
router.get('/', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const [userRows] = await db.query('SELECT is_main_admin FROM employee_users WHERE id = ?', [userId]);
    const isMainAdmin = userRows.length > 0 && (userRows[0].is_main_admin === 1 || userRows[0].is_main_admin === true);

    let query = `
      SELECT q.id, q.quotation_no, q.client_name, q.quotation_date, q.expiry_date, q.include_gst,
              q.subtotal, q.tax, q.total_amount, q.paid_amount, q.balance_amount, q.status, q.created_at,
              q.linked_invoice_id, q.invoice_no AS linked_invoice_no, q.notes, q.terms,
              COALESCE(eu.full_name, 'Main Admin') AS created_by_name,
              (SELECT qi.description FROM quotation_items qi
                WHERE qi.quotation_id = q.id ORDER BY qi.sort_order ASC, qi.id ASC LIMIT 1) AS package_type
       FROM quotations q 
       LEFT JOIN employee_users eu ON q.created_by = eu.id
    `;
    let queryParams = [];

    if (!isMainAdmin) {
      query += ` WHERE q.created_by = ? `;
      queryParams.push(userId);
    }

    query += ` ORDER BY q.id DESC `;

    const [rows] = await db.query(query, queryParams);
    return res.json({ success: true, data: rows });
  } catch (err) {
    console.error('GET /quotations ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/quotations — save created_by
router.post('/', authenticateToken, async (req, res) => {
  const {
    quotationNo, clientName, clientId, quotationDate, expiryDate, includeGST,
    subtotal, tax, totalAmount, paidAmount, balanceAmount, items,
    notes, terms,
  } = req.body;

  if (!quotationNo || !clientName || !Array.isArray(items) || items.length === 0)
    return res.status(400).json({ success: false, message: 'quotationNo, clientName and at least one item are required' });

  const adminId = req.user.id; // ✅ Logged-in admin ID

  const connection = await db.getConnection();
  try {
    await connection.beginTransaction();

    const [result] = await connection.query(
      `INSERT INTO quotations
        (quotation_no, client_name, client_id, quotation_date, expiry_date, include_gst,
         subtotal, tax, total_amount, paid_amount, balance_amount, status,
         notes, terms, created_by)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'DRAFT', ?, ?, ?)`,
      [
        quotationNo, clientName, clientId, quotationDate || '', expiryDate || '',
        includeGST ? 1 : 0, subtotal || 0, tax || 0, totalAmount || 0,
        paidAmount || 0, balanceAmount || 0, notes || '', terms || '', adminId
      ]
    );

    const quotationId = result.insertId;

    for (let i = 0; i < items.length; i++) {
      const it = items[i];
      await connection.query(
        `INSERT INTO quotation_items
          (quotation_id, package_id, description, qty, rate, amount, paid_amount, pending_amount, sort_order)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          quotationId, it.packageId || null, it.description || '',
          it.qty || 1, it.rate || 0, it.amount || 0,
          it.paidAmount || 0, it.pendingAmount || 0, i,
        ]
      );
    }

    await connection.commit();
    return res.status(201).json({
      success: true,
      message: 'Quotation created successfully',
      data: { id: quotationId, quotationNo },
    });
  } catch (err) {
    await connection.rollback();
    console.error('POST /quotations ERROR:', err.message);
    if (err.code === 'ER_DUP_ENTRY')
      return res.status(409).json({ success: false, message: `Quotation "${quotationNo}" already exists` });
    return res.status(500).json({ success: false, message: err.message });
  } finally {
    connection.release();
  }
});

// PATCH /api/quotations/:id/status — update status; if ACCEPTED, auto-create a linked invoice
router.patch('/:id/status', authenticateToken, async (req, res) => {
  const { status } = req.body;
  const allowed = ['DRAFT', 'SENT', 'ACCEPTED', 'EXPIRED'];

  if (!status || !allowed.includes(status.toUpperCase()))
    return res.status(400).json({ success: false, message: `status must be one of ${allowed.join(', ')}` });

  const newStatus = status.toUpperCase();
  const adminId = req.user.id; // 🟢 Logged-in admin/employee ID

  const connection = await db.getConnection();
  try {
    await connection.beginTransaction();

    // ── 1. Update the quotation's status ────────────────────────────────────
    const [result] = await connection.query(
      `UPDATE quotations SET status = ? WHERE id = ?`,
      [newStatus, req.params.id]
    );
    if (result.affectedRows === 0) {
      await connection.rollback();
      return res.status(404).json({ success: false, message: 'Quotation not found' });
    }

    // ── 2. If ACCEPTED → auto-create a linked invoice ────────────────────────
    let invoiceNo   = null;
    let invoiceId   = null;

    if (newStatus === 'ACCEPTED') {
      const [existing] = await connection.query(
        `SELECT linked_invoice_id, invoice_no FROM quotations WHERE id = ?`,
        [req.params.id]
      );
      if (existing[0]?.linked_invoice_id) {
        await connection.commit();
        return res.json({
          success: true,
          message: 'Status updated (invoice already exists)',
          data: { invoiceNo: existing[0].invoice_no, invoiceId: existing[0].linked_invoice_id, alreadyExists: true },
        });
      }

      const [quotRows] = await connection.query(
        `SELECT * FROM quotations WHERE id = ?`, [req.params.id]);
      const quot = quotRows[0];

      const [items] = await connection.query(
        `SELECT * FROM quotation_items WHERE quotation_id = ? ORDER BY sort_order ASC, id ASC`,
        [req.params.id]
      );

      const quotNo = quot.quotation_no || '';
      const parts  = quotNo.split('-');
      const year   = parts[1] || new Date().getFullYear();
      const suffix = parts[2] || '0001';
      invoiceNo    = `INV-${year}-${suffix}`;

      const [dupCheck] = await connection.query(
        `SELECT id FROM invoices WHERE invoice_no = ?`, [invoiceNo]);
      if (dupCheck.length > 0) {
        invoiceNo = `INV-${year}-${suffix}-R${dupCheck.length + 1}`;
      }

      const invStatus = 'DRAFT';

      // 🟢 3. Insert invoice with created_by set to the logged-in user
      const [invResult] = await connection.query(
        `INSERT INTO invoices
          (invoice_no, client_name, invoice_date, maintenance_date, include_gst,
           discount, subtotal, tax, total_amount, paid_amount, balance_amount,
           status, notes, linked_quotation_id, linked_quotation_no, created_by)
         VALUES (?, ?, ?, ?, ?, 0, ?, ?, ?, 0, ?, ?, '', ?, ?, ?)`,
        [
          invoiceNo,
          quot.client_name,
          quot.quotation_date,
          '',
          quot.include_gst,
          quot.subtotal,
          quot.tax,
          quot.total_amount,
          quot.total_amount,
          invStatus,
          req.params.id,
          quotNo,
          adminId, // 🟢 Login pannavanga ID inga store aagum
        ]
      );
      invoiceId = invResult.insertId;

      for (let i = 0; i < items.length; i++) {
        const it = items[i];
        await connection.query(
          `INSERT INTO invoice_items
            (invoice_id, package_id, description, qty, rate, amount, paid_amount, pending_amount, sort_order)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          [
            invoiceId,
            it.package_id || null,
            it.description,
            it.qty,
            it.rate,
            it.amount,
            0,
            it.amount,
            i,
          ]
        );
      }

      await connection.query(
        `UPDATE quotations SET linked_invoice_id = ?, invoice_no = ? WHERE id = ?`,
        [invoiceId, invoiceNo, req.params.id]
      );
    }

    await connection.commit();

    return res.json({
      success: true,
      message: newStatus === 'ACCEPTED'
        ? `Quotation accepted — Invoice ${invoiceNo} created automatically`
        : 'Status updated',
      data: invoiceNo ? { invoiceNo, invoiceId } : null,
    });
  } catch (err) {
    await connection.rollback();
    console.error('PATCH /quotations/:id/status ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  } finally {
    connection.release();
  }
});

// GET /api/quotations/:id — single quotation with its items
router.get('/:id', async (req, res) => {
  try {
    const [qRows] = await db.query(`SELECT * FROM quotations WHERE id = ?`, [req.params.id]);
    if (qRows.length === 0)
      return res.status(404).json({ success: false, message: 'Quotation not found' });

    const [items] = await db.query(
      `SELECT id, package_id, description, qty, rate, amount, paid_amount, pending_amount, sort_order
       FROM quotation_items WHERE quotation_id = ? ORDER BY sort_order ASC, id ASC`,
      [req.params.id]
    );

    return res.json({ success: true, data: { ...qRows[0], items } });
  } catch (err) {
    console.error('GET /quotations/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

router.post('/', async (req, res) => {
  const {
    quotationNo, clientName, clientId, quotationDate, expiryDate, includeGST,
    subtotal, tax, totalAmount, paidAmount, balanceAmount, items,
    notes, terms,
  } = req.body;

  if (!quotationNo || !clientName || !Array.isArray(items) || items.length === 0)
    return res.status(400).json({ success: false, message: 'quotationNo, clientName and at least one item are required' });

  const connection = await db.getConnection();
  try {
    await connection.beginTransaction();

    const [result] = await connection.query(
      `INSERT INTO quotations
        (quotation_no, client_name, client_id, quotation_date, expiry_date, include_gst,
         subtotal, tax, total_amount, paid_amount, balance_amount, status,
         notes, terms)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'DRAFT', ?, ?)`,
      [
        quotationNo,                    // ✅ quotation_no (?)
        clientName,                     // ✅ client_name (?)
        clientId,                       // ✅ client_id (?) - FIXED: changed from clientId to client_id
        quotationDate || '',            // ✅ quotation_date (?)
        expiryDate || '',               // ✅ expiry_date (?)
        includeGST ? 1 : 0,             // ✅ include_gst (?)
        subtotal || 0,                  // ✅ subtotal (?)
        tax || 0,                       // ✅ tax (?)
        totalAmount || 0,               // ✅ total_amount (?)
        paidAmount || 0,                // ✅ paid_amount (?)
        balanceAmount || 0,             // ✅ balance_amount (?) - FIXED: was missing!
        notes || '',                    // ✅ notes (?)
        terms || '',                    // ✅ terms (?)
      ]
      // status is hardcoded as 'DRAFT' ✅
    );

    const quotationId = result.insertId;

    // ✅ Insert quotation items
    for (let i = 0; i < items.length; i++) {
      const it = items[i];
      await connection.query(
        `INSERT INTO quotation_items
          (quotation_id, package_id, description, qty, rate, amount, paid_amount, pending_amount, sort_order)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          quotationId,
          it.packageId || null,
          it.description || '',
          it.qty || 1,
          it.rate || 0,
          it.amount || 0,
          it.paidAmount || 0,
          it.pendingAmount || 0,
          i,
        ]
      );
    }

    await connection.commit();

    return res.status(201).json({
      success: true,
      message: 'Quotation created successfully',
      data: { id: quotationId, quotationNo },
    });
  } catch (err) {
    await connection.rollback();
    console.error('POST /quotations ERROR:', err.message);
    if (err.code === 'ER_DUP_ENTRY')
      return res.status(409).json({ success: false, message: `Quotation "${quotationNo}" already exists` });
    return res.status(500).json({ success: false, message: err.message });
  } finally {
    connection.release();
  }
});


// PUT /api/quotations/:id — update quotation + replace its line items
// ✅ UPDATED: Added notes and terms support
router.put('/:id', async (req, res) => {
  const {
    clientName, quotationDate, expiryDate, includeGST,
    subtotal, tax, totalAmount, paidAmount, balanceAmount, items, status,
    notes, terms,
  } = req.body;

  if (!clientName || !Array.isArray(items) || items.length === 0)
    return res.status(400).json({ success: false, message: 'clientName and at least one item are required' });

  const connection = await db.getConnection();
  try {
    await connection.beginTransaction();

    // ✅ UPDATED: Added notes and terms to UPDATE
    const [result] = await connection.query(
      `UPDATE quotations
       SET client_name = ?, quotation_date = ?, expiry_date = ?, include_gst = ?,
           subtotal = ?, tax = ?, total_amount = ?, paid_amount = ?, balance_amount = ?,
           status = COALESCE(?, status),
           notes = ?, terms = ?
       WHERE id = ?`,
      [
        clientName, quotationDate || '', expiryDate || '',
        includeGST ? 1 : 0,
        subtotal || 0, tax || 0, totalAmount || 0, paidAmount || 0, balanceAmount || 0,
        status || null,
        notes || '',     // ✅ NEW: Update notes
        terms || '',     // ✅ NEW: Update terms
        req.params.id,
      ]
    );

    if (result.affectedRows === 0) {
      await connection.rollback();
      return res.status(404).json({ success: false, message: 'Quotation not found' });
    }

    // Replace all line items
    await connection.query(`DELETE FROM quotation_items WHERE quotation_id = ?`, [req.params.id]);

    for (let i = 0; i < items.length; i++) {
      const it = items[i];
      await connection.query(
        `INSERT INTO quotation_items
          (quotation_id, package_id, description, qty, rate, amount, paid_amount, pending_amount, sort_order)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          req.params.id, it.packageId || null, it.description || '',
          it.qty || 1, it.rate || 0, it.amount || 0,
          it.paidAmount || 0, it.pendingAmount || 0, i,
        ]
      );
    }

    await connection.commit();
    return res.json({ success: true, message: 'Quotation updated' });
  } catch (err) {
    await connection.rollback();
    console.error('PUT /quotations/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  } finally {
    connection.release();
  }
});

// DELETE /api/quotations/:id — delete quotation (cascades to items)
router.delete('/:id', async (req, res) => {
  try {
    const [result] = await db.query(`DELETE FROM quotations WHERE id = ?`, [req.params.id]);
    if (result.affectedRows === 0)
      return res.status(404).json({ success: false, message: 'Quotation not found' });
    return res.json({ success: true, message: 'Quotation deleted' });
  } catch (err) {
    console.error('DELETE /quotations/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router; 