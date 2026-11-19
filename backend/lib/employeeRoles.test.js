'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  normalizeRoleIds,
  mergeRoleAccessRows,
} = require('./employeeRoles');

test('normalizes and deduplicates selected role IDs', () => {
  assert.deepEqual(normalizeRoleIds(['4', 2, 4]), [4, 2]);
  assert.equal(normalizeRoleIds([1, 'invalid']), null);
});

test('combines module access from all assigned roles', () => {
  const result = mergeRoleAccessRows([
    {
      application: 'client_repository',
      access_type: 'employee',
      allowed_pages: '["documents"]',
    },
    {
      application: 'client_repository',
      access_type: 'admin',
      allowed_pages: ['clients'],
    },
    {
      application: 'task_manager',
      access_type: 'none',
      allowed_pages: ['not-granted'],
    },
  ]);

  assert.deepEqual(result.client_repository, {
    accessType: 'admin',
    allowedPages: ['documents', 'clients'],
  });
  assert.deepEqual(result.task_manager, {
    accessType: 'none',
    allowedPages: [],
  });
});

test('combines role SOP access across assigned roles', () => {
  const result = mergeRoleAccessRows([
    {
      application: 'role_sop',
      access_type: 'none',
      allowed_pages: '[]',
    },
    {
      application: 'role_sop',
      access_type: 'employee',
      allowed_pages: '[]',
    },
  ]);

  assert.deepEqual(result.role_sop, {
    accessType: 'employee',
    allowedPages: [],
  });
});
