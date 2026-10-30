// mysql2's default local timezone represents SQL DATE at local midnight.
// Converting that midnight to UTC can silently move an employment boundary.
const dateKey = value => value instanceof Date
  ? `${value.getFullYear()}-${String(value.getMonth()+1).padStart(2,'0')}-${String(value.getDate()).padStart(2,'0')}`
  : String(value || '').slice(0, 10);
function validDate(value) {
  return /^\d{4}-\d{2}-\d{2}$/.test(value || '') &&
    !Number.isNaN(Date.parse(value + 'T00:00:00Z')) && new Date(value + 'T00:00:00Z').toISOString().slice(0, 10) === value;
}
function employedOn(periods, date) {
  return periods.some(p => date >= dateKey(p.started_on) && (!p.ended_on || date <= dateKey(p.ended_on)));
}
function overlaps(periods, start, end) {
  return periods.some(p => dateKey(p.started_on) <= end && (!p.ended_on || dateKey(p.ended_on) >= start));
}
function finalPay(salary, workingDays, eligibleDays, lopDays) {
  const dailyRate = workingDays > 0 ? salary / workingDays : 0;
  const deductions = Math.min(eligibleDays * dailyRate, Math.ceil(lopDays * dailyRate));
  return { dailyRate, deductions, netPay: Math.max(0, Math.round((eligibleDays * dailyRate - deductions) * 100) / 100) };
}
module.exports = { dateKey, validDate, employedOn, overlaps, finalPay };
