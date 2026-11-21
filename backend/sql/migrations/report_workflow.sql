-- Report workflow tables used by /api/report-export.
-- Safe to run on existing databases; existing tables are left unchanged.
USE godigital_db;

CREATE TABLE IF NOT EXISTS client_profiles (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  company_name VARCHAR(255) NOT NULL,
  logo_data MEDIUMBLOB NULL,
  logo_mime_type VARCHAR(150) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_client_profiles_company (company_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS report_templates (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  scope VARCHAR(100) NOT NULL,
  file_name VARCHAR(500) NOT NULL,
  template_data LONGBLOB NOT NULL,
  uploaded_by_user_id BIGINT UNSIGNED NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_report_templates_scope (scope)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS client_full_report_history (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  company_name VARCHAR(255) NOT NULL,
  report_month TINYINT UNSIGNED NOT NULL,
  report_year SMALLINT UNSIGNED NOT NULL,
  file_format VARCHAR(10) NOT NULL,
  file_name VARCHAR(500) NOT NULL,
  content_type VARCHAR(150) NOT NULL,
  file_data LONGBLOB NOT NULL,
  downloaded_by_user_id BIGINT UNSIGNED NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_client_report_history_company_period
    (company_name, report_year, report_month, created_at),
  KEY idx_client_report_history_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS report_submissions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  company_name VARCHAR(255) NOT NULL,
  report_month TINYINT UNSIGNED NOT NULL,
  report_year SMALLINT UNSIGNED NOT NULL,
  payload LONGBLOB NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'pending',
  submitted_by_user_id BIGINT UNSIGNED NULL,
  submitted_by_name VARCHAR(255) NOT NULL,
  reviewed_by_user_id BIGINT UNSIGNED NULL,
  reviewed_by_name VARCHAR(255) NULL,
  review_note VARCHAR(2000) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  reviewed_at DATETIME NULL,
  PRIMARY KEY (id),
  KEY idx_report_submissions_status_created (status, created_at),
  KEY idx_report_submissions_company_period
    (company_name, report_year, report_month, created_at),
  KEY idx_report_submissions_submitter (submitted_by_user_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS report_workflow_drafts (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  client_id INT UNSIGNED NOT NULL,
  client_name VARCHAR(255) NOT NULL,
  template_id INT UNSIGNED NOT NULL,
  employee_id INT UNSIGNED NOT NULL,
  report_name VARCHAR(255) NOT NULL,
  reporting_month DATE NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'draft',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_report_workflow_drafts_employee (employee_id, updated_at),
  KEY idx_report_workflow_drafts_client_month
    (client_id, reporting_month, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS report_workflow_screenshots (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  draft_id INT UNSIGNED NOT NULL,
  original_filename VARCHAR(500) NOT NULL,
  mime_type VARCHAR(100) NOT NULL,
  image_data MEDIUMBLOB NOT NULL,
  provider_name VARCHAR(100) NULL,
  provider_confidence DECIMAL(5,4) NULL,
  template_page_id INT NULL,
  ocr_status VARCHAR(20) NOT NULL DEFAULT 'pending',
  ocr_error VARCHAR(1000) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_report_workflow_screenshots_draft (draft_id, created_at),
  CONSTRAINT fk_report_workflow_screenshots_draft
    FOREIGN KEY (draft_id) REFERENCES report_workflow_drafts(id)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS report_workflow_fields (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  draft_id INT UNSIGNED NOT NULL,
  screenshot_id INT UNSIGNED NULL,
  template_page_id INT NULL,
  provider_name VARCHAR(100) NULL,
  source_label VARCHAR(255) NOT NULL,
  extracted_value TEXT NULL,
  override_label VARCHAR(255) NULL,
  override_value TEXT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_report_workflow_fields_draft (draft_id, template_page_id),
  KEY idx_report_workflow_fields_screenshot (screenshot_id),
  CONSTRAINT fk_report_workflow_fields_draft
    FOREIGN KEY (draft_id) REFERENCES report_workflow_drafts(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_report_workflow_fields_screenshot
    FOREIGN KEY (screenshot_id) REFERENCES report_workflow_screenshots(id)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
