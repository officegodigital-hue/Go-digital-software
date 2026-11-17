const db = require('../config/db');
const policy = require('../lib/attendancePolicy');
const { isWorkingDay } = require('./auto-absence');

async function primaryAdmin() {
  const [[admin]] = await db.query(`
    SELECT id, full_name FROM employee_users
    WHERE is_active = 1 AND (user_type = 'admin' OR is_main_admin = 1)
    ORDER BY is_main_admin DESC, id LIMIT 1
  `);
  return admin;
}

async function exceptions(query, id, date) {
  const [[row]] = await query.query(`
    SELECT EXISTS (SELECT 1 FROM employee_leaves WHERE employee_id = ?
      AND ? BETWEEN from_date AND to_date AND status IN ('pending', 'approved')) AS on_leave,
    EXISTS (SELECT 1 FROM attendance_permission_requests WHERE employee_id = ?
      AND request_date = ? AND status IN ('pending', 'approved')) AS permission
  `, [id, date, id, date]);
  return row;
}

async function insertMessage(query, sender, recipient, message) {
  const [result] = await query.query(
    'INSERT INTO notifications (sender_name, recipient_name, message, is_group, is_seen) VALUES (?, ?, ?, 0, 0)',
    [sender, recipient, message]
  );
  return { id: result.insertId, senderName: sender, recipientName: recipient, message,
    time: 'Just Now', createdAt: new Date().toISOString(), isGroup: false, isSeen: false };
}

function emitMessage(io, message) {
  if (!io || !message) return;
  io.emit('receive_message', message);
  io.emit('new_notification', {
    recipient: message.recipientName, sender: message.senderName,
    message: message.message, isGroup: false, messageId: message.id
  });
}

async function attendanceManager() {
  const [people] = await db.query(`
    SELECT id, full_name, is_main_admin FROM employee_users
    WHERE is_active = 1 AND LOWER(TRIM(role)) = 'manager'
    ORDER BY is_main_admin DESC, id
  `);
  if (people.length === 1 || (people[0]?.is_main_admin && !people[1]?.is_main_admin)) {
    return people[0];
  }
  return null;
}
async function attendanceUpdate(io, id, date, at, action, late = false) {
  try {
    const day = await exceptions(db, id, date);
    const admin = day.permission ? await attendanceManager() : await primaryAdmin();
    const [[employee]] = await db.query('SELECT full_name FROM employee_users WHERE id = ?', [id]);
    if (!admin || !employee || Number(admin.id) === Number(id)) return;
    const message = `${employee.full_name} checked ${action} at ${policy.formatDisplayTime(at)}.`;
    const label = late && !day.permission ? 'Late check-in. ' : '';
    emitMessage(io, await insertMessage(db, employee.full_name, admin.full_name, label + message));
  } catch (error) {
    console.error('Attendance chat update failed:', error.message);
  }
}

let running = false;
let auditReady = false;

async function runReminders(io) {
  if (running) return;
  running = true;
  try {
    if (!auditReady) {
      await db.query(`CREATE TABLE IF NOT EXISTS hrms_attendance_chat_reminders (
        employee_id INT NOT NULL, attendance_date DATE NOT NULL,
        kind VARCHAR(10) NOT NULL, sent_at DATETIME NOT NULL,
        PRIMARY KEY (employee_id, attendance_date, kind)
      ) ENGINE=InnoDB`);
      auditReady = true;
    }
    const admin = await attendanceManager();
    if (!admin) return;
    const { date, time, dateTime } = policy.partsInZone();
    const { shiftStart, shiftEnd } = await policy.getTimeSettings(db);
    const overnight = shiftEnd < shiftStart;
    if (!overnight && time <= shiftStart) return;
    const yesterday = new Date(Date.parse(date + 'T00:00:00Z') - 86400000).toISOString().slice(0, 10);
    const [employees] = await db.query(`
      SELECT u.id, u.full_name, COALESCE(NULLIF(p.department, ''), u.role, '') AS department
      FROM employee_users u LEFT JOIN hrms_employee_profiles p ON p.employee_user_id = u.id
      WHERE u.user_type = 'employee' AND u.is_active = 1 AND u.id <> ?
    `, [admin.id]);
    for (const employee of employees) {
      if (time > shiftStart && (overnight || time < shiftEnd) && await isWorkingDay(date, employee)) {
        await remind(io, admin, employee, date, dateTime, 'check-in');
      }
      if (!overnight && time > shiftEnd) {
        await remind(io, admin, employee, date, dateTime, 'checkout');
      }
      if (overnight && time > shiftEnd) {
        await remind(io, admin, employee, yesterday, dateTime, 'checkout');
      }
    }
  } catch (error) {
    console.error('Attendance chat reminders failed:', error.message);
  } finally {
    running = false;
  }
}

async function remind(io, manager, employee, date, now, kind) {
  const connection = await db.getConnection();
  let message;
  let committed = false;
  try {
    await connection.beginTransaction();
    const [claim] = await connection.query(
      `INSERT IGNORE INTO hrms_attendance_chat_reminders
       (employee_id, attendance_date, kind, sent_at) VALUES (?, ?, ?, ?)`,
      [employee.id, date, kind, now]
    );
    if (!claim.affectedRows) {
      if (kind === 'check-in') return;
      const [updated] = await connection.query(
        `UPDATE hrms_attendance_chat_reminders SET sent_at = ?
         WHERE employee_id = ? AND attendance_date = ? AND kind = ?
           AND sent_at <= DATE_SUB(?, INTERVAL 30 MINUTE)`,
        [now, employee.id, date, kind, now]
      );
      if (!updated.affectedRows) return;
    }
    const [[record]] = await connection.query(
      'SELECT check_in_at, check_out_at FROM attendance_records WHERE employee_id = ? AND attendance_date = ? FOR UPDATE',
      [employee.id, date]
    );
    if (kind === 'check-in' ? record?.check_in_at : !record?.check_in_at || record.check_out_at) return;
    const day = await exceptions(connection, employee.id, date);
    if (day.on_leave || day.permission) return;
    message = await insertMessage(connection, manager.full_name, employee.full_name,
      kind === 'check-in' ? 'Reminder: Please check in.' : 'Reminder: Please check out.');
    await connection.commit();
    committed = true;
  } finally {
    try {
      if (!committed) await connection.rollback();
    } finally {
      connection.release();
    }
  }
  emitMessage(io, message);
}

module.exports = { attendanceUpdate, runReminders };
