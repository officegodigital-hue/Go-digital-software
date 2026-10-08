const db = require('../config/db');
const policy = require('../lib/attendancePolicy');
const locationPolicy = require('../lib/attendanceLocationPolicy');
const { locationQuality, historyPoint } = require('../lib/trackingQuality');

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

async function homeTrackingIsEnabled() {
  const [rows] = await db.query('SELECT home_tracking_enabled FROM hrms_tracking_settings WHERE id = 1');
  return !rows.length || Number(rows[0].home_tracking_enabled) !== 0;
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
      const markedAbsent = Boolean(record && record.attendance_status === 'absent');
      let status = 'Absent';
      let minutes = Number((record && record.working_minutes) || 0);

      if (isFuture) {
        status = 'Upcoming';
      } else if (isSunday) {
        status = 'Weekly off';
      } else if (checkIn) {
        // Employee physically attended — determine correct status
        const effectivelyLate = isLate || markedAbsent; // absent threshold = very late
        if (checkOut) {
          status = effectivelyLate ? 'Late · out' : 'Checked out';
          present += 1;
          if (effectivelyLate) late += 1;
        } else {
          status = effectivelyLate ? 'Late · in' : 'In';
          minutes = minutesFromCheckIn(checkIn);
          present += 1;
          stillIn += 1;
          if (effectivelyLate) late += 1;
        }
      } else if (markedAbsent) {
        status = 'Absent';
        absent += 1;
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
      absentAfter: policy.ABSENT_AFTER,
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
const MAX_TRACKING_ACCURACY_METERS = 200;
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

  const apiKey = process.env.GOOGLE_GEOCODING_API_KEY ||
    process.env.GOOGLE_ROADS_API_KEY;
  if (!apiKey) return null;

  try {
    const url = 'https://maps.googleapis.com/maps/api/geocode/json'
      + '?latlng=' + encodeURIComponent(latitude + ',' + longitude)
      + '&key=' + apiKey;
    const response = await fetch(url, { signal: AbortSignal.timeout(4000) });
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
    if (!['office', 'home', 'hybrid'].includes(status)) {
      return fail(res, 400, "status must be 'office', 'home', or 'hybrid'");
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

function routePoint(row) {
  return { latitude: Number(row.latitude), longitude: Number(row.longitude) };
}

function rawDistanceMeters(points) {
  return points.slice(1).reduce(function (total, point, index) {
    const previous = points[index];
    return total + distanceMeters(previous.latitude, previous.longitude, point.latitude, point.longitude);
  }, 0);
}

// Google returns an encoded polyline. Decoding it here keeps the API key in
// the backend and allows Flutter to draw the exact same route on every device.
function decodePolyline(encoded) {
  const points = [];
  let index = 0; let lat = 0; let lng = 0;
  while (index < encoded.length) {
    let result = 1; let shift = 0; let byte;
    do { byte = encoded.charCodeAt(index++) - 63 - 1; result += byte << shift; shift += 5; } while (byte >= 0x1f);
    lat += result & 1 ? ~(result >> 1) : result >> 1;
    result = 1; shift = 0;
    do { byte = encoded.charCodeAt(index++) - 63 - 1; result += byte << shift; shift += 5; } while (byte >= 0x1f);
    lng += result & 1 ? ~(result >> 1) : result >> 1;
    points.push({ latitude: lat / 1e5, longitude: lng / 1e5 });
  }
  return points;
}

async function routeViaRoutesApi(points) {
  const apiKey = process.env.GOOGLE_ROUTES_API_KEY || process.env.GOOGLE_ROADS_API_KEY;
  if (!apiKey || points.length < 2) return null;
  const all = []; let meters = 0; let seconds = 0;
  // Routes API supports limited intermediates; groups overlap by one point so
  // the complete journey remains connected.
  for (let start = 0; start < points.length - 1; start += 24) {
    const group = points.slice(start, Math.min(start + 25, points.length));
    const body = {
      origin: { location: { latLng: { latitude: group[0].latitude, longitude: group[0].longitude } } },
      destination: { location: { latLng: { latitude: group[group.length - 1].latitude, longitude: group[group.length - 1].longitude } } },
      intermediates: group.slice(1, -1).map(function (point) { return { location: { latLng: { latitude: point.latitude, longitude: point.longitude } } }; }),
      travelMode: 'DRIVE',
      routingPreference: 'TRAFFIC_UNAWARE',
      polylineQuality: 'HIGH_QUALITY',
    };
    const response = await fetch('https://routes.googleapis.com/directions/v2:computeRoutes', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-Goog-Api-Key': apiKey, 'X-Goog-FieldMask': 'routes.distanceMeters,routes.duration,routes.polyline.encodedPolyline' },
      body: JSON.stringify(body),
    });
    if (!response.ok) return null;
    const data = await response.json(); const route = data.routes && data.routes[0];
    if (!route || !route.polyline || !route.polyline.encodedPolyline) return null;
    const decoded = decodePolyline(route.polyline.encodedPolyline);
    all.push.apply(all, all.length ? decoded.slice(1) : decoded);
    meters += Number(route.distanceMeters || 0);
    seconds += Number(String(route.duration || '0s').replace('s', '')) || 0;
  }
  return all.length ? { source: 'routes', points: all, distanceMeters: meters, durationSeconds: seconds } : null;
}

async function routeViaRoadsApi(points) {
  const apiKey = process.env.GOOGLE_ROADS_API_KEY;
  if (!apiKey || points.length < 2) return null;
  const all = [];
  for (let start = 0; start < points.length - 1; start += 95) {
    const group = points.slice(start, Math.min(start + 100, points.length));
    const path = group.map(function (p) { return p.latitude + ',' + p.longitude; }).join('|');
    const response = await fetch('https://roads.googleapis.com/v1/snapToRoads?interpolate=true&path=' + encodeURIComponent(path) + '&key=' + encodeURIComponent(apiKey));
    if (!response.ok) return null;
    const data = await response.json();
    const snapped = (data.snappedPoints || []).map(function (p) { return { latitude: Number(p.location.latitude), longitude: Number(p.location.longitude) }; });
    all.push.apply(all, all.length ? snapped.slice(1) : snapped);
  }
  return all.length ? { source: 'roads', points: all, distanceMeters: rawDistanceMeters(all), durationSeconds: 0 } : null;
}

async function buildRoute(employeeUserId, date, pingRows, bypassCache = false) {
  if (!pingRows.length) {
    return { source: 'raw', points: [], distanceMeters: 0, durationSeconds: 0, averageSpeedKmh: 0, lastUpdated: null };
  }
  const lastPing = pingRows.length ? pingRows[pingRows.length - 1].recorded_at : null;
  const [cacheRows] = await db.query('SELECT * FROM hrms_tracking_route_cache WHERE employee_user_id = ? AND route_date = ?', [employeeUserId, date]);
  const cached = cacheRows[0];
  if (!bypassCache && cached && String(cached.last_ping_at || '') === String(lastPing || '')) {
    return { source: cached.source, points: JSON.parse(cached.route_points_json), distanceMeters: Number(cached.distance_meters), durationSeconds: Number(cached.duration_seconds), averageSpeedKmh: Number(cached.average_speed_kmh), lastUpdated: lastPing };
  }
  const raw = pingRows.map(routePoint);
  let built = await routeViaRoutesApi(raw).catch(function () { return null; });
  if (!built) built = await routeViaRoadsApi(raw).catch(function () { return null; });
  if (!built) built = { source: 'raw', points: raw, distanceMeters: rawDistanceMeters(raw), durationSeconds: 0 };
  if (!built.durationSeconds && pingRows.length > 1) built.durationSeconds = Math.max(0, Math.round((new Date(lastPing).getTime() - new Date(pingRows[0].recorded_at).getTime()) / 1000));
  const averageSpeedKmh = built.durationSeconds ? (built.distanceMeters / 1000) / (built.durationSeconds / 3600) : 0;
  await db.query(`INSERT INTO hrms_tracking_route_cache (employee_user_id, route_date, source, route_points_json, distance_meters, duration_seconds, average_speed_kmh, last_ping_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ON DUPLICATE KEY UPDATE source=VALUES(source), route_points_json=VALUES(route_points_json), distance_meters=VALUES(distance_meters), duration_seconds=VALUES(duration_seconds), average_speed_kmh=VALUES(average_speed_kmh), last_ping_at=VALUES(last_ping_at)`, [employeeUserId, date, built.source, JSON.stringify(built.points), built.distanceMeters, built.durationSeconds, averageSpeedKmh, lastPing]);
  return Object.assign(built, { averageSpeedKmh: averageSpeedKmh, lastUpdated: lastPing });
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
       AND accuracy_meters IS NOT NULL
       AND accuracy_meters <= ${MAX_TRACKING_ACCURACY_METERS}
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
  `${session.id}:${new Date(firstStillPing.recorded_at).toISOString()}`;

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
    const body = req.body || {};
    const address = typeof body.address === 'string'
      ? body.address.trim().slice(0, 255) : '';
    if (!employeeUserId) return fail(res, 401, 'Unauthorized');
    const fix = locationPolicy.validateFix(body, MAX_TRACKING_ACCURACY_METERS);
    const [result] = await db.query(
      `INSERT INTO hrms_location_pings
        (employee_user_id, latitude, longitude, accuracy_meters, address)
       VALUES (?, ?, ?, ?, ?)`,
      [employeeUserId, fix.latitude, fix.longitude, fix.accuracy, address || null]
    );
    const pingId = result.insertId;

    detectFieldWaitingTime(employeeUserId, fix.latitude, fix.longitude).catch(
  function (error) {
    console.error('Field waiting-time detection failed', error.message);
  }
);

    ok(res, null, 'Location recorded'); // respond right away, don't block on geocoding

    if (!address) {
      reverseGeocode(fix.latitude, fix.longitude).then(function (resolvedAddress) {
        if (!resolvedAddress) return;
        db.query(`UPDATE hrms_location_pings SET address = ? WHERE id = ?`, [resolvedAddress, pingId])
          .catch(function (e) { console.error('Address backfill failed', e.message); });
      });
    }
  } catch (error) {
    console.error('POST /hrms/tracking/ping', error);
    if (error instanceof locationPolicy.LocationPolicyError) {
      return fail(res, error.status, error.message);
    }
    return fail(res, 500, error.message);
  }
}

async function liveOverview(req, res) {
  try {
    const date = String(req.query.date || policy.todayIstDate()).slice(0, 10);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
      return fail(res, 400, 'date must be YYYY-MM-DD');
    }
    const [profiles] = await db.query(`
      SELECT id, employee_user_id, full_name, employee_code, work_mode
      FROM hrms_employee_profiles
      WHERE employment_status <> 'Inactive'
      ORDER BY full_name ASC
    `);
    const userIds = profiles.map(function (row) { return row.employee_user_id; }).filter(Boolean);

    const [[settings]] = await db.query(`
      SELECT office_latitude, office_longitude, office_radius_meters,
             home_radius_meters
      FROM hrms_tracking_settings WHERE id = 1
    `);

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
          `SELECT p.employee_user_id, p.latitude, p.longitude,
                  p.accuracy_meters, p.address, p.recorded_at
           FROM hrms_location_pings p
           INNER JOIN (
             SELECT employee_user_id, MAX(id) AS latest_id
             FROM hrms_location_pings
             WHERE employee_user_id IN (?)
               AND DATE(recorded_at) = ?
             GROUP BY employee_user_id
           ) latest
           ON latest.employee_user_id = p.employee_user_id AND latest.latest_id = p.id`,
          [userIds, date]
        )
      : [[]];
    const pingMap = new Map();
    latestPings.forEach(function (row) { pingMap.set(Number(row.employee_user_id), row); });

    const [attendance] = userIds.length
      ? await db.query(
          `SELECT id, employee_id,
                  DATE_FORMAT(attendance_date, '%Y-%m-%d') AS attendance_date,
                  check_in_at, check_out_at, is_late, attendance_status,
                  session_status, check_in_method, working_minutes
           FROM attendance_records
           WHERE attendance_date = ? AND employee_id IN (?)`,
          [date, userIds]
        )
      : [[]];
    const attendanceMap = new Map();
    attendance.forEach(function (row) {
      attendanceMap.set(Number(row.employee_id), row);
    });

    const attendanceIds = attendance.map(function (row) { return row.id; }).filter(Boolean);
    const [activeBreaks] = attendanceIds.length
      ? await db.query(
          `SELECT attendance_id FROM attendance_breaks
           WHERE attendance_id IN (?) AND status = 'active'`,
          [attendanceIds]
        )
      : [[]];
    const activeBreakIds = new Set(activeBreaks.map(function (row) {
      return Number(row.attendance_id);
    }));

    const [recentAttendance] = userIds.length
      ? await db.query(
          `SELECT ar.employee_id,
                  DATE_FORMAT(ar.attendance_date, '%Y-%m-%d') AS attendance_date,
                  ar.check_in_at, ar.is_late, ar.attendance_status,
                  p.latitude AS check_in_lat, p.longitude AS check_in_lng
           FROM attendance_records ar
           LEFT JOIN hrms_location_pings p
             ON p.employee_user_id = ar.employee_id
             AND p.recorded_at >= ar.check_in_at
             AND p.recorded_at <= DATE_ADD(ar.check_in_at, INTERVAL 10 MINUTE)
             AND p.accuracy_meters IS NOT NULL
             AND p.accuracy_meters <= ${MAX_TRACKING_ACCURACY_METERS}
           WHERE ar.employee_id IN (?) AND ar.attendance_date <= ?
           ORDER BY ar.attendance_date DESC, ar.check_in_at DESC, p.recorded_at ASC`,
          [userIds, date]
        )
      : [[]];
    const recentMap = new Map();
    recentAttendance.forEach(function (row) {
      const employeeId = Number(row.employee_id);
      const items = recentMap.get(employeeId) || [];
      // one entry per date — use first row (earliest ping after check-in)
      const existingIdx = items.findIndex(function (i) { return i.date === row.attendance_date; });
      if (existingIdx === -1 && items.length < 4) {
        items.push({
          date: row.attendance_date,
          checkInAt: row.check_in_at,
          isLate: Boolean(Number(row.is_late)),
          status: row.attendance_status,
          checkInLat: row.check_in_lat != null ? Number(row.check_in_lat) : null,
          checkInLng: row.check_in_lng != null ? Number(row.check_in_lng) : null,
        });
        recentMap.set(employeeId, items);
      }
    });

    const [homeLocations] = userIds.length
      ? await db.query(
          `SELECT employee_user_id, latitude, longitude, address,
                  approval_status
           FROM hrms_employee_home_locations
           WHERE employee_user_id IN (?) AND approval_status = 'approved'`,
          [userIds]
        )
      : [[]];
    const homeMap = new Map();
    homeLocations.forEach(function (row) {
      homeMap.set(Number(row.employee_user_id), row);
    });

    const now = Date.now();
    let activeNow = 0;
    const counts = { office: 0, home: 0, hybrid: 0 };

    const items = profiles.map(function (profile) {
      const uid = profile.employee_user_id ? Number(profile.employee_user_id) : null;
      const profileMode = String(profile.work_mode || 'Office').toLowerCase();
      const rawStatus = (uid && statusMap.get(uid)) || profileMode || 'office';
      const status = rawStatus === 'field' ? 'hybrid' : rawStatus;
      const ping = uid ? pingMap.get(uid) : null;
      const quality = ping ? locationQuality(ping) : null;
      const usablePing = quality === 'usable' ? ping : null;
      const record = uid ? attendanceMap.get(uid) : null;
      const home = uid ? homeMap.get(uid) : null;
      counts[status] = (counts[status] || 0) + 1;

      let isActive = false;
      if (usablePing && ping.recorded_at) {
        const ageMinutes = (now - new Date(ping.recorded_at).getTime()) / 60000;
        isActive = ageMinutes >= 0 && ageMinutes <= ACTIVE_WINDOW_MINUTES;
      }
      if (isActive) activeNow += 1;

      const officeDistance = usablePing && settings
        ? Math.round(distanceMeters(
            Number(ping.latitude), Number(ping.longitude),
            Number(settings.office_latitude), Number(settings.office_longitude)))
        : null;
      const homeDistance = usablePing && home
        ? Math.round(distanceMeters(
            Number(ping.latitude), Number(ping.longitude),
            Number(home.latitude), Number(home.longitude)))
        : null;

      return {
        employeeUserId: uid,
        name: String(profile.full_name || '').trim(),
        employeeCode: profile.employee_code,
        status: status,
        latitude: usablePing ? Number(ping.latitude) : null,
        longitude: usablePing ? Number(ping.longitude) : null,
        locationQuality: quality,
        accuracyMeters: ping && ping.accuracy_meters != null
          ? Number(ping.accuracy_meters) : null,
        address: ping ? ping.address : null,
        lastUpdated: ping ? ping.recorded_at : null,
        active: isActive,
        attendanceDate: date,
        checkInAt: record ? record.check_in_at : null,
        checkOutAt: record ? record.check_out_at : null,
        isLate: Boolean(record && Number(record.is_late)),
        attendanceStatus: record ? record.attendance_status : null,
        sessionStatus: record ? record.session_status : null,
        checkInMethod: record ? record.check_in_method : null,
        workingMinutes: Number((record && record.working_minutes) || 0),
        onBreak: Boolean(record && activeBreakIds.has(Number(record.id))),
        officeDistanceMeters: officeDistance,
        officeRadiusMeters: Number((settings && settings.office_radius_meters) || 0),
        homeDistanceMeters: homeDistance,
        homeRadiusMeters: Number((settings && settings.home_radius_meters) || 0),
        homeAddress: home ? home.address : null,
        homeApprovalStatus: home ? home.approval_status : null,
        homeLatitude: home ? Number(home.latitude) : null,
        homeLongitude: home ? Number(home.longitude) : null,
        recentAttendance: uid ? (recentMap.get(uid) || []) : [],
      };
    });

    return ok(res, {
      date: date,
      counts: {
        office: counts.office || 0,
        home: counts.home || 0,
        hybrid: counts.hybrid || 0,
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
      `SELECT id, latitude, longitude, accuracy_meters, address, recorded_at
       FROM hrms_location_pings
       WHERE employee_user_id = ? AND DATE(recorded_at) = ?
       ORDER BY recorded_at ASC, id ASC`,
      [employeeUserId, date]
    );

    await Promise.all(pings
      .filter(function (row) { return !String(row.address || '').trim(); })
      .map(async function (row) {
        const address = await reverseGeocode(Number(row.latitude), Number(row.longitude));
        if (!address) return;
        row.address = address;
        await db.query('UPDATE hrms_location_pings SET address = ? WHERE id = ?', [address, row.id]);
      }));

    // Keep every recorded fix in history, but never use poor/unknown accuracy
    // to manufacture a precise route or inflate distance calculations.
    const usablePings = pings.filter(row => locationQuality(row) === 'usable');
    const unverifiedPointCount = pings.length - usablePings.length;
    const route = await buildRoute(employeeUserId, date, usablePings, unverifiedPointCount > 0);
    const activities = pings.map(function (row) {
      return { ...historyPoint(row), placeName: row.address || 'Location name unavailable' };
    });
    return ok(res, {
      employeeUserId: employeeUserId,
      date: date,
      points: usablePings.map(historyPoint),
      recordedPoints: pings.map(historyPoint),
      totalPointCount: pings.length,
      unverifiedPointCount,
      routePoints: route.points,
      routeSource: route.source,
      distanceMeters: route.distanceMeters,
      durationSeconds: route.durationSeconds,
      averageSpeedKmh: route.averageSpeedKmh,
      lastUpdated: route.lastUpdated,
      activities: activities,
    });
  } catch (error) {
    console.error('GET /hrms/tracking/route/:employeeUserId', error);
    return fail(res, 500, error.message);
  }
}
async function myRouteHistory(req, res) {
  req.params.employeeUserId = String(req.user.id);
  return routeHistory(req, res);
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

    const homeRadiusMeters =
        Number(req.body.homeRadiusMeters ?? current.home_radius_meters);

    const fieldPingIntervalMinutes =
        Number(req.body.fieldPingIntervalMinutes ??
            current.field_ping_interval_minutes);

    const fieldWaitingMinutes =
        Number(req.body.fieldWaitingMinutes ??
            current.field_waiting_minutes);

    const stationaryRadiusMeters =
        Number(req.body.stationaryRadiusMeters ??
            current.stationary_radius_meters);

    const sharedOutsideRadiusGrace = req.body.outsideRadiusGraceMinutes;
    const officeOutsideRadiusGraceMinutes = Number(
      req.body.officeOutsideRadiusGraceMinutes ??
      sharedOutsideRadiusGrace ??
      current.office_outside_radius_grace_minutes ??
      current.outside_radius_grace_minutes
    );
    const homeOutsideRadiusGraceMinutes = Number(
      req.body.homeOutsideRadiusGraceMinutes ??
      sharedOutsideRadiusGrace ??
      current.home_outside_radius_grace_minutes ??
      current.outside_radius_grace_minutes
    );

    const homeTrackingEnabled = req.body.homeTrackingEnabled == null
      ? Number(current.home_tracking_enabled) !== 0
      : Boolean(req.body.homeTrackingEnabled);

    if (
      !officeName ||
      !officeAddress ||
      !Number.isFinite(officeLatitude) ||
      !Number.isFinite(officeLongitude) ||
      officeLatitude < -90 ||
      officeLatitude > 90 ||
      officeLongitude < -180 ||
      officeLongitude > 180 ||
      officeRadiusMeters < 1 ||
      homeRadiusMeters < 1 ||
      fieldPingIntervalMinutes < 1 ||
      fieldWaitingMinutes < 1 ||
      stationaryRadiusMeters < 1 ||
      officeOutsideRadiusGraceMinutes < 1 ||
      homeOutsideRadiusGraceMinutes < 1
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
           home_radius_meters = ?,
           field_ping_interval_minutes = ?,
           field_waiting_minutes = ?,
           stationary_radius_meters = ?,
           office_outside_radius_grace_minutes = ?,
           home_outside_radius_grace_minutes = ?,
           home_tracking_enabled = ?,
           updated_by = ?
       WHERE id = 1`,
      [
        officeName,
        officeAddress,
        officeLatitude,
        officeLongitude,
        officeRadiusMeters,
        homeRadiusMeters,
        fieldPingIntervalMinutes,
        fieldWaitingMinutes,
        stationaryRadiusMeters,
        officeOutsideRadiusGraceMinutes,
        homeOutsideRadiusGraceMinutes,
        homeTrackingEnabled ? 1 : 0,
        req.user.id,
      ]
    );

    return getTrackingSettings(req, res);
  } catch (error) {
    console.error('PUT /hrms/tracking/settings', error);
    return fail(res, 500, error.message);
  }
}

async function updateHybridSettings(req, res) {
  try {
    const [rows] = await db.query('SELECT * FROM hrms_tracking_settings WHERE id = 1');
    if (!rows.length) return fail(res, 404, 'Tracking settings not found');
    const current = rows[0];

    const fieldWaitingMinutes = req.body.fieldWaitingMinutes != null
      ? Number(req.body.fieldWaitingMinutes) : Number(current.field_waiting_minutes);
    const stationaryRadiusMeters = req.body.stationaryRadiusMeters != null
      ? Number(req.body.stationaryRadiusMeters) : Number(current.stationary_radius_meters);
    const fieldPingIntervalMinutes = req.body.fieldPingIntervalMinutes != null
      ? Number(req.body.fieldPingIntervalMinutes) : Number(current.field_ping_interval_minutes);
    const officeOutsideRadiusGraceMinutes = req.body.officeOutsideRadiusGraceMinutes != null
      ? Number(req.body.officeOutsideRadiusGraceMinutes)
      : Number(current.office_outside_radius_grace_minutes ?? current.outside_radius_grace_minutes ?? 5);

    if (!Number.isFinite(fieldWaitingMinutes) || fieldWaitingMinutes < 1 ||
        !Number.isFinite(stationaryRadiusMeters) || stationaryRadiusMeters < 1 ||
        !Number.isFinite(fieldPingIntervalMinutes) || fieldPingIntervalMinutes < 1 ||
        !Number.isFinite(officeOutsideRadiusGraceMinutes) || officeOutsideRadiusGraceMinutes < 1) {
      return fail(res, 400, 'All hybrid settings must be whole numbers greater than zero.');
    }

    await db.query(
      `UPDATE hrms_tracking_settings
       SET field_waiting_minutes = ?, stationary_radius_meters = ?,
           field_ping_interval_minutes = ?, office_outside_radius_grace_minutes = ?,
           updated_by = ?
       WHERE id = 1`,
      [fieldWaitingMinutes, stationaryRadiusMeters, fieldPingIntervalMinutes,
       officeOutsideRadiusGraceMinutes, req.user.id]
    );

    return getTrackingSettings(req, res);
  } catch (error) {
    console.error('PUT /hrms/tracking/hybrid-settings', error);
    return fail(res, 500, error.message);
  }
}

async function updateHomeSettings(req, res) {
  try {
    const [rows] = await db.query('SELECT * FROM hrms_tracking_settings WHERE id = 1');
    if (!rows.length) return fail(res, 404, 'Tracking settings not found');
    const current = rows[0];

    const homeRadiusMeters = req.body.homeRadiusMeters != null
      ? Number(req.body.homeRadiusMeters) : Number(current.home_radius_meters);
    const homeOutsideRadiusGraceMinutes = req.body.homeOutsideRadiusGraceMinutes != null
      ? Number(req.body.homeOutsideRadiusGraceMinutes)
      : Number(current.home_outside_radius_grace_minutes ?? current.outside_radius_grace_minutes ?? 5);
    const homeTrackingEnabled = req.body.homeTrackingEnabled != null
      ? Boolean(req.body.homeTrackingEnabled) : Number(current.home_tracking_enabled) !== 0;

    if (!Number.isFinite(homeRadiusMeters) || homeRadiusMeters < 1 ||
        !Number.isFinite(homeOutsideRadiusGraceMinutes) || homeOutsideRadiusGraceMinutes < 1) {
      return fail(res, 400, 'Enter a valid home radius and grace time (both at least 1).');
    }

    await db.query(
      `UPDATE hrms_tracking_settings
       SET home_radius_meters = ?, home_outside_radius_grace_minutes = ?,
           home_tracking_enabled = ?, updated_by = ?
       WHERE id = 1`,
      [homeRadiusMeters, homeOutsideRadiusGraceMinutes, homeTrackingEnabled ? 1 : 0, req.user.id]
    );

    return getTrackingSettings(req, res);
  } catch (error) {
    console.error('PUT /hrms/tracking/home-settings', error);
    return fail(res, 500, error.message);
  }
}

async function updateOfficeLocation(req, res) {
  try {
    const officeName = String(req.body.officeName ?? '').trim();
    const officeAddress = String(req.body.officeAddress ?? '').trim();
    const officeLatitude = Number(req.body.officeLatitude);
    const officeLongitude = Number(req.body.officeLongitude);
    const officeRadiusMeters = Number(req.body.officeRadiusMeters);

    if (!officeName || !officeAddress ||
        !Number.isFinite(officeLatitude) || !Number.isFinite(officeLongitude) ||
        officeLatitude < -90 || officeLatitude > 90 ||
        officeLongitude < -180 || officeLongitude > 180 ||
        officeRadiusMeters < 1 || !Number.isFinite(officeRadiusMeters)) {
      return fail(res, 400, 'Enter a valid office name, address, map pin and radius.');
    }

    await db.query(
      `UPDATE hrms_tracking_settings
       SET office_name = ?, office_address = ?, office_latitude = ?,
           office_longitude = ?, office_radius_meters = ?, updated_by = ?
       WHERE id = 1`,
      [officeName, officeAddress, officeLatitude, officeLongitude, officeRadiusMeters, req.user.id]
    );

    return getTrackingSettings(req, res);
  } catch (error) {
    console.error('PUT /hrms/tracking/office-location', error);
    return fail(res, 500, error.message);
  }
}

async function getMyHomeLocation(req, res) {
  try {
    if (!await homeTrackingIsEnabled()) return fail(res, 403, 'Home tracking is currently disabled by admin');
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
    if (!await homeTrackingIsEnabled()) return fail(res, 403, 'Home tracking is currently disabled by admin');
    const employeeUserId = req.user && req.user.id;
    const body = req.body || {};
    const address = typeof body.address === 'string' ? body.address.trim() : '';
    const captureSource = String(body.captureSource || 'gps').toLowerCase();

    if (!employeeUserId) {
      return fail(res, 401, 'Unauthorized');
    }

    if (address.length > 500) return fail(res, 400, 'Home address must be 500 characters or fewer.');
    connection = await db.getConnection();
    await connection.beginTransaction();
    await locationPolicy.profileFor(connection, employeeUserId, true);
    let fix;
    if (captureSource === 'map') {
      // A map-selected home is always reviewed by an admin before it becomes
      // usable. Clock In still requires a fresh, accurate GPS fix inside the
      // approved radius, so this fallback does not bypass attendance checks.
      const coordinates = locationPolicy.coordinates(body.latitude, body.longitude);
      const capturedAt = typeof body.capturedAt === 'string' ? Date.parse(body.capturedAt) : NaN;
      if (!Number.isFinite(capturedAt) ||
          Date.now() - capturedAt > 120000 || capturedAt - Date.now() > 30000) {
        throw new locationPolicy.LocationPolicyError(400, 'Select a fresh Home location and try again.');
      }
      fix = { ...coordinates, accuracy: null };
    } else if (captureSource === 'gps') {
      // Home registration only needs a rough GPS fix — admin reviews before
      // it becomes active. Use 1000 m so web browsers (WiFi/IP geo) are accepted.
      fix = locationPolicy.validateFix(body, 1000);
    } else {
      throw new locationPolicy.LocationPolicyError(400, 'captureSource must be gps or map.');
    }

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

    const [profiles] = await db.query('SELECT work_mode FROM hrms_employee_profiles WHERE employee_user_id = ? LIMIT 1', [employeeUserId]);
    const isHybrid = Boolean(profiles[0] && profiles[0].work_mode === 'Hybrid');
    const [rows] = await db.query(
      `SELECT *
       FROM hrms_field_tracking_sessions
       WHERE employee_user_id = ? AND is_active = 1
       ORDER BY started_at DESC
       LIMIT 1`,
      [employeeUserId]
    );

    return ok(res, Object.assign({ isActive: false, isHybrid: isHybrid }, rows[0] || {}));
  } catch (error) {
    console.error('GET /hrms/tracking/field-session', error);
    return fail(res, 500, error.message);
  }
}

async function startFieldTracking(req, res) {
  try {
    const employeeUserId = req.user && req.user.id;
    const body = req.body || {};
    const address = typeof body.address === 'string'
      ? body.address.trim().slice(0, 255) : '';

    if (!employeeUserId) {
      return fail(res, 401, 'Unauthorized');
    }

    const fix = locationPolicy.validateFix(body, MAX_TRACKING_ACCURACY_METERS);

    const [profiles] = await db.query(
      `SELECT work_mode
       FROM hrms_employee_profiles
       WHERE employee_user_id = ?`,
      [employeeUserId]
    );

    if (!profiles.length || profiles[0].work_mode !== 'Hybrid') {
      return fail(res, 403, 'Hybrid live tracking is only available for Hybrid employees');
    }

    const [activeSessions] = await db.query(
      `SELECT id
       FROM hrms_field_tracking_sessions
       WHERE employee_user_id = ? AND is_active = 1
       LIMIT 1`,
      [employeeUserId]
    );

    if (activeSessions.length) {
      await db.query(
        `UPDATE hrms_attendance_radius_departures departure
         INNER JOIN attendance_records attendance ON attendance.id = departure.attendance_id
         SET departure.status = 'cancelled', departure.last_seen_at = ?
         WHERE attendance.employee_id = ?
           AND attendance.attendance_date = ?
           AND attendance.check_out_at IS NULL
           AND departure.status = 'pending'`,
        [policy.nowIstDateTime(), employeeUserId, policy.todayIstDate()]
      );
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
      [employeeUserId, fix.latitude, fix.longitude]
    );

    await db.query(
      `INSERT INTO hrms_location_pings
        (employee_user_id, latitude, longitude, accuracy_meters, address)
       VALUES (?, ?, ?, ?, ?)`,
      [employeeUserId, fix.latitude, fix.longitude, fix.accuracy, address || null]
    );

    await db.query(
      `INSERT INTO hrms_employee_location_status (employee_user_id, status)
       VALUES (?, 'hybrid')
       ON DUPLICATE KEY UPDATE
         status = 'hybrid',
         updated_at = CURRENT_TIMESTAMP`,
      [employeeUserId]
    );

    // A Hybrid employee may begin tracking during an outside-radius grace
    // period. Cancel that pending checkout immediately rather than waiting
    // for the next GPS heartbeat.
    await db.query(
      `UPDATE hrms_attendance_radius_departures departure
       INNER JOIN attendance_records attendance ON attendance.id = departure.attendance_id
       SET departure.status = 'cancelled', departure.last_seen_at = ?
       WHERE attendance.employee_id = ?
         AND attendance.attendance_date = ?
         AND attendance.check_out_at IS NULL
         AND departure.status = 'pending'`,
      [policy.nowIstDateTime(), employeeUserId, policy.todayIstDate()]
    );

    return ok(
      res,
      { sessionId: session.insertId, isActive: true },
      'Hybrid live tracking started'
    );
  } catch (error) {
    console.error('POST /hrms/tracking/field-session/start', error);
    if (error instanceof locationPolicy.LocationPolicyError) {
      return fail(res, error.status, error.message);
    }
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
      'Hybrid live tracking stopped'
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
  myRouteHistory,
  getTrackingSettings,
  updateTrackingSettings,
  updateHybridSettings,
  updateHomeSettings,
  updateOfficeLocation,
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
