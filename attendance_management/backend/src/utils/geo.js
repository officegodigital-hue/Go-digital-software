const AppError = require('./AppError');

const EARTH_RADIUS_METERS = 6371000;

const toRadians = (degrees) => {
  return Number(degrees) * (Math.PI / 180);
};

const isValidLatitude = (latitude) => {
  return (
    Number.isFinite(latitude) &&
    latitude >= -90 &&
    latitude <= 90
  );
};

const isValidLongitude = (longitude) => {
  return (
    Number.isFinite(longitude) &&
    longitude >= -180 &&
    longitude <= 180
  );
};

/**
 * Calculates straight-line distance between two coordinates
 * using the Haversine formula.
 */
const calculateDistanceMeters = (
  latitude1,
  longitude1,
  latitude2,
  longitude2,
) => {
  const firstLatitude = Number(latitude1);
  const firstLongitude = Number(longitude1);
  const secondLatitude = Number(latitude2);
  const secondLongitude = Number(longitude2);

  if (
    !isValidLatitude(firstLatitude) ||
    !isValidLongitude(firstLongitude) ||
    !isValidLatitude(secondLatitude) ||
    !isValidLongitude(secondLongitude)
  ) {
    throw new AppError(
      422,
      'INVALID_COORDINATES',
      'Valid latitude and longitude values are required',
    );
  }

  const latitudeDifference = toRadians(
    secondLatitude - firstLatitude,
  );

  const longitudeDifference = toRadians(
    secondLongitude - firstLongitude,
  );

  const firstLatitudeRadians =
    toRadians(firstLatitude);

  const secondLatitudeRadians =
    toRadians(secondLatitude);

  const haversineValue =
    Math.sin(latitudeDifference / 2) ** 2 +
    Math.cos(firstLatitudeRadians) *
      Math.cos(secondLatitudeRadians) *
      Math.sin(longitudeDifference / 2) ** 2;

  const centralAngle =
    2 *
    Math.atan2(
      Math.sqrt(haversineValue),
      Math.sqrt(1 - haversineValue),
    );

  return EARTH_RADIUS_METERS * centralAngle;
};

/**
 * Validates location data received from Flutter.
 *
 * Expected input:
 * {
 *   latitude: 12.921456,
 *   longitude: 80.127845,
 *   accuracy_meters: 10,
 *   is_mocked: false
 * }
 */
const normalizeLocation = (value) => {
  if (value == null) {
    return null;
  }

  if (
    typeof value !== 'object' ||
    Array.isArray(value)
  ) {
    throw new AppError(
      422,
      'INVALID_LOCATION',
      'Location data must be a valid object',
    );
  }

  const latitude = Number(value.latitude);
  const longitude = Number(value.longitude);

  const accuracyMeters =
    value.accuracy_meters == null
      ? null
      : Number(value.accuracy_meters);

  const isMocked =
    value.is_mocked === true ||
    value.is_mocked === 1 ||
    value.is_mocked === '1';

  if (!isValidLatitude(latitude)) {
    throw new AppError(
      422,
      'INVALID_LATITUDE',
      'Latitude must be between -90 and 90',
    );
  }

  if (!isValidLongitude(longitude)) {
    throw new AppError(
      422,
      'INVALID_LONGITUDE',
      'Longitude must be between -180 and 180',
    );
  }

  if (
    accuracyMeters != null &&
    (
      !Number.isFinite(accuracyMeters) ||
      accuracyMeters < 0
    )
  ) {
    throw new AppError(
      422,
      'INVALID_LOCATION_ACCURACY',
      'Location accuracy must be a positive number',
    );
  }

  return {
    latitude,
    longitude,
    accuracyMeters,
    isMocked,
  };
};

/**
 * Checks whether the employee location is inside the
 * configured office radius.
 */
const evaluateGeofence = (
  employeeLocation,
  officeLocation,
) => {
  if (!employeeLocation || !officeLocation) {
    return {
      inside: null,
      distanceMeters: null,
      allowedRadiusMeters: null,
    };
  }

  const officeLatitude = Number(
    officeLocation.latitude,
  );

  const officeLongitude = Number(
    officeLocation.longitude,
  );

  const allowedRadiusMeters = Number(
    officeLocation.radius_meters,
  );

  if (
    !isValidLatitude(officeLatitude) ||
    !isValidLongitude(officeLongitude)
  ) {
    throw new AppError(
      500,
      'OFFICE_LOCATION_INVALID',
      'Office location coordinates are not configured correctly',
    );
  }

  if (
    !Number.isFinite(allowedRadiusMeters) ||
    allowedRadiusMeters <= 0
  ) {
    throw new AppError(
      500,
      'OFFICE_RADIUS_INVALID',
      'Office geofence radius is not configured correctly',
    );
  }

  const distanceMeters =
    calculateDistanceMeters(
      employeeLocation.latitude,
      employeeLocation.longitude,
      officeLatitude,
      officeLongitude,
    );

  return {
    inside:
      distanceMeters <= allowedRadiusMeters,

    distanceMeters:
      Number(distanceMeters.toFixed(2)),

    allowedRadiusMeters,
  };
};

/**
 * Validates mock location, required location and geofence.
 */
const validateGeofenceAccess = ({
  rawLocation,
  officeLocation,
}) => {
  const location = normalizeLocation(
    rawLocation,
  );

  const strictMode =
    officeLocation != null &&
    (
      officeLocation.strict_mode === true ||
      officeLocation.strict_mode === 1 ||
      officeLocation.strict_mode === '1'
    );

  if (strictMode && location == null) {
    throw new AppError(
      422,
      'LOCATION_REQUIRED',
      'Current location is required for attendance',
    );
  }

  if (strictMode && location?.isMocked) {
    throw new AppError(
      403,
      'MOCK_LOCATION_DETECTED',
      'Mock location is not allowed for attendance',
    );
  }

  const geofence = evaluateGeofence(
    location,
    officeLocation,
  );

  if (
    strictMode &&
    geofence.inside === false
  ) {
    throw new AppError(
      403,
      'OUTSIDE_GEOFENCE',
      'You are outside the permitted office location',
      {
        distance_meters:
          geofence.distanceMeters,

        allowed_radius_meters:
          geofence.allowedRadiusMeters,
      },
    );
  }

  return {
    location,
    geofence,
    strictMode,
  };
};

module.exports = {
  EARTH_RADIUS_METERS,
  calculateDistanceMeters,
  normalizeLocation,
  evaluateGeofence,
  validateGeofenceAccess,
};