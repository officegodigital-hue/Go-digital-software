// backend/routes/contentCalendarRoutes.js
const express = require('express');
const router = express.Router();
const db = require('../config/db');

// GET /api/content-calendar/clients
router.get('/clients', async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT 
          c.id, 
          c.company_name, 
          COUNT(cc.id) AS allocated_count,
          SUM(CASE WHEN tti.status = 'COMPLETED' THEN 1 ELSE 0 END) AS completed_count,
          SUM(CASE WHEN tti.status IS NULL OR tti.status IN ('IDLE', 'PENDING', 'ON HOLD') THEN 1 ELSE 0 END) AS pending_count
       FROM clients c
       LEFT JOIN content_calendar cc ON cc.client_id = c.id
       LEFT JOIN time_tracking_task_items tti ON tti.id = cc.task_item_id
       WHERE c.is_active = 1
       GROUP BY c.id, c.company_name
       ORDER BY c.company_name ASC`
    );

    return res.json({ success: true, clients: rows });
  } catch (err) {
    console.error('GET /content-calendar/clients ERROR:', err.message);
    return res.status(500).json({ success: false, error: err.message });
  }
});

// GET /api/content-calendar/creative-team
router.get('/creative-team', async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT id, full_name, role 
       FROM employee_users 
       WHERE is_active = 1 
       ORDER BY role ASC, full_name ASC`
    );
    return res.json({ success: true, employees: rows });
  } catch (err) {
    console.error('GET /content-calendar/creative-team ERROR:', err.message);
    return res.status(500).json({ success: false, error: err.message });
  }
});

// GET /api/content-calendar/:clientId
router.get('/:clientId', async (req, res) => {
  try {
    const { clientId } = req.params;
    const [rows] = await db.query(
      `SELECT 
          cc.*, 
          DATE_FORMAT(cc.publish_date, '%Y-%m-%d') AS publish_date,
          DATE_FORMAT(cc.submit_date, '%Y-%m-%d') AS submit_date,
          tti.status AS task_status,
          tti.review_status,
          tti.duration_secs
       FROM content_calendar cc
       LEFT JOIN time_tracking_task_items tti ON tti.id = cc.task_item_id
       WHERE cc.client_id = ?
       ORDER BY cc.s_no ASC, cc.id ASC`,
      [clientId]
    );

    return res.json({ success: true, rows });
  } catch (err) {
    console.error('GET /content-calendar/:clientId ERROR:', err.message);
    return res.status(500).json({ success: false, error: err.message });
  }
});

// POST /api/content-calendar/assign
router.post('/assign', async (req, res) => {
  const {
    calendar_id,
    client_id,
    deliverable,
    hook_headline,
    description,
    caption,
    cta,
    publish_date,
    submit_date,
    assigned_to_id
  } = req.body;

  const assignedById = req.user?.id || req.body.assigned_by_id;
  const assignedByName = req.user?.full_name || req.body.assigned_by_name || 'Handler';

  const connection = await db.getConnection();
  try {
    await connection.beginTransaction();

    let targetEmpName = 'Unassigned';
    if (assigned_to_id) {
      const [empRows] = await connection.query('SELECT full_name FROM employee_users WHERE id = ?', [assigned_to_id]);
      if (empRows.length) targetEmpName = empRows[0].full_name;
    }

    const [clientRows] = await connection.query('SELECT company_name FROM clients WHERE id = ?', [client_id]);
    const clientName = clientRows.length ? clientRows[0].company_name : 'Client';

    let taskListId;
    const [tlRows] = await connection.query(
      `SELECT id FROM task_list WHERE client_name = ? AND employee_id = ? LIMIT 1`,
      [clientName, assigned_to_id]
    );

    if (tlRows.length) {
      taskListId = tlRows[0].id;
    } else {
      const [tlIns] = await connection.query(
        `INSERT INTO task_list (client_name, employee_id, employee_name, deliverables)
         VALUES (?, ?, ?, ?)`,
        [clientName, assigned_to_id, targetEmpName, deliverable]
      );
      taskListId = tlIns.insertId;
    }

    let taskItemId;
    if (calendar_id) {
      const [cal] = await connection.query('SELECT task_item_id FROM content_calendar WHERE id = ?', [calendar_id]);
      if (cal.length && cal[0].task_item_id) {
        taskItemId = cal[0].task_item_id;
        await connection.query(
          `UPDATE time_tracking_task_items 
           SET task_description = ?, submit_date = ? 
           WHERE id = ?`,
          [hook_headline, submit_date || null, taskItemId]
        );
      }
    }

    if (!taskItemId) {
      const [insItem] = await connection.query(
        `INSERT INTO time_tracking_task_items 
          (task_list_id, s_no, submit_date, task_description, duration_secs, status)
         VALUES (?, 1, ?, ?, 0, 'IDLE')`,
        [taskListId, submit_date || null, hook_headline]
      );
      taskItemId = insItem.insertId;
    }

    if (calendar_id) {
      await connection.query(
        `UPDATE content_calendar 
         SET deliverable = ?, hook_headline = ?, description = ?, caption = ?, cta = ?, 
             publish_date = ?, submit_date = ?, assigned_to_id = ?, assigned_to_name = ?, 
             assigned_by_id = ?, assigned_by_name = ?, task_item_id = ?
         WHERE id = ?`,
        [
          deliverable, hook_headline, description, caption, cta,
          publish_date || null, submit_date || null, assigned_to_id, targetEmpName,
          assignedById, assignedByName, taskItemId, calendar_id
        ]
      );
    } else {
      await connection.query(
        `INSERT INTO content_calendar 
          (client_id, client_name, deliverable, hook_headline, description, caption, cta, 
           publish_date, submit_date, assigned_to_id, assigned_to_name, assigned_by_id, assigned_by_name, task_item_id)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          client_id, clientName, deliverable, hook_headline, description, caption, cta,
          publish_date || null, submit_date || null, assigned_to_id, targetEmpName,
          assignedById, assignedByName, taskItemId
        ]
      );
    }

    if (assigned_to_id) {
      await connection.query(
        `INSERT INTO notifications (sender_name, recipient_name, message)
         VALUES (?, ?, ?)`,
        [
          assignedByName,
          targetEmpName,
          `New ${deliverable} content deliverable assigned: "${hook_headline}" for ${clientName}.`
        ]
      );
    }

    await connection.commit();

    const io = req.app.get('io');
    if (io) {
      io.emit('calendar:assigned', {
        client_id,
        deliverable,
        hook_headline,
        assigned_to_name: targetEmpName
      });
    }

    return res.json({ success: true, message: 'Content brief assigned successfully', task_item_id: taskItemId });
  } catch (err) {
    await connection.rollback();
    console.error('POST /content-calendar/assign ERROR:', err.message);
    return res.status(500).json({ success: false, error: err.message });
  } finally {
    connection.release();
  }
});

module.exports = router;