const { test } = require('node:test');
const assert = require('node:assert/strict');
const { listEmployeeRecords } = require('./employeeRecords');

test('retained records summary is read-only, includes previous exits and keeps calendar dates', async () => {
  const queries = [];
  const result = await listEmployeeRecords({ query: async sql => {
    queries.push(sql);
    return [[{ employeeUserId: 7, name: 'Ravi', isActive: 0, lastWorkingDate: new Date(2026, 9, 28),
      originalJoiningDate: '2026-01-01', latestJoiningDate: '2026-01-01', settlementStatus: 'Needs review' },
      { employeeUserId: 8, name: 'Priya', isActive: 1, lastWorkingDate: '2026-10-20',
        latestJoiningDate: '2026-10-30', settlementStatus: 'Settled' }]];
  } });
  assert.equal(queries.length, 1);
  assert.match(queries[0], /WHERE u.is_active=0 OR e.id IS NOT NULL/);
  assert.ok(!/\b(UPDATE|DELETE|INSERT|ALTER|CREATE)\b/i.test(queries[0]));
  assert.equal(result[0].lastWorkingDate, '2026-10-28');
  assert.equal(result[0].isActive, false);
  assert.equal(result[1].isActive, true);
  assert.equal(result[1].latestJoiningDate, '2026-10-30');
});

test('records endpoint uses the existing authentication and admin guards', () => {
  const fs = require('node:fs');
  const vm = require('node:vm');
  const routes = [];
  const authenticate = () => {};
  const admin = () => {};
  const router = { get: (path, ...handlers) => routes.push({ path, handlers }), post: () => {}, patch: () => {} };
  vm.runInNewContext(fs.readFileSync(require.resolve('../routes/employeeLifecycle'), 'utf8'), {
    module: { exports: {} },
    require: path => path === 'express' ? { Router: () => router }
      : path === './auth' ? { authenticateToken: authenticate }
      : path === '../controllers/hrmsEmployeesController' ? { requireAdmin: admin } : {},
  });
  const recordRoute = routes.find(row => row.path === '/records');
  assert.ok(recordRoute);
  assert.equal(recordRoute.handlers[0][0], authenticate);
  assert.equal(recordRoute.handlers[0][1], admin);
});
