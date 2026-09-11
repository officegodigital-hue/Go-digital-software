-- ── Client Onboarding — tables ───────────────────────────────────────────────
USE godigital_db;

-- Main client/company record
CREATE TABLE IF NOT EXISTS clients (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  company_name    VARCHAR(255) NOT NULL,
  industry        VARCHAR(100) NOT NULL DEFAULT 'Financial Services',
  contact_person  VARCHAR(150) DEFAULT '',
  email           VARCHAR(255) DEFAULT '',
  address         TEXT,
  status          ENUM('draft','complete') NOT NULL DEFAULT 'draft',
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Client login credentials (Facebook, Instagram, Server, etc.)
CREATE TABLE IF NOT EXISTS client_credentials (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  client_id       INT NULL,                 -- optional link to clients table
  username        VARCHAR(255) NOT NULL,
  password        VARCHAR(255) NOT NULL,    -- store as-is or encrypt as needed
  platform        VARCHAR(100) NOT NULL,
  contact_number  VARCHAR(30)  DEFAULT '',
  email           VARCHAR(255) DEFAULT '',
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE
);

-- Seed sample credential rows (matches your hard-coded list)
INSERT INTO client_credentials (username, password, platform, contact_number, email) VALUES
  ('client.fb.account', 'encrypted_pw', 'Facebook Login',          '+91 98765 43210', 'handler@example.com'),
  ('client.ig.account', 'encrypted_pw', 'Instagram Login',         '+91 98765 43210', 'handler@example.com'),
  ('client.linkedin',   'encrypted_pw', 'LinkedIn Login',          '+91 98765 43210', 'handler@example.com'),
  ('client.youtube',    'encrypted_pw', 'YouTube Login',           '+91 98765 43210', 'handler@example.com'),
  ('client.gbp',        'encrypted_pw', 'Google Business Profile', '+91 98765 43210', 'handler@example.com'),
  ('server.client.com', 'encrypted_pw', 'Server Login',            '+91 98765 43210', 'handler@example.com');


-- ── Add bank details columns to clients table ─────────────────────────────────
USE godigital_db;

ALTER TABLE clients
  ADD COLUMN bank_account_name   VARCHAR(255) DEFAULT '' AFTER address,
  ADD COLUMN bank_name           VARCHAR(255) DEFAULT '' AFTER bank_account_name,
  ADD COLUMN bank_account_number VARCHAR(100) DEFAULT '' AFTER bank_name,
  ADD COLUMN bank_ifsc           VARCHAR(50)  DEFAULT '' AFTER bank_account_number;

DESCRIBE clients;



-- ── Enforce one credential per (client_id, platform) ──────────────────────────
USE godigital_db;

-- Remove any existing duplicates first (keeps the most recently updated row)
DELETE c1 FROM client_credentials c1
INNER JOIN client_credentials c2
  ON c1.client_id = c2.client_id
 AND c1.platform   = c2.platform
 AND c1.id < c2.id;

-- Add unique constraint: same client cannot have two rows with the same platform
ALTER TABLE client_credentials
  ADD UNIQUE KEY uniq_client_platform (client_id, platform);

DESCRIBE client_credentials;