-- ── Time Manager — task_timings table ────────────────────────────────────────
USE godigital_db;

CREATE TABLE IF NOT EXISTS task_timings (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  task_name   VARCHAR(150) NOT NULL,
  qty         VARCHAR(20)  NOT NULL,
  timing      VARCHAR(50)  NOT NULL,   -- e.g. "30 mins", "3 hrs", "1 days"
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Seed data (matches the Flutter hard-coded list)
INSERT INTO task_timings (task_name, qty, timing) VALUES
  ('Poster',     '1', '30 mins'),
  ('Video',      '1', '3 hrs'),
  ('Meta Ads',   '2', '1 days'),
  ('Google Ads', '1', '1 days');


  -- ── Enforce unique task_name in task_timings ──────────────────────────────────
USE godigital_db;

SET SQL_SAFE_UPDATES = 0;

-- Remove duplicates first (keep the lowest id for each task_name)
DELETE t1 FROM task_timings t1
INNER JOIN task_timings t2
  ON t1.task_name = t2.task_name
 AND t1.id > t2.id;

SET SQL_SAFE_UPDATES = 1;

-- Add unique constraint
ALTER TABLE task_timings
  ADD UNIQUE KEY uniq_task_name (task_name);

DESCRIBE task_timings;