function locationQuality(row) {
  if (row.latitude == null || row.longitude == null ||
      !Number.isFinite(Number(row.latitude)) || Math.abs(Number(row.latitude)) > 90 ||
      !Number.isFinite(Number(row.longitude)) || Math.abs(Number(row.longitude)) > 180) return 'invalid';
  if (row.accuracy_meters == null || row.accuracy_meters === '') return 'unknown_accuracy';
  const accuracy = Number(row.accuracy_meters);
  if (!Number.isFinite(accuracy) || accuracy < 0) return 'invalid';
  return accuracy <= 200 ? 'usable' : 'low_accuracy';
}

function historyPoint(row) {
  return {
    latitude: Number(row.latitude), longitude: Number(row.longitude),
    address: row.address || null, recordedAt: row.recorded_at,
    accuracyMeters: row.accuracy_meters == null ? null : Number(row.accuracy_meters),
    locationQuality: locationQuality(row),
  };
}

module.exports = { locationQuality, historyPoint };
