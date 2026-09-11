-- ── Recreate clients and client_credentials tables ───────────────────────────
USE godigital_db;

-- Drop old tables if they exist (in correct order due to FK)
DROP TABLE IF EXISTS client_credentials;
DROP TABLE IF EXISTS clients;

-- ── Main client/company record ────────────────────────────────────────────────
CREATE TABLE clients (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  company_name    VARCHAR(255) NOT NULL,
  industry        VARCHAR(100) NOT NULL DEFAULT 'Financial Services',
  contact_person  VARCHAR(150) DEFAULT '',
  email           VARCHAR(255) DEFAULT '',
  address         TEXT,
  status          ENUM('draft','pending','verified','complete') NOT NULL DEFAULT 'draft',
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- ── Client login credentials (Facebook, Instagram, Server, etc.) ──────────────
CREATE TABLE client_credentials (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  client_id       INT NULL,
  username        VARCHAR(255) NOT NULL,
  password        VARCHAR(255) NOT NULL,
  platform        VARCHAR(100) NOT NULL,
  contact_number  VARCHAR(30)  DEFAULT '',
  email           VARCHAR(255) DEFAULT '',
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE
);

-- ── Verify ─────────────────────────────────────────────────────────────────────
SHOW TABLES;
DESCRIBE clients;
DESCRIBE client_credentials;