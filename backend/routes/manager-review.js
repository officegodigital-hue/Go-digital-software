// routes/manager-review.js — work submitted by employees (status = COMPLETED),
// awaiting a manager's Approve / Rework / Reject decision + comment.
// Manager decisions live in their own `manager_review` table, one row per
// tracking item, rather than as extra columns on time_tracking_task_items.
const express = require('express');
const router  = express.Router();
const db      = require('../config/db');
const { createNotification } = require('./notifications');

function formatDuration(seconds) {
  if (!seconds) return '0 mins';

  const hrs = Math.floor(seconds / 3600);
  const mins = Math.floor((seconds % 3600) / 60);

  if (hrs > 0 && mins > 0) return `${hrs} hrs ${mins} mins`;
  if (hrs > 0) return `${hrs} hrs`;
  return `${mins} mins`;
}

// GET /api/manager-review — every tracking row currently COMPLETED, across
// all employees/clients, with the manager's current action/comment on it
// (LEFT JOIN so rows with no review yet still show up, defaulting to 'ACTION').
// router.get('/', async (req, res) => {
//   try {
//     const [rows] = await db.query(`
//       SELECT
//         tti.id AS tracking_item_id,
//         tl.client_name,
//         tl.employee_name,
//         tl.deliverables AS task,
//         tl.duration AS estimated_duration,
//         tti.status,
//         tti.duration_secs,
//         mr.manager_action,
//         mr.manager_comment
//       FROM time_tracking_task_items tti
//       JOIN task_list tl ON tl.id = tti.task_list_id
//       LEFT JOIN manager_review mr ON mr.tracking_item_id = tti.id
//       WHERE tti.status = 'COMPLETED'
//       ORDER BY tti.updated_at DESC
//     `);
//     const data = rows.map(r => ({
//     ...r,
//     duration:
//         r.status === 'COMPLETED'
//             ? formatDuration(r.duration_secs)
//             : (r.estimated_duration || 'N/A')
// }));

//     return res.json({ success: true, data });
//   } catch (err) {
//     console.error('GET /manager-review ERROR:', err.message);
//     return res.status(500).json({ success: false, message: err.message });
//   }
// });

router.get('/', async (req, res) => {
  try {

    // Create ACTION row automatically if it doesn't exist
    await db.query(`
      INSERT INTO manager_review
      (
          tracking_item_id,
          manager_action,
          reviewed_at
      )
      SELECT
          tti.id,
          'ACTION',
          NOW()
      FROM time_tracking_task_items tti
      LEFT JOIN manager_review mr
          ON mr.tracking_item_id = tti.id
      WHERE
          tti.status = 'COMPLETED'
          AND mr.tracking_item_id IS NULL
    `);

    const [rows] = await db.query(`
      SELECT
        tti.id AS tracking_item_id,
        tl.client_name,
        tl.employee_name,
        tl.deliverables AS task,
        tl.duration AS estimated_duration,
        tti.status,
        tti.duration_secs,
        COALESCE(mr.manager_action,'ACTION') AS manager_action,
        mr.manager_comment
      FROM time_tracking_task_items tti
      JOIN task_list tl
        ON tl.id = tti.task_list_id
      LEFT JOIN manager_review mr
        ON mr.tracking_item_id = tti.id
      WHERE tti.status = 'COMPLETED'
      ORDER BY tti.updated_at DESC
    `);

    const data = rows.map(r => ({
      ...r,
      duration:
          r.status === 'COMPLETED'
              ? formatDuration(r.duration_secs)
              : (r.estimated_duration || 'N/A')
    }));

    return res.json({
      success: true,
      data
    });

  } catch (err) {
    console.error('GET /manager-review ERROR:', err.message);
    return res.status(500).json({
      success: false,
      message: err.message
    });
  }
});

// Employee Task Status
router.get('/task-status/:employeeName', async (req, res) => {
  try {
    const employeeName = req.params.employeeName;

    const [rows] = await db.query(
      `
      SELECT
          tti.id AS tracking_item_id,
          tl.client_name,
          tl.employee_name,
          tl.deliverables AS task,
          tti.task_description AS task_description,
          tti.duration_secs,
          tti.status,
          COALESCE(mr.manager_action, 'ACTION') AS manager_action,
          COALESCE(mr.manager_comment, '') AS manager_comment
      FROM time_tracking_task_items tti

      JOIN task_list tl
           ON tl.id = tti.task_list_id

      LEFT JOIN manager_review mr
           ON mr.tracking_item_id = tti.id

      WHERE
          tl.employee_name = ?
          AND tti.status = 'COMPLETED'

      ORDER BY tti.updated_at DESC
      `,
      [employeeName]
    );

    const data = rows.map(r => ({
      ...r,
      duration: formatDuration(r.duration_secs)
    }));

    res.json({
      success: true,
      data
    });

  } catch (err) {
    console.error('GET /manager-review/task-status ERROR:', err);

    res.status(500).json({
      success: false,
      message: err.message
    });
  }
});


// PATCH /api/manager-review/:trackingItemId — find-or-create the review row
// for this tracking item, then update action and/or comment on it. Either
// field can be sent alone (the dropdown fires with just { action }, the
// comment field debounces and fires with just { comment }).
router.patch('/:trackingItemId', async (req, res) => {

   console.log(req.body);
  const { trackingItemId } = req.params;
  const { action, comment, senderEmployeeName } = req.body;
  const senderName = senderEmployeeName || "Unknown";
  
   console.log("Sender Name:", senderEmployeeName);
  if (action === undefined && comment === undefined) {
    return res.status(400).json({ success: false, message: 'action or comment is required' });
  }

  try {
    // Confirm the tracking item actually exists before attaching a review to it.
    const [trackingRows] = await db.query(
      `SELECT id FROM time_tracking_task_items WHERE id = ?`,
      [trackingItemId]
    );
    if (trackingRows.length === 0) {
      return res.status(404).json({ success: false, message: 'Tracking item not found' });
    }

    // const [existing] = await db.query(
    //   `SELECT * FROM manager_review WHERE tracking_item_id = ?`,
    //   [trackingItemId]
    // );

    // if (existing.length > 0) {
    //   const updates = ['reviewed_at = NOW()'];
    //   const values = [];
    //   if (action !== undefined) { updates.push('manager_action = ?'); values.push(action); }
    //   if (comment !== undefined) { updates.push('manager_comment = ?'); values.push(comment); }
    //   values.push(existing[0].id);

    //   await db.query(`UPDATE manager_review SET ${updates.join(', ')} WHERE id = ?`, values);
    // } else {
    //   await db.query(
    //     `INSERT INTO manager_review (tracking_item_id, manager_action, manager_comment, reviewed_at)
    //      VALUES (?, ?, ?, NOW())`,
    //     [trackingItemId, action ?? 'ACTION', comment ?? null]
    //   );
    // }

    // const [rows] = await db.query(
    //   `SELECT * FROM manager_review WHERE tracking_item_id = ?`,
    //   [trackingItemId]
    // );

const updates = [];
const values = [];

if (action !== undefined) {
  updates.push("manager_action = ?");
  values.push(action);
}

if (comment !== undefined) {
  updates.push("manager_comment = ?");
  values.push(comment);
}

updates.push("reviewed_at = NOW()");
values.push(trackingItemId);

await db.query(
  `UPDATE manager_review
   SET ${updates.join(", ")}
   WHERE tracking_item_id = ?`,
  values
);

const [rows] = await db.query(
`
SELECT *
FROM manager_review
WHERE tracking_item_id = ?
`,
[trackingItemId]);



    // FIX: this is the missing piece — when the manager actually sets a
    // decision (APPROVED/REWORK/REJECTED, not just typing a comment), the
    // employee who did the work gets a real notification about it.
    // if (action !== undefined && action !== 'ACTION') {
    // if (rows.length > 0 && rows[0].manager_action !== 'ACTION') {
 if (
    action !== undefined &&
    action !== "ACTION" &&
    rows.length > 0
) {
    try {
       const review = rows[0];

        const [taskInfo] = await db.query(
          `SELECT tl.employee_name, tl.deliverables
           FROM time_tracking_task_items tti
           JOIN task_list tl ON tl.id = tti.task_list_id
           WHERE tti.id = ?`,
          [trackingItemId]
        );

        if (taskInfo.length > 0) {

            let preview = "";

            switch (review.manager_action) {
                case "APPROVED":
                    preview = `✅ Your task "${taskInfo[0].deliverables}" has been approved`;
                    break;

                case "REWORK":
                    preview = `🔄 Rework requested for "${taskInfo[0].deliverables}"`;
                    break;

               case "REJECTED":
                    preview = `❌ Your task "${taskInfo[0].deliverables}" has been rejected`;
                    break;
            }

            await createNotification({
    senderName: senderName,
    recipientName: taskInfo[0].employee_name,
    message: JSON.stringify({
        preview,
        payload: {
            type: "TASK_REVIEW",
            sender: senderEmployeeName,
            recipient: taskInfo[0].employee_name,
            taskName: taskInfo[0].deliverables,
            action: review.manager_action,
            comment: review.manager_comment ?? "",
            reviewedAt: new Date().toLocaleString("en-IN"),
        },
    }),
});

        }

    } catch (notifyErr) {
        console.error(notifyErr);
    }
}

try {
      const io = req.app.get('io');
      if (io) {
        io.emit('task_updated', { 
          type: 'MANAGER_REVIEW', 
          trackingItemId: trackingItemId,
          action: rows.length > 0 ? rows[0].manager_action : action 
        });
        console.log('📡 Broadcasted task_updated for tracking item:', trackingItemId);
      }
    } catch (socketErr) {
      console.error('Socket emit error:', socketErr);
    }

    return res.json({ success: true, message: 'Review updated', data: rows[0] });
  } catch (err) {
    console.error('PATCH /manager-review/:trackingItemId ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;