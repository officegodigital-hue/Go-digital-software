// lib/taskRules.js — Task deadline rules (admin "Task Deadline Rules" page).
//
// A rule says, for one role + task (e.g. Ads Handler · Google Ads):
//   start_within_days     must be STARTED within N days of being assigned
//   complete_within_days  must be COMPLETED (submitted) within N days
//   per_week / weeks      weekly pace: per_week items every week, or when
//                         per_week is empty → ceil(total / weeks)
//                         (weeks = 4 → 8 posters = 2/week, 12 = 3/week)
//   qty                   optional: rule only for that assigned quantity
//
// role_key: designer, videographer, video_editor, website_designer,
//           ui_ux_designer, developer, ads_handling, page_handling,
//           content_calendar (Page/Ads Handler preparing a category)
// task_name '*' = any task of that role.

const ROLE_OPTIONS = [
  { key: 'ads_handling', label: 'Ads Handler' },
  { key: 'page_handling', label: 'Page Handler' },
  { key: 'content_calendar', label: 'Content Calendar (Page/Ads Handler)' },
  { key: 'designer', label: 'Designer' },
  { key: 'video_editor', label: 'Video Editor' },
  { key: 'videographer', label: 'Videographer' },
  { key: 'website_designer', label: 'Website Designer' },
  { key: 'developer', label: 'Developer' },
  { key: 'ui_ux_designer', label: 'UI/UX Designer' },
];

const SEED = [
  ['ads_handling', 'Meta Ads', null, 2, null, null, null, 'Meta Ads must start within 2 days of assignment'],
  ['ads_handling', 'Google Ads', null, 4, null, null, null, 'Google Ads must start within 4 days of assignment'],
  ['content_calendar', '*', null, null, 3, null, null, 'Prepare and assign the Content Calendar within 3 days'],
  ['website_designer', 'Landing Page', null, null, 2, null, null, 'Landing page completed within 2 days after it is assigned'],
  ['designer', 'Poster', null, null, null, null, 4, '8 posters → 2 a week, 12 posters → 3 a week'],
  ['video_editor', '*', null, null, null, null, 4, 'Weekly pace: total ÷ 4 weeks'],
];

