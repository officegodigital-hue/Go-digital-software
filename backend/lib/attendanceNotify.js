// lib/attendanceNotify.js
//
// Posts attendance/leave/permission events into the shared `notifications`
// table. Those rows surface in the Chat/notification centre and are pushed to
// phones by the notification watcher (lib/pushNotifications.js). All helpers are
// fire-and-forget: a notification failure must never break the attendance flow.
const db = require('../config/db');
const { createNotification } = require('../routes/notifications');

// Employees live in `employee_users`; attendance handlers use their id as
// req.user.id / employee_id. Notifications target people by their display name.
async function employeeName(id) {
  if (!id) return null;
  try {
    const [rows] = await db.query('SELECT full_name FROM employee_users WHERE id = ? LIMIT 1', [id]);
    return rows[0]?.full_name || null;
  } catch (_) {
    return null;
  }
}

async function adminNames() {
  try {
    const [rows] = await db.query("SELECT name FROM users WHERE role = 'Admin' AND is_active = 1");
    return rows.map((r) => r.name).filter(Boolean);
  } catch (_) {
    return [];
  }
}

async function notifyAdmins({ senderName, message }) {
  try {
    const admins = await adminNames();
    for (const admin of admins) {
      await createNotification({ senderName: senderName || 'Attendance', recipientName: admin, message });
    }
  } catch (error) {
    console.error('attendanceNotify.notifyAdmins failed:', error.message);
  }
}

async function notifyUserByName(name, { senderName, message }) {
  if (!name) return;
  try {
    await createNotification({ senderName: senderName || 'Admin', recipientName: name, message });
  } catch (error) {
    console.error('attendanceNotify.notifyUserByName failed:', error.message);
  }
}

async function notifyEmployeeById(id, opts) {
  const name = await employeeName(id);
  if (name) await notifyUserByName(name, opts);
}

module.exports = { employeeName, notifyAdmins, notifyUserByName, notifyEmployeeById };
