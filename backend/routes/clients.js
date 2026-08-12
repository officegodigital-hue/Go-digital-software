// routes/clients.js — Client Onboarding CRUD API (v4: bank details + new % scheme)
const express = require('express');
const router  = express.Router();
const db      = require('../config/db');
 
// ── Completion percentage rules ────────────────────────────────────────────────
// 30% -> company details saved (Save Draft)
// +20% -> bank details fully filled (all 4 fields)
// +30% -> credentials, 5% each, capped at 6 credentials (30%)
// Max before completion = 80%
// 100% -> status = 'complete' (Complete Registration), forced
const FORM_PERCENT       = 30;
const BANK_PERCENT       = 20;
const PER_CREDENTIAL     = 5;
const MAX_CREDENTIALS    = 6; // 6 x 5% = 30%

function computePercent(client, credentialCount) {
  if (client.status === 'complete') return 100;

  let percent = FORM_PERCENT; // company details saved -> 30%

  // Bank details -> +20% only if ALL 4 fields are filled
  const bankFilled =
    !!(client.bank_account_name && client.bank_account_name.trim()) &&
    !!(client.bank_name && client.bank_name.trim()) &&
    !!(client.bank_account_number && client.bank_account_number.trim()) &&
    !!(client.bank_ifsc && client.bank_ifsc.trim());

  if (bankFilled) percent += BANK_PERCENT;

  // Credentials -> 5% each, capped at 6 (30%)
  const credPercent = Math.min(credentialCount, MAX_CREDENTIALS) * PER_CREDENTIAL;
  percent += credPercent;

  return Math.min(80, Math.round(percent));
}

