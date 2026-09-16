'use strict';

// Existing anomalies remain available for audited repair. These triggers prevent
// new orphan records or disagreement between profile and login ownership.
async function ensureEmployeeIdentityIntegrity(db) {
  const [columns] = await db.query(`SELECT TABLE_NAME, COLUMN_NAME FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND (TABLE_NAME LIKE 'hrms_%' OR TABLE_NAME LIKE 'attendance_%')
    AND COLUMN_NAME IN ('employee_id', 'employee_user_id')`);
  const [existing] = await db.query('SELECT TRIGGER_NAME FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA = DATABASE()');
  const names = new Set(existing.map(row => row.TRIGGER_NAME));
  for (const row of columns) {
    const table = row.TABLE_NAME;
    const column = row.COLUMN_NAME;
    if (!/^[a-zA-Z0-9_]+$/.test(table)) throw new Error('Unexpected identity table');
    for (const event of ['INSERT', 'UPDATE']) {
      const name = `identity_${event === 'INSERT' ? 'i' : 'u'}_${table}`;
      if (names.has(name)) continue;
      let checks = `IF NEW.${column} IS NOT NULL AND NOT EXISTS (SELECT 1 FROM employee_users WHERE id = NEW.${column}) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Employee account does not exist'; END IF;`;
      if (['hrms_payroll_items', 'hrms_employee_compensation'].includes(table)) {
        checks += ` IF NEW.profile_id IS NOT NULL AND NOT EXISTS
          (SELECT 1 FROM hrms_employee_profiles WHERE id = NEW.profile_id AND employee_user_id <=> NEW.employee_user_id) THEN
          SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Employee and profile ownership disagree'; END IF;`;
      }
      if (table === 'hrms_payslip_requests') {
        checks += ` IF NOT EXISTS (SELECT 1 FROM hrms_payroll_items WHERE id = NEW.payroll_item_id AND employee_user_id = NEW.employee_user_id) THEN
          SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Payslip employee does not own payroll'; END IF;`;
      }
      await db.query(`CREATE TRIGGER \`${name}\` BEFORE ${event} ON \`${table}\` FOR EACH ROW BEGIN ${checks} END`);
      names.add(name);
    }
  }
  for (const table of ['employee_users', 'hrms_employee_profiles']) {
    const name = `identity_retain_${table}`;
    if (!names.has(name)) await db.query(`CREATE TRIGGER ${name} BEFORE DELETE ON ${table} FOR EACH ROW
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Deactivate employees to retain historical ownership'`);
  }
}

module.exports = { ensureEmployeeIdentityIntegrity };
