// routes/taskRules.js — Task Deadline Rules CRUD.
// Mount in server.js:  app.use('/api/task-rules', require('./routes/taskRules'));
const express = require('express');
const router = express.Router();
const db = require('../config/db');
const { ROLE_OPTIONS, ensureRulesTable } = require('../lib/taskRules');

router.use(async (req, res, next) => {
  try {
    await ensureRulesTable(db);
    next();
  } catch (err) {
    console.error('task_deadline_rules setup failed:', err.message);
    res.status(500).json({ success: false, message: err.message });
  }
});

const intOrNull = (v) => {
  if (v === null || v === undefined || String(v).trim() === '') return null;
  const n = Number.parseInt(v, 10);
  return Number.isFinite(n) && n >= 0 ? n : null;
};

function body(req) {
  const b = req.body || {};
  return {
    role_key: String(b.role_key || '').trim(),
    task_name: String(b.task_name || '*').trim() || '*',
    qty: intOrNull(b.qty),
    start_within_days: intOrNull(b.start_within_days),
    complete_within_days: intOrNull(b.complete_within_days),
    per_week: intOrNull(b.per_week),
    weeks: intOrNull(b.weeks),
    notes: String(b.notes || '').trim().slice(0, 500) || null,
    is_active: b.is_active === false || b.is_active === 0 ? 0 : 1,
  };
}

function validate(r) {
  if (!ROLE_OPTIONS.some((o) => o.key === r.role_key)) return 'Choose a role';
  if (r.start_within_days === null && r.complete_within_days === null &&
      r.per_week === null && r.weeks === null) {
    return 'Set at least one: start within, complete within, or weekly pace';
  }
  return null;
}

// GET /api/task-rules  → { data: rules, roles }
router.get('/', async (req, res) => {
  try {
    const [rows] = await db.query('SELECT * FROM task_deadline_rules ORDER BY role_key, task_name, qty, id');
    return res.json({ success: true, data: rows, roles: ROLE_OPTIONS });
  } catch (err) {
    console.error('GET /task-rules ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

router.post('/', async (req, res) => {
  const r = body(req);
  const problem = validate(r);
  if (problem) return res.status(400).json({ success: false, message: problem });
  try {
    const [ins] = await db.query(
      `INSERT INTO task_deadline_rules
         (role_key, task_name, qty, start_within_days, complete_within_days, per_week, weeks, notes, is_active)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [r.role_key, r.task_name, r.qty, r.start_within_days, r.complete_within_days,
        r.per_week, r.weeks, r.notes, r.is_active],
    );
    return res.status(201).json({ success: true, data: { id: ins.insertId, ...r } });
  } catch (err) {
    console.error('POST /task-rules ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

router.put('/:id', async (req, res) => {
  const r = body(req);
  const problem = validate(r);
  if (problem) return res.status(400).json({ success: false, message: problem });
  try {
    const [result] = await db.query(
      `UPDATE task_deadline_rules
       SET role_key = ?, task_name = ?, qty = ?, start_within_days = ?, complete_within_days = ?,
           per_week = ?, weeks = ?, notes = ?, is_active = ?
       WHERE id = ?`,
      [r.role_key, r.task_name, r.qty, r.start_within_days, r.complete_within_days,
        r.per_week, r.weeks, r.notes, r.is_active, req.params.id],
    );
    if (!result.affectedRows) return res.status(404).json({ success: false, message: 'Rule not found' });
    return res.json({ success: true });
  } catch (err) {
    console.error('PUT /task-rules ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

router.delete('/:id', async (req, res) => {
  try {
    const [result] = await db.query('DELETE FROM task_deadline_rules WHERE id = ?', [req.params.id]);
    if (!result.affectedRows) return res.status(404).json({ success: false, message: 'Rule not found' });
    return res.json({ success: true });
  } catch (err) {
    console.error('DELETE /task-rules ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
