const db = require('../config/db');
const { ensureCalendarOverrideTables } = require('../lib/calendarOverrides');

function ok(res, data) { return res.json({ success: true, message: 'OK', data }); }
function fail(res, status, message) { return res.status(status).json({ success: false, message }); }

async function mine(req, res) {
  try {
    await ensureCalendarOverrideTables();
    const [rows] = await db.query(`SELECT id, override_id AS overrideId, title, message, is_read AS isRead,
      read_at AS readAt, created_at AS createdAt
      FROM hrms_employee_calendar_notifications WHERE employee_id=? ORDER BY created_at DESC LIMIT 100`, [req.user.id]);
    return ok(res, { items: rows, unreadCount: rows.filter((row) => !Number(row.isRead)).length });
  } catch (error) { return fail(res, 500, error.message); }
}

async function markRead(req, res) {
  try {
    const id = Number(req.params.id);
    if (!Number.isInteger(id) || id < 1) return fail(res, 400, 'A valid notification is required');
    await ensureCalendarOverrideTables();
    const [result] = await db.query(`UPDATE hrms_employee_calendar_notifications
      SET is_read=1, read_at=COALESCE(read_at, CURRENT_TIMESTAMP) WHERE id=? AND employee_id=?`, [id, req.user.id]);
    if (!result.affectedRows) return fail(res, 404, 'Notification not found');
    return ok(res, { id, isRead: true });
  } catch (error) { return fail(res, 500, error.message); }
}

module.exports = { mine, markRead };
