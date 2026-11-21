'use strict';

const {
  loadEmployeeRoles,
  loadRoleApplicationAccess,
} = require('./employeeRoles');

function isAdmin(user) {
  return String(user?.userType || '').toLowerCase() === 'admin'
    || user?.isMainAdmin === true
    || String(user?.reportAccessType || '').toLowerCase() === 'admin'
    || String(user?.role || '').toLowerCase() === 'admin';
}

function nameKey(value) {
  return String(value || '').toLowerCase().replace(/[^a-z0-9]+/g, '');
}

function isAssignedName(cell, employeeName) {
  const expected = nameKey(employeeName);
  if (!expected) return false;
  return String(cell || '')
    .split(/,|&|\/|\band\b/i)
    .some((name) => nameKey(name) === expected);
}

async function reportAccessType(db, user) {
  if (isAdmin(user)) return 'admin';
  if (!user?.id) return 'none';

  const [directRows] = await db.query(
    `SELECT access_type FROM employee_application_access
     WHERE employee_id = ? AND application = 'reports' LIMIT 1`,
    [user.id],
  );
  if (directRows.length) {
    return String(directRows[0].access_type || 'none').toLowerCase();
  }

  const roles = await loadEmployeeRoles(db, user.id, user.role);
  const access = await loadRoleApplicationAccess(
    db,
    roles.map((role) => Number(role.id)),
  );
  return String(access.reports?.accessType || 'none').toLowerCase();
}

