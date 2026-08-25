// routes/task-master.js — Task Master API (Manage task roles and tasks)
const express = require('express');
const router = express.Router();
const db = require('../config/db');

// GET /api/task-master — Get all tasks grouped by role
router.get('/', async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT id, task_name, role_key, created_at
       FROM task_master
       ORDER BY role_key ASC, task_name ASC`
    );
    return res.json({ success: true, data: rows });
  } catch (err) {
    console.error('GET /task-master ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/task-master/:roleKey — Get tasks for a specific role
router.get('/:roleKey', async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT id, task_name, role_key
       FROM task_master
       WHERE role_key = ?
       ORDER BY task_name ASC`,
      [req.params.roleKey]
    );
    return res.json({ success: true, data: rows });
  } catch (err) {
    console.error('GET /task-master/:roleKey ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/task-master — Create new task
// Body: { task_name, role_key }
router.post('/', async (req, res) => {
  const { task_name, role_key } = req.body;

  if (!task_name || !role_key) {
    return res.status(400).json({ 
      success: false, 
      message: 'task_name and role_key are required' 
    });
  }

  try {
    const [result] = await db.query(
      `INSERT INTO task_master (task_name, role_key) VALUES (?, ?)`,
      [task_name, role_key]
    );

    return res.status(201).json({
      success: true,
      message: 'Task created successfully',
      data: { id: result.insertId, task_name, role_key },
    });
  } catch (err) {
    console.error('POST /task-master ERROR:', err.message);
    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ 
        success: false,  
        message: `Task "${task_name}" already exists for this role` 
      });
    }
    return res.status(500).json({ success: false, message: err.message });
  }
});

// PUT /api/task-master/:id — Update existing task
// Body: { task_name, role_key }
// router.put('/:id', async (req, res) => {
//   const { task_name, role_key } = req.body;

//   if (!task_name || !role_key) {
//     return res.status(400).json({ 
//       success: false, 
//       message: 'task_name and role_key are required' 
//     });
//   }

//   try {
//     const [result] = await db.query(
//       `UPDATE task_master SET task_name = ?, role_key = ? WHERE id = ?`,
//       [task_name, role_key, req.params.id]
//     );

//     if (result.affectedRows === 0) {
//       return res.status(404).json({ 
//         success: false, 
//         message: 'Task not found' 
//       });
//     }

//     return res.json({
//       success: true,
//       message: 'Task updated successfully',
//       data: { id: req.params.id, task_name, role_key },
//     });
//   } catch (err) {
//     console.error('PUT /task-master/:id ERROR:', err.message);
//     return res.status(500).json({ success: false, message: err.message });
//   }
// });

// PUT /api/task-master/:id — Update existing task
// Body: { task_name, role_key }
router.put('/:id', async (req, res) => {
  const { task_name, role_key } = req.body;
  const taskMasterId = req.params.id;

  if (!task_name || !role_key) {
    return res.status(400).json({
      success: false,
      message: 'task_name and role_key are required'
    });
  }

  let connection;

  try {
    connection = await db.getConnection();

    await connection.beginTransaction();

    // =========================================================
    // 1. Get OLD task information using Task Master ID
    // =========================================================
    const [oldTaskRows] = await connection.query(
      `SELECT id, task_name, role_key
       FROM task_master
       WHERE id = ?`,
      [taskMasterId]
    );

    if (oldTaskRows.length === 0) {
      await connection.rollback();

      return res.status(404).json({
        success: false,
        message: 'Task not found'
      });
    }

    const oldTaskName = oldTaskRows[0].task_name;
    const newTaskName = task_name.trim();

    // If nothing actually changed
    if (
      oldTaskName === newTaskName &&
      oldTaskRows[0].role_key === role_key
    ) {
      await connection.rollback();

      return res.json({
        success: true,
        message: 'No changes found',
        data: {
          id: taskMasterId,
          task_name: newTaskName,
          role_key
        }
      });
    }

    // =========================================================
    // 2. Update Task Master
    // =========================================================
    const [result] = await connection.query(
      `UPDATE task_master
       SET task_name = ?, role_key = ?
       WHERE id = ?`,
      [
        newTaskName,
        role_key,
        taskMasterId
      ]
    );

    if (result.affectedRows === 0) {
      await connection.rollback();

      return res.status(404).json({
        success: false,
        message: 'Task not found'
      });
    }

    // =========================================================
    // 3. Update task_list
    //
    // task_list has task_master_id.
    // Replace only the old task name inside deliverables.
    // =========================================================
    const [taskListResult] = await connection.query(
      `UPDATE task_list
       SET deliverables = REPLACE(deliverables, ?, ?)
       WHERE task_master_id = ?
         AND deliverables IS NOT NULL`,
      [
        oldTaskName,
        newTaskName,
        taskMasterId
      ]
    );

    // =========================================================
    // 4. Update task_assignments
    //
    // These columns contain task names such as:
    //
    // GMB (1)
    // META ADS (1), GMB (1)
    // GMB (1), FACEBOOK VEDIOS (1)
    //
    // So we replace ONLY the task name part.
    // =========================================================
    const assignmentColumns = [
      'designer_tasks',
      'videographer_tasks',
      'video_editor_task',
      'ui_ux_tasks',
      'developer_tasks',
      'ads_platform',
      'pages_platform',
      'website_designer_task'
    ];

    let assignmentUpdated = 0;

    for (const column of assignmentColumns) {
      const [updateResult] = await connection.query(
        `UPDATE task_assignments
         SET ${column} = REPLACE(${column}, ?, ?)
         WHERE ${column} IS NOT NULL
           AND ${column} LIKE ?`,
        [
          oldTaskName,
          newTaskName,
          `%${oldTaskName}%`
        ]
      );

      assignmentUpdated += updateResult.affectedRows;
    }

    // =========================================================
    // 5. Commit all changes
    // =========================================================
    await connection.commit();

    console.log('==========================================');
    console.log('✅ TASK MASTER UPDATED');
    console.log(`ID           : ${taskMasterId}`);
    console.log(`Old Name     : ${oldTaskName}`);
    console.log(`New Name     : ${newTaskName}`);
    console.log(`Role         : ${role_key}`);
    console.log(
      `task_list    : ${taskListResult.affectedRows} rows`
    );
    console.log(
      `assignments  : ${assignmentUpdated} rows`
    );
    console.log('==========================================');

    return res.json({
      success: true,
      message: 'Task updated successfully across all related data',
      data: {
        id: taskMasterId,
        old_task_name: oldTaskName,
        task_name: newTaskName,
        role_key,
        task_list_updated: taskListResult.affectedRows,
        task_assignments_updated: assignmentUpdated
      }
    });

  } catch (err) {

    if (connection) {
      try {
        await connection.rollback();
      } catch (rollbackErr) {
        console.error(
          'Rollback ERROR:',
          rollbackErr.message
        );
      }
    }

    console.error(
      'PUT /task-master/:id ERROR:',
      err.message
    );

    return res.status(500).json({
      success: false,
      message: err.message
    });

  } finally {

    if (connection) {
      connection.release();
    }
  }
});

// DELETE /api/task-master/:id — Delete task
router.delete('/:id', async (req, res) => {
  try {
    const [result] = await db.query(
      `DELETE FROM task_master WHERE id = ?`,
      [req.params.id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ 
        success: false, 
        message: 'Task not found' 
      });
    }

    return res.json({
      success: true,
      message: 'Task deleted successfully',
    });
  } catch (err) {
    console.error('DELETE /task-master/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;