// routes/tasks.js — Task Assignments CRUD API
const express = require('express');
const router  = express.Router();
const db      = require('../config/db');
const { createNotification } = require('./notifications');


const formatDate = (date) => {
  if (!date || date.trim() === '' || date === '—') {
    return null;
  }
  
  // If the date is already in YYYY-MM-DD format, return it
  if (/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    return date;
  }

  // Convert DD/MM/YYYY to YYYY-MM-DD
  if (date.includes('/')) {
    const parts = date.split('/');
    if (parts.length === 3) {
      const day = parts[0].padStart(2, '0');
      const month = parts[1].padStart(2, '0');
      const year = parts[2];
      return `${year}-${month}-${day}`;
    }
  }

  return null;
};

// Every role column + its matching "what was assigned" text column.
// Used by both POST (new assignment) and PUT (reassignment) to loop over
// all six possible assignees on a task_assignments row.
const ROLE_FIELDS = [
  { employeeField: 'designer',     tasksField: 'designerTasks',     label: 'designer_tasks_col' },
  { employeeField: 'videographer', tasksField: 'videographerTasks', label: 'videographer_tasks_col' },
  { employeeField: 'videoEditor',  tasksField: 'videoEditorTask',   label: 'video_editor_task_col' },
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
  ${taskColumn} as task,
  ${employeeColumn} as employee
FROM task_assignments
WHERE ${employeeColumn}=?
  AND is_assigned = 1
ORDER BY created_at DESC
      `,
      [employeeName]
    );
    console.log(rows);

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
    clientName, deliverables = '', adsHandling = '', adsPlatform = '', adsSubmitDate = null,
    pageHandling = '', pagesPlatform = '', pageSubmitDate = null,
    designer = '', designerTasks = '', designerSubmitDate = null,
    videographer = '', videographerTasks = '', videographerSubmitDate = null,
    videoEditor = '', videoEditorTask = '', videoEditorSubmitDate = null,
    uiUxDesigner = '', uiUxTasks = '', uiUxSubmitDate = null,
    developer = '', developerTasks = '', developerSubmitDate = null,
    deadline = '', maintenanceDate = '', comments = '', isAssigned = false,
    assignedByName = 'Admin',
  } = req.body;

  if (!clientName) return res.status(400).json({ success: false, message: 'clientName is required' });

  try {
    const io = req.app.get("io");
    const [result] = await db.query(
      `INSERT INTO task_assignments (client_name, deliverables, ads_handling, ads_platform, ads_submit_date, 
       page_handling, pages_platform, page_submit_date, designer, designer_tasks, designer_submit_date, 
       videographer, videographer_tasks, videographer_submit_date, 
       video_editor, video_editor_task, video_editor_submit_date, ui_ux_designer, ui_ux_tasks, ui_ux_submit_date, 
       developer, developer_tasks, developer_submit_date, deadline, maintenance_date, comments, is_assigned) 
       VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
      // [clientName, deliverables, adsHandling, adsPlatform, adsSubmitDate, 
      //  pageHandling, pagesPlatform, pageSubmitDate, designer, designerTasks, designerSubmitDate, 
      //  videographer, videographerTasks, videographerSubmitDate, videoEditor, videoEditorTask, videoEditorSubmitDate, 
      //  uiUxDesigner, uiUxTasks, uiUxSubmitDate, 
      //  developer, developerTasks, developerSubmitDate, deadline, maintenanceDate, comments, isAssigned ? 1 : 0]
      [
 clientName,
 deliverables,
 adsHandling,
 adsPlatform,
 formatDate(adsSubmitDate),

 pageHandling,
 pagesPlatform,
 formatDate(pageSubmitDate),

 designer,
 designerTasks,
 formatDate(designerSubmitDate),

 videographer,
 videographerTasks,
 formatDate(videographerSubmitDate),

 videoEditor,
 videoEditorTask,
 formatDate(videoEditorSubmitDate),

 uiUxDesigner,
 uiUxTasks,
 formatDate(uiUxSubmitDate),

 developer,
 developerTasks,
 formatDate(developerSubmitDate),

 deadline,
 maintenanceDate,
 comments,
 isAssigned ? 1 : 0
]
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

    // ✅ Task assign seiyum pothu (isAssigned true-a irunthal) notification send agum
    // Insert successful aana piragu DB value check pannunga
const [rows] = await db.query(
  `SELECT is_assigned FROM task_assignments WHERE id = ?`,
  [result.insertId]
);

// if (rows.length && rows[0].is_assigned == 1) {
//   const assignments = [
//     { employeeName: designer,     tasks: designerTasks },
//     { employeeName: videographer, tasks: videographerTasks },
//     { employeeName: videoEditor,  tasks: videoEditorTask },
//     { employeeName: uiUxDesigner, tasks: uiUxTasks },
//     { employeeName: developer,    tasks: developerTasks },
//     { employeeName: adsHandling,  tasks: adsPlatform },
//     { employeeName: pageHandling, tasks: pagesPlatform },
//   ];

//   for (const { employeeName, tasks } of assignments) {
//     if (employeeName && employeeName.trim() !== '' && employeeName.toUpperCase() !== 'NONE') {
//       try {
//         await createNotification({
//           senderName: assignedByName,
//           recipientName: employeeName,
//           message: JSON.stringify({
//             preview: `${assignedByName} assigned you a new task for ${clientName}`,
//             payload: {
//               type: "TASK_ASSIGNED",
//               sender: assignedByName,
//               recipient: employeeName,
//               client: clientName,
//               taskName: tasks || deliverables,
//             }
//           }),
//         });
//       } catch (notifyErr) {
//         console.error('⚠️ task-assign notification failed:', notifyErr.message);
//       }
//     }
//   }
// }


    try {
  const io = req.app.get('io');
  if (io) {
    io.emit('task_updated', { 
      type: 'TASK_ASSIGNED', 
      message: 'New task assigned by admin' 
    });
  }
} catch (socketErr) {
  console.error('Socket emit error:', socketErr);
}

    return res.status(201).json({ success: true, message: 'Task created', data: { id: result.insertId } });

  } catch (err) {
    console.error('POST /tasks ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// PUT /api/tasks/:id — update task safely
router.put('/:id', async (req, res) => {
  try {
    // =========================================================
    // 1. Get existing task
    // =========================================================
    const [existingRows] = await db.query(
      `SELECT * FROM task_assignments WHERE id = ?`,
      [req.params.id]
    );

    if (existingRows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Task not found'
      });
    }

    const existing = existingRows[0];

    // =========================================================
    // Helper functions
    // =========================================================

    // Normal field:
    // - undefined => keep old value
    // - null      => keep old value
    // - ""        => keep old value
    // - actual value => update
    const keepExisting = (newValue, oldValue) => {
      if (
        newValue === undefined ||
        newValue === null ||
        (typeof newValue === 'string' && newValue.trim() === '')
      ) {
        return oldValue;
      }

      return newValue;
    };

    // Date field:
    // - undefined => keep old date
    // - null      => keep old date
    // - ""        => keep old date
    // - valid date => update
    const keepExistingDate = (newValue, oldValue) => {
      if (
        newValue === undefined ||
        newValue === null ||
        (typeof newValue === 'string' && newValue.trim() === '')
      ) {
        return oldValue;
      }

      const formatted = formatDate(newValue);

      // If formatDate cannot convert it,
      // do NOT destroy the existing date.
      if (!formatted) {
        return oldValue;
      }

      return formatted;
    };

    // =========================================================
    // 2. Read values
    // =========================================================

    const clientName = keepExisting(
      req.body.clientName,
      existing.client_name
    );

    const deliverables = keepExisting(
      req.body.deliverables,
      existing.deliverables
    );

    // ---------------------------------------------------------
    // ADS HANDLING
    // ---------------------------------------------------------

    const adsHandling = keepExisting(
      req.body.adsHandling,
      existing.ads_handling
    );

    const adsPlatform = keepExisting(
      req.body.adsPlatform,
      existing.ads_platform
    );

    const adsSubmitDate = keepExistingDate(
      req.body.adsSubmitDate,
      existing.ads_submit_date
    );

    // ---------------------------------------------------------
    // PAGE HANDLING
    // ---------------------------------------------------------

    const pageHandling = keepExisting(
      req.body.pageHandling,
      existing.page_handling
    );

    const pagesPlatform = keepExisting(
      req.body.pagesPlatform,
      existing.pages_platform
    );

    const pageSubmitDate = keepExistingDate(
      req.body.pageSubmitDate,
      existing.page_submit_date
    );

    // ---------------------------------------------------------
    // DESIGNER
    // ---------------------------------------------------------

    const designer = keepExisting(
      req.body.designer,
      existing.designer
    );

    const designerTasks = keepExisting(
      req.body.designerTasks,
      existing.designer_tasks
    );

    const designerSubmitDate = keepExistingDate(
      req.body.designerSubmitDate,
      existing.designer_submit_date
    );

    // ---------------------------------------------------------
    // VIDEOGRAPHER
    // ---------------------------------------------------------

    const videographer = keepExisting(
      req.body.videographer,
      existing.videographer
    );

    const videographerTasks = keepExisting(
      req.body.videographerTasks,
      existing.videographer_tasks
    );

    const videographerSubmitDate = keepExistingDate(
      req.body.videographerSubmitDate,
      existing.videographer_submit_date
    );

    // ---------------------------------------------------------
    // VIDEO EDITOR
    // ---------------------------------------------------------

    const videoEditor = keepExisting(
      req.body.videoEditor,
      existing.video_editor
    );

    const videoEditorTask = keepExisting(
      req.body.videoEditorTask,
      existing.video_editor_task
    );

    const videoEditorSubmitDate = keepExistingDate(
      req.body.videoEditorSubmitDate,
      existing.video_editor_submit_date
    );

    // ---------------------------------------------------------
    // UI / UX DESIGNER
    // ---------------------------------------------------------

    const uiUxDesigner = keepExisting(
      req.body.uiUxDesigner,
      existing.ui_ux_designer
    );

    const uiUxTasks = keepExisting(
      req.body.uiUxTasks,
      existing.ui_ux_tasks
    );

    const uiUxSubmitDate = keepExistingDate(
      req.body.uiUxSubmitDate,
      existing.ui_ux_submit_date
    );

    // ---------------------------------------------------------
    // DEVELOPER
    // ---------------------------------------------------------

    const developer = keepExisting(
      req.body.developer,
      existing.developer
    );

    const developerTasks = keepExisting(
      req.body.developerTasks,
      existing.developer_tasks
    );

    const developerSubmitDate = keepExistingDate(
      req.body.developerSubmitDate,
      existing.developer_submit_date
    );

    // ---------------------------------------------------------
    // COMMON FIELDS
    // ---------------------------------------------------------

    const deadline = keepExisting(
      req.body.deadline,
      existing.deadline
    );

    const maintenanceDate = keepExisting(
      req.body.maintenanceDate,
      existing.maintenance_date
    );

    const comments = keepExisting(
      req.body.comments,
      existing.comments
    );

    const isAssigned =
      req.body.isAssigned !== undefined
        ? (req.body.isAssigned ? 1 : 0)
        : existing.is_assigned;

    // =========================================================
    // 3. UPDATE DATABASE
    // =========================================================

    await db.query(
      `UPDATE task_assignments
       SET
         client_name=?,
         deliverables=?,

         ads_handling=?,
         ads_platform=?,
         ads_submit_date=?,

         page_handling=?,
         pages_platform=?,
         page_submit_date=?,

         designer=?,
         designer_tasks=?,
         designer_submit_date=?,

         videographer=?,
         videographer_tasks=?,
         videographer_submit_date=?,

         video_editor=?,
         video_editor_task=?,
         video_editor_submit_date=?,

         ui_ux_designer=?,
         ui_ux_tasks=?,
         ui_ux_submit_date=?,

         developer=?,
         developer_tasks=?,
         developer_submit_date=?,

         deadline=?,
         maintenance_date=?,
         comments=?,
         is_assigned=?

       WHERE id=?`,
      [
        clientName,
        deliverables,

        adsHandling,
        adsPlatform,
        adsSubmitDate,

        pageHandling,
        pagesPlatform,
        pageSubmitDate,

        designer,
        designerTasks,
        designerSubmitDate,

        videographer,
        videographerTasks,
        videographerSubmitDate,

        videoEditor,
        videoEditorTask,
        videoEditorSubmitDate,

        uiUxDesigner,
        uiUxTasks,
        uiUxSubmitDate,

        developer,
        developerTasks,
        developerSubmitDate,

        deadline,
        maintenanceDate,
        comments,
        isAssigned,

        req.params.id
      ]
    );

    // =========================================================
    // 4. Socket update
    // =========================================================

    try {
      const io = req.app.get('io');

      if (io) {
        io.emit('task_updated', {
          type: 'TASK_ASSIGNED',
          message: 'Task updated'
        });
      }
    } catch (socketErr) {
      console.error(
        'Socket emit error:',
        socketErr
      );
    }

    // =========================================================
    // 5. Response
    // =========================================================

    return res.json({
      success: true,
      message: 'Task updated safely without wiping existing data'
    });

  } catch (err) {
    console.error(
      'PUT /tasks/:id ERROR:',
      err.message
    );

    return res.status(500).json({
      success: false,
      message: err.message
    });
  }
});

