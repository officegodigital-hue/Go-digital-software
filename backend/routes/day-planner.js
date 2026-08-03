// routes/day-planner.js — Day Plan Sheet: save, fetch (filtered by employee
// + date), and submit (locks rows + notifies Admin).
const express = require('express');
const router  = express.Router();
const db      = require('../config/db');
const { createNotification } = require('./notifications');

// GET /api/day-planner?employeeName=Arun&date=2026-07-09
router.get('/', async (req, res) => {
  // const { employeeName, date } = req.query;
  const { employeeName, date, reportType } = req.query;

  if (!employeeName || !date) {
    return res.status(400).json({ success: false, message: 'employeeName and date are required' });
  }

  try {
    const [rows] = await db.query(
      `SELECT *, DATE_FORMAT(plan_date, '%Y-%m-%d') AS plan_date_str
       FROM day_plan_rows WHERE employee_name = ? AND plan_date = ? AND report_type = ? ORDER BY id ASC`,
      [employeeName, date, reportType || "Morning"]
    );

    const data = rows.map((r) => ({
      id: r.id,
      date: r.plan_date,
      client: r.client_name || '',
      maintenance_date: r.maintenance_date || '',
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

      deliverables_4: r.deliverables_4 || '',
      complete_deliverables_4: r.complete_deliverables_4 || '',
      balanced_deliverables_4: r.balanced_deliverables_4 || '',

      deliverables_5: r.deliverables_5 || '',
      complete_deliverables_5: r.complete_deliverables_5 || '',
      balanced_deliverables_5: r.balanced_deliverables_5 || '',

      deliverables_6: r.deliverables_6 || '',
      complete_deliverables_6: r.complete_deliverables_6 || '',
      balanced_deliverables_6: r.balanced_deliverables_6 || '',
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
    employeeName, employeeRole, date, reportType, client, maintenanceDate,  ads, todayLeads, todayReport,
    deliverables1, completeDeliverables1, balancedDeliverables1,
    deliverables2, completeDeliverables2, balancedDeliverables2,
    deliverables3, completeDeliverables3, balancedDeliverables3,
    deliverables4, completeDeliverables4, balancedDeliverables4,
    deliverables5, completeDeliverables5, balancedDeliverables5,
    deliverables6, completeDeliverables6, balancedDeliverables6,
    todayPlan, status, remarks,
  } = req.body;

  if (!employeeName || !date) {
    return res.status(400).json({ success: false, message: 'employeeName and date are required' });
  }

  try {
    const [result] = await db.query(
      `INSERT INTO day_plan_rows
        (employee_name, employee_role, plan_date, report_type, client_name,  maintenance_date,  ads, today_leads, today_report,
         deliverables_1, complete_deliverables_1, balanced_deliverables_1,
         deliverables_2, complete_deliverables_2, balanced_deliverables_2,
         deliverables_3, complete_deliverables_3, balanced_deliverables_3,
         deliverables_4, complete_deliverables_4, balanced_deliverables_4,
         deliverables_5, complete_deliverables_5, balanced_deliverables_5,
         deliverables_6, complete_deliverables_6, balanced_deliverables_6,
         today_plan, status, remarks)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?,?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        employeeName, employeeRole || null, date, reportType || "Morning", client || null, maintenanceDate || null, ads || null,
        todayLeads || null, todayReport || null,
        deliverables1 || null, completeDeliverables1 || null, balancedDeliverables1 || null,
        deliverables2 || null, completeDeliverables2 || null, balancedDeliverables2 || null,
        deliverables3 || null, completeDeliverables3 || null, balancedDeliverables3 || null,
        deliverables4 || null, completeDeliverables4 || null, balancedDeliverables4 || null,
        deliverables5 || null, completeDeliverables5 || null, balancedDeliverables5 || null,
        deliverables6 || null, completeDeliverables6 || null, balancedDeliverables6 || null,
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
    client,maintenanceDate, ads, todayLeads, todayReport,
    deliverables1, completeDeliverables1, balancedDeliverables1,
    deliverables2, completeDeliverables2, balancedDeliverables2,
    deliverables3, completeDeliverables3, balancedDeliverables3,
    deliverables4, completeDeliverables4, balancedDeliverables4,
    deliverables5, completeDeliverables5, balancedDeliverables5,
    deliverables6, completeDeliverables6, balancedDeliverables6,
    todayPlan, status, remarks,
  } = req.body;

  try {
    const [result] = await db.query(
      `UPDATE day_plan_rows SET
        client_name = ?, maintenance_date=?,  ads = ?, today_leads = ?, today_report = ?,
        deliverables_1 = ?, complete_deliverables_1 = ?, balanced_deliverables_1 = ?,
        deliverables_2 = ?, complete_deliverables_2 = ?, balanced_deliverables_2 = ?,
        deliverables_3 = ?, complete_deliverables_3 = ?, balanced_deliverables_3 = ?,
        deliverables_4 = ?, complete_deliverables_4 = ?, balanced_deliverables_4 = ?,
        deliverables_5 = ?, complete_deliverables_5 = ?, balanced_deliverables_5 = ?,
        deliverables_6 = ?, complete_deliverables_6 = ?, balanced_deliverables_6 = ?,
        today_plan = ?, status = ?, remarks = ?
       WHERE id = ?`,
      [
        client || null, maintenanceDate || null, ads || null, todayLeads || null, todayReport || null,
        deliverables1 || null, completeDeliverables1 || null, balancedDeliverables1 || null,
        deliverables2 || null, completeDeliverables2 || null, balancedDeliverables2 || null,
        deliverables3 || null, completeDeliverables3 || null, balancedDeliverables3 || null,
        deliverables4 || null, completeDeliverables4 || null,balancedDeliverables4 || null,
        deliverables5 || null, completeDeliverables5 || null, balancedDeliverables5 || null,
        deliverables6 || null, completeDeliverables6 || null, balancedDeliverables6 || null,
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
// router.post('/submit', async (req, res) => {
//   const { employeeName, date, reportType } = req.body;

//   if (!employeeName || !date) {
//     return res.status(400).json({ success: false, message: 'employeeName and date are required' });
//   }

// try {

//   // Get submitted planner rows
//   const [plannerRows] = await db.query(
//     `
//     SELECT *
//     FROM day_plan_rows
//     WHERE employee_name = ?
//     AND plan_date = ?
//     AND report_type=?
//     ORDER BY id ASC
//     `,
//     [
//       employeeName,
//       date,
//       reportType || "Morning"
//     ]
//   );


//   const [admins] = await db.query(
//     `
//     SELECT full_name 
//     FROM employee_users
//     WHERE user_type = 'admin'
//     AND is_active = 1
//     `
//   );


//   for (const admin of admins) {

//     await db.query(
// `
// UPDATE day_plan_rows
// SET
// is_submitted=1,
// submitted_at=NOW()
// WHERE employee_name=?
// AND plan_date=?
// AND report_type=?
// `,
// [
// employeeName,
// date,
// reportType || "Morning"
// ]
// );


//     await createNotification({

//       senderName: employeeName,

//       recipientName: admin.full_name,


//       message: JSON.stringify({

//         preview: `${employeeName} submitted ${reportType} Day Planner`,


//         payload: {

//           type: "PLAN_SUBMITTED",

//           sender: employeeName,

//           recipient: admin.full_name,

//           date: date,


//           plannerData: plannerRows

//         }

//       })

//     });


//   }


// }
// catch(notifyErr){

//  console.error(
//  "Day planner notification failed:",
//  notifyErr.message
//  );

// }
// });

// POST /api/day-planner/submit
router.post('/submit', async (req, res) => {
  const { employeeName, date, reportType } = req.body;

  if (!employeeName || !date) {
    return res.status(400).json({
      success: false,
      message: 'employeeName and date are required'
    });
  }

  const currentReportType = reportType || "Morning";

  try {

    // Get planner rows
    const [plannerRows] = await db.query(
      `
      SELECT *
      FROM day_plan_rows
      WHERE employee_name = ?
      AND plan_date = ?
      AND report_type = ?
      ORDER BY id ASC
      `,
      [
        employeeName,
        date,
        currentReportType
      ]
    );

    if (plannerRows.length === 0) {
      return res.status(404).json({
        success: false,
        message: "No planner rows found."
      });
    }

    // Mark submitted
    await db.query(
      `
      UPDATE day_plan_rows
      SET
          is_submitted = 1,
          submitted_at = NOW()
      WHERE employee_name = ?
      AND plan_date = ?
      AND report_type = ?
      `,
      [
        employeeName,
        date,
        currentReportType
      ]
    );

    // Get admins
    const [admins] = await db.query(
      `
      SELECT full_name
      FROM employee_users
      WHERE user_type='admin'
      AND is_active=1
      `
    );

    // Notify every admin
    for (const admin of admins) {

      await createNotification({

        senderName: employeeName,

        recipientName: admin.full_name,

        message: JSON.stringify({

          preview: `${employeeName} submitted ${currentReportType} Day Planner`,

          payload: {

            type: "PLAN_SUBMITTED",

            sender: employeeName,

            recipient: admin.full_name,

            reportType: currentReportType,

            date,

            plannerData: plannerRows

          }

        })

      });

    }

    return res.json({
      success: true,
      message: `${currentReportType} Day Planner submitted successfully.`
    });

  } catch (err) {

    console.error("POST /day-planner/submit ERROR:", err);

    return res.status(500).json({
      success: false,
      message: err.message
    });

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
    const { date, reportType } = req.query; 

    // If a date is provided, filter by it; otherwise, default to today's date
    const sql = `
      SELECT *, DATE_FORMAT(plan_date, '%Y-%m-%d') AS plan_date_str
      FROM day_plan_rows
      WHERE employee_name = ?
      AND DATE(plan_date) = ${date ? '?' : 'CURDATE()'}
      AND report_type=?
      ORDER BY id
    `;

    // const params = date ? [employee, date] : [employee];
    const params = date
    ? [employee, date, reportType || "Morning"]
    : [employee, reportType || "Morning"];
    const [rows] = await db.query(sql, params);

    const data = rows.map((r) => ({
      id: r.id,
      date: r.plan_date_str,
      client: r.client_name || '',
      maintenance_date: r.maintenance_date ||  null,
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
      deliverables_4: r.deliverables_4 || '',
      complete_deliverables_4: r.complete_deliverables_4 || '',
      balanced_deliverables_4: r.balanced_deliverables_4 || '',

      deliverables_5: r.deliverables_5 || '',
      complete_deliverables_5: r.complete_deliverables_5 || '',
      balanced_deliverables_5: r.balanced_deliverables_5 || '',

      deliverables_6: r.deliverables_6 || '',
      complete_deliverables_6: r.complete_deliverables_6 || '',
      balanced_deliverables_6: r.balanced_deliverables_6 || '',
      today_plan: r.today_plan || '',
      report_type: r.report_type,
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

// GET /api/day-planner/month-history/:employeeName?month=2026-07
router.get('/month-history/:employeeName', async (req, res) => {
  const { employeeName } = req.params;
  const { month } = req.query; // format: YYYY-MM

  if (!employeeName || !month) {
    return res.status(400).json({ success: false, message: 'employeeName and month are required' });
  }

  try {
    const [rows] = await db.query(
      `SELECT *, DATE_FORMAT(plan_date, '%Y-%m-%d') AS plan_date_str
       FROM day_plan_rows 
       WHERE employee_name = ? AND DATE_FORMAT(plan_date, '%Y-%m') = ? 
       ORDER BY plan_date DESC, id ASC`,
      [employeeName, month]
    );

    return res.json({ success: true, data: rows });
  } catch (err) {
    console.error('GET /day-planner/month-history ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/day-planner/submissions?date=2026-07-30&type=Morning
router.get('/submissions', async (req, res) => {
  const { date, type } = req.query;

  const targetDate = date || new Date().toISOString().split('T')[0];
  const reportType = type || "Morning";

  try {

    // Get all active employees
    const [employees] = await db.query(
      `
      SELECT
          id,
          full_name AS fullName,
          role,
          user_type AS userType
      FROM employee_users
      WHERE is_active = 1
      ORDER BY full_name
      `
    );

    // Get submitted employees for selected report type
    const [submissions] = await db.query(
      `
      SELECT
          employee_name AS employeeName,
          MAX(is_submitted) AS submitted
      FROM day_plan_rows
      WHERE
          plan_date = ?
          AND report_type = ?
      GROUP BY employee_name
      `,
      [
        targetDate,
        reportType
      ]
    );

    return res.json({
      success: true,
      employees,
      submissions: submissions.map((row) => ({
        employeeName: row.employeeName,
        submitted: row.submitted == 1
      }))
    });

  } catch (err) {

    console.error("GET /day-planner/submissions ERROR:", err);

    return res.status(500).json({
      success: false,
      message: err.message
    });

  }
});

// GET /api/admin/day-planner/submissions?date=2026-07-30&type=Morning
router.get('/admin/day-planner/submissions', async (req, res) => {
  const { date, type } = req.query;

  const targetDate = date || new Date().toISOString().split('T')[0];
  const reportType = type || "Morning";

  try {

    // Get all active employees
    const [employees] = await db.query(
      `
      SELECT
          id,
          full_name AS fullName,
          role,
          user_type AS userType
      FROM employee_users
      WHERE is_active = 1
      ORDER BY full_name
      `
    );

    // Get submitted employees for selected report type
    const [submissions] = await db.query(
      `
      SELECT
          employee_name AS employeeName,
          MAX(is_submitted) AS submitted
      FROM day_plan_rows
      WHERE
          plan_date = ?
          AND report_type = ?
      GROUP BY employee_name
      `,
      [
        targetDate,
        reportType
      ]
    );

    return res.json({
      success: true,
      employees,
      submissions: submissions.map((row) => ({
        employeeName: row.employeeName,
        submitted: row.submitted == 1
      }))
    });

  } catch (err) {

    console.error("GET /admin/day-planner/submissions ERROR:", err);

    return res.status(500).json({
      success: false,
      message: err.message
    });

  }
});


module.exports = router;