'use strict';

class LocationPolicyError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

function number(value) {
  if (typeof value !== 'number' && typeof value !== 'string') return NaN;
  if (typeof value === 'string' && !value.trim()) return NaN;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : NaN;
}

function coordinates(latitude, longitude) {
  const lat = number(latitude);
  const lng = number(longitude);
  if (!Number.isFinite(lat) || !Number.isFinite(lng) ||
      Math.abs(lat) > 90 || Math.abs(lng) > 180) {
    throw new LocationPolicyError(400, 'Valid GPS latitude and longitude are required.');
  }
  return { latitude: lat, longitude: lng };
}

function distanceMeters(a, b) {
  const radians = value => value * Math.PI / 180;
  const dLat = radians(b.latitude - a.latitude);
  const dLng = radians(b.longitude - a.longitude);
  const value = Math.sin(dLat / 2) ** 2 +
    Math.cos(radians(a.latitude)) * Math.cos(radians(b.latitude)) *
    Math.sin(dLng / 2) ** 2;
  const clamped = Math.max(0, Math.min(1, value));
  return 6371000 * 2 * Math.atan2(Math.sqrt(clamped), Math.sqrt(1 - clamped));
}

function validateFix(body, radiusMeters, now = Date.now()) {
  const fix = coordinates(body && body.latitude, body && body.longitude);
  const accuracy = number(body && body.accuracy);
  if (!Number.isFinite(accuracy) || accuracy < 0 || accuracy > radiusMeters) {
    throw new LocationPolicyError(400,
      `GPS accuracy must be ${radiusMeters} metres or better. Enable precise location and try again.`);
  }
  const capturedAt = body && body.capturedAt;
  const capturedTime = typeof capturedAt === 'string' &&
    /T.*(?:Z|[+-]\d{2}:\d{2})$/.test(capturedAt) ? Date.parse(capturedAt) : NaN;
  if (!Number.isFinite(capturedTime) || now - capturedTime > 120000 || capturedTime - now > 30000) {
    throw new LocationPolicyError(400, 'A fresh GPS location is required. Please try again.');
  }
  return { ...fix, accuracy };
}

async function profileFor(db, employeeId, lock = false) {
  if (!Number.isSafeInteger(Number(employeeId)) || Number(employeeId) < 1) {
    throw new LocationPolicyError(401, 'Unauthorized');
  }
  const [rows] = await db.query(
    `SELECT id, work_mode FROM hrms_employee_profiles
     WHERE employee_user_id = ?${lock ? ' FOR UPDATE' : ''}`, [employeeId]);
  if (rows.length !== 1) {
    throw new LocationPolicyError(403, 'An employee profile must be configured by admin before clocking in.');
  }
  const profile = rows[0];
  if (!['Office', 'Home', 'Hybrid'].includes(profile.work_mode)) {
    throw new LocationPolicyError(403, 'Employee work mode must be configured by admin.');
  }
  return profile;
}

async function settingsFor(db, lock = false) {
  const [rows] = await db.query(
    `SELECT office_latitude, office_longitude, office_radius_meters, outside_radius_grace_minutes,
            office_outside_radius_grace_minutes, home_outside_radius_grace_minutes,
            office_no_gps_timeout_minutes, home_no_gps_timeout_minutes,
            home_radius_meters, home_tracking_enabled
     FROM hrms_tracking_settings WHERE id = 1${lock ? ' FOR UPDATE' : ''}`);
  if (rows.length !== 1) {
    throw new LocationPolicyError(503, 'Office and Home location settings are unavailable. Contact admin.');
  }
  const radiusMeters = number(rows[0].office_radius_meters);
  if (!Number.isSafeInteger(radiusMeters) || radiusMeters < 1) {
    throw new LocationPolicyError(503, 'Admin must configure a valid Office/Home radius.');
  }
  const sharedGrace = number(rows[0].outside_radius_grace_minutes);
  const officeGrace = number(rows[0].office_outside_radius_grace_minutes);
  const homeGrace = number(rows[0].home_outside_radius_grace_minutes);
  const officeNoGps = number(rows[0].office_no_gps_timeout_minutes);
  const homeNoGps = number(rows[0].home_no_gps_timeout_minutes);
  const homeRadius = number(rows[0].home_radius_meters);
  return {
    ...rows[0],
    radiusMeters,
    // shared legacy field (kept for backward compat)
    outsideRadiusGraceMinutes: Number.isFinite(sharedGrace) && sharedGrace > 0 ? Number(sharedGrace) : 2,
    // per-mode grace (falls back to shared value if not set)
    officeOutsideRadiusGraceMinutes: Number.isFinite(officeGrace) && officeGrace > 0 ? Number(officeGrace) : 5,
    homeOutsideRadiusGraceMinutes: Number.isFinite(homeGrace) && homeGrace > 0 ? Number(homeGrace) : 5,
    // no-gps timeout
    officeNoGpsTimeoutMinutes: Number.isFinite(officeNoGps) && officeNoGps > 0 ? Number(officeNoGps) : 30,
    homeNoGpsTimeoutMinutes: Number.isFinite(homeNoGps) && homeNoGps > 0 ? Number(homeNoGps) : 30,
    // home-specific
    homeRadiusMeters: Number.isFinite(homeRadius) && homeRadius > 0 ? Number(homeRadius) : 200,
    homeTrackingEnabled: rows[0].home_tracking_enabled !== 0,
  };
}

