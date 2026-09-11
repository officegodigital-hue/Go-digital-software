// routes/daily-reports.js
// ✅ COMPLETE API ROUTES FOR DAILY REPORTS

const express = require('express');
const router = express.Router();
const db = require('../config/db');
const { authenticateToken } = require('./auth'); // Your auth middleware

// ============================================
// ✅ 1. GET ALL REPORTS FOR LOGGED-IN EMPLOYEE
// ============================================
router.get('/', authenticateToken, async (req, res) => {
  try {
    const employeeId = req.user.id;

    console.log(`📋 [GET /daily-reports] Employee ID: ${employeeId}`);

    const [reports] = await db.query(
      `SELECT 
        id,
        employee_id,
        client,
        report,
        DATE_FORMAT(submission_date, '%d/%m/%Y') as submissionDate,
        status,
        created_at,
        updated_at
       FROM daily_reports
       WHERE employee_id = ?
       ORDER BY created_at DESC`,
      [employeeId]
    );

    console.log(`✅ Found ${reports.length} reports`);

    return res.json({
      success: true,
      data: reports,
      message: `Retrieved ${reports.length} reports`,
    });
  } catch (err) {
    console.error('❌ GET /daily-reports ERROR:', err.message);
    return res.status(500).json({
      success: false,
      message: 'Error fetching reports',
      error: err.message,
    });
  }
});

// ============================================
// ✅ 2. GET SINGLE REPORT BY ID
// ============================================
router.get('/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const employeeId = req.user.id;

    console.log(`📋 [GET /daily-reports/:id] Report ID: ${id}, Employee: ${employeeId}`);

    const [reports] = await db.query(
      `SELECT 
        id,
        employee_id,
        client,
        report,
        DATE_FORMAT(submission_date, '%d/%m/%Y') as submissionDate,
        status,
        created_at
       FROM daily_reports
       WHERE id = ? AND employee_id = ?`,
      [id, employeeId]
    );

    if (reports.length === 0) {
      console.log('⚠️ Report not found or access denied');
      return res.status(404).json({
        success: false,
        message: 'Report not found',
      });
    }

    console.log('✅ Report found');
    return res.json({
      success: true,
      data: reports[0],
    });
  } catch (err) {
    console.error('❌ GET /daily-reports/:id ERROR:', err.message);
    return res.status(500).json({
      success: false,
      message: 'Error fetching report',
      error: err.message,
    });
  }
});

// ============================================
// ✅ 3. CREATE NEW REPORT
// ============================================
router.post('/', authenticateToken, async (req, res) => {
  try {
    const { client, report, submissionDate, status = 'DONE' } = req.body;
    const employeeId = req.user.id;

    console.log(`➕ [POST /daily-reports] Creating report for employee: ${employeeId}`);

    // Validation
    if (!client || !report || !submissionDate) {
      console.log('⚠️ Missing required fields');
      return res.status(400).json({
        success: false,
        message: 'Client, report, and submission date are required',
      });
    }

    // Convert date format: dd/MM/yyyy → YYYY-MM-DD
    const [day, month, year] = submissionDate.split('/');
    const dbDate = `${year}-${month}-${day}`;

    console.log(`📅 Date conversion: ${submissionDate} → ${dbDate}`);

    const [result] = await db.query(
      `INSERT INTO daily_reports 
        (employee_id, client, report, submission_date, status)
       VALUES (?, ?, ?, ?, ?)`,
      [employeeId, client, report, dbDate, status]
    );

    console.log(`✅ Report created with ID: ${result.insertId}`);

    return res.status(201).json({
      success: true,
      message: 'Report created successfully',
      data: {
        id: result.insertId,
        employee_id: employeeId,
        client,
        report,
        submissionDate,
        status,
      },
    });
  } catch (err) {
    console.error('❌ POST /daily-reports ERROR:', err.message);
    return res.status(500).json({
      success: false,
      message: 'Error creating report',
      error: err.message,
    });
  }
});

// ============================================
// ✅ 4. UPDATE EXISTING REPORT
// ============================================
router.put('/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { client, report, submissionDate, status = 'DONE' } = req.body;
    const employeeId = req.user.id;

    console.log(`✏️ [PUT /daily-reports/:id] Updating report ID: ${id}`);

    // Validation
    if (!client || !report || !submissionDate) {
      console.log('⚠️ Missing required fields');
      return res.status(400).json({
        success: false,
        message: 'Client, report, and submission date are required',
      });
    }

    // Check if report exists and belongs to employee
    const [existing] = await db.query(
      'SELECT id FROM daily_reports WHERE id = ? AND employee_id = ?',
      [id, employeeId]
    );

    if (existing.length === 0) {
      console.log('⚠️ Report not found or access denied');
      return res.status(404).json({
        success: false,
        message: 'Report not found or you do not have permission',
      });
    }

    // Convert date format: dd/MM/yyyy → YYYY-MM-DD
    const [day, month, year] = submissionDate.split('/');
    const dbDate = `${year}-${month}-${day}`;

    await db.query(
      `UPDATE daily_reports
       SET client = ?, report = ?, submission_date = ?, status = ?
       WHERE id = ? AND employee_id = ?`,
      [client, report, dbDate, status, id, employeeId]
    );

    console.log(`✅ Report updated successfully`);

    return res.json({
      success: true,
      message: 'Report updated successfully',
      data: {
        id: parseInt(id),
        employee_id: employeeId,
        client,
        report,
        submissionDate,
        status,
      },
    });
  } catch (err) {
    console.error('❌ PUT /daily-reports/:id ERROR:', err.message);
    return res.status(500).json({
      success: false,
      message: 'Error updating report',
      error: err.message,
    });
  }
});

// ============================================
// ✅ 5. DELETE REPORT
// ============================================
router.delete('/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const employeeId = req.user.id;

    console.log(`🗑️ [DELETE /daily-reports/:id] Deleting report ID: ${id}`);

    // Check if report exists and belongs to employee
    const [existing] = await db.query(
      'SELECT id FROM daily_reports WHERE id = ? AND employee_id = ?',
      [id, employeeId]
    );

    if (existing.length === 0) {
      console.log('⚠️ Report not found or access denied');
      return res.status(404).json({
        success: false,
        message: 'Report not found or you do not have permission',
      });
    }

    await db.query(
      'DELETE FROM daily_reports WHERE id = ? AND employee_id = ?',
      [id, employeeId]
    );

    console.log(`✅ Report deleted successfully`);

    return res.json({
      success: true,
      message: 'Report deleted successfully',
    });
  } catch (err) {
    console.error('❌ DELETE /daily-reports/:id ERROR:', err.message);
    return res.status(500).json({
      success: false,
      message: 'Error deleting report',
      error: err.message,
    });
  }
});

// ============================================
// ✅ 6. FILTER REPORTS BY DATE
// ============================================
router.get('/filter/by-date', authenticateToken, async (req, res) => {
  try {
    const { date } = req.query;
    const employeeId = req.user.id;

    if (!date) {
      return res.status(400).json({
        success: false,
        message: 'Date query parameter is required (format: dd/MM/yyyy)',
      });
    }

    console.log(`🔍 [GET /filter/by-date] Filtering by date: ${date}`);

    // Convert date format: dd/MM/yyyy → YYYY-MM-DD
    const [day, month, year] = date.split('/');
    const dbDate = `${year}-${month}-${day}`;

    const [reports] = await db.query(
      `SELECT 
        id,
        employee_id,
        client,
        report,
        DATE_FORMAT(submission_date, '%d/%m/%Y') as submissionDate,
        status,
        created_at
       FROM daily_reports
       WHERE employee_id = ? AND submission_date = ?
       ORDER BY created_at DESC`,
      [employeeId, dbDate]
    );

    console.log(`✅ Found ${reports.length} reports for date: ${dbDate}`);

    return res.json({
      success: true,
      data: reports,
    });
  } catch (err) {
    console.error('❌ GET /filter/by-date ERROR:', err.message);
    return res.status(500).json({
      success: false,
      message: 'Error filtering reports',
      error: err.message,
    });
  }
});

// ============================================
// ✅ 7. SEARCH REPORTS
// ============================================
router.get('/search/:query', authenticateToken, async (req, res) => {
  try {
    const { query } = req.params;
    const employeeId = req.user.id;

    console.log(`🔍 [GET /search/:query] Search query: ${query}`);

    const [reports] = await db.query(
      `SELECT 
        id,
        employee_id,
        client,
        report,
        DATE_FORMAT(submission_date, '%d/%m/%Y') as submissionDate,
        status,
        created_at
       FROM daily_reports
       WHERE employee_id = ? 
       AND (client LIKE ? OR report LIKE ?)
       ORDER BY created_at DESC`,
      [employeeId, `%${query}%`, `%${query}%`]
    );

    console.log(`✅ Found ${reports.length} matching reports`);

    return res.json({
      success: true,
      data: reports,
    });
  } catch (err) {
    console.error('❌ GET /search/:query ERROR:', err.message);
    return res.status(500).json({
      success: false,
      message: 'Error searching reports',
      error: err.message,
    });
  }
});

module.exports = router;