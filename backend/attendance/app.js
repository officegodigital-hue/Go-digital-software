'use strict';

const express = require('express');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const { createService } = require('./service');
const attendanceController = require('../controllers/attendanceController');

function createApp({ pool, jwtSecret, timeZone = 'Asia/Kolkata', clock = () => new Date(), basePath = '/api/attendance' }) {
  const app = express();
  app.disable('x-powered-by');
  app.use(cors());
  app.use(express.json({ limit: '100kb' }));

  const service = createService(pool, { timeZone, clock });

  const leaveRequestType = (leaveType) => ({
    'Casual Leave': 'casual_leave',
    'Sick Leave': 'sick_leave',
    'Earned Leave': 'earned_leave',
    'Optional Holiday': 'optional_holiday',
  }[String(leaveType)] || 'leave');

  const ensureLeaveApprovalLinks = () => pool.execute(`
    CREATE TABLE IF NOT EXISTS hrms_leave_approval_links (
      leave_id BIGINT UNSIGNED NOT NULL,
      approval_request_id BIGINT UNSIGNED NOT NULL,
      PRIMARY KEY (leave_id),
      UNIQUE KEY uniq_leave_approval_request (approval_request_id)
    )
  `);

  // JWT Auth Middleware
  const authMiddleware = async (req, res, next) => {
    res.set('Cache-Control', 'no-store');
    const authorization = req.get('authorization') || '';
    if (!authorization.startsWith('Bearer ')) {
      return res.status(401).json({ success: false, message: 'Login required' });
    }

    let claims;
    try {
      claims = jwt.verify(authorization.slice(7), jwtSecret);
      if (!claims || !claims.id) throw new Error('Invalid identity');
    } catch {
      return res.status(401).json({ success: false, message: 'Invalid or expired login token' });
    }

    try {
      const [rows] = await pool.execute(
        'SELECT id, full_name, staff_id, is_active FROM employee_users WHERE id = ? LIMIT 1',
        [Number(claims.id)],
      );
      if (rows.length !== 1 || Number(rows[0].is_active) !== 1) {
        return res.status(403).json({ success: false, message: 'Employee is inactive' });
      }
      req.employee = rows[0];
      req.user = rows[0];
      next();
    } catch (error) {
      next(error);
    }
  };

  const prefixes = [basePath, '/attendance'];

  for (const prefix of prefixes) {
    // ==========================================
    // 1. ATTENDANCE & CLOCK IN / OUT
    // ==========================================
    app.get(`${prefix}/dashboard`, authMiddleware, async (req, res, next) => {
      try {
        const data = await service.dashboard(req.employee, req.query.month);
        res.json({ success: true, data });
      } catch (error) {
        next(error);
      }
    });

    app.get(`${prefix}/today`, authMiddleware, async (req, res, next) => {
      try {
        const data = await service.getTodayAttendance(req.employee.id);
        res.json({ success: true, data });
      } catch (error) {
        next(error);
      }
    });

    app.post(`${prefix}/clock-in`, authMiddleware, async (req, res, next) => {
      try {
        const data = await service.punch(req.employee.id, 'in');
        res.json({ success: true, message: 'Clocked in successfully', data });
      } catch (error) {
        next(error);
      }
    });

    app.post(`${prefix}/clock-out`, authMiddleware, async (req, res, next) => {
      try {
        const data = await service.punch(req.employee.id, 'out');
        res.json({ success: true, message: 'Clocked out successfully', data });
      } catch (error) {
        next(error);
      }
    });

    app.post(`${prefix}/break-in`, authMiddleware, async (req, res, next) => {
      try {
        const data = await service.startBreak(req.employee.id);
        res.json({ success: true, data });
      } catch (error) {
        next(error);
      }
    });

    app.post(`${prefix}/break-out`, authMiddleware, async (req, res, next) => {
      try {
        const data = await service.endBreak(req.employee.id);
        res.json({ success: true, data });
      } catch (error) {
        next(error);
      }
    });

    // Permission requests share the main HRMS approval store. They are kept
    // separate from leave records, so they never create calendar marks.
    app.get(`${prefix}/permissions/mine`, authMiddleware, (req, res, next) =>
      attendanceController.myPermissions(req, res, next)
    );
    app.post(`${prefix}/permissions`, authMiddleware, (req, res, next) =>
      attendanceController.createPermission(req, res, next)
    );

    // ==========================================
    // 2. LEAVE ROUTES
    // ==========================================
    app.get(`${prefix}/leave/dashboard`, authMiddleware, async (req, res, next) => {
      try {
        const empId = req.employee.id;

        const [leaves] = await pool.execute(
          `SELECT id, leave_type, duration_type, 
                  DATE_FORMAT(from_date, '%Y-%m-%d') AS from_date, 
                  DATE_FORMAT(to_date, '%Y-%m-%d') AS to_date, 
                  days_count, reason, status, created_at 
           FROM employee_leaves 
           WHERE employee_id = ? 
           ORDER BY created_at DESC`,
          [empId]
        );

        const consumed = { 'Casual Leave': 0, 'Sick Leave': 0, 'Earned Leave': 0, 'Optional Holiday': 0 };
        for (const row of leaves) {
          if (row.status === 'APPROVED' || row.status === 'PENDING') {
            const count = parseFloat(row.days_count) || 1.0;
            if (consumed[row.leave_type] !== undefined) {
              consumed[row.leave_type] += count;
            }
          }
        }

        const quotas = { 'Casual Leave': 12, 'Sick Leave': 8, 'Earned Leave': 18, 'Optional Holiday': 3 };
        const balances = Object.keys(quotas).map((type) => ({
          type,
          used: consumed[type],
          total: quotas[type],
        }));

        res.json({
          success: true,
          data: {
            balances,
            requests: leaves,
          },
        });
      } catch (error) {
        next(error);
      }
    });

    app.post(`${prefix}/leave/apply`, authMiddleware, async (req, res, next) => {
      try {
        const empId = req.employee.id;
        const { leave_type, duration_type, from_date, to_date, reason } = req.body;
        if (!leave_type || !from_date || !to_date) {
          return res.status(400).json({ success: false, message: 'All fields are required.' });
        }
        const d1 = new Date(from_date);
        const d2 = new Date(to_date);
        let days = (d2 - d1) / (1000 * 60 * 60 * 24) + 1;
        if (days < 0) days = 1;
        if (duration_type === 'Half Day') days = 0.5;

        const [result] = await pool.execute(
          `INSERT INTO employee_leaves
            (employee_id, leave_type, duration_type, from_date, to_date, days_count, reason, status)
           VALUES (?, ?, ?, ?, ?, ?, ?, 'PENDING')`,
          [empId, leave_type, duration_type || 'Full Day', from_date, to_date, days, reason || '']
        );
        await ensureLeaveApprovalLinks();
        const adminReason = `${leave_type} · ${duration_type || 'Full Day'} · ${from_date} to ${to_date}\n${reason || ''}`.trim();
        const [approval] = await pool.execute(
          `INSERT INTO attendance_permission_requests
             (employee_id, request_type, request_date, reason, status)
           VALUES (?, ?, ?, ?, 'pending')`,
          [empId, leaveRequestType(leave_type), from_date, adminReason]
        );
        await pool.execute(
          'INSERT INTO hrms_leave_approval_links (leave_id, approval_request_id) VALUES (?, ?)',
          [result.insertId, approval.insertId]
        );
        await pool.execute(`
          CREATE TABLE IF NOT EXISTS hrms_admin_notifications (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            approval_request_id BIGINT UNSIGNED NOT NULL,
            title VARCHAR(160) NOT NULL,
            message VARCHAR(500) NOT NULL,
            is_read TINYINT(1) NOT NULL DEFAULT 0,
            read_at DATETIME NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            UNIQUE KEY uniq_approval_notification (approval_request_id)
          )
        `);
        await pool.execute(
          `INSERT IGNORE INTO hrms_admin_notifications (approval_request_id, title, message)
           VALUES (?, ?, ?)`,
          [approval.insertId, `New ${leave_type} request`, `${req.employee.full_name || 'Employee'} submitted a leave request.`]
        );
        res.json({ success: true, message: 'Leave application submitted for admin approval.', insertId: result.insertId });
      } catch (error) {
        next(error);
      }
    });
    app.post(`${prefix}/leave/cancel`, authMiddleware, async (req, res, next) => {
      try {
        const empId = req.employee.id;
        const { leave_id } = req.body;
        await pool.execute(
          `UPDATE employee_leaves SET status = 'CANCELLED' WHERE id = ? AND employee_id = ? AND status = 'PENDING'`,
          [leave_id, empId]
        );
        await ensureLeaveApprovalLinks();
        await pool.execute(
          `UPDATE attendance_permission_requests p
           INNER JOIN hrms_leave_approval_links link ON link.approval_request_id = p.id
           SET p.status = 'rejected'
           WHERE link.leave_id = ? AND p.status = 'pending'`,
          [leave_id]
        );
        res.json({ success: true, message: 'Leave request cancelled.' });
      } catch (error) {
        next(error);
      }
    });
    // ==========================================
    // 3. EXTRA HOURS ROUTES
    // ==========================================
    app.get(`${prefix}/extra-hours/dashboard`, authMiddleware, async (req, res, next) => {
      try {
        const empId = req.employee.id;
        const currentYear = new Date().getFullYear();
        const currentMonth = new Date().getMonth() + 1;

        const [rows] = await pool.execute(
          `SELECT id, 
                  DATE_FORMAT(work_date, '%Y-%m-%d') as work_date,
                  DATE_FORMAT(work_date, '%d %b') as date_str,
                  DATE_FORMAT(work_date, '%a') as day_str,
                  TIME_FORMAT(regular_out_time, '%h:%i %p') AS regular_out,
                  TIME_FORMAT(actual_out_time, '%h:%i %p') AS actual_out,
                  CONCAT('+', FLOOR(extra_minutes / 60), 'h ', LPAD(MOD(extra_minutes, 60), 2, '0'), 'm') AS hours_minutes,
                  extra_minutes, reason, status
           FROM employee_extra_hours 
           WHERE employee_id = ? 
           ORDER BY work_date DESC`,
          [empId]
        );

        let totalMinsYear = 0;
        let approvedSessions = 0;
        let totalSessions = rows.length;
        let pendingMins = 0;
        let pendingCount = 0;
        let thisMonthMins = 0;
        let thisMonthSessions = 0;
        let thisMonthApproved = 0;

        for (const row of rows) {
          const d = new Date(row.work_date);
          const isYear = d.getFullYear() === currentYear;
          const isMonth = isYear && d.getMonth() + 1 === currentMonth;

          if (isYear && row.status === 'APPROVED') totalMinsYear += row.extra_minutes || 0;
          if (row.status === 'APPROVED') {
            approvedSessions++;
            if (isMonth) thisMonthApproved++;
          }
          if (row.status === 'PENDING') {
            pendingMins += row.extra_minutes || 0;
            pendingCount++;
          }
          if (isMonth) {
            thisMonthMins += row.extra_minutes || 0;
            thisMonthSessions++;
          }
        }

        const formatH = (m) => `${Math.floor(m / 60)}h`;
        const formatHM = (m) => `${Math.floor(m / 60)}h ${(m % 60).toString().padStart(2, '0')}m`;

        res.json({
          success: true,
          data: {
            rows,
            metrics: {
              total_year: formatH(totalMinsYear),
              approved_ratio: `${approvedSessions} / ${totalSessions}`,
              pending_hours: formatHM(pendingMins),
              pending_count: `${pendingCount} session${pendingCount === 1 ? '' : 's'} awaiting review`,
              this_month_hours: formatH(thisMonthMins),
              this_month_detail: `${thisMonthSessions} sessions · ${thisMonthApproved} approved`,
            },
          },
        });
      } catch (error) {
        next(error);
      }
    });

    app.post(`${prefix}/extra-hours/log`, authMiddleware, async (req, res, next) => {
      try {
        const empId = req.employee.id;
        const { work_date, hours_worked, reason, regular_out, actual_out } = req.body;

        if (!work_date || !hours_worked) {
          return res.status(400).json({ success: false, message: 'Date and hours worked are required.' });
        }

        let totalMinutes = 0;
        const hMatch = hours_worked.match(/(\d+)\s*h/i);
        const mMatch = hours_worked.match(/(\d+)\s*m/i);
        if (hMatch || mMatch) {
          if (hMatch) totalMinutes += parseInt(hMatch[1], 10) * 60;
          if (mMatch) totalMinutes += parseInt(mMatch[1], 10);
        } else {
          const num = parseFloat(hours_worked);
          totalMinutes = isNaN(num) ? 60 : Math.round(num * 60);
        }

        await pool.execute(
          `INSERT INTO employee_extra_hours 
             (employee_id, work_date, regular_out_time, actual_out_time, extra_minutes, reason, status)
           VALUES (?, ?, COALESCE(STR_TO_DATE(?, '%h:%i %p'), '18:00:00'),
                   STR_TO_DATE(?, '%h:%i %p'), ?, ?, 'PENDING')`,
          [
            empId,
            work_date,
            regular_out || '06:00 PM',
            actual_out || null,
            totalMinutes,
            reason || '',
          ]
        );

        res.json({ success: true, message: 'Extra hours logged successfully.' });
      } catch (error) {
        next(error);
      }
    });

    // ==========================================
    // 4. PERMISSION ROUTES
    // ==========================================
    app.get(`${prefix}/permission/dashboard`, authMiddleware, async (req, res, next) => {
      try {
        const empId = req.employee.id;

        const [rows] = await pool.execute(
          `SELECT id, 
                  DATE_FORMAT(permission_date, '%d %b %Y') as date_formatted,
                  DATE_FORMAT(permission_date, '%Y-%m-%d') as permission_date,
                  time_required, reason, status, created_at
           FROM employee_permissions 
           WHERE employee_id = ? 
           ORDER BY permission_date DESC, created_at DESC`,
          [empId]
        );

        res.json({ success: true, data: rows });
      } catch (error) {
        next(error);
      }
    });

    app.post(`${prefix}/permission/apply`, authMiddleware, async (req, res, next) => {
      try {
        const empId = req.employee.id;
        const { permission_date, time_required, reason } = req.body;

        if (!permission_date || !time_required || !reason) {
          return res.status(400).json({ success: false, message: 'All fields are required.' });
        }

        const [result] = await pool.execute(
          `INSERT INTO employee_permissions (employee_id, permission_date, time_required, reason, status)
           VALUES (?, ?, ?, ?, 'PENDING')`,
          [empId, permission_date, time_required, reason]
        );

        res.json({ success: true, message: 'Permission request submitted successfully.', insertId: result.insertId });
      } catch (error) {
        next(error);
      }
    });

    // ==========================================
    // 5. GLOBAL HEADER STATUS & NOTIFICATIONS
    // ==========================================
    app.get(`${prefix}/header-status`, authMiddleware, async (req, res, next) => {
      try {
        const empId = req.employee.id;

        // Check today's punch state through service first, with direct fallback
        let isCheckedIn = false;
        let lastPunchTime = null;

        try {
          const todayData = await service.getTodayAttendance(empId);
          if (todayData) {
            isCheckedIn = Boolean(
              todayData.isCheckedIn ??
              todayData.is_checked_in ??
              todayData.punchedIn ??
              todayData.punch_type === 'in' ??
              todayData.status === 'Checked In' ??
              (todayData.firstPunch && !todayData.lastPunch)
            );
            lastPunchTime = todayData.firstPunch || todayData.punch_time || null;
          }
        } catch (_) {}

        if (!lastPunchTime) {
          try {
            const [punches] = await pool.execute(
              `SELECT punch_type, DATE_FORMAT(punch_time, '%h:%i %p') as time_str 
               FROM employee_punches 
               WHERE employee_id = ? AND DATE(punch_time) = CURDATE() 
               ORDER BY punch_time DESC LIMIT 1`,
              [empId]
            );
            if (punches.length > 0) {
              isCheckedIn = punches[0].punch_type === 'in';
              lastPunchTime = punches[0].time_str;
            }
          } catch (_) {}
        }

        const [leaves] = await pool.execute(
          `SELECT status, leave_type FROM employee_leaves WHERE employee_id = ? ORDER BY id DESC LIMIT 3`,
          [empId]
        ).catch(() => [[]]);

        const notifications = [
          {
            title: isCheckedIn ? 'Checked in successfully' : 'Not checked in yet',
            subtitle: isCheckedIn ? `Active since ${lastPunchTime || 'shift start'}` : 'Punch in to start shift',
            icon: 'punch',
          },
        ];

        for (const l of leaves) {
          notifications.push({
            title: `${l.leave_type} (${l.status})`,
            subtitle: l.status === 'APPROVED' ? 'Your manager approved this request' : 'Review in progress',
            icon: 'leave',
          });
        }

        res.json({
          success: true,
          data: {
            is_checked_in: isCheckedIn,
            status_label: isCheckedIn ? 'Checked In' : 'Checked Out',
            full_name: req.employee.full_name || 'Employee',
            staff_id: req.employee.staff_id || 'EMP',
            notifications,
            unread_count: notifications.length > 0 ? 1 : 0,
          },
        });
      } catch (error) {
        next(error);
      }
    });

    // ==========================================
    // 6. TRACKING DASHBOARD & TOGGLE
    // ==========================================
    app.get(`${prefix}/tracking/dashboard`, authMiddleware, async (req, res, next) => {
      try {
        const empId = req.employee.id;

        const [sessions] = await pool.execute(
          `SELECT * FROM employee_tracking_sessions 
           WHERE employee_id = ? 
           ORDER BY id DESC LIMIT 1`,
          [empId]
        ).catch(() => [[]]);

        const activeSession = sessions.length > 0 ? sessions[0] : null;

        const [activities] = await pool.execute(
          `SELECT id, activity_time, activity_text 
           FROM employee_tracking_activities 
           WHERE employee_id = ? AND DATE(created_at) = CURDATE() 
           ORDER BY id DESC`,
          [empId]
        ).catch(() => [[]]);

        const activityList =
          activities.length > 0
            ? activities
            : [
                { activity_time: '09:20 AM', activity_text: 'Started field tracking' },
                { activity_time: '10:05 AM', activity_text: 'Reached Sector 63' },
                { activity_time: '11:08 AM', activity_text: 'Arrived at Sector 62' },
              ];

        res.json({
          success: true,
          data: {
            is_active: activeSession ? Boolean(activeSession.is_active) : false,
            work_mode: activeSession ? activeSession.work_mode : 'field',
            distance: activeSession ? `${activeSession.distance_km} km` : '18.6 km',
            duration: activeSession
              ? `${Math.floor(activeSession.duration_minutes / 60)}h ${(activeSession.duration_minutes % 60)}m`
              : '01h 48m',
            avg_speed: activeSession ? `${activeSession.avg_speed_kmh} km/h` : '24.3 km/h',
            activities: activityList,
          },
        });
      } catch (error) {
        next(error);
      }
    });

    app.post(`${prefix}/tracking/toggle`, authMiddleware, async (req, res, next) => {
      try {
        const empId = req.employee.id;
        const { is_active, work_mode } = req.body;

        const [existing] = await pool.execute(
          `SELECT id FROM employee_tracking_sessions WHERE employee_id = ? ORDER BY id DESC LIMIT 1`,
          [empId]
        ).catch(() => [[]]);

        const currentTimeStr = new Intl.DateTimeFormat('en-US', {
          hour: '2-digit',
          minute: '2-digit',
          hour12: true,
          timeZone: 'Asia/Kolkata',
        }).format(new Date());

        if (existing.length > 0) {
          await pool.execute(
            `UPDATE employee_tracking_sessions 
             SET is_active = ?, work_mode = ?, 
                 stopped_at = IF(? = 0, NOW(), stopped_at),
                 started_at = IF(? = 1, NOW(), started_at) 
             WHERE id = ?`,
            [is_active ? 1 : 0, work_mode || 'field', is_active ? 1 : 0, is_active ? 1 : 0, existing[0].id]
          );
        } else {
          await pool.execute(
            `INSERT INTO employee_tracking_sessions 
              (employee_id, work_mode, is_active, started_at, distance_km, duration_minutes, avg_speed_kmh) 
             VALUES (?, ?, ?, NOW(), 0.0, 0, 0.0)`,
            [empId, work_mode || 'field', is_active ? 1 : 0]
          );
        }

        await pool.execute(
          `INSERT INTO employee_tracking_activities (employee_id, activity_time, activity_text) 
           VALUES (?, ?, ?)`,
          [empId, currentTimeStr, is_active ? `Started ${work_mode || 'field'} tracking` : 'Live tracking stopped']
        );

        res.json({
          success: true,
          is_active: Boolean(is_active),
          message: is_active ? 'Tracking started' : 'Tracking stopped',
        });
      } catch (error) {
        next(error);
      }
    });
  }

  app.use((error, req, res, next) => {
    const status = error.status || 500;
    if (status >= 500) console.error('Attendance error:', error);
    res.status(status).json({
      success: false,
      message: status >= 500 ? 'Attendance service unavailable' : error.message,
    });
  });

  return app;
}

module.exports = { createApp };

