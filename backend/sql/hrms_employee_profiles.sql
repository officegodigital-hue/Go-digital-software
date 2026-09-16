CREATE TABLE IF NOT EXISTS hrms_employee_profiles (
  id INT NOT NULL AUTO_INCREMENT,
  employee_user_id INT NULL,
  employee_code VARCHAR(50) NOT NULL,
  full_name VARCHAR(255) NOT NULL,
  email VARCHAR(255) NULL,
  department VARCHAR(100) NOT NULL DEFAULT 'Engineering',
  work_mode ENUM('Office','Home','Field') NOT NULL DEFAULT 'Office',
  employment_status ENUM('Active','On Leave','Inactive') NOT NULL DEFAULT 'Active',
  monthly_salary INT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uniq_hrms_employee_code (employee_code)
);