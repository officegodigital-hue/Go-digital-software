// routes/invoices.js
// ============================================================
// GoDigital - Invoices CRUD API
// With invoice line items, payment history, recurring invoices,
// daily/monthly invoice numbering and CSV export.
// ============================================================

const express = require('express');
const router = express.Router();
const db = require('../config/db');
const { authenticateToken } = require('./auth');

// ============================================================
// CONSTANTS
// ============================================================

const ALLOWED_INVOICE_MODES = ['daily', 'monthly'];
const ALLOWED_STATUS = ['DRAFT', 'PARTIAL', 'PAID', 'OVERDUE'];

const INVOICE_START_SEQUENCE = 301;


// ============================================================
// DATE PARSER
// Supports:
//
// DD/MM/YYYY
// YYYY-MM-DD
// JS Date
// ============================================================

function parseInvoiceDate(value) {
  if (!value) {
    return new Date();
  }

  if (value instanceof Date) {
    return value;
  }

  const str = String(value).trim();

  if (!str) {
    return new Date();
  }

  // ----------------------------------------------------------
  // DD/MM/YYYY
  // ----------------------------------------------------------

  const slashParts = str.split('/');

  if (slashParts.length === 3) {
    const dd = parseInt(slashParts[0], 10);
    const mm = parseInt(slashParts[1], 10);
    const yyyy = parseInt(slashParts[2], 10);

    if (
      !Number.isNaN(dd) &&
      !Number.isNaN(mm) &&
      !Number.isNaN(yyyy)
    ) {
      const result = new Date(
        yyyy,
        mm - 1,
        dd
      );

      if (!Number.isNaN(result.getTime())) {
        return result;
      }
    }
  }

  // ----------------------------------------------------------
  // YYYY-MM-DD
  // ----------------------------------------------------------

  const dashParts = str.split('-');

  if (dashParts.length === 3) {
    const yyyy = parseInt(dashParts[0], 10);
    const mm = parseInt(dashParts[1], 10);
    const dd = parseInt(dashParts[2], 10);

    if (
      !Number.isNaN(dd) &&
      !Number.isNaN(mm) &&
      !Number.isNaN(yyyy)
    ) {
      const result = new Date(
        yyyy,
        mm - 1,
        dd
      );

      if (!Number.isNaN(result.getTime())) {
        return result;
      }
    }
  }

  // ----------------------------------------------------------
  // Normal JS date
  // ----------------------------------------------------------

  const parsed = new Date(str);

  if (!Number.isNaN(parsed.getTime())) {
    return parsed;
  }

  return new Date();
}


// ============================================================
// FORMAT DATE AS DD/MM/YYYY
// ============================================================

function formatDDMMYYYY(date) {
  const d = parseInvoiceDate(date);

  const dd = String(
    d.getDate()
  ).padStart(2, '0');

  const mm = String(
    d.getMonth() + 1
  ).padStart(2, '0');

  const yyyy = d.getFullYear();

  return `${dd}/${mm}/${yyyy}`;
}


// ============================================================
// FORMAT DATE AS YYYY-MM-DD
// ============================================================

function formatYYYYMMDD(date) {
  const d = parseInvoiceDate(date);

  const yyyy = d.getFullYear();

  const mm = String(
    d.getMonth() + 1
  ).padStart(2, '0');

  const dd = String(
    d.getDate()
  ).padStart(2, '0');

  return `${yyyy}-${mm}-${dd}`;
}


// ============================================================
// INVOICE NUMBER GENERATOR
//
// DAILY:
//
// INV-YYYYMMDD301
// INV-YYYYMMDD302
// INV-YYYYMMDD303
//
// Example:
//
// INV-20260907301
// INV-20260907302
//
// ------------------------------------------------------------
//
// MONTHLY:
//
// INV-YYYYMM301
// INV-YYYYMM302
// INV-YYYYMM303
//
// Example:
//
// INV-202609301
// INV-202609302
//
// IMPORTANT:
//
// Invoice number is ALWAYS generated from invoices table.
// Frontend invoice number is NOT trusted.
// Quotation number is NOT used to generate invoice number.
// ============================================================

