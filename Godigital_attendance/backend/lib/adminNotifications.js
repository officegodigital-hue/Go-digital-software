'use strict';

const db = require('../config/db');

const TYPES = {
  APPROVAL: 'approval_request',
  TRACKING_COMMENT: 'tracking_comment',
  FIELD_WAITING_REASON: 'field_waiting_reason',
};

async function ensureAdminNotificationTables() {
  await db.query(`
    CREATE TABLE IF NOT EXISTS hrms_admin_notifications (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      approval_request_id BIGINT UNSIGNED NULL,
      notification_type VARCHAR(48) NOT NULL DEFAULT 'approval_request',
      source_id BIGINT UNSIGNED NULL,
      employee_user_id INT NULL,
      title VARCHAR(160) NOT NULL,
      message VARCHAR(500) NOT NULL,
      is_read TINYINT(1) NOT NULL DEFAULT 0,
      read_at DATETIME NULL,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      UNIQUE KEY uniq_approval_notification (approval_request_id),
      UNIQUE KEY uniq_admin_notification_source (notification_type, source_id)
    )
  `);

  const [columns] = await db.query(`
    SELECT COLUMN_NAME, IS_NULLABLE FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'hrms_admin_notifications'
  `);
  const has = (name) => columns.some((column) => column.COLUMN_NAME === name);
  const approvalColumn = columns.find((column) => column.COLUMN_NAME === 'approval_request_id');
  if (approvalColumn && approvalColumn.IS_NULLABLE !== 'YES') {
    await db.query('ALTER TABLE hrms_admin_notifications MODIFY approval_request_id BIGINT UNSIGNED NULL');
  }
  if (!has('notification_type')) {
    await db.query("ALTER TABLE hrms_admin_notifications ADD COLUMN notification_type VARCHAR(48) NOT NULL DEFAULT 'approval_request' AFTER approval_request_id");
  }
  if (!has('source_id')) {
    await db.query('ALTER TABLE hrms_admin_notifications ADD COLUMN source_id BIGINT UNSIGNED NULL AFTER notification_type');
  }
  if (!has('employee_user_id')) {
    await db.query('ALTER TABLE hrms_admin_notifications ADD COLUMN employee_user_id INT NULL AFTER source_id');
  }
  await db.query(`
    UPDATE hrms_admin_notifications
    SET notification_type = 'approval_request', source_id = approval_request_id
    WHERE notification_type = 'approval_request' AND source_id IS NULL
  `);
  const [indexes] = await db.query(`
    SELECT INDEX_NAME FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'hrms_admin_notifications'
  `);
  if (!indexes.some((index) => index.INDEX_NAME === 'uniq_admin_notification_source')) {
    await db.query('ALTER TABLE hrms_admin_notifications ADD UNIQUE KEY uniq_admin_notification_source (notification_type, source_id)');
  }

  await db.query(`
    CREATE TABLE IF NOT EXISTS hrms_admin_notification_settings (
      id TINYINT NOT NULL PRIMARY KEY,
      sound_enabled TINYINT(1) NOT NULL DEFAULT 1,
      sound_name VARCHAR(80) NOT NULL DEFAULT 'notification.mp3',
      sound_volume TINYINT UNSIGNED NOT NULL DEFAULT 70,
      comment_notifications_enabled TINYINT(1) NOT NULL DEFAULT 1,
      waiting_reason_notifications_enabled TINYINT(1) NOT NULL DEFAULT 1,
      updated_by INT NULL,
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )
  `);
  await db.query('INSERT IGNORE INTO hrms_admin_notification_settings (id) VALUES (1)');
}

async function getSettings() {
  await ensureAdminNotificationTables();
  const [rows] = await db.query('SELECT * FROM hrms_admin_notification_settings WHERE id = 1');
  const row = rows[0] || {};
  return {
    soundEnabled: Boolean(row.sound_enabled),
    soundName: row.sound_name || 'notification.mp3',
    soundVolume: Number(row.sound_volume || 70),
    commentNotificationsEnabled: Boolean(row.comment_notifications_enabled),
    waitingReasonNotificationsEnabled: Boolean(row.waiting_reason_notifications_enabled),
  };
}

async function updateSettings(input, adminUserId) {
  await ensureAdminNotificationTables();
  const soundNames = ['notification.mp3', 'notifications.mp3', 'notificationss.mp3', 'notification_ai voice.mp3'];
  const soundName = soundNames.includes(String(input.soundName || ''))
    ? String(input.soundName) : 'notification.mp3';
  const volume = Math.min(100, Math.max(0, Number(input.soundVolume)));
  await db.query(`
    UPDATE hrms_admin_notification_settings
    SET sound_enabled = ?, sound_name = ?, sound_volume = ?,
        comment_notifications_enabled = ?, waiting_reason_notifications_enabled = ?, updated_by = ?
    WHERE id = 1
  `, [
    input.soundEnabled ? 1 : 0,
    soundName,
    Number.isFinite(volume) ? Math.round(volume) : 70,
    input.commentNotificationsEnabled ? 1 : 0,
    input.waitingReasonNotificationsEnabled ? 1 : 0,
    adminUserId || null,
  ]);
  return getSettings();
}

async function createAdminNotification({ type, sourceId, employeeUserId, title, message }) {
  await ensureAdminNotificationTables();
  const settings = await getSettings();
  if ((type === TYPES.TRACKING_COMMENT && !settings.commentNotificationsEnabled) ||
      (type === TYPES.FIELD_WAITING_REASON && !settings.waitingReasonNotificationsEnabled)) {
    return false;
  }
  await db.query(`
    INSERT IGNORE INTO hrms_admin_notifications
      (approval_request_id, notification_type, source_id, employee_user_id, title, message)
    VALUES (NULL, ?, ?, ?, ?, ?)
  `, [type, sourceId, employeeUserId, title, message]);
  return true;
}

module.exports = { TYPES, ensureAdminNotificationTables, getSettings, updateSettings, createAdminNotification };
