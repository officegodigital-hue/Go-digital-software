async function ensureHrmsTrackingTables(db) {
  await db.query(`
    CREATE TABLE IF NOT EXISTS hrms_tracking_settings (
      id TINYINT PRIMARY KEY,
      office_name VARCHAR(120) NOT NULL,
      office_address VARCHAR(500) NOT NULL,
      office_latitude DECIMAL(10,7) NOT NULL,
      office_longitude DECIMAL(10,7) NOT NULL,
      office_radius_meters INT NOT NULL DEFAULT 100,
      field_ping_interval_minutes INT NOT NULL DEFAULT 15,
      field_waiting_minutes INT NOT NULL DEFAULT 60,
      lunch_break_limit_minutes INT NOT NULL DEFAULT 70,
      stationary_radius_meters INT NOT NULL DEFAULT 50,
      updated_by INT NULL,
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )
  `);

  await db.query(`
    INSERT IGNORE INTO hrms_tracking_settings (
      id, office_name, office_address, office_latitude, office_longitude,
      office_radius_meters, field_ping_interval_minutes,
      field_waiting_minutes, lunch_break_limit_minutes, stationary_radius_meters
    ) VALUES (1, 'Main Office', 'Configure this address in Admin > Tracking',
      12.8542438, 80.0699862, 100, 15, 60, 70, 50)
  `);

  const [settingsColumns] = await db.query(
    `SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'hrms_tracking_settings'`
  );
  if (!settingsColumns.some((column) => column.COLUMN_NAME === 'lunch_break_limit_minutes')) {
    await db.query('ALTER TABLE hrms_tracking_settings ADD COLUMN lunch_break_limit_minutes INT NOT NULL DEFAULT 70');
  }
  if (!settingsColumns.some((column) => column.COLUMN_NAME === 'labour_lunch_break_limit_minutes')) {
    await db.query('ALTER TABLE hrms_tracking_settings ADD COLUMN labour_lunch_break_limit_minutes INT NOT NULL DEFAULT 70');
  }
  if (!settingsColumns.some((column) => column.COLUMN_NAME === 'employee_lunch_break_limit_minutes')) {
    await db.query('ALTER TABLE hrms_tracking_settings ADD COLUMN employee_lunch_break_limit_minutes INT NOT NULL DEFAULT 70');
  }
  if (!settingsColumns.some((column) => column.COLUMN_NAME === 'labour_lunch_start')) {
    await db.query("ALTER TABLE hrms_tracking_settings ADD COLUMN labour_lunch_start TIME NOT NULL DEFAULT '12:30:00'");
  }
  if (!settingsColumns.some((column) => column.COLUMN_NAME === 'labour_lunch_end')) {
    await db.query("ALTER TABLE hrms_tracking_settings ADD COLUMN labour_lunch_end TIME NOT NULL DEFAULT '13:00:00'");
  }
  if (!settingsColumns.some((column) => column.COLUMN_NAME === 'employee_lunch_start')) {
    await db.query("ALTER TABLE hrms_tracking_settings ADD COLUMN employee_lunch_start TIME NOT NULL DEFAULT '12:30:00'");
  }
  if (!settingsColumns.some((column) => column.COLUMN_NAME === 'employee_lunch_end')) {
    await db.query("ALTER TABLE hrms_tracking_settings ADD COLUMN employee_lunch_end TIME NOT NULL DEFAULT '13:00:00'");
  }
  if (!settingsColumns.some((column) => column.COLUMN_NAME === 'home_tracking_enabled')) {
    await db.query('ALTER TABLE hrms_tracking_settings ADD COLUMN home_tracking_enabled TINYINT(1) NOT NULL DEFAULT 0');
  }

  await db.query(`
    CREATE TABLE IF NOT EXISTS hrms_employee_location_status (
      employee_user_id INT PRIMARY KEY,
      status ENUM('office','home','field') NOT NULL DEFAULT 'office',
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )
  `);

  await db.query(`
    CREATE TABLE IF NOT EXISTS hrms_location_pings (
      id INT AUTO_INCREMENT PRIMARY KEY,
      employee_user_id INT NOT NULL,
      latitude DECIMAL(10,7) NOT NULL,
      longitude DECIMAL(10,7) NOT NULL,
      accuracy_meters DECIMAL(6,1) NULL,
      address VARCHAR(255) NULL,
      recorded_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      INDEX idx_employee_recorded (employee_user_id, recorded_at)
    )
  `);

  await db.query(`
    CREATE TABLE IF NOT EXISTS hrms_field_tracking_sessions (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
      employee_user_id INT NOT NULL,
      is_active TINYINT(1) NOT NULL DEFAULT 1,
      started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      stopped_at DATETIME NULL,
      start_latitude DECIMAL(10,7) NULL,
      start_longitude DECIMAL(10,7) NULL,
      stop_latitude DECIMAL(10,7) NULL,
      stop_longitude DECIMAL(10,7) NULL,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      INDEX idx_field_employee (employee_user_id, is_active)
    )
  `);

  await db.query(`
    CREATE TABLE IF NOT EXISTS hrms_field_waiting_reasons (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
      field_session_id BIGINT UNSIGNED NOT NULL,
      employee_user_id INT NOT NULL,
      latitude DECIMAL(10,7) NULL,
      longitude DECIMAL(10,7) NULL,
      waiting_started_at DATETIME NOT NULL,
      waiting_detected_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      waiting_minutes INT NOT NULL DEFAULT 0,
      event_key VARCHAR(180) NOT NULL,
      reason TEXT NULL,
      reason_submitted_at DATETIME NULL,
      review_status ENUM('pending','reviewed') NOT NULL DEFAULT 'pending',
      reviewed_by INT NULL,
      reviewed_at DATETIME NULL,
      UNIQUE KEY uq_field_waiting_event (event_key),
      INDEX idx_waiting_employee (employee_user_id, review_status),
      INDEX idx_waiting_session (field_session_id)
    )
  `);
}

module.exports = { ensureHrmsTrackingTables };