let ready = null;
function ensureRulesTable(db) {
  if (!ready) {
    ready = (async () => {
      await db.query(`
        CREATE TABLE IF NOT EXISTS task_deadline_rules (
          id INT AUTO_INCREMENT PRIMARY KEY,
          role_key VARCHAR(40) NOT NULL,
          task_name VARCHAR(255) NOT NULL DEFAULT '*',
          qty INT NULL,
          start_within_days INT NULL,
          complete_within_days INT NULL,
          per_week INT NULL,
          weeks INT NULL,
          notes VARCHAR(500) NULL,
          is_active TINYINT(1) NOT NULL DEFAULT 1,
          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          INDEX idx_tdr_role (role_key)
        )`);
      const [[{ n }]] = await db.query('SELECT COUNT(*) AS n FROM task_deadline_rules');
      if (Number(n) === 0) {
        for (const r of SEED) {
          await db.query(
            `INSERT INTO task_deadline_rules
               (role_key, task_name, qty, start_within_days, complete_within_days, per_week, weeks, notes)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
            r,
          );
        }
      }
    })().catch((err) => {
      ready = null;
      throw err;
    });
  }
  return ready;
}

async function loadRules(db) {
  await ensureRulesTable(db);
  const [rows] = await db.query(
    'SELECT * FROM task_deadline_rules WHERE is_active = 1 ORDER BY role_key, task_name, qty',
  );
  return rows;
}

const norm = (v) => String(v ?? '').trim().replace(/\s+/g, ' ').toLowerCase();

/** Best rule for this role + task + quantity (most specific wins). */
function matchRule(rules, roleKey, taskName, qty) {
  const task = norm(taskName);
  let best = null;
  let bestScore = -1;
  for (const r of rules) {
    if (r.role_key !== roleKey) continue;
    const rt = norm(r.task_name);
    let score;
    if (rt === '*' || rt === '') score = 1;
    else if (rt === task) score = 4;
    else if (task.includes(rt) || rt.includes(task)) score = 3;
    else continue;
    if (r.qty !== null && r.qty !== undefined) {
      if (Number(r.qty) !== Number(qty)) continue;
      score += 10;
    }
    if (score > bestScore) {
      best = r;
      bestScore = score;
    }
  }
  return best;
}

const DAY = 24 * 60 * 60 * 1000;
const addDays = (d, n) => new Date(d.getTime() + n * DAY);
const daysBetween = (a, b) => Math.floor((b.getTime() - a.getTime()) / DAY);
const fmt = (d) => d
  ? d.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
  : '';

/**
 * Evaluate one piece of work against its rule.
 * work = { total, done, started, started_at, completed_at, assigned_at }
 * Returns { rule, start_due, complete_due, per_week, expected_by_now, issues[], status }
 */
function evaluate(rule, work, now = new Date()) {
  const out = {
    rule: rule ? {
      id: rule.id,
      task_name: rule.task_name,
      qty: rule.qty,
      start_within_days: rule.start_within_days,
      complete_within_days: rule.complete_within_days,
      per_week: rule.per_week,
      weeks: rule.weeks,
      notes: rule.notes,
    } : null,
    start_due: null,
    complete_due: null,
    per_week: null,
    expected_by_now: null,
    issues: [],
    status: 'NO RULE',
  };
  const assigned = work.assigned_at ? new Date(work.assigned_at) : null;
  const total = Math.max(Number(work.total) || 0, 0);
  const done = Math.max(Number(work.done) || 0, 0);
  const allDone = total > 0 && done >= total;
  if (!rule || !assigned || Number.isNaN(assigned.getTime())) {
    out.status = allDone ? 'DONE' : rule ? 'WAITING' : 'NO RULE';
    return out;
  }

  if (rule.start_within_days !== null && rule.start_within_days !== undefined) {
    const due = addDays(assigned, Number(rule.start_within_days));
    out.start_due = due.toISOString();
    if (!work.started && now > due) {
      const late = Math.max(1, Math.floor((now.getTime() - due.getTime()) / DAY));
      out.issues.push({
        type: 'NOT_STARTED',
        days_late: late,
        message: `Should have started by ${fmt(due)} — not started (${late} day${late === 1 ? '' : 's'} late)`,
      });
    }
  }
  if (rule.complete_within_days !== null && rule.complete_within_days !== undefined) {
    const due = addDays(assigned, Number(rule.complete_within_days));
    out.complete_due = due.toISOString();
    if (!allDone && now > due) {
      const late = Math.max(1, Math.floor((now.getTime() - due.getTime()) / DAY));
      out.issues.push({
        type: 'NOT_COMPLETED',
        days_late: late,
        message: `Should be completed by ${fmt(due)} — ${done}/${total} done (${late} day${late === 1 ? '' : 's'} late)`,
      });
    }
  }
  const perWeek = rule.per_week
    ? Number(rule.per_week)
    : rule.weeks ? Math.ceil(total / Number(rule.weeks)) : 0;
  if (perWeek > 0 && total > 0) {
    out.per_week = perWeek;
    const fullWeeks = Math.max(Math.floor(daysBetween(assigned, now) / 7), 0);
    const expected = Math.min(total, perWeek * fullWeeks);
    out.expected_by_now = expected;
    if (done < expected) {
      out.issues.push({
        type: 'BEHIND_WEEKLY',
        days_late: 0,
        message: `${perWeek} per week → ${expected} expected after ${fullWeeks} week${fullWeeks === 1 ? '' : 's'}, only ${done} done`,
      });
    }
  }
  out.status = out.issues.length ? 'LATE' : allDone ? 'DONE' : 'ON TRACK';
  return out;
}

module.exports = { ROLE_OPTIONS, ensureRulesTable, loadRules, matchRule, evaluate };