async function generateNextInvoiceNumber(
  connection,
  invoiceDate,
  mode = 'daily'
) {
  const normalizedMode =
    String(mode || 'daily')
      .trim()
      .toLowerCase();

  if (!ALLOWED_INVOICE_MODES.includes(normalizedMode)) {
    throw new Error(
      'Invoice mode must be daily or monthly'
    );
  }

  const date = parseInvoiceDate(invoiceDate);

  if (
    !date ||
    Number.isNaN(date.getTime())
  ) {
    throw new Error(
      'Invalid invoice date'
    );
  }

  const yyyy = date.getFullYear();

  const mm = String(
    date.getMonth() + 1
  ).padStart(2, '0');

  const dd = String(
    date.getDate()
  ).padStart(2, '0');

  let prefix;

  if (normalizedMode === 'monthly') {
    // Example:
    // INV-202609301

    prefix = `INV-${yyyy}${mm}`;
  } else {
    // Example:
    // INV-20260907301

    prefix = `INV-${yyyy}${mm}${dd}`;
  }

  const likePattern =
    `${prefix}%`;

  // ----------------------------------------------------------
  // IMPORTANT:
  // We only search invoice numbers belonging to this
  // exact daily/monthly prefix.
  // ----------------------------------------------------------

  const [rows] =
    await connection.query(
      `
      SELECT
        id,
        invoice_no
      FROM invoices
      WHERE invoice_no LIKE ?
      ORDER BY id DESC
      LIMIT 100
      `,
      [likePattern]
    );

  let highestSequence =
    INVOICE_START_SEQUENCE - 1;

  for (const row of rows) {
    const invoiceNo =
      String(row.invoice_no || '');

    if (
      !invoiceNo.startsWith(prefix)
    ) {
      continue;
    }

    const sequencePart =
      invoiceNo.substring(
        prefix.length
      );

    const sequence =
      parseInt(sequencePart, 10);

    if (
      !Number.isNaN(sequence) &&
      sequence >= INVOICE_START_SEQUENCE &&
      sequence > highestSequence
    ) {
      highestSequence = sequence;
    }
  }

  const nextSequence =
    highestSequence + 1;

  return `${prefix}${nextSequence}`;
}


// ============================================================
// CSV ESCAPE
// ============================================================

function csvEscape(value) {
  if (
    value === null ||
    value === undefined
  ) {
    return '""';
  }

  const text = String(value);

  return `"${text.replace(/"/g, '""')}"`;
}


// ============================================================
// GET /api/invoices/next-number
//
// Query:
//
// ?mode=daily
// ?mode=monthly
//
// Optional:
//
// ?date=07/09/2026
//
// IMPORTANT:
// This only previews the next number.
// Actual POST /invoices generates the final number again.
// ============================================================

router.get(
  '/next-number',
  authenticateToken,
  async (req, res) => {
    let connection;

    try {
      const mode =
        String(
          req.query.mode || 'daily'
        )
          .trim()
          .toLowerCase();

      if (
        !ALLOWED_INVOICE_MODES.includes(mode)
      ) {
        return res.status(400).json({
          success: false,
          message:
            'mode must be daily or monthly',
        });
      }

      const invoiceDate =
        req.query.date ||
        new Date();

      connection =
        await db.getConnection();

      await connection.beginTransaction();

      const invoiceNo =
        await generateNextInvoiceNumber(
          connection,
          invoiceDate,
          mode
        );

      await connection.commit();

      return res.json({
        success: true,
        data: {
          invoiceNo,
          mode,
          invoiceDate:
            formatDDMMYYYY(
              invoiceDate
            ),
        },
      });

    } catch (err) {
      if (connection) {
        try {
          await connection.rollback();
        } catch (_) {}
      }

      console.error(
        'GET /invoices/next-number ERROR:',
        err.message
      );

      return res.status(500).json({
        success: false,
        message: err.message,
      });

    } finally {
      if (connection) {
        connection.release();
      }
    }
  }
);


// ============================================================
// GET /api/invoices/metrics
//
// Summary cards
// ============================================================

router.get(
  '/metrics',
  authenticateToken,
  async (req, res) => {
    try {
      const userId =
        req.user.id;

      const [userRows] =
        await db.query(
          `
          SELECT is_main_admin
          FROM employee_users
          WHERE id = ?
          `,
          [userId]
        );

      const isMainAdmin =
        userRows.length > 0 &&
        (
          userRows[0].is_main_admin === 1 ||
          userRows[0].is_main_admin === true
        );

      const {
        month,
        year,
      } = req.query;

      // ------------------------------------------------------
      // IMPORTANT:
      // Do NOT INNER JOIN clients here.
      //
      // An invoice must remain visible even if:
      // - client became inactive
      // - client was renamed
      // - client record no longer matches
      // ------------------------------------------------------

      let query = `
        SELECT

          COALESCE(
            SUM(i.total_amount),
            0
          ) AS total_invoiced,

          COALESCE(
            SUM(i.paid_amount),
            0
          ) AS collected_amount,

          COALESCE(
            SUM(i.balance_amount),
            0
          ) AS outstanding_balance

        FROM invoices i

        WHERE 1 = 1
      `;

      const params = [];

      if (!isMainAdmin) {
        query += `
          AND i.created_by = ?
        `;

        params.push(userId);
      }

      if (
        month &&
        year
      ) {
        query += `
          AND
          MONTH(
            COALESCE(
              STR_TO_DATE(
                i.invoice_date,
                '%d/%m/%Y'
              ),
              STR_TO_DATE(
                i.invoice_date,
                '%Y-%m-%d'
              )
            )
          ) = ?

          AND
          YEAR(
            COALESCE(
              STR_TO_DATE(
                i.invoice_date,
                '%d/%m/%Y'
              ),
              STR_TO_DATE(
                i.invoice_date,
                '%Y-%m-%d'
              )
            )
          ) = ?
        `;

        params.push(
          parseInt(month, 10),
          parseInt(year, 10)
        );
      }

      const [rows] =
        await db.query(
          query,
          params
        );

      return res.json({
        success: true,
        data:
          rows[0] || {
            total_invoiced: 0,
            collected_amount: 0,
            outstanding_balance: 0,
          },
      });

    } catch (err) {
      console.error(
        'GET /invoices/metrics ERROR:',
        err.message
      );

      return res.status(500).json({
        success: false,
        message: err.message,
      });
    }
  }
);


