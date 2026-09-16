'use strict';

require('dotenv').config();
const express = require('express');
const cors = require('cors');
const db = require('./config/db');
const { ensureAttendanceTables } = require('./lib/ensureAttendanceTables');
const { ensureAuthSchema } = require('./lib/ensureAuthSchema');
const { ensureHrmsEmployeeTables } = require('./lib/ensureHrmsEmployeeTables');
const { ensureHrmsTrackingTables } = require('./lib/ensureHrmsTrackingTables');
const attendancePolicy = require('./lib/attendancePolicy');
const { createApp: createEmployeeAttendanceApp } = require('./attendance/app');

const app = express();
const port = Number(process.env.PORT || 3000);

app.disable('x-powered-by');
app.use(cors());
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true }));

// The only retained feature area is Attendance. Authentication and the employee
// directory remain because attendance records are always tied to signed-in staff.
app.use('/api/auth', require('./routes/auth'));
app.use('/api/attendance', require('./routes/attendance'));
app.use('/api/attendance', createEmployeeAttendanceApp({
  pool: db,
  jwtSecret: process.env.JWT_SECRET || 'change-this-in-production',
  timeZone: process.env.ATTENDANCE_TIMEZONE || 'Asia/Kolkata',
  basePath: '',
}));
app.use('/api/hrms/employees', require('./routes/hrmsEmployees'));
app.use('/api/hrms/dashboard', require('./routes/hrmsDashboard'));
app.use('/api/hrms/approvals', require('./routes/hrmsApprovals'));
app.use('/api/hrms/payroll', require('./routes/hrmsPayroll'));
app.use('/api/hrms/tracking', require('./routes/hrmsTracking'));

app.get('/', (_req, res) => res.json({ status: 'ok', service: 'GoDigital Attendance API' }));
app.use((_req, res) => res.status(404).json({ success: false, message: 'Route not found' }));
app.use((error, _req, res, _next) => {
  console.error(error);
  res.status(500).json({ success: false, message: 'Internal server error' });
});

async function start() {
  await ensureAttendanceTables(db);
  await ensureAuthSchema(db);
  await attendancePolicy.getTimeSettings(db);
  await ensureHrmsEmployeeTables(db);
  await ensureHrmsTrackingTables(db);
  app.listen(port, () => console.log(`Attendance API running at http://localhost:${port}`));
}

start().catch((error) => {
  console.error('Attendance API could not start:', error.message);
  process.exitCode = 1;
});

module.exports = app;
