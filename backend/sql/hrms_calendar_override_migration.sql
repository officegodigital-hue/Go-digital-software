-- Fully dynamic, scoped calendar overrides. Existing rows remain All Employees.
ALTER TABLE hrms_calendar_overrides DROP INDEX unique_work_date;
ALTER TABLE hrms_calendar_overrides
  ADD COLUMN scope_type ENUM('all','department','employees') NOT NULL DEFAULT 'all' AFTER status,
  ADD COLUMN department VARCHAR(255) NULL AFTER scope_type;
UPDATE hrms_calendar_overrides SET scope_type = 'all' WHERE scope_type IS NULL;

CREATE TABLE IF NOT EXISTS hrms_calendar_override_targets (
  override_id INT UNSIGNED NOT NULL,
  employee_id BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (override_id, employee_id),
  KEY employee_date (employee_id)
);

CREATE TABLE IF NOT EXISTS hrms_employee_calendar_notifications (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  employee_id BIGINT UNSIGNED NOT NULL,
  override_id INT UNSIGNED NOT NULL,
  title VARCHAR(160) NOT NULL,
  message VARCHAR(500) NOT NULL,
  is_read TINYINT(1) NOT NULL DEFAULT 0,
  read_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY employee_override (employee_id, override_id),
  KEY employee_unread (employee_id, is_read, created_at)
);