// ============================================================
// GET /api/invoices/export-csv
//
// MUST BE BEFORE /:id
//
// Exports ALL invoices user is allowed to see.
// ============================================================

router.get(
  '/export-csv',
  authenticateToken,
  async (req, res) => {
    try {
      const userId =
        req.user.id;

      const [userRows] =
        await db.query(
          `
          SELECT is_main_admin
          FROM employee_users
          WHERE id = ?
          `,
          [userId]
        );

      const isMainAdmin =
        userRows.length > 0 &&
        (
          userRows[0].is_main_admin === 1 ||
          userRows[0].is_main_admin === true
        );

      let query = `
        SELECT

          i.id,
          i.invoice_no,
          i.client_name,
          i.invoice_date,
          i.maintenance_date,
          i.include_gst,
          i.discount,
          i.subtotal,
          i.tax,
          i.total_amount,
          i.paid_amount,
          i.balance_amount,
          i.status,
          i.created_at,
          i.linked_quotation_id,

          COALESCE(
            eu.full_name,
            'Main Admin'
          ) AS created_by_name,

          (
            SELECT
              ii.description
            FROM invoice_items ii
            WHERE ii.invoice_id = i.id
            ORDER BY
              ii.sort_order ASC,
              ii.id ASC
            LIMIT 1
          ) AS package_type

        FROM invoices i

        LEFT JOIN employee_users eu
          ON i.created_by = eu.id

        WHERE 1 = 1
      `;

      const params = [];

      if (!isMainAdmin) {
        query += `
          AND i.created_by = ?
        `;

        params.push(userId);
      }

      query += `
        ORDER BY i.id DESC
      `;

      const [rows] =
        await db.query(
          query,
          params
        );

      const header = [
        'Invoice ID',
        'Invoice No',
        'Client Name',
        'Package Type',
        'Invoice Date',
        'Maintenance Date',
        'GST',
        'Discount',
        'Subtotal',
        'Tax',
        'Total Amount',
        'Paid Amount',
        'Balance Amount',
        'Status',
        'Created By',
        'Linked Quotation ID',
        'Created At',
      ];

      const csvRows = [];

      csvRows.push(
        header
          .map(csvEscape)
          .join(',')
      );

      for (const row of rows) {
        csvRows.push(
          [
            row.id,
            row.invoice_no,
            row.client_name,
            row.package_type,
            row.invoice_date,
            row.maintenance_date,

            row.include_gst
              ? 'Yes'
              : 'No',

            row.discount,
            row.subtotal,
            row.tax,
            row.total_amount,
            row.paid_amount,
            row.balance_amount,
            row.status,
            row.created_by_name,
            row.linked_quotation_id,
            row.created_at,
          ]
            .map(csvEscape)
            .join(',')
        );
      }

      // UTF-8 BOM
      const csv =
        '\uFEFF' +
        csvRows.join('\r\n');

      const fileDate =
        formatYYYYMMDD(
          new Date()
        );

      res.setHeader(
        'Content-Type',
        'text/csv; charset=utf-8'
      );

      res.setHeader(
        'Content-Disposition',
        `attachment; filename="GoDigital_Invoices_${fileDate}.csv"`
      );

      return res.send(csv);

    } catch (err) {
      console.error(
        'GET /invoices/export-csv ERROR:',
        err.message
      );

      return res.status(500).json({
        success: false,
        message: err.message,
      });
    }
  }
);


// ============================================================
// GET /api/invoices
//
// ALL invoices.
//
// IMPORTANT FIX:
// No INNER JOIN clients.
// No c.is_active = 1 filter.
//
// Therefore old invoices will NOT disappear just because
// client became inactive.
// ============================================================

