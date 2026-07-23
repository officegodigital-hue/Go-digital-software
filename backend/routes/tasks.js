// routes/tasks.js — Task Assignments CRUD API
const express = require('express');
const router  = express.Router();
const db      = require('../config/db');
const { createNotification } = require('./notifications');

// Every role column + its matching "what was assigned" text column.
// Used by both POST (new assignment) and PUT (reassignment) to loop over
// all six possible assignees on a task_assignments row.
const ROLE_FIELDS = [
  { employeeField: 'designer',     tasksField: 'designerTasks',     label: 'designer_tasks_col' },
  { employeeField: 'videographer', tasksField: 'videographerTasks', label: 'videographer_tasks_col' },
  { employeeField: 'uiUxDesigner', tasksField: 'uiUxTasks',         label: 'ui_ux_tasks_col' },
  { employeeField: 'developer',    tasksField: 'developerTasks',    label: 'developer_tasks_col' },
  { employeeField: 'adsHandling',  tasksField: 'adsPlatform',       label: 'ads_platform_col' },
  { employeeField: 'pageHandling', tasksField: 'pagesPlatform',     label: 'pages_platform_col' },
];

// GET /api/tasks — all task rows
router.get('/', async (req, res) => {
  try {
    const [rows] = await db.query(`SELECT * FROM task_assignments ORDER BY created_at DESC`);
    return res.json({ success: true, data: rows });
  } catch (err) {
    console.error('GET /tasks ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// GET assigned clients for logged in employee
router.get('/employee/:employeeName/:role', async (req, res) => {
  const { employeeName, role } = req.params;

  let employeeColumn = '';
  let taskColumn = '';

  switch (role.toLowerCase()) {
    case 'designer':
      employeeColumn = 'designer';
      taskColumn = 'designer_tasks';
      break;

    case 'videographer':
      employeeColumn = 'videographer';
      taskColumn = 'videographer_tasks';
      break;
      case 'video editor':
  employeeColumn = 'video_editor';
  taskColumn = 'video_editor_task';
  break;

    case 'developer':
      employeeColumn = 'developer';
      taskColumn = 'developer_tasks';
      break;

    case 'ui ux designer':
    case 'ui/ux designer':
      employeeColumn = 'ui_ux_designer';
      taskColumn = 'ui_ux_tasks';
      break;

    case 'ads handler':
      employeeColumn = 'ads_handling';
      taskColumn = 'ads_platform';
      break;

    case 'page handler':
      employeeColumn = 'page_handling';
      taskColumn = 'pages_platform';
      break;

    default:
      return res.status(400).json({
        success: false,
        message: 'Invalid role'
      });
  }

  try {

    const [rows] = await db.query(
      `
      SELECT
        id,
        client_name,
        deliverables,
        ${taskColumn} as task
      FROM task_assignments
      WHERE ${employeeColumn}=?
      ORDER BY created_at DESC
      `,
      [employeeName]
    );

    res.json({
      success: true,
      data: rows
    });

  } catch(err){

    console.log(err);

    res.status(500).json({
      success:false,
      message:err.message
    });

  }

});

// POST /api/tasks — create a new task row
router.post('/', async (req, res) => {
  const {
    clientName, deliverables = '', adsHandling = '', adsPlatform = '', adsSubmitDate = '',
    pageHandling = '', pagesPlatform = '', pageSubmitDate = '',
    designer = '', designerTasks = '', designerSubmitDate = '',
    videographer = '', videographerTasks = '', videographerSubmitDate = '',
    videoEditor = '', videoEditorTask = '', videoEditorSubmitDate = '',
    uiUxDesigner = '', uiUxTasks = '', uiUxSubmitDate = '',
    developer = '', developerTasks = '', developerSubmitDate = '',
    deadline = '', maintenanceDate = '', comments = '', isAssigned = false,
    // NOTE: no auth middleware on this route yet, so the admin's name has to
    // come from the request body until authenticateToken is added here.
    // Falls back to 'Admin' if the frontend doesn't send it.
    assignedByName = 'Admin',
  } = req.body;

  if (!clientName) return res.status(400).json({ success: false, message: 'clientName is required' });

  try {
    const [result] = await db.query(
      `INSERT INTO task_assignments (client_name, deliverables, ads_handling, ads_platform, ads_submit_date, 
       page_handling, pages_platform, page_submit_date, designer, designer_tasks, designer_submit_date, 
       videographer, videographer_tasks, videographer_submit_date, 
       video_editor, video_editor_task, video_editor_submit_date, ui_ux_designer, ui_ux_tasks, ui_ux_submit_date, 
       developer, developer_tasks, developer_submit_date, deadline, maintenance_date, comments, is_assigned) 
       VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
      [clientName, deliverables, adsHandling, adsPlatform, adsSubmitDate, 
       pageHandling, pagesPlatform, pageSubmitDate, designer, designerTasks, designerSubmitDate, 
       videographer, videographerTasks, videographerSubmitDate, videoEditor, videoEditorTask, videoEditorSubmitDate, 
       uiUxDesigner, uiUxTasks, uiUxSubmitDate, 
       developer, developerTasks, developerSubmitDate, deadline, maintenanceDate, comments, isAssigned ? 1 : 0]
    );

    // FIX: this is the missing piece — every employee named in any role
    // column now gets notified that they were just assigned a task.
    const assignments = {
      designer:     { employeeName: designer,     tasks: designerTasks },
      videographer: { employeeName: videographer, tasks: videographerTasks },
      videoEditor: { employeeName: videoEditor, tasks: videoEditorTask },
      uiUxDesigner: { employeeName: uiUxDesigner, tasks: uiUxTasks },
      developer:    { employeeName: developer,    tasks: developerTasks },
      adsHandling:  { employeeName: adsHandling,  tasks: adsPlatform },
      pageHandling: { employeeName: pageHandling, tasks: pagesPlatform },
    };

    for (const { employeeName, tasks } of Object.values(assignments)) {
      if (employeeName && employeeName.trim() !== '') {
        try {
          await createNotification({
            senderName: assignedByName,
            recipientName: employeeName,
            message: `${assignedByName} assigned you a new task${tasks ? `: "${tasks}"` : ''} for ${clientName}.`,
          });
        } catch (notifyErr) {
          console.error('⚠️ task-assign notification failed (non-fatal):', notifyErr.message);
        }
      }
    }

    return res.status(201).json({ success: true, message: 'Task created', data: { id: result.insertId } });
  } catch (err) {
    console.error('POST /tasks ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// PUT /api/tasks/:id — update a task row
router.put('/:id', async (req, res) => {
  const {
    clientName, deliverables = '', adsHandling = '', adsPlatform = '', adsSubmitDate = '',
    pageHandling = '', pagesPlatform = '', pageSubmitDate = '',
    designer = '', designerTasks = '', designerSubmitDate = '',
    videographer = '', videographerTasks = '', videographerSubmitDate = '',
    videoEditor = '',
videoEditorTask = '',
videoEditorSubmitDate = '',
    uiUxDesigner = '', uiUxTasks = '', uiUxSubmitDate = '',
    developer = '', developerTasks = '', developerSubmitDate = '',
    deadline = '', maintenanceDate = '', comments = '', isAssigned = false,
    assignedByName = 'Admin',
  } = req.body;

  try {
    // FIX: fetch the row BEFORE updating so we can tell which role
    // assignments actually changed — editing the deadline shouldn't
    // re-notify every employee on the task with a fresh "assigned" message.
    const [existingRows] = await db.query(`SELECT * FROM task_assignments WHERE id = ?`, [req.params.id]);
    if (existingRows.length === 0) {
      return res.status(404).json({ success: false, message: 'Task not found' });
    }
    const existing = existingRows[0];

    const [result] = await db.query(
      `UPDATE task_assignments SET client_name=?, deliverables=?, ads_handling=?, ads_platform=?, ads_submit_date=?,
       page_handling=?, pages_platform=?, page_submit_date=?, designer=?, designer_tasks=?, designer_submit_date=?,
       videographer=?, videographer_tasks=?, videographer_submit_date=?, video_editor=?, video_editor_task=?, video_editor_submit_date=?, 
       ui_ux_designer=?, ui_ux_tasks=?, ui_ux_submit_date=?,
       developer=?, developer_tasks=?, developer_submit_date=?, deadline=?, maintenance_date=?, comments=?, is_assigned=?
       WHERE id=?`,
      [clientName, deliverables, adsHandling, adsPlatform, adsSubmitDate,
       pageHandling, pagesPlatform, pageSubmitDate, designer, designerTasks, designerSubmitDate,
       videographer, videographerTasks, videographerSubmitDate, 
       videoEditor, videoEditorTask, videoEditorSubmitDate,
       uiUxDesigner, uiUxTasks, uiUxSubmitDate,
       developer, developerTasks, developerSubmitDate, deadline, maintenanceDate, comments, isAssigned ? 1 : 0, req.params.id]
    );
    if (result.affectedRows === 0) return res.status(404).json({ success: false, message: 'Task not found' });

    // FIX: notify only when a role's employee OR their task text actually
    // changed from what was already there — not on every save.
    const roleChanges = [
      { employeeName: designer,     tasks: designerTasks,     oldEmployee: existing.designer,     oldTasks: existing.designer_tasks },
      { employeeName: videographer, tasks: videographerTasks, oldEmployee: existing.videographer, oldTasks: existing.videographer_tasks },
      { employeeName: videoEditor, tasks: videoEditorTask, oldEmployee: existing.video_editor, oldTasks: existing.video_editor_tasks },
      { employeeName: uiUxDesigner, tasks: uiUxTasks,         oldEmployee: existing.ui_ux_designer, oldTasks: existing.ui_ux_tasks },
      { employeeName: developer,    tasks: developerTasks,    oldEmployee: existing.developer,    oldTasks: existing.developer_tasks },
      { employeeName: adsHandling,  tasks: adsPlatform,       oldEmployee: existing.ads_handling,  oldTasks: existing.ads_platform },
      { employeeName: pageHandling, tasks: pagesPlatform,     oldEmployee: existing.page_handling, oldTasks: existing.pages_platform },
    ];

    for (const { employeeName, tasks, oldEmployee, oldTasks } of roleChanges) {
      if (!employeeName || employeeName.trim() === '') continue;
      const changed = employeeName !== oldEmployee || tasks !== oldTasks;
      if (!changed) continue;

      const isNewAssignment = employeeName !== oldEmployee;
      try {
        await createNotification({
          senderName: assignedByName,
          recipientName: employeeName,
          message: isNewAssignment
            ? `${assignedByName} assigned you a new task${tasks ? `: "${tasks}"` : ''} for ${clientName}.`
            : `${assignedByName} updated your task${tasks ? ` to: "${tasks}"` : ''} for ${clientName}.`,
        });
      } catch (notifyErr) {
        console.error('⚠️ task-update notification failed (non-fatal):', notifyErr.message);
      }
    }

    return res.json({ success: true, message: 'Task updated' });
  } catch (err) {
    console.error('PUT /tasks/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// PATCH /api/tasks/:id/assign — toggle is_assigned
router.patch('/:id/assign', async (req, res) => {
  const { isAssigned } = req.body;
  try {
    const [result] = await db.query(
      `UPDATE task_assignments SET is_assigned=? WHERE id=?`,
      [isAssigned ? 1 : 0, req.params.id]
    );
    if (result.affectedRows === 0)
      return res.status(404).json({ success: false, message: 'Task not found' });
    return res.json({ success: true, message: 'Assignment toggled' });
  } catch (err) {
    console.error('PATCH /tasks/:id/assign ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// DELETE /api/tasks/:id
router.delete('/:id', async (req, res) => {
  try {
    const [result] = await db.query(`DELETE FROM task_assignments WHERE id=?`, [req.params.id]);
    if (result.affectedRows === 0)
      return res.status(404).json({ success: false, message: 'Task not found' });
    return res.json({ success: true, message: 'Task deleted' });
  } catch (err) {
    console.error('DELETE /tasks/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;