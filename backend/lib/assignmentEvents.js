// lib/assignmentEvents.js — remembers when a client is given to an employee
// (new admin assignment, admin moves a role from one person to another,
// Page/Ads Handler assigns / reassigns / emergency-assigns rows).
// The employee dashboard "New Clients" card counts these.
const db = require('../config/db');

let ready = null;
function ensureEventsTable() {
  if (!ready) {
    ready = db.query(
      `CREATE TABLE IF NOT EXISTS employee_assignment_events (
         id INT AUTO_INCREMENT PRIMARY KEY,
         employee_name VARCHAR(255) NOT NULL,
         client_name VARCHAR(255) NOT NULL,
         kind VARCHAR(40) NOT NULL,
         from_employee VARCHAR(255) NULL,
         by_name VARCHAR(255) NULL,
         assignment_id INT NULL,
         deliverable VARCHAR(255) NULL,
         due_date DATE NULL,
         created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
         INDEX idx_eae_emp (employee_name),
         INDEX idx_eae_created (created_at)
       )`,
    ).catch((err) => {
      ready = null;
      throw err;
    });
  }
  return ready;
}

const ymd = (v) => {
  if (!v) return null;
  if (v instanceof Date) {
    if (Number.isNaN(v.getTime())) return null;
    const p = (n) => String(n).padStart(2, '0');
    return `${v.getFullYear()}-${p(v.getMonth() + 1)}-${p(v.getDate())}`;
  }
  const s = String(v).trim().slice(0, 10);
  return /^\d{4}-\d{2}-\d{2}$/.test(s) ? s : null;
};

/** Never throws — a failed log must not break the assignment itself. */
async function logAssignmentEvent(ev) {
  try {
    if (!ev || !String(ev.employee || '').trim() || !String(ev.client || '').trim()) return;
    await ensureEventsTable();
    await db.query(
      `INSERT INTO employee_assignment_events
         (employee_name, client_name, kind, from_employee, by_name, assignment_id, deliverable, due_date)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        String(ev.employee).trim(),
        String(ev.client).trim(),
        String(ev.kind || 'ASSIGNED').slice(0, 40),
        ev.from ? String(ev.from).trim() : null,
        ev.by ? String(ev.by).trim() : null,
        ev.assignmentId || null,
        ev.deliverable ? String(ev.deliverable).slice(0, 255) : null,
        ymd(ev.due),
      ],
    );
  } catch (err) {
    console.warn('assignment event not saved:', err.message);
  }
}

module.exports = { ensureEventsTable, logAssignmentEvent };