// PATCH /api/tasks/:id/assign — toggle is_assigned
// PATCH /api/tasks/:id/assign — toggle is_assigned & trigger notification
router.patch('/:id/assign', async (req, res) => {
  const { isAssigned } = req.body;
  try {
    // 1. Task-oda current details-ah fetch pannunga (yar yaru antha task-la irukaanga nu paaka)
    const [existingRows] = await db.query(`SELECT * FROM task_assignments WHERE id = ?`, [req.params.id]);
    if (existingRows.length === 0) {
      return res.status(404).json({ success: false, message: 'Task not found' });
    }
    const task = existingRows[0];

    // 2. is_assigned status-ah database-la update pannunga
    const [result] = await db.query(
      `UPDATE task_assignments SET is_assigned=? WHERE id=?`,
      [isAssigned ? 1 : 0, req.params.id]
    );
    if (result.affectedRows === 0)
      return res.status(404).json({ success: false, message: 'Task not found' });

    // 3. User "ASSIGN" pandrapo mattum (isAssigned true-ah irunthal) notification send agum
    if (isAssigned) {
      const assignedByName = req.body.assignedByName || 'Admin';
      const clientName = task.client_name;

      const assignments = [
        { employeeName: task.designer,     tasks: task.designer_tasks },
        { employeeName: task.videographer, tasks: task.videographer_tasks },
        { employeeName: task.video_editor,  tasks: task.video_editor_task },
        { employeeName: task.ui_ux_designer, tasks: task.ui_ux_tasks },
        { employeeName: task.developer,    tasks: task.developer_tasks },
        { employeeName: task.ads_handling,  tasks: task.ads_platform },
        { employeeName: task.page_handling, tasks: task.pages_platform },
      ];

      for (const { employeeName, tasks } of assignments) {
        if (employeeName && employeeName.trim() !== '' && employeeName.toUpperCase() !== 'NONE') {
          try {
            await createNotification({
              senderName: assignedByName,
              recipientName: employeeName,
              message: JSON.stringify({
                preview: `${assignedByName} assigned you a new task for ${clientName}`,
                payload: {
                  type: "TASK_ASSIGNED",
                  sender: assignedByName,
                  recipient: employeeName,
                  client: clientName,
                  taskName: tasks || task.deliverables,
                }
              }),
            });
          } catch (notifyErr) {
            console.error('⚠️ task-assign notification failed:', notifyErr.message);
          }
        }
      }
    }

    const io = req.app.get("io");
    if (io) {
      io.emit("taskAssigned", { refresh: true });
      io.emit('task_updated', { type: 'TASK_ASSIGNED', message: 'Task assigned' });
    }

    return res.json({ success: true, message: 'Assignment toggled and notifications sent' });
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
    const io = req.app.get("io");

io.emit("taskAssigned", {
  refresh: true,
});
    return res.json({ success: true, message: 'Task deleted' });
  } catch (err) {
    console.error('DELETE /tasks/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;