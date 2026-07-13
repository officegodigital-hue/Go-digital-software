const express = require('express');
const router = express.Router();
const db = require('../config/db');

// ✅ ENDPOINT 1: Save task progress (auto-save from employee side)
router.post('/save-task-progress', (req, res) => {
  const {
    employee_name,
    client_name,
    task_name,
    task_key,
    task_id,
    status,
    duration,
    comment,
    row_index,
    submit_date,
    description,
  } = req.body;

  if (!task_key) {
    return res.status(400).json({ success: false, message: 'task_key is required' });
  }

  // ✅ Use task_tracking_details table - SIMPLIFIED (no CASE WHEN with placeholders)
  const sql = `
    INSERT INTO task_tracking_details 
    (task_id, task_key, employee_name, client_name, task_name, submit_date, task_description, comment, row_count, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
    ON DUPLICATE KEY UPDATE 
    submit_date = VALUES(submit_date),
    task_description = VALUES(task_description),
    comment = VALUES(comment),
    row_count = VALUES(row_count),
    updated_at = NOW()
  `;

  const values = [
    task_id || 0,
    task_key,
    employee_name || '',
    client_name || '',
    task_name || '',
    submit_date || '',
    description || '',
    comment || '',
    row_index || 1,
  ];

  db.query(sql, values, (err, result) => {
    if (err) {
      console.error('❌ Save task progress error:', err);
      return res.status(500).json({ success: false, message: err.message });
    }

    console.log(`✅ Task progress saved: ${task_key}`);
    res.status(200).json({
      success: true,
      message: 'Task progress saved successfully',
      data: { task_key, status, duration, comment },
    });
  });
});

// ✅ ENDPOINT 2: Log action (immediate logging)
router.post('/log-action', (req, res) => {
  const {
    task_key,
    task_id,
    employee_name,
    client_name,
    task_name,
    action_type,
    duration_so_far,
    current_session_duration,
  } = req.body;

  if (!task_key) {
    return res.status(400).json({ success: false, message: 'task_key is required' });
  }

  const validActions = ['START', 'HOLD', 'RESTART', 'COMPLETED', 'REJECTED'];
  const normalizedAction = action_type?.toUpperCase() || '';

  if (!validActions.includes(normalizedAction)) {
    return res.status(400).json({
      success: false,
      message: `Invalid action. Must be one of: ${validActions.join(', ')}`,
    });
  }

  // ✅ Create immutable action log entry
  const sql = `
    INSERT INTO task_action_logs 
    (task_id, task_key, employee_name, client_name, task_name, action_type, action_timestamp, duration_so_far, current_session_duration, created_at)
    VALUES (?, ?, ?, ?, ?, ?, NOW(), ?, ?, NOW())
  `;

  const values = [
    task_id || 0,
    task_key,
    employee_name || '',
    client_name || '',
    task_name || '',
    normalizedAction,
    duration_so_far || 0,
    current_session_duration || 0,
  ];

  db.query(sql, values, (err, result) => {
    if (err) {
      console.error('❌ Log action error:', err);
      return res.status(500).json({ success: false, message: err.message });
    }

    console.log(`✅ Action logged: ${normalizedAction} for ${task_key}`);
    res.status(201).json({
      success: true,
      message: `Action logged: ${normalizedAction}`,
      action_log_id: result.insertId,
      task_key,
      action_type: normalizedAction,
    });
  });
});

