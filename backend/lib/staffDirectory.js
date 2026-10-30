const STAFF = {
  table: process.env.STAFF_TABLE || 'employee_users',
  id: process.env.STAFF_ID_COLUMN || 'id',
  name: process.env.STAFF_NAME_COLUMN || 'full_name',
  role: process.env.STAFF_ROLE_COLUMN || 'role',
  active: process.env.STAFF_ACTIVE_COLUMN || 'is_active',
  staffCode: process.env.STAFF_CODE_COLUMN || 'staff_id',
};

function quote(identifier) {
  return '`' + String(identifier).replace(/`/g, '') + '`';
}

function staffFrom() {
  return quote(STAFF.table);
}

function staffSelect(alias) {
  alias = alias || 's';
  var a = quote(alias);
  return a + '.' + quote(STAFF.id) + ' AS id, ' +
    a + '.' + quote(STAFF.name) + ' AS full_name, ' +
    a + '.' + quote(STAFF.role) + ' AS role, ' +
    a + '.' + quote(STAFF.staffCode) + ' AS staff_id, ' +
    a + '.' + quote(STAFF.active) + ' AS is_active';
}

function activeCondition(alias) {
  alias = alias || 's';
  return quote(alias) + '.' + quote(STAFF.active) + ' = 1';
}

async function listActiveStaff(db) {
  const [rows] = await db.query(
    'SELECT ' + staffSelect('s') + ' FROM ' + staffFrom() + ' s WHERE ' + activeCondition('s') +
    ' ORDER BY s.' + quote(STAFF.name) + ' ASC'
  );
  return rows;
}

async function listHistoricalStaff(db, start, end) {
  await require('./employeeLifecycle').ensureLifecycle();
  const [rows] = await db.query('SELECT ' + staffSelect('s') + ' FROM ' + staffFrom() + ` s WHERE
    EXISTS (SELECT 1 FROM employee_employment_periods p WHERE p.employee_user_id=s.id AND p.started_on<=? AND (p.ended_on IS NULL OR p.ended_on>=?))
    OR EXISTS (SELECT 1 FROM attendance_records a WHERE a.employee_id=s.id AND a.attendance_date BETWEEN ? AND ?)
    ORDER BY s.` + quote(STAFF.name), [end,start,start,end]);
  return rows;
}

async function findStaffById(db, id) {
  const [rows] = await db.query(
    'SELECT ' + staffSelect('s') + ' FROM ' + staffFrom() + ' s WHERE s.' + quote(STAFF.id) + ' = ? LIMIT 1',
    [id]
  );
  return rows[0] || null;
}

module.exports = {
  STAFF: STAFF,
  quote: quote,
  staffFrom: staffFrom,
  staffSelect: staffSelect,
  activeCondition: activeCondition,
  listActiveStaff: listActiveStaff,
  listHistoricalStaff,
  findStaffById: findStaffById
};