const db = require('../config/db');

function parsePages(value) {
  if (Array.isArray(value)) return value;

  try {
    const parsed = JSON.parse(value || '[]');
    return Array.isArray(parsed) ? parsed : [];
  } catch (_) {
    return [];
  }
}

function hasInvoicePage(pages) {
  return parsePages(pages).some(
    (page) => String(page).trim().toLowerCase() === '/invoice'
  );
}

async function getInvoiceAccess(employeeId) {
  const [[employee]] = await db.query(
    `SELECT id, full_name, role, is_active, is_main_admin
     FROM employee_users
     WHERE id = ?`,
    [employeeId]
  );

  if (!employee || !Number(employee.is_active)) {
    return { allowed: false, isMainAdmin: false };
  }

  const isMainAdmin = Number(employee.is_main_admin) === 1;

  if (isMainAdmin) {
    return { allowed: true, isMainAdmin: true };
  }

  const [appRows] = await db.query(
    `SELECT application, access_type, allowed_pages
     FROM employee_application_access
     WHERE employee_id = ?`,
    [employeeId]
  );

  let applicationAccess = appRows;

  if (appRows.length === 0 && employee.role) {
    const [roleRows] = await db.query(
      `SELECT ra.application, ra.access_type, ra.allowed_pages
       FROM role_application_access ra
       JOIN user_roles ur ON ur.id = ra.role_id
       WHERE UPPER(TRIM(ur.role_name)) = UPPER(TRIM(?))`,
      [employee.role]
    );

    applicationAccess = roleRows;
  }

  const hasApplicationAccess = applicationAccess.some((row) => {
    return (
      String(row.application).toLowerCase() === 'task_manager' &&
      ['employee', 'admin'].includes(
        String(row.access_type).toLowerCase()
      ) &&
      hasInvoicePage(row.allowed_pages)
    );
  });

  if (hasApplicationAccess) {
    return { allowed: true, isMainAdmin: false };
  }

  // Explicit application permissions take priority over legacy permissions.
  if (applicationAccess.length > 0) {
    return { allowed: false, isMainAdmin: false };
  }

  // Legacy page permissions.
  const [legacyRows] = await db.query(
    `SELECT allowed_pages
     FROM role_page_access
     WHERE employee_id = ?`,
    [employeeId]
  );

  const hasLegacyAccess = legacyRows.some((row) =>
    hasInvoicePage(row.allowed_pages)
  );

  return {
    allowed: hasLegacyAccess,
    isMainAdmin: false,
  };
}

module.exports = {
  getInvoiceAccess,
};