async function listAssignedReportClients(db, userId) {
  const [[employee]] = await db.query(
    `SELECT id, full_name FROM employee_users
     WHERE id = ? AND COALESCE(is_active, 1) = 1 LIMIT 1`,
    [userId],
  );
  if (!employee) {
    const error = new Error('The signed-in employee is unavailable.');
    error.status = 403;
    throw error;
  }

  const [rows] = await db.query(
    `SELECT
       c.id AS client_id,
       c.company_name AS client_name,
       c.industry,
       ta.id AS task_id,
       ta.deliverables,
       ta.ads_handling,
       ta.ads_platform,
       ta.page_handling,
       ta.pages_platform,
       ta.deadline
     FROM task_assignments ta
     INNER JOIN clients c
       ON LOWER(TRIM(c.company_name)) = LOWER(TRIM(ta.client_name))
     WHERE ta.is_assigned = 1
       AND COALESCE(c.is_active, 1) = 1
     ORDER BY c.company_name, ta.created_at DESC, ta.id DESC`,
  );

  const clients = new Map();
  for (const row of rows.filter((item) =>
    isAssignedName(item.ads_handling, employee.full_name)
    || isAssignedName(item.page_handling, employee.full_name))) {
    const clientId = Number(row.client_id);
    let client = clients.get(clientId);
    if (!client) {
      client = {
        id: clientId,
        name: row.client_name,
        industry: row.industry || '',
        assignedHandlers: [],
        assignedTasks: [],
      };
      clients.set(clientId, client);
    }

    if (isAssignedName(row.ads_handling, employee.full_name)) {
      client.assignedHandlers.push({
        role: 'Ads Handler',
        employee: employee.full_name,
        task: row.ads_platform || '',
      });
      client.assignedTasks.push({
        taskId: Number(row.task_id),
        role: 'Ads Handler',
        task: row.ads_platform || '',
        deliverables: row.deliverables || '',
        deadline: row.deadline || null,
      });
    }
    if (isAssignedName(row.page_handling, employee.full_name)) {
      client.assignedHandlers.push({
        role: 'Page Handler',
        employee: employee.full_name,
        task: row.pages_platform || '',
      });
      client.assignedTasks.push({
        taskId: Number(row.task_id),
        role: 'Page Handler',
        task: row.pages_platform || '',
        deliverables: row.deliverables || '',
        deadline: row.deadline || null,
      });
    }
  }

  // Merge in report-module-owned assignments (lib/ensureReportClientSchema.js),
  // keyed by company_name; these may reference clients that don't exist in the
  // Task Manager `clients` table, so they stand on their own.
  try {
    const [reportRows] = await db.query(
      `SELECT company_name, providers FROM report_client_assignments
       WHERE employee_id = ? AND active = 1`,
      [userId],
    );
    const byName = new Map(
      [...clients.values()].map((c) => [nameKey(c.name), c]),
    );
    for (const row of reportRows) {
      const key = nameKey(row.company_name);
      let client = byName.get(key);
      if (!client) {
        client = {
          id: null,
          name: row.company_name,
          industry: '',
          assignedHandlers: [],
          assignedTasks: [],
        };
        clients.set(`report:${key}`, client);
        byName.set(key, client);
      }
      let providers = [];
      try {
        const parsed = JSON.parse(row.providers || '[]');
        if (Array.isArray(parsed)) providers = parsed.map((p) => String(p));
      } catch (_) { /* ignore malformed JSON */ }
      for (const provider of providers) {
        if (client.assignedTasks.some((t) => t.task === provider)) continue;
        client.assignedHandlers.push({ role: 'Report Handler', task: provider });
        client.assignedTasks.push({
          taskId: null,
          role: 'Report Handler',
          task: provider,
          deliverables: '',
          deadline: null,
        });
      }
    }
  } catch (error) {
    if (!/doesn't exist|no such table/i.test(error.message || '')) throw error;
  }

  // Attach client logos (stored in client_profiles, keyed by company_name) so
  // the employee's client cards and report header can show the brand logo.
  try {
    const all = [...clients.values()];
    const names = all.map((c) => c.name).filter(Boolean);
    if (names.length) {
      const [logos] = await db.query(
        `SELECT company_name, logo_data, logo_mime_type FROM client_profiles
         WHERE company_name IN (${names.map(() => '?').join(',')})`,
        names,
      );
      const byName = new Map(logos.map((l) => [nameKey(l.company_name), l]));
      for (const c of all) {
        const logo = byName.get(nameKey(c.name));
        if (logo?.logo_data) {
          c.logoBase64 = logo.logo_data.toString('base64');
          c.logoMimeType = logo.logo_mime_type || 'image/png';
        }
      }
    }
  } catch (error) {
    if (!/doesn't exist|no such table/i.test(error.message || '')) throw error;
  }

  return [...clients.values()];
}

async function canAccessReportClient(db, user, companyName) {
  if (isAdmin(user)) return true;
  if (!user?.id || !String(companyName || '').trim()) return false;

  // Report-module assignment grants access directly (keyed by company_name).
  try {
    const [reportRows] = await db.query(
      `SELECT 1 FROM report_client_assignments
       WHERE employee_id = ? AND active = 1
         AND LOWER(TRIM(company_name)) = LOWER(TRIM(?)) LIMIT 1`,
      [user.id, companyName],
    );
    if (reportRows.length) return true;
  } catch (error) {
    if (!/doesn't exist|no such table/i.test(error.message || '')) throw error;
  }

  const [[employee]] = await db.query(
    `SELECT full_name FROM employee_users
     WHERE id = ? AND COALESCE(is_active, 1) = 1 LIMIT 1`,
    [user.id],
  );
  if (!employee?.full_name) return false;

  const [rows] = await db.query(
    `SELECT ta.ads_handling, ta.page_handling
     FROM task_assignments ta
     INNER JOIN clients c
       ON LOWER(TRIM(c.company_name)) = LOWER(TRIM(ta.client_name))
     WHERE LOWER(TRIM(c.company_name)) = LOWER(TRIM(?))
       AND COALESCE(c.is_active, 1) = 1
       AND ta.is_assigned = 1
     `,
    [companyName],
  );
  return rows.some((row) =>
    isAssignedName(row.ads_handling, employee.full_name)
    || isAssignedName(row.page_handling, employee.full_name));
}

module.exports = {
  canAccessReportClient,
  isAdmin,
  listAssignedReportClients,
  reportAccessType,
};
