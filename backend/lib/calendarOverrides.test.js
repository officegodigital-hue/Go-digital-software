const test = require('node:test');
const assert = require('node:assert/strict');
const { resolveEffectiveOverrides } = require('./calendarOverrides');

test('selected employee override wins over department and all-employee rules', () => {
  const rows = [
    { work_date: '2026-10-10', status: 'Holiday', scope_type: 'all' },
    { work_date: '2026-10-10', status: 'Weekly Off', scope_type: 'department', department: 'Sales' },
    { work_date: '2026-10-10', status: 'Working Day', scope_type: 'employees', employee_id: 7 },
  ];
  const values = resolveEffectiveOverrides(rows, [
    { employee_user_id: 7, department: 'Sales' },
    { employee_user_id: 8, department: 'Sales' },
    { employee_user_id: 9, department: 'Design' },
  ]);
  assert.equal(values.get(7).get('2026-10-10').status, 'Working Day');
  assert.equal(values.get(8).get('2026-10-10').status, 'Weekly Off');
  assert.equal(values.get(9).get('2026-10-10').status, 'Holiday');
});
