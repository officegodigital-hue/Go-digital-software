// routes/tasks.js — Task Assignments CRUD API
const express = require('express');
const router  = express.Router();
const db      = require('../config/db');
const { createNotification } = require('./notifications');


// const formatDate = (date) => {
//   if (!date || date.trim() === '' || date === '—') {
//     return null;
//   }
  
//   // If the date is already in YYYY-MM-DD format, return it
//   if (/^\d{4}-\d{2}-\d{2}$/.test(date)) {
//     return date;
//   }

//   // Convert DD/MM/YYYY to YYYY-MM-DD
//   if (date.includes('/')) {
//     const parts = date.split('/');
//     if (parts.length === 3) {
//       const day = parts[0].padStart(2, '0');
//       const month = parts[1].padStart(2, '0');
//       const year = parts[2];
//       return `${year}-${month}-${day}`;
//     }
//   }

//   return null;
// };

const formatDbDate = (date) => {
  if (!date || typeof date !== 'string' || date.trim() === '' || date === '—' || date === 'null') {
    return null;
  }
  if (/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    return date;
  }
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
  { employeeField: 'websiteDesigner', tasksField: 'websiteDesignerTasks',     label: 'website_designer_tasks_col' },
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

      case 'website designer':
case 'website designer task':
case 'website_designer':
case 'website_designer_task':
  employeeColumn = 'website_designer';
  taskColumn = 'website_designer_tasks';
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
    clientName, deliverables = '', adsHandling = '', adsPlatform = '', 
    pageHandling = '', pagesPlatform = '', 
    designer = '', designerTasks = '', 
    videographer = '', videographerTasks = '', 
    videoEditor = '', videoEditorTask = '', 
    uiUxDesigner = '', uiUxTasks = '', 
    developer = '', developerTasks = '', 
    websiteDesigner = '', websiteDesignerTasks = '', 
    deadline = '', maintenanceDate = '', comments = '', isAssigned = false,
    assignedByName = 'Admin',
  } = req.body;

  if (!clientName) return res.status(400).json({ success: false, message: 'clientName is required' });

  try {
    const io = req.app.get("io");
    const [result] = await db.query(
      `INSERT INTO task_assignments (client_name, deliverables, ads_handling, ads_platform, 
       page_handling, pages_platform, designer, designer_tasks, 
       videographer, videographer_tasks, 
       video_editor, video_editor_task, ui_ux_designer, ui_ux_tasks, 
       developer, developer_tasks,
       website_designer, website_designer_tasks,
       deadline, maintenance_date, comments, is_assigned) 
       VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
      [
        clientName,
        deliverables,
        adsHandling,
        adsPlatform,
        pageHandling,
        pagesPlatform,
        designer,
        designerTasks,
        videographer,
        videographerTasks,
        videoEditor,
        videoEditorTask,
        uiUxDesigner,
        uiUxTasks,
        developer,
        developerTasks,
        websiteDesigner,
        websiteDesignerTasks,
        // formatDate(deadline), // 👈 Deadline datetime format-ku format aagum
        formatDbDate(deadline), // 🟢 Updated to formatDbDate
        maintenanceDate,
        comments,
        isAssigned ? 1 : 0
      ]
    );

    // Notifications & socket code remains same...
    const [rows] = await db.query(
      `SELECT is_assigned FROM task_assignments WHERE id = ?`,
      [result.insertId]
    );

    if (rows.length && rows[0].is_assigned == 1) {
      const assignments = [
        { employeeName: designer,     tasks: designerTasks },
        { employeeName: videographer, tasks: videographerTasks },
        { employeeName: videoEditor,  tasks: videoEditorTask },
        { employeeName: uiUxDesigner, tasks: uiUxTasks },
        { employeeName: developer,    tasks: developerTasks },
        { employeeName: adsHandling,  tasks: adsPlatform },
        { employeeName: pageHandling, tasks: pagesPlatform },
        { employeeName: websiteDesigner, tasks: websiteDesignerTasks },
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
                  taskName: tasks || deliverables,
                }
              }),
            });
          } catch (notifyErr) {
            console.error('⚠️ task-assign notification failed:', notifyErr.message);
          }
        }
      }
    }

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

// // PUT /api/tasks/:id — update task safely
router.put('/:id', async (req, res) => {
  try {
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

    const keepExisting = (newValue, oldValue) => {
    //   if (
    //     newValue === undefined ||
    //     newValue === null ||
    //     (typeof newValue === 'string' && newValue.trim() === '')
    //   ) 
    //   {
    //     return oldValue;
    //   }
    //   return newValue;
    // };

    if (newValue === undefined) {
        return oldValue;
      }
      return newValue === null ? '' : newValue;
    };

    const keepExistingDate = (newValue, oldValue) => {
      if (
        newValue === undefined ||
        newValue === null ||
        (typeof newValue === 'string' && newValue.trim() === '')
      ) {
        return oldValue;
      }
      // const formatted = formatDate(newValue);
      const formatted = formatDbDate(newValue);
      if (!formatted) {
        return oldValue;
      }
      return formatted;
    };

    const clientName = keepExisting(req.body.clientName, existing.client_name);
    const deliverables = keepExisting(req.body.deliverables, existing.deliverables);

    const adsHandling = keepExisting(req.body.adsHandling, existing.ads_handling);
    const adsPlatform = keepExisting(req.body.adsPlatform, existing.ads_platform);

    const pageHandling = keepExisting(req.body.pageHandling, existing.page_handling);
    const pagesPlatform = keepExisting(req.body.pagesPlatform, existing.pages_platform);

    const designer = keepExisting(req.body.designer, existing.designer);
    const designerTasks = keepExisting(req.body.designerTasks, existing.designer_tasks);

    const videographer = keepExisting(req.body.videographer, existing.videographer);
    const videographerTasks = keepExisting(req.body.videographerTasks, existing.videographer_tasks);

    const videoEditor = keepExisting(req.body.videoEditor, existing.video_editor);
    const videoEditorTask = keepExisting(req.body.videoEditorTask, existing.video_editor_task);

    const uiUxDesigner = keepExisting(req.body.uiUxDesigner, existing.ui_ux_designer);
    const uiUxTasks = keepExisting(req.body.uiUxTasks, existing.ui_ux_tasks);

    const developer = keepExisting(req.body.developer, existing.developer);
    const developerTasks = keepExisting(req.body.developerTasks, existing.developer_tasks);

    const websiteDesigner = keepExisting(req.body.websiteDesigner, existing.website_designer);
    const websiteDesignerTasks = keepExisting(req.body.websiteDesignerTasks, existing.website_designer_tasks);

    const deadline = keepExistingDate(req.body.deadline, existing.deadline); // 👈 Deadline formatted datetime
    const maintenanceDate = keepExisting(req.body.maintenanceDate, existing.maintenance_date);
    const comments = keepExisting(req.body.comments, existing.comments);

    const isAssigned =
      req.body.isAssigned !== undefined
        ? (req.body.isAssigned ? 1 : 0)
        : existing.is_assigned;

    await db.query(
      `UPDATE task_assignments
       SET
         client_name=?,
         deliverables=?,
         ads_handling=?,
         ads_platform=?,
         page_handling=?,
         pages_platform=?,
         designer=?,
         designer_tasks=?,
         videographer=?,
         videographer_tasks=?,
         video_editor=?,
         video_editor_task=?,
         ui_ux_designer=?,
         ui_ux_tasks=?,
         developer=?,
         developer_tasks=?,
         website_designer=?,
         website_designer_tasks=?,
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
        pageHandling,
        pagesPlatform,
        designer,
        designerTasks,
        videographer,
        videographerTasks,
        videoEditor,
        videoEditorTask,
        uiUxDesigner,
        uiUxTasks,
        developer,
        developerTasks,
        websiteDesigner,
        websiteDesignerTasks,
        deadline,
        maintenanceDate,
        comments,
        isAssigned,
        req.params.id
      ]
    );
    
    // 🟢 NEW FIX: Oru task re-assign aagum pothu (e.g., designer, adsHandling, etc. mathum pothu),
    // antha task_assignment_id-kku link aana task_list table-la irukkira employee_name-aiyum update panrom
    // Ithanaala munnadi iruntha tracking rows & completed records puthu employee-ku transfer/retain aagum.
    const allAssignedEmployees = [
      adsHandling, pageHandling, designer, videographer, 
      videoEditor, uiUxDesigner, developer, websiteDesigner
    ].filter(emp => emp && emp.trim() !== '' && emp.toUpperCase() !== 'NONE');

    if (allAssignedEmployees.length > 0) {
      // Oru task-assignment row-la multiple roles irukalam, aana particular role-ku thakkatha task_list update aagum
      for (const empName of allAssignedEmployees) {
        await db.query(
          `UPDATE task_list 
           SET employee_name = ? 
           WHERE task_assignment_id = ?`,
          [empName, req.params.id]
        );
      }
    }
    
    try {
      const io = req.app.get('io');
      if (io) {
        io.emit('task_updated', {
          type: 'TASK_ASSIGNED',
          message: 'Task updated'
        });
      }
    } catch (socketErr) {
      console.error('Socket emit error:', socketErr);
    }

    return res.json({
      success: true,
      message: 'Task updated safely without submit dates'
    });

  } catch (err) {
    console.error('PUT /tasks/:id ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
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
        {  employeeName: task.website_designer,  tasks: task.website_designer_tasks},
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


// routes/tasks.js — Duplicate next month route
router.post('/:id/duplicate-next-month', async (req, res) => {
  try {
    const [rows] = await db.query(`SELECT * FROM task_assignments WHERE id = ?`, [req.params.id]);
    if (rows.length === 0) return res.status(404).json({ success: false, message: 'Task not found' });
    const task = rows[0];

    // Calculate next month dates safely
    let nextMaintenance = null;
    if (task.maintenance_date) {
      let parsedMaint = new Date(task.maintenance_date);
      if (!isNaN(parsedMaint.getTime())) {
        parsedMaint.setMonth(parsedMaint.getMonth() + 1);
        nextMaintenance = parsedMaint.toISOString().slice(0, 19).replace('T', ' ');
      } else {
        nextMaintenance = task.maintenance_date;
      }
    }

    let nextDeadline = task.deadline ? new Date(task.deadline) : new Date();
    if (!isNaN(nextDeadline.getTime())) {
      nextDeadline.setMonth(nextDeadline.getMonth() + 1);
    } else {
      nextDeadline = new Date();
      nextDeadline.setMonth(nextDeadline.getMonth() + 1);
    }

    const formatSqlDate = (d) => d instanceof Date ? d.toISOString().slice(0, 19).replace('T', ' ') : d;
    const formattedDeadlineStr = formatSqlDate(nextDeadline);

    // 🟢 Prevent manual duplicate if it already exists for the same deadline date
    const [existingNextCycle] = await db.query(`
      SELECT id FROM task_assignments 
      WHERE client_name = ? 
        AND deliverables = ? 
        AND deadline = ?
    `, [task.client_name, task.deliverables, formattedDeadlineStr]);

    if (existingNextCycle.length > 0) {
      return res.status(400).json({ 
        success: false, 
        message: 'A task for this next cycle deadline already exists!' 
      });
    }

    // Insert brand new active task for next cycle (is_assigned = 1)
    const [result] = await db.query(`
      INSERT INTO task_assignments (
        client_name, deliverables, maintenance_date, 
        ads_handling, ads_platform, 
        page_handling, pages_platform, 
        designer, designer_tasks, 
        videographer, videographer_tasks, 
        video_editor, video_editor_task, 
        ui_ux_designer, ui_ux_tasks, 
        developer, developer_tasks, 
        website_designer, website_designer_tasks, 
        deadline, comments, is_assigned
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)
    `, [
      task.client_name, 
      task.deliverables, 
      nextMaintenance,
      task.ads_handling, 
      task.ads_platform,
      task.page_handling, 
      task.pages_platform,
      task.designer, 
      task.designer_tasks,
      task.videographer, 
      task.videographer_tasks,
      task.video_editor, 
      task.video_editor_task,
      task.ui_ux_designer, 
      task.ui_ux_tasks,
      task.developer, 
      task.developer_tasks,
      task.website_designer, 
      task.website_designer_tasks,
      formattedDeadlineStr, 
      task.comments
    ]);

    const io = req.app.get('io');
    if (io) {
      io.emit('taskAssigned', { refresh: true });
      io.emit('task_updated', { type: 'TASK_ASSIGNED', message: 'New recurring task added' });
    }

    return res.status(201).json({ 
      success: true, 
      message: 'New next cycle task created successfully!', 
      newId: result.insertId 
    });
  } catch (err) {
    console.error('Duplicate next month error:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});


module.exports = router;