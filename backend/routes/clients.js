// routes/clients.js — Client Onboarding CRUD API (v4: bank details + new % scheme)
const express = require('express');
const router  = express.Router();
const db      = require('../config/db');

// ✅ FIX: Import authenticateToken from auth.js
const { authenticateToken } = require('./auth');
 
// ── Completion percentage rules ────────────────────────────────────────────────
const FORM_PERCENT       = 30;
const BANK_PERCENT       = 20;
const PER_CREDENTIAL     = 5;
const MAX_CREDENTIALS    = 6;

function computePercent(client, credentialCount) {
  if (client.status === 'complete') return 100;

  let percent = FORM_PERCENT;

  const bankFilled =
    !!(client.bank_account_name && client.bank_account_name.trim()) &&
    !!(client.bank_name && client.bank_name.trim()) &&
    !!(client.bank_account_number && client.bank_account_number.trim()) &&
    !!(client.bank_ifsc && client.bank_ifsc.trim());

  if (bankFilled) percent += BANK_PERCENT;

  const credPercent = Math.min(credentialCount, MAX_CREDENTIALS) * PER_CREDENTIAL;
  percent += credPercent;

  return Math.min(80, Math.round(percent));
}

// ── Client state: Active / On Hold / Inactive ─────────────────────────────────
// On Hold = is_on_hold = 1 AND is_active = 0, so every screen that lists only
// active clients (Employee Workspace, Task Assign, credentials, search …)
// hides the client until it is set back to Active.
let holdColumnsReady = null;
function ensureHoldColumns() {
  if (!holdColumnsReady) {
    holdColumnsReady = (async () => {
      const [cols] = await db.query(
        `SELECT COLUMN_NAME AS c FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'clients'`,
      );
      const have = new Set(cols.map((r) => r.c));
      if (!have.has('is_on_hold')) {
        await db.query('ALTER TABLE clients ADD COLUMN is_on_hold TINYINT(1) NOT NULL DEFAULT 0');
      }
      if (!have.has('on_hold_at')) {
        await db.query('ALTER TABLE clients ADD COLUMN on_hold_at DATETIME NULL');
      }
    })().catch((err) => {
      holdColumnsReady = null;
      console.error('clients: hold columns not added:', err.message);
    });
  }
  return holdColumnsReady;
}
ensureHoldColumns();

function clientState(c) {
  if (Number(c.is_on_hold) === 1) return 'hold';
  return Number(c.is_active) === 1 || c.is_active == null ? 'active' : 'inactive';
}
const STATE_RANK = { active: 0, hold: 1, inactive: 2 };

// S.No = display_order, always 1..N with no gaps:
// Active clients first, then On Hold, then In-Active; inside each group the
// saved order (new / unnumbered ones at the bottom).
// move = { id, position } puts that client at that S.No, kept inside its group.
// toEnd = id → that client goes to the bottom of its group (new / state change).
async function renumberClients(conn, { move = null, toEnd = null } = {}) {
  const [rows] = await conn.query('SELECT id, display_order, is_active, is_on_hold FROM clients FOR UPDATE');
  const big = Number.MAX_SAFE_INTEGER;
  const key = (r) => {
    if (toEnd !== null && Number(r.id) === Number(toEnd)) return big;
    const d = Number(r.display_order);
    return d > 0 ? d : big - 1;
  };
  const groups = [[], [], []];
  rows
    .sort((a, b) => key(a) - key(b) || Number(a.id) - Number(b.id))
    .forEach((r) => groups[STATE_RANK[clientState(r)]].push(r));

  if (move) {
    const g = groups.find((list) => list.some((r) => Number(r.id) === Number(move.id)));
    if (g) {
      const offset = groups.slice(0, groups.indexOf(g)).reduce((n, list) => n + list.length, 0);
      const from = g.findIndex((r) => Number(r.id) === Number(move.id));
      const [item] = g.splice(from, 1);
      const to = Math.max(0, Math.min(Number(move.position) - 1 - offset, g.length));
      g.splice(to, 0, item);
    }
  }

  const ordered = groups.flat();
  const changed = ordered
    .map((r, i) => ({ id: Number(r.id), pos: i + 1, old: Number(r.display_order) }))
    .filter((r) => r.pos !== r.old);
  if (!changed.length) return;
  const ids = changed.map((r) => r.id);
  const caseSql = (sign) => `CASE id ${changed.map((r) => `WHEN ${r.id} THEN ${sign * r.pos}`).join(' ')} END`;
  // Two passes (negative first) so a UNIQUE index on display_order never clashes.
  await conn.query(`UPDATE clients SET display_order = ${caseSql(-1)} WHERE id IN (${ids.join(',')})`);
  await conn.query(`UPDATE clients SET display_order = ${caseSql(1)} WHERE id IN (${ids.join(',')})`);
}

async function withConnection(fn) {
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const out = await fn(conn);
    await conn.commit();
    return out;
  } catch (err) {
    try { await conn.rollback(); } catch (_) { /* ignore */ }
    throw err;
  } finally {
    conn.release();
  }
}


// 🟢 GET /api/clients/all-for-credentials — Fetch all active clients for credentials directory
router.get('/all-for-credentials', authenticateToken, async (req, res) => {
  try {
    const [clients] = await db.query(
      `SELECT c.*, 
              COALESCE(eu.full_name, 'Main Admin') AS created_by_name
       FROM clients c
       LEFT JOIN employee_users eu ON c.created_by = eu.id
       WHERE c.is_active = 1 OR c.is_active IS NULL
       ORDER BY c.company_name ASC`
    );

    const [credCounts] = await db.query(
      `SELECT client_id, COUNT(*) as cnt FROM client_credentials
       WHERE client_id IS NOT NULL GROUP BY client_id`
    );
    const countMap = {};
    credCounts.forEach(c => { countMap[c.client_id] = c.cnt; });

    const data = clients.map(c => ({
      ...c,
      credential_count: countMap[c.id] || 0,
      completion_percent: computePercent(c, countMap[c.id] || 0),
    }));

    return res.json({ success: true, data });
  } catch (err) {
    console.error('GET /clients/all-for-credentials ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// 🟢 1. PUT /active-list ON TOP OF /:id to prevent route hijacking
router.get('/active-list', async (req, res) => {
  try {
    const [clients] = await db.query(
      `SELECT id, company_name, industry, is_active 
       FROM clients 
       WHERE is_active = 1 OR is_active IS NULL 
       ORDER BY company_name ASC`
    );

    return res.json({
      success: true,
      data: clients,
    });
  } catch (err) {
    console.error('GET /clients/active-list ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// 1. GET /api/clients — Role-based filtering for main admin and regular admins
router.get('/', authenticateToken, async (req, res) => {
  try {
    await ensureHoldColumns();
    const userId = req.user.id;

    // ✅ Kandupudippu: Database-la check panni Main Admin-ah nu paarkurom
    const [userRows] = await db.query('SELECT is_main_admin FROM employee_users WHERE id = ?', [userId]);
    const isMainAdmin = userRows.length > 0 && (userRows[0].is_main_admin === 1 || userRows[0].is_main_admin === true);

    let query = `
      SELECT c.*, 
             COALESCE(eu.full_name, 'Main Admin') AS created_by_name
      FROM clients c
      LEFT JOIN employee_users eu ON c.created_by = eu.id
    `;
    let queryParams = [];

    // ✅ Main Admin illena (Normal Admin), avanga add pannathu mattum show aaganum
    if (!isMainAdmin) {
      query += ` WHERE c.created_by = ? `;
      queryParams.push(userId);
    }

    query += `
      ORDER BY
        CASE
          WHEN COALESCE(c.is_on_hold, 0) = 1 THEN 1
          WHEN c.is_active = 1 OR c.is_active IS NULL THEN 0
          ELSE 2
        END ASC,
        CASE WHEN c.display_order IS NULL OR c.display_order <= 0 THEN 1 ELSE 0 END ASC,
        c.display_order ASC,
        c.id ASC
    `;

    const [clients] = await db.query(query, queryParams);

    const [credCounts] = await db.query(
      `SELECT client_id, COUNT(*) as cnt FROM client_credentials
       WHERE client_id IS NOT NULL GROUP BY client_id`
    );
    const countMap = {};
    credCounts.forEach(c => { countMap[c.client_id] = c.cnt; });

    const data = clients.map(c => ({
      ...c,
      client_state: clientState(c),
      credential_count: countMap[c.id] || 0,
      completion_percent: computePercent(c, countMap[c.id] || 0),
    }));

    return res.json({ success: true, data });
  } catch (err) {
    console.error('GET /clients ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/clients/search/query
router.get('/search/query', async (req, res) => {
  try {
    const query = req.query.query || '';

    if (query.trim().length === 0) {
      const [clients] = await db.query(`
        SELECT id, company_name, industry
        FROM clients
        WHERE is_active = 1
        ORDER BY company_name ASC
      `);

      return res.json({
        success: true,
        data: clients,
      });
    }

    const [clients] = await db.query(`
      SELECT id, company_name, industry
      FROM clients
      WHERE is_active = 1
        AND company_name LIKE ?
      ORDER BY company_name ASC
    `, [`%${query}%`]);

    return res.json({
      success: true,
      data: clients,
    });

  } catch (err) {
    console.error("GET /clients/search ERROR:", err.message);
    return res.status(500).json({
      success: false,
      message: err.message,
    });
  }
});

// GET /api/clients/:id
router.get('/:id', async (req, res) => {
  try {
    const [rows] = await db.query(`SELECT * FROM clients WHERE id = ?`, [req.params.id]);
    if (rows.length === 0)
      return res.status(404).json({ success: false, message: 'Client not found' });

    const [credCount] = await db.query(
      `SELECT COUNT(*) as cnt FROM client_credentials WHERE client_id = ?`,
      [req.params.id]
    );
    const cnt = credCount[0].cnt;

    const client = rows[0];
    return res.json({
      success: true,
      data: { ...client, credential_count: cnt, completion_percent: computePercent(client, cnt) },
    });
  } catch (err) {
    console.error('GET /clients/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// 2. POST /api/clients — Create Client (With created_by Tracker)
router.post('/', authenticateToken, async (req, res) => {
  const {
    companyName, industry, contactPerson, email, address,
    bankAccountName, bankName, bankAccountNumber, bankIfsc, status,
    clientPhone, gstNumber
  } = req.body;

  if (!companyName)
    return res.status(400).json({ success: false, message: 'companyName is required' });

  const adminId = req.user.id; // ✅ Yaru create pandrangalo avanga ID

  try {
    const [result] = await db.query(
      `INSERT INTO clients
        (company_name, industry, contact_person, email, address,
         bank_account_name, bank_name, bank_account_number, bank_ifsc, status, client_phone, gst_number, created_by)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        companyName, industry || '', contactPerson || '', email || '', address || '',
        bankAccountName || '', bankName || '', bankAccountNumber || '', bankIfsc || '',
        status || 'draft', clientPhone || '', gstNumber || '', adminId
      ]
    );

    // New client → last S.No of the Active group.
    try {
      await ensureHoldColumns();
      await withConnection((conn) => renumberClients(conn, { toEnd: result.insertId }));
    } catch (e) {
      console.error('POST /clients renumber failed:', e.message);
    }

    const completionPercent = computePercent({
      status: status || 'draft',
      bank_account_name: bankAccountName, bank_name: bankName,
      bank_account_number: bankAccountNumber, bank_ifsc: bankIfsc,
    }, 0);

    return res.status(201).json({
      success: true,
      message: 'Client created',
      data: { id: result.insertId, completion_percent: completionPercent },
    });
  } catch (err) {
    console.error('POST /clients ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// PUT /api/clients/:id
// router.put('/:id', async (req, res) => {
//   const {
//     companyName,  industry, contactPerson, email, address,
//     bankAccountName, bankName, bankAccountNumber, bankIfsc, status,
//     clientPhone, gstNumber 
//   } = req.body;

//   if (!companyName)
//     return res.status(400).json({ success: false, message: 'companyName is required' });

//   try {
//     const [result] = await db.query(
//       `UPDATE clients
//        SET company_name = ?,  industry = ?, contact_person = ?, email = ?, address = ?,
//            bank_account_name = ?, bank_name = ?, bank_account_number = ?, bank_ifsc = ?,
//            status = ?, client_phone = ?, gst_number = ?
//        WHERE id = ?`,
//       [
//         companyName,  industry || '', contactPerson || '', email || '', address || '',
//         bankAccountName || '', bankName || '', bankAccountNumber || '', bankIfsc || '',
//         status || 'draft', clientPhone || '', gstNumber || '', req.params.id
//       ]
//     );
    
//     if (result.affectedRows === 0)
//       return res.status(404).json({ success: false, message: 'Client not found' });

//     const [credCount] = await db.query(
//       `SELECT COUNT(*) as cnt FROM client_credentials WHERE client_id = ?`,
//       [req.params.id]
//     );
    
//     const completionPercent = computePercent({
//       status: status || 'draft',
//       bank_account_name: bankAccountName, bank_name: bankName,
//       bank_account_number: bankAccountNumber, bank_ifsc: bankIfsc,
//     }, credCount[0].cnt);

//     return res.json({ success: true, message: 'Client updated', completion_percent: completionPercent });
//   } catch (err) {
//     console.error('PUT /clients/:id ERROR:', err.message);
//     return res.status(500).json({ success: false, message: err.message });
//   }
// });

// PUT /api/clients/:id — Update client & cascade company name changes to all related tables
router.put('/:id', async (req, res) => {
  const {
    companyName,  industry, contactPerson, email, address,
    bankAccountName, bankName, bankAccountNumber, bankIfsc, status,
    clientPhone, gstNumber 
  } = req.body;

  if (!companyName)
    return res.status(400).json({ success: false, message: 'companyName is required' });

  const clientId = req.params.id;
  const connection = await db.getConnection();

  try {
    await connection.beginTransaction();

    // 1. Fetch old client details to get the previous company name
    const [oldRows] = await connection.query(`SELECT company_name FROM clients WHERE id = ?`, [clientId]);
    if (oldRows.length === 0) {
      await connection.rollback();
      return res.status(404).json({ success: false, message: 'Client not found' });
    }
    const oldCompanyName = oldRows[0].company_name;
    const newCompanyName = companyName.trim();

    // 2. Update the clients table
    const [result] = await connection.query(
      `UPDATE clients
       SET company_name = ?,  industry = ?, contact_person = ?, email = ?, address = ?,
           bank_account_name = ?, bank_name = ?, bank_account_number = ?, bank_ifsc = ?,
           status = ?, client_phone = ?, gst_number = ?
       WHERE id = ?`,
      [
        newCompanyName,  industry || '', contactPerson || '', email || '', address || '',
        bankAccountName || '', bankName || '', bankAccountNumber || '', bankIfsc || '',
        status || 'draft', clientPhone || '', gstNumber || '', clientId
      ]
    );
    
    if (result.affectedRows === 0) {
      await connection.rollback();
      return res.status(404).json({ success: false, message: 'Client not found' });
    }

    // 3. 🟢 CASCADE COMPANY NAME CHANGE: If company name changed, update all linked records
    if (oldCompanyName && oldCompanyName.trim().toUpperCase() !== newCompanyName.toUpperCase()) {
      const targetOldName = oldCompanyName.trim();

      // Update invoices table
      await connection.query(
        `UPDATE invoices SET client_name = ? WHERE UPPER(TRIM(client_name)) = UPPER(TRIM(?))`,
        [newCompanyName, targetOldName]
      );

      // Update quotations table
      await connection.query(
        `UPDATE quotations SET client_name = ? WHERE UPPER(TRIM(client_name)) = UPPER(TRIM(?))`,
        [newCompanyName, targetOldName]
      );

      // Update task_assignments table
      await connection.query(
        `UPDATE task_assignments SET client_name = ? WHERE UPPER(TRIM(client_name)) = UPPER(TRIM(?))`,
        [newCompanyName, targetOldName]
      );

      // Update task_list table
      await connection.query(
        `UPDATE task_list SET client_name = ? WHERE UPPER(TRIM(client_name)) = UPPER(TRIM(?))`,
        [newCompanyName, targetOldName]
      );

      // Update day_plan_rows table
      await connection.query(
        `UPDATE day_plan_rows SET client_name = ? WHERE UPPER(TRIM(client_name)) = UPPER(TRIM(?))`,
        [newCompanyName, targetOldName]
      );
    }

    const [credCount] = await connection.query(
      `SELECT COUNT(*) as cnt FROM client_credentials WHERE client_id = ?`,
      [clientId]
    );
    
    const completionPercent = computePercent({
      status: status || 'draft',
      bank_account_name: bankAccountName, bank_name: bankName,
      bank_account_number: bankAccountNumber, bank_ifsc: bankIfsc,
    }, credCount[0].cnt);

    await connection.commit();
    return res.json({ success: true, message: 'Client updated successfully', completion_percent: completionPercent });
  } catch (err) {
    await connection.rollback();
    console.error('PUT /clients/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  } finally {
    connection.release();
  }
});

// PATCH /api/clients/:id
//   { state: 'active' | 'hold' | 'inactive' }  — Active / On Hold / Inactive
//   { isActive: true | false }                 — old toggle (still works)
//   { status: 'draft' | 'pending' | 'verified' | 'complete' } — onboarding step
router.patch('/:id', async (req, res) => {
  try {
    await ensureHoldColumns();
    const { isActive, state, status } = req.body || {};
    let next = null;
    if (state !== undefined && state !== null && state !== '') next = String(state).trim().toLowerCase();
    else if (isActive !== undefined && isActive !== null) next = isActive ? 'active' : 'inactive';
    if (next === 'on hold' || next === 'on_hold') next = 'hold';
    if (next && !['active', 'hold', 'inactive'].includes(next)) {
      return res.status(400).json({ success: false, message: 'state must be active, hold or inactive' });
    }

    const sets = [];
    const vals = [];
    if (next === 'active') sets.push('is_active = 1', 'is_on_hold = 0', 'on_hold_at = NULL');
    if (next === 'hold') sets.push('is_active = 0', 'is_on_hold = 1', 'on_hold_at = NOW()');
    if (next === 'inactive') sets.push('is_active = 0', 'is_on_hold = 0', 'on_hold_at = NULL');
    if (status !== undefined && status !== null && status !== '') {
      const st = String(status).trim().toLowerCase();
      if (!['draft', 'pending', 'verified', 'complete'].includes(st)) {
        return res.status(400).json({ success: false, message: 'Unknown onboarding status' });
      }
      sets.push('status = ?');
      vals.push(st);
    }
    if (!sets.length) {
      return res.status(400).json({ success: false, message: 'Nothing to update' });
    }

    const [result] = await db.query(
      `UPDATE clients SET ${sets.join(', ')} WHERE id = ?`,
      [...vals, req.params.id],
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: 'Client not found' });
    }

    // Changed group (Active / On Hold / In-Active) → bottom of that group,
    // every S.No renumbered with no gaps.
    if (next) {
      try {
        await withConnection((conn) => renumberClients(conn, { toEnd: Number(req.params.id) }));
      } catch (e) {
        console.error('PATCH /clients renumber failed:', e.message);
      }
    }

    // Open Employee Workspace pages refresh their client cards.
    if (next) req.app.get('io')?.emit('task_updated', { type: 'client_state', clientId: Number(req.params.id), state: next });

    const label = { active: 'Active', hold: 'On Hold', inactive: 'Inactive' }[next];
    return res.json({
      success: true,
      state: next,
      message: label ? `Client set to ${label}` : 'Client status updated',
    });
  } catch (err) {
    console.error('PATCH /clients/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// DELETE /api/clients/:id
router.delete('/:id', async (req, res) => {
  try {
    const [result] = await db.query(`DELETE FROM clients WHERE id = ?`, [req.params.id]);
    if (result.affectedRows === 0)
      return res.status(404).json({ success: false, message: 'Client not found' });
    try {
      await withConnection((conn) => renumberClients(conn));
    } catch (e) {
      console.error('DELETE /clients renumber failed:', e.message);
    }
    return res.json({ success: true, message: 'Client deleted' });
  } catch (err) {
    console.error('DELETE /clients/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

router.get('/list', async (req, res) => {
  try {
    const [clients] = await db.query(
      `SELECT id, company_name FROM clients WHERE status = 'verified' AND is_active = 1 ORDER BY company_name ASC`
    );
 
    res.json({
      success: true,
      data: clients,
    });
  } catch (error) {
    console.error('Error fetching clients:', error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

router.get('/search', async (req, res) => {
  try {
    const { q } = req.query; 
 
    if (!q || q.trim() === '') {
      const [clients] = await db.query(
        `SELECT id, company_name FROM clients WHERE status = 'verified'  AND is_active = 1 ORDER BY company_name ASC LIMIT 20`
      );
      return res.json({
        success: true,
        data: clients,
      });
    }
 
    const searchTerm = `%${q}%`;
    const [clients] = await db.query(
      `SELECT id, company_name FROM clients 
       WHERE status = 'verified'  AND is_active = 1 AND company_name LIKE ? 
       ORDER BY company_name ASC LIMIT 20`,
      [searchTerm]
    );
 
    res.json({
      success: true,
      data: clients,
    });
  } catch (error) {
    console.error('Error searching clients:', error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});
 
// PATCH /api/clients/:id/order  { position }
// Moves the client to that S.No (inside its own Active / On Hold / In-Active
// group) and renumbers everyone 1..N.
router.patch('/:id/order', async (req, res) => {
  const clientId = Number(req.params.id);
  const position = Number(req.body?.position);
  if (!Number.isInteger(clientId) || !Number.isInteger(position) || position < 1) {
    return res.status(400).json({ success: false, message: 'Invalid client id or position' });
  }
  try {
    await ensureHoldColumns();
    const [[exists]] = await db.query('SELECT id FROM clients WHERE id = ?', [clientId]);
    if (!exists) return res.status(404).json({ success: false, message: 'Client not found' });
    await withConnection((conn) => renumberClients(conn, { move: { id: clientId, position } }));
    const [[after]] = await db.query('SELECT display_order FROM clients WHERE id = ?', [clientId]);
    return res.json({
      success: true,
      position: Number(after?.display_order) || position,
      message: 'Client order updated successfully',
    });
  } catch (e) {
    console.error('Client reorder error:', e);
    return res.status(500).json({ success: false, message: e.message });
  }
});

module.exports = router;