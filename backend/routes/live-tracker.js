// routes/live-tracker.js

const express = require('express');
const router = express.Router();
const db = require('../config/db');

function formatDuration(seconds) {
    seconds = Number(seconds || 0);

    const hrs = Math.floor(seconds / 3600);
    const mins = Math.floor((seconds % 3600) / 60);

    if (hrs > 0 && mins > 0) {
        return `${hrs} hrs ${mins} mins`;
    }

    if (hrs > 0) {
        return `${hrs} hrs`;
    }

    return `${mins} mins`;
}


// ============================================================
// GET LIVE TRACKER
// /api/live-tracker/:employeeName?date=2026-08-13
// ============================================================

router.get('/:employeeName', async (req, res) => {

    const { employeeName } = req.params;
    const { date } = req.query;

    if (!employeeName) {
        return res.status(400).json({
            success: false,
            message: 'employeeName is required'
        });
    }

    try {

        const targetDate = date || new Date()
            .toISOString()
            .slice(0, 10);


        const [rows] = await db.query(`
            SELECT
                lth.id,
                lth.task_list_id,
                lth.tracking_item_id,

                lth.employee_name,
                lth.client_name,
                lth.task,

                lth.status,

                lth.started_at,
                lth.ended_at,

                lth.duration_secs,

                COALESCE(lth.manager_action, 'ACTION')
                    AS manager_action,

                COALESCE(lth.manager_comment, '')
                    AS manager_comment,

                lth.created_at

            FROM live_tracking_history lth

            WHERE lth.employee_name = ?

              AND DATE(lth.created_at) = ?

            ORDER BY lth.created_at ASC

        `, [
            employeeName,
            targetDate
        ]);


        // ====================================================
        // TOTAL WORKING TIME FOR SELECTED DATE
        // ====================================================

        let totalWorkingSecs = 0;

        rows.forEach(row => {
            totalWorkingSecs += Number(row.duration_secs || 0);
        });


        // ====================================================
        // DATA
        // ====================================================

        const data = rows.map(row => {

            return {

                historyId: row.id,

                taskListId: row.task_list_id,

                trackingItemId: row.tracking_item_id,

                client_name: row.client_name || '',

                employee_name: row.employee_name,

                task: row.task || '',

                status: row.status || 'IDLE',

                duration: formatDuration(
                    row.duration_secs
                ),

                durationSecs: Number(
                    row.duration_secs || 0
                ),

                manager_action:
                    row.manager_action || 'ACTION',

                manager_comment:
                    row.manager_comment || '',

                started_at: row.started_at,

                ended_at: row.ended_at,

                created_at: row.created_at
            };

        });


        return res.json({

            success: true,

            date: targetDate,

            totalWorkingSecs,

            totalWorkingTime:
                formatDuration(totalWorkingSecs),

            data

        });

    } catch (err) {

        console.error(
            'GET /live-tracker ERROR:',
            err
        );

        return res.status(500).json({

            success: false,

            message: err.message

        });

    } 

});


module.exports = router;