const db = require('../config/db');
const policy = require('../lib/attendancePolicy');
const locationPolicy = require('../lib/attendanceLocationPolicy');

function ok(res, data, message) {
  return res.json({ success: true, message: message || 'OK', data: data });
}

function fail(res, status, message) {
  return res.status(status).json({ success: false, message: message });
}

function requireAdmin(req, res, next) {
  const userType = String((req.user && req.user.userType) || '').toLowerCase();
  if (userType !== 'admin') {
    return fail(res, 403, 'Admin access required');
  }
  return next();
}

const LEAVE_TYPES = ['leave', 'risk_leave', 'annual_leave', 'sick_leave', 'personal_leave'];

function isoDate(value) {
  if (!value) return '';
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return value.toISOString().slice(0, 10);
  }
  const match = String(value).match(/(\d{4}-\d{2}-\d{2})/);
  return match ? match[1] : '';
}

function formatHours(minutes) {
  const total = Math.max(0, Number(minutes) || 0);
  const hours = Math.floor(total / 60);
  const mins = total % 60;
  if (!total) return '—';
  return hours + 'h ' + String(mins).padStart(2, '0') + 'm';
}

function minutesFromCheckIn(checkInAt) {
  if (!checkInAt) return 0;
  const start = new Date(String(checkInAt).replace(' ', 'T'));
  if (Number.isNaN(start.getTime())) return 0;
  return Math.max(0, Math.round((Date.now() - start.getTime()) / 60000));
}

function weekdayIndex(date) {
  const [year, month, day] = date.split('-').map(Number);
  return new Date(Date.UTC(year, month - 1, day)).getUTCDay();
}

async function list(req, res) {
  try {
    const today = policy.todayIstDate();
    const date = String(req.query.date || today).slice(0, 10);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
      return fail(res, 400, 'date must be YYYY-MM-DD');
    }
    const employee = String(req.query.employee || '').trim();
    const statusFilter = String(req.query.status || '').trim();
    const isSunday = weekdayIndex(date) === 0;
    const isFuture = date > today;

    const [profiles] = await db.query(`
      SELECT * FROM hrms_employee_profiles
      WHERE employment_status <> 'Inactive'
      ORDER BY full_name ASC
    `);

    const userIds = profiles.map(function (row) { return row.employee_user_id; }).filter(Boolean);

    const [records] = userIds.length
      ? await db.query(
          `SELECT employee_id, DATE_FORMAT(attendance_date, '%Y-%m-%d') AS attendance_date,
                  check_in_at, check_out_at, is_late, working_minutes, check_in_method,
                  attendance_status, session_status
           FROM attendance_records
           WHERE attendance_date = ?
             AND employee_id IN (?)`,
          [date, userIds]
        )
      : [[]];

    const leavePlaceholders = LEAVE_TYPES.map(function () { return '?'; }).join(', ');
    const [leaves] = userIds.length
      ? await db.query(
          `SELECT employee_id, request_type
           FROM attendance_permission_requests
           WHERE status = 'approved'
             AND request_type IN (` + leavePlaceholders + `)
             AND request_date = ?
             AND employee_id IN (?)`,
          LEAVE_TYPES.concat([date, userIds])
        )
      : [[]];

    const recordMap = new Map();
    records.forEach(function (row) {
      recordMap.set(Number(row.employee_id), row);
    });
    const leaveMap = new Map();
    leaves.forEach(function (row) {
      leaveMap.set(Number(row.employee_id), row.request_type);
    });

    let present = 0;
    let late = 0;
    let stillIn = 0;
    let absent = 0;
    let onLeave = 0;

    let items = profiles.map(function (profile) {
      const record = profile.employee_user_id
        ? recordMap.get(Number(profile.employee_user_id))
        : null;
      const leaveType = profile.employee_user_id
        ? leaveMap.get(Number(profile.employee_user_id))
        : null;
      const checkIn = record && record.check_in_at;
      const checkOut = record && record.check_out_at;
      const isLate = Boolean(record && Number(record.is_late));
      let status = 'Absent';
      let minutes = Number((record && record.working_minutes) || 0);

      if (isFuture) {
        status = 'Upcoming';
      } else if (isSunday) {
        status = 'Weekly off';
      } else if (checkIn) {
        if (checkOut) {
          status = isLate ? 'Late · out' : 'Checked out';
          present += 1;
          if (isLate) late += 1;
        } else {
          status = isLate ? 'Late · in' : 'In';
          minutes = minutesFromCheckIn(checkIn);
          present += 1;
          stillIn += 1;
          if (isLate) late += 1;
        }
      } else if (leaveType) {
        status = 'On leave';
        onLeave += 1;
      } else {
        absent += 1;
      }

      return {
        profileId: profile.id,
        employeeUserId: profile.employee_user_id,
        name: String(profile.full_name || '').trim(),
        employeeCode: profile.employee_code,
        department: profile.department,
        checkIn: policy.formatDisplayTime(checkIn),
        checkOut: policy.formatDisplayTime(checkOut),
        method: (record && record.check_in_method) || '—',
        hours: formatHours(minutes),
        workingMinutes: minutes,
        isLate: isLate,
        status: status,
      };
    });

    const names = [...new Set(items.map(function (item) { return item.name; }))];
    if (employee && employee !== 'All Employees') {
      items = items.filter(function (item) { return item.name === employee; });
    }
    if (statusFilter && statusFilter !== 'All Status') {
      items = items.filter(function (item) { return item.status === statusFilter; });
    }

    return ok(res, {
      date: date,
      today: today,
      timezone: policy.TIME_ZONE,
      lateAfter: policy.LATE_AFTER,
      shiftStart: policy.SHIFT_START,
      requiredHours: policy.REQUIRED_MINUTES / 60,
      employees: names,
      items: items,
      kpis: {
        present: present,
        late: late,
        stillIn: stillIn,
        absent: absent,
        onLeave: onLeave,
        total: profiles.length,
      },
    });
  } catch (error) {
    console.error('GET /hrms/tracking', error);
    return fail(res, 500, error.message);
  }
}