router.get(
  '/',
  authenticateToken,
  async (req, res) => {
    try {
      const userId =
        req.user.id;

      const [userRows] =
        await db.query(
          `
          SELECT is_main_admin
          FROM employee_users
          WHERE id = ?
          `,
          [userId]
        );

      const isMainAdmin =
        userRows.length > 0 &&
        (
          userRows[0].is_main_admin === 1 ||
          userRows[0].is_main_admin === true
        );

      let query = `
        SELECT

          i.id,
          i.invoice_no,
          i.client_name,
          i.invoice_date,
          i.maintenance_date,
          i.include_gst,
          i.discount,
          i.subtotal,
          i.tax,
          i.total_amount,
          i.paid_amount,
          i.balance_amount,
          i.status,
          i.notes,
          i.created_at,
          i.created_by,
          i.linked_quotation_id,

          -- Kept for compatibility with existing frontend.
          i.invoice_no AS linked_invoice_no,

          COALESCE(
            eu.full_name,
            'Main Admin'
          ) AS created_by_name,

          (
            SELECT
              ii.description
            FROM invoice_items ii
            WHERE ii.invoice_id = i.id
            ORDER BY
              ii.sort_order ASC,
              ii.id ASC
            LIMIT 1
          ) AS package_type

        FROM invoices i

        LEFT JOIN employee_users eu
          ON i.created_by = eu.id

        WHERE 1 = 1
      `;

      const queryParams = [];

      if (!isMainAdmin) {
        query += `
          AND i.created_by = ?
        `;

        queryParams.push(
          userId
        );
      }

      query += `
        ORDER BY i.id DESC
      `;

      const [rows] =
        await db.query(
          query,
          queryParams
        );

      return res.json({
        success: true,
        data: rows,
      });

    } catch (err) {
      console.error(
        'GET /invoices ERROR:',
        err.message
      );

      return res.status(500).json({
        success: false,
        message: err.message,
      });
    }
  }
);


// ============================================================
// GET /api/invoices/client-package/:clientName
//
// IMPORTANT:
// This route MUST be before /:id
// ============================================================

router.get(
  '/client-package/:clientName',
  async (req, res) => {
    try {
      const clientName =
        req.params.clientName;

      const [rows] =
        await db.query(
          `
          SELECT
            GROUP_CONCAT(
              DISTINCT ii.description
              SEPARATOR ', '
            ) AS packages

          FROM invoices i

          INNER JOIN invoice_items ii
            ON ii.invoice_id = i.id

          WHERE
            TRIM(
              LOWER(i.client_name)
            )
            =
            TRIM(
              LOWER(?)
            )
          `,
          [clientName]
        );

      return res.json({
        success: true,
        packages:
          rows[0]?.packages || '',
      });

    } catch (err) {
      console.error(
        'GET /client-package ERROR:',
        err.message
      );

      return res.status(500).json({
        success: false,
        message: err.message,
      });
    }
  }
);


// ============================================================
// GET /api/invoices/client-details/:clientName
//
// IMPORTANT:
// This route MUST be before /:id
// ============================================================

router.get(
  '/client-details/:clientName',
  async (req, res) => {
    try {
      const clientName =
        req.params.clientName;

      // ------------------------------------------------------
      // Get most recent PAID/PARTIAL invoice.
      // No client table dependency.
      // ------------------------------------------------------

      const [invoiceRows] =
        await db.query(
          `
          SELECT
            i.id,
            i.invoice_no,
            i.maintenance_date,
            i.created_at

          FROM invoices i

          WHERE
            TRIM(
              LOWER(i.client_name)
            )
            =
            TRIM(
              LOWER(?)
            )

            AND i.status IN (
              'PAID',
              'PARTIAL'
            )

          ORDER BY
            i.created_at DESC,
            i.id DESC

          LIMIT 1
          `,
          [clientName]
        );

      if (
        invoiceRows.length === 0
      ) {
        return res.json({
          success: true,
          data: {
            packages: '',
            maintenance_date: '',
          },
        });
      }

      const invoiceId =
        invoiceRows[0].id;

      const maintenanceDate =
        invoiceRows[0]
          .maintenance_date || '';

      const [itemRows] =
        await db.query(
          `
          SELECT
            GROUP_CONCAT(
              ii.description
              SEPARATOR ', '
            ) AS packages

          FROM invoice_items ii

          WHERE
            ii.invoice_id = ?
          `,
          [invoiceId]
        );

      const packages =
        itemRows[0]?.packages || '';

      return res.json({
        success: true,
        data: {
          packages,
          maintenance_date:
            maintenanceDate,
        },
      });

    } catch (err) {
      console.error(
        'GET /client-details ERROR:',
        err.message
      );

      return res.status(500).json({
        success: false,
        message: err.message,
      });
    }
  }
);


// ============================================================
// GET /api/invoices/:id
//
// Single invoice + items + payment history
//
// IMPORTANT:
// This route is AFTER all specific GET routes.
// ============================================================

