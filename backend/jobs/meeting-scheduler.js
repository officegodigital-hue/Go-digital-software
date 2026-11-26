const db = require('../config/db');
const { ensureMeetingSchemaOnce } = require('../lib/ensureMeetingSchema');
const { closeEndedMeetings, backfillOpenMeetings } = require('../lib/meetingSync');

let ready;
let running;

function refreshMeetingSchedules(io) {
  if (!ready) {
    ready = ensureMeetingSchemaOnce(db).then(backfillOpenMeetings).catch((err) => {
      ready = null;
      throw err;
    });
  }
  if (!running) {
    running = ready.then(closeEndedMeetings).then((result) => {
      if (result.closed) io?.emit('meeting_tracking_updated', result);
      return result;
    }).finally(() => { running = null; });
  }
  return running;
}

async function runMeetingScheduler(io) {
  try {
    return await refreshMeetingSchedules(io);
  } catch (err) {
    console.error('meeting-scheduler error:', err.message);
  }
}

module.exports = { refreshMeetingSchedules, runMeetingScheduler };
