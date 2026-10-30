const express = require('express');
const router = express.Router();
const db = require('../config/db');
const { authenticateToken } = require('./auth');
const { requireAdmin } = require('../controllers/hrmsEmployeesController');
const lifecycle = require('../lib/employeeLifecycle');
const policy = require('../lib/attendancePolicy');
const handle = fn => [authenticateToken, requireAdmin, async (req, res) => {
  try { await lifecycle.ensureLifecycle(); res.json({ success: true, data: await fn(req) }); }
  catch (error) { res.status(error.status || 500).json({ success: false, message: error.message, data: error.data }); }
}];
router.post('/:id/exit-preview', handle(req => lifecycle.preview(Number(req.params.id), req.body)));
router.post('/:id/exit', handle(req => lifecycle.deactivate(Number(req.params.id), req.body, req.user.id, req.app.get('io'))));
router.post('/:id/reactivate', handle(req => lifecycle.reactivate(Number(req.params.id), req.body, req.user.id)));
router.post('/:id/exit-exceptions', handle(async req => {
  const id=Number(req.params.id), reason=String(req.body.resolution || '').trim();
  const lastWorkingDate=lifecycle.automaticLastWorkingDate();
  if (!reason) throw lifecycle.problem('An exception resolution reason is required');
  const connection=await db.getConnection();
  try {
    await connection.beginTransaction();
    const user=await lifecycle.account(connection,id,true);
    const check=await lifecycle.inspect(connection,user,lastWorkingDate);
    const conflict=check.conflicts.find(c=>c.source===req.body.source && Number(c.id)===Number(req.body.sourceId));
    if (!conflict) throw lifecycle.problem('Conflict not found. Refresh the exit preview.',409);
    await connection.query(`INSERT INTO employee_exit_exceptions (employee_user_id,source_table,source_id,last_working_date,record_hash,reason,created_by,created_at) VALUES (?,?,?,?,?,?,?,?)`,
      [id,conflict.source,conflict.id,lastWorkingDate,conflict.hash,reason,req.user.id,policy.nowIstDateTime()]);
    await connection.query("INSERT INTO employee_lifecycle_audit (employee_user_id,action,details,created_by,created_at) VALUES (?,'EXIT_EXCEPTION',?,?,?)",[id,JSON.stringify({...req.body,hash:conflict.hash}),req.user.id,policy.nowIstDateTime()]);
    await connection.commit();return { resolved:true };
  } catch(error) { await connection.rollback();throw error; } finally { connection.release(); }
}));
router.get('/:id/lifecycle', handle(async req => {
  const id = Number(req.params.id);
  const user = await lifecycle.account(db, id);
  const [exits] = await db.query('SELECT * FROM employee_exits WHERE employee_user_id=? ORDER BY id DESC', [id]);
  const [periods] = await db.query('SELECT * FROM employee_employment_periods WHERE employee_user_id=? ORDER BY started_on', [id]);
  const [audit] = await db.query('SELECT * FROM employee_lifecycle_audit WHERE employee_user_id=? ORDER BY id DESC', [id]);
  const [adjustments] = await db.query('SELECT * FROM employee_salary_adjustments WHERE employee_user_id=? ORDER BY id DESC', [id]);
  const [payroll] = await db.query('SELECT * FROM hrms_payroll_items WHERE employee_user_id=? ORDER BY pay_year DESC,pay_month DESC', [id]);
  const sources = await lifecycle.sourceRows(db, user);
  const finalSalary=[];
  for(const exit of exits) for(const salary of await lifecycle.salaryPreview(id,require('../lib/employmentDates').dateKey(exit.last_working_date))) finalSalary.push({...salary,exitId:exit.id});
  return { employee: lifecycle.serializeRecord(user), exits:exits.map(lifecycle.serializeRecord), periods:periods.map(lifecycle.serializeRecord),
    audit:audit.map(lifecycle.serializeRecord),
    payroll:payroll.map(lifecycle.serializeRecord), adjustments:adjustments.map(lifecycle.serializeRecord), finalSalary,
    exitDateRequired: !Number(user.is_active) && !exits.length,
    history: sources.map(s => ({ source: s.table, records: s.rows.map(lifecycle.serializeRecord) })) };
}));
router.post('/adjustments/:adjustmentId/resolve', handle(async req => {
  const resolution = String(req.body.resolution || '').trim();
  if (!resolution) throw lifecycle.problem('Record the adjustment decision and payment or recovery reference');
  const connection = await db.getConnection();
  try {
    await connection.beginTransaction();
    const [[item]] = await connection.query('SELECT * FROM employee_salary_adjustments WHERE id=? FOR UPDATE', [req.params.adjustmentId]);
    if (!item || item.resolved_at) throw lifecycle.problem('Unresolved adjustment not found', 404);
    await connection.query('UPDATE employee_salary_adjustments SET resolution=?,resolved_by=?,resolved_at=? WHERE id=?', [resolution,req.user.id,policy.nowIstDateTime(),item.id]);
    await connection.query("INSERT INTO employee_lifecycle_audit (employee_user_id,action,details,created_by,created_at) VALUES (?,'SALARY_ADJUSTMENT',?,?,?)", [item.employee_user_id,JSON.stringify({ adjustmentId:item.id,resolution,difference:item.difference }),req.user.id,policy.nowIstDateTime()]);
    await connection.commit(); return { id:item.id };
  } catch(error) { await connection.rollback(); throw error; } finally { connection.release(); }
}));
router.post('/:id/settlement/complete', handle(async req => {
  return lifecycle.completeSettlement(Number(req.params.id), req.user.id);
}));
router.get('/:id/payroll/:payrollId/payslip', authenticateToken, requireAdmin, async (req, res) => {
  try {
    const [[row]] = await db.query(`SELECT p.*,e.full_name,e.employee_code,e.department FROM hrms_payroll_items p
      JOIN hrms_employee_profiles e ON e.id=p.profile_id AND e.employee_user_id=p.employee_user_id
      WHERE p.id=? AND p.employee_user_id=? AND p.status='paid' AND p.monthly_salary>0`, [req.params.payrollId,req.params.id]);
    if (!row) throw lifecycle.problem('Verified paid payslip not found',404);
    const pdf = await require('../lib/payslipPdf').buildPayslipPdf(row);
    res.type('application/pdf').send(pdf);
  } catch(error) { res.status(error.status || 500).json({success:false,message:error.message}); }
});
router.get('/settlements/outstanding', handle(async () => {
  const [items] = await db.query(`SELECT u.id AS employee_user_id,u.full_name,e.id AS exit_id,
    e.last_working_date,COALESCE(e.settlement_status,'Exit date required') AS settlement_status
    FROM employee_users u LEFT JOIN employee_exits e ON e.id=(SELECT MAX(x.id) FROM employee_exits x WHERE x.employee_user_id=u.id)
    WHERE (u.is_active=0 AND e.id IS NULL)
       OR EXISTS (SELECT 1 FROM employee_exits x WHERE x.employee_user_id=u.id AND x.settlement_status<>'Settled')
       OR EXISTS (SELECT 1 FROM hrms_payroll_items p WHERE p.employee_user_id=u.id AND p.status<>'paid') AND e.id IS NOT NULL
    ORDER BY u.full_name`);
  return { items:items.map(lifecycle.serializeRecord) };
}));
module.exports = router;
