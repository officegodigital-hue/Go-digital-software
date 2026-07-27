// routes/day-planner.js — Day Plan Sheet: save, fetch (filtered by employee
// + date), and submit (locks rows + notifies Admin).
const express = require('express');
const router  = express.Router();
const db      = require('../config/db');
const { createNotification } = require('./notifications');

// GET /api/day-planner?employeeName=Arun&date=2026-07-09
router.get('/', async (req, res) => {
  const { employeeName, date } = req.query;

  if (!employeeName || !date) {
    return res.status(400).json({ success: false, message: 'employeeName and date are required' });
  }

  try {
    const [rows] = await db.query(
      `SELECT *, DATE_FORMAT(plan_date, '%Y-%m-%d') AS plan_date_str
       FROM day_plan_rows WHERE employee_name = ? AND plan_date = ? ORDER BY id ASC`,
      [employeeName, date]
    );

    const data = rows.map((r) => ({
      id: r.id,
      date: r.plan_date,
      client: r.client_name || '',
      ads: r.ads || '',
      today_leads: r.today_leads || '',
      today_report: r.today_report || '',

      deliverables_1: r.deliverables_1 || '',
      complete_deliverables_1: r.complete_deliverables_1 || '',
      balanced_deliverables_1: r.balanced_deliverables_1 || '',

      deliverables_2: r.deliverables_2 || '',
      complete_deliverables_2: r.complete_deliverables_2 || '',
      balanced_deliverables_2: r.balanced_deliverables_2 || '',

      deliverables_3: r.deliverables_3 || '',
      complete_deliverables_3: r.complete_deliverables_3 || '',
      balanced_deliverables_3: r.balanced_deliverables_3 || '',

      today_plan: r.today_plan || '',
      status: r.status || '',
      remarks: r.remarks || '',
      isSubmitted: !!r.is_submitted,
    }));

    return res.json({ success: true, data });
  } catch (err) {
    console.error('GET /day-planner ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/day-planner — create a new row
router.post('/', async (req, res) => {
  const {
    employeeName, employeeRole, date, client, ads, todayLeads, todayReport,
    deliverables1, completeDeliverables1, balancedDeliverables1,
    deliverables2, completeDeliverables2, balancedDeliverables2,
    deliverables3, completeDeliverables3, balancedDeliverables3,
    todayPlan, status, remarks,
  } = req.body;

  if (!employeeName || !date) {
    return res.status(400).json({ success: false, message: 'employeeName and date are required' });
  }

  try {
    const [result] = await db.query(
      `INSERT INTO day_plan_rows
        (employee_name, employee_role, plan_date, client_name, ads, today_leads, today_report,
         deliverables_1, complete_deliverables_1, balanced_deliverables_1,
         deliverables_2, complete_deliverables_2, balanced_deliverables_2,
         deliverables_3, complete_deliverables_3, balanced_deliverables_3,
         today_plan, status, remarks)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        employeeName, employeeRole || null, date, client || null, ads || null,
        todayLeads || null, todayReport || null,
        deliverables1 || null, completeDeliverables1 || null, balancedDeliverables1 || null,
        deliverables2 || null, completeDeliverables2 || null, balancedDeliverables2 || null,
        deliverables3 || null, completeDeliverables3 || null, balancedDeliverables3 || null,
        todayPlan || null, status || null, remarks || null,
      ]
    );

    return res.status(201).json({ success: true, message: 'Row created', data: { id: result.insertId } });
  } catch (err) {
    console.error('POST /day-planner ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

router.delete('/:id', async (req, res) => {
  try {
    const [result] = await db.query(
      `DELETE FROM day_plan_rows WHERE id = ?`,
      [req.params.id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({
        success: false,
        message: 'Row not found'
      });
    }

    return res.json({
      success: true,
      message: 'Row deleted'
    });

  } catch (err) {
    console.error(err);
    return res.status(500).json({
      success: false,
      message: err.message
    });
  }
});

// PUT /api/day-planner/:id — update/save an existing row
router.put('/:id', async (req, res) => {
  const { id } = req.params;
  const {
    client, ads, todayLeads, todayReport,
    deliverables1, completeDeliverables1, balancedDeliverables1,
    deliverables2, completeDeliverables2, balancedDeliverables2,
    deliverables3, completeDeliverables3, balancedDeliverables3,
    todayPlan, status, remarks,
  } = req.body;

  try {
    const [result] = await db.query(
      `UPDATE day_plan_rows SET
        client_name = ?, ads = ?, today_leads = ?, today_report = ?,
        deliverables_1 = ?, complete_deliverables_1 = ?, balanced_deliverables_1 = ?,
        deliverables_2 = ?, complete_deliverables_2 = ?, balanced_deliverables_2 = ?,
        deliverables_3 = ?, complete_deliverables_3 = ?, balanced_deliverables_3 = ?,
        today_plan = ?, status = ?, remarks = ?
       WHERE id = ?`,
      [
        client || null, ads || null, todayLeads || null, todayReport || null,
        deliverables1 || null, completeDeliverables1 || null, balancedDeliverables1 || null,
        deliverables2 || null, completeDeliverables2 || null, balancedDeliverables2 || null,
        deliverables3 || null, completeDeliverables3 || null, balancedDeliverables3 || null,
        todayPlan || null, status || null, remarks || null,
        id,
      ]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: 'Row not found' });
    }

    return res.json({ success: true, message: 'Row saved' });
  } catch (err) {
    console.error('PUT /day-planner/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// DELETE /api/day-planner/:id
router.delete('/:id', async (req, res) => {
  try {
    const [result] = await db.query(`DELETE FROM day_plan_rows WHERE id = ?`, [req.params.id]);
    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: 'Row not found' });
    }
    return res.json({ success: true, message: 'Row deleted' });
  } catch (err) {
    console.error('DELETE /day-planner/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/day-planner/submit — locks every row for this employee/date
// and notifies Admin.
router.post('/submit', async (req, res) => {
  const { employeeName, date } = req.body;

  if (!employeeName || !date) {
    return res.status(400).json({ success: false, message: 'employeeName and date are required' });
  }

try {

  // Get submitted planner rows
  const [plannerRows] = await db.query(
    `
    SELECT *
    FROM day_plan_rows
    WHERE employee_name = ?
    AND plan_date = ?
    ORDER BY id ASC
    `,
    [
      employeeName,
      date
    ]
  );


  const [admins] = await db.query(
    `
    SELECT full_name 
    FROM employee_users
    WHERE user_type = 'admin'
    AND is_active = 1
    `
  );


  for (const admin of admins) {


    await createNotification({

      senderName: employeeName,

      recipientName: admin.full_name,


      message: JSON.stringify({

        preview: `${employeeName} submitted Day Planner`,


        payload: {

          type: "PLAN_SUBMITTED",

          sender: employeeName,

          recipient: admin.full_name,

          date: date,


          plannerData: plannerRows

        }

      })

    });


  }


}
catch(notifyErr){

 console.error(
 "Day planner notification failed:",
 notifyErr.message
 );

}
});

router.get('/progress/:employee/:client', async (req, res) => {
  try {

    const employee = req.params.employee;
    const client = req.params.client;

    const [rows] = await db.query(`
SELECT
    tl.id,
    tl.deliverables,
    tl.no_of_rows,

    (
        SELECT COUNT(*)
        FROM time_tracking_task_items tti
        WHERE tti.task_list_id = tl.id
        AND tti.status='COMPLETED'
    ) completed

FROM task_list tl

WHERE
tl.employee_name=?
AND tl.client_name=?
ORDER BY tl.id
`,
[
employee,
client
]);

const data = rows.map(r=>({

deliverable:r.deliverables,

completed:`${r.completed}/${r.no_of_rows}`,

balance:`${r.no_of_rows-r.completed}/${r.no_of_rows}`

}));

return res.json({
success:true,
data
});

  } catch(err){
      console.log(err);
      res.status(500).json({
        success:false,
        message:err.message
      });
  }
});

router.get("/today/:employee", async (req, res) => {
  try {
    const employee = req.params.employee;
    // Get the date from the query string (e.g., /api/day-planner/today/Arun?date=2026-07-10)
    const { date } = req.query; 

    // If a date is provided, filter by it; otherwise, default to today's date
    const sql = `
      SELECT *, DATE_FORMAT(plan_date, '%Y-%m-%d') AS plan_date_str
      FROM day_plan_rows
      WHERE employee_name = ?
      AND DATE(plan_date) = ${date ? '?' : 'CURDATE()'}
      ORDER BY id
    `;

    const params = date ? [employee, date] : [employee];
    const [rows] = await db.query(sql, params);

    const data = rows.map((r) => ({
      id: r.id,
      date: r.plan_date_str,
      client: r.client_name || '',
      ads: r.ads || '',
      today_leads: r.today_leads || '',
      today_report: r.today_report || '',
      deliverables_1: r.deliverables_1 || '',
      complete_deliverables_1: r.complete_deliverables_1 || '',
      balanced_deliverables_1: r.balanced_deliverables_1 || '',
      deliverables_2: r.deliverables_2 || '',
      complete_deliverables_2: r.complete_deliverables_2 || '',
      balanced_deliverables_2: r.balanced_deliverables_2 || '',
      deliverables_3: r.deliverables_3 || '',
      complete_deliverables_3: r.complete_deliverables_3 || '',
      balanced_deliverables_3: r.balanced_deliverables_3 || '',
      today_plan: r.today_plan || '',
      status: r.status || '',
      remarks: r.remarks || '',
      isSubmitted: !!r.is_submitted,
    }));

    res.json(data);
  } catch (err) {
    console.error('GET /day-planner/today/:employee ERROR:', err.message);
    res.status(500).json({ success: false, message: err.message });
  }
});

router.get('/status/:employeeName', async (req, res) => {
  const { employeeName } = req.params;
 
  try {
    const now = new Date();
    const date = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
 
    const [rows] = await db.query(
      `SELECT COUNT(*) AS cnt FROM day_plan_rows WHERE employee_name = ? AND plan_date = ? AND is_submitted = 1`,
      [employeeName, date]
    );
    const submitted = rows[0].cnt > 0;
 
    const minutesNow = now.getHours() * 60 + now.getMinutes();
    const t930 = 9 * 60 + 30;
    const t945 = 9 * 60 + 45;
    const t1000 = 10 * 60;
 
    // Tier escalates the later it gets, but ONLY matters if not submitted.
    let deadlineLevel = 'none';
    if (!submitted) {
      if (minutesNow >= t1000) deadlineLevel = 'admin_notified';
      else if (minutesNow >= t945) deadlineLevel = 'urgent';
      else if (minutesNow >= t930) deadlineLevel = 'warning';
    }
 
    return res.json({
      success: true,
      data: { submitted, deadlineLevel, date },
    });
  } catch (err) {
    console.error('GET /day-planner/status ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});




module.exports = router;