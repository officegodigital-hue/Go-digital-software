// routes/packages.js — Service Packages CRUD API
const express = require('express');
const router  = express.Router();
const db      = require('../config/db');

function parseJSONField(field) {
  if (Array.isArray(field)) return field;
  try {
    return JSON.parse(field);
  } catch (_) {
    return [];
  }
}

// GET /api/packages — list all packages, ordered by sort_order
router.get('/', async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT id, title, subtitle, price, period, is_google, is_popular, features, package_tasks, sort_order
       FROM packages ORDER BY sort_order ASC, id ASC`
    );
    const data = rows.map(r => ({
      ...r,
      is_google:     !!r.is_google,
      is_popular:    !!r.is_popular,
      features:      parseJSONField(r.features),
      package_tasks: parseJSONField(r.package_tasks),
    }));
    return res.json({ success: true, data });
  } catch (err) {
    console.error('GET /packages ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/packages/:id — single package
router.get('/:id', async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT id, title, subtitle, price, period, is_google, is_popular, features, package_tasks, sort_order
       FROM packages WHERE id = ?`,
      [req.params.id]
    );
    if (rows.length === 0)
      return res.status(404).json({ success: false, message: 'Package not found' });

    const r = rows[0];
    return res.json({
      success: true,
      data: {
        ...r,
        is_google:     !!r.is_google,
        is_popular:    !!r.is_popular,
        features:      parseJSONField(r.features),
        package_tasks: parseJSONField(r.package_tasks),
      },
    });
  } catch (err) {
    console.error('GET /packages/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/packages — create new package
router.post('/', async (req, res) => {
  const { title, subtitle, price, period, isGoogle, is_google, isPopular, is_popular, features, package_tasks } = req.body;

  const googleFlag = isGoogle !== undefined ? isGoogle : is_google;
  const popularFlag = isPopular !== undefined ? isPopular : is_popular;

  if (!title || !price || !Array.isArray(features) || features.length === 0)
    return res.status(400).json({ success: false, message: 'title, price and at least one feature are required' });

  try {
    const [maxRow] = await db.query(`SELECT COALESCE(MAX(sort_order), 0) AS maxOrder FROM packages`);
    const nextOrder = maxRow[0].maxOrder + 1;

    const [result] = await db.query(
      `INSERT INTO packages (title, subtitle, price, period, is_google, is_popular, features, package_tasks, sort_order)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        title, subtitle || '', price, period || '/Month',
        googleFlag ? 1 : 0, popularFlag ? 1 : 0,
        JSON.stringify(features),
        JSON.stringify(package_tasks || []),
        nextOrder,
      ]
    );

    return res.status(201).json({
      success: true,
      message: 'Package created',
      data: {
        id: result.insertId, title, subtitle: subtitle || '', price, period: period || '/Month',
        is_google: !!googleFlag, is_popular: !!popularFlag, features, package_tasks: package_tasks || [], sort_order: nextOrder,
      },
    });
  } catch (err) {
    console.error('POST /packages ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// PUT /api/packages/:id — update existing package
router.put('/:id', async (req, res) => {
  const { title, subtitle, price, period, isGoogle, is_google, isPopular, is_popular, features, package_tasks } = req.body;

  const googleFlag = isGoogle !== undefined ? isGoogle : is_google;
  const popularFlag = isPopular !== undefined ? isPopular : is_popular;

  if (!title || !price || !Array.isArray(features) || features.length === 0)
    return res.status(400).json({ success: false, message: 'title, price and at least one feature are required' });

  try {
    const [result] = await db.query(
      `UPDATE packages
       SET title = ?, subtitle = ?, price = ?, period = ?, is_google = ?, is_popular = ?, features = ?, package_tasks = ?
       WHERE id = ?`,
      [
        title, subtitle || '', price, period || '/Month',
        googleFlag ? 1 : 0, popularFlag ? 1 : 0,
        JSON.stringify(features),
        JSON.stringify(package_tasks || []),
        req.params.id,
      ]
    );
    if (result.affectedRows === 0)
      return res.status(404).json({ success: false, message: 'Package not found' });

    return res.json({ success: true, message: 'Package updated' });
  } catch (err) {
    console.error('PUT /packages/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// DELETE /api/packages/:id — delete package
router.delete('/:id', async (req, res) => {
  try {
    const [result] = await db.query(`DELETE FROM packages WHERE id = ?`, [req.params.id]);
    if (result.affectedRows === 0)
      return res.status(404).json({ success: false, message: 'Package not found' });
    return res.json({ success: true, message: 'Package deleted' });
  } catch (err) {
    console.error('DELETE /packages/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;