const db = require('./config/db');

(async () => {
  try {
    const [users] = await db.query(`
      SELECT
        e.id,
        e.full_name AS employee_name,
        e.role,
        e.user_type,
        e.is_main_admin,
        CASE
          WHEN LOWER(TRIM(COALESCE(e.user_type, ''))) = 'admin'
            OR COALESCE(e.is_main_admin, 0) = 1
          THEN 'Account Admin'
          WHEN EXISTS (
            SELECT 1 FROM employee_application_access ea
            WHERE ea.employee_id = e.id
              AND LOWER(TRIM(ea.access_type)) = 'admin'
          )
          THEN 'Employee Admin Access'
          WHEN NOT EXISTS (
            SELECT 1 FROM employee_application_access ea
            WHERE ea.employee_id = e.id
          )
          AND EXISTS (
            SELECT 1 FROM role_application_access ra
            JOIN user_roles ur ON ur.id = ra.role_id
            WHERE UPPER(TRIM(ur.role_name)) = UPPER(TRIM(e.role))
              AND LOWER(TRIM(ra.access_type)) = 'admin'
          )
          THEN 'Role Admin Access'
        END AS admin_access_source
      FROM employee_users e
      WHERE e.is_active = 1
        AND (
          LOWER(TRIM(COALESCE(e.user_type, ''))) = 'admin'
          OR COALESCE(e.is_main_admin, 0) = 1
          OR EXISTS (
            SELECT 1 FROM employee_application_access ea
            WHERE ea.employee_id = e.id
              AND LOWER(TRIM(ea.access_type)) = 'admin'
          )
          OR (
            NOT EXISTS (
              SELECT 1 FROM employee_application_access ea
              WHERE ea.employee_id = e.id
            )
            AND EXISTS (
              SELECT 1 FROM role_application_access ra
              JOIN user_roles ur ON ur.id = ra.role_id
              WHERE UPPER(TRIM(ur.role_name)) = UPPER(TRIM(e.role))
                AND LOWER(TRIM(ra.access_type)) = 'admin'
            )
          )
        )
      ORDER BY e.full_name
    `);

    console.table(users);
    console.log('Total active users with Admin access:', users.length);
  } catch (error) {
    console.error('Error:', error.message);
  } finally {
    await db.end();
  }
})();
