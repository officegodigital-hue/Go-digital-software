'use strict';

// Admin-side client creation, employee assignment and provider assignment for
// the Client Report Management module. Uses the report-owned tables from
// lib/ensureReportClientSchema.js plus the existing client_profiles (logo) and
// client_full_report_history (report count / delete guard). Report-only: it
// never writes to the Task Manager's clients / task_assignments tables.

const db = require('../config/db');
const { isAdmin } = require('../lib/reportTaskAccess');
const { createNotification } = require('../routes/notifications');

// Best-effort notification; never fails the request it is attached to.
async function notify(senderName, recipientName, message) {
  if (!recipientName) return;
  try {
    await createNotification({
      senderName: senderName || 'Admin',
      recipientName,
      message,
    });
  } catch (error) {
    console.error('Report assignment notification failed:', error.message);
  }
}

function requireAdmin(req, res) {
  if (!isAdmin(req.user)) {
    res.status(403).json({
      success: false,
      message: 'Only report administrators can manage clients and assignments.',
    });
    return false;
  }
  return true;
}

function parseProviders(raw) {
  if (!raw) return [];
  try {
    const value = typeof raw === 'string' ? JSON.parse(raw) : raw;
    return Array.isArray(value)
      ? value.map((v) => String(v)).filter(Boolean)
      : [];
  } catch (_) {
    return [];
  }
}

// ── Assignable employees (dropdown) ─────────────────────────────────────────
async function listAssignableEmployees(req, res) {
  try {
    if (!requireAdmin(req, res)) return undefined;
    const [rows] = await db.query(
      `SELECT id, full_name AS name, user_type AS userType, role
       FROM employee_users
       WHERE COALESCE(is_active, 1) = 1
       ORDER BY full_name`,
    );
    return res.json({ success: true, employees: rows });
  } catch (error) {
    console.error('listAssignableEmployees error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to load employees.' });
  }
}

// ── List report clients (admin Clients card) ────────────────────────────────
async function listReportClients(req, res) {
  try {
    if (!requireAdmin(req, res)) return undefined;
    const [clients] = await db.query(
      `SELECT rc.company_name, rc.business_category, rc.created_at,
              cp.logo_data, cp.logo_mime_type,
              (SELECT COUNT(*) FROM client_full_report_history h
                 WHERE h.company_name = rc.company_name) AS report_count,
              (SELECT MAX(h.created_at) FROM client_full_report_history h
                 WHERE h.company_name = rc.company_name) AS last_report_at
       FROM report_clients rc
       LEFT JOIN client_profiles cp ON cp.company_name = rc.company_name
       ORDER BY rc.company_name`,
    );
    const [assignments] = await db.query(
      `SELECT company_name, employee_id, employee_name, providers, active, assigned_at
       FROM report_client_assignments
       ORDER BY assigned_at DESC`,
    );
    const byCompany = new Map();
    for (const a of assignments) {
      const list = byCompany.get(a.company_name) || [];
      list.push({
        employeeId: a.employee_id,
        employeeName: a.employee_name,
        providers: parseProviders(a.providers),
        active: a.active === 1,
        assignedAt: a.assigned_at,
      });
      byCompany.set(a.company_name, list);
    }
    const out = clients.map((c) => {
      const employees = byCompany.get(c.company_name) || [];
      const providers = [
        ...new Set(employees.filter((e) => e.active).flatMap((e) => e.providers)),
      ];
      return {
        companyName: c.company_name,
        businessCategory: c.business_category || '',
        reportCount: Number(c.report_count) || 0,
        lastReportAt: c.last_report_at,
        logoBase64: c.logo_data ? c.logo_data.toString('base64') : null,
        logoMimeType: c.logo_mime_type || null,
        employees,
        providers,
      };
    });
    return res.json({ success: true, clients: out });
  } catch (error) {
    console.error('listReportClients error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to load report clients.' });
  }
}

