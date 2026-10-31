const { test } = require('node:test');
const assert = require('node:assert/strict');

test('tracking setup leaves policies unconfigured and migration preserves saved admin values',
  { skip: process.env.EMPLOYEE_EXIT_MYSQL_TEST !== '1', timeout: 60000 }, async () => {
    require('dotenv').config({ quiet: true });
    const mysql = require('mysql2/promise');
    const { ensureHrmsTrackingTables } = require('./ensureHrmsTrackingTables');
    const name = `codex_tracking_config_test_${Date.now()}_${process.pid}`;
    assert.match(name, /^codex_tracking_config_test_\d+_\d+$/);
    const c = await mysql.createConnection({ host: process.env.DB_HOST || 'localhost',
      port: Number(process.env.DB_PORT || 3306), user: process.env.DB_USER || 'root', password: process.env.DB_PASSWORD || '' });
    try {
      await c.query(`CREATE DATABASE \`${name}\``);
      await c.changeUser({ database: name });
      await ensureHrmsTrackingTables(c);
      let [[row]] = await c.query('SELECT * FROM hrms_tracking_settings WHERE id=1');
      for (const key of ['office_radius_meters', 'home_radius_meters', 'field_waiting_minutes',
        'stationary_radius_meters', 'field_ping_interval_minutes', 'office_no_gps_timeout_minutes', 'office_latitude']) {
        assert.equal(row[key], null, key);
      }
      await c.query('UPDATE hrms_tracking_settings SET office_radius_meters=321, home_radius_meters=456, field_waiting_minutes=1, stationary_radius_meters=1000, field_ping_interval_minutes=1 WHERE id=1');
      // Emulate an older installation's schema default without altering its saved value.
      await c.query('ALTER TABLE hrms_tracking_settings MODIFY office_radius_meters INT NOT NULL DEFAULT 100');
      await ensureHrmsTrackingTables(c);
      [[row]] = await c.query('SELECT * FROM hrms_tracking_settings WHERE id=1');
      assert.equal(row.office_radius_meters, 321);
      assert.equal(row.home_radius_meters, 456);
      assert.equal(row.field_waiting_minutes, 1);
      assert.equal(row.stationary_radius_meters, 1000);
      assert.equal(row.field_ping_interval_minutes, 1);
      const [[column]] = await c.query("SELECT COLUMN_DEFAULT,IS_NULLABLE FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='hrms_tracking_settings' AND COLUMN_NAME='office_radius_meters'");
      assert.equal(column.COLUMN_DEFAULT == null || column.COLUMN_DEFAULT === 'NULL', true);
      assert.equal(column.IS_NULLABLE, 'YES');
    } finally {
      if (/^codex_tracking_config_test_\d+_\d+$/.test(name)) await c.query(`DROP DATABASE IF EXISTS \`${name}\``);
      await c.end();
    }
  });
