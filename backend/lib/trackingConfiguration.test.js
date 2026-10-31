const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const { configuredNumber } = require('./configuredSetting');
const { settingsFor } = require('./attendanceLocationPolicy');

test('configured values accept zero only where allowed and never invent policy values', () => {
  assert.equal(configuredNumber('17', 'timeout'), 17);
  assert.equal(configuredNumber(0, 'break', true), 0);
  for (const value of [null, undefined, '', ' ', NaN, Infinity, 0, -1, 1.2]) {
    assert.throws(() => configuredNumber(value, 'timeout'), /Admin must configure/);
  }
});

test('location policy uses the saved Office and Home settings and rejects missing configuration', async () => {
  const row = { office_radius_meters: 321, home_radius_meters: 456,
    office_outside_radius_grace_minutes: 7, home_outside_radius_grace_minutes: 11,
    office_no_gps_timeout_minutes: 13, home_no_gps_timeout_minutes: 17 };
  const db = { query: async () => [[row]] };
  const result = await settingsFor(db);
  assert.equal(result.radiusMeters, 321);
  assert.equal(result.homeRadiusMeters, 456);
  assert.equal(result.officeOutsideRadiusGraceMinutes, 7);
  assert.equal(result.homeOutsideRadiusGraceMinutes, 11);
  assert.equal(result.officeNoGpsTimeoutMinutes, 13);
  assert.equal(result.homeNoGpsTimeoutMinutes, 17);
  row.home_radius_meters = null;
  await assert.rejects(settingsFor(db), /Admin must configure Home radius/);
  assert.equal((await settingsFor(db, false, 'Office')).radiusMeters, 321);
  row.home_radius_meters = 456;
  row.office_radius_meters = null;
  assert.equal((await settingsFor(db, false, 'Home')).homeRadiusMeters, 456);
});

test('break protection and Home checkout follow admin break duration, grace and Home radius', async () => {
  const source = fs.readFileSync(require.resolve('../controllers/hrmsTrackingController'), 'utf8');
  const ping = source.slice(source.indexOf('async function ping('), source.indexOf('async function liveOverview('));
  let breakMinutes = 22;
  const calls = [];
  const query = async (sql, params) => {
    calls.push({ sql, params });
    if (sql.includes('INSERT INTO hrms_location_pings')) return [{ insertId: 1 }];
    if (sql.includes('SELECT work_mode')) return [[{ work_mode: 'Home' }]];
    if (sql.includes('FROM attendance_breaks')) return [[{ id: 1, break_minutes: breakMinutes }]];
    if (sql.includes('FROM hrms_attendance_time_settings')) return [[{ break_minutes: 20, break_grace_minutes: 3 }]];
    if (sql.includes('SELECT id, check_in_at')) return [[{ id: 8, outside_radius_since: '2026-10-30 09:00:00' }]];
    return [[]];
  };
  const scope = { db: { query }, configuredNumber, console,
    policy: { todayIstDate: () => '2026-10-30' },
    locationPolicy: { getCheckInPolicy: async () => ({ center: {} }),
      settingsFor: async () => ({ radiusMeters: 500, homeRadiusMeters: 100,
        homeOutsideRadiusGraceMinutes: 11, officeOutsideRadiusGraceMinutes: 7 }),
      distanceMeters: () => 200 },
    detectFieldWaitingTime: async () => {}, reverseGeocode: async () => null,
    ok: () => {}, fail: (_, status, message) => assert.fail(`${status}: ${message}`), module: { exports: {} } };
  vm.runInNewContext(ping + '; module.exports = ping;', scope);
  const req = { user: { id: 7 }, body: { latitude: 13, longitude: 80 } };
  await scope.module.exports(req, {});
  assert.ok(calls.some(c => c.sql.includes('SET outside_radius_since = NULL')));
  calls.length = 0;
  breakMinutes = 24;
  await scope.module.exports(req, {});
  // Above the configured 20+3 minute break protection, not a fixed 70 minutes.
  const expiry = calls.find(c => c.sql.includes('CURRENT_TIMESTAMP - INTERVAL'));
  assert.deepEqual(Array.from(expiry.params), [8, 11]);
});
