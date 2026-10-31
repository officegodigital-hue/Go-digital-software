// Read-only summary of retained employee records; lifecycle actions stay in their existing service.
async function listEmployeeRecords(db) {
  const [rows] = await db.query(`
    SELECT p.employee_user_id AS employeeUserId, p.employee_code AS employeeCode,
      p.full_name AS name, p.department, p.work_mode AS workMode, u.is_active AS isActive,
      u.date_of_joining AS originalJoiningDate,
      (SELECT MAX(ep.started_on) FROM employee_employment_periods ep
       WHERE ep.employee_user_id=u.id) AS latestJoiningDate,
      e.id AS exitId, e.last_working_date AS lastWorkingDate, e.reason,
      COALESCE(e.settlement_status, 'Exit date required') AS settlementStatus,
      e.disabled_at AS disabledAt
    FROM hrms_employee_profiles p
    JOIN employee_users u ON u.id=p.employee_user_id
    LEFT JOIN employee_exits e ON e.id=(SELECT MAX(x.id) FROM employee_exits x WHERE x.employee_user_id=u.id)
    WHERE u.is_active=0 OR e.id IS NOT NULL
    ORDER BY e.last_working_date DESC, p.full_name ASC
  `);
  // DATE columns must keep their calendar date regardless of the API host's timezone.
  const { dateKey } = require('./employmentDates');
  return rows.map(row => ({ ...row, isActive: Boolean(Number(row.isActive)),
    originalJoiningDate: row.originalJoiningDate ? dateKey(row.originalJoiningDate) : null,
    latestJoiningDate: row.latestJoiningDate ? dateKey(row.latestJoiningDate) : null,
    lastWorkingDate: row.lastWorkingDate ? dateKey(row.lastWorkingDate) : null }));
}
module.exports = { listEmployeeRecords };
