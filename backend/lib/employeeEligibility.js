const db = require('../config/db');

const NAME_FIELDS = new Set(['employee', 'employeeName', 'employee_name', 'designer', 'videographer', 'videoEditor',
  'video_editor', 'websiteDesigner', 'website_designer', 'uiUxDesigner', 'ui_ux_designer', 'developer',
  'adsHandling', 'ads_handling', 'pageHandling', 'page_handling', 'assignedTo', 'assigned_to_name',
  'recipientName', 'recipient_name', 'selectedPersons', 'members', 'assignees', 'assignedEmployees']);
const ID_FIELDS = new Set(['employeeId', 'employee_id', 'employeeUserId', 'employee_user_id', 'assigned_to_id', 'assigned_to', 'cc_assigned_to_id']);

async function assertActive(value, executor = db) {
  const byId = typeof value === 'number' || /^\d+$/.test(String(value));
  const [users] = await executor.query(`SELECT id,full_name,is_active FROM employee_users${byId ? ' WHERE id=?' : ''}`, byId ? [value] : []);
  const normalize=name=>String(name || '').toLowerCase().replace(/[^a-z0-9]/g,'');
  if (users.some(u => (byId || normalize(u.full_name)===normalize(value)) && !Number(u.is_active))) throw Object.assign(new Error('Inactive employees cannot participate in new live work'), { status: 409 });
}
async function checkBody(body, field = '') {
  if (Array.isArray(body)) { for (const value of body) await checkBody(value, field); return; }
  if (body && typeof body === 'object') {
    for (const [key, value] of Object.entries(body)) await checkBody(value, key);
    return;
  }
  if (!body || (!NAME_FIELDS.has(field) && !ID_FIELDS.has(field))) return;
  const values = NAME_FIELDS.has(field) ? String(body).split(/,|&|\/|\band\b/i) : [body];
  for (const value of values) if (String(value).trim()) await assertActive(String(value).trim());
}

async function liveWriteGuard(req, res, next) {
  if (['GET', 'HEAD', 'OPTIONS'].includes(req.method)) return next();
  // History/corrections and lifecycle operations intentionally accept inactive identities.
  if (!/^\/(tasks|task-list|tracking-items|employee-tasks|content-calendar|workspace-tasks|task-planner|videographer-planner|day-planner|chat|invoices)(\/|$)/.test(req.path)) return next();
  try {
    await checkBody(req.body);
    next();
  }
  catch (error) { res.status(error.status || 503).json({ success: false, message: error.message }); }
}
module.exports = { assertActive, checkBody, liveWriteGuard };
