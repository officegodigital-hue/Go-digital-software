const db = require('../config/db');
const policy = require('./attendancePolicy');
const { dateKey, validDate } = require('./employmentDates');
const { createHash } = require('node:crypto');

let ready;
function ensureLifecycle() {
  if (!ready) ready = setup().catch(error => { ready = null; throw error; });
  return ready;
}
async function setup() {
  const [joiningColumn] = await db.query("SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='employee_users' AND COLUMN_NAME='date_of_joining'");
  if (!joiningColumn.length) {
    try { await db.query('ALTER TABLE employee_users ADD COLUMN date_of_joining DATE NULL'); }
    catch(error) { if (error.code !== 'ER_DUP_FIELDNAME') throw error; }
  }
  await db.query(`CREATE TABLE IF NOT EXISTS employee_employment_periods (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, employee_user_id INT NOT NULL,
    started_on DATE NOT NULL, ended_on DATE NULL, created_by INT NULL,
    INDEX employee_period (employee_user_id, started_on, ended_on))`);
  await db.query(`CREATE TABLE IF NOT EXISTS employee_exits (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, employee_user_id INT NOT NULL,
    last_working_date DATE NOT NULL, reason TEXT NOT NULL, disabled_at DATETIME NOT NULL,
    created_by INT NOT NULL, settlement_status VARCHAR(40) NOT NULL DEFAULT 'Needs review',
    preview_json LONGTEXT NOT NULL, INDEX employee_exit (employee_user_id, id))`);
  await db.query(`CREATE TABLE IF NOT EXISTS employee_lifecycle_audit (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, employee_user_id INT NOT NULL,
    action VARCHAR(40) NOT NULL, details LONGTEXT NOT NULL, created_by INT NOT NULL,
    created_at DATETIME NOT NULL, INDEX employee_audit (employee_user_id, id))`);
  await db.query(`CREATE TABLE IF NOT EXISTS employee_salary_adjustments (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, exit_id BIGINT UNSIGNED NOT NULL,
    payroll_item_id BIGINT NOT NULL, employee_user_id INT NOT NULL,
    paid_amount DECIMAL(12,2) NOT NULL, calculated_amount DECIMAL(12,2) NOT NULL,
    difference DECIMAL(12,2) NOT NULL, resolution TEXT NULL, resolved_by INT NULL,
    resolved_at DATETIME NULL, UNIQUE KEY exit_payroll (exit_id,payroll_item_id))`);
  await db.query(`CREATE TABLE IF NOT EXISTS employee_exit_exceptions (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, employee_user_id INT NOT NULL,
    source_table VARCHAR(80) NOT NULL, source_id BIGINT NOT NULL, last_working_date DATE NOT NULL,
    record_hash CHAR(64) NOT NULL, reason TEXT NOT NULL, created_by INT NOT NULL,
    created_at DATETIME NOT NULL, INDEX employee_exception(employee_user_id,last_working_date))`);
  // Unknown legacy exit dates are deliberately not inferred from updated_at.
  await db.query(`INSERT INTO employee_employment_periods (employee_user_id, started_on)
    SELECT u.id, COALESCE(u.date_of_joining, DATE(u.created_at)) FROM employee_users u
    WHERE u.is_active = 1 AND NOT EXISTS
    (SELECT 1 FROM employee_employment_periods p WHERE p.employee_user_id = u.id)`);
}
function problem(message, status = 400, data) {
  return Object.assign(new Error(message), { status, data });
}
function serializeRecord(record) {
  return Object.fromEntries(Object.entries(record).map(([key,value])=>{
    if (!(value instanceof Date)) return [key,value];
    if (key.endsWith('_date') || ['joining_date','started_on','ended_on','period_start','period_end'].includes(key)) return [key,dateKey(value)];
    return [key,`${dateKey(value)} ${String(value.getHours()).padStart(2,'0')}:${String(value.getMinutes()).padStart(2,'0')}:${String(value.getSeconds()).padStart(2,'0')}`];
  }));
}
async function account(executor, id, lock = false) {
  const [[user]] = await executor.query(`SELECT id, full_name, created_at, date_of_joining AS joining_date, is_active FROM employee_users WHERE id = ?${lock ? ' FOR UPDATE' : ''}`, [id]);
  if (!user) throw problem('Employee not found', 404);
  return user;
}
function automaticLastWorkingDate() {
  const today = new Date(policy.todayIstDate() + 'T00:00:00Z');
  today.setUTCDate(today.getUTCDate() - 1);
  return today.toISOString().slice(0, 10);
}
function validateExit(user, body) {
  const date = body.lastWorkingDate;
  if (!validDate(date)) throw problem('Choose a valid last working date');
  if (date > policy.todayIstDate()) throw problem('Last working date cannot be in the future');
  if (user.joining_date && date < dateKey(user.joining_date)) throw problem('Last working date cannot precede joining date');
  if (!String(body.reason || '').trim()) throw problem('An exit reason is required');
  if (String(body.reason).length > 2000) throw problem('Exit reason must be 2000 characters or fewer');
}

