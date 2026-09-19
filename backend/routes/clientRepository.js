const express = require('express');
const db = require('../config/db');
const { authenticateToken } = require('./auth');
const router = express.Router();
router.use(authenticateToken);

function isAdmin(req) { return String(req.user.userType).toLowerCase() === 'admin'; }
function requireAdmin(req, res, next) {
  if (!isAdmin(req)) {
    return res.status(403).json({ success: false, message: 'Administrator access is required.' });
  }
  return next();
}
function isAccessEnforcementEnabled() {
  // During the merge, every signed-in local GoDigital user can verify the
  // original Assets UI and API. The final admin allocation phase enables this
  // gate in production (or explicitly with CLIENT_REPOSITORY_ACCESS_ENFORCED).
  return process.env.NODE_ENV === 'production' ||
    process.env.CLIENT_REPOSITORY_ACCESS_ENFORCED === 'true';
}
async function requireAccess(req, res, next) {
  if (isAdmin(req) || !isAccessEnforcementEnabled()) return next();
  const [rows] = await db.query('SELECT employee_id FROM client_repository_access WHERE employee_id = ?', [req.user.id]);
  if (!rows.length) return res.status(403).json({ success: false, message: 'Client Work Repository access has not been granted.' });
  next();
}

router.get('/summary', requireAccess, async (_req, res, next) => {
  try {
    const [[company]] = await db.query('SELECT COUNT(*) count FROM companies');
    const [[asset]] = await db.query('SELECT COUNT(*) count FROM assets');
    res.json({ success: true, data: { companies: company.count, assets: asset.count } });
  } catch (error) { next(error); }
});
router.get('/dashboard', requireAdmin, async (_req, res, next) => {
  try {
    const [[company]] = await db.query('SELECT COUNT(*) AS count FROM companies');
    const [[asset]] = await db.query('SELECT COUNT(*) AS count FROM assets');
    const [[user]] = await db.query('SELECT COUNT(*) AS count FROM employee_users WHERE is_active = 1');
    const [[shared]] = await db.query('SELECT COUNT(*) AS count FROM client_repository_access');
    res.json({ success: true, data: {
      companies: company.count,
      assets: asset.count,
      users: user.count,
      shared: shared.count,
    }});
  } catch (error) { next(error); }
});
router.get('/permissions/me', requireAccess, (_req, res) => {
  // Repository access is intentionally all-or-nothing. Once an administrator
  // grants it, the employee can use the complete Assets module.
  res.json({
    success: true,
    data: {
      can_view: true,
      can_download: true,
      can_create: true,
      can_edit: true,
      can_delete: true,
      can_create_company: true,
    },
  });
});
router.get('/companies', requireAccess, async (_req, res, next) => {
  try {
    const [rows] = await db.query(`
      SELECT c.id, c.name, c.logo_url, c.is_active,
        COALESCE(GROUP_CONCAT(DISTINCT cs.section SEPARATOR '|'), '') AS sections
      FROM companies c
      LEFT JOIN company_sections cs ON cs.company_id = c.id
      GROUP BY c.id, c.name, c.logo_url, c.is_active
      ORDER BY c.name
    `);
    res.json({
      success: true,
      data: rows.map((row) => ({
        ...row,
        sections: row.sections ? row.sections.split('|') : [],
      })),
    });
  } catch (error) { next(error); }
});
router.get('/assets', requireAccess, async (_req, res, next) => {
  try {
    const [rows] = await db.query(`
      SELECT id, company_id, company_name, section, type, name, description,
             link, file_url, file_name, mime_type, file_size, created_at
      FROM assets
      ORDER BY created_at DESC
    `);
    res.json({ success: true, data: rows });
  } catch (error) { next(error); }
});
// Original Assets admin pages use these dynamic GoDigital resources.
router.get('/users', requireAdmin, async (_req, res, next) => {
  try {
    const [rows] = await db.query(`
      SELECT id, full_name AS name, email, role, user_type AS role_type,
             is_active, staff_id, initials
      FROM employee_users
      ORDER BY full_name
    `);
    res.json({ success: true, data: rows });
  } catch (error) { next(error); }
});
router.get('/permissions', requireAdmin, async (_req, res, next) => {
  try {
    const [rows] = await db.query(`
      SELECT e.id AS user_id, e.full_name AS user_name, e.email, e.role,
             a.employee_id IS NOT NULL AS can_view,
             a.employee_id IS NOT NULL AS can_create,
             a.employee_id IS NOT NULL AS can_edit,
             a.employee_id IS NOT NULL AS can_delete,
             a.employee_id IS NOT NULL AS can_download,
             a.employee_id IS NOT NULL AS can_create_company
      FROM employee_users e
      LEFT JOIN client_repository_access a ON a.employee_id = e.id
      WHERE e.is_active = 1
      ORDER BY e.full_name
    `);
    res.json({ success: true, data: rows });
  } catch (error) { next(error); }
});
router.get('/downloads', requireAdmin, async (_req, res, next) => {
  try {
    const [rows] = await db.query(`
      SELECT d.id, d.downloaded_at AS created_at, a.name AS asset_name,
             a.file_name, a.type AS asset_type, a.section,
             c.name AS company_name, e.full_name AS user_name, e.email AS user_email
      FROM asset_downloads d
      JOIN assets a ON a.id = d.asset_id
      JOIN companies c ON c.id = a.company_id
      JOIN employee_users e ON e.id = d.employee_id
      ORDER BY d.downloaded_at DESC
    `);
    res.json({ success: true, data: rows });
  } catch (error) { next(error); }
});
router.get('/access', async (req, res, next) => {
  if (!isAdmin(req)) return res.sendStatus(403);
  try { const [rows] = await db.query('SELECT e.id, e.full_name, e.staff_id, a.employee_id IS NOT NULL AS has_access FROM employee_users e LEFT JOIN client_repository_access a ON a.employee_id=e.id ORDER BY e.full_name'); res.json({ success: true, data: rows }); } catch (error) { next(error); }
});
router.put('/access/:employeeId', async (req, res, next) => {
  if (!isAdmin(req)) return res.sendStatus(403);
  try { if (req.body.granted) await db.query('INSERT IGNORE INTO client_repository_access (employee_id, granted_by) VALUES (?,?)', [req.params.employeeId, req.user.id]); else await db.query('DELETE FROM client_repository_access WHERE employee_id=?', [req.params.employeeId]); res.json({ success: true }); } catch (error) { next(error); }
});
module.exports = router;