const ACTIVE_WINDOW_MINUTES = 15;
const GEOCODE_CACHE_TTL_MS = 24 * 60 * 60 * 1000; // 24h; rounded coords repeat a lot
const geocodeCache = new Map();

function roundCoord(value) {
  return Math.round(Number(value) * 10000) / 10000; // ~11m precision
}

async function reverseGeocode(latitude, longitude) {
  const key = roundCoord(latitude) + ',' + roundCoord(longitude);
  const cached = geocodeCache.get(key);
  if (cached && cached.expiresAt > Date.now()) {
    return cached.address;
  }

  const apiKey = process.env.GOOGLE_GEOCODING_API_KEY;
  if (!apiKey) return null;

  try {
    const url = 'https://maps.googleapis.com/maps/api/geocode/json'
      + '?latlng=' + encodeURIComponent(latitude + ',' + longitude)
      + '&key=' + apiKey;
    const response = await fetch(url);
    const data = await response.json();

    if (data.status !== 'OK' || !data.results || !data.results.length) {
      return null;
    }

    const localityResult = data.results.find(function (r) {
      return r.types.includes('sublocality') || r.types.includes('locality');
    });
    const address = (localityResult || data.results[0]).formatted_address;

    geocodeCache.set(key, { address: address, expiresAt: Date.now() + GEOCODE_CACHE_TTL_MS });
    return address;
  } catch (error) {
    console.error('Reverse geocode failed', error.message);
    return null;
  }
}

async function setStatus(req, res) {
  try {
    const employeeUserId = req.user && req.user.id;
    const status = String(req.body.status || '').toLowerCase();
    if (!employeeUserId) return fail(res, 401, 'Unauthorized');
    if (!['office', 'home', 'field'].includes(status)) {
      return fail(res, 400, "status must be 'office', 'home', or 'field'");
    }
    await db.query(
      `INSERT INTO hrms_employee_location_status (employee_user_id, status)
       VALUES (?, ?)
       ON DUPLICATE KEY UPDATE status = VALUES(status), updated_at = CURRENT_TIMESTAMP`,
      [employeeUserId, status]
    );
    return ok(res, { status: status }, 'Status updated');
  } catch (error) {
    console.error('POST /hrms/tracking/status', error);
    return fail(res, 500, error.message);
  }
}

