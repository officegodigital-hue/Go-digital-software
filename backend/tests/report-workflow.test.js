'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const { detectProvider } = require('../controllers/dashboardOcr.controller');
const { listAssignedReportClients, canAccessReportClient } = require('../lib/reportTaskAccess');
const { ensureFullReportExportSchema } = require('../lib/ensureFullReportExportSchema');
const { ensureReportWorkflowSchema } = require('../lib/ensureReportWorkflowSchema');
const { buildReportHtml } = require('../services/reportHtml.service');

test('full report schema initializes storage needed by submit and download', async () => {
  const statements = [];
  await ensureFullReportExportSchema({
    query: async (sql) => statements.push(sql),
  });

  for (const table of [
    'client_profiles',
    'report_templates',
    'client_full_report_history',
    'report_submissions',
  ]) {
    assert.ok(statements.some((sql) => sql.includes(`CREATE TABLE IF NOT EXISTS ${table}`)));
  }
});

test('report workflow schema initializes draft, screenshot, and field storage', async () => {
  const statements = [];
  await ensureReportWorkflowSchema({
    query: async (sql) => statements.push(sql),
  });

  for (const table of [
    'report_workflow_drafts',
    'report_workflow_screenshots',
    'report_workflow_fields',
  ]) {
    assert.ok(statements.some((sql) => sql.includes(`CREATE TABLE IF NOT EXISTS ${table}`)));
  }
});

test('OCR provider detection identifies Analytics and Search Console dashboards', () => {
  assert.equal(detectProvider('Google Analytics 4 active users').name, 'Google Analytics');
  assert.equal(detectProvider('Google Search Console total clicks').name, 'Google Search Console');
});

test('report export includes only selected provider pages and retains mandatory pages', () => {
  const html = buildReportHtml({
    providers: [{ provider: 'GOOGLE_ANALYTICS' }],
    snapshots: [{ provider: 'GOOGLE_ANALYTICS', metrics: { active_users: '120' } }],
  });

  assert.match(html, /Google Analytics — Dashboard/);
  assert.doesNotMatch(html, /Google Ads — Dashboard/);
  assert.match(html, /Channel Summary/);
  assert.match(html, /Next Month Plan/);
});

test('assigned-client access recognizes names in multi-person Task Manager assignments', async () => {
  const task = {
    client_id: 3,
    client_name: 'Example Client',
    industry: 'Retail',
    task_id: 12,
    deliverables: 'Monthly campaign report',
    ads_handling: 'Alex Smith, Jane Doe',
    ads_platform: 'Google Ads',
    page_handling: 'Other Employee',
    pages_platform: 'Instagram',
    deadline: null,
  };
  const db = {
    query: async (sql, params) => {
      if (sql.includes('SELECT id, full_name')) {
        return [[{ id: 8, full_name: 'Jane Doe' }]];
      }
      if (sql.includes('SELECT full_name')) {
        return [[{ full_name: 'Jane Doe' }]];
      }
      if (sql.includes('FROM report_client_assignments')) return [[]];
      if (params?.[0] === 'Other Client') return [[]];
      return [[task]];
    },
  };

  const clients = await listAssignedReportClients(db, 8);
  assert.equal(clients.length, 1);
  assert.equal(clients[0].assignedHandlers[0].role, 'Ads Handler');
  assert.equal(await canAccessReportClient(db, { id: 8 }, 'Example Client'), true);
  assert.equal(await canAccessReportClient(db, { id: 8 }, 'Other Client'), false);
});
