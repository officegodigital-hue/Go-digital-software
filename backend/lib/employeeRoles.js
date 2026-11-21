'use strict';

const APPLICATIONS = ['attendance', 'task_manager', 'client_repository', 'role_sop', 'reports'];
const ACCESS_RANK = { none: 0, employee: 1, admin: 2 };

function invalidRoleAssignment(message) {
  const error = new Error(message);
  error.status = 400;
  return error;
}

function normalizeRoleIds(value) {
  if (!Array.isArray(value)) return null;
  const ids = value.map((item) => Number(item));
  if (ids.some((id) => !Number.isSafeInteger(id) || id <= 0)) return null;
  return [...new Set(ids)];
}

function parsePages(value) {
  if (Array.isArray(value)) return value.map(String);
  try {
    const parsed = JSON.parse(value || '[]');
    return Array.isArray(parsed) ? parsed.map(String) : [];
  } catch (_) {
    return [];
  }
}

function mergeRoleAccessRows(rows) {
  const access = Object.fromEntries(
    APPLICATIONS.map((application) => [
      application,
      { accessType: 'none', allowedPages: [] },
    ]),
  );

  for (const row of rows) {
    const application = String(row.application || '').trim().toLowerCase();
    if (!access[application]) continue;

    const accessType = String(row.access_type || row.accessType || 'none').toLowerCase();
    if (!(accessType in ACCESS_RANK) || accessType === 'none') continue;
    const current = access[application];
    if (ACCESS_RANK[accessType] > ACCESS_RANK[current.accessType]) {
      current.accessType = accessType;
    }
    current.allowedPages = [
      ...new Set([...current.allowedPages, ...parsePages(row.allowed_pages ?? row.allowedPages)]),
    ];
  }
  return access;
}

async function loadEmployeeRoles(connection, employeeId, legacyRole) {
  const [rows] = await connection.query(`
    SELECT ur.id, ur.role_name, ur.user_type
    FROM employee_user_roles eur
    INNER JOIN user_roles ur ON ur.id = eur.role_id
    WHERE eur.employee_id = ?
    ORDER BY ur.role_name
  `, [employeeId]);
  if (rows.length || !legacyRole) return rows;
  const [legacyRows] = await connection.query(`
    SELECT id, role_name, user_type
    FROM user_roles
    WHERE UPPER(TRIM(role_name)) = UPPER(TRIM(?))
    ORDER BY id
  `, [legacyRole]);
  return legacyRows;
}

async function saveEmployeeRoleAssignments(connection, employeeId, roleIds, legacyRole, userType) {
  let roles;
  if (roleIds !== null) {
    if (!roleIds.length) {
      throw invalidRoleAssignment('At least one access role must be selected.');
    }
    const [found] = await connection.query(
      'SELECT id, role_name, user_type FROM user_roles WHERE id IN (?)',
      [roleIds],
    );
    if (found.length !== roleIds.length) {
      throw invalidRoleAssignment('One or more selected roles do not exist.');
    }
    if (found.some((role) => String(role.user_type).toLowerCase() !== String(userType).toLowerCase())) {
      throw invalidRoleAssignment('Selected roles must match the employee account type.');
    }
    roles = found;
  } else {
    const [found] = await connection.query(`
      SELECT id, role_name, user_type
      FROM user_roles
      WHERE UPPER(TRIM(role_name)) = UPPER(TRIM(?))
      ORDER BY id
    `, [legacyRole]);
    roles = found;
  }

  await connection.query('DELETE FROM employee_user_roles WHERE employee_id = ?', [employeeId]);
  for (const role of roles) {
    await connection.query(
      'INSERT INTO employee_user_roles (employee_id, role_id) VALUES (?, ?)',
      [employeeId, role.id],
    );
  }
  return roles;
}

async function loadRoleApplicationAccess(connection, roleIds) {
  if (!roleIds.length) return mergeRoleAccessRows([]);
  const [rows] = await connection.query(`
    SELECT application, access_type, allowed_pages
    FROM role_application_access
    WHERE role_id IN (?)
  `, [roleIds]);
  return mergeRoleAccessRows(rows);
}

async function saveEmployeeApplicationAccess(connection, employeeId, access) {
  for (const application of APPLICATIONS) {
    const item = access[application] || {};
    await connection.query(`
      INSERT INTO employee_application_access
        (employee_id, application, access_type, allowed_pages)
      VALUES (?, ?, ?, ?)
      ON DUPLICATE KEY UPDATE
        access_type = VALUES(access_type),
        allowed_pages = VALUES(allowed_pages)
    `, [
      employeeId,
      application,
      item.accessType,
      JSON.stringify(item.allowedPages),
    ]);
  }
}

async function refreshEmployeeApplicationAccess(connection, employeeIds) {
  for (const employeeId of employeeIds) {
    const [employeeRows] = await connection.query(
      'SELECT role FROM employee_users WHERE id = ?',
      [employeeId],
    );
    if (!employeeRows.length) continue;
    const roles = await loadEmployeeRoles(connection, employeeId, employeeRows[0].role);
    const access = await loadRoleApplicationAccess(
      connection,
      roles.map((role) => Number(role.id)),
    );
    await saveEmployeeApplicationAccess(connection, employeeId, access);
  }
}

module.exports = {
  APPLICATIONS,
  normalizeRoleIds,
  mergeRoleAccessRows,
  loadEmployeeRoles,
  saveEmployeeRoleAssignments,
  loadRoleApplicationAccess,
  saveEmployeeApplicationAccess,
  refreshEmployeeApplicationAccess,
};
