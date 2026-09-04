require('dotenv').config();
const express = require('express');
const cors    = require('cors');
const http    = require('http');
const { Server } = require("socket.io");
const cron = require('node-cron');
const db = require('./config/db');

// Run every day at midnight (00:00) to check expired tasks and auto-create next cycle once per deadline
cron.schedule('0 0 * * *', async () => {
  console.log('🔄 Running Daily Task Auto-Rollover & Next Cycle Check...');
  try {
    const [expiredTasks] = await db.query(`
      SELECT * FROM task_assignments 
      WHERE is_assigned = 1 
        AND deadline IS NOT NULL 
        AND DATE(deadline) < CURDATE()
    `);

    console.log(`📌 Found ${expiredTasks.length} expired task(s) for auto-rollover check.`);

    for (const task of expiredTasks) {
      // 🟢 Calculate next cycle dates (adding 1 month to maintenance & deadline)
      let nextMaintenance = task.maintenance_date ? new Date(task.maintenance_date) : new Date();
      if (!isNaN(nextMaintenance.getTime())) {
        nextMaintenance.setMonth(nextMaintenance.getMonth() + 1);
      } else {
        nextMaintenance = new Date();
        nextMaintenance.setMonth(nextMaintenance.getMonth() + 1);
      }

      let nextDeadline = task.deadline ? new Date(task.deadline) : new Date();
      if (!isNaN(nextDeadline.getTime())) {
        nextDeadline.setMonth(nextDeadline.getMonth() + 1);
      } else {
        nextDeadline = new Date();
        nextDeadline.setMonth(nextDeadline.getMonth() + 1);
      }

      const formatSqlDate = (d) => d instanceof Date ? d.toISOString().slice(0, 19).replace('T', ' ') : d.toISOString().slice(0, 19).replace('T', ' ');

      // 🟢 Check if next cycle task already exists for this client and deliverables to prevent daily spamming
      const [existingNextCycle] = await db.query(`
        SELECT id FROM task_assignments 
        WHERE client_name = ? 
          AND deliverables = ? 
          AND deadline = ?
      `, [task.client_name, task.deliverables, formatSqlDate(nextDeadline)]);

      // Oru vela antha next cycle deadline-ku task illaiyendraal mattum, auto-assign seyyum (Once only)
      if (existingNextCycle.length === 0) {
        await db.query(`
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
          formatSqlDate(nextMaintenance),
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
          formatSqlDate(nextDeadline), 
          task.comments
        ]);
        console.log(`✅ Auto-created next cycle task for client: ${task.client_name}`);
      }
    }
    console.log('✅ Expired tasks automatic rollover process completed.');
  } catch (err) {
    console.error('❌ Automatic rollover cron error:', err.message);
  }
});




const employeeRoutes = require('./routes/employees');
const timingRoutes    = require('./routes/timings'); 
const clientRoutes     = require('./routes/clients');        
const credentialRoutes = require('./routes/credentials'); 
const packageRoutes    = require('./routes/packages');   
const quotationRoutes  = require('./routes/quotations');
const invoiceRoutes    = require('./routes/invoices'); 
const taskRoutes       = require('./routes/tasks');  
const authRoutes = require('./routes/auth');
const employeeTaskRoutes  = require('./routes/employee-tasks'); 
const dailyReportsRouter = require('./routes/daily-reports');
const taskPlannerRoutes   = require('./routes/task-planner');   
const videographerPlannerRoutes = require('./routes/videographer-planner');
const feedbackRoutes = require('./routes/feedback'); 
const taskMasterRoutes = require('./routes/task-master');
const taskRolesRoutes = require('./routes/task-roles');
const taskListRoutes = require('./routes/task-list');
const trackingItemsRoutes = require('./routes/tracking-items');
const dashboardRoutes = require('./routes/dashboard');
const adminEmployeeStatusRoutes = require('./routes/admin-employee-status');
const notificationsRoutes = require('./routes/notifications');

const DayPlannerRoutes = require('./routes/day-planner');
const performanceRoutes = require('./routes/performance');
const app  = express();
const PORT = process.env.PORT || 3000;

// ── 1. Create HTTP Server & Initialize Socket.io ─────────────────────────────
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE"]
  }
});

app.set('io', io);

io.on('connection', (socket) => {
  console.log(`⚡ A user connected: ${socket.id}`);

  socket.on('disconnect', () => {
    console.log(`🔌 User disconnected: ${socket.id}`);
  });
});

// ── CORS middleware ──────────────────────────────────────────────────────────
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin',  '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  
  if (req.method === 'OPTIONS') {
    return res.sendStatus(200);
  }
  next();
});

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// ✅ Duplicate `const db` removed from here!
require('./jobs/day-planner-reminders')(db);

// ── Routes ────────────────────────────────────────────────────────────────────
app.use('/api/employees', employeeRoutes);
app.use('/api/timings', timingRoutes);
app.use('/api/clients', clientRoutes);
app.use('/api/credentials', credentialRoutes);
app.use('/api/packages', packageRoutes);
app.use('/api/quotations', quotationRoutes);
app.use('/api/invoices', invoiceRoutes); 
app.use('/api/tasks', taskRoutes);
app.use('/api/auth', authRoutes);
app.use('/api/employee-tasks', employeeTaskRoutes); 
app.use('/api/daily-reports', dailyReportsRouter);
app.use('/api/task-planner',   taskPlannerRoutes); 
app.use('/api/videographer-planner', videographerPlannerRoutes); 
app.use('/api/feedback', feedbackRoutes); 
app.use('/api/task-master', taskMasterRoutes);
app.use('/api/task-roles', taskRolesRoutes);
app.use('/api/task-list', taskListRoutes);
app.use('/api/tracking-items', trackingItemsRoutes);
app.use('/api/dashboard', dashboardRoutes);
app.use('/api/admin', adminEmployeeStatusRoutes);
app.use('/api/manager-review', require('./routes/manager-review'));
app.use('/api/notifications', notificationsRoutes);
app.use('/api/day-planner', DayPlannerRoutes); 
app.use('/api/performance', performanceRoutes);

// Health check
app.get('/', (req, res) => {
  res.json({ message: 'GoDigital API is running', status: 'ok' });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ success: false, message: 'Route not found' });
});

// Global error handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ success: false, message: 'Internal server error' });
});

server.listen(PORT, () => {
  console.log(`GoDigital API running at http://localhost:${PORT}`);
  console.log(`✅ Socket.io server is active and running`);
});