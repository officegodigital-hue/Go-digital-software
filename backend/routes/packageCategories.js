// routes/packageCategories.js — Package category master CRUD API
// Mount in server/app: app.use('/api/package-categories', require('./routes/packageCategories'));
const express = require('express');
const router  = express.Router();
const db      = require('../config/db');

const HEX = /^#[0-9A-Fa-f]{6}$/;

// GET /api/package-categories — list all categories with package counts
router.get('/', async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT c.id, c.name, c.color, c.sort_order,
              COUNT(p.id) AS package_count
       FROM package_categories c
       LEFT JOIN packages p ON p.category_id = c.id
       GROUP BY c.id, c.name, c.color, c.sort_order
       ORDER BY c.sort_order ASC, c.name ASC`
    );
    return res.json({ success: true, data: rows });
  } catch (err) {
    console.error('GET /package-categories ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/package-categories — create category { name, color }
router.post('/', async (req, res) => {
  const name  = (req.body.name || '').trim();
  const color = HEX.test(req.body.color || '') ? req.body.color.toUpperCase() : '#0052CC';

  if (!name)
    return res.status(400).json({ success: false, message: 'Category name is required' });

  try {
    const [maxRow] = await db.query(
      `SELECT COALESCE(MAX(sort_order), 0) AS maxOrder FROM package_categories`
    );
    const nextOrder = maxRow[0].maxOrder + 1;

    const [result] = await db.query(
      `INSERT INTO package_categories (name, color, sort_order) VALUES (?, ?, ?)`,
      [name, color, nextOrder]
    );
    return res.status(201).json({
      success: true,
      message: 'Category created',
      data: { id: result.insertId, name, color, sort_order: nextOrder },
    });
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY')
      return res.status(409).json({ success: false, message: `"${name}" already exists` });
    console.error('POST /package-categories ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// PUT /api/package-categories/:id — rename / recolour { name, color }
router.put('/:id', async (req, res) => {
  const name  = (req.body.name || '').trim();
  const color = HEX.test(req.body.color || '') ? req.body.color.toUpperCase() : '#0052CC';

  if (!name)
    return res.status(400).json({ success: false, message: 'Category name is required' });

  try {
    const [result] = await db.query(
      `UPDATE package_categories SET name = ?, color = ? WHERE id = ?`,
      [name, color, req.params.id]
    );
    if (result.affectedRows === 0)
      return res.status(404).json({ success: false, message: 'Category not found' });
    return res.json({ success: true, message: 'Category updated' });
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY')
      return res.status(409).json({ success: false, message: `"${name}" already exists` });
    console.error('PUT /package-categories/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// DELETE /api/package-categories/:id — packages in it become Uncategorized
router.delete('/:id', async (req, res) => {
  try {
    await db.query(`UPDATE packages SET category_id = NULL WHERE category_id = ?`, [req.params.id]);
    const [result] = await db.query(`DELETE FROM package_categories WHERE id = ?`, [req.params.id]);
    if (result.affectedRows === 0)
      return res.status(404).json({ success: false, message: 'Category not found' });
    return res.json({ success: true, message: 'Category deleted' });
  } catch (err) {
    console.error('DELETE /package-categories/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