async function getCheckInPolicy(db, employeeId, lock = false) {
  const profile = await profileFor(db, employeeId, lock);
  const workMode = await effectiveWorkMode(db, employeeId, undefined, lock, profile);
  if (workMode === 'Hybrid') {
    const [sessions] = await db.query(
      `SELECT id FROM hrms_field_tracking_sessions
       WHERE employee_user_id = ? AND is_active = 1
       LIMIT 1${lock ? ' FOR UPDATE' : ''}`,
      [employeeId]
    );
    const trackingActive = sessions.length > 0;
    return {
      workMode,
      requiresLocation: false,
      radiusMeters: null,
      trackingRequired: false,
      trackingActive,
      canClockIn: true,
    };
  }
  const settings = await settingsFor(db, lock);
  let center;
  if (workMode === 'Office') {
    try {
      center = coordinates(settings.office_latitude, settings.office_longitude);
    } catch (_) {
      throw new LocationPolicyError(503, 'Admin must configure a valid office location.');
    }
  } else {
    const [homes] = await db.query(
      `SELECT latitude, longitude, approval_status FROM hrms_employee_home_locations
       WHERE employee_user_id = ?${lock ? ' FOR UPDATE' : ''}`, [employeeId]);
    if (homes.length !== 1) {
      throw new LocationPolicyError(403, 'Register your Home location in Tracking and wait for admin approval.');
    }
    if (homes[0].approval_status !== 'approved') {
      throw new LocationPolicyError(403,
        homes[0].approval_status === 'rejected'
          ? 'Your Home location was rejected. Submit a new location in Tracking for approval.'
          : 'Your Home location is awaiting admin approval.');
    }
    try {
      center = coordinates(homes[0].latitude, homes[0].longitude);
    } catch (_) {
      throw new LocationPolicyError(503, 'The approved Home location is invalid. Contact admin.');
    }
  }
  const radiusMeters = workMode === 'Home' ? settings.homeRadiusMeters : settings.radiusMeters;
  return { workMode, requiresLocation: true, radiusMeters, center };
}

// A WFH permission is a temporary location rule, never a change to the
// employee's configured work mode.  The range test makes it expire naturally
// after its final approved day without a nightly reset job.
async function effectiveWorkMode(db, employeeId, date, lock = false, profile) {
  const permanent = profile || await profileFor(db, employeeId, lock);
  const day = date || require('../lib/attendancePolicy').todayIstDate();
  try {
    const [rows] = await db.query(
      `SELECT id FROM attendance_permission_requests
       WHERE employee_id = ? AND request_type = 'wfh' AND status = 'approved'
         AND request_date <= ?
         AND COALESCE(wfh_end_date, request_date) >= ?
       LIMIT 1${lock ? ' FOR UPDATE' : ''}`,
      [employeeId, day, day]
    );
    if (rows.length) return 'Home';
  } catch (error) {
    // Older installations do not have the range column until their first WFH
    // request. Their existing single-day WFH requests still work.
    if (error.code !== 'ER_BAD_FIELD_ERROR') throw error;
    const [rows] = await db.query(
      `SELECT id FROM attendance_permission_requests
       WHERE employee_id = ? AND request_type = 'wfh' AND status = 'approved'
         AND request_date = ? LIMIT 1${lock ? ' FOR UPDATE' : ''}`,
      [employeeId, day]
    );
    if (rows.length) return 'Home';
  }
  return permanent.work_mode;
}

function validateCheckIn(locationPolicy, body, now) {
  if (!locationPolicy.requiresLocation) return null;
  const fix = validateFix(body, locationPolicy.radiusMeters, now);
  const distance = distanceMeters(locationPolicy.center, fix);
  // Accuracy never enlarges the allowed radius. The boundary itself is allowed.
  if (distance > locationPolicy.radiusMeters + 0.000001) {
    throw new LocationPolicyError(403,
      `Clock In requires being within ${locationPolicy.radiusMeters} metres of your ${locationPolicy.workMode === 'Home' ? 'approved Home' : 'office'} location. You are about ${Math.round(distance)} metres away.`);
  }
  return fix;
}

module.exports = {
  LocationPolicyError, coordinates, distanceMeters, validateFix,
  profileFor, settingsFor, getCheckInPolicy, validateCheckIn, effectiveWorkMode
};
