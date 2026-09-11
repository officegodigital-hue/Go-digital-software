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
      stationary_radius_meters INT NOT NULL DEFAULT 50,
      updated_by INT NULL,
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )
  `);

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
}

module.exports = { ensureHrmsTrackingTables };
