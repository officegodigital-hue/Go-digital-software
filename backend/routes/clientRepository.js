const express = require('express');
const multer = require('multer');
const fs = require('fs');
const path = require('path');
const db = require('../config/db');
const { authenticateToken } = require('./auth');

const router = express.Router();
const uploadDir = path.join(__dirname, '..', 'uploads', 'client-repository');
fs.mkdirSync(uploadDir, { recursive: true });
const upload = multer({
  storage: multer.diskStorage({
    destination: (_req, _file, done) => done(null, uploadDir),
    filename: (_req, file, done) => done(null, `${Date.now()}-${Math.round(Math.random() * 1e9)}-${path.basename(file.originalname || 'file').replace(/[^a-zA-Z0-9._-]/g, '_')}`),
  }),
  limits: { fileSize: 25 * 1024 * 1024 },
});

router.use(authenticateToken);
const permissions = ['can_view', 'can_create', 'can_edit', 'can_delete', 'can_download', 'can_create_company'];
const allPermissions = () => Object.fromEntries(permissions.map((key) => [key, true]));
const isAdmin = (req) => String(req.user?.userType || '').toLowerCase() === 'admin';
const requireAdmin = (req, res, next) => isAdmin(req) ? next() : res.status(403).json({ success: false, message: 'Administrator access is required.' });

async function readPermissions(req) {
  if (isAdmin(req)) return allPermissions();
  const [[row]] = await db.query(`SELECT ${permissions.join(', ')} FROM client_repository_access WHERE employee_id=?`, [req.user.id]);
  return row || Object.fromEntries(permissions.map((key) => [key, false]));
}
function requirePermission(key) {
  return async (req, res, next) => {
    try {
      if (!(await readPermissions(req))[key]) return res.status(403).json({ success: false, message: 'You do not have permission for this Client Repository action.' });
      return next();
    } catch (error) { return next(error); }
  };
}
const uploadUrl = (file) => file ? `/uploads/client-repository/${file.filename}` : null;
const removeUpload = (file) => file?.path && fs.unlink(file.path, () => {});
async function companyById(id) { const [[row]] = await db.query('SELECT id, name, logo_url, is_active FROM companies WHERE id=?', [id]); return row; }
async function assetById(id) { const [[row]] = await db.query('SELECT * FROM assets WHERE id=?', [id]); return row; }
async function replaceSections(companyId, input) {
  if (input === undefined) return;
  const sections = String(input || '').split(/[|,]/).map((item) => item.trim()).filter(Boolean);
  await db.query('DELETE FROM company_sections WHERE company_id=?', [companyId]);
  if (sections.length) await db.query('INSERT INTO company_sections (company_id, section) VALUES ?', [sections.map((section) => [companyId, section])]);
}

router.get('/summary', requirePermission('can_view'), async (_req, res, next) => {
  try {
    const [[companies]] = await db.query('SELECT COUNT(*) AS count FROM companies WHERE is_active=1');
    const [[assets]] = await db.query('SELECT COUNT(*) AS count FROM assets');
    res.json({ success: true, data: { companies: companies.count, assets: assets.count } });
  } catch (error) { next(error); }
});
router.get('/dashboard', requireAdmin, async (_req, res, next) => {
  try {
    const [[companies]] = await db.query('SELECT COUNT(*) AS count FROM companies WHERE is_active=1');
    const [[assets]] = await db.query('SELECT COUNT(*) AS count FROM assets');
    const [[users]] = await db.query('SELECT COUNT(*) AS count FROM employee_users WHERE is_active=1');
    const [[shared]] = await db.query('SELECT COUNT(*) AS count FROM client_repository_access WHERE can_view=1');
    res.json({ success: true, data: { companies: companies.count, assets: assets.count, users: users.count, shared: shared.count } });
  } catch (error) { next(error); }
});
router.get('/permissions/me', async (req, res, next) => { try { res.json({ success: true, data: await readPermissions(req) }); } catch (error) { next(error); } });
// One authoritative profile endpoint for the repository shell.  It always
// reads the signed-in employee from the database, so headers never depend on
// stale browser preferences or a hardcoded Admin/User label.
router.get('/profile/me', async (req, res, next) => {
  try {
    const [[profile]] = await db.query(`SELECT id, full_name AS name, email, mobile, role, user_type,
      initials, profile_photo_url FROM employee_users WHERE id=? AND is_active=1`, [req.user.id]);
    if (!profile) return res.status(404).json({ success: false, message: 'Current user profile was not found.' });
    res.json({ success: true, data: profile });
  } catch (error) { next(error); }
});
router.put('/profile/me', async (req, res, next) => {
  try {
    const name = String(req.body.name || '').trim();
    const email = String(req.body.email || '').trim().toLowerCase();
    const mobile = String(req.body.mobile || '').trim();
    if (!name || !email) return res.status(400).json({ success: false, message: 'Name and email are required.' });
    if (!email.includes('@')) return res.status(400).json({ success: false, message: 'Enter a valid email address.' });
    const user = userNameParts(name);
    await db.query(`UPDATE employee_users SET first_name=?,last_name=?,full_name=?,initials=?,email=?,mobile=? WHERE id=?`,
      [user.firstName, user.lastName, user.fullName, user.initials, email, mobile || null, req.user.id]);
    // Attendance and HRMS use this linked profile.  Keep it in sync with the
    // one employee_users source record used by tasks and Client Repository.
    await db.query('UPDATE hrms_employee_profiles SET full_name=?,email=? WHERE employee_user_id=?', [user.fullName, email, req.user.id]);
    const [[profile]] = await db.query(`SELECT id, full_name AS name, email, mobile, role, user_type,
      initials, profile_photo_url FROM employee_users WHERE id=?`, [req.user.id]);
    res.json({ success: true, data: profile });
  } catch (error) { next(error); }
});

