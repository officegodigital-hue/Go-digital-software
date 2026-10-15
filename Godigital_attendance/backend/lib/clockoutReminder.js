'use strict';

const db = require('../config/db');
const TIME_ZONE = process.env.ATTENDANCE_TIMEZONE || 'Asia/Kolkata';

async function ensureTables() {
  await db.query(`CREATE TABLE IF NOT EXISTS hrms_clockout_reminder_policy (
    id TINYINT UNSIGNED NOT NULL PRIMARY KEY,
    enabled TINYINT(1) NOT NULL DEFAULT 1,
    threshold_minutes INT UNSIGNED NOT NULL DEFAULT 540,
    repeat_minutes INT UNSIGNED NOT NULL DEFAULT 60,
    sound_name VARCHAR(255) NULL,
    updated_by BIGINT UNSIGNED NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  )`);
  await db.query(`INSERT IGNORE INTO hrms_clockout_reminder_policy (id) VALUES (1)`);
  await db.query(`CREATE TABLE IF NOT EXISTS hrms_notification_devices (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    employee_user_id BIGINT UNSIGNED NOT NULL,
    platform ENUM('web','android') NOT NULL,
    token TEXT NOT NULL,
    token_hash CHAR(64) NOT NULL,
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    permission_status VARCHAR(32) NOT NULL DEFAULT 'granted',
    last_seen_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_notification_device (employee_user_id, token_hash),
    KEY idx_notification_employee (employee_user_id, is_active)
  )`);
  await db.query(`CREATE TABLE IF NOT EXISTS hrms_clockout_reminder_events (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    attendance_id BIGINT UNSIGNED NOT NULL,
    employee_user_id BIGINT UNSIGNED NOT NULL,
    reminder_slot INT UNSIGNED NOT NULL,
    status ENUM('pending','sent','failed','stale') NOT NULL DEFAULT 'pending',
    delivery_channel VARCHAR(32) NULL,
    retry_count INT UNSIGNED NOT NULL DEFAULT 0,
    last_error VARCHAR(500) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    sent_at TIMESTAMP NULL,
    UNIQUE KEY uq_clockout_reminder_slot (attendance_id, reminder_slot)
  )`);
  await db.query(`CREATE TABLE IF NOT EXISTS hrms_clockout_reminder_audit (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    employee_user_id BIGINT UNSIGNED NOT NULL,
    attendance_id BIGINT UNSIGNED NULL,
    event_id BIGINT UNSIGNED NULL,
    channel VARCHAR(32) NOT NULL,
    result VARCHAR(32) NOT NULL,
    error_message VARCHAR(500) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
  )`);
}

async function policy() {
  await ensureTables();
  const [[row]] = await db.query('SELECT * FROM hrms_clockout_reminder_policy WHERE id = 1');
  return { enabled: Boolean(Number(row.enabled)), thresholdMinutes: Number(row.threshold_minutes), repeatMinutes: Number(row.repeat_minutes), soundName: row.sound_name || null };
}

async function updatePolicy(body, adminId) {
  const enabled = body.enabled === false || body.enabled === 0 ? 0 : 1;
  const thresholdMinutes = Number(body.thresholdMinutes ?? body.threshold_minutes ?? 540);
  const repeatMinutes = Number(body.repeatMinutes ?? body.repeat_minutes ?? 60);
  if (!Number.isInteger(thresholdMinutes) || thresholdMinutes < 1 || !Number.isInteger(repeatMinutes) || repeatMinutes < 1) throw new Error('Threshold and repeat intervals must be positive whole minutes');
  await ensureTables();
  await db.query('UPDATE hrms_clockout_reminder_policy SET enabled = ?, threshold_minutes = ?, repeat_minutes = ?, sound_name = ?, updated_by = ? WHERE id = 1', [enabled, thresholdMinutes, repeatMinutes, body.soundName || null, adminId || null]);
  return policy();
}

async function registerDevice(employeeId, body) {
  await ensureTables();
  const crypto = require('crypto');
  const platform = String(body.platform || '').toLowerCase();
  const token = String(body.token || body.subscription || '').trim();
  if (!['android', 'web'].includes(platform) || !token) throw new Error('A valid platform and notification token are required');
  const tokenHash = crypto.createHash('sha256').update(token).digest('hex');
  await db.query(`INSERT INTO hrms_notification_devices (employee_user_id, platform, token, token_hash, permission_status, last_seen_at)
    VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
    ON DUPLICATE KEY UPDATE token = VALUES(token), is_active = 1, permission_status = VALUES(permission_status), last_seen_at = CURRENT_TIMESTAMP`, [employeeId, platform, token, tokenHash, body.permissionStatus || 'granted']);
  return { registered: true, platform, tokenHash };
}

async function unregisterDevice(employeeId, id) { await ensureTables(); await db.query('UPDATE hrms_notification_devices SET is_active = 0 WHERE id = ? AND employee_user_id = ?', [Number(id), employeeId]); return { removed: true }; }

async function status(employeeId) {
  await ensureTables();
  const p = await policy();
  const [[row]] = await db.query(`SELECT id, check_in_at, TIMESTAMPDIFF(MINUTE, check_in_at, CURRENT_TIMESTAMP) AS worked_minutes FROM attendance_records WHERE employee_id = ? AND check_out_at IS NULL ORDER BY check_in_at DESC LIMIT 1`, [employeeId]);
  if (!row) return { active: false, policy: p };
  const worked = Number(row.worked_minutes || 0);
  return { active: true, attendanceId: row.id, checkInAt: row.check_in_at, workedMinutes: worked, thresholdReached: p.enabled && worked >= p.thresholdMinutes, reminderSlot: worked >= p.thresholdMinutes ? Math.floor((worked - p.thresholdMinutes) / p.repeatMinutes) : null, nextReminderMinutes: worked < p.thresholdMinutes ? p.thresholdMinutes - worked : p.repeatMinutes - ((worked - p.thresholdMinutes) % p.repeatMinutes), policy: p };
}

async function scan() {
  const p = await policy();
  if (!p.enabled) return;
  const [rows] = await db.query(`SELECT id, employee_id, check_in_at, TIMESTAMPDIFF(MINUTE, check_in_at, CURRENT_TIMESTAMP) AS worked_minutes FROM attendance_records WHERE check_out_at IS NULL AND check_in_at IS NOT NULL AND TIMESTAMPDIFF(MINUTE, check_in_at, CURRENT_TIMESTAMP) >= ?`, [p.thresholdMinutes]);
  for (const row of rows) {
    const slot = Math.floor((Number(row.worked_minutes) - p.thresholdMinutes) / p.repeatMinutes);
    const [result] = await db.query(`INSERT IGNORE INTO hrms_clockout_reminder_events (attendance_id, employee_user_id, reminder_slot) VALUES (?, ?, ?)`, [row.id, row.employee_id, slot]);
    if (result.affectedRows) await db.query(`INSERT INTO hrms_clockout_reminder_audit (employee_user_id, attendance_id, event_id, channel, result) VALUES (?, ?, ?, 'scheduler', 'queued')`, [row.employee_id, row.id, result.insertId]);
  }
}

module.exports = { ensureTables, policy, updatePolicy, registerDevice, unregisterDevice, status, scan };
