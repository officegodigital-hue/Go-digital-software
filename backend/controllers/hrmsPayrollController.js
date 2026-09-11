const db = require('../config/db');
const policy = require('../lib/attendancePolicy');

function ok(res, data, message) {
  return res.json({ success: true, message: message || 'OK', data: data });
}

function fail(res, status, message) {
  return res.status(status).json({ success: false, message: message });
}

function requireAdmin(req, res, next) {
  const userType = String((req.user && req.user.userType) || '').toLowerCase();
  if (userType !== 'admin') {
    return fail(res, 403, 'Admin access required');
  }
  return next();
}

const LEAVE_TYPES = ['leave', 'risk_leave', 'annual_leave', 'sick_leave', 'personal_leave'];
const MONTHS = ['January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'];

function formatSalary(value) {
  if (value === null || value === undefined || value === '') return 'Not Set';
  const digits = String(value).replace(/[^0-9]/g, '');
  if (!digits) return 'Not Set';
  return '₹' + Number(digits).toLocaleString('en-IN');
}

function pad(value) {
  return String(value).padStart(2, '0');
}

function ymd(year, month, day) {
  return year + '-' + pad(month) + '-' + pad(day);
}

function utcWeekday(year, month, day) {
  return new Date(Date.UTC(year, month - 1, day)).getUTCDay();
}

function daysInMonth(year, month) {
  return new Date(Date.UTC(year, month, 0)).getUTCDate();
}

function isoDate(value) {
  if (!value) return '';
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return value.toISOString().slice(0, 10);
  }
  const match = String(value).match(/(\d{4}-\d{2}-\d{2})/);
  return match ? match[1] : '';
}

function parseMonth(req) {
  const today = policy.todayIstDate();
  const [ty, tm] = today.split('-').map(Number);
  const body = req.body || {};
  const year = Number(req.query.year || body.year || ty);
  const month = Number(req.query.month || body.month || tm);
  if (!year || month < 1 || month > 12) {
    return { error: 'year and month (1-12) are required' };
  }
  return { year: year, month: month, today: today };
}

function monthOptions(today) {
  const [ty, tm] = today.split('-').map(Number);
  const items = [];
  for (let i = 0; i < 12; i += 1) {
    let month = tm - i;
    let year = ty;
    while (month < 1) {
      month += 12;
      year -= 1;
    }
    items.push({
      year: year,
      month: month,
      label: MONTHS[month - 1] + ' ' + year,
    });
  }
  return items;
}

async function computeRows(year, month, today) {
  const weeklyOff = 0;
  const totalDays = daysInMonth(year, month);
  const start = ymd(year, month, 1);
  const end = ymd(year, month, totalDays);
  const cutoff = end < today ? end : today;

  const [profiles] = await db.query(`
    SELECT * FROM hrms_employee_profiles
    WHERE employment_status <> 'Inactive'
    ORDER BY full_name ASC
  `);

  const userIds = profiles.map(function (row) { return row.employee_user_id; }).filter(Boolean);

  const [records] = userIds.length
    ? await db.query(
        `SELECT employee_id, DATE_FORMAT(attendance_date, '%Y-%m-%d') AS attendance_date,
                check_in_at, is_late
         FROM attendance_records
         WHERE attendance_date BETWEEN ? AND ?
           AND employee_id IN (?)`,
        [start, end, userIds]
      )
    : [[]];

  const leavePlaceholders = LEAVE_TYPES.map(function () { return '?'; }).join(', ');
  const [leaves] = userIds.length
    ? await db.query(
        `SELECT employee_id, DATE_FORMAT(request_date, '%Y-%m-%d') AS request_date
         FROM attendance_permission_requests
         WHERE status = 'approved'
           AND request_type IN (` + leavePlaceholders + `)
           AND request_date BETWEEN ? AND ?
           AND employee_id IN (?)`,
        LEAVE_TYPES.concat([start, end, userIds])
      )
    : [[]];

  const [savedRows] = await db.query(
    `SELECT * FROM hrms_payroll_items WHERE pay_year = ? AND pay_month = ?`,
    [year, month]
  );
  const savedMap = new Map();
  savedRows.forEach(function (row) {
    savedMap.set(Number(row.profile_id), row);
  });

  const recordMap = new Map();
  records.forEach(function (row) {
    recordMap.set(row.employee_id + '|' + isoDate(row.attendance_date), row);
  });
  const leaveSet = new Set();
  leaves.forEach(function (row) {
    leaveSet.add(row.employee_id + '|' + isoDate(row.request_date));
  });

  return profiles.map(function (profile) {
    let workingDays = 0;
    let present = 0;
    let late = 0;
    let leaveDays = 0;
    let absent = 0;

    for (let day = 1; day <= totalDays; day += 1) {
      const date = ymd(year, month, day);
      if (utcWeekday(year, month, day) === weeklyOff) continue;
      if (date > cutoff) continue;
      workingDays += 1;
      const userId = profile.employee_user_id;
      const key = userId ? userId + '|' + date : '';
      const record = key ? recordMap.get(key) : null;
      if (record && record.check_in_at) {
        if (Number(record.is_late)) late += 1;
        else present += 1;
      } else if (key && leaveSet.has(key)) {
        leaveDays += 1;
      } else {
        absent += 1;
      }
    }

    const salaryNumber = Number(profile.monthly_salary || 0);
    const paidDays = present + late;
    const lopDays = Math.max(0, workingDays - paidDays);
    const netPay = workingDays && salaryNumber
      ? Math.round((paidDays / workingDays) * salaryNumber)
      : 0;
    const deductions = salaryNumber ? Math.max(0, salaryNumber - netPay) : 0;
    const saved = savedMap.get(Number(profile.id));
    const status = saved ? String(saved.status) : 'draft';

    return {
      id: saved ? saved.id : null,
      profileId: profile.id,
      employeeUserId: profile.employee_user_id,
      name: String(profile.full_name || '').trim(),
      employeeCode: profile.employee_code,
      department: profile.department,
      monthlySalary: salaryNumber || null,
      salary: formatSalary(profile.monthly_salary),
      workingDays: workingDays,
      presentDays: present,
      lateDays: late,
      leaveDays: leaveDays,
      absentDays: absent,
      paidDays: paidDays,
      lopDays: lopDays,
      deductions: deductions,
      deductionsLabel: salaryNumber ? formatSalary(deductions) : '–',
      netPay: netPay,
      netPayLabel: salaryNumber ? formatSalary(netPay) : '–',
      status: status === 'paid' ? 'Paid' : status === 'pending' ? 'Pending' : 'Draft',
      paidAt: saved && saved.paid_at ? isoDate(saved.paid_at) : '',
    };
  });
}

