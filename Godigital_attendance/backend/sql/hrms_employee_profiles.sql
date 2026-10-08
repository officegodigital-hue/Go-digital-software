CREATE TABLE IF NOT EXISTS hrms_employee_profiles (
  id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  employee_user_id INT NULL UNIQUE,
  employee_code VARCHAR(64) NOT NULL UNIQUE,
  full_name VARCHAR(160) NOT NULL,
  email VARCHAR(160) NULL,
  department VARCHAR(100) NOT NULL DEFAULT 'Engineering',
  work_mode VARCHAR(32) NOT NULL DEFAULT 'Office',
  employee_type ENUM('Employee', 'Labour') NOT NULL DEFAULT 'Employee',
  employment_status VARCHAR(32) NOT NULL DEFAULT 'Active',
  field_tracking_enabled TINYINT(1) NOT NULL DEFAULT 0,
  monthly_salary DECIMAL(12,2) NULL,
  salary_type ENUM('Standard', 'Flexible') NOT NULL DEFAULT 'Standard',
  flexible_cycle_start_day TINYINT UNSIGNED NULL,
  flexible_cycle_end_day TINYINT UNSIGNED NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
