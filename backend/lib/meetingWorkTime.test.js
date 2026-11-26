const { test } = require('node:test');
const assert = require('node:assert/strict');
const { additionalMeetingSeconds } = require('./meetingWorkTime');

test('meetings add only time outside counted task and meeting overlaps', () => {
  const tasks = [[0, 10000], [30000, 40000]];
  const meetings = [[5000, 25000], [20000, 35000], [45000, 50000]];
  assert.equal(additionalMeetingSeconds(tasks, meetings), 25);
  assert.equal(additionalMeetingSeconds(tasks, [[2000, 8000]]), 0);
  assert.equal(additionalMeetingSeconds([], meetings), 35);
  assert.equal(additionalMeetingSeconds(tasks, []), 0);
});