function toKpis(items) {
  const withSalary = items.filter(function (item) { return item.monthlySalary; });
  const totalPayroll = withSalary.reduce(function (sum, item) { return sum + item.netPay; }, 0);
  const paid = items.filter(function (item) { return item.status === 'Paid'; }).length;
  const pending = items.filter(function (item) { return item.status === 'Pending'; }).length;
  const draft = items.filter(function (item) { return item.status === 'Draft'; }).length;
  return {
    totalPayroll: totalPayroll,
    totalPayrollLabel: formatSalary(totalPayroll || null),
    employees: items.length,
    paid: paid,
    pending: pending,
    draft: draft,
  };
}

async function list(req, res) {
  try {
    const parsed = parseMonth(req);
    if (parsed.error) return fail(res, 400, parsed.error);
    const employee = String(req.query.employee || '').trim();
    const status = String(req.query.status || '').trim();
    const allItems = await computeRows(parsed.year, parsed.month, parsed.today);
    let items = allItems;
    if (employee && employee !== 'All Employees') {
      items = items.filter(function (item) { return item.name === employee; });
    }
    if (status && status !== 'All Status') {
      items = items.filter(function (item) { return item.status === status; });
    }
    const names = [...new Set(allItems.map(function (item) { return item.name; }))];
    return ok(res, {
      year: parsed.year,
      month: parsed.month,
      label: MONTHS[parsed.month - 1] + ' ' + parsed.year,
      months: monthOptions(parsed.today),
      timezone: policy.TIME_ZONE,
      items: items,
      employees: names,
      kpis: toKpis(items),
    });
  } catch (error) {
    console.error('GET /hrms/payroll', error);
    return fail(res, 500, error.message);
  }
}

async function generate(req, res) {
  try {
    const parsed = parseMonth(req);
    if (parsed.error) return fail(res, 400, parsed.error);
    const items = await computeRows(parsed.year, parsed.month, parsed.today);
    for (const item of items) {
      await db.query(
        `INSERT INTO hrms_payroll_items
          (profile_id, employee_user_id, pay_year, pay_month, monthly_salary,
           working_days, paid_days, lop_days, deductions, net_pay, status)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending')
         ON DUPLICATE KEY UPDATE
           employee_user_id = VALUES(employee_user_id),
           monthly_salary = VALUES(monthly_salary),
           working_days = VALUES(working_days),
           paid_days = VALUES(paid_days),
           lop_days = VALUES(lop_days),
           deductions = VALUES(deductions),
           net_pay = VALUES(net_pay),
           status = IF(status = 'paid', 'paid', 'pending')`,
        [
          item.profileId,
          item.employeeUserId || null,
          parsed.year,
          parsed.month,
          item.monthlySalary,
          item.workingDays,
          item.paidDays,
          item.lopDays,
          item.deductions,
          item.netPay,
        ]
      );
    }
    const refreshed = await computeRows(parsed.year, parsed.month, parsed.today);
    return ok(res, {
      year: parsed.year,
      month: parsed.month,
      items: refreshed,
      kpis: toKpis(refreshed),
    }, 'Payroll generated for ' + MONTHS[parsed.month - 1] + ' ' + parsed.year);
  } catch (error) {
    console.error('POST /hrms/payroll/generate', error);
    return fail(res, 500, error.message);
  }
}

async function markPaid(req, res) {
  try {
    const id = Number(req.params.id);
    const status = String((req.body && req.body.status) || 'paid').toLowerCase();
    if (status !== 'paid' && status !== 'pending') {
      return fail(res, 400, 'status must be paid or pending');
    }
    const at = status === 'paid' ? policy.nowIstDateTime() : null;
    const [result] = await db.query(
      `UPDATE hrms_payroll_items
       SET status = ?, paid_at = ?
       WHERE id = ?`,
      [status, at, id]
    );
    if (!result.affectedRows) {
      return fail(res, 404, 'Payroll row not found. Generate payroll for this month first.');
    }
    const [rows] = await db.query('SELECT * FROM hrms_payroll_items WHERE id = ?', [id]);
    return ok(res, rows[0] || {}, 'Marked ' + status);
  } catch (error) {
    console.error('PATCH /hrms/payroll/:id', error);
    return fail(res, 500, error.message);
  }
}

module.exports = {
  requireAdmin,
  list,
  generate,
  markPaid,
};