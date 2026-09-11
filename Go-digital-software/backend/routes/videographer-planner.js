// routes/videographer-planner.js
const express = require('express');
const router  = express.Router();
const db      = require('../config/db');

const { createNotification } = require('./notifications');

// ── Default sections for videographer ────────────────────────────────────────
const DEFAULT_SECTIONS = 5; // 5 empty rows by default

// GET /api/videographer-planner?employee=NAME
router.get('/', async (req, res) => {
  const { employee } = req.query;
  if (!employee)
    return res.status(400).json({ success: false, message: 'employee required' });
  try {
    const [rows] = await db.query(
      `SELECT * FROM videographer_planner
       WHERE UPPER(employee_name) = ? ORDER BY created_at ASC`,
      [employee.toUpperCase()]
    );
    return res.json({ success: true, data: rows });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/videographer-planner/shares?employee=NAME
// router.get('/shares', async (req, res) => {
//   const { employee } = req.query;
//   if (!employee)
//     return res.status(400).json({ success: false, message: 'employee required' });
//   try {
//     const [rows] = await db.query(
//       `SELECT * FROM videographer_planner_shares
//        WHERE UPPER(sender_employee_name) = ? ORDER BY shared_at DESC`,
//       [employee.toUpperCase()]
//     );
//     return res.json({ success: true, data: rows });
//   } catch (err) {
//     return res.status(500).json({ success: false, message: err.message });
//   }
// });
router.get('/shares', async (req, res) => {
  const { employee } = req.query;

  if (!employee) {
    return res.status(400).json({
      success: false,
      message: 'employee required',
    });
  }

  try {
    const [rows] = await db.query(
      `SELECT * FROM videographer_planner_shares
       WHERE UPPER(sender_employee_name) = ?
       ORDER BY shared_at DESC`,
      [employee.toUpperCase()]
    );

    return res.json({
      success: true,
      data: rows,
    });
  } catch (err) {
    return res.status(500).json({
      success: false,
      message: err.message,
    });
  }
});

// POST /api/videographer-planner — create a new row
// router.post('/', async (req, res) => {
//   const { employeeName, clientName = '', schedulingDetails = '' } = req.body;
//   if (!employeeName)
//     return res.status(400).json({ success: false, message: 'employeeName required' });
//   try {
//     const [result] = await db.query(
//       `INSERT INTO videographer_planner (employee_name, client_name, scheduling_details)
//        VALUES (?, ?, ?)`,
//       [employeeName.toUpperCase(), clientName, schedulingDetails]
//     );
//     return res.status(201).json({ success: true, data: { id: result.insertId } });
//   } catch (err) {
//     return res.status(500).json({ success: false, message: err.message });
//   }
// });



// PUT /api/videographer-planner/:id — save before sharing
// router.put('/:id', async (req, res) => {
//   const { clientName, schedulingDetails } = req.body;
//   try {
//     const [result] = await db.query(
//       `UPDATE videographer_planner SET client_name = ?, scheduling_details = ? WHERE id = ?`,
//       [clientName || '', schedulingDetails || '', req.params.id]
//     );
//     if (result.affectedRows === 0)
//       return res.status(404).json({ success: false, message: 'Row not found' });
//     return res.json({ success: true, message: 'Updated' });
//   } catch (err) {
//     return res.status(500).json({ success: false, message: err.message });
//   }
// });

// PUT /api/videographer-planner/:id
// PUT /api/videographer-planner/:id — Update share history record
// PUT /api/videographer-planner/:id
router.put('/:id', async (req, res) => {
  const {
    clientName,
    schedulingDetails,
    status,
  } = req.body;

  // Status-ai uppercase-a mathi, empty-ah iruntha 'PROCESS' set panrathu
  const finalStatus = (status || 'PROCESS').toUpperCase();

  try {
    const [[share]] = await db.query(
  `SELECT sender_employee_name, receiver_employee_name
   FROM videographer_planner_shares
   WHERE id = ?`,
  [req.params.id]
);

if (!share) {
  return res.status(404).json({
    success: false,
    message: "History record not found",
  });
}

    const [result] = await db.query(
      `UPDATE videographer_planner_shares
       SET client_name = ?,
           scheduling_details = ?,
           status = ?
       WHERE id = ?`,
      [
        clientName || '',
        schedulingDetails || '',
        finalStatus,
        req.params.id,
      ]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({
        success: false,
        message: 'History record not found',
      });
    }
    await createNotification({
   recipientName: share.receiver_employee_name,
   senderName: share.sender_employee_name,
  message: JSON.stringify({
    preview: `${share.sender_employee_name} updated your shared video task`,
    payload: {
      type: "VIDEOGRAPHER_SHARE_UPDATED",
      clientName,
      schedulingDetails,
      status: finalStatus,
      updatedAt: new Date(),
    },
  }),
});

    return res.json({
      success: true,
      message: 'Updated successfully',
    });

  } catch (err) {
    console.error("Database Update Error:", err.message);
    return res.status(500).json({
      success: false,
      message: err.message,
    });
  }
});

// PATCH /api/videographer-planner/:id/share
// INSERTs new record into videographer_planner_shares, clears row fields
router.patch('/:id/share', async (req, res) => {
  const {
    senderEmployeeName, senderEmployeeId,
    clientName, schedulingDetails,
    status,
    receiverEmployeeName, receiverEmployeeId,
    receiverRole, receiverShort,
  } = req.body;

  if (!senderEmployeeName || !receiverEmployeeName || !receiverRole)
    return res.status(400).json({ success: false, message: 'senderEmployeeName, receiverEmployeeName and receiverRole required' });

  const connection = await db.getConnection();
  try {
    await connection.beginTransaction();

    // INSERT new share record — never update
    await connection.query(
      `INSERT INTO videographer_planner_shares
         (planner_id, sender_employee_name, sender_employee_id,
          client_name, scheduling_details, status,
          receiver_employee_name, receiver_employee_id, receiver_role, receiver_short)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?,?)`,
      [
        req.params.id,
        senderEmployeeName.toUpperCase(), senderEmployeeId || null,
        clientName || '', schedulingDetails || '',
  status || 'PROCESS',
        receiverEmployeeName, receiverEmployeeId || null,
        receiverRole, receiverShort || '',
      ]
    );

await createNotification({
  senderName: senderEmployeeName,
  recipientName: receiverEmployeeName,
  message: JSON.stringify({
    preview: `Video Task shared by ${senderEmployeeName}`,
    payload: {
      type: "VIDEOGRAPHER_SHARE",
      sender: senderEmployeeName,
      client: clientName,
      schedulingDetails: schedulingDetails,
      status: status || "PROCESS",
      sharedAt: new Date(),
    }
  }),
});

    // Clear fields on main row so it's ready for next entry
    await connection.query(
      `UPDATE videographer_planner SET client_name = '', scheduling_details = '',
       status = 'PROCESS' WHERE id = ?`,
      [req.params.id]
    );

    await connection.commit();
    return res.json({ success: true, message: 'Share saved as new record' });
  } catch (err) {
    await connection.rollback();
    return res.status(500).json({ success: false, message: err.message });
  } finally {
    connection.release();
  }
});

// PATCH /api/videographer-planner/:id/reset
router.patch('/:id/reset', async (req, res) => {
  try {
    await db.query(
      `UPDATE videographer_planner SET client_name = '', scheduling_details = '', status ='PROCESS'  WHERE id = ?`,
      [req.params.id]
    );
    return res.json({ success: true, message: 'Row reset' });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// DELETE /api/videographer-planner/:id
router.delete('/:id', async (req, res) => {
  try {

    const [[share]] = await db.query(
  `SELECT sender_employee_name, receiver_employee_name
   FROM videographer_planner_shares
   WHERE id = ?`,
  [req.params.id]
);

if (!share) {
  return res.status(404).json({
    success: false,
    message: "History record not found",
  });
}

    const [result] = await db.query(
      `DELETE FROM videographer_planner_shares WHERE id = ?`,
      [req.params.id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({
        success: false,
        message: 'History record not found',
      });
    }
    await createNotification({
  senderName: share.sender_employee_name,
  recipientName: share.receiver_employee_name,
  message: JSON.stringify({
    preview: `${share.sender_employee_name} deleted your shared video task`,
    payload: {
      type: "VIDEOGRAPHER_SHARE_DELETED",
      deletedAt: new Date(),
    },
  }),
});

    return res.json({
      success: true,
      message: 'Deleted successfully',
    });

  } catch (err) {
    return res.status(500).json({
      success: false,
      message: err.message,
    });
  }
});

module.exports = router;