async function ensureHrmsTrackingTables(db) {
  // One-time compatibility migration. Existing Field tracking records become
  // Hybrid; Home remains unchanged because Home features are retained.
  try {
    await db.query("ALTER TABLE hrms_employee_profiles MODIFY work_mode ENUM('Office','Home','Field','Hybrid') NOT NULL DEFAULT 'Office'");
    await db.query("UPDATE hrms_employee_profiles SET work_mode = 'Hybrid' WHERE work_mode = 'Field'");
    await db.query("ALTER TABLE hrms_employee_profiles MODIFY work_mode ENUM('Office','Home','Hybrid') NOT NULL DEFAULT 'Office'");
  } catch (error) {
    console.error('Hybrid work-mode migration skipped:', error.message);
  }
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
      stationary_radius_meters INT NOT NULL DEFAULT 50,
      updated_by INT NULL,
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )
  `);
  try {
    await db.query("ALTER TABLE hrms_employee_location_status MODIFY status ENUM('office','home','field','hybrid') NOT NULL DEFAULT 'office'");
    await db.query("UPDATE hrms_employee_location_status SET status = 'hybrid' WHERE status = 'field'");
    await db.query("ALTER TABLE hrms_employee_location_status MODIFY status ENUM('office','home','hybrid') NOT NULL DEFAULT 'office'");
  } catch (error) {
    console.error('Hybrid location-status migration skipped:', error.message);
  }

  // Kept as an additive migration so installations with the existing table
  // retain every setting and employee record.
  try {
    await db.query(`ALTER TABLE hrms_tracking_settings
      ADD COLUMN home_tracking_enabled TINYINT(1) NOT NULL DEFAULT 1`);
  } catch (error) {
    if (error && error.code !== 'ER_DUP_FIELDNAME') throw error;
  }
  try { await db.query('ALTER TABLE hrms_tracking_settings ADD COLUMN outside_radius_grace_minutes SMALLINT UNSIGNED NOT NULL DEFAULT 5'); } catch (error) { if (error && error.code !== 'ER_DUP_FIELDNAME') throw error; }

  await db.query(`CREATE TABLE IF NOT EXISTS hrms_attendance_radius_departures (
    attendance_id BIGINT UNSIGNED PRIMARY KEY, employee_id BIGINT UNSIGNED NOT NULL,
    location_type VARCHAR(16) NOT NULL, left_at DATETIME NOT NULL, last_seen_at DATETIME NOT NULL,
    latitude DECIMAL(10,7) NOT NULL, longitude DECIMAL(10,7) NOT NULL, distance_meters DECIMAL(10,2) NOT NULL,
    status ENUM('pending','cancelled','auto_checked_out') NOT NULL DEFAULT 'pending',
    INDEX idx_radius_departure_employee (employee_id, status)
  )`);

  await db.query(`
    INSERT IGNORE INTO hrms_tracking_settings (
      id, office_name, office_address, office_latitude, office_longitude,
      office_radius_meters, field_ping_interval_minutes,
      field_waiting_minutes, stationary_radius_meters
    ) VALUES (1, 'Main Office', 'Configure this address in Admin > Tracking',
      12.8542438, 80.0699862, 100, 15, 60, 50)
  `);

  await db.query(`
    CREATE TABLE IF NOT EXISTS hrms_employee_location_status (
      employee_user_id INT PRIMARY KEY,
      status ENUM('office','home','hybrid') NOT NULL DEFAULT 'office',
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
    CREATE TABLE IF NOT EXISTS hrms_tracking_route_cache (
      id BIGINT AUTO_INCREMENT PRIMARY KEY,
      employee_user_id INT NOT NULL,
      route_date DATE NOT NULL,
      source ENUM('routes','roads','raw') NOT NULL DEFAULT 'raw',
      route_points_json LONGTEXT NOT NULL,
      distance_meters DECIMAL(12,2) NOT NULL DEFAULT 0,
      duration_seconds INT NOT NULL DEFAULT 0,
      average_speed_kmh DECIMAL(8,2) NOT NULL DEFAULT 0,
      last_ping_at DATETIME NULL,
      generated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      UNIQUE KEY uq_tracking_route_day (employee_user_id, route_date),
      INDEX idx_tracking_route_generated (generated_at)
    )
  `);
}

module.exports = { ensureHrmsTrackingTables };