// ✅ ENDPOINT 3: Batch update (for auto-save multiple tasks)
router.post('/batch-update-tasks', (req, res) => {
  const { updates } = req.body;

  if (!updates || !Array.isArray(updates) || updates.length === 0) {
    return res.status(400).json({
      success: false,
      message: 'No updates provided',
    });
  }

  let savedCount = 0;
  const errors = [];
  let completedQueries = 0;

  for (const update of updates) {
    const {
      task_key,
      task_id,
      employee_name,
      client_name,
      task_name,
      submit_date,
      task_description,
      comment,
      row_count,
    } = update;

    if (!task_key) {
      errors.push({
        task_key: task_key || 'unknown',
        error: 'Missing task_key',
      });
      completedQueries++;
      continue;
    }

    const sql = `
      INSERT INTO task_tracking_details 
      (task_id, task_key, employee_name, client_name, task_name, submit_date, task_description, comment, row_count, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
      ON DUPLICATE KEY UPDATE 
      submit_date = VALUES(submit_date),
      task_description = VALUES(task_description),
      comment = VALUES(comment),
      row_count = VALUES(row_count),
      updated_at = NOW()
    `;

    const values = [
      task_id || 0,
      task_key,
      employee_name || '',
      client_name || '',
      task_name || '',
      submit_date || '',
      task_description || '',
      comment || '',
      row_count || 1,
    ];

    db.query(sql, values, (err, result) => {
      completedQueries++;

      if (err) {
        console.error(`❌ Error updating ${task_key}:`, err.message);
        errors.push({
          task_key,
          error: err.message,
        });
      } else {
        savedCount++;
        console.log(`✅ Updated task tracking: ${task_key}`);
      }

      // When all queries are done, send response
      if (completedQueries === updates.length) {
        res.status(200).json({
          success: true,
          saved_count: savedCount,
          total_updates: updates.length,
          errors: errors.length > 0 ? errors : null,
          message: `✅ Successfully saved ${savedCount}/${updates.length} task updates`,
        });
      }
    });
  }
});

// ✅ ENDPOINT 4: Get task progress
router.get('/task-progress/:task_key', (req, res) => {
  const { task_key } = req.params;

  const sql = 'SELECT * FROM task_tracking_details WHERE task_key = ?';

  db.query(sql, [task_key], (err, results) => {
    if (err) {
      console.error('❌ Get task progress error:', err);
      return res.status(500).json({ success: false, message: err.message });
    }

    if (results.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Task tracking detail not found',
      });
    }

    res.status(200).json({
      success: true,
      data: results[0],
    });
  });
});

// ✅ ENDPOINT 5: Get all actions for a task
router.get('/task-actions/:task_key', (req, res) => {
  const { task_key } = req.params;

  const sql = `
    SELECT * FROM task_action_logs 
    WHERE task_key = ? 
    ORDER BY action_timestamp ASC
  `;

  db.query(sql, [task_key], (err, results) => {
    if (err) {
      console.error('❌ Get task actions error:', err);
      return res.status(500).json({ success: false, message: err.message });
    }

    res.status(200).json({
      success: true,
      task_key,
      total_actions: results.length,
      actions: results,
    });
  });
});

// ✅ ENDPOINT 6: Get all tasks for an employee
router.get('/employee-tasks/:employee_name', (req, res) => {
  const { employee_name } = req.params;

  const sql = `
    SELECT * FROM task_tracking_details 
    WHERE employee_name = ? 
    ORDER BY updated_at DESC
  `;

  db.query(sql, [employee_name], (err, results) => {
    if (err) {
      console.error('❌ Get employee tasks error:', err);
      return res.status(500).json({ success: false, message: err.message });
    }

    res.status(200).json({
      success: true,
      employee_name,
      total_tasks: results.length,
      data: results,
    });
  });
});

// ✅ ENDPOINT 7: Get analytics for a task
router.get('/task-analytics/:task_key', (req, res) => {
  const { task_key } = req.params;

  const sql = `
    SELECT * FROM task_action_logs 
    WHERE task_key = ? 
    ORDER BY action_timestamp ASC
  `;

  db.query(sql, [task_key], (err, results) => {
    if (err) {
      console.error('❌ Get analytics error:', err);
      return res.status(500).json({ success: false, message: err.message });
    }

    if (results.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'No actions found for this task',
      });
    }

    // Calculate analytics
    let totalDuration = 0;
    let holdCount = 0;
    let restartCount = 0;
    let isCompleted = false;
    let isRejected = false;
    let startTime = null;
    let endTime = null;

    for (const action of results) {
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

    res.status(200).json({
      success: true,
      task_key,
      total_actions: results.length,
      analytics: {
        total_duration_seconds: totalDuration,
        total_duration_minutes: (totalDuration / 60).toFixed(2),
        total_duration_hours: (totalDuration / 3600).toFixed(2),
        hold_count: holdCount,
        restart_count: restartCount,
        is_completed: isCompleted,
        is_rejected: isRejected,
        start_time: startTime,
        end_time: endTime,
        status: isCompleted ? 'COMPLETED' : isRejected ? 'REJECTED' : 'IN_PROGRESS',
      },
    });
  });
});

module.exports = router;