'use strict';

const db = require('../config/db');

const STANDARD_ID = null;
const DAY_NAMES = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
function dateValue(value) { return value instanceof Date ? value.toISOString().slice(0, 10) : String(value || '').slice(0, 10); }

async function ensureTables() {
  await db.query(`CREATE TABLE IF NOT EXISTS hrms_working_day_templates (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(120) NOT NULL,
    description VARCHAR(500) NULL,
    version INT UNSIGNED NOT NULL DEFAULT 1,
    effective_from DATE NOT NULL,
    is_archived TINYINT(1) NOT NULL DEFAULT 0,
    created_by BIGINT UNSIGNED NULL,
    updated_by BIGINT UNSIGNED NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_working_template_name_version (name, version)
  )`);
  await db.query(`CREATE TABLE IF NOT EXISTS hrms_working_day_template_days (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    template_id BIGINT UNSIGNED NOT NULL,
    weekday TINYINT UNSIGNED NOT NULL,
    is_working TINYINT(1) NOT NULL DEFAULT 0,
    shift_start TIME NULL,
    shift_end TIME NULL,
    break_start TIME NULL,
    break_end TIME NULL,
    UNIQUE KEY uq_working_template_day (template_id, weekday)
  )`);
  await db.query(`CREATE TABLE IF NOT EXISTS hrms_employee_working_day_assignments (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    profile_id BIGINT UNSIGNED NOT NULL,
    template_id BIGINT UNSIGNED NULL,
    effective_from DATE NOT NULL,
    effective_to DATE NULL,
    assigned_by BIGINT UNSIGNED NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_employee_working_assignment (profile_id, effective_from)
  )`);
  await db.query(`CREATE TABLE IF NOT EXISTS hrms_working_day_audit (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    entity_type VARCHAR(40) NOT NULL,
    entity_id BIGINT UNSIGNED NULL,
    action VARCHAR(40) NOT NULL,
    before_json JSON NULL,
    after_json JSON NULL,
    changed_by BIGINT UNSIGNED NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
  )`);
  // A NULL template_id explicitly represents Standard Working Days. This
  // gives every existing profile a stable default without changing history.
  await db.query(`INSERT INTO hrms_employee_working_day_assignments (profile_id, template_id, effective_from)
    SELECT p.id, NULL, CURDATE() FROM hrms_employee_profiles p
    LEFT JOIN hrms_employee_working_day_assignments a ON a.profile_id = p.id
    WHERE a.id IS NULL`);
}

function normalizeDay(day, index) {
  const value = day || {};
  const weekday = Number(value.weekday ?? index);
  const isWorking = Boolean(value.isWorking ?? value.is_working);
  const start = isWorking ? String(value.shiftStart ?? value.shift_start ?? '').trim() : null;
  const end = isWorking ? String(value.shiftEnd ?? value.shift_end ?? '').trim() : null;
  const breakStart = isWorking ? String(value.breakStart ?? value.break_start ?? '').trim() || null : null;
  const breakEnd = isWorking ? String(value.breakEnd ?? value.break_end ?? '').trim() || null : null;
  if (!Number.isInteger(weekday) || weekday < 0 || weekday > 6) throw new Error('weekday must be between 0 and 6');
  if (isWorking && (!/^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/.test(start) || !/^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/.test(end))) throw new Error(`${DAY_NAMES[weekday]} requires valid shift start and end times`);
  if (breakStart && !/^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/.test(breakStart)) throw new Error('Invalid break start time');
  if (breakEnd && !/^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/.test(breakEnd)) throw new Error('Invalid break end time');
  if (breakStart && breakEnd && !(breakStart < breakEnd && start < breakStart && breakEnd < end)) throw new Error(`${DAY_NAMES[weekday]} break must be inside the shift`);
  if (isWorking && !(start < end)) throw new Error(`${DAY_NAMES[weekday]} cannot be an overnight shift`);
  return { weekday, isWorking: isWorking ? 1 : 0, shiftStart: start || null, shiftEnd: end || null, breakStart, breakEnd };
}

function normalizeDays(days) {
  const input = Array.isArray(days) ? days : [];
  const seen = new Set();
  const result = [];
  for (let i = 0; i < input.length; i += 1) {
    const day = normalizeDay(input[i], i);
    if (seen.has(day.weekday)) throw new Error('Each weekday may appear only once');
    seen.add(day.weekday); result.push(day);
  }
  if (!result.some((day) => day.isWorking)) throw new Error('Template must contain at least one working day');
  for (let weekday = 0; weekday < 7; weekday += 1) if (!seen.has(weekday)) result.push({ weekday, isWorking: 0, shiftStart: null, shiftEnd: null, breakStart: null, breakEnd: null });
  return result.sort((a, b) => a.weekday - b.weekday);
}

async function audit(entityType, entityId, action, before, after, changedBy) {
  await db.query('INSERT INTO hrms_working_day_audit (entity_type, entity_id, action, before_json, after_json, changed_by) VALUES (?, ?, ?, ?, ?, ?)', [entityType, entityId || null, action, before ? JSON.stringify(before) : null, after ? JSON.stringify(after) : null, changedBy || null]);
}

async function list(includeArchived = false) {
  await ensureTables();
  const [rows] = await db.query(`SELECT * FROM hrms_working_day_templates ${includeArchived ? '' : 'WHERE is_archived = 0'} ORDER BY name, version DESC`);
  const output = [];
  for (const row of rows) {
    const [days] = await db.query('SELECT weekday, is_working, shift_start, shift_end, break_start, break_end FROM hrms_working_day_template_days WHERE template_id = ? ORDER BY weekday', [row.id]);
    output.push({ ...row, days: days.map((day) => ({ weekday: Number(day.weekday), isWorking: Boolean(Number(day.is_working)), shiftStart: day.shift_start, shiftEnd: day.shift_end, breakStart: day.break_start, breakEnd: day.break_end })) });
  }
  return output;
}

async function create(body, adminId) {
  await ensureTables();
  const name = String(body.name || '').trim();
  if (!name) throw new Error('Template name is required');
  const days = normalizeDays(body.days);
  const [existing] = await db.query('SELECT id FROM hrms_working_day_templates WHERE LOWER(name) = LOWER(?) AND is_archived = 0 LIMIT 1', [name]);
  if (existing.length) throw new Error('An active template with this name already exists');
  const connection = await db.getConnection();
  try {
    await connection.beginTransaction();
    const [result] = await connection.query('INSERT INTO hrms_working_day_templates (name, description, version, effective_from, created_by, updated_by) VALUES (?, ?, 1, COALESCE(?, CURDATE()), ?, ?)', [name, String(body.description || '').trim() || null, body.effectiveFrom || null, adminId || null, adminId || null]);
    for (const day of days) await connection.query('INSERT INTO hrms_working_day_template_days (template_id, weekday, is_working, shift_start, shift_end, break_start, break_end) VALUES (?, ?, ?, ?, ?, ?, ?)', [result.insertId, day.weekday, day.isWorking, day.shiftStart, day.shiftEnd, day.breakStart, day.breakEnd]);
    await connection.commit();
    const created = { id: result.insertId, name, description: String(body.description || '').trim(), version: 1, effectiveFrom: body.effectiveFrom || new Date().toISOString().slice(0, 10), days };
    await audit('working_day_template', result.insertId, 'created', null, created, adminId);
    return created;
  } catch (error) { await connection.rollback(); throw error; } finally { connection.release(); }
}

async function assignmentFor(profileId, date) {
  await ensureTables();
  const [rows] = await db.query(`SELECT a.template_id, t.name, t.version, d.weekday, d.is_working, d.shift_start, d.shift_end, d.break_start, d.break_end
    FROM hrms_employee_working_day_assignments a LEFT JOIN hrms_working_day_templates t ON t.id = a.template_id
    LEFT JOIN hrms_working_day_template_days d ON d.template_id = a.template_id
    WHERE a.profile_id = ? AND a.effective_from <= ? AND (a.effective_to IS NULL OR a.effective_to >= ?) ORDER BY a.effective_from DESC, a.id DESC`, [profileId, date, date]);
  if (!rows.length || !rows[0].template_id) return null;
  return { id: rows[0].template_id, name: rows[0].name, version: rows[0].version, days: rows.map((row) => ({ weekday: Number(row.weekday), isWorking: Boolean(Number(row.is_working)), shiftStart: row.shift_start, shiftEnd: row.shift_end, breakStart: row.break_start, breakEnd: row.break_end })) };
}

async function assign(profileId, body, adminId) {
  await ensureTables();
  const type = String(body.workingDaysType || body.working_days_type || 'standard').toLowerCase();
  // Employee-form assignments are effective immediately unless an explicit
  // future date is supplied by a dedicated assignment workflow.
  const effectiveFrom = String(body.effectiveFrom || body.effective_from || new Date().toISOString().slice(0, 10));
  let templateId = null;
  if (type === 'template') {
    templateId = Number(body.workingDaysTemplateId || body.working_days_template_id);
    if (!templateId) throw new Error('A working-days template is required');
    const [rows] = await db.query('SELECT id FROM hrms_working_day_templates WHERE id = ? AND is_archived = 0', [templateId]);
    if (!rows.length) throw new Error('Working-days template is unavailable');
  } else if (type !== 'standard') throw new Error('workingDaysType must be standard or template');
  const [current] = await db.query('SELECT * FROM hrms_employee_working_day_assignments WHERE profile_id = ? AND effective_to IS NULL ORDER BY effective_from DESC, id DESC LIMIT 1', [profileId]);
  if (current[0] && dateValue(current[0].effective_from) === effectiveFrom && Number(current[0].template_id || 0) === Number(templateId || 0)) return;
  // When an admin changes the assignment today, close the previous current
  // assignment as well as future assignments. Otherwise two open rows can
  // remain and different list queries may continue to display Standard.
  if (current[0] && (dateValue(current[0].effective_from) !== effectiveFrom || Number(current[0].template_id || 0) !== Number(templateId || 0))) await db.query('UPDATE hrms_employee_working_day_assignments SET effective_to = DATE_SUB(?, INTERVAL 1 DAY) WHERE id = ?', [effectiveFrom, current[0].id]);
  const [result] = await db.query('INSERT INTO hrms_employee_working_day_assignments (profile_id, template_id, effective_from, assigned_by) VALUES (?, ?, ?, ?)', [profileId, templateId, effectiveFrom, adminId || null]);
  await audit('employee_working_days', profileId, 'assigned', current[0] || null, { templateId, type, effectiveFrom, assignmentId: result.insertId }, adminId);
}

async function isWorkingDay(profileId, date, standardFn) {
  const template = await assignmentFor(profileId, date);
  if (!template) return standardFn();
  const weekday = new Date(`${date}T00:00:00Z`).getUTCDay();
  return Boolean(template.days.find((day) => day.weekday === weekday)?.isWorking);
}

async function workingDaysForPeriod(profileId, start, end, weeklyOff, overrides) {
  await ensureTables();
  const [assignments] = await db.query(`SELECT a.template_id, a.effective_from, a.effective_to, d.weekday, d.is_working
    FROM hrms_employee_working_day_assignments a LEFT JOIN hrms_working_day_template_days d ON d.template_id = a.template_id
    WHERE a.profile_id = ? AND (a.effective_to IS NULL OR a.effective_to >= ?) AND a.effective_from <= ? ORDER BY a.effective_from ASC`, [profileId, start, end]);
  const result = new Map();
  for (let date = start; date <= end; date = nextDate(date)) {
    const override = overrides.get(date);
    if (override === 'Working Day') { result.set(date, true); continue; }
    if (override === 'Holiday' || override === 'Weekly Off') { result.set(date, false); continue; }
    const row = assignments.filter((item) => dateValue(item.effective_from) <= date && (!item.effective_to || dateValue(item.effective_to) >= date));
    const templateId = row.length ? row[0].template_id : null;
    if (!templateId) { result.set(date, !weeklyOff.has(new Date(`${date}T00:00:00Z`).getUTCDay())); continue; }
    const weekday = new Date(`${date}T00:00:00Z`).getUTCDay();
    const day = row.find((item) => Number(item.weekday) === weekday);
    result.set(date, Boolean(day && Number(day.is_working)));
  }
  return result;
}

function nextDate(date) { const [year, month, day] = String(date).split('-').map(Number); const value = new Date(Date.UTC(year, month - 1, day + 1)); return `${value.getUTCFullYear()}-${String(value.getUTCMonth() + 1).padStart(2, '0')}-${String(value.getUTCDate()).padStart(2, '0')}`; }

module.exports = { ensureTables, list, create, normalizeDays, assignmentFor, assign, isWorkingDay, workingDaysForPeriod, audit, STANDARD_ID };
