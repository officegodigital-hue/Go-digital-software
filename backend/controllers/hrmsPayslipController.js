const db = require('../config/db');

const ok = (res, data, message) => res.json({ success: true, message: message || 'OK', data });
const fail = (res, status, message) => res.status(status).json({ success: false, message });

async function ensureTable() {
  await db.query(`CREATE TABLE IF NOT EXISTS hrms_payslip_requests (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    payroll_item_id BIGINT UNSIGNED NOT NULL,
    employee_user_id BIGINT UNSIGNED NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    reviewed_by BIGINT UNSIGNED NULL,
    reviewed_at DATETIME NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uniq_payslip_employee (payroll_item_id, employee_user_id)
  )`);
  await db.query(`CREATE TABLE IF NOT EXISTS hrms_payslip_approval_links (
    payslip_request_id BIGINT UNSIGNED NOT NULL,
    approval_request_id BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (payslip_request_id),
    UNIQUE KEY uniq_payslip_approval_request (approval_request_id)
  )`);
}

async function ensureCompensationTable() {
  await db.query(`CREATE TABLE IF NOT EXISTS hrms_employee_compensation (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    profile_id BIGINT UNSIGNED NULL,
    employee_user_id BIGINT UNSIGNED NOT NULL,
    monthly_salary DECIMAL(12,2) NOT NULL,
    effective_from DATE NOT NULL,
    created_by BIGINT UNSIGNED NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY employee_effective (employee_user_id, effective_from)
  )`);
  try { await db.query('ALTER TABLE hrms_employee_compensation ADD COLUMN profile_id BIGINT UNSIGNED NULL AFTER id'); } catch (_) {}
}

function requireAdmin(req, res, next) {
  if (String(req.user && req.user.userType || '').toLowerCase() !== 'admin') return fail(res, 403, 'Admin access required');
  return next();
}

async function summary(req, res) {
  try {
    await ensureCompensationTable();
    const [[compensation]] = await db.query(`SELECT c.monthly_salary, c.effective_from FROM hrms_employee_compensation c
      JOIN hrms_employee_profiles e ON e.employee_user_id = c.employee_user_id AND (c.profile_id IS NULL OR c.profile_id = e.id)
      WHERE c.employee_user_id = ? AND c.effective_from <= CURDATE() ORDER BY c.effective_from DESC, c.id DESC LIMIT 1`, [req.user.id]);
    const [[payroll]] = await db.query(`SELECT p.* FROM hrms_payroll_items p
      JOIN hrms_employee_profiles e ON e.id = p.profile_id AND e.employee_user_id = p.employee_user_id
      WHERE p.employee_user_id = ? AND p.monthly_salary > 0 ORDER BY p.pay_year DESC, p.pay_month DESC, p.id DESC LIMIT 1`, [req.user.id]);
    const [[invalid]] = await db.query(`SELECT p.id FROM hrms_payroll_items p JOIN hrms_employee_profiles e ON e.id = p.profile_id
      WHERE e.employee_user_id = ? AND (NOT(p.employee_user_id <=> e.employee_user_id) OR (p.status = 'paid' AND COALESCE(p.monthly_salary, 0) <= 0)) LIMIT 1`, [req.user.id]);
    return ok(res, { compensation: compensation || null, payroll: payroll || null, reviewRequired: Boolean(invalid) });
  } catch (error) { return fail(res, 500, error.message); }
}

async function compensationList(req, res) {
  try {
    await ensureCompensationTable();
    const employeeId = Number(req.query.employeeUserId || 0);
    const [rows] = await db.query(`SELECT id, employee_user_id, monthly_salary, effective_from, created_at FROM hrms_employee_compensation ${employeeId ? 'WHERE employee_user_id = ?' : ''} ORDER BY employee_user_id, effective_from DESC`, employeeId ? [employeeId] : []);
    return ok(res, rows);
  } catch (error) { return fail(res, 500, error.message); }
}

async function saveCompensation(req, res) {
  try {
    await ensureCompensationTable();
    const employeeUserId = Number(req.body && req.body.employeeUserId);
    const monthlySalary = Number(req.body && req.body.monthlySalary);
    const effectiveFrom = String(req.body && req.body.effectiveFrom || '').slice(0, 10);
    if (!employeeUserId || !Number.isFinite(monthlySalary) || monthlySalary < 0 || !/^\d{4}-\d{2}-\d{2}$/.test(effectiveFrom)) return fail(res, 400, 'employeeUserId, monthlySalary, and effectiveFrom are required');
    const [[profile]] = await db.query('SELECT id FROM hrms_employee_profiles WHERE employee_user_id = ? LIMIT 1', [employeeUserId]);
    const [result] = await db.query(`INSERT INTO hrms_employee_compensation (profile_id, employee_user_id, monthly_salary, effective_from, created_by) VALUES (?, ?, ?, ?, ?)`, [profile ? profile.id : null, employeeUserId, monthlySalary, effectiveFrom, req.user.id]);
    // Profile is the live Admin/dashboard source; the history row remains the payroll source.
    if (profile) await db.query('UPDATE hrms_employee_profiles SET monthly_salary = ? WHERE id = ?', [monthlySalary, profile.id]);
    return ok(res, { id: result.insertId }, 'Compensation saved');
  } catch (error) { return fail(res, 500, error.message); }
}

async function mine(req, res) {
  try {
    await ensureTable();
    const [rows] = await db.query(`
      SELECT p.id, p.pay_year, p.pay_month, p.monthly_salary, p.deductions, p.net_pay, p.status,
             COALESCE(a.status, 'not_requested') AS request_status
      FROM hrms_payroll_items p
      JOIN hrms_employee_profiles e ON e.id = p.profile_id AND e.employee_user_id = p.employee_user_id
      LEFT JOIN hrms_payslip_requests request ON request.payroll_item_id = p.id AND request.employee_user_id = p.employee_user_id
      LEFT JOIN hrms_payslip_approval_links link ON link.payslip_request_id = request.id
      LEFT JOIN attendance_permission_requests a ON a.id = link.approval_request_id
      WHERE p.employee_user_id = ? AND p.status = 'paid' AND p.monthly_salary > 0
      ORDER BY p.pay_year DESC, p.pay_month DESC`, [req.user.id]);
    return ok(res, rows);
  } catch (error) { return fail(res, 500, error.message); }
}

async function request(req, res) {
  try {
    await ensureTable();
    const payrollId = Number(req.params.payrollId);
    const [[payroll]] = await db.query(
      `SELECT id, pay_year, pay_month FROM hrms_payroll_items WHERE id = ? AND employee_user_id = ? AND status = 'paid'`,
      [payrollId, req.user.id]
    );
    if (!payroll) return fail(res, 404, 'Paid payroll item not found');
    const [[existing]] = await db.query(`
      SELECT a.status FROM hrms_payslip_requests request
      LEFT JOIN hrms_payslip_approval_links link ON link.payslip_request_id = request.id
      LEFT JOIN attendance_permission_requests a ON a.id = link.approval_request_id
      WHERE request.payroll_item_id = ? AND request.employee_user_id = ?`, [payrollId, req.user.id]);
    if (existing) return ok(res, { status: existing.status }, 'Request already exists');
    const today = new Date().toISOString().slice(0, 10);
    const [created] = await db.query(`
      INSERT INTO attendance_permission_requests (employee_id, request_type, request_date, reason, status, created_at)
      VALUES (?, 'payslip_download', ?, ?, 'pending', NOW())`,
      [req.user.id, today, `Payslip download request for ${payroll.pay_month}/${payroll.pay_year}`]
    );
    const [requestRow] = await db.query(`INSERT INTO hrms_payslip_requests (payroll_item_id, employee_user_id, status) VALUES (?, ?, 'pending')`, [payrollId, req.user.id]);
    await db.query('INSERT INTO hrms_payslip_approval_links (payslip_request_id, approval_request_id) VALUES (?, ?)', [requestRow.insertId, created.insertId]);
    return ok(res, { status: 'pending' }, 'Payslip request sent to Admin');
  } catch (error) { return fail(res, 500, error.message); }
}

async function download(req, res) {
  try {
    await ensureTable();
    const payrollId = Number(req.params.payrollId);
    const [[row]] = await db.query(`
      SELECT p.*, a.status AS request_status FROM hrms_payroll_items p
      JOIN hrms_payslip_requests request ON request.payroll_item_id = p.id AND request.employee_user_id = p.employee_user_id
      JOIN hrms_payslip_approval_links link ON link.payslip_request_id = request.id
      JOIN attendance_permission_requests a ON a.id = link.approval_request_id
      WHERE p.id = ? AND p.employee_user_id = ?`, [payrollId, req.user.id]);
    if (!row || row.request_status !== 'approved') return fail(res, 403, 'Admin approval is required before download');
    res.type('text/plain').send(`PAYSLIP\nPeriod: ${row.pay_month}/${row.pay_year}\nGross Salary: ${row.monthly_salary}\nLeave Deduction: ${row.deductions}\nNet Pay: ${row.net_pay}`);
  } catch (error) { return fail(res, 500, error.message); }
}

module.exports = { ensureTable, ensureCompensationTable, requireAdmin, mine, summary, request, download, compensationList, saveCompensation };
