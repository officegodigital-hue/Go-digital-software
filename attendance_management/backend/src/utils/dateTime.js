const DEFAULT_TIMEZONE = 'Asia/Kolkata';

/**
 * Returns date and time values for the requested timezone.
 *
 * Example:
 * {
 *   date: '2026-07-22',
 *   hour: 18,
 *   minute: 30,
 *   second: 15,
 *   minutesFromMidnight: 1110
 * }
 */
const getTimeZoneParts = (
  timeZone = DEFAULT_TIMEZONE,
  date = new Date(),
) => {
  const formatter = new Intl.DateTimeFormat('en-GB', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false,
  });

  const formattedParts = formatter.formatToParts(date);

  const values = {};

  for (const part of formattedParts) {
    if (part.type !== 'literal') {
      values[part.type] = part.value;
    }
  }

  // Some JavaScript environments may return 24 for midnight.
  const hour = Number(values.hour) % 24;
  const minute = Number(values.minute);
  const second = Number(values.second);

  return {
    date: `${values.year}-${values.month}-${values.day}`,
    year: Number(values.year),
    month: Number(values.month),
    day: Number(values.day),
    hour,
    minute,
    second,
    minutesFromMidnight: hour * 60 + minute,
  };
};

/**
 * Converts a MySQL TIME value such as 09:30:00 into total minutes.
 */
const timeStringToMinutes = (value) => {
  if (value == null || value === '') {
    return 0;
  }

  const parts = String(value).split(':');

  const hour = Number(parts[0] || 0);
  const minute = Number(parts[1] || 0);

  if (
    !Number.isFinite(hour) ||
    !Number.isFinite(minute)
  ) {
    return 0;
  }

  return hour * 60 + minute;
};

/**
 * Calculates scheduled shift duration.
 * Supports overnight shifts such as 22:00 to 06:00.
 */
const calculateShiftMinutes = (
  startTime,
  endTime,
) => {
  const startMinutes =
    timeStringToMinutes(startTime);

  const endMinutes =
    timeStringToMinutes(endTime);

  if (endMinutes >= startMinutes) {
    return endMinutes - startMinutes;
  }

  return 1440 - startMinutes + endMinutes;
};

/**
 * Calculates full minutes between two JavaScript dates.
 */
const calculateMinutesBetween = (
  startDate,
  endDate,
) => {
  if (!startDate || !endDate) {
    return 0;
  }

  const start = new Date(startDate);
  const end = new Date(endDate);

  const startMilliseconds = start.getTime();
  const endMilliseconds = end.getTime();

  if (
    !Number.isFinite(startMilliseconds) ||
    !Number.isFinite(endMilliseconds)
  ) {
    return 0;
  }

  const difference =
    endMilliseconds - startMilliseconds;

  return Math.max(
    0,
    Math.floor(difference / 60000),
  );
};

/**
 * Formats a duration into a display-friendly value.
 *
 * Example:
 * 510 minutes -> "8h 30m"
 */
const formatMinutes = (totalMinutes) => {
  const safeMinutes = Math.max(
    0,
    Number(totalMinutes) || 0,
  );

  const hours = Math.floor(safeMinutes / 60);
  const minutes = safeMinutes % 60;

  if (hours === 0) {
    return `${minutes}m`;
  }

  return `${hours}h ${minutes}m`;
};

module.exports = {
  DEFAULT_TIMEZONE,
  getTimeZoneParts,
  timeStringToMinutes,
  calculateShiftMinutes,
  calculateMinutesBetween,
  formatMinutes,
};