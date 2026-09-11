const TIME_ZONE = process.env.ATTENDANCE_TZ || 'Asia/Kolkata';
const REQUIRED_MINUTES = Number(process.env.ATTENDANCE_REQUIRED_MINUTES || 9 * 60);
const defaults = Object.freeze({
  shiftStart: process.env.ATTENDANCE_SHIFT_START || '09:30:00',
  shiftEnd: process.env.ATTENDANCE_SHIFT_END || '18:30:00',
  lateAfter: process.env.ATTENDANCE_LATE_AFTER || '10:00:00',
});
let settings = { ...defaults };

function partsInZone(date, timeZone) {
  date = date || new Date();
  timeZone = timeZone || TIME_ZONE;
  const formatted = new Intl.DateTimeFormat('en-GB', {
    timeZone: timeZone, year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', second: '2-digit', hourCycle: 'h23'
  }).formatToParts(date);
  function get(type) { return formatted.find(function (part) { return part.type === type; }).value; }
  const year = get('year'); const month = get('month'); const day = get('day');
  const hour = get('hour'); const minute = get('minute'); const second = get('second');
  return { date: year + '-' + month + '-' + day, time: hour + ':' + minute + ':' + second,
    dateTime: year + '-' + month + '-' + day + ' ' + hour + ':' + minute + ':' + second,
    hour: Number(hour), minute: Number(minute), second: Number(second) };
}
function todayIstDate() { return partsInZone().date; }
function nowIstDateTime() { return partsInZone().dateTime; }
function timeToSeconds(hhmmss) { const p = String(hhmmss).split(':'); return (Number(p[0]) || 0) * 3600 + (Number(p[1]) || 0) * 60 + (Number(p[2]) || 0); }
function isLateCheckIn(dateTimeSql) { const time = String(dateTimeSql).slice(11, 19); return timeToSeconds(time) > timeToSeconds(settings.lateAfter); }
function isLateAt(date, timeZone) { return timeToSeconds(partsInZone(date, timeZone).time) > timeToSeconds(settings.lateAfter); }
function minutesBetween(startSql, endSql) { const start = new Date(String(startSql).replace(' ', 'T')); const end = new Date(String(endSql).replace(' ', 'T')); if (isNaN(start.getTime()) || isNaN(end.getTime())) return 0; return Math.max(0, Math.round((end.getTime() - start.getTime()) / 60000)); }
function isEarlyExit(workingMinutes) { return Number(workingMinutes || 0) < REQUIRED_MINUTES; }
function formatDisplayTime(dateTimeSql) { if (!dateTimeSql) return '-'; const time = String(dateTimeSql).slice(11, 19); const parts = time.split(':'); const h = Number(parts[0]); const suffix = h >= 12 ? 'PM' : 'AM'; const hour12 = ((h + 11) % 12) + 1; return String(hour12).padStart(2, '0') + ':' + parts[1] + ' ' + suffix; }
function displayStatus(row) { if (row.status === 'on_leave') return 'On Leave'; if (!row.checkInAt) return 'Absent'; if (row.checkOutAt && isEarlyExit(minutesBetween(row.checkInAt, row.checkOutAt))) return 'Early Exit'; if (row.isLate || row.status === 'late') return 'Late'; return 'Present'; }
function weekdayShort(dateStr) { const p = dateStr.split('-').map(Number); return ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][new Date(Date.UTC(p[0], p[1] - 1, p[2])).getUTCDay()]; }
function addDays(dateStr, days) { const p = dateStr.split('-').map(Number); const next = new Date(Date.UTC(p[0], p[1] - 1, p[2]) + days * 86400000); return next.getUTCFullYear() + '-' + String(next.getUTCMonth() + 1).padStart(2, '0') + '-' + String(next.getUTCDate()).padStart(2, '0'); }
function weekdaysForDate(dateStr) { const p = dateStr.split('-').map(Number); const day = new Date(Date.UTC(p[0], p[1] - 1, p[2])).getUTCDay(); const monday = addDays(dateStr, day === 0 ? -6 : 1 - day); return [0, 1, 2, 3, 4].map(function (offset) { return addDays(monday, offset); }); }
function normalizeTime(value, label) { const match = /^(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d)?$/.exec(String(value || '').trim()); if (!match) throw new Error(label + ' must use HH:mm'); return String(value).trim().length === 5 ? String(value).trim() + ':00' : String(value).trim(); }
async function ensureTimeSettings(db) { await db.query(`CREATE TABLE IF NOT EXISTS hrms_attendance_time_settings (id TINYINT PRIMARY KEY, shift_start TIME NOT NULL, shift_end TIME NOT NULL, late_after TIME NOT NULL, updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP)`); await db.query('INSERT IGNORE INTO hrms_attendance_time_settings (id, shift_start, shift_end, late_after) VALUES (1, ?, ?, ?)', [defaults.shiftStart, defaults.shiftEnd, defaults.lateAfter]); }
async function getTimeSettings(db) { await ensureTimeSettings(db); const [rows] = await db.query('SELECT shift_start, shift_end, late_after FROM hrms_attendance_time_settings WHERE id = 1'); if (rows[0]) { settings = { shiftStart: String(rows[0].shift_start), shiftEnd: String(rows[0].shift_end), lateAfter: String(rows[0].late_after) }; if (timeToSeconds(settings.lateAfter) < timeToSeconds(settings.shiftStart)) { settings.lateAfter = settings.shiftStart; await db.query('UPDATE hrms_attendance_time_settings SET late_after = ? WHERE id = 1', [settings.lateAfter]); } } return { ...settings }; }
async function updateTimeSettings(db, value) { const next = { shiftStart: normalizeTime(value.shiftStart, 'Check-in time'), shiftEnd: normalizeTime(value.shiftEnd, 'Check-out time'), lateAfter: normalizeTime(value.lateAfter, 'Late-after time') }; if (timeToSeconds(next.lateAfter) < timeToSeconds(next.shiftStart)) next.lateAfter = next.shiftStart; await ensureTimeSettings(db); await db.query('UPDATE hrms_attendance_time_settings SET shift_start = ?, shift_end = ?, late_after = ? WHERE id = 1', [next.shiftStart, next.shiftEnd, next.lateAfter]); settings = next; return { ...settings }; }
module.exports = { TIME_ZONE, REQUIRED_MINUTES, partsInZone, todayIstDate, nowIstDateTime, isLateCheckIn, isLateAt, minutesBetween, isEarlyExit, formatDisplayTime, displayStatus, weekdayShort, weekdaysForDate, getTimeSettings, updateTimeSettings, get LATE_AFTER() { return settings.lateAfter; }, get SHIFT_START() { return settings.shiftStart; }, get SHIFT_END() { return settings.shiftEnd; } };


