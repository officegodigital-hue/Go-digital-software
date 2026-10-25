const policy = require('./attendancePolicy');

// Inputs are SQL wall-clock timestamps, in the same timezone as attendance.
function workedMinutes(row, breaks, now, live = false) {
  if (!row || !row.check_in_at || row.admin_status_override === 'absent') return 0;
  const end = row.check_out_at || (live ? now : null);
  if (!end) return 0;
  const startDate = new Date(row.check_in_at.replace(' ', 'T'));
  const endDate = new Date(end.replace(' ', 'T'));
  const elapsed = (endDate - startDate) / 60000;
  // A forgotten checkout spanning several days is not a valid daily shift.
  // Keep overnight shifts and overtime within a full day intact.
  if (!Number.isFinite(elapsed) || elapsed < 0 || elapsed > 24 * 60) return 0;
  const deducted = (breaks || []).reduce((sum, brk) => {
    if (brk.ended_at || ['completed', 'auto_closed'].includes(brk.status)) {
      return sum + Math.max(0, Number(brk.duration_minutes) || 0);
    }
    if (!brk.started_at) return sum;
    const breakStart = brk.started_at > row.check_in_at ? brk.started_at : row.check_in_at;
    return sum + policy.minutesBetween(breakStart, end);
  }, 0);
  return Math.max(0, Math.round(elapsed) - deducted);
}

module.exports = { workedMinutes };
