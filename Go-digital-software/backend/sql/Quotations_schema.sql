-- ── Quotations + Quotation Items tables ─────────────────────────────────────
USE godigital_db;

CREATE TABLE IF NOT EXISTS quotations (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  quotation_no    VARCHAR(50)   NOT NULL UNIQUE,
  client_name     VARCHAR(150)  NOT NULL,
  quotation_date  VARCHAR(20)   NOT NULL,
  expiry_date     VARCHAR(20)   NOT NULL,
  include_gst     TINYINT(1)    NOT NULL DEFAULT 0,
  subtotal        DECIMAL(12,2) NOT NULL DEFAULT 0,
  tax             DECIMAL(12,2) NOT NULL DEFAULT 0,
  total_amount    DECIMAL(12,2) NOT NULL DEFAULT 0,
  paid_amount     DECIMAL(12,2) NOT NULL DEFAULT 0,
  balance_amount  DECIMAL(12,2) NOT NULL DEFAULT 0,
  status          VARCHAR(20)   NOT NULL DEFAULT 'DRAFT',
  created_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS quotation_items (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  quotation_id    INT NOT NULL,
  package_id      INT NULL,
  description     VARCHAR(255)  NOT NULL,
  qty             INT           NOT NULL DEFAULT 1,
  rate            DECIMAL(12,2) NOT NULL DEFAULT 0,
  amount          DECIMAL(12,2) NOT NULL DEFAULT 0,
  paid_amount     DECIMAL(12,2) NOT NULL DEFAULT 0,
  pending_amount  DECIMAL(12,2) NOT NULL DEFAULT 0,
  sort_order      INT           NOT NULL DEFAULT 0,
  FOREIGN KEY (quotation_id) REFERENCES quotations(id) ON DELETE CASCADE,
  FOREIGN KEY (package_id)   REFERENCES packages(id)   ON DELETE SET NULL
);

SELECT * FROM quotations;