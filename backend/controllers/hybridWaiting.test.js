const { test } = require('node:test');
const assert = require('node:assert/strict');
let fixture;
const saved = new Map();
async function query(sql, params) {
  if (sql.includes('FROM hrms_field_tracking_sessions')) return [fixture.active === false ? [] : [{ id: fixture.session, started_at: '2026-10-30 09:00:00' }]];
  if (sql.includes('FROM hrms_tracking_settings')) return [[fixture.settings || { field_waiting_minutes: 1, stationary_radius_meters: 1000 }]];
  if (sql.includes('FROM hrms_field_waiting_reasons')) return [fixture.pending ? [{ id: 1 }] : []];
  if (sql.includes('FROM hrms_location_pings')) return [fixture.pings];
  if (sql.includes('INSERT IGNORE INTO hrms_field_waiting_reasons')) {
    fixture.attempts++;
    if (saved.has(params[6])) return [{ affectedRows: 0 }];
    saved.set(params[6], params);
    return [{ affectedRows: 1 }];
  }
  throw Error('Unexpected SQL: ' + sql);
}
require.cache[require.resolve('../config/db')] = { exports: { query } };
const { detectFieldWaitingTime } = require('./hrmsTrackingController');
const now = Date.parse('2026-10-30T09:02:00Z');
function ping(secondsAgo, latitude = 13) {
  return { latitude, longitude: 80, recorded_at: new Date(now - secondsAgo * 1000) };
}
function reset(t) {
  t.mock.method(Date, 'now', () => now);
  saved.clear();
  fixture = { session: 10, pings: [ping(60), ping(0)], attempts: 0 };
}
test('one minute inside the test radius creates an alert; another session gets its own alert', async t => {
  reset(t);
  await detectFieldWaitingTime(7, 13, 80);
  fixture.session = 11;
  await detectFieldWaitingTime(8, 13, 80);
  assert.equal(saved.size, 2);
  assert.deepEqual([...saved.keys()], ['10:2026-10-30T09:01:00.000Z', '11:2026-10-30T09:01:00.000Z']);
});
test('same stop stays deduplicated after submitting a reason; a new stop can alert', async t => {
  reset(t);
  await detectFieldWaitingTime(7, 13, 80);
  await detectFieldWaitingTime(7, 13, 80);
  assert.equal(saved.size, 1);
  fixture.pings = [ping(120, 14), ping(60), ping(0)];
  await detectFieldWaitingTime(7, 13, 80);
  assert.equal(saved.size, 1);
  fixture.pings = [ping(120), ping(61, 14), ping(60, 14), ping(0, 14)];
  await detectFieldWaitingTime(7, 14, 80);
  assert.equal(saved.size, 2);
});
test('pending reason, insufficient time, movement outside radius, and stopped tracking do not create an alert', async t => {
  reset(t);
  fixture.pending = true;
  await detectFieldWaitingTime(7, 13, 80);
  fixture.pending = false;
  fixture.pings = [ping(59), ping(0)];
  await detectFieldWaitingTime(7, 13, 80);
  fixture.pings = [ping(120, 14), ping(0)];
  await detectFieldWaitingTime(7, 13, 80);
  fixture.active = false;
  await detectFieldWaitingTime(7, 13, 80);
  assert.equal(fixture.attempts, 0);
});

test('waiting threshold and radius follow saved admin changes, without fallback defaults', async t => {
  reset(t);
  fixture.settings = {field_waiting_minutes:3, stationary_radius_meters:1000};
  fixture.pings = [ping(120),ping(0)];
  await detectFieldWaitingTime(7,13,80);
  assert.equal(saved.size,0);
  fixture.pings = [ping(180),ping(0)];
  await detectFieldWaitingTime(7,13,80);
  assert.equal(saved.size,1);
  saved.clear();
  fixture.settings = {field_waiting_minutes:1, stationary_radius_meters:10};
  fixture.pings = [ping(120,13.0005),ping(0)];
  await detectFieldWaitingTime(7,13,80);
  assert.equal(saved.size,0);
  fixture.settings.stationary_radius_meters=1000;
  await detectFieldWaitingTime(7,13,80);
  assert.equal(saved.size,1);
  fixture.settings={};
  await assert.rejects(detectFieldWaitingTime(7,13,80),/Admin must configure/);
});
