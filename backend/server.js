require('dotenv').config();
const express = require('express');
const cors    = require('cors');
const cron = require("node-cron");

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
// const taskActionsRoutes = require('./routes/task-actions');
const dashboardRoutes = require('./routes/dashboard');
const adminEmployeeStatusRoutes = require('./routes/admin-employee-status');
const notificationsRoutes = require('./routes/notifications');

const DayPlannerRoutes = require('./routes/day-planner'); // Import the new route

const app  = express();
const PORT = process.env.PORT || 3000;

// ── CORS middleware — handles ALL methods including preflight ─────────────────
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

const db = require('./config/db');
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
// app.use('/api/task-actions', taskActionsRoutes);
app.use('/api/dashboard', dashboardRoutes);
app.use('/api/admin', adminEmployeeStatusRoutes);
app.use('/api/manager-review', require('./routes/manager-review'));
app.use('/api/notifications', notificationsRoutes);
app.use('/api/day-planner', DayPlannerRoutes); // Use the new route
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

app.listen(PORT, () => {
  console.log(`GoDigital API running at http://localhost:${PORT}`);
  console.log(`✅ Task tracking endpoints available at http://localhost:${PORT}/api/task-tracking`);
  console.log(`✅ Action logging endpoints available at http://localhost:${PORT}/api/task-actions`);
});