// jobs/day-planner-reminders.js — scheduled deadline checks for Day Plan
// submission. Requires the `node-cron` package: npm install node-cron
//
// Register this once at server startup, e.g. in your main server file:
//   require('./jobs/day-planner-reminders')(db);
//
const cron = require('node-cron');
const { createNotification } = require('../routes/notifications');

function todayDateString() {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
}

// Every employee who's expected to submit a Day Plan today — anyone with
// an active task_list assignment. Adjust this query if you have a
// different definition of "active employee."
async function getActiveEmployeeNames(db) {
  const [rows] = await db.query(
    `SELECT DISTINCT employee_name FROM task_list WHERE employee_name IS NOT NULL AND employee_name != ''`
  );
  return rows.map((r) => r.employee_name);
}

// Employees from that list who have NOT submitted today's Day Plan yet.
// "Not submitted" = no day_plan_rows row for today with is_submitted = 1.
async function getUnsubmittedEmployees(db, date) {
  const activeEmployees = await getActiveEmployeeNames(db);
  if (activeEmployees.length === 0) return [];

  const [submittedRows] = await db.query(
    `SELECT DISTINCT employee_name FROM day_plan_rows WHERE plan_date = ? AND is_submitted = 1`,
    [date]
  );
  const submittedSet = new Set(submittedRows.map((r) => r.employee_name));

  return activeEmployees.filter((name) => !submittedSet.has(name));
}

module.exports = function registerDayPlannerReminders(db) {
  // ── 9:30 AM — first warning, sent to the employee ──────────────────────
  cron.schedule('30 9 * * *', async () => {
    try {
      const date = todayDateString();
      const unsubmitted = await getUnsubmittedEmployees(db, date);

      for (const employeeName of unsubmitted) {
        await createNotification({
          senderName: 'System',
          recipientName: employeeName,
          message: `Reminder: your Day Plan for today hasn't been submitted yet. Please submit it before 9:30 AM.`,
        });
      }
      console.log(`⏰ 9:30 Day Plan reminder sent to ${unsubmitted.length} employee(s).`);
    } catch (err) {
      console.error('❌ 9:30 Day Plan reminder job failed:', err.message);
    }
  });

  // ── 9:45 AM — escalated warning (also drives the in-app banner via the
  // status endpoint below — this notification is a backup channel) ───────
  cron.schedule('45 9 * * *', async () => {
    try {
      const date = todayDateString();
      const unsubmitted = await getUnsubmittedEmployees(db, date);

      for (const employeeName of unsubmitted) {
        await createNotification({
          senderName: 'System',
          recipientName: employeeName,
          message: `⚠️ URGENT: your Day Plan for today is still not submitted. Submit immediately to avoid being reported to Admin.`,
        });
      }
      console.log(`⚠️ 9:45 Day Plan escalation sent to ${unsubmitted.length} employee(s).`);
    } catch (err) {
      console.error('❌ 9:45 Day Plan escalation job failed:', err.message);
    }
  });

  // ── 10:00 AM — notify Admin about anyone still unsubmitted ──────────────
  cron.schedule('0 10 * * *', async () => {
    try {
      const date = todayDateString();
      const unsubmitted = await getUnsubmittedEmployees(db, date);

      for (const employeeName of unsubmitted) {
        await createNotification({
          senderName: 'System',
          recipientName: 'Admin',
          message: `${employeeName} has not submitted their Day Plan report for ${date}.`,
        });
      }
      console.log(`🚨 10:00 Admin alert sent for ${unsubmitted.length} unsubmitted employee(s).`);
    } catch (err) {
      console.error('❌ 10:00 Day Plan admin-alert job failed:', err.message);
    }
  });

  console.log('✅ Day Planner reminder cron jobs registered (9:30 / 9:45 / 10:00).');
};