router.get(
  '/:id',
  async (req, res) => {
    try {
      const invoiceId =
        req.params.id;

      const [iRows] =
        await db.query(
          `
          SELECT *
          FROM invoices
          WHERE id = ?
          `,
          [invoiceId]
        );

      if (
        iRows.length === 0
      ) {
        return res.status(404).json({
          success: false,
          message:
            'Invoice not found',
        });
      }

      const [items] =
        await db.query(
          `
          SELECT

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

          ORDER BY
            sort_order ASC,
            id ASC
          `,
          [invoiceId]
        );

      const [payments] =
        await db.query(
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

          ORDER BY
            id DESC
          `,
          [invoiceId]
        );

      return res.json({
        success: true,
        data: {
          ...iRows[0],
          items,
          payments,
        },
      });

    } catch (err) {
      console.error(
        'GET /invoices/:id ERROR:',
        err.message
      );

      return res.status(500).json({
        success: false,
        message: err.message,
      });
    }
  }
);


// ============================================================
// POST /api/invoices
//
// CREATE INVOICE
//
// IMPORTANT:
// invoiceNo from frontend is NOT trusted.
//
// Backend generates:
// daily:
// INV-YYYYMMDD301
//
// monthly:
// INV-YYYYMM301
// ============================================================

router.post(
  '/',
  authenticateToken,
  async (req, res) => {

    const {
      // Kept from frontend for compatibility.
      // Backend will NOT trust this.
      invoiceNo: frontendInvoiceNo,

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
      invoiceMode,
    } = req.body;

    // --------------------------------------------------------
    // VALIDATION
    // --------------------------------------------------------

    if (
      !clientName ||
      !Array.isArray(items) ||
      items.length === 0
    ) {
      return res.status(400).json({
        success: false,
        message:
          'clientName and at least one item are required',
      });
    }

    const mode =
      String(
        invoiceMode || 'daily'
      )
        .trim()
        .toLowerCase();

    if (
      !ALLOWED_INVOICE_MODES.includes(mode)
    ) {
      return res.status(400).json({
        success: false,
        message:
          'invoiceMode must be daily or monthly',
      });
    }

    const adminId =
      req.user.id;

    const total =
      Number(totalAmount || 0);

    const paid =
      Number(paidAmount || 0);

    const balance =
      Number(
        balanceAmount !== undefined
          ? balanceAmount
          : Math.max(total - paid, 0)
      );

    let status = 'DRAFT';

    if (paid <= 0) {
      status = 'DRAFT';
    } else if (paid >= total) {
      status = 'PAID';
    } else {
      status = 'PARTIAL';
    }

    let connection;

    try {
      connection =
        await db.getConnection();

      await connection.beginTransaction();

      // ------------------------------------------------------
      // GENERATE ACTUAL INVOICE NUMBER FROM DB
      // ------------------------------------------------------

      const generatedInvoiceNo =
        await generateNextInvoiceNumber(
          connection,
          invoiceDate || new Date(),
          mode
        );

      // ------------------------------------------------------
      // INSERT INVOICE
      // ------------------------------------------------------

      const [result] =
        await connection.query(
          `
          INSERT INTO invoices
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
            notes,
            created_by
          )

          VALUES
          (
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?
          )
          `,
          [
            generatedInvoiceNo,
            clientName,
            invoiceDate || '',
            maintenanceDate || '',
            includeGST ? 1 : 0,
            Number(discount || 0),
            Number(subtotal || 0),
            Number(tax || 0),
            total,
            paid,
            balance,
            status,
            notes || '',
            adminId,
          ]
        );

      const invoiceId =
        result.insertId;

      // ------------------------------------------------------
      // INSERT LINE ITEMS
      // ------------------------------------------------------

      for (
        let i = 0;
        i < items.length;
        i++
      ) {
        const it =
          items[i] || {};

        await connection.query(
          `
          INSERT INTO invoice_items
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

          VALUES
          (
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?
          )
          `,
          [
            invoiceId,

            it.packageId ??
              it.package_id ??
              null,

            it.description || '',

            Number(
              it.qty || 1
            ),

            Number(
              it.rate || 0
            ),

            Number(
              it.tax ??
              it.taxPercent ??
              it.tax_percent ??
              0
            ),

            Number(
              it.discount ??
              it.discountAmount ??
              it.discount_amount ??
              0
            ),

            Number(
              it.amount || 0
            ),

            Number(
              it.paidAmount ??
              it.paid_amount ??
              0
            ),

            Number(
              it.pendingAmount ??
              it.pending_amount ??
              0
            ),

            i,
          ]
        );
      }

      // ------------------------------------------------------
      // INITIAL PAYMENT HISTORY
      //
      // Only create payment history when invoice has an
      // actual paid amount.
      //
      // This avoids creating meaningless zero-payment rows.
      // ------------------------------------------------------

      if (paid > 0) {
        await connection.query(
          `
          INSERT INTO invoice_payments
          (
            invoice_id,
            paid_date,
            total_amount,
            paid_total_amount,
            paid_amount,
            balanced_amount
          )

          VALUES
          (
            ?,
            ?,
            ?,
            ?,
            ?,
            ?
          )
          `,
          [
            invoiceId,
            invoiceDate ||
              new Date(),
            total,
            paid,
            paid,
            balance,
          ]
        );
      }

      await connection.commit();

      return res.status(201).json({
        success: true,
        message:
          'Invoice created successfully',

        data: {
          id: invoiceId,

          // THIS is the real saved number.
          invoiceNo:
            generatedInvoiceNo,

          status,

          mode,

          // Returned only for debugging/
          // compatibility.
          requestedInvoiceNo:
            frontendInvoiceNo || null,
        },
      });

    } catch (err) {
      if (connection) {
        try {
          await connection.rollback();
        } catch (_) {}
      }

      console.error(
        'POST /invoices ERROR:',
        err.message
      );

      if (
        err.code ===
        'ER_DUP_ENTRY'
      ) {
        return res.status(409).json({
          success: false,
          message:
            'Invoice number already exists. Please retry.',
        });
      }

      return res.status(500).json({
        success: false,
        message: err.message,
      });

    } finally {
      if (connection) {
        connection.release();
      }
    }
  }
);


// ============================================================
// PUT /api/invoices/:id
//
// UPDATE INVOICE + REPLACE LINE ITEMS
// ============================================================

router.put(
  '/:id',
  async (req, res) => {

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

    if (
      !clientName ||
      !Array.isArray(items) ||
      items.length === 0
    ) {
      return res.status(400).json({
        success: false,
        message:
          'clientName and at least one item are required',
      });
    }

    const total =
      Number(totalAmount || 0);

    const paid =
      Number(paidAmount || 0);

    let derivedStatus =
      status
        ? String(status)
            .toUpperCase()
        : null;

    if (
      derivedStatus &&
      !ALLOWED_STATUS.includes(
        derivedStatus
      )
    ) {
      return res.status(400).json({
        success: false,
        message:
          `status must be one of ${ALLOWED_STATUS.join(', ')}`,
      });
    }

    if (!derivedStatus) {
      if (paid <= 0) {
        derivedStatus = 'DRAFT';
      } else if (paid >= total) {
        derivedStatus = 'PAID';
      } else {
        derivedStatus = 'PARTIAL';
      }
    }

    const balance =
      Number(
        balanceAmount !== undefined
          ? balanceAmount
          : Math.max(total - paid, 0)
      );

    let connection;

    try {
      connection =
        await db.getConnection();

      await connection.beginTransaction();

      // ------------------------------------------------------
      // GET OLD INVOICE
      // ------------------------------------------------------

      const [[oldInvoice]] =
        await connection.query(
          `
          SELECT
            id,
            paid_amount,
            invoice_no

          FROM invoices

          WHERE id = ?

          FOR UPDATE
          `,
          [req.params.id]
        );

      if (!oldInvoice) {
        await connection.rollback();

        return res.status(404).json({
          success: false,
          message:
            'Invoice not found',
        });
      }

      const oldPaid =
        Number(
          oldInvoice.paid_amount || 0
        );

      const newPayment =
        paid - oldPaid;

      // ------------------------------------------------------
      // UPDATE MAIN INVOICE
      //
      // invoice_no is intentionally NOT changed.
      // ------------------------------------------------------

      const [result] =
        await connection.query(
          `
          UPDATE invoices

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

          WHERE id = ?
          `,
          [
            clientName,

            invoiceDate || '',

            maintenanceDate || '',

            includeGST ? 1 : 0,

            Number(
              discount || 0
            ),

            Number(
              subtotal || 0
            ),

            Number(
              tax || 0
            ),

            total,

            paid,

            balance,

            derivedStatus,

            notes || '',

            req.params.id,
          ]
        );

      if (
        result.affectedRows === 0
      ) {
        await connection.rollback();

        return res.status(404).json({
          success: false,
          message:
            'Invoice not found',
        });
      }

      // ------------------------------------------------------
      // DELETE OLD ITEMS
      // ------------------------------------------------------

      await connection.query(
        `
        DELETE FROM invoice_items
        WHERE invoice_id = ?
        `,
        [req.params.id]
      );

      // ------------------------------------------------------
      // INSERT UPDATED ITEMS
      // ------------------------------------------------------

      for (
        let i = 0;
        i < items.length;
        i++
      ) {
        const it =
          items[i] || {};

        await connection.query(
          `
          INSERT INTO invoice_items
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

          VALUES
          (
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?
          )
          `,
          [
            req.params.id,

            it.packageId ??
              it.package_id ??
              null,

            it.description || '',

            Number(
              it.qty || 1
            ),

            Number(
              it.rate || 0
            ),

            Number(
              it.tax ??
              it.taxPercent ??
              it.tax_percent ??
              0
            ),

            Number(
              it.discount ??
              it.discountAmount ??
              it.discount_amount ??
              0
            ),

            Number(
              it.amount || 0
            ),

            Number(
              it.paidAmount ??
              it.paid_amount ??
              0
            ),

            Number(
              it.pendingAmount ??
              it.pending_amount ??
              0
            ),

            i,
          ]
        );
      }

      // ------------------------------------------------------
      // PAYMENT HISTORY
      //
      // If payment increased, add only the NEW payment.
      // ------------------------------------------------------

      if (newPayment > 0) {
        await connection.query(
          `
          INSERT INTO invoice_payments
          (
            invoice_id,
            paid_date,
            total_amount,
            paid_total_amount,
            paid_amount,
            balanced_amount
          )

          VALUES
          (
            ?,
            ?,
            ?,
            ?,
            ?,
            ?
          )
          `,
          [
            req.params.id,

            invoiceDate ||
              new Date(),

            total,

            paid,

            newPayment,

            balance,
          ]
        );
      }

      await connection.commit();

      return res.json({
        success: true,
        message:
          'Invoice updated successfully',

        data: {
          id:
            Number(
              req.params.id
            ),

          invoiceNo:
            oldInvoice.invoice_no,

          status:
            derivedStatus,
        },
      });

    } catch (err) {
      if (connection) {
        try {
          await connection.rollback();
        } catch (_) {}
      }

      console.error(
        'PUT /invoices/:id ERROR:',
        err.message
      );

      return res.status(500).json({
        success: false,
        message: err.message,
      });

    } finally {
      if (connection) {
        connection.release();
      }
    }
  }
);


// ============================================================
// PATCH /api/invoices/:id/status
// ============================================================

router.patch(
  '/:id/status',
  async (req, res) => {

    const status =
      String(
        req.body.status || ''
      ).toUpperCase();

    if (
      !ALLOWED_STATUS.includes(
        status
      )
    ) {
      return res.status(400).json({
        success: false,
        message:
          `status must be one of ${ALLOWED_STATUS.join(', ')}`,
      });
    }

    try {
      const [result] =
        await db.query(
          `
          UPDATE invoices

          SET status = ?

          WHERE id = ?
          `,
          [
            status,
            req.params.id,
          ]
        );

      if (
        result.affectedRows === 0
      ) {
        return res.status(404).json({
          success: false,
          message:
            'Invoice not found',
        });
      }

      return res.json({
        success: true,
        message:
          'Status updated',
      });

    } catch (err) {
      console.error(
        'PATCH /invoices/:id/status ERROR:',
        err.message
      );

      return res.status(500).json({
        success: false,
        message: err.message,
      });
    }
  }
);


// ============================================================
// DELETE /api/invoices/:id
//
// Deletes:
//
// 1. invoice_items
// 2. invoice_payments
// 3. invoices
//
// Everything happens inside ONE transaction.
// ============================================================

router.delete(
  '/:id',
  async (req, res) => {

    const invoiceId =
      req.params.id;

    let connection;

    try {
      connection =
        await db.getConnection();

      await connection.beginTransaction();

      // ------------------------------------------------------
      // FIRST VERIFY INVOICE EXISTS
      // ------------------------------------------------------

      const [invoiceRows] =
        await connection.query(
          `
          SELECT
            id,
            invoice_no

          FROM invoices

          WHERE id = ?

          FOR UPDATE
          `,
          [invoiceId]
        );

      if (
        invoiceRows.length === 0
      ) {
        await connection.rollback();

        return res.status(404).json({
          success: false,
          message:
            'Invoice not found',
        });
      }

      const invoiceNo =
        invoiceRows[0].invoice_no;

      // ------------------------------------------------------
      // DELETE PAYMENT HISTORY
      // ------------------------------------------------------

      await connection.query(
        `
        DELETE FROM invoice_payments
        WHERE invoice_id = ?
        `,
        [invoiceId]
      );

      // ------------------------------------------------------
      // DELETE LINE ITEMS
      // ------------------------------------------------------

      await connection.query(
        `
        DELETE FROM invoice_items
        WHERE invoice_id = ?
        `,
        [invoiceId]
      );

      // ------------------------------------------------------
      // DELETE MAIN INVOICE
      // ------------------------------------------------------

      const [result] =
        await connection.query(
          `
          DELETE FROM invoices
          WHERE id = ?
          `,
          [invoiceId]
        );

      if (
        result.affectedRows === 0
      ) {
        await connection.rollback();

        return res.status(404).json({
          success: false,
          message:
            'Invoice not found',
        });
      }

      await connection.commit();

      return res.json({
        success: true,
        message:
          'Invoice and all related records deleted successfully',

        data: {
          id:
            Number(invoiceId),

          invoiceNo,
        },
      });

    } catch (err) {
      if (connection) {
        try {
          await connection.rollback();
        } catch (_) {}
      }

      console.error(
        'DELETE /invoices/:id ERROR:',
        err.message
      );

      // ------------------------------------------------------
      // Helpful FK error
      // ------------------------------------------------------

      if (
        err.code ===
        'ER_ROW_IS_REFERENCED_2'
      ) {
        return res.status(409).json({
          success: false,
          message:
            'Invoice cannot be deleted because another table still references this invoice.',
          errorCode:
            err.code,
        });
      }

      return res.status(500).json({
        success: false,
        message: err.message,
        errorCode:
          err.code || null,
      });

    } finally {
      if (connection) {
        connection.release();
      }
    }
  }
);


// ============================================================
// POST /api/invoices/generate-recurring
//
// Automatically creates next-cycle DRAFT invoices.
//
// IMPORTANT:
// Random invoice number removed.
//
// Uses same:
//
// monthly:
// INV-YYYYMM301
//
// generator.
// ============================================================

router.post(
  '/generate-recurring',
  authenticateToken,
  async (req, res) => {

    let connection;

    try {
      connection =
        await db.getConnection();

      await connection.beginTransaction();

      // ------------------------------------------------------
      // GET ALL INVOICES WITH MAINTENANCE DATE
      // ------------------------------------------------------

      const [invoices] =
        await connection.query(
          `
          SELECT *
          FROM invoices

          WHERE
            maintenance_date IS NOT NULL

            AND TRIM(
              maintenance_date
            ) != ''
          `
        );

      let createdCount = 0;

      // ------------------------------------------------------
      // PROCESS EACH INVOICE
      // ------------------------------------------------------

      for (
        const inv of invoices
      ) {

        const maintenanceDate =
          parseInvoiceDate(
            inv.maintenance_date
          );

        if (
          !maintenanceDate ||
          Number.isNaN(
            maintenanceDate.getTime()
          )
        ) {
          continue;
        }

        // ----------------------------------------------------
        // TODAY
        // ----------------------------------------------------

        const today =
          new Date();

        today.setHours(
          0,
          0,
          0,
          0
        );

        // ----------------------------------------------------
        // ONLY IF MAINTENANCE DATE PASSED
        // ----------------------------------------------------

        if (
          maintenanceDate >= today
        ) {
          continue;
        }

        // ----------------------------------------------------
        // NEXT MONTH
        // ----------------------------------------------------

        const nextMDate =
          new Date(
            maintenanceDate
          );

        nextMDate.setMonth(
          nextMDate.getMonth() + 1
        );

        const nextMDateStr =
          formatDDMMYYYY(
            nextMDate
          );

        // ----------------------------------------------------
        // CHECK EXISTING DRAFT
        //
        // Prevent duplicate recurring invoices.
        // ----------------------------------------------------

        const [
          existingDraft,
        ] =
          await connection.query(
            `
            SELECT
              id,
              invoice_no

            FROM invoices

            WHERE
              client_name = ?

              AND status = 'DRAFT'

              AND maintenance_date = ?

            LIMIT 1
            `,
            [
              inv.client_name,
              nextMDateStr,
            ]
          );

        if (
          existingDraft.length > 0
        ) {
          continue;
        }

        // ----------------------------------------------------
        // GENERATE REAL MONTHLY INVOICE NUMBER
        // ----------------------------------------------------

        const invoiceNo =
          await generateNextInvoiceNumber(
            connection,
            nextMDate,
            'monthly'
          );

        // ----------------------------------------------------
        // INSERT NEXT CYCLE INVOICE
        // ----------------------------------------------------

        const [result] =
          await connection.query(
            `
            INSERT INTO invoices
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
              notes,
              created_by
            )

            VALUES
            (
              ?,
              ?,
              ?,
              ?,
              ?,
              ?,
              ?,
              ?,
              ?,
              0,
              ?,
              'DRAFT',
              ?,
              ?
            )
            `,
            [
              invoiceNo,

              inv.client_name,

              nextMDateStr,

              nextMDateStr,

              inv.include_gst,

              inv.discount || 0,

              inv.subtotal || 0,

              inv.tax || 0,

              inv.total_amount || 0,

              inv.total_amount || 0,

              inv.notes || '',

              inv.created_by,
            ]
          );

        const newInvoiceId =
          result.insertId;

        // ----------------------------------------------------
        // COPY PREVIOUS INVOICE ITEMS
        // ----------------------------------------------------

        const [items] =
          await connection.query(
            `
            SELECT *

            FROM invoice_items

            WHERE invoice_id = ?

            ORDER BY
              sort_order ASC,
              id ASC
            `,
            [inv.id]
          );

        for (
          let i = 0;
          i < items.length;
          i++
        ) {
          const it =
            items[i];

          await connection.query(
            `
            INSERT INTO invoice_items
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

            VALUES
            (
              ?,
              ?,
              ?,
              ?,
              ?,
              ?,
              ?,
              ?,
              0,
              ?,
              ?
            )
            `,
            [
              newInvoiceId,

              it.package_id,

              it.description,

              it.qty,

              it.rate,

              it.tax_percent,

              it.discount_amount,

              it.amount,

              it.amount,

              i,
            ]
          );
        }

        createdCount++;
      }

      await connection.commit();

      return res.json({
        success: true,

        message:
          `Successfully generated ${createdCount} recurring draft invoice(s).`,

        createdCount,
      });

    } catch (err) {
      if (connection) {
        try {
          await connection.rollback();
        } catch (_) {}
      }

      console.error(
        'POST /invoices/generate-recurring ERROR:',
        err.message
      );

      return res.status(500).json({
        success: false,
        message: err.message,
      });

    } finally {
      if (connection) {
        connection.release();
      }
    }
  }
);


// ============================================================
// EXPORT ROUTER
// ============================================================
//
// generateNextInvoiceNumber is also exported so other routes
// (e.g. quotations.js converting an accepted quotation into an
// invoice) can reuse the SAME numbering logic instead of
// building their own invoice number by hand. This keeps the
// sequence (…301, 302, 303…) continuous no matter where an
// invoice is created from.
// ============================================================

module.exports = router;
module.exports.generateNextInvoiceNumber = generateNextInvoiceNumber;