// ── Create / update a client (name, category, logo, assignments) ────────────
async function upsertReportClient(req, res) {
  try {
    if (!requireAdmin(req, res)) return undefined;
    const companyName = String(req.body?.companyName || '').trim();
    if (!companyName) {
      return res.status(422).json({ success: false, message: 'Company name is required.' });
    }
    const businessCategory = req.body?.businessCategory
      ? String(req.body.businessCategory).trim().slice(0, 255)
      : null;

    // Unique client name guard (case-insensitive) against a different existing row.
    const [existing] = await db.query(
      'SELECT id FROM report_clients WHERE LOWER(company_name) = LOWER(?) LIMIT 1',
      [companyName],
    );

    await db.query(
      `INSERT INTO report_clients (company_name, business_category, created_by_user_id)
       VALUES (?,?,?)
       ON DUPLICATE KEY UPDATE business_category = VALUES(business_category)`,
      [companyName.slice(0, 255), businessCategory, req.user?.id || null],
    );

    // Optional logo → stored in the shared client_profiles table.
    if (req.body?.logoBase64) {
      const logo = Buffer.from(String(req.body.logoBase64), 'base64');
      const mime = String(req.body?.logoMimeType || 'image/png').slice(0, 150);
      await db.query(
        `INSERT INTO client_profiles (company_name, logo_data, logo_mime_type)
         VALUES (?,?,?)
         ON DUPLICATE KEY UPDATE logo_data = VALUES(logo_data), logo_mime_type = VALUES(logo_mime_type)`,
        [companyName.slice(0, 255), logo, mime],
      );
    }

    // Optional full assignment replacement: [{employeeId, employeeName, providers[]}]
    if (Array.isArray(req.body?.assignments)) {
      await applyAssignments(companyName, req.body.assignments, req.user?.id || null);
    }

    return res.status(existing.length ? 200 : 201).json({ success: true, companyName });
  } catch (error) {
    console.error('upsertReportClient error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to save the client.' });
  }
}

// Replace the active assignment set for a client; deactivate ones not present.
async function applyAssignments(companyName, assignments, actorId) {
  const keepIds = [];
  for (const a of assignments) {
    const employeeId = Number(a?.employeeId);
    if (!Number.isSafeInteger(employeeId) || employeeId < 1) continue;
    const providers = JSON.stringify(parseProviders(a?.providers));
    const employeeName = a?.employeeName ? String(a.employeeName).slice(0, 255) : null;
    await db.query(
      `INSERT INTO report_client_assignments
         (company_name, employee_id, employee_name, providers, active, assigned_by_user_id, revoked_at)
       VALUES (?,?,?,?,1,?,NULL)
       ON DUPLICATE KEY UPDATE
         employee_name = VALUES(employee_name),
         providers = VALUES(providers),
         active = 1,
         assigned_by_user_id = VALUES(assigned_by_user_id),
         revoked_at = NULL`,
      [companyName, employeeId, employeeName, providers, actorId],
    );
    keepIds.push(employeeId);
  }
  // Deactivate assignments the admin removed (preserve the row for history).
  if (keepIds.length) {
    await db.query(
      `UPDATE report_client_assignments
         SET active = 0, revoked_at = NOW()
       WHERE company_name = ? AND active = 1
         AND employee_id NOT IN (${keepIds.map(() => '?').join(',')})`,
      [companyName, ...keepIds],
    );
  } else {
    await db.query(
      `UPDATE report_client_assignments SET active = 0, revoked_at = NOW()
       WHERE company_name = ? AND active = 1`,
      [companyName],
    );
  }
}

// ── Assign one employee (+providers) to an existing client ──────────────────
async function assignEmployee(req, res) {
  try {
    if (!requireAdmin(req, res)) return undefined;
    const companyName = String(req.body?.companyName || '').trim();
    const employeeId = Number(req.body?.employeeId);
    if (!companyName || !Number.isSafeInteger(employeeId) || employeeId < 1) {
      return res.status(422).json({ success: false, message: 'Company name and employee are required.' });
    }
    const [[client]] = await db.query(
      'SELECT id FROM report_clients WHERE company_name = ? LIMIT 1',
      [companyName],
    );
    if (!client) {
      return res.status(404).json({ success: false, message: 'Create the client before assigning employees.' });
    }
    const [[employee]] = await db.query(
      'SELECT full_name FROM employee_users WHERE id = ? LIMIT 1',
      [employeeId],
    );
    const providers = JSON.stringify(parseProviders(req.body?.providers));
    await db.query(
      `INSERT INTO report_client_assignments
         (company_name, employee_id, employee_name, providers, active, assigned_by_user_id, revoked_at)
       VALUES (?,?,?,?,1,?,NULL)
       ON DUPLICATE KEY UPDATE
         employee_name = VALUES(employee_name),
         providers = VALUES(providers),
         active = 1, assigned_by_user_id = VALUES(assigned_by_user_id), revoked_at = NULL`,
      [companyName, employeeId, employee?.full_name || null, providers, req.user?.id || null],
    );
    await notify(
      req.user?.name,
      employee?.full_name,
      `You have been assigned to ${companyName} for client reports.`,
    );
    return res.json({ success: true });
  } catch (error) {
    console.error('assignEmployee error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to assign the employee.' });
  }
}