// GET /api/clients — list all clients WITH completion % and credential count
router.get('/', async (req, res) => {
  try {
    // const [clients] = await db.query(`SELECT * FROM clients ORDER BY display_order ASC`);

    const [clients] = await db.query(`
  SELECT *
  FROM clients
  ORDER BY
    CASE
      WHEN is_active = 1 THEN 0
      ELSE 1
    END ASC,
    display_order ASC,
    id ASC
`);

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
    console.error('GET /clients ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ✅ NEW: GET /api/clients/search/query — search clients by company name
// router.get('/search/query', async (req, res) => {
//   try {
//     const query = req.query.query || '';
    
//     if (query.trim().length === 0) {
//       // ✅ ADDED: industry field
//       const [clients] = await db.query(
//         `SELECT id, company_name, industry 
//          FROM clients 
//         WHERE active = 1
//          ORDER BY company_name ASC`
//       );
      
//       return res.json({ success: true, data: clients, });
//     }
    
//     // ✅ ADDED: industry field
//     const [clients] = await db.query(
//       `SELECT id, company_name, industry 
//        FROM clients 
//         WHERE active = 1
//        AND company_name LIKE ? 
//        ORDER BY company_name ASC`,
//       [`%${query}%`]
//     );
 
//     return res.json({ success: true, data: clients });
//   } catch (err) {
//     console.error('GET /clients/search ERROR:', err.message);
//     return res.status(500).json({ success: false, message: err.message });
//   }
// });

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


// GET /api/clients/:id — single client with completion %
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

router.post('/', async (req, res) => {
  const {
    companyName, industry, contactPerson, email, address,
    bankAccountName, bankName, bankAccountNumber, bankIfsc, status,
    clientPhone, gstNumber // Add these
  } = req.body;

  if (!companyName)
    return res.status(400).json({ success: false, message: 'companyName is required' });

  try {
    const [result] = await db.query(
      `INSERT INTO clients
        (company_name,  industry, contact_person, email, address,
         bank_account_name, bank_name, bank_account_number, bank_ifsc, status, client_phone, gst_number)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        companyName,  industry || '', contactPerson || '', email || '', address || '',
        bankAccountName || '', bankName || '', bankAccountNumber || '', bankIfsc || '',
        status || 'draft', clientPhone || '', gstNumber || ''
      ]
    );

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

// Updated PUT /api/clients/:id
router.put('/:id', async (req, res) => {
  console.log("BODY:", req.body);
  console.log("Industry:", req.body.industry);
  const {
    companyName,  industry, contactPerson, email, address,
    bankAccountName, bankName, bankAccountNumber, bankIfsc, status,
    clientPhone, gstNumber // Add these
  } = req.body;

  if (!companyName)
    return res.status(400).json({ success: false, message: 'companyName is required' });

  try {
    const [result] = await db.query(
      `UPDATE clients
       SET company_name = ?,  industry = ?, contact_person = ?, email = ?, address = ?,
           bank_account_name = ?, bank_name = ?, bank_account_number = ?, bank_ifsc = ?,
           status = ?, client_phone = ?, gst_number = ?
       WHERE id = ?`,
      [
        companyName,  industry || '', contactPerson || '', email || '', address || '',
        bankAccountName || '', bankName || '', bankAccountNumber || '', bankIfsc || '',
        status || 'draft', clientPhone || '', gstNumber || '', req.params.id
      ]
    );
    
    if (result.affectedRows === 0)
      return res.status(404).json({ success: false, message: 'Client not found' });

    const [credCount] = await db.query(
      `SELECT COUNT(*) as cnt FROM client_credentials WHERE client_id = ?`,
      [req.params.id]
    );
    
    const completionPercent = computePercent({
      status: status || 'draft',
      bank_account_name: bankAccountName, bank_name: bankName,
      bank_account_number: bankAccountNumber, bank_ifsc: bankIfsc,
    }, credCount[0].cnt);

    return res.json({ success: true, message: 'Client updated', completion_percent: completionPercent });
  } catch (err) {
    console.error('PUT /clients/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});


// PATCH /api/clients/:id/status — quickly update only the status (Verify / Pending button)
// router.patch('/:id/status', async (req, res) => {
//   const { status } = req.body;
//   if (!['draft', 'pending', 'verified', 'complete'].includes(status))
//     return res.status(400).json({ success: false, message: 'Invalid status value' });

//   try {
//     const [result] = await db.query(
//       `UPDATE clients SET status = ? WHERE id = ?`,
//       [status, req.params.id]
//     );
//     if (result.affectedRows === 0)
//       return res.status(404).json({ success: false, message: 'Client not found' });

//     const [rows] = await db.query(`SELECT * FROM clients WHERE id = ?`, [req.params.id]);
//     const [credCount] = await db.query(
//       `SELECT COUNT(*) as cnt FROM client_credentials WHERE client_id = ?`,
//       [req.params.id]
//     );
//     const completionPercent = computePercent(rows[0], credCount[0].cnt);

//     return res.json({ success: true, message: `Status updated to ${status}`, completion_percent: completionPercent });
//   } catch (err) {
//     console.error('PATCH /clients/:id/status ERROR:', err.message);
//     return res.status(500).json({ success: false, message: err.message });
//   }
// });

// PATCH /api/clients/:id
router.patch('/:id', async (req, res) => {
  try {
    const { isActive } = req.body;

    const [result] = await db.query(
      `UPDATE clients
       SET is_active = ?
       WHERE id = ?`,
      [isActive ? 1 : 0, req.params.id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({
        success: false,
        message: 'Client not found',
      });
    }

    res.json({
      success: true,
      message: 'Client status updated',
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({
      success: false,
      message: err.message,
    });
  }
});

// DELETE /api/clients/:id
router.delete('/:id', async (req, res) => {
  try {
    const [result] = await db.query(`DELETE FROM clients WHERE id = ?`, [req.params.id]);
    if (result.affectedRows === 0)
      return res.status(404).json({ success: false, message: 'Client not found' });
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
    const { q } = req.query; // search query parameter
 
    if (!q || q.trim() === '') {
      // If no search, return all
      const [clients] = await db.query(
        `SELECT id, company_name FROM clients WHERE status = 'verified'  AND is_active = 1 ORDER BY company_name ASC LIMIT 20`
      );
      return res.json({
        success: true,
        data: clients,
      });
    }
 
    // Search by company name
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
 
// ✅ GET single client details
// router.get('/:id', async (req, res) => {
//   try {
//     const { id } = req.params;
 
//     const [clients] = await db.query(
//       `SELECT * FROM clients WHERE id = ?`,
//       [id]
//     );
 
//     if (clients.length === 0) {
//       return res.status(404).json({
//         success: false,
//         error: 'Client not found',
//       });
//     }
 
//     res.json({
//       success: true,
//       data: clients[0],
//     });
//   } catch (error) {
//     console.error('Error fetching client:', error);
//     res.status(500).json({
//       success: false,
//       error: error.message,
//     });
//   }
// });

router.patch('/clients/:id', async (req, res) => {
  const { isActive } = req.body;

  await db.query(
    'UPDATE clients SET is_active=? WHERE id=?',
    [isActive ? 1 : 0, req.params.id]
  );

  res.json({
    success: true,
  });
});

// PATCH /api/clients/:id/order
router.patch('/:id/order', async (req, res) => {
  const conn = await db.getConnection();

  try {
    await conn.beginTransaction();

    const clientId = Number(req.params.id);
    const requestedPos = Number(req.body.position);

    if (!Number.isInteger(clientId) || !Number.isInteger(requestedPos)) {
      await conn.rollback();
      return res.status(400).json({
        success: false,
        message: 'Invalid client id or position',
      });
    }

    // ---------------------------------------------------------
    // Get all clients in the correct base order
    // Active first, Inactive last
    // ---------------------------------------------------------
    const [clients] = await conn.query(
      `
      SELECT id, display_order, is_active
      FROM clients
      ORDER BY
        is_active DESC,
        CASE
          WHEN display_order IS NULL OR display_order <= 0 THEN 999999
          ELSE display_order
        END ASC,
        id ASC
      FOR UPDATE
      `
    );

    if (!clients.length) {
      await conn.rollback();

      return res.status(404).json({
        success: false,
        message: 'No clients found',
      });
    }

    const clientIndex = clients.findIndex(
      c => Number(c.id) === clientId
    );

    if (clientIndex === -1) {
      await conn.rollback();

      return res.status(404).json({
        success: false,
        message: 'Client not found',
      });
    }

    const selectedClient = clients[clientIndex];

    // ---------------------------------------------------------
    // Separate Active / Inactive
    // ---------------------------------------------------------
    let activeClients = clients.filter(
      c => Number(c.is_active) === 1
    );

    let inactiveClients = clients.filter(
      c => Number(c.is_active) !== 1
    );

    // ---------------------------------------------------------
    // Reorder ONLY inside the client's group
    //
    // Active client:
    //   position 1 = first active
    //
    // Inactive client:
    //   position 1 = first inactive
    // ---------------------------------------------------------
    if (Number(selectedClient.is_active) === 1) {
      const currentIndex = activeClients.findIndex(
        c => Number(c.id) === clientId
      );

      let targetIndex = requestedPos - 1;

      // Keep within active list
      targetIndex = Math.max(
        0,
        Math.min(targetIndex, activeClients.length - 1)
      );

      const [movedClient] = activeClients.splice(
        currentIndex,
        1
      );

      activeClients.splice(
        targetIndex,
        0,
        movedClient
      );
    } else {
      const currentIndex = inactiveClients.findIndex(
        c => Number(c.id) === clientId
      );

      let targetIndex = requestedPos - 1;

      // Keep within inactive list
      targetIndex = Math.max(
        0,
        Math.min(targetIndex, inactiveClients.length - 1)
      );

      const [movedClient] = inactiveClients.splice(
        currentIndex,
        1
      );

      inactiveClients.splice(
        targetIndex,
        0,
        movedClient
      );
    }

    // ---------------------------------------------------------
    // Final order:
    //
    // Active
    // 1
    // 2
    // 3
    //
    // Inactive
    // 4
    // 5
    // 6
    // ---------------------------------------------------------
    const finalClients = [
      ...activeClients,
      ...inactiveClients,
    ];

    // ---------------------------------------------------------
    // First give temporary negative values.
    //
    // This avoids duplicate display_order conflicts if
    // display_order has UNIQUE constraint.
    // ---------------------------------------------------------
    for (let i = 0; i < finalClients.length; i++) {
      await conn.query(
        `
        UPDATE clients
        SET display_order = ?
        WHERE id = ?
        `,
        [
          -(i + 1),
          finalClients[i].id,
        ]
      );
    }

    // ---------------------------------------------------------
    // Now save clean 1..N sequence
    // ---------------------------------------------------------
    for (let i = 0; i < finalClients.length; i++) {
      await conn.query(
        `
        UPDATE clients
        SET display_order = ?
        WHERE id = ?
        `,
        [
          i + 1,
          finalClients[i].id,
        ]
      );
    }

    await conn.commit();

    return res.json({
      success: true,
      message: 'Client order updated successfully',
    });

  } catch (e) {
    await conn.rollback();

    console.error('Client reorder error:', e);

    return res.status(500).json({
      success: false,
      message: e.message,
    });

  } finally {
    conn.release();
  }
});

module.exports = router;