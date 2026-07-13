USE godigital_db;

CREATE TABLE IF NOT EXISTS task_assignments (
  id                  INT AUTO_INCREMENT PRIMARY KEY,
  client_name         VARCHAR(150) NOT NULL,
  deliverables        TEXT         DEFAULT '',
  ads_handling        VARCHAR(100) DEFAULT '',
  ads_platform        VARCHAR(100) DEFAULT '',
  page_handling       VARCHAR(100) DEFAULT '',
  pages_platform      VARCHAR(100) DEFAULT '',
  designer            VARCHAR(100) DEFAULT '',
  designer_tasks      VARCHAR(100) DEFAULT '',
  videographer        VARCHAR(100) DEFAULT '',
  videographer_tasks  VARCHAR(100) DEFAULT '',
  ui_ux_designer      VARCHAR(100) DEFAULT '',
  ui_ux_tasks         VARCHAR(100) DEFAULT '',
  deadline            VARCHAR(50)  DEFAULT '',
  comments            TEXT         DEFAULT '',
  is_assigned         TINYINT(1)   NOT NULL DEFAULT 0,
  created_at          DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at          DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);