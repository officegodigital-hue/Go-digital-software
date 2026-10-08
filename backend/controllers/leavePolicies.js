const db = require('../config/db');
const leaveSystem = require('../lib/leaveSystem');

function validAllowance(value) {
  const number = Number(value);
  return Number.isFinite(number) && number >= 0 && number <= 366 && number * 2 === Math.floor(number * 2);
}

async function visibleCount(exceptId) {
  const [rows] = await db.query(`SELECT COUNT(*) AS total FROM hrms_leave_types WHERE show_balance_card = 1 AND is_active = 1 ${exceptId ? 'AND id <> ?' : ''}`, exceptId ? [exceptId] : []);
  return Number(rows[0].total || 0);
}

exports.list = async (_req, res) => {
  try { res.json({ success: true, data: await leaveSystem.listTypes(db) }); }
  catch (_) { res.status(500).json({ success: false, message: 'Unable to load leave types.' }); }
};

exports.create = async (req, res) => {
  const body = req.body || {}; const name = String(body.name || '').trim();
  if (!name || name.length > 80 || !validAllowance(body.annual_allowance)) return res.status(400).json({ success: false, message: 'Enter a unique leave type and allowance in half-day increments.' });
  try {
    await leaveSystem.ensureLeaveTables(db);
    const show = body.show_balance_card === true || body.show_balance_card === 1;
    if (show && await visibleCount() >= 4) return res.status(400).json({ success: false, message: 'A maximum of four leave balance cards may be visible.' });
    const mode = body.display_mode === 'USAGE_ONLY' ? 'USAGE_ONLY' : 'BALANCE_USAGE';
    const abbr = String(body.abbreviation || '').trim().toUpperCase().slice(0, 10) || null;
    const isLop = body.is_lop === false || body.is_lop === 0 ? 0 : 1;
    const [result] = await db.query(`INSERT INTO hrms_leave_types (name, annual_allowance, is_active, show_balance_card, usage_only, display_mode, abbreviation, is_lop, card_order) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`, [name, Number(body.annual_allowance), body.is_active === false ? 0 : 1, show ? 1 : 0, mode === 'USAGE_ONLY' ? 1 : 0, mode, abbr, isLop, show ? Number(body.card_order || 99) : null]);
    res.status(201).json({ success: true, id: result.insertId });
  } catch (error) { res.status(error.code === 'ER_DUP_ENTRY' ? 409 : 500).json({ success: false, message: error.code === 'ER_DUP_ENTRY' ? 'A leave type with this name already exists.' : 'Unable to create leave type.' }); }
};

// Bulk save — receives all leave types in one request and validates the
// complete final state before writing anything. This avoids the ordering
// problem where saving a hidden row first fails because the newly-visible
// row hasn't been saved yet.
exports.saveAll = async (req, res) => {
  const items = Array.isArray(req.body) ? req.body : null;
  if (!items || !items.length) return res.status(400).json({ success: false, message: 'Send an array of leave types.' });
  for (const item of items) {
    const name = String(item.name || '').trim();
    if (!name || name.length > 80 || !validAllowance(item.annual_allowance)) {
      return res.status(400).json({ success: false, message: `"${name || '?'}" has an invalid name or allowance (use 0–366 in half-day steps).` });
    }
  }
  // Validate final visible count across all rows being saved
  const finalVisible = items.filter((item) => {
    const active = item.is_active === false ? 0 : 1;
    return active && (item.show_balance_card === true || item.show_balance_card === 1);
  }).length;
  if (finalVisible < 2) return res.status(400).json({ success: false, message: 'Keep at least two leave balance cards visible.' });
  if (finalVisible > 4) return res.status(400).json({ success: false, message: 'A maximum of four leave balance cards may be visible.' });
  try {
    await leaveSystem.ensureLeaveTables(db);
    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      const id = Number(item.id);
      if (!id) continue;
      const name = String(item.name || '').trim();
      const active = item.is_active === false ? 0 : 1;
      const show = active && (item.show_balance_card === true || item.show_balance_card === 1) ? 1 : 0;
      const mode = item.display_mode === 'USAGE_ONLY' || item.usage_only === true || item.usage_only === 1 ? 'USAGE_ONLY' : 'BALANCE_USAGE';
      const abbr = String(item.abbreviation || '').trim().toUpperCase().slice(0, 10) || null;
      const isLop = item.is_lop === false || item.is_lop === 0 ? 0 : 1;
      await db.query(`UPDATE hrms_leave_types SET name = ?, annual_allowance = ?, is_active = ?, show_balance_card = ?,
        usage_only = ?, display_mode = ?, abbreviation = ?, is_lop = ?, card_order = ? WHERE id = ?`,
        [name, Number(item.annual_allowance), active, show, mode === 'USAGE_ONLY' ? 1 : 0, mode, abbr, isLop, show ? i + 1 : null, id]);
    }
    res.json({ success: true });
  } catch (error) {
    res.status(error.code === 'ER_DUP_ENTRY' ? 409 : 500).json({
      success: false,
      message: error.code === 'ER_DUP_ENTRY' ? 'A leave type with this name already exists.' : 'Unable to save leave types.',
    });
  }
};

// Keep single-row save for backward compatibility
exports.save = async (req, res) => {
  const body = req.body || {}; const id = Number(req.params.id); const name = String(body.name || '').trim();
  if (!id || !name || !validAllowance(body.annual_allowance)) return res.status(400).json({ success: false, message: 'Enter a valid leave type and allowance in half-day increments.' });
  try {
    await leaveSystem.ensureLeaveTables(db);
    const [current] = await db.query('SELECT id FROM hrms_leave_types WHERE id = ?', [id]);
    if (!current.length) return res.status(404).json({ success: false, message: 'Leave type not found.' });
    const active = body.is_active === false ? 0 : 1; const show = active && (body.show_balance_card === true || body.show_balance_card === 1) ? 1 : 0;
    const mode = body.display_mode === 'USAGE_ONLY' || body.usage_only === true || body.usage_only === 1 ? 'USAGE_ONLY' : 'BALANCE_USAGE';
    const abbr = String(body.abbreviation || '').trim().toUpperCase().slice(0, 10) || null;
    const isLop = body.is_lop === false || body.is_lop === 0 ? 0 : 1;
    await db.query(`UPDATE hrms_leave_types SET name = ?, annual_allowance = ?, is_active = ?, show_balance_card = ?, usage_only = ?, display_mode = ?, abbreviation = ?, is_lop = ?, card_order = ? WHERE id = ?`, [name, Number(body.annual_allowance), active, show, mode === 'USAGE_ONLY' ? 1 : 0, mode, abbr, isLop, show ? Number(body.card_order || 99) : null, id]);
    res.json({ success: true });
  } catch (error) { res.status(error.code === 'ER_DUP_ENTRY' ? 409 : 500).json({ success: false, message: error.code === 'ER_DUP_ENTRY' ? 'A leave type with this name already exists.' : 'Unable to save leave type.' }); }
};
