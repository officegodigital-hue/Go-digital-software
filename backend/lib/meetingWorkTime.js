function coveredMillis(intervals) {
  const sorted = intervals.filter(([start, end]) => end > start).sort(([a], [b]) => a - b);
  let covered = 0;
  let lastEnd = -Infinity;
  for (const [start, end] of sorted) {
    covered += Math.max(0, end - Math.max(start, lastEnd));
    lastEnd = Math.max(lastEnd, end);
  }
  return covered;
}

// Preserve the task total and add only the meeting time outside counted tasks.
function additionalMeetingSeconds(taskIntervals, meetingIntervals) {
  if (!meetingIntervals.length) return 0;
  return Math.floor((coveredMillis([...taskIntervals, ...meetingIntervals]) - coveredMillis(taskIntervals)) / 1000);
}

module.exports = { additionalMeetingSeconds };