// ── Revoke an employee assignment, optionally reassigning to another ────────
async function revokeAssignment(req, res) {
  try {
    if (!requireAdmin(req, res)) return undefined;
    const companyName = String(req.body?.companyName || '').trim();
    const employeeId = Number(req.body?.employeeId);
    const reassignTo = req.body?.reassignToEmployeeId
      ? Number(req.body.reassignToEmployeeId)
      : null;
    if (!companyName || !Number.isSafeInteger(employeeId) || employeeId < 1) {
      return res.status(422).json({ success: false, message: 'Company name and employee are required.' });
    }
    const [[current]] = await db.query(
      'SELECT providers, employee_name FROM report_client_assignments WHERE company_name = ? AND employee_id = ? LIMIT 1',
      [companyName, employeeId],
    );
    // Reassign preserves the client's provider assignment on the new employee.
    if (reassignTo && Number.isSafeInteger(reassignTo) && reassignTo > 0) {
      const [[employee]] = await db.query(
        'SELECT full_name FROM employee_users WHERE id = ? LIMIT 1',
        [reassignTo],
      );
      const providers = current ? current.providers : JSON.stringify([]);
      await db.query(
        `INSERT INTO report_client_assignments
           (company_name, employee_id, employee_name, providers, active, assigned_by_user_id, revoked_at)
         VALUES (?,?,?,?,1,?,NULL)
         ON DUPLICATE KEY UPDATE
           employee_name = VALUES(employee_name), providers = VALUES(providers),
           active = 1, assigned_by_user_id = VALUES(assigned_by_user_id), revoked_at = NULL`,
        [companyName, reassignTo, employee?.full_name || null, providers, req.user?.id || null],
      );
      await notify(
        req.user?.name,
        employee?.full_name,
        `You have been assigned to ${companyName} (reassigned) for client reports.`,
      );
    }
    // Deactivate the original assignment (history preserved).
    await db.query(
      `UPDATE report_client_assignments SET active = 0, revoked_at = NOW()
       WHERE company_name = ? AND employee_id = ?`,
      [companyName, employeeId],
    );
    await notify(
      req.user?.name,
      current?.employee_name,
      `Your assignment to ${companyName} for client reports has been revoked.`,
    );
    return res.json({ success: true });
  } catch (error) {
    console.error('revokeAssignment error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to revoke the assignment.' });
  }
}

// ── Delete a client — only when no report history exists ────────────────────
async function deleteReportClient(req, res) {
  try {
    if (!requireAdmin(req, res)) return undefined;
    const companyName = String(req.params.company || '').trim();
    if (!companyName) {
      return res.status(422).json({ success: false, message: 'Company name is required.' });
    }
    const [[history]] = await db.query(
      'SELECT COUNT(*) AS n FROM client_full_report_history WHERE company_name = ?',
      [companyName],
    );
    if (Number(history.n) > 0) {
      return res.status(409).json({
        success: false,
        message: 'This client has report history and cannot be deleted. Revoke or reassign the employee instead.',
      });
    }
    await db.query('DELETE FROM report_client_assignments WHERE company_name = ?', [companyName]);
    await db.query('DELETE FROM report_clients WHERE company_name = ?', [companyName]);
    return res.json({ success: true });
  } catch (error) {
    console.error('deleteReportClient error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to delete the client.' });
  }
}

module.exports = {
  listAssignableEmployees,
  listReportClients,
  upsertReportClient,
  assignEmployee,
  revokeAssignment,
  deleteReportClient,
};