function distanceMeters(lat1, lng1, lat2, lng2) {
  const earthRadius = 6371000;

  const toRadians = (value) => (value * Math.PI) / 180;

  const dLat = toRadians(lat2 - lat1);
  const dLng = toRadians(lng2 - lng1);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRadians(lat1)) *
      Math.cos(toRadians(lat2)) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);

  return earthRadius * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

async function detectFieldWaitingTime(employeeUserId, latitude, longitude) {
  const [sessions] = await db.query(
    `SELECT id, started_at
     FROM hrms_field_tracking_sessions
     WHERE employee_user_id = ? AND is_active = 1
     ORDER BY started_at DESC
     LIMIT 1`,
    [employeeUserId]
  );

  if (!sessions.length) return;

  const session = sessions[0];

  const [settingsRows] = await db.query(
    `SELECT field_waiting_minutes, stationary_radius_meters
     FROM hrms_tracking_settings
     WHERE id = 1`
  );

  if (!settingsRows.length) return;

  const waitingMinutes = Number(settingsRows[0].field_waiting_minutes || 60);

  const stationaryRadius = Number(
    settingsRows[0].stationary_radius_meters || 50
  );

  const [existingAlerts] = await db.query(
    `SELECT id
     FROM hrms_field_waiting_reasons
     WHERE field_session_id = ?
       AND reason IS NULL
       AND review_status = 'pending'
     LIMIT 1`,
    [session.id]
  );

  if (existingAlerts.length) return;

  const [pings] = await db.query(
    `SELECT latitude, longitude, recorded_at
     FROM hrms_location_pings
     WHERE employee_user_id = ?
       AND recorded_at >= ?
     ORDER BY recorded_at ASC`,
    [employeeUserId, session.started_at]
  );

  if (pings.length < 2) return;

  let firstStillPing = pings[pings.length - 1];

  for (let index = pings.length - 1; index >= 0; index--) {
    const ping = pings[index];

    const distance = distanceMeters(
      latitude,
      longitude,
      Number(ping.latitude),
      Number(ping.longitude)
    );

    if (distance > stationaryRadius) break;

    firstStillPing = ping;
  }

  const startedAt = new Date(firstStillPing.recorded_at);

  const elapsedMinutes = Math.floor(
    (Date.now() - startedAt.getTime()) / 60000
  );

  if (elapsedMinutes < waitingMinutes) return;

const eventKey =
  '${session.id}:${new Date(firstStillPing.recorded_at).toISOString()}';

await db.query(
  `INSERT IGNORE INTO hrms_field_waiting_reasons (
     field_session_id,
     employee_user_id,
     latitude,
     longitude,
     waiting_started_at,
     waiting_detected_at,
     waiting_minutes,
     event_key
   )
   VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP, ?, ?)`,
  [
    session.id,
    employeeUserId,
    latitude,
    longitude,
    firstStillPing.recorded_at,
    elapsedMinutes,
    eventKey,
  ]
);
}

async function ping(req, res) {
  try {
    const employeeUserId = req.user && req.user.id;
    const latitude = Number(req.body.latitude);
    const longitude = Number(req.body.longitude);
    const accuracy = req.body.accuracy != null ? Number(req.body.accuracy) : null;
    if (!employeeUserId) return fail(res, 401, 'Unauthorized');
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
      return fail(res, 400, 'latitude and longitude are required numbers');
    }
    const [result] = await db.query(
      `INSERT INTO hrms_location_pings (employee_user_id, latitude, longitude, accuracy_meters)
       VALUES (?, ?, ?, ?)`,
      [employeeUserId, latitude, longitude, accuracy]
    );
    const pingId = result.insertId;

    detectFieldWaitingTime(employeeUserId, latitude, longitude).catch(
  function (error) {
    console.error('Field waiting-time detection failed', error.message);
  }
);

    ok(res, null, 'Location recorded'); // respond right away, don't block on geocoding

    reverseGeocode(latitude, longitude).then(function (address) {
      if (!address) return;
      db.query(`UPDATE hrms_location_pings SET address = ? WHERE id = ?`, [address, pingId])
        .catch(function (e) { console.error('Address backfill failed', e.message); });
    });
  } catch (error) {
    console.error('POST /hrms/tracking/ping', error);
    return fail(res, 500, error.message);
  }
}

