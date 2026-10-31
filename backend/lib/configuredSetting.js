'use strict';

// Policy values come from saved admin settings, never from fallback constants.
function configuredNumber(value, label, allowZero = false) {
  const number = value == null || String(value).trim() === '' ? NaN : Number(value);
  if (!Number.isSafeInteger(number) || (allowZero ? number < 0 : number <= 0)) {
    throw Object.assign(new Error(`Admin must configure ${label}`), { status: 503 });
  }
  return number;
}

module.exports = { configuredNumber };
