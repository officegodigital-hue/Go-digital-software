'use strict';

const db = require('../config/db');
const templates = require('../lib/workingDaysTemplates');

function ok(res, data, message) { return res.json({ success: true, message: message || 'OK', data }); }
function fail(res, status, message) { return res.status(status).json({ success: false, message }); }

async function list(req, res) { try { return ok(res, { items: await templates.list(true) }); } catch (e) { return fail(res, 500, e.message); } }
async function create(req, res) { try { return ok(res, await templates.create(req.body || {}, req.user && req.user.id), 'Working days template created'); } catch (e) { return fail(res, e.code === 'ER_DUP_ENTRY' ? 409 : 400, e.message); } }

async function update(req, res) {
  try {
    await templates.ensureTables();
    const id = Number(req.params.id);
    const [rows] = await db.query('SELECT * FROM hrms_working_day_templates WHERE id = ? AND is_archived = 0', [id]);
    if (!rows.length) return fail(res, 404, 'Template not found');
    const body = req.body || {};
    const name = String(body.name || rows[0].name).trim();
    const days = templates.normalizeDays(body.days);
    const [duplicate] = await db.query('SELECT id FROM hrms_working_day_templates WHERE LOWER(name) = LOWER(?) AND is_archived = 0 AND id <> ? LIMIT 1', [name, id]);
    if (duplicate.length) return fail(res, 409, 'An active template with this name already exists');
    const connection = await db.getConnection();
    try {
      await connection.beginTransaction();
      await connection.query('UPDATE hrms_working_day_templates SET is_archived = 1, updated_by = ? WHERE id = ?', [req.user && req.user.id, id]);
      const [result] = await connection.query('INSERT INTO hrms_working_day_templates (name, description, version, effective_from, created_by, updated_by) VALUES (?, ?, ?, COALESCE(?, CURDATE()), ?, ?)', [name, String(body.description || rows[0].description || '').trim() || null, Number(rows[0].version) + 1, body.effectiveFrom || null, req.user && req.user.id, req.user && req.user.id]);
      for (const day of days) await connection.query('INSERT INTO hrms_working_day_template_days (template_id, weekday, is_working, shift_start, shift_end, break_start, break_end) VALUES (?, ?, ?, ?, ?, ?, ?)', [result.insertId, day.weekday, day.isWorking, day.shiftStart, day.shiftEnd, day.breakStart, day.breakEnd]);
      await connection.commit();
      const after = { id: result.insertId, name, version: Number(rows[0].version) + 1, days };
      await templates.audit('working_day_template', result.insertId, 'version_created', { id, version: rows[0].version }, after, req.user && req.user.id);
      return ok(res, after, 'Working days template version created');
    } catch (e) { await connection.rollback(); throw e; } finally { connection.release(); }
  } catch (e) { return fail(res, e.code === 'ER_DUP_ENTRY' ? 409 : 400, e.message); }
}

async function archive(req, res) { try { await templates.ensureTables(); const id = Number(req.params.id); const [used] = await db.query('SELECT id FROM hrms_employee_working_day_assignments WHERE template_id = ? LIMIT 1', [id]); if (used.length) { await db.query('UPDATE hrms_working_day_templates SET is_archived = 1, updated_by = ? WHERE id = ?', [req.user && req.user.id, id]); return ok(res, { id, archived: true }, 'Template archived and retained for history'); } const [result] = await db.query('UPDATE hrms_working_day_templates SET is_archived = 1, updated_by = ? WHERE id = ?', [req.user && req.user.id, id]); if (!result.affectedRows) return fail(res, 404, 'Template not found'); return ok(res, { id, archived: true }, 'Template archived'); } catch (e) { return fail(res, 400, e.message); } }

async function employeeWorkingDays(req, res) {
  try {
    const profileId = Number(req.params.id); const date = String(req.query.date || new Date().toISOString().slice(0, 10));
    const assignment = await templates.assignmentFor(profileId, date);
    return ok(res, { type: assignment ? 'template' : 'standard', template: assignment, effectiveDate: date });
  } catch (e) { return fail(res, 500, e.message); }
}

module.exports = { list, create, update, archive, employeeWorkingDays };
