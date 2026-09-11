-- ── GoDigital Admin Panel — MySQL Schema ─────────────────────────────────────
-- Run this in MySQL Workbench to create the database and tables

CREATE DATABASE IF NOT EXISTS godigital_db;
USE godigital_db;

-- ── Employee Users table ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS employee_users (
  id           INT AUTO_INCREMENT PRIMARY KEY,
  first_name   VARCHAR(100) NOT NULL,
  middle_name  VARCHAR(100) DEFAULT '',
  last_name    VARCHAR(100) NOT NULL,
  full_name    VARCHAR(255) NOT NULL,
  initials     VARCHAR(5)   NOT NULL,
  staff_id     VARCHAR(50)  NOT NULL UNIQUE,
  email        VARCHAR(255) NOT NULL UNIQUE,
  username     VARCHAR(100) NOT NULL UNIQUE,
  password     VARCHAR(255) NOT NULL,          -- store hashed (bcrypt)
  role         ENUM(
                 'UI/ UX Designer',
                 'Graphic Designer',
                 'Digital Marketing',
                 'Video Editor',
                 'Web Developer'
               ) NOT NULL DEFAULT 'Graphic Designer',
  is_active    TINYINT(1)   NOT NULL DEFAULT 1,
  created_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- ── Seed data (matches the Flutter hard-coded list) ───────────────────────────
INSERT INTO employee_users
  (first_name, middle_name, last_name, full_name, initials, staff_id, email, username, password, role, is_active)
VALUES
  ('Pavithra', 'C', '',      'Pavithra C', 'PC', '173549695', 'pavithra@godigital.in',  'pavithra', '$2b$10$placeholder_hash_1', 'Graphic Designer',    1),
  ('Susan',    '',  '',      'Susan',      'SS', '173540695', 'susan@godigital.in',     'susan',    '$2b$10$placeholder_hash_2', 'Digital Marketing',   0),
  ('Arun',     '',  '',      'Arun',       'AD', '173540696', 'arun@godigital.in',      'arun',     '$2b$10$placeholder_hash_3', 'Video Editor',        1),
  ('Ravi',     '',  '',      'Ravi',       'RK', '173540697', 'ravi@godigital.in',      'ravi',     '$2b$10$placeholder_hash_4', 'Graphic Designer',    1);