async function liveOverview(req, res) {
  try {
    const [profiles] = await db.query(`
      SELECT id, employee_user_id, full_name, employee_code
      FROM hrms_employee_profiles
      WHERE employment_status <> 'Inactive'
    `);
    const userIds = profiles.map(function (row) { return row.employee_user_id; }).filter(Boolean);

    const [statuses] = userIds.length
      ? await db.query(
          `SELECT employee_user_id, status FROM hrms_employee_location_status
           WHERE employee_user_id IN (?)`,
          [userIds]
        )
      : [[]];
    const statusMap = new Map();
    statuses.forEach(function (row) { statusMap.set(Number(row.employee_user_id), row.status); });

    const [latestPings] = userIds.length
      ? await db.query(
          `SELECT p.employee_user_id, p.latitude, p.longitude, p.address, p.recorded_at
           FROM hrms_location_pings p
           INNER JOIN (
             SELECT employee_user_id, MAX(recorded_at) AS max_time
             FROM hrms_location_pings
             WHERE employee_user_id IN (?)
             GROUP BY employee_user_id
           ) latest
           ON latest.employee_user_id = p.employee_user_id AND latest.max_time = p.recorded_at`,
          [userIds]
        )
      : [[]];
    const pingMap = new Map();
    latestPings.forEach(function (row) { pingMap.set(Number(row.employee_user_id), row); });

    const now = Date.now();
    let activeNow = 0;
    const counts = { office: 0, home: 0, field: 0 };

    const items = profiles.map(function (profile) {
      const uid = profile.employee_user_id ? Number(profile.employee_user_id) : null;
      const status = (uid && statusMap.get(uid)) || 'office';
      const ping = uid ? pingMap.get(uid) : null;
      counts[status] = (counts[status] || 0) + 1;

      let isActive = false;
      if (ping && ping.recorded_at) {
        const ageMinutes = (now - new Date(ping.recorded_at).getTime()) / 60000;
        isActive = ageMinutes <= ACTIVE_WINDOW_MINUTES;
      }
      if (isActive) activeNow += 1;

      return {
        employeeUserId: uid,
        name: String(profile.full_name || '').trim(),
        employeeCode: profile.employee_code,
        status: status,
        latitude: ping ? Number(ping.latitude) : null,
        longitude: ping ? Number(ping.longitude) : null,
        address: ping ? ping.address : null,
        lastUpdated: ping ? ping.recorded_at : null,
        active: isActive,
      };
    });

    return ok(res, {
      counts: {
        office: counts.office || 0,
        home: counts.home || 0,
        field: counts.field || 0,
        activeNow: activeNow,
      },
      items: items,
    });
  } catch (error) {
    console.error('GET /hrms/tracking/live', error);
    return fail(res, 500, error.message);
  }
}

async function routeHistory(req, res) {
  try {
    const employeeUserId = Number(req.params.employeeUserId);
    const date = String(req.query.date || policy.todayIstDate()).slice(0, 10);
    if (!employeeUserId) return fail(res, 400, 'Valid employeeUserId is required');
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) return fail(res, 400, 'date must be YYYY-MM-DD');

    const [pings] = await db.query(
      `SELECT latitude, longitude, address, recorded_at
       FROM hrms_location_pings
       WHERE employee_user_id = ? AND DATE(recorded_at) = ?
       ORDER BY recorded_at ASC`,
      [employeeUserId, date]
    );

    return ok(res, {
      employeeUserId: employeeUserId,
      date: date,
      points: pings.map(function (row) {
        return {
          latitude: Number(row.latitude),
          longitude: Number(row.longitude),
          address: row.address,
          recordedAt: row.recorded_at,
        };
      }),
    });
  } catch (error) {
    console.error('GET /hrms/tracking/route/:employeeUserId', error);
    return fail(res, 500, error.message);
  }
}
async function getTrackingSettings(req, res) {
  try {
    const [rows] = await db.query(
      'SELECT * FROM hrms_tracking_settings WHERE id = 1'
    );

    if (!rows.length) {
      return fail(res, 404, 'Tracking settings not found');
    }

    return ok(res, rows[0]);
  } catch (error) {
    console.error('GET /hrms/tracking/settings', error);
    return fail(res, 500, error.message);
  }
}

async function updateTrackingSettings(req, res) {
  try {
    const [rows] = await db.query(
      'SELECT * FROM hrms_tracking_settings WHERE id = 1'
    );

    if (!rows.length) {
      return fail(res, 404, 'Tracking settings not found');
    }

    const current = rows[0];

    const officeName =
        String(req.body.officeName ?? current.office_name).trim();

    const officeAddress =
        String(req.body.officeAddress ?? current.office_address).trim();

    const officeLatitude =
        Number(req.body.officeLatitude ?? current.office_latitude);

    const officeLongitude =
        Number(req.body.officeLongitude ?? current.office_longitude);

    const officeRadiusMeters =
        Number(req.body.officeRadiusMeters ?? current.office_radius_meters);

    const fieldPingIntervalMinutes =
        Number(req.body.fieldPingIntervalMinutes ??
            current.field_ping_interval_minutes);

    const fieldWaitingMinutes =
        Number(req.body.fieldWaitingMinutes ??
            current.field_waiting_minutes);

    const stationaryRadiusMeters =
        Number(req.body.stationaryRadiusMeters ??
            current.stationary_radius_meters);

    if (
      !officeName ||
      !officeAddress ||
      !Number.isFinite(officeLatitude) ||
      !Number.isFinite(officeLongitude) ||
      officeRadiusMeters < 1 ||
      fieldPingIntervalMinutes < 1 ||
      fieldWaitingMinutes < 1 ||
      stationaryRadiusMeters < 1
    ) {
      return fail(res, 400, 'Invalid tracking settings');
    }

    await db.query(
      `UPDATE hrms_tracking_settings
       SET office_name = ?,
           office_address = ?,
           office_latitude = ?,
           office_longitude = ?,
           office_radius_meters = ?,
           field_ping_interval_minutes = ?,
           field_waiting_minutes = ?,
           stationary_radius_meters = ?,
           updated_by = ?
       WHERE id = 1`,
      [
        officeName,
        officeAddress,
        officeLatitude,
        officeLongitude,
        officeRadiusMeters,
        fieldPingIntervalMinutes,
        fieldWaitingMinutes,
        stationaryRadiusMeters,
        req.user.id,
      ]
    );

    return getTrackingSettings(req, res);
  } catch (error) {
    console.error('PUT /hrms/tracking/settings', error);
    return fail(res, 500, error.message);
  }
}

async function getMyHomeLocation(req, res) {
  try {
    const employeeUserId = req.user && req.user.id;

    if (!employeeUserId) {
      return fail(res, 401, 'Unauthorized');
    }

    const [rows] = await db.query(
      `SELECT employee_user_id, latitude, longitude, address,
              approval_status, submitted_at, reviewed_at, rejection_reason
       FROM hrms_employee_home_locations
       WHERE employee_user_id = ?`,
      [employeeUserId]
    );

    return ok(res, rows[0] || null);
  } catch (error) {
    console.error('GET /hrms/tracking/home-location', error);
    return fail(res, 500, error.message);
  }
}

async function submitHomeLocation(req, res) {
  let connection;
  try {
    const employeeUserId = req.user && req.user.id;
    const body = req.body || {};
    const address = typeof body.address === 'string' ? body.address.trim() : '';

    if (!employeeUserId) {
      return fail(res, 401, 'Unauthorized');
    }

    if (address.length > 500) return fail(res, 400, 'Home address must be 500 characters or fewer.');
    connection = await db.getConnection();
    await connection.beginTransaction();
    await locationPolicy.profileFor(connection, employeeUserId, true);
    const settings = await locationPolicy.settingsFor(connection, true);
    const fix = locationPolicy.validateFix(body, settings.radiusMeters);

    await connection.query(
      `INSERT INTO hrms_employee_home_locations
        (employee_user_id, latitude, longitude, address, approval_status)
       VALUES (?, ?, ?, ?, 'pending')
       ON DUPLICATE KEY UPDATE
         latitude = VALUES(latitude),
         longitude = VALUES(longitude),
         address = VALUES(address),
         approval_status = 'pending',
         reviewed_by = NULL,
         reviewed_at = NULL,
         rejection_reason = NULL,
         submitted_at = CURRENT_TIMESTAMP,
         updated_at = CURRENT_TIMESTAMP`,
      [employeeUserId, fix.latitude, fix.longitude, address || null]
    );
    await connection.commit();
    return ok(res, null, 'Home location submitted for admin approval');
  } catch (error) {
    if (connection) await connection.rollback();
    if (error instanceof locationPolicy.LocationPolicyError) return fail(res, error.status, error.message);
    console.error('POST /hrms/tracking/home-location', error);
    return fail(res, 500, 'Unable to submit Home location. Please try again.');
  } finally {
    if (connection) connection.release();
  }
}

async function listHomeLocations(req, res) {
  try {
    if (String(req.user && req.user.userType || '').toLowerCase() !== 'admin') {
      return fail(res, 403, 'Admin access required');
    }
    const [rows] = await db.query(`
      SELECT h.employee_user_id, h.latitude, h.longitude, h.address,
             h.approval_status, h.submitted_at, h.reviewed_at,
             h.rejection_reason, p.full_name, p.employee_code
      FROM hrms_employee_home_locations h
      LEFT JOIN hrms_employee_profiles p
        ON p.employee_user_id = h.employee_user_id
      ORDER BY
        CASE h.approval_status
          WHEN 'pending' THEN 1
          WHEN 'approved' THEN 2
          ELSE 3
        END,
        h.submitted_at DESC
    `);

    return ok(res, { items: rows });
  } catch (error) {
    console.error('GET /hrms/tracking/home-locations', error);
    return fail(res, 500, error.message);
  }
}

async function reviewHomeLocation(req, res) {
  let connection;
  try {
    if (String(req.user && req.user.userType || '').toLowerCase() !== 'admin') {
      return fail(res, 403, 'Admin access required');
    }
    const employeeUserId = Number(req.params.employeeUserId);
    const body = req.body || {};
    const approvalStatus = String(body.approvalStatus || '').toLowerCase();
    const rejectionReason = typeof body.rejectionReason === 'string' ? body.rejectionReason.trim() : '';

    if (!Number.isSafeInteger(employeeUserId) || employeeUserId < 1) {
      return fail(res, 400, 'Valid employee ID is required');
    }

    if (!['approved', 'rejected'].includes(approvalStatus)) {
      return fail(res, 400, 'approvalStatus must be approved or rejected');
    }
    if (rejectionReason.length > 500) return fail(res, 400, 'Rejection reason must be 500 characters or fewer.');
    if (approvalStatus === 'rejected' && !rejectionReason) {
      return fail(res, 400, 'Enter a reason for rejecting the Home location.');
    }
    const reviewedCoordinates = locationPolicy.coordinates(body.latitude, body.longitude);
    connection = await db.getConnection();
    await connection.beginTransaction();
    const profile = await locationPolicy.profileFor(connection, employeeUserId, true);
    const [homes] = await connection.query(
      `SELECT latitude, longitude, approval_status FROM hrms_employee_home_locations
       WHERE employee_user_id = ? FOR UPDATE`, [employeeUserId]);
    if (homes.length !== 1) {
      throw new locationPolicy.LocationPolicyError(404, 'Home location request not found.');
    }
    if (homes[0].approval_status !== 'pending') {
      throw new locationPolicy.LocationPolicyError(409, 'This Home location request was already reviewed. Refresh the list.');
    }
    if (Number(homes[0].latitude) !== reviewedCoordinates.latitude ||
        Number(homes[0].longitude) !== reviewedCoordinates.longitude) {
      throw new locationPolicy.LocationPolicyError(409, 'The employee submitted a different Home location. Refresh and review the new request.');
    }
    await connection.query(
      `UPDATE hrms_employee_home_locations
       SET approval_status = ?,
           reviewed_by = ?,
           reviewed_at = CURRENT_TIMESTAMP,
           rejection_reason = ?
       WHERE employee_user_id = ? AND approval_status = 'pending'`,
      [
        approvalStatus,
        req.user.id,
        approvalStatus === 'rejected' ? rejectionReason || null : null,
        employeeUserId,
      ]
    );
    if (approvalStatus === 'approved') {
      await connection.query(
        "UPDATE hrms_employee_profiles SET work_mode = 'Home' WHERE id = ?", [profile.id]);
    }
    await connection.commit();
    return ok(res, null, approvalStatus === 'approved'
      ? 'Home location approved. Employee work mode is now Home.'
      : 'Home location rejected');
  } catch (error) {
    if (connection) await connection.rollback();
    if (error instanceof locationPolicy.LocationPolicyError) return fail(res, error.status, error.message);
    console.error('PATCH /hrms/tracking/home-locations/:employeeUserId', error);
    return fail(res, 500, 'Unable to review Home location. Please try again.');
  } finally {
    if (connection) connection.release();
  }
}

async function getMyFieldSession(req, res) {
  try {
    const employeeUserId = req.user && req.user.id;

    if (!employeeUserId) {
      return fail(res, 401, 'Unauthorized');
    }

    const [rows] = await db.query(
      `SELECT *
       FROM hrms_field_tracking_sessions
       WHERE employee_user_id = ? AND is_active = 1
       ORDER BY started_at DESC
       LIMIT 1`,
      [employeeUserId]
    );

    return ok(res, rows[0] || { isActive: false });
  } catch (error) {
    console.error('GET /hrms/tracking/field-session', error);
    return fail(res, 500, error.message);
  }
}

async function startFieldTracking(req, res) {
  try {
    const employeeUserId = req.user && req.user.id;
    const latitude = Number(req.body.latitude);
    const longitude = Number(req.body.longitude);
    const accuracy =
        req.body.accuracy != null ? Number(req.body.accuracy) : null;

    if (!employeeUserId) {
      return fail(res, 401, 'Unauthorized');
    }

    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
      return fail(res, 400, 'Valid latitude and longitude are required');
    }

    const [profiles] = await db.query(
      `SELECT work_mode
       FROM hrms_employee_profiles
       WHERE employee_user_id = ?`,
      [employeeUserId]
    );

    if (!profiles.length || profiles[0].work_mode !== 'Field') {
      return fail(res, 403, 'Field live tracking is only available for Field employees');
    }

    const [activeSessions] = await db.query(
      `SELECT id
       FROM hrms_field_tracking_sessions
       WHERE employee_user_id = ? AND is_active = 1
       LIMIT 1`,
      [employeeUserId]
    );

    if (activeSessions.length) {
      return ok(
        res,
        { sessionId: activeSessions[0].id, isActive: true },
        'Live tracking is already active'
      );
    }

    const [session] = await db.query(
      `INSERT INTO hrms_field_tracking_sessions
        (employee_user_id, start_latitude, start_longitude)
       VALUES (?, ?, ?)`,
      [employeeUserId, latitude, longitude]
    );

    await db.query(
      `INSERT INTO hrms_location_pings
        (employee_user_id, latitude, longitude, accuracy_meters)
       VALUES (?, ?, ?, ?)`,
      [employeeUserId, latitude, longitude, accuracy]
    );

    await db.query(
      `INSERT INTO hrms_employee_location_status (employee_user_id, status)
       VALUES (?, 'field')
       ON DUPLICATE KEY UPDATE
         status = 'field',
         updated_at = CURRENT_TIMESTAMP`,
      [employeeUserId]
    );

    return ok(
      res,
      { sessionId: session.insertId, isActive: true },
      'Field live tracking started'
    );
  } catch (error) {
    console.error('POST /hrms/tracking/field-session/start', error);
    return fail(res, 500, error.message);
  }
}