// Fixed source allowlist; optional legacy modules are inspected before use.
const SOURCES = {
  attendance_records: { owners: ['employee_id'], dates: ['attendance_date'], attendance: true },
  hrms_attendance_sessions: { owners: ['employee_id'], dates: ['work_date'], attendance: true },
  employee_leaves: { owners: ['employee_id'], dates: ['from_date', 'to_date'] },
  attendance_permission_requests: { owners: ['employee_id'], dates: ['request_date'] },
  hrms_field_tracking_sessions: { owners: ['employee_user_id'], dates: ['started_at'] },
  live_tracking_sessions: { owners: ['employee_id'], dates: ['started_at'] },
  hrms_tracking_points: { owners: ['employee_user_id'], dates: ['recorded_at'], historyOnly:true },
  hrms_location_pings: { owners: ['employee_user_id'], dates: ['recorded_at'], historyOnly: true },
  hrms_tracking_locations: { owners: ['employee_user_id'], dates: ['recorded_at'], historyOnly:true },
};
async function sourceRows(executor, user) {
  const [schema] = await executor.query(`SELECT TABLE_NAME, COLUMN_NAME FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN (?)`, [Object.keys(SOURCES)]);
  const columns = new Map();
  schema.forEach(c => { if (!columns.has(c.TABLE_NAME)) columns.set(c.TABLE_NAME, new Set()); columns.get(c.TABLE_NAME).add(c.COLUMN_NAME); });
  const sources = [];
  for (const [table, spec] of Object.entries(SOURCES)) {
    const cols = columns.get(table);
    if (!cols || !cols.has('id')) continue;
    const owners = spec.owners.filter(c => cols.has(c));
    if (!owners.length) continue;
    const clauses = owners.map(c => c.endsWith('_id') ? `\`${c}\` = ?` : `LOWER(TRIM(\`${c}\`)) = LOWER(TRIM(?))`);
    const [rows] = await executor.query(`SELECT * FROM ${table} WHERE ${clauses.join(' OR ')} ORDER BY id DESC`, owners.map(c => c.endsWith('_id') ? user.id : user.full_name));
    sources.push({ table, spec, cols, owners, rows });
  }
  return sources;
}
async function inspect(executor, user, date) {
  const sources = await sourceRows(executor, user);
  const [exceptions] = await executor.query('SELECT * FROM employee_exit_exceptions WHERE employee_user_id=? AND last_working_date=?', [user.id,date]);
  const conflicts = [];
  for (const source of sources) for (const row of source.rows) {
    const after = source.spec.dates.some(c => row[c] && dateKey(row[c]) > date);
    const attendanceExists = source.spec.attendance && (row.check_in_at || row.clock_in_at || row.admin_status_override || ['present', 'late'].includes(String(row.attendance_status).toLowerCase()));
    if (after && attendanceExists) {
      const hash = createHash('sha256').update(JSON.stringify(row)).digest('hex');
      const resolution = exceptions.find(e => e.source_table === source.table && Number(e.source_id) === Number(row.id) && e.record_hash === hash);
      conflicts.push({ source: source.table, id: row.id, hash, resolved: !!resolution,
        resolution: resolution?.reason, date: source.spec.dates.map(c => dateKey(row[c])).filter(Boolean).join(' / ') });
    }
  }
  return { conflicts, sources };
}
async function salaryPreview(id, date, connection) {
  const payroll = require('../controllers/hrmsPayrollController');
  const [year, month] = date.split('-').map(Number);
  const result = [];
  if (!connection && payroll.ensureCustomCycleTable) await payroll.ensureCustomCycleTable();
  const executor=connection || db;
  const [custom]=await executor.query(`SELECT c.pay_year,c.pay_month FROM hrms_payroll_custom_cycles c
    JOIN hrms_employee_profiles p ON p.id=c.profile_id WHERE p.employee_user_id=? AND c.period_start<=? AND c.period_end>=?`,[id,date,date]);
  const candidates=new Map();
  // Include the next month: flexible cycles may end there.
  for (const offset of [0, 1]) {
    const target = new Date(Date.UTC(year, month - 1 + offset, 1));
    candidates.set(`${target.getUTCFullYear()}-${target.getUTCMonth()+1}`,[target.getUTCFullYear(),target.getUTCMonth()+1]);
  }
  for(const row of custom) candidates.set(`${row.pay_year}-${row.pay_month}`,[Number(row.pay_year),Number(row.pay_month)]);
  for(const [payYear,payMonth] of candidates.values()) {
    const items = await payroll.computeRows(payYear, payMonth, policy.todayIstDate(),
      { exitOverride: { employeeId: Number(id), date }, connection, skipSetup: !!connection });
    for (const item of items) if (Number(item.employeeUserId) === Number(id) && item.periodStart <= date && item.periodEnd >= date) result.push({...item,payYear,payMonth});
  }
  return result;
}
async function preview(id, body = {}) {
  body = { ...body, lastWorkingDate: automaticLastWorkingDate() };
  await ensureLifecycle();
  const user = await account(db, id);
  validateExit(user, body);
  const check = await inspect(db, user, body.lastWorkingDate);
  const salary = await salaryPreview(id, body.lastWorkingDate);
  return { lastWorkingDate: body.lastWorkingDate, conflicts: check.conflicts,
    salary, settlementStatus: salary.length && salary.every(s => s.monthlySalary && !s.integrityError) ? 'Review required' : 'Needs review' };
}
async function deactivate(id, body = {}, adminId, io) {
  body = { ...body, lastWorkingDate: automaticLastWorkingDate() };
  if (Number(id) === Number(adminId)) throw problem('You cannot deactivate your own account');
  // Warm payroll schemas outside the transaction (MySQL DDL implicitly commits).
  await preview(id, body);
  const connection = await db.getConnection();
  try {
    await connection.beginTransaction();
    const user = await account(connection, id, true);
    validateExit(user, body);
    const [[previous]] = await connection.query('SELECT id FROM employee_exits WHERE employee_user_id=? ORDER BY id DESC LIMIT 1', [id]);
    if (!Number(user.is_active) && previous) throw problem('Employee is already inactive', 409);
    const [periods] = await connection.query('SELECT * FROM employee_employment_periods WHERE employee_user_id=? ORDER BY started_on DESC FOR UPDATE', [id]);
    if (periods[0] && body.lastWorkingDate < dateKey(periods[0].started_on)) throw problem('Last working date precedes the current employment start');
    const check = await inspect(connection, user, body.lastWorkingDate);
    if (check.conflicts.some(c => !c.resolved)) throw problem('Resolve records after the last working date before confirming exit', 409, { conflicts: check.conflicts });
    const salary = await salaryPreview(id, body.lastWorkingDate, connection);
    const now = policy.nowIstDateTime();
    const settlementStatus=salary.length && salary.every(s=>s.monthlySalary && !s.integrityError) ? 'Review required' : 'Needs review';
    const [exit] = await connection.query(`INSERT INTO employee_exits
      (employee_user_id,last_working_date,reason,disabled_at,created_by,preview_json,settlement_status) VALUES (?,?,?,?,?,?,?)`,
      [id, body.lastWorkingDate, body.reason.trim(), now, adminId, JSON.stringify(salary),settlementStatus]);
    if (!periods.length) await connection.query('INSERT INTO employee_employment_periods (employee_user_id,started_on,ended_on,created_by) VALUES (?,?,?,?)', [id, dateKey(user.joining_date || user.created_at), body.lastWorkingDate, adminId]);
    else await connection.query('UPDATE employee_employment_periods SET ended_on=? WHERE employee_user_id=? AND ended_on IS NULL', [body.lastWorkingDate, id]);
    await connection.query('UPDATE employee_users SET is_active=0 WHERE id=?', [id]);
    await connection.query("UPDATE hrms_employee_profiles SET employment_status='Inactive' WHERE employee_user_id=?", [id]);
    for (const table of ['hrms_field_tracking_sessions', 'live_tracking_sessions']) {
      const tracking = check.sources.find(s => s.table === table);
      if (tracking && tracking.cols.has('is_active')) {
        const stop = tracking.cols.has('stopped_at') ? ',stopped_at=?' : '';
        const owner = table === 'live_tracking_sessions' ? 'employee_id' : 'employee_user_id';
        await connection.query(`UPDATE ${table} SET is_active=0${stop} WHERE ${owner}=? AND is_active=1`, stop ? [now, id] : [id]);
      }
    }
    const payroll = require('../controllers/hrmsPayrollController');
    const [savedPayroll] = await connection.query('SELECT * FROM hrms_payroll_items WHERE employee_user_id=? FOR UPDATE', [id]);
    for (const saved of savedPayroll) {
      const computed = (await payroll.computeRows(Number(saved.pay_year), Number(saved.pay_month), policy.todayIstDate(), { connection, skipSetup: true }))
        .find(p => Number(p.id) === Number(saved.id));
      if (!computed || computed.integrityError || !computed.monthlySalary) continue;
      if (saved.status === 'paid') {
        if (Math.abs(Number(saved.net_pay) - computed.calculatedNetPay) > 0.01) await connection.query(`INSERT INTO employee_salary_adjustments
          (exit_id,payroll_item_id,employee_user_id,paid_amount,calculated_amount,difference) VALUES (?,?,?,?,?,?)`,
          [exit.insertId, saved.id, id, saved.net_pay, computed.calculatedNetPay, computed.calculatedNetPay - Number(saved.net_pay)]);
      } else await connection.query(`UPDATE hrms_payroll_items SET working_days=?,daily_rate=?,paid_days=?,lop_days=?,deductions=?,net_pay=? WHERE id=? AND status<>'paid'`,
        [computed.workingDays, computed.dailyRate, computed.paidDays, computed.lopDays, computed.deductions, computed.netPay, saved.id]);
    }
    await connection.query(`INSERT INTO employee_lifecycle_audit (employee_user_id,action,details,created_by,created_at) VALUES (?,'EXIT',?,?,?)`, [id, JSON.stringify({ ...body, exitId: exit.insertId }), adminId, now]);
    await connection.commit();
    if (io) {
      for (const socket of io.sockets.sockets.values()) {
        if (Number(socket.data?.employeeId) === Number(id)) { socket.emit('account_deactivated'); socket.disconnect(true); }
      }
      io.emit('employee_status_changed', { employeeId: Number(id), active: false });
    }
    return { exitId: exit.insertId, lastWorkingDate: body.lastWorkingDate, settlementStatus };
  } catch (error) { await connection.rollback(); throw error; }
  finally { connection.release(); }
}
async function reactivate(id, body = {}, adminId) {
  body = { ...body, startDate: policy.todayIstDate() };
  await ensureLifecycle();
  const connection = await db.getConnection();
  try {
    await connection.beginTransaction();
    const user = await account(connection, id, true);
    if (Number(user.is_active)) throw problem('Employee is already active', 409);
    const [[last]] = await connection.query('SELECT last_working_date FROM employee_exits WHERE employee_user_id=? ORDER BY id DESC LIMIT 1', [id]);
    if (!last) throw problem('Record the previous last working date before reactivation');
    if (body.startDate <= dateKey(last.last_working_date)) throw problem('New start date must follow the previous last working date');
    await connection.query('INSERT INTO employee_employment_periods (employee_user_id,started_on,created_by) VALUES (?,?,?)', [id, body.startDate, adminId]);
    await connection.query('UPDATE employee_users SET is_active=1 WHERE id=?', [id]);
    await connection.query("UPDATE hrms_employee_profiles SET employment_status='Active' WHERE employee_user_id=?", [id]);
    await connection.query("INSERT INTO employee_lifecycle_audit (employee_user_id,action,details,created_by,created_at) VALUES (?,'REACTIVATE',?,?,?)", [id, JSON.stringify(body), adminId, policy.nowIstDateTime()]);
    await connection.commit();
    return { startDate: body.startDate };
  } catch (error) { await connection.rollback(); throw error; }
  finally { connection.release(); }
}
async function completeSettlement(id, adminId) {
  await ensureLifecycle();
  const [exits] = await db.query("SELECT * FROM employee_exits WHERE employee_user_id=? AND settlement_status<>'Settled' ORDER BY id", [id]);
  if (!exits.length) throw problem('No unsettled exit found');
  // Prepare optional payroll schemas before acquiring the transactional locks.
  for(const exit of exits) await salaryPreview(id, dateKey(exit.last_working_date));
  const connection = await db.getConnection();
  try {
    await connection.beginTransaction();
    await account(connection, id, true);
    const [lockedExits] = await connection.query("SELECT * FROM employee_exits WHERE employee_user_id=? AND settlement_status<>'Settled' ORDER BY id FOR UPDATE", [id]);
    const [unpaid] = await connection.query("SELECT id FROM hrms_payroll_items WHERE employee_user_id=? AND status<>'paid' FOR UPDATE", [id]);
    const [adjustments] = await connection.query('SELECT id FROM employee_salary_adjustments WHERE employee_user_id=? AND resolved_at IS NULL FOR UPDATE', [id]);
    const salary=[];
    for(const exit of lockedExits) {
      const cycle=await salaryPreview(id,dateKey(exit.last_working_date),connection);
      if(!cycle.length) throw problem('Final salary cycle is missing',409);
      salary.push(...cycle);
    }
    if (unpaid.length || adjustments.length || !salary.length || salary.some(s => !s.monthlySalary || s.integrityError || s.status !== 'Paid')) throw problem('Pay all outstanding salary and resolve adjustments before completing settlement',409);
    await connection.query("UPDATE employee_exits SET settlement_status='Settled' WHERE employee_user_id=?", [id]);
    await connection.query("INSERT INTO employee_lifecycle_audit (employee_user_id,action,details,created_by,created_at) VALUES (?,'SETTLEMENT_COMPLETE',?,?,?)", [id,JSON.stringify({exitIds:lockedExits.map(e=>e.id)}),adminId,policy.nowIstDateTime()]);
    await connection.commit(); return { settlementStatus:'Settled' };
  } catch(error) { await connection.rollback(); throw error; } finally { connection.release(); }
}
module.exports = { automaticLastWorkingDate, ensureLifecycle, preview, deactivate, reactivate, completeSettlement, salaryPreview, serializeRecord, account, inspect, sourceRows, SOURCES, problem };