router.get('/companies', requirePermission('can_view'), async (_req, res, next) => {
  try {
    const [rows] = await db.query(`SELECT c.id,c.name,c.logo_url,c.is_active,COALESCE(GROUP_CONCAT(DISTINCT cs.section SEPARATOR '|'),'') AS sections
      FROM companies c LEFT JOIN company_sections cs ON cs.company_id=c.id GROUP BY c.id,c.name,c.logo_url,c.is_active ORDER BY c.name`);
    res.json({ success: true, data: rows.map((row) => ({ ...row, sections: row.sections ? row.sections.split('|') : [] })) });
  } catch (error) { next(error); }
});
router.post('/companies', requirePermission('can_create_company'), upload.single('logo'), async (req, res, next) => {
  try {
    const name = String(req.body.name || '').trim();
    if (!name) { removeUpload(req.file); return res.status(400).json({ success: false, message: 'Company name is required.' }); }
    const [result] = await db.query('INSERT INTO companies (name,logo_url) VALUES (?,?)', [name, uploadUrl(req.file)]);
    await replaceSections(result.insertId, req.body.section);
    res.status(201).json({ success: true, data: await companyById(result.insertId) });
  } catch (error) { removeUpload(req.file); next(error); }
});
router.put('/companies/:id', requirePermission('can_edit'), upload.single('logo'), async (req, res, next) => {
  try {
    const company = await companyById(req.params.id);
    if (!company) { removeUpload(req.file); return res.status(404).json({ success: false, message: 'Company not found.' }); }
    const name = String(req.body.name || company.name).trim();
    await db.query('UPDATE companies SET name=?,logo_url=? WHERE id=?', [name, uploadUrl(req.file) || company.logo_url, company.id]);
    await replaceSections(company.id, req.body.section);
    res.json({ success: true, data: await companyById(company.id) });
  } catch (error) { removeUpload(req.file); next(error); }
});
router.delete('/companies/:id', requirePermission('can_delete'), async (req, res, next) => {
  try { const company = await companyById(req.params.id); if (!company) return res.status(404).json({ success: false, message: 'Company not found.' }); await db.query('DELETE FROM companies WHERE id=?', [company.id]); res.json({ success: true }); } catch (error) { next(error); }
});

router.get('/assets', requirePermission('can_view'), async (_req, res, next) => {
  try { const [rows] = await db.query('SELECT id,company_id,company_name,section,type,name,description,link,username,password,file_url,file_name,mime_type,file_size,created_by_employee_id,created_at,updated_at FROM assets ORDER BY created_at DESC'); res.json({ success: true, data: rows }); } catch (error) { next(error); }
});
router.post('/assets', requirePermission('can_create'), upload.single('file'), async (req, res, next) => {
  try {
    const company = await companyById(req.body.company_id); const name = String(req.body.name || '').trim();
    if (!company || !name) { removeUpload(req.file); return res.status(400).json({ success: false, message: 'A valid company and asset name are required.' }); }
    const [result] = await db.query(`INSERT INTO assets (company_id,company_name,section,type,name,description,link,username,password,file_url,file_name,mime_type,file_size,created_by_employee_id)
      VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)`, [company.id, company.name, req.body.section || null, req.body.type || null, name, req.body.description || null, req.body.link || null, req.body.username || null, req.body.password || null, uploadUrl(req.file), req.file?.originalname || null, req.file?.mimetype || null, req.file?.size || null, req.user.id]);
    res.status(201).json({ success: true, data: await assetById(result.insertId) });
  } catch (error) { removeUpload(req.file); next(error); }
});
router.put('/assets/:id', requirePermission('can_edit'), upload.single('file'), async (req, res, next) => {
  try {
    const asset = await assetById(req.params.id); const company = await companyById(req.body.company_id || asset?.company_id);
    if (!asset || !company) { removeUpload(req.file); return res.status(404).json({ success: false, message: 'Asset or company not found.' }); }
    await db.query(`UPDATE assets SET company_id=?,company_name=?,section=?,type=?,name=?,description=?,link=?,username=?,password=?,file_url=?,file_name=?,mime_type=?,file_size=? WHERE id=?`,
      [company.id, company.name, req.body.section ?? asset.section, req.body.type ?? asset.type, req.body.name ?? asset.name, req.body.description ?? asset.description, req.body.link ?? asset.link, req.body.username ?? asset.username, req.body.password ?? asset.password, uploadUrl(req.file) || asset.file_url, req.file?.originalname || asset.file_name, req.file?.mimetype || asset.mime_type, req.file?.size || asset.file_size, asset.id]);
    res.json({ success: true, data: await assetById(asset.id) });
  } catch (error) { removeUpload(req.file); next(error); }
});
router.delete('/assets/:id', requirePermission('can_delete'), async (req, res, next) => {
  try { const asset = await assetById(req.params.id); if (!asset) return res.status(404).json({ success: false, message: 'Asset not found.' }); await db.query('DELETE FROM assets WHERE id=?', [asset.id]); res.json({ success: true }); } catch (error) { next(error); }
});
router.get('/assets/:id/file', requirePermission('can_download'), async (req, res, next) => {
  try {
    const asset = await assetById(req.params.id);
    if (!asset?.file_url) return res.status(404).json({ success: false, message: 'This asset does not have an uploaded file.' });
    const filePath = path.resolve(__dirname, '..', asset.file_url.replace(/^\//, ''));
    if (!filePath.startsWith(uploadDir) || !fs.existsSync(filePath)) return res.status(404).json({ success: false, message: 'The uploaded file is unavailable.' });
    await db.query('INSERT INTO asset_downloads (asset_id,employee_id) VALUES (?,?)', [asset.id, req.user.id]);
    return res.download(filePath, asset.file_name || path.basename(filePath));
  } catch (error) { return next(error); }
});

function userNameParts(value) {
  const words = String(value || '').trim().split(/\s+/).filter(Boolean);
  const firstName = words[0] || 'User';
  const lastName = words.slice(1).join(' ') || firstName;
  return { firstName, lastName, fullName: words.join(' ') || firstName, initials: `${firstName[0]}${lastName[0]}`.toUpperCase() };
}
router.get('/users', requireAdmin, async (_req, res, next) => { try { const [rows] = await db.query('SELECT id,full_name AS name,email,mobile,role,user_type AS role_type,is_active,staff_id,initials,profile_photo_url FROM employee_users ORDER BY full_name'); res.json({ success: true, data: rows }); } catch (error) { next(error); } });
router.post('/users', requireAdmin, async (req, res, next) => {
  try {
    const email = String(req.body.email || '').trim().toLowerCase();
    const password = String(req.body.password || '');
    if (!email || !password) return res.status(400).json({ success: false, message: 'Email and password are required.' });
    const user = userNameParts(req.body.name);
    const role = String(req.body.role || 'User');
    const userType = role.toLowerCase() === 'admin' ? 'admin' : 'employee';
    const username = `${email.split('@')[0].replace(/[^a-z0-9._-]/gi, '') || 'user'}${Date.now().toString().slice(-5)}`;
    const staffId = `CR-${Date.now()}`;
    const [result] = await db.query(`INSERT INTO employee_users (first_name,last_name,full_name,initials,staff_id,email,username,password,mobile,role,user_type,is_active) VALUES (?,?,?,?,?,?,?,?,?,?,?,1)`, [user.firstName, user.lastName, user.fullName, user.initials, staffId, email, username, password, req.body.mobile || null, role, userType]);
    const [[created]] = await db.query('SELECT id,full_name AS name,email,mobile,role,user_type AS role_type,is_active,staff_id,initials FROM employee_users WHERE id=?', [result.insertId]);
    res.status(201).json({ success: true, data: created });
  } catch (error) { next(error); }
});
router.put('/users/:id', requireAdmin, async (req, res, next) => {
  try {
    const user = userNameParts(req.body.name);
    const values = [user.firstName, user.lastName, user.fullName, user.initials, String(req.body.email || '').trim().toLowerCase(), req.body.mobile || null, req.body.role || 'User'];
    let sql = 'UPDATE employee_users SET first_name=?,last_name=?,full_name=?,initials=?,email=?,mobile=?,role=?';
    if (req.body.password) { sql += ',password=?'; values.push(req.body.password); }
    sql += ' WHERE id=?'; values.push(req.params.id);
    const [result] = await db.query(sql, values);
    if (!result.affectedRows) return res.status(404).json({ success: false, message: 'User not found.' });
    const [[updated]] = await db.query('SELECT id,full_name AS name,email,mobile,role,user_type AS role_type,is_active,staff_id,initials FROM employee_users WHERE id=?', [req.params.id]);
    res.json({ success: true, data: updated });
  } catch (error) { next(error); }
});
router.put('/users/:id/status', requireAdmin, async (req, res, next) => { try { await db.query('UPDATE employee_users SET is_active=? WHERE id=?', [req.body.is_active ? 1 : 0, req.params.id]); res.json({ success: true }); } catch (error) { next(error); } });
router.delete('/users/:id', requireAdmin, async (req, res, next) => { try { await db.query('DELETE FROM employee_users WHERE id=?', [req.params.id]); res.json({ success: true }); } catch (error) { next(error); } });
router.post('/users/me/photo', upload.single('photo'), async (req, res, next) => {
  try {
    if (!req.file) return res.status(400).json({ success: false, message: 'A profile photo is required.' });
    const profilePhotoUrl = uploadUrl(req.file);
    await db.query('UPDATE employee_users SET profile_photo_url=? WHERE id=?', [profilePhotoUrl, req.user.id]);
    res.json({ success: true, data: { profile_photo_url: profilePhotoUrl } });
  } catch (error) { removeUpload(req.file); next(error); }
});
router.delete('/users/me/photo', async (req, res, next) => {
  try {
    const [[profile]] = await db.query('SELECT profile_photo_url FROM employee_users WHERE id=?', [req.user.id]);
    if (!profile) return res.status(404).json({ success: false, message: 'Current user profile was not found.' });

    await db.query('UPDATE employee_users SET profile_photo_url=NULL WHERE id=?', [req.user.id]);

    const storedUrl = String(profile.profile_photo_url || '');
    if (storedUrl) {
      const storedPath = path.resolve(__dirname, '..', storedUrl.replace(/^\//, ''));
      if (storedPath.startsWith(`${uploadDir}${path.sep}`) && fs.existsSync(storedPath)) {
        fs.unlink(storedPath, () => {});
      }
    }

    res.json({ success: true, data: { profile_photo_url: null } });
  } catch (error) { next(error); }
});

router.get('/permissions', requireAdmin, async (_req, res, next) => {
  try { const [rows] = await db.query(`SELECT e.id AS user_id,e.full_name AS user_name,e.email,e.role,${permissions.map((key) => `COALESCE(a.${key},0) AS ${key}`).join(',')} FROM employee_users e LEFT JOIN client_repository_access a ON a.employee_id=e.id WHERE e.is_active=1 ORDER BY e.full_name`); res.json({ success: true, data: rows }); } catch (error) { next(error); }
});
router.get('/permissions/user/:id', requireAdmin, async (req, res, next) => { try { const [[row]] = await db.query(`SELECT ${permissions.join(',')} FROM client_repository_access WHERE employee_id=?`, [req.params.id]); res.json({ success: true, data: row || {} }); } catch (error) { next(error); } });
router.put('/permissions/user/:id', requireAdmin, async (req, res, next) => {
  try {
    const values = permissions.map((key) => req.body[key] ? 1 : 0);
    await db.query(`INSERT INTO client_repository_access (employee_id,granted_by,${permissions.join(',')}) VALUES (?, ?, ${permissions.map(() => '?').join(',')}) ON DUPLICATE KEY UPDATE granted_by=VALUES(granted_by),${permissions.map((key) => `${key}=VALUES(${key})`).join(',')}`, [req.params.id, req.user.id, ...values]);
    const permData = Object.fromEntries(permissions.map((key, index) => [key, Boolean(values[index])]));

    // Notify the user about their updated client repository access.
    const canAccess = values.some(Boolean);
    const message = canAccess
      ? 'Your access to the Client Repository has been updated by an administrator.'
      : 'Your Client Repository access has been removed by an administrator.';
    await db.query(
      `INSERT INTO client_repository_notifications (recipient_id, recipient_name, sender_name, message)
       SELECT id, full_name, ?, ? FROM employee_users WHERE id=?`,
      [req.user.fullName, message, req.params.id],
    ).catch(() => {}); // non-fatal — don't fail the permission update if notify fails

    res.json({ success: true, data: permData });
  } catch (error) { next(error); }
});
router.get('/downloads', requirePermission('can_download'), async (req, res, next) => {
  try {
    const employeeFilter = isAdmin(req) ? '' : 'WHERE d.employee_id=?';
    const [rows] = await db.query(`SELECT d.id,d.downloaded_at AS created_at,a.name AS asset_name,a.file_name,a.type AS asset_type,a.section,c.name AS company_name,e.full_name AS user_name,e.email AS user_email FROM asset_downloads d JOIN assets a ON a.id=d.asset_id JOIN companies c ON c.id=a.company_id JOIN employee_users e ON e.id=d.employee_id ${employeeFilter} ORDER BY d.downloaded_at DESC`, isAdmin(req) ? [] : [req.user.id]);
    res.json({ success: true, data: rows });
  } catch (error) { next(error); }
});
router.get('/notifications', async (req, res, next) => {
  try {
    const limit = Math.max(1, Math.min(Number(req.query.limit) || 20, 100));
    const [rows] = await db.query(
      `SELECT id, sender_name, message, created_at, is_seen FROM client_repository_notifications
       WHERE recipient_id=? ORDER BY created_at DESC LIMIT ?`,
      [req.user.id, limit],
    );
    res.json({ success: true, data: rows.map((row) => ({ id: row.id, title: row.sender_name, message: row.message, created_at: row.created_at, is_read: Boolean(row.is_seen) })) });
  } catch (error) { next(error); }
});
router.get('/notifications/unread-count', async (req, res, next) => {
  try {
    const [[row]] = await db.query(
      'SELECT COUNT(*) AS unread_count FROM client_repository_notifications WHERE recipient_id=? AND COALESCE(is_seen,0)=0',
      [req.user.id],
    );
    res.json({ success: true, data: row });
  } catch (error) { next(error); }
});
router.put('/notifications/:id/read', async (req, res, next) => {
  try {
    await db.query(
      'UPDATE client_repository_notifications SET is_seen=1 WHERE id=? AND recipient_id=?',
      [req.params.id, req.user.id],
    );
    res.json({ success: true });
  } catch (error) { next(error); }
});
router.put('/notifications/read-all', async (req, res, next) => {
  try {
    await db.query(
      'UPDATE client_repository_notifications SET is_seen=1 WHERE recipient_id=?',
      [req.user.id],
    );
    res.json({ success: true });
  } catch (error) { next(error); }
});
// Admin: send a notification to a specific user or broadcast to all users with access.
router.post('/notifications/send', requireAdmin, async (req, res, next) => {
  try {
    const message = String(req.body.message || '').trim();
    if (!message) return res.status(400).json({ success: false, message: 'Message is required.' });
    const recipientId = req.body.recipient_id ? Number(req.body.recipient_id) : null;
    if (recipientId) {
      await db.query(
        `INSERT INTO client_repository_notifications (recipient_id, recipient_name, sender_name, message)
         SELECT id, full_name, ?, ? FROM employee_users WHERE id=?`,
        [req.user.fullName, message, recipientId],
      );
    } else {
      // Broadcast to all users who have client repository access.
      await db.query(
        `INSERT INTO client_repository_notifications (recipient_id, recipient_name, sender_name, message)
         SELECT e.id, e.full_name, ?, ? FROM employee_users e INNER JOIN client_repository_access a ON a.employee_id=e.id WHERE e.is_active=1`,
        [req.user.fullName, message],
      );
    }
    res.status(201).json({ success: true });
  } catch (error) { next(error); }
});
router.delete('/notifications/:id', async (req, res, next) => {
  try {
    await db.query(
      'DELETE FROM client_repository_notifications WHERE id=? AND recipient_id=?',
      [req.params.id, req.user.id],
    );
    res.json({ success: true });
  } catch (error) { next(error); }
});

module.exports = router;