async function stopFieldTracking(req, res) {
  try {
    const employeeUserId = req.user && req.user.id;
    const latitude =
        req.body.latitude != null ? Number(req.body.latitude) : null;
    const longitude =
        req.body.longitude != null ? Number(req.body.longitude) : null;
    const accuracy =
        req.body.accuracy != null ? Number(req.body.accuracy) : null;

    if (!employeeUserId) {
      return fail(res, 401, 'Unauthorized');
    }

    const [activeSessions] = await db.query(
      `SELECT id
       FROM hrms_field_tracking_sessions
       WHERE employee_user_id = ? AND is_active = 1
       ORDER BY started_at DESC
       LIMIT 1`,
      [employeeUserId]
    );

    if (!activeSessions.length) {
      return ok(res, { isActive: false }, 'No active field tracking session');
    }

    const sessionId = activeSessions[0].id;

    await db.query(
      `UPDATE hrms_field_tracking_sessions
       SET is_active = 0,
           stopped_at = CURRENT_TIMESTAMP,
           stop_latitude = ?,
           stop_longitude = ?
       WHERE id = ?`,
      [
        Number.isFinite(latitude) ? latitude : null,
        Number.isFinite(longitude) ? longitude : null,
        sessionId,
      ]
    );

    if (Number.isFinite(latitude) && Number.isFinite(longitude)) {
      await db.query(
        `INSERT INTO hrms_location_pings
          (employee_user_id, latitude, longitude, accuracy_meters)
         VALUES (?, ?, ?, ?)`,
        [employeeUserId, latitude, longitude, accuracy]
      );
    }

    return ok(
      res,
      { sessionId: sessionId, isActive: false },
      'Field live tracking stopped'
    );
  } catch (error) {
    console.error('POST /hrms/tracking/field-session/stop', error);
    return fail(res, 500, error.message);
  }
}
async function getMyWaitingAlert(req, res) {
  try {
    const employeeUserId = req.user && req.user.id;

    const [rows] = await db.query(
      `SELECT id, waiting_minutes, waiting_started_at, waiting_detected_at
       FROM hrms_field_waiting_reasons
       WHERE employee_user_id = ?
         AND reason IS NULL
         AND review_status = 'pending'
       ORDER BY waiting_detected_at DESC
       LIMIT 1`,
      [employeeUserId]
    );

    return ok(res, rows[0] || null);
  } catch (error) {
    return fail(res, 500, error.message);
  }
}

async function submitWaitingReason(req, res) {
  try {
    const employeeUserId = req.user && req.user.id;
    const reasonId = Number(req.params.id);
    const reason = String(req.body.reason || '').trim();

    if (!reasonId || !reason) {
      return fail(res, 400, 'Waiting reason is required');
    }

    const [result] = await db.query(
      `UPDATE hrms_field_waiting_reasons
       SET reason = ?,
           reason_submitted_at = CURRENT_TIMESTAMP
       WHERE id = ?
         AND employee_user_id = ?
         AND reason IS NULL`,
      [reason, reasonId, employeeUserId]
    );

    if (!result.affectedRows) {
      return fail(res, 404, 'Waiting alert not found');
    }

    return ok(res, null, 'Waiting reason submitted');
  } catch (error) {
    return fail(res, 500, error.message);
  }
}

async function listFieldWaitingReasons(req, res) {
  try {
    const [rows] = await db.query(`
      SELECT w.*,
             p.full_name,
             p.employee_code
      FROM hrms_field_waiting_reasons w
      LEFT JOIN hrms_employee_profiles p
        ON p.employee_user_id = w.employee_user_id
      ORDER BY w.waiting_detected_at DESC
      LIMIT 100
    `);

    return ok(res, { items: rows });
  } catch (error) {
    return fail(res, 500, error.message);
  }
}

async function reviewFieldWaitingReason(req, res) {
  try {
    const reasonId = Number(req.params.id);

    if (!reasonId) {
      return fail(res, 400, 'Valid waiting reason ID is required');
    }

    const [result] = await db.query(
      `UPDATE hrms_field_waiting_reasons
       SET review_status = 'reviewed',
           reviewed_by = ?,
           reviewed_at = CURRENT_TIMESTAMP
       WHERE id = ?`,
      [req.user.id, reasonId]
    );

    if (!result.affectedRows) {
      return fail(res, 404, 'Waiting reason not found');
    }

    return ok(res, null, 'Waiting reason reviewed');
  } catch (error) {
    return fail(res, 500, error.message);
  }
}



module.exports = {
  requireAdmin,
  list,
  setStatus,
  ping,
  liveOverview,
  routeHistory,
  getTrackingSettings,
  updateTrackingSettings,
  getMyHomeLocation,
  submitHomeLocation,
  listHomeLocations,
  reviewHomeLocation,
  getMyFieldSession,
startFieldTracking,
stopFieldTracking,
getMyWaitingAlert,
submitWaitingReason,
listFieldWaitingReasons,
reviewFieldWaitingReason,
};
