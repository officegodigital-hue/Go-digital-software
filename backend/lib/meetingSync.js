const db = require('../config/db');
const { ensureMeetingSchemaOnce } = require('./ensureMeetingSchema');

const IST_OFFSET = 330 * 60 * 1000;
const wall = (epoch) => new Date(epoch + IST_OFFSET).toISOString().slice(0, 19).replace('T', ' ');
const istNowString = () => wall(Date.now());
const nameKey = (value) => String(value ?? '').trim().toLowerCase();

function wallToEpoch(value) {
  const match = /^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2}):(\d{2})$/.exec(value || '');
  if (!match || Number(match[1]) < 1000) return null;
  const [, y, m, d, h, min, s] = match;
  const epoch = Date.UTC(+y, +m - 1, +d, +h, +min, +s) - IST_OFFSET;
  return wall(epoch) === value.replace('T', ' ') ? epoch : null;
}

function normalizeWallClock(value) {
  if (typeof value !== 'string') return null;
  const raw = value.trim();
  const match = /^(\d{4}-\d{2}-\d{2})[ T](\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM)?$/i.exec(raw);
  if (match) {
    const [, date, hours, minutes, seconds = '00', meridiem] = match;
    let hour = Number(hours);
    if (meridiem) {
      if (hour < 1 || hour > 12) return null;
      hour = hour % 12 + (meridiem.toUpperCase() === 'PM' ? 12 : 0);
    }
    const normalized = date + ' ' + String(hour).padStart(2, '0') + ':' + minutes + ':' + seconds;
    return wallToEpoch(normalized) === null ? null : normalized;
  }

  const iso = /^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2})(?::(\d{2})(?:\.\d{1,3})?)?(Z|[+-]\d{2}:\d{2})$/i.exec(raw);
  if (!iso || wallToEpoch(iso[1] + ':' + (iso[2] || '00')) === null) return null;
  const epoch = Date.parse(raw);
  if (!Number.isFinite(epoch)) return null;
  const normalized = wall(epoch);
  return wallToEpoch(normalized) === null ? null : normalized;
}

function error(statusCode, message) {
  return Object.assign(new Error(message), { statusCode });
}

function resolveSchedule({ startAt, endAt, durationMins, meetingTime }) {
  const start = normalizeWallClock(startAt ?? meetingTime);
  if (!start) throw error(400, 'Enter a valid meeting date and start time (IST).');

  const hasDuration = durationMins != null && durationMins !== '';
  const duration = hasDuration ? Number(durationMins) : null;
  if (hasDuration && (!['number', 'string'].includes(typeof durationMins) ||
      !Number.isSafeInteger(duration) || duration < 1 || duration > Math.floor(2147483647 / 60))) {
    throw error(400, 'Meeting duration must be a positive whole number of minutes.');
  }

  let end = null;
  if (endAt != null && endAt !== '') {
    end = normalizeWallClock(endAt);
    if (!end) throw error(400, 'Enter a valid meeting end time (IST).');
  } else if (duration) {
    end = wall(wallToEpoch(start) + duration * 60000);
  }

  const startEpoch = wallToEpoch(start);
  const endEpoch = wallToEpoch(end);
  if (end && (endEpoch === null || endEpoch <= startEpoch)) {
    throw error(400, 'Meeting end time must be after the start time.');
  }
  if (end && endEpoch - startEpoch > 2147483647 * 1000) {
    throw error(400, 'The meeting duration is too long.');
  }
  const minutes = end ? Math.ceil((endEpoch - startEpoch) / 60000) : null;
  if (end && hasDuration && minutes !== duration) {
    throw error(400, 'Meeting end time and duration must agree.');
  }
  return { startAt: start, endAt: end, durationMins: minutes };
}

function safeJsonArray(value) {
  if (Array.isArray(value)) return value;
  try {
    const parsed = JSON.parse(value);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function selection(value) {
  if (value === undefined) return undefined;
  if (!Array.isArray(value) || value.some((name) => typeof name !== 'string' || !name.trim() || name.trim().length > 255)) {
    throw error(400, 'Meeting selections must contain valid employee or group names.');
  }
  return [...new Map(value.map((name) => [nameKey(name), name.trim()])).values()];
}

async function transaction(work) {
  await ensureMeetingSchemaOnce(db);
  for (let attempt = 0; ; attempt++) {
    const conn = await db.getConnection();
    try {
      await conn.beginTransaction();
      const result = await work(conn);
      await conn.commit();
      return result;
    } catch (err) {
      await conn.rollback();
      if (err.code !== 'ER_LOCK_DEADLOCK' || attempt >= 2) throw err;
    } finally {
      conn.release();
    }
  }
}

const wallFields = ['start_at', 'end_at', 'started_at', 'completed_at']
  .map((field) => "DATE_FORMAT(" + field + ", '%Y-%m-%d %H:%i:%s') AS " + field).join(', ');

async function lockMeeting(conn, id) {
  const [[meeting]] = await conn.query(
    'SELECT *, ' + wallFields + ' FROM scheduled_meetings WHERE id = ? FOR UPDATE', [id],
  );
  if (!meeting) throw error(404, 'Meeting not found.');
  return meeting;
}

async function expandParticipants(conn, meeting, { lockGroups = false, validateGroups = false } = {}) {
  const names = new Map();
  function add(value, source, group = null) {
    if (typeof value !== 'string' || !value.trim() || names.has(nameKey(value))) return;
    names.set(nameKey(value), { name: value.trim(), source, group });
  }

  for (const name of safeJsonArray(meeting.attendees)) add(name, 'individual');
  const groups = safeJsonArray(meeting.groups).filter((group) => typeof group === 'string' && group.trim());
  if (groups.length) {
    const [rows] = await conn.query(
      'SELECT group_name, members FROM chat_groups WHERE group_name IN (?) ORDER BY id' +
        (lockGroups ? ' LOCK IN SHARE MODE' : ''),
      [groups],
    );
    if (validateGroups) {
      const found = new Set(rows.map((row) => nameKey(row.group_name)));
      if (groups.some((group) => !found.has(nameKey(group)))) {
        throw error(400, 'A selected chat group is no longer available. Refresh the meeting and select it again.');
      }
    }
    for (const row of rows) {
      for (const name of safeJsonArray(row.members)) add(name, 'group', row.group_name);
    }
  }
  return names;
}

function open(meeting) {
  return meeting.status === 'Scheduled' || meeting.status === 'Active';
}

async function closeSessions(conn, meetingId, status, end, employeeName = null) {
  const employeeClause = employeeName === null ? '' : ' AND employee_name = ?';
  await conn.query(
    "UPDATE meeting_tracking_sessions SET status = ?, ended_at = GREATEST(started_at, ?), " +
    "tracked_intervals = JSON_ARRAY_APPEND(COALESCE(tracked_intervals, " +
    "IF(duration_secs > 0, JSON_ARRAY(JSON_ARRAY(DATE_FORMAT(started_at, '%Y-%m-%d %H:%i:%s'), " +
    "DATE_FORMAT(DATE_ADD(started_at, INTERVAL duration_secs SECOND), '%Y-%m-%d %H:%i:%s'))), JSON_ARRAY())), " +
    "'$', JSON_ARRAY(DATE_FORMAT(COALESCE(active_since, started_at), '%Y-%m-%d %H:%i:%s'), ?)), " +
    "duration_secs = duration_secs + GREATEST(0, TIMESTAMPDIFF(SECOND, COALESCE(active_since, started_at), ?)), " +
    "active_since = NULL WHERE meeting_id = ? AND status = 'ACTIVE'" + employeeClause,
    [status, end, end, end, meetingId, ...(employeeName === null ? [] : [employeeName])],
  );
}

async function syncParticipants(conn, meeting, now, { existingSchedule = false, validateGroups = false } = {}) {
  const desired = await expandParticipants(conn, meeting, { lockGroups: true, validateGroups });
  const [current] = await conn.query(
    "SELECT employee_name FROM meeting_participants WHERE meeting_id = ?", [meeting.id],
  );
  const previous = new Set(current.map((row) => nameKey(row.employee_name)));
  for (const { employee_name: name } of current) {
    if (desired.has(nameKey(name))) continue;
    await conn.query('DELETE FROM meeting_participants WHERE meeting_id = ? AND employee_name = ?', [meeting.id, name]);
    await conn.query(
      "DELETE FROM meeting_tracking_sessions WHERE meeting_id = ? AND employee_name = ? AND status = 'SCHEDULED'",
      [meeting.id, name],
    );
    const end = meeting.end_at && meeting.end_at < now ? meeting.end_at : now;
    await closeSessions(conn, meeting.id, 'CANCELLED', end, name);
  }

  for (const [key, { name, source, group }] of desired) {
    await conn.query(
      'INSERT INTO meeting_participants (meeting_id, employee_name, source, source_group) VALUES (?, ?, ?, ?) ' +
      'ON DUPLICATE KEY UPDATE source = VALUES(source), source_group = VALUES(source_group)',
      [meeting.id, name, source, group],
    );
    const running = meeting.status === 'Active';
    const joining = running && !previous.has(key);
    const started = running ? (existingSchedule ? meeting.started_at || meeting.start_at || now : now) : null;
    await conn.query(
      `INSERT INTO meeting_tracking_sessions
         (meeting_id, employee_name, status, scheduled_start, scheduled_end, started_at, active_since)
       VALUES (?, ?, ?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE
         scheduled_start = VALUES(scheduled_start), scheduled_end = VALUES(scheduled_end),
         started_at = IF((status = 'CANCELLED' AND ?) OR status = 'SCHEDULED',
           COALESCE(started_at, VALUES(started_at)), started_at),
         active_since = IF((status = 'CANCELLED' AND ?) OR status = 'SCHEDULED', VALUES(active_since), active_since),
         ended_at = IF(status = 'CANCELLED' AND ?, NULL, ended_at),
         status = IF((status = 'CANCELLED' AND ?) OR status = 'SCHEDULED', VALUES(status), status)`,
      [meeting.id, name, running ? 'ACTIVE' : 'SCHEDULED', meeting.start_at, meeting.end_at,
        started, started, joining, joining, joining, joining],
    );
  }
  return desired;
}

async function activate(conn, meeting, start) {
  await conn.query(
    "UPDATE scheduled_meetings SET status = 'Active', started_at = COALESCE(started_at, ?) WHERE id = ?",
    [start, meeting.id],
  );
  await conn.query(
    "UPDATE meeting_tracking_sessions SET status = 'ACTIVE', started_at = COALESCE(started_at, ?), active_since = ? " +
    "WHERE meeting_id = ? AND status = 'SCHEDULED'", [start, start, meeting.id],
  );
  meeting.status = 'Active';
  meeting.started_at ||= start;
}

async function finish(conn, meeting, status, end) {
  await closeSessions(conn, meeting.id, status === 'Completed' ? 'COMPLETED' : 'CANCELLED', end);
  await conn.query(
    "UPDATE meeting_tracking_sessions SET status = 'CANCELLED', ended_at = ? WHERE meeting_id = ? AND status = 'SCHEDULED'",
    [end, meeting.id],
  );
  await conn.query(
    'UPDATE scheduled_meetings SET status = ?, completed_at = ? WHERE id = ?',
    [status, status === 'Completed' ? end : null, meeting.id],
  );
  meeting.status = status;
}

async function closeEndedMeeting(conn, meeting, now) {
  if (meeting.status !== 'Active' || !meeting.end_at || meeting.end_at > now) return false;
  await finish(conn, meeting, 'Completed', meeting.end_at);
  return true;
}

async function backfillOpenMeetings() {
  const [rows] = await db.query("SELECT id FROM scheduled_meetings WHERE status IN ('Scheduled', 'Active')");
  for (const { id } of rows) {
    await transaction(async (conn) => {
      const meeting = await lockMeeting(conn, id);
      if (!open(meeting)) return;
      const now = istNowString();
      if (!meeting.start_at) {
        meeting.start_at = normalizeWallClock(meeting.meeting_time);
        if (meeting.start_at) {
          if (meeting.status === 'Active' && !meeting.started_at) {
            meeting.status = 'Scheduled';
          }
          await conn.query('UPDATE scheduled_meetings SET start_at = ?, status = ? WHERE id = ?',
            [meeting.start_at, meeting.status, id]);
        }
      }
      await syncParticipants(conn, meeting, now, { existingSchedule: true });
    });
  }
}

async function closeEndedMeetings() {
  const now = istNowString();
  const [rows] = await db.query(
    "SELECT id FROM scheduled_meetings WHERE status = 'Active' AND end_at <= ?", [now],
  );
  let closed = 0;
  for (const { id } of rows) {
    const changed = await transaction(async (conn) => closeEndedMeeting(conn, await lockMeeting(conn, id), now));
    if (changed) closed++;
  }
  return { closed };
}

async function updateGroupMeetings(conn, oldName, newName) {
  const [rows] = await conn.query(
    "SELECT id FROM scheduled_meetings WHERE status IN ('Scheduled', 'Active') ORDER BY id FOR UPDATE",
  );
  const now = istNowString();
  let changed = false;
  for (const { id } of rows) {
    const meeting = await lockMeeting(conn, id);
    const groups = safeJsonArray(meeting.groups);
    if (!groups.some((group) => nameKey(group) === nameKey(oldName))) continue;
    await closeEndedMeeting(conn, meeting, now);
    if (!open(meeting)) {
      changed = true;
      continue;
    }
    if (oldName !== newName) {
      meeting.groups = JSON.stringify(groups.map((group) => nameKey(group) === nameKey(oldName) ? newName : group));
      await conn.query('UPDATE scheduled_meetings SET `groups` = ? WHERE id = ?', [meeting.groups, id]);
    }
    await syncParticipants(conn, meeting, now);
    changed = true;
  }
  return changed;
}

async function getLiveSessionsForEmployee(employeeName, date) {
  const now = istNowString();
  const day = date ?? now.slice(0, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(day) || wallToEpoch(day + ' 00:00:00') === null) {
    throw error(400, 'Enter a valid tracking date (YYYY-MM-DD).');
  }

  const [rows] = await db.query(
    `SELECT s.id, s.meeting_id, s.status, s.duration_secs,
            DATE_FORMAT(s.scheduled_start, '%Y-%m-%d %H:%i:%s') AS scheduled_start,
            DATE_FORMAT(s.scheduled_end, '%Y-%m-%d %H:%i:%s') AS scheduled_end,
            DATE_FORMAT(s.started_at, '%Y-%m-%d %H:%i:%s') AS started_at,
            DATE_FORMAT(s.ended_at, '%Y-%m-%d %H:%i:%s') AS ended_at,
            DATE_FORMAT(s.active_since, '%Y-%m-%d %H:%i:%s') AS active_since,
            m.title, m.meeting_link, m.host_name, m.meeting_details, m.status AS meeting_status
     FROM meeting_tracking_sessions s
     JOIN scheduled_meetings m ON m.id = s.meeting_id
     WHERE LOWER(TRIM(s.employee_name)) = ?
       AND (s.status = 'ACTIVE'
            OR (s.status IN ('SCHEDULED', 'CANCELLED') AND s.started_at IS NULL AND DATE(s.scheduled_start) = ?)
            OR (DATE(s.started_at) <= ? AND DATE(s.ended_at) >= ?))
     ORDER BY s.scheduled_start IS NULL, s.scheduled_start, s.id`,
    [nameKey(employeeName), day, day, day],
  );

  return rows.map((row) => {
    let seconds = Number(row.duration_secs || 0);
    if (row.status === 'ACTIVE' && row.started_at) {
      const end = row.scheduled_end && row.scheduled_end < now ? row.scheduled_end : now;
      seconds += Math.max(0, (wallToEpoch(end) - wallToEpoch(row.active_since || row.started_at)) / 1000);
    }
    return {
      sessionId: row.id, meetingId: row.meeting_id, title: row.title || 'Meeting',
      host: row.host_name || '', link: row.meeting_link || '', details: row.meeting_details || '',
      status: row.status, meetingStatus: row.meeting_status,
      remainingSecs: row.status === 'ACTIVE' && row.scheduled_end
        ? Math.max(0, (wallToEpoch(row.scheduled_end) - wallToEpoch(now)) / 1000)
        : null,
      scheduledStart: row.scheduled_start, scheduledEnd: row.scheduled_end,
      startedAt: row.started_at, endedAt: row.ended_at, durationSecs: seconds,
    };
  });
}

async function meetingWork(employee, from, now, to) {
  await ensureMeetingSchemaOnce(db);
  const [rows] = await db.query(
    `SELECT status, duration_secs, tracked_intervals,
            DATE_FORMAT(started_at, '%Y-%m-%d %H:%i:%s') AS started_at,
            DATE_FORMAT(active_since, '%Y-%m-%d %H:%i:%s') AS active_since,
            DATE_FORMAT(scheduled_end, '%Y-%m-%d %H:%i:%s') AS scheduled_end
       FROM meeting_tracking_sessions
       WHERE LOWER(TRIM(employee_name)) = ? AND started_at < ?
         AND (status = 'ACTIVE' OR ended_at > ?)`,
    [nameKey(employee), wall(to.getTime()), wall(from.getTime())],
  );
  const intervals = [];
  let runningUntil = 0;
  function add(start, end) {
    if (start === null || end === null) return;
    const first = Math.max(start, from.getTime());
    const last = Math.min(end, now.getTime(), to.getTime());
    if (first < last) intervals.push([first, last]);
  }
  for (const row of rows) {
    const started = wallToEpoch(row.started_at);
    if (row.tracked_intervals == null && row.duration_secs > 0 && started !== null) {
      // Older records retained elapsed seconds but did not store rejoin intervals.
      add(started, started + Number(row.duration_secs) * 1000);
    }
    for (const [start, end] of safeJsonArray(row.tracked_intervals)) {
      add(wallToEpoch(start), wallToEpoch(end));
    }
    if (row.status === 'ACTIVE') {
      const stop = Math.min(wallToEpoch(row.scheduled_end) ?? Infinity, to.getTime());
      const start = wallToEpoch(row.active_since) ?? started;
      add(start, stop);
      if (start !== null && start <= now.getTime() && stop > now.getTime()) {
        runningUntil = Math.max(runningUntil, stop);
      }
    }
  }
  return { intervals, runningUntil };
}

module.exports = {
  meetingWork,
  closeEndedMeetings, activate, backfillOpenMeetings, error, expandParticipants, finish,
  getLiveSessionsForEmployee, istNowString, lockMeeting, nameKey, open, resolveSchedule,
  safeJsonArray, selection, syncParticipants, transaction, updateGroupMeetings, wallToEpoch,
};
