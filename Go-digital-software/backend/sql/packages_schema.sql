-- ── Service Packages table ──────────────────────────────────────────────────
USE godigital_db;

CREATE TABLE IF NOT EXISTS packages (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  title       VARCHAR(150)  NOT NULL,
  subtitle    VARCHAR(255)  DEFAULT '',
  price       VARCHAR(50)   NOT NULL,
  period      VARCHAR(20)   NOT NULL DEFAULT '/Month',
  is_google   TINYINT(1)    NOT NULL DEFAULT 0,
  is_popular  TINYINT(1)    NOT NULL DEFAULT 0,
  features    JSON          NOT NULL,   -- array of strings, e.g. ["Feature 1", "Feature 2"]
  sort_order  INT           NOT NULL DEFAULT 0,
  created_at  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Seed with the 3 default packages (matches the current hard-coded cards)
INSERT INTO packages (title, subtitle, price, period, is_google, is_popular, features, sort_order) VALUES
(
  'Kickstart Package',
  'SMART LAUNCH FOR GROWING BRANDS',
  '₹8,000',
  '/Month',
  0,
  0,
  JSON_ARRAY(
    'Platforms: Facebook | Instagram | LinkedIn',
    '6 Creative Posters',
    '1 Reels Video / Video Shoot',
    'Basic Ads Campaign Setup',
    'AI Monitoring - Smart Layer'
  ),
  1
),
(
  'Smart Package',
  'AI OPTIMIZED SOCIAL + CAMPAIGN GROWTH',
  '₹12,000',
  '/setup',
  0,
  1,
  JSON_ARRAY(
    'Platforms: Facebook | Instagram | LinkedIn',
    '12 Premium Posters',
    '2 Reel Video/ Video Shoot',
    'Social Media Maintenance',
    'Ad Campaign Management',
    '100% AI Monitoring System'
  ),
  2
),
(
  'Performance Package',
  'CONVERSION-FOCUSED GOOGLE ADS SYSTEM',
  '₹15,000',
  '/Month',
  1,
  0,
  JSON_ARRAY(
    'High-Converting Landing Page',
    '1000+ Words Optimized Content',
    'Google Micro Conversion Setup',
    'Performance Max Campaign',
    'Full Funnel Monitoring',
    '100% AI Monitoring System'
  ),
  3
);

SELECT * FROM packages;