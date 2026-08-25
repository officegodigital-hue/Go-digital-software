require('dotenv').config();
const express = require('express');
const cors    = require('cors');

const cron = require('node-cron');
const db = require('./config/db');

// Run every month on the 1st day at midnight (00:00) to check and auto-assign active client tasks for the next month
cron.schedule('0 0 1 * *', async () => {
  console.log('🔄 Running Monthly Task Auto-Assignment Check...');
  try {
    const [activeTasks] = await db.query(`
      SELECT t.*, c.is_active 
      FROM task_assignments t
      JOIN clients c ON t.client_name = c.company_name
      WHERE t.is_assigned = 1 AND c.is_active = 1
    `);

    for (const task of activeTasks) {
      let currentDeadline = task.deadline ? new Date(task.deadline) : new Date();
      currentDeadline.setMonth(currentDeadline.getMonth() + 1);

      let currentMaintenance = task.maintenance_date ? new Date(task.maintenance_date) : new Date();
      currentMaintenance.setMonth(currentMaintenance.getMonth() + 1);

      await db.query(`
        INSERT INTO task_assignments (
          client_name, deliverables, maintenance_date, 
          ads_handling, ads_platform, ads_submit_date,
          page_handling, pages_platform, page_submit_date,
          designer, designer_tasks, designer_submit_date,
          videographer, videographer_tasks, videographer_submit_date,
          video_editor, video_editor_task, video_editor_submit_date,
          ui_ux_designer, ui_ux_tasks, ui_ux_submit_date,
          developer, developer_tasks, developer_submit_date,
          website_designer, website_designer_tasks, website_designer_submit_date,
          deadline, comments, is_assigned, assigned_by_name
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?)
      `, [
        task.client_name, task.deliverables, currentMaintenance,
        task.ads_handling, task.ads_platform, currentMaintenance,
        task.page_handling, task.pages_platform, currentMaintenance,
        task.designer, task.designer_tasks, currentMaintenance,
        task.videographer, task.videographer_tasks, currentMaintenance,
        task.video_editor, task.video_editor_task, currentMaintenance,
        task.ui_ux_designer, task.ui_ux_tasks, currentMaintenance,
        task.developer, task.developer_tasks, currentMaintenance,
        task.website_designer, task.website_designer_tasks, currentMaintenance,
        currentDeadline, task.comments, task.assigned_by_name
      ]);
    }
    console.log('✅ Monthly active client tasks auto-assigned successfully for the next month.');
  } catch (err) {
    console.error('❌ Auto-assignment cron error:', err.message);
  }
});

const http = require("http");
const { Server } = require("socket.io");

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