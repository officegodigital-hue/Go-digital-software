const db = require('../config/db');
const { buildPayslipPdf } = require('../lib/payslipPdf');
const { computeRows } = require('./hrmsPayrollController');
const attendancePolicy = require('../lib/attendancePolicy');
const { effectiveOverrides } = require('../lib/calendarOverrides');
const { dateKey, employedOn } = require('../lib/employmentDates');
const companyName = process.env.COMPANY_NAME || 'GO DIGITAL';

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
    const today = attendancePolicy.todayIstDate();
    const [year, month] = today.split('-').map(Number);
    const rows = await computeRows(year, month, today);
    const live = rows.find((row) => Number(row.employeeUserId) === Number(req.user.id)) || null;
    return ok(res, { compensation: compensation || null, payroll: payroll || null, livePayroll: live, reviewRequired: Boolean(invalid) });
  } catch (error) { return fail(res, 500, error.message); }
}

function historyDate(year, month, day) {
  return `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
}

function historyDaysInMonth(year, month) {
  return new Date(Date.UTC(year, month, 0)).getUTCDate();
}

async function history(req, res) {
  try {
    const match = /^(\d{4})-(0[1-9]|1[0-2])$/.exec(String(req.query.month || ''));
    if (!match) return fail(res, 400, 'A valid month (YYYY-MM) is required');

    const year = Number(match[1]);
    const month = Number(match[2]);
    const today = attendancePolicy.todayIstDate();
    if (`${match[1]}-${match[2]}` > today.slice(0, 7)) {
      return fail(res, 400, 'Future salary history is not available');
    }

    // The payroll engine remains the source of truth for all summary figures.
    // This endpoint only presents the employee's existing monthly data.
    const payrollRows = await computeRows(year, month, today, { employeeId: req.user.id });
    const payroll = payrollRows.find((row) => Number(row.employeeUserId) === Number(req.user.id)) || null;
    const start = historyDate(year, month, 1);
    const end = historyDate(year, month, historyDaysInMonth(year, month));

    const [[profile]] = await db.query(`
      SELECT p.employee_user_id, p.department, p.salary_type, p.salary_cycle_start_day, p.salary_cycle_end_day,
             u.is_active, u.created_at AS account_created_at, u.date_of_joining AS joining_date,
             COALESCE(NULLIF(p.department, ''), u.role, '') AS calendar_department
      FROM hrms_employee_profiles p
      JOIN employee_users u ON u.id = p.employee_user_id
      WHERE p.employee_user_id = ? LIMIT 1`, [req.user.id]);
    if (!profile) return ok(res, { month: `${match[1]}-${match[2]}`, payroll, days: [] });

    const [periods] = await db.query(
      'SELECT started_on, ended_on FROM employee_employment_periods WHERE employee_user_id = ? ORDER BY started_on, id',
      [req.user.id]
    );
    const employmentPeriods = periods.length
      ? periods
      : Number(profile.is_active)
        ? [{ started_on: dateKey(profile.joining_date || profile.account_created_at), ended_on: null }]
        : [];
    const [[policyRow]] = await db.query(
      'SELECT weekly_off_days, deduct_explicit_absence, missing_attendance_is_absent FROM hrms_payroll_policy WHERE id = 1'
    );
    let weeklyOffDays = [0];
    try { weeklyOffDays = JSON.parse(policyRow?.weekly_off_days || '[0]').map(Number); } catch (_) {}
    const weeklyOff = new Set(weeklyOffDays);
    const deductAbsence = Boolean(Number(policyRow?.deduct_explicit_absence ?? 1));
    const missingIsAbsent = Boolean(Number(policyRow?.missing_attendance_is_absent ?? 0));

    const [records] = await db.query(`
      SELECT DATE_FORMAT(attendance_date, '%Y-%m-%d') AS attendance_date,
             check_in_at, check_out_at, is_late, attendance_status, admin_status_override
      FROM attendance_records
      WHERE employee_id = ? AND attendance_date BETWEEN ? AND ?`, [req.user.id, start, end]);
    const recordMap = new Map(records.map((row) => [dateKey(row.attendance_date), row]));

    const [leaves] = await db.query(`
      SELECT DATE_FORMAT(el.from_date, '%Y-%m-%d') AS from_date,
             DATE_FORMAT(el.to_date, '%Y-%m-%d') AS to_date, el.duration_type,
             el.leave_type, lt.is_lop
      FROM employee_leaves el
      LEFT JOIN hrms_leave_types lt ON lt.id = el.leave_type_id
      WHERE el.employee_id = ? AND el.status = 'APPROVED'
        AND el.from_date <= ? AND el.to_date >= ?`, [req.user.id, end, start]);
    const leaveMap = new Map();
    for (const leave of leaves) {
      let date = dateKey(leave.from_date);
      const leaveEnd = dateKey(leave.to_date);
      while (date && date <= leaveEnd) {
        if (!leaveMap.has(date)) leaveMap.set(date, {
          isLop: Number(leave.is_lop) === 1,
          isHalf: leave.duration_type === 'Half Day',
          name: leave.leave_type || 'Approved leave',
        });
        const next = new Date(`${date}T00:00:00Z`);
        next.setUTCDate(next.getUTCDate() + 1);
        date = next.toISOString().slice(0, 10);
      }
    }
    const overrides = await effectiveOverrides(start, end, [profile]);
    const employeeOverrides = overrides.get(Number(req.user.id)) || new Map();
    const dailyRate = Number(payroll?.dailyRate || 0);
    const days = [];

    for (let day = 1; day <= historyDaysInMonth(year, month); day += 1) {
      const date = historyDate(year, month, day);
      const weekday = new Date(`${date}T00:00:00Z`).getUTCDay();
      const override = employeeOverrides.get(date)?.status;
      const workingDay = override === 'Working Day' || (!override && !weeklyOff.has(weekday));
      const employed = employedOn(employmentPeriods, date);
      const record = recordMap.get(date);
      const leave = leaveMap.get(date);
      const future = date > today;
      let status = 'No attendance recorded';
      let source = 'No payroll impact';
      let amount = 0;
      let direction = 'none';

      if (!employed) {
        status = 'Not employed';
      } else if (future) {
        status = 'Upcoming';
      } else if (!workingDay) {
        status = override === 'Holiday' ? 'Holiday' : 'Weekly Off';
        source = 'No payroll impact';
      } else {
        const attendanceStatus = String(record?.attendance_status || '').toLowerCase().trim();
        if (attendanceStatus === 'absent') {
          status = 'Absent';
          if (deductAbsence) {
            source = 'Attendance deduction'; amount = dailyRate; direction = 'deduction';
          } else source = 'No deduction by policy';
        } else if (record && (record.check_in_at || attendanceStatus === 'present')) {
          const late = !record.admin_status_override && (Number(record.is_late) || attendanceStatus === 'late');
          status = late ? 'Late' : 'Present';
          source = late ? 'Worked — late check-in' : 'Worked'; amount = dailyRate; direction = 'paid';
        } else if (leave) {
          const factor = leave.isHalf ? 0.5 : 1;
          status = leave.isLop ? 'Unpaid Leave' : 'Paid Leave';
          source = leave.name;
          amount = dailyRate * factor;
          direction = leave.isLop ? 'deduction' : 'paid';
        } else if (missingIsAbsent) {
          status = 'Absent'; source = 'Missing attendance policy';
          if (deductAbsence) { amount = dailyRate; direction = 'deduction'; }
        }
      }
      days.push({
        date, status, source, direction, amount: Math.round(amount * 100) / 100,
        checkIn: record?.check_in_at || null, checkOut: record?.check_out_at || null,
      });
    }
    return ok(res, { month: `${match[1]}-${match[2]}`, payroll, days });
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
      SELECT request.id AS payslip_request_id, a.status FROM hrms_payslip_requests request
      LEFT JOIN hrms_payslip_approval_links link ON link.payslip_request_id = request.id
      LEFT JOIN attendance_permission_requests a ON a.id = link.approval_request_id
      WHERE request.payroll_item_id = ? AND request.employee_user_id = ?`, [payrollId, req.user.id]);
    if (existing && existing.status !== 'rejected') {
      return ok(res, { status: existing.status }, 'Request already exists');
    }
    const today = new Date().toISOString().slice(0, 10);
    const [created] = await db.query(`
      INSERT INTO attendance_permission_requests (employee_id, request_type, request_date, reason, status, created_at)
      VALUES (?, 'payslip_download', ?, ?, 'pending', NOW())`,
      [req.user.id, today, `Payslip download request for ${payroll.pay_month}/${payroll.pay_year}`]
    );
    if (existing) {
      await db.query(
        `UPDATE hrms_payslip_requests SET status = 'pending' WHERE id = ?`,
        [existing.payslip_request_id]
      );
      await db.query(
        `UPDATE hrms_payslip_approval_links SET approval_request_id = ? WHERE payslip_request_id = ?`,
        [created.insertId, existing.payslip_request_id]
      );
      return ok(res, { status: 'pending' }, 'Payslip request sent to Admin again');
    }
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
      SELECT p.*, a.status AS request_status, e.full_name, e.employee_code, e.department
      FROM hrms_payroll_items p
      JOIN hrms_employee_profiles e ON e.id = p.profile_id AND e.employee_user_id = p.employee_user_id
      JOIN hrms_payslip_requests request ON request.payroll_item_id = p.id AND request.employee_user_id = p.employee_user_id
      JOIN hrms_payslip_approval_links link ON link.payslip_request_id = request.id
      JOIN attendance_permission_requests a ON a.id = link.approval_request_id
      WHERE p.id = ? AND p.employee_user_id = ?`, [payrollId, req.user.id]);
    if (!row || row.request_status !== 'approved') return fail(res, 403, 'Admin approval is required before download');
    const generatedPdf = await buildPayslipPdf(row);
    res.set('Content-Disposition', `attachment; filename="Salary-Slip-${row.pay_month}-${row.pay_year}.pdf"`);
    res.type('application/pdf').send(generatedPdf);
    return;
    const money = (value) => `Rs. ${Number(value || 0).toLocaleString('en-IN')}`;
    const employeeName = row.employee_name || row.name || 'Employee';
    const pdfText = (value) => String(value ?? '').replace(/[\\()]/g, '\\$&');
    const lines = [
      companyName, `SALARY SLIP FOR THE MONTH - ${row.pay_month}/${row.pay_year}`,
      `Employee Name: ${employeeName}`, `Employee Code: ${row.employee_code || row.employee_user_id || '-'}`,
      `Gross Earnings (A): ${money(row.monthly_salary)}`, `Leave Deduction: ${money(row.deductions)}`,
      `Total Deductions (B): ${money(row.deductions)}`, `TOTAL NET PAYABLE (A-B): ${money(row.net_pay)}`,
      'This is a system generated pay slip and hence company signature is not required.'
    ];
    let y = 770;
    const commands = ['BT /F1 16 Tf 50 800 Td'];
    lines.forEach((line, index) => { commands.push(`/F1 ${index < 2 ? 16 : 11} Tf 0 -${index === 0 ? 28 : 25} Td (${pdfText(line)}) Tj`); });
    commands.push('ET');
    const stream = commands.join('\n');
    const objects = [
      '<< /Type /Catalog /Pages 2 0 R >>', '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>', `<< /Length ${Buffer.byteLength(stream, 'utf8')} >>\nstream\n${stream}\nendstream`
    ];
    let pdf = '%PDF-1.4\n'; const offsets = [0];
    objects.forEach((object, index) => { offsets.push(Buffer.byteLength(pdf, 'utf8')); pdf += `${index + 1} 0 obj\n${object}\nendobj\n`; });
    const xref = Buffer.byteLength(pdf, 'utf8'); pdf += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`; offsets.slice(1).forEach((offset) => { pdf += `${String(offset).padStart(10, '0')} 00000 n \n`; }); pdf += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF`;
    res.set('Content-Disposition', `attachment; filename="Salary-Slip-${row.pay_month}-${row.pay_year}.pdf"`);
    res.type('application/pdf').send(Buffer.from(pdf, 'utf8'));
    return;
    res.type('html').send(`<!doctype html><html><head><meta charset="utf-8"><style>
      body{font-family:Arial,sans-serif;color:#172554;margin:0;padding:32px;background:#f5f7fb}
      .sheet{max-width:760px;margin:auto;background:#fff;border:1px solid #dbe3f0;border-radius:12px;overflow:hidden}
      .head{background:#0b3b8f;color:#fff;padding:26px 32px}.brand{font-size:22px;font-weight:700;letter-spacing:.5px}.title{font-size:18px;margin-top:8px;opacity:.9}
      .meta{display:grid;grid-template-columns:1fr 1fr 1fr 1fr;padding:22px 32px;border-bottom:1px solid #e5eaf2}.label{color:#64748b;font-size:12px;text-transform:uppercase}.value{font-weight:700;margin-top:5px}
      table{width:calc(100% - 64px);margin:24px 32px;border-collapse:collapse}th,td{padding:10px 12px;border:1px solid #dbe3f0;text-align:left}th{background:#eef3fb}td:nth-child(even),th:nth-child(even){text-align:right}
      .net{margin:0 32px 30px;padding:20px;background:#eaf2ff;border-left:5px solid #1261e8;display:flex;justify-content:space-between;font-size:20px;font-weight:700}.foot{padding:16px 32px;color:#64748b;font-size:12px;border-top:1px solid #e5eaf2}
    </style></head><body><section class="sheet"><header class="head"><div class="brand">${companyName}</div><div class="title">Salary Slip</div></header>
      <div class="meta"><div><div class="label">Employee Name</div><div class="value">${employeeName}</div></div><div><div class="label">Employee Code</div><div class="value">${row.employee_code || row.employee_user_id || '—'}</div></div><div><div class="label">Pay period</div><div class="value">${row.pay_month}/${row.pay_year}</div></div><div><div class="label">Net days payable</div><div class="value">${row.paid_days || '—'}</div></div></div>
      <table><tr><th>Earnings</th><th>Amount (INR)</th><th>Deductions</th><th>Amount (INR)</th></tr><tr><td>Gross Salary</td><td>${money(row.monthly_salary)}</td><td>Leave Deduction</td><td>${money(row.deductions)}</td></tr><tr><td>Other Earnings</td><td>${money(0)}</td><td>Other Deductions</td><td>${money(0)}</td></tr><tr><th>Total Earnings (A)</th><th>${money(row.monthly_salary)}</th><th>Total Deductions (B)</th><th>${money(row.deductions)}</th></tr></table>
      <div class="net"><span>Total Net Payable (A − B)</span><span>${money(row.net_pay)}</span></div><div class="foot">This is a system generated pay slip and hence company signature is not required.</div></section></body></html>`);
  } catch (error) { return fail(res, 500, error.message); }
}

module.exports = { ensureTable, ensureCompensationTable, requireAdmin, mine, summary, history, request, download, compensationList, saveCompensation };
