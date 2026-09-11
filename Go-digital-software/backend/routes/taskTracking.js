
// routes/taskTracking.js

const express = require('express');
const router = express.Router();

const db      = require('../config/db');

const TaskTrackingDetail = db.TaskTrackingDetail;
const TaskActionLog = db.TaskActionLog;

// ✅ ENDPOINT 1: Batch update task tracking details (Auto-save)
router.post('/task-tracking/batch-update', async (req, res) => {
  try {
    const { updates } = req.body;

    if (!updates || !Array.isArray(updates) || updates.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'No updates provided',
      });
    }

    let savedCount = 0;
    const errors = [];

    for (const update of updates) {
      try {
        const { task_key, submit_date, task_description, comment, row_count } = update;

        if (!task_key) {
          errors.push({
            task_key: task_key || 'unknown',
            error: 'Missing task_key',
          });
          continue;
        }

        // Find and update or create
        const [tracking, created] = await TaskTrackingDetail.findOrCreate({
          where: { task_key },
          defaults: {
            task_key,
            task_id: 0,
            employee_name: update.employee_name || '',
            client_name: update.client_name || '',
            task_name: update.task_name || '',
            submit_date: submit_date || '',
            task_description: task_description || '',
            comment: comment || '',
            row_count: row_count || 1,
          },
        });

        if (!created) {
          // Update existing
          await tracking.update({
            submit_date: submit_date !== undefined ? submit_date : tracking.submit_date,
            task_description: task_description !== undefined ? task_description : tracking.task_description,
            comment: comment !== undefined ? comment : tracking.comment,
            row_count: row_count !== undefined ? row_count : tracking.row_count,
            updated_at: new Date(),
          });
        }

        savedCount++;
        console.log(`✅ Updated task tracking: ${task_key}`);
      } catch (error) {
        console.error(`❌ Error updating ${update.task_key}:`, error.message);
        errors.push({
          task_key: update.task_key,
          error: error.message,
        });
      }
    }

    return res.status(200).json({
      success: true,
      saved_count: savedCount,
      total_updates: updates.length,
      errors: errors.length > 0 ? errors : null,
      message: `✅ Successfully saved ${savedCount}/${updates.length} task updates`,
    });
  } catch (error) {
    console.error('❌ Batch update error:', error);
    return res.status(500).json({
      success: false,
      message: `Error during batch update: ${error.message}`,
    });
  }
});

// ✅ ENDPOINT 2: Log task action (CREATE new entry for each action)
router.post('/task-actions/log', async (req, res) => {
  try {
    const {
      task_key,
      task_id,
      employee_name,
      client_name,
      task_name,
      action_type,
      action_timestamp,
      duration_so_far,
      current_session_duration,
    } = req.body;

    // Validate required fields
    const requiredFields = [
      'task_key',
      'task_id',
      'employee_name',
      'client_name',
      'task_name',
      'action_type',
      'action_timestamp',
    ];

    for (const field of requiredFields) {
      if (!(field in req.body)) {
        return res.status(400).json({
          success: false,
          message: `Missing required field: ${field}`,
        });
      }
    }

    // Validate action_type
    const validActions = ['START', 'HOLD', 'RESTART', 'COMPLETED', 'REJECTED'];
    const normalizedAction = action_type.toUpperCase();

    if (!validActions.includes(normalizedAction)) {
      return res.status(400).json({
        success: false,
        message: `Invalid action_type. Must be one of: ${validActions.join(', ')}`,
      });
    }

    // ✅ CREATE new action log entry (immutable audit trail)
    const actionLog = await TaskActionLog.create({
      task_id,
      task_key,
      employee_name,
      client_name,
      task_name,
      action_type: normalizedAction,
      action_timestamp: new Date(action_timestamp),
      duration_so_far: duration_so_far || 0,
      current_session_duration: current_session_duration || 0,
    });

    console.log(`✅ Logged action: ${normalizedAction} for task ${task_key}`);

    return res.status(201).json({
      success: true,
      message: `✅ Action logged: ${normalizedAction}`,
      action_log_id: actionLog.id,
      task_key,
      action_type: normalizedAction,
    });
  } catch (error) {
    console.error('❌ Error logging action:', error);
    return res.status(500).json({
      success: false,
      message: `Error logging action: ${error.message}`,
    });
  }
});

// ✅ ENDPOINT 3: Get task tracking details
router.get('/task-tracking/:task_key', async (req, res) => {
  try {
    const { task_key } = req.params;

    const tracking = await TaskTrackingDetail.findOne({
      where: { task_key },
    });

    if (!tracking) {
      return res.status(404).json({
        success: false,
        message: 'Task tracking detail not found',
      });
    }

    return res.status(200).json({
      success: true,
      data: tracking.toJSON(),
    });
  } catch (error) {
    console.error('❌ Error fetching task tracking:', error);
    return res.status(500).json({
      success: false,
      message: `Error: ${error.message}`,
    });
  }
});

