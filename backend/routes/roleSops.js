'use strict';

const express = require('express');
const multer = require('multer');
const fs = require('fs');
const path = require('path');
const db = require('../config/db');
const { authenticateToken } = require('./auth');

const router = express.Router();
const privateUploadDir = path.join(__dirname, '..', 'private_uploads', 'role-sops');
fs.mkdirSync(privateUploadDir, { recursive: true });

const upload = multer({
  storage: multer.diskStorage({
    destination: (_req, _file, done) => done(null, privateUploadDir),
    filename: (_req, _file, done) =>
      done(null, `${Date.now()}-${Math.round(Math.random() * 1e9)}.pdf`),
  }),
  limits: { fileSize: 25 * 1024 * 1024 },
  fileFilter: (_req, file, done) => {
    if (path.extname(file.originalname || '').toLowerCase() !== '.pdf') {
      return done(new Error('Only PDF files can be uploaded.'));
    }
    return done(null, true);
  },
});

router.use(authenticateToken);

function isAdmin(req) {
  return String(req.user?.userType || '').toLowerCase() === 'admin' ||
    req.user?.isMainAdmin === true ||
    Number(req.user?.isMainAdmin) === 1;
}

async function hasSopAccess(employeeId) {
  const [rows] = await db.query(`
    SELECT access_type
    FROM employee_application_access
    WHERE employee_id = ? AND application = 'role_sop'
    LIMIT 1
  `, [employeeId]);
  return ['employee', 'admin'].includes(
    String(rows[0]?.access_type || 'none').toLowerCase(),
  );
}

function requireAdmin(req, res, next) {
  if (!isAdmin(req)) {
    return res.status(403).json({ success: false, message: 'Administrator access is required.' });
  }
  return next();
}

function removeFile(filePath) {
  if (filePath) fs.promises.unlink(filePath).catch((error) => {
    if (error.code !== 'ENOENT') console.error('Unable to remove replaced role SOP:', error.message);
  });
}

function displayFileName(value) {
  return path
    .basename(String(value || 'role-sop.pdf').replace(/\\/g, '/'))
    .replace(/[\u0000-\u001f\u007f"]/g, '_');
}

router.get('/', async (req, res) => {
  try {
    if (!isAdmin(req) && !(await hasSopAccess(req.user.id))) {
      return res.json({ success: true, data: [] });
    }
    const [rows] = isAdmin(req)
      ? await db.query(`
          SELECT s.id, s.role_id, r.role_name, s.title, s.file_name, s.updated_at
          FROM role_sops s
          INNER JOIN user_roles r ON r.id = s.role_id
          ORDER BY r.role_name
        `)
      : await db.query(`
          SELECT s.id, s.role_id, r.role_name, s.title, s.file_name, s.updated_at
          FROM role_sops s
          INNER JOIN user_roles r ON r.id = s.role_id
          INNER JOIN employee_user_roles eur ON eur.role_id = r.id
          WHERE eur.employee_id = ?
          ORDER BY r.role_name
        `, [req.user.id]);
    return res.json({ success: true, data: rows });
  } catch (error) {
    console.error('GET /role-sops ERROR:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to load role-based SOPs.' });
  }
});

router.put('/:roleId', requireAdmin, (req, res, next) => {
  upload.single('file')(req, res, (error) => {
    if (error) {
      return res.status(400).json({ success: false, message: error.message });
    }
    return next();
  });
}, async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ success: false, message: 'Choose a PDF file to upload.' });
  }

  try {
    const handle = await fs.promises.open(req.file.path, 'r');
    const signature = Buffer.alloc(5);
    await handle.read(signature, 0, signature.length, 0);
    await handle.close();
    if (signature.toString('ascii') !== '%PDF-') {
      removeFile(req.file.path);
      return res.status(400).json({ success: false, message: 'The selected file is not a valid PDF.' });
    }

    const [[role]] = await db.query(
      'SELECT id, role_name FROM user_roles WHERE id = ?',
      [req.params.roleId],
    );
    if (!role) {
      removeFile(req.file.path);
      return res.status(404).json({ success: false, message: 'Role not found.' });
    }

    const title = String(req.body.title || role.role_name).trim().slice(0, 180);
    const [[previous]] = await db.query(
      'SELECT storage_name FROM role_sops WHERE role_id = ?',
      [role.id],
    );
    await db.query(`
      INSERT INTO role_sops (role_id, title, file_name, storage_name, updated_by)
      VALUES (?, ?, ?, ?, ?)
      ON DUPLICATE KEY UPDATE
        title = VALUES(title),
        file_name = VALUES(file_name),
        storage_name = VALUES(storage_name),
        updated_by = VALUES(updated_by),
        updated_at = CURRENT_TIMESTAMP
    `, [role.id, title || role.role_name, displayFileName(req.file.originalname), path.basename(req.file.filename), req.user.id]);

    if (previous?.storage_name && previous.storage_name !== req.file.filename) {
      removeFile(path.join(privateUploadDir, path.basename(previous.storage_name)));
    }
    return res.json({ success: true, message: 'Role SOP saved.' });
  } catch (error) {
    removeFile(req.file.path);
    console.error('PUT /role-sops/:roleId ERROR:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to save the role-based SOP.' });
  }
});

router.delete('/:roleId', requireAdmin, async (req, res) => {
  try {
    const [[sop]] = await db.query(
      'SELECT id, storage_name FROM role_sops WHERE role_id = ?',
      [req.params.roleId],
    );
    if (!sop) {
      return res.status(404).json({ success: false, message: 'No SOP exists for this role.' });
    }
    await db.query('DELETE FROM role_sops WHERE role_id = ?', [req.params.roleId]);
    if (sop.storage_name) {
      removeFile(path.join(privateUploadDir, path.basename(sop.storage_name)));
    }
    return res.json({ success: true, message: 'Role SOP deleted.' });
  } catch (error) {
    console.error('DELETE /role-sops/:roleId ERROR:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to delete the role-based SOP.' });
  }
});

router.get('/:id/file', async (req, res) => {
  try {
    if (!isAdmin(req) && !(await hasSopAccess(req.user.id))) {
      return res.status(403).json({ success: false, message: 'SOP access is not enabled for your account.' });
    }
    const [rows] = isAdmin(req)
      ? await db.query('SELECT file_name, storage_name FROM role_sops WHERE id = ?', [req.params.id])
      : await db.query(`
          SELECT s.file_name, s.storage_name
          FROM role_sops s
          INNER JOIN employee_user_roles eur ON eur.role_id = s.role_id
          WHERE s.id = ? AND eur.employee_id = ?
        `, [req.params.id, req.user.id]);
    const sop = rows[0];
    if (!sop) {
      return res.status(404).json({ success: false, message: 'SOP not found or access denied.' });
    }

    const storageName = path.basename(sop.storage_name);
    const filePath = path.join(privateUploadDir, storageName);
    res.set({
      'Content-Type': 'application/pdf',
      'Content-Disposition': `inline; filename="${displayFileName(sop.file_name)}"`,
      'Cache-Control': 'private, no-store',
    });
    return res.sendFile(filePath, (error) => {
      if (error && !res.headersSent) {
        console.error('GET /role-sops/:id/file ERROR:', error.message);
        res.status(error.code === 'ENOENT' ? 404 : 500).json({
          success: false,
          message: error.code === 'ENOENT' ? 'SOP file not found.' : 'Unable to open the SOP file.',
        });
      }
    });
  } catch (error) {
    console.error('GET /role-sops/:id/file ERROR:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to open the SOP file.' });
  }
});

module.exports = router;