// ✅ ENDPOINT 4: Get all actions for a task (audit trail)
router.get('/task-actions/:task_key/all', async (req, res) => {
  try {
    const { task_key } = req.params;

    const actions = await TaskActionLog.findAll({
      where: { task_key },
      order: [['action_timestamp', 'ASC']],
    });

    return res.status(200).json({
      success: true,
      task_key,
      total_actions: actions.length,
      actions: actions.map((action) => action.toJSON()),
    });
  } catch (error) {
    console.error('❌ Error fetching action history:', error);
    return res.status(500).json({
      success: false,
      message: `Error: ${error.message}`,
    });
  }
});

// ✅ ENDPOINT 5: Get tasks by employee
router.get('/task-tracking/employee/:employee_name', async (req, res) => {
  try {
    const { employee_name } = req.params;

    const trackings = await TaskTrackingDetail.findAll({
      where: { employee_name },
    });

    return res.status(200).json({
      success: true,
      employee_name,
      total_tasks: trackings.length,
      data: trackings.map((t) => t.toJSON()),
    });
  } catch (error) {
    console.error('❌ Error fetching employee tasks:', error);
    return res.status(500).json({
      success: false,
      message: `Error: ${error.message}`,
    });
  }
});

// ✅ ENDPOINT 6: Analytics - Get performance metrics for a task
router.get('/task-actions/:task_key/analytics', async (req, res) => {
  try {
    const { task_key } = req.params;

    const actions = await TaskActionLog.findAll({
      where: { task_key },
      order: [['action_timestamp', 'ASC']],
    });

    if (actions.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'No actions found for this task',
      });
    }

    // Calculate metrics
    let totalDuration = 0;
    let holdCount = 0;
    let restartCount = 0;
    let isCompleted = false;
    let isRejected = false;
    let startTime = null;
    let endTime = null;

    for (const action of actions) {
      if (action.action_type === 'START') {
        startTime = action.action_timestamp;
      } else if (action.action_type === 'HOLD') {
        holdCount++;
      } else if (action.action_type === 'RESTART') {
        restartCount++;
      } else if (action.action_type === 'COMPLETED') {
        isCompleted = true;
        endTime = action.action_timestamp;
        totalDuration = action.duration_so_far + action.current_session_duration;
      } else if (action.action_type === 'REJECTED') {
        isRejected = true;
        endTime = action.action_timestamp;
        totalDuration = action.duration_so_far + action.current_session_duration;
      }
    }

    return res.status(200).json({
      success: true,
      task_key,
      total_actions: actions.length,
      analytics: {
        total_duration_seconds: totalDuration,
        total_duration_minutes: (totalDuration / 60).toFixed(2),
        total_duration_hours: (totalDuration / 3600).toFixed(2),
        hold_count: holdCount,
        restart_count: restartCount,
        is_completed: isCompleted,
        is_rejected: isRejected,
        start_time: startTime ? startTime.toISOString() : null,
        end_time: endTime ? endTime.toISOString() : null,
        status: isCompleted ? 'COMPLETED' : isRejected ? 'REJECTED' : 'IN_PROGRESS',
      },
    });
  } catch (error) {
    console.error('❌ Error calculating analytics:', error);
    return res.status(500).json({
      success: false,
      message: `Error: ${error.message}`,
    });
  }
});

// ✅ ENDPOINT 7: Initialize task tracking
router.post('/task-tracking/init', async (req, res) => {
  try {
    const {
      task_key,
      task_id,
      employee_name,
      client_name,
      task_name,
      submit_date,
      task_description,
      row_count,
    } = req.body;

    if (!task_key) {
      return res.status(400).json({
        success: false,
        message: 'Missing task_key',
      });
    }

    const tracking = await TaskTrackingDetail.findOne({
      where: { task_key },
    });

    if (tracking) {
      // Already initialized
      return res.status(200).json({
        success: true,
        message: 'Task tracking already initialized',
        data: tracking.toJSON(),
      });
    }

    // Create new tracking entry
    const newTracking = await TaskTrackingDetail.create({
      task_id: task_id || 0,
      task_key,
      employee_name: employee_name || '',
      client_name: client_name || '',
      task_name: task_name || '',
      submit_date: submit_date || '',
      task_description: task_description || '',
      comment: '',
      row_count: row_count || 1,
    });

    console.log(`✅ Initialized task tracking: ${task_key}`);

    return res.status(201).json({
      success: true,
      message: 'Task tracking initialized',
      data: newTracking.toJSON(),
    });
  } catch (error) {
    console.error('❌ Error initializing task tracking:', error);
    return res.status(500).json({
      success: false,
      message: `Error: ${error.message}`,
    });
  }
});

module.exports = router;