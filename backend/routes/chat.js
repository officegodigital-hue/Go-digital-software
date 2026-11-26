// routes/chat.js

const express = require('express');
const router = express.Router();
const db = require('../config/db');

const meetingSync = require('../lib/meetingSync');
const { refreshMeetingSchedules } = require('../jobs/meeting-scheduler');

const multer = require('multer');
const fs = require('fs');
const path = require('path');

// ============================================================
// FILE UPLOAD CONFIGURATION
// ============================================================

const uploadDir = path.join(__dirname, '..', 'uploads', 'chat');

// Automatically create folder if it doesn't exist
fs.mkdirSync(uploadDir, { recursive: true });

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const safeOriginalName = path
      .basename(file.originalname)
      .replace(/[^a-zA-Z0-9._-]/g, '_');

    const uniqueName = `${Date.now()}-${Math.round(Math.random() * 1e9)}-${safeOriginalName}`;

    cb(null, uniqueName);
  }
});

const upload = multer({
  storage,
  limits: {
    fileSize: 10 * 1024 * 1024 // 10 MB limit matching frontend validation
  },
  fileFilter: (req, file, cb) => {
    // Accept standard document types or fallback based on extensions if mimetype is generic/empty
    const allowedMimes = [
      'application/pdf',
      'application/x-pdf',
      'text/csv',
      'text/plain',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.ms-powerpoint',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'image/jpeg',
      'image/png',
      'application/octet-stream' // often sent by browsers for binary formats
    ];

    if (allowedMimes.includes(file.mimetype) || !file.mimetype) {
      cb(null, true);
    } else {
      cb(new Error('Invalid file type! Only PDF, CSV, PPT, PPTX, DOC and DOCX files are allowed.'));
    }
  }
});

// ============================================================
// HELPER FUNCTIONS
// ============================================================

async function createNotification({ senderName, recipientName, message }) {
  await db.query(
    `
      INSERT INTO notifications
      (sender_name, recipient_name, message)
      VALUES (?, ?, ?)
    `,
    [senderName, recipientName, message]
  );
}

function formatTime(dateVal) {
  if (!dateVal) return '';

  const created = new Date(dateVal);
  const now = new Date();

  const createdDateOnly = new Date(
    created.getFullYear(),
    created.getMonth(),
    created.getDate()
  );

  const nowDateOnly = new Date(
    now.getFullYear(),
    now.getMonth(),
    now.getDate()
  );

  const diffDays = Math.floor(
    (nowDateOnly.getTime() - createdDateOnly.getTime()) / (1000 * 60 * 60 * 24)
  );

  if (diffDays === 0) {
    return created.toLocaleTimeString('en-IN', {
      timeZone: 'Asia/Kolkata',
      hour: 'numeric',
      minute: '2-digit',
      hour12: true
    });
  }

  if (diffDays === 1) {
    return 'Yesterday';
  }

  if (diffDays < 7) {
    return created.toLocaleDateString('en-IN', {
      timeZone: 'Asia/Kolkata',
      weekday: 'long'
    });
  }

  const dd = created.getDate().toString().padStart(2, '0');
  const mm = (created.getMonth() + 1).toString().padStart(2, '0');
  const yy = created.getFullYear();

  return `${dd}/${mm}/${yy}`;
}

function buildAttachment(req, file) {
  if (!file) return null;

  return {
    name: file.originalname,
    fileName: file.filename,
    mimeType: file.mimetype,
    size: file.size,
    url: `/uploads/chat/${file.filename}`,
    fileUrl: `/uploads/chat/${file.filename}`
  };
}

// ============================================================
// API ROUTES
// ============================================================

// 1. GET /api/chat/:employeeName
router.get('/:employeeName', async (req, res) => {
  const { employeeName } = req.params;

  try {
    // PINNED CHATS
    let pinnedChats = [];
    try {
      const [pinRows] = await db.query(
        `
        SELECT
          id,
          owner_name,
          target_name,
          is_group,
          pinned,
          created_at
        FROM chat_pins
        WHERE owner_name = ?
          AND pinned = 1
        ORDER BY created_at DESC
        `,
        [employeeName]
      );

      pinnedChats = pinRows.map((p) => ({
        id: p.id,
        ownerName: p.owner_name,
        targetName: p.target_name,
        isGroup: !!p.is_group,
        pinned: !!p.pinned,
        createdAt: p.created_at,
      }));
    } catch (pinError) {
      console.error('GET pinnedChats ERROR:', pinError.message);
      pinnedChats = [];
    }

    // MESSAGES (FETCH ROWS FIRST SO IT IS AVAILABLE FOR CHAT LIST)
    const [rows] = await db.query(
      `
      SELECT *
      FROM notifications
      WHERE
        sender_name = ?
        OR recipient_name = ?
        OR is_group = 1
      ORDER BY created_at DESC
      `,
      [employeeName, employeeName]
    );

    // ============================================================
    // CHAT LIST / LAST CHAT TIME
    // WhatsApp-style conversation ordering
    // ============================================================

    let chatList = [];

    try {
      const chatMap = new Map();

      for (const r of rows) {
        const isGroup = !!r.is_group;
        let targetName = null;

        if (isGroup) {
          targetName = r.recipient_name;
        } else {
          if (r.sender_name === employeeName) {
            targetName = r.recipient_name;
          } else if (r.recipient_name === employeeName) {
            targetName = r.sender_name;
          }
        }

        if (!targetName) continue;

        const key = `${isGroup ? 'group' : 'user'}:${targetName}`;
        const existing = chatMap.get(key);
        const currentDate = new Date(r.created_at);

        if (
          !existing ||
          currentDate.getTime() > new Date(existing.lastChatAt).getTime()
        ) {
          chatMap.set(key, {
            targetName,
            isGroup,
            lastMessage: r.message || '',
            lastChatAt: r.created_at,
            lastChatTime: formatTime(r.created_at),
            lastMessageId: r.id,
            lastSenderName: r.sender_name,
            isSeen: !!r.is_seen,
            seenAt: r.seen_at || null,
          });
        }
      }

      chatList = Array.from(chatMap.values());

      const pinnedMap = new Map();
      for (const pin of pinnedChats) {
        const key = `${pin.isGroup ? 'group' : 'user'}:${pin.targetName}`;
        pinnedMap.set(key, true);
      }

      chatList = chatList.map((chat) => {
        const key = `${chat.isGroup ? 'group' : 'user'}:${chat.targetName}`;
        return {
          ...chat,
          isPinned: pinnedMap.get(key) === true,
        };
      });

      chatList.sort((a, b) => {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return new Date(b.lastChatAt).getTime() - new Date(a.lastChatAt).getTime();
      });

    } catch (chatListError) {
      console.error('CHAT LIST ERROR:', chatListError.message);
      chatList = [];
    }

    // GROUPS
    let allGroups = [];
    try {
      const [groupRows] = await db.query(`SELECT * FROM chat_groups`);
      allGroups = groupRows;
    } catch (_) {
      allGroups = [];
    }

    const groups = allGroups.filter((g) => {
      try {
        const members = JSON.parse(g.members || '[]');
        return members.includes(employeeName) || g.created_by === employeeName;
      } catch (_) {
        return false;
      }
    });

    const data = rows.map((r) => {
      let attachment = null;
      try {
        if (r.attachment && typeof r.attachment === 'string') {
          attachment = JSON.parse(r.attachment);
        } else if (r.attachment) {
          attachment = r.attachment;
        }
      } catch (_) {
        attachment = null;
      }

      return {
        id: r.id,
        senderName: r.sender_name,
        recipientName: r.recipient_name,
        message: r.message,
        time: formatTime(r.created_at),
        createdAt: r.created_at,
        isGroup: !!r.is_group,
        isSeen: !!r.is_seen,
        seenAt: r.seen_at || null,
        isFavorite: !!r.is_favorite,
        isArchived: !!r.is_archived,
        attachment
      };
    });

    // EMPLOYEES
    const [employees] = await db.query(
      `
      SELECT
        id,
        full_name,
        role,
        user_type,
        initials,
        is_active
      FROM employee_users
      WHERE is_active = 1
      ORDER BY full_name ASC
      `
    );

    let meetings = [];
    try {
      await refreshMeetingSchedules(req.app.get('io'));
      meetings = await meetingsFor(req.user);
    } catch (err) {
      console.error('Could not load meetings:', err.message);
    }

    // UNREAD COUNT
    let unreadCount = 0;
    try {
      const [countRows] = await db.query(
        `
        SELECT COUNT(*) AS unread_count
        FROM notifications
        WHERE recipient_name = ?
          AND sender_name != ?
          AND is_group = 0
          AND is_seen = 0
        `,
        [employeeName, employeeName]
      );

      unreadCount = Number(countRows[0]?.unread_count || 0);
    } catch (countError) {
      console.error('Unread count ERROR:', countError.message);
      unreadCount = 0;
    }

    return res.json({
      success: true,
      data,
      employees,
      groups,
      meetings,
      pinnedChats,
      unreadCount,
      chatList,
    });

  } catch (err) {
    console.error('GET /chat/:employeeName ERROR:', err.message);
    return res.status(500).json({
      success: false,
      message: err.message
    });
  }
});

// 2. PATCH /api/chat/pin-chat
router.patch('/pin-chat', async (req, res) => {
  const { ownerName, targetName, isGroup = false, pinned = false } = req.body;

  if (!ownerName || !targetName) {
    return res.status(400).json({
      success: false,
      message: 'ownerName and targetName are required'
    });
  }

  const groupFlag = isGroup === true || isGroup === 1 || isGroup === '1' || isGroup === 'true' ? 1 : 0;
  const pinFlag = pinned === true || pinned === 1 || pinned === '1' || pinned === 'true' ? 1 : 0;

  try {
    if (pinFlag === 1) {
      const [existingRows] = await db.query(
        `
        SELECT id
        FROM chat_pins
        WHERE owner_name = ?
          AND target_name = ?
          AND is_group = ?
        LIMIT 1
        `,
        [ownerName, targetName, groupFlag]
      );

      if (existingRows.length > 0) {
        await db.query(
          `
          UPDATE chat_pins
          SET pinned = 1
          WHERE id = ?
          `,
          [existingRows[0].id]
        );
      } else {
        await db.query(
          `
          INSERT INTO chat_pins (owner_name, target_name, is_group, pinned)
          VALUES (?, ?, ?, 1)
          `,
          [ownerName, targetName, groupFlag]
        );
      }
    }

    if (pinFlag === 0) {
      await db.query(
        `
        UPDATE chat_pins
        SET pinned = 0
        WHERE owner_name = ?
          AND target_name = ?
          AND is_group = ?
        `,
        [ownerName, targetName, groupFlag]
      );
    }

    const [rows] = await db.query(
      `
      SELECT id, owner_name, target_name, is_group, pinned, created_at
      FROM chat_pins
      WHERE owner_name = ?
        AND target_name = ?
        AND is_group = ?
        AND pinned = 1
      LIMIT 1
      `,
      [ownerName, targetName, groupFlag]
    );

    const currentPinned = rows.length > 0;
    const io = req.app.get('io');

    if (io) {
      io.emit('chat_pin_updated', {
        ownerName,
        targetName,
        isGroup: groupFlag === 1,
        pinned: currentPinned
      });
    }

    return res.json({
      success: true,
      message: currentPinned ? 'Chat pinned successfully' : 'Chat unpinned successfully',
      data: {
        ownerName,
        targetName,
        isGroup: groupFlag === 1,
        pinned: currentPinned
      }
    });

  } catch (err) {
    console.error('PATCH /chat/pin-chat ERROR:', err);
    return res.status(500).json({
      success: false,
      message: 'Failed to update pin state',
      error: err.message
    });
  }
});

// 3. PATCH /api/chat/mark-seen
router.patch('/mark-seen', async (req, res) => {
  const { recipientName, senderName } = req.body;

  if (!recipientName || !senderName) {
    return res.status(400).json({
      success: false,
      message: 'recipientName and senderName are required'
    });
  }

  try {
    const seenAt = new Date();
    let result;
    try {
      [result] = await db.query(
        `
          UPDATE notifications
          SET is_seen = 1, seen_at = ?
          WHERE recipient_name = ?
            AND sender_name = ?
            AND is_seen = 0
        `,
        [seenAt, recipientName, senderName]
      );
    } catch (dbError) {
      // seen_at column not added yet: fall back to the old behaviour
      if (dbError.code !== 'ER_BAD_FIELD_ERROR') throw dbError;
      [result] = await db.query(
        `
          UPDATE notifications
          SET is_seen = 1
          WHERE recipient_name = ?
            AND sender_name = ?
            AND is_seen = 0
        `,
        [recipientName, senderName]
      );
    }

    const io = req.app.get('io');
    if (io && result.affectedRows > 0) {
      io.emit('messages_seen', {
        recipientName,
        senderName,
        seenAt: seenAt.toISOString(),
        affectedRows: result.affectedRows
      });
    }

    return res.json({
      success: true,
      message: 'Messages marked as seen',
      seenAt: seenAt.toISOString(),
      affectedRows: result.affectedRows
    });

  } catch (err) {
    console.error('PATCH /chat/mark-seen ERROR:', err.message);
    return res.status(500).json({
      success: false,
      message: err.message
    });
  }
});

// 4. PATCH /api/chat/mark-seen-group
router.patch('/mark-seen-group', async (req, res) => {
  const { groupName, employeeName } = req.body;

  if (!groupName) {
    return res.status(400).json({
      success: false,
      message: 'groupName is required'
    });
  }

  try {
    const seenAt = new Date();
    let where = `
      WHERE recipient_name = ?
        AND is_group = 1
        AND is_seen = 0
    `;
    const whereValues = [groupName];

    if (employeeName) {
      where += ` AND sender_name != ?`;
      whereValues.push(employeeName);
    }

    let result;
    try {
      [result] = await db.query(
        `UPDATE notifications SET is_seen = 1, seen_at = ? ${where}`,
        [seenAt, ...whereValues]
      );
    } catch (dbError) {
      if (dbError.code !== 'ER_BAD_FIELD_ERROR') throw dbError;
      [result] = await db.query(
        `UPDATE notifications SET is_seen = 1 ${where}`,
        whereValues
      );
    }
    const io = req.app.get('io');

    if (io) {
      io.emit('group_messages_seen', {
        groupName,
        employeeName: employeeName || null,
        seenAt: seenAt.toISOString(),
        affectedRows: result.affectedRows
      });
    }

    return res.json({
      success: true,
      message: 'Group messages marked as seen',
      affectedRows: result.affectedRows
    });

  } catch (err) {
    console.error('PATCH /chat/mark-seen-group ERROR:', err.message);
    return res.status(500).json({
      success: false,
      message: err.message
    });
  }
});

// 5. POST /api/chat/send
router.post('/send', (req, res, next) => {
  upload.single('file')(req, res, function (err) {
    if (err instanceof multer.MulterError) {
      return res.status(400).json({ success: false, message: `Upload error: ${err.message}` });
    } else if (err) {
      return res.status(400).json({ success: false, message: err.message });
    }
    // Proceed to your normal async route logic if no multer error
    next();
  });
}, async (req, res) => {
  const { senderName, recipientName, message, groupId, isGroup } = req.body;

  const targetRecipient = recipientName || groupId;
  const isGroupMsg = isGroup == 1 || isGroup === true || isGroup === 'true';

  if (!targetRecipient || (!message && !req.file)) {
    return res.status(400).json({
      success: false,
      message: 'Recipient and message/file are required'
    });
  }

  try {
    if (!isGroupMsg) await require('../lib/employeeEligibility').assertActive(targetRecipient);
    const attachment = buildAttachment(req, req.file);
    let finalMessage = message || '';

    if (attachment) {
      const attachmentText = `📎 ${attachment.name}`;
      finalMessage = finalMessage ? `${finalMessage}\n${attachmentText}` : attachmentText;
    }

    let result;
    try {
      [result] = await db.query(
        `
          INSERT INTO notifications
          (sender_name, recipient_name, message, is_group, is_seen, attachment)
          VALUES (?, ?, ?, ?, 0, ?)
        `,
        [
          senderName || 'Admin',
          targetRecipient,
          finalMessage,
          isGroupMsg ? 1 : 0,
          attachment ? JSON.stringify(attachment) : null
        ]
      );
    } catch (dbError) {
      if (dbError.code === 'ER_BAD_FIELD_ERROR' && /attachment/i.test(dbError.message)) {
        [result] = await db.query(
          `
            INSERT INTO notifications
            (sender_name, recipient_name, message, is_group, is_seen)
            VALUES (?, ?, ?, ?, 0)
          `,
          [senderName || 'Admin', targetRecipient, finalMessage, isGroupMsg ? 1 : 0]
        );
      } else {
        throw dbError;
      }
    }

    const newMessageObj = {
      id: result.insertId,
      senderName: senderName || 'Admin',
      recipientName: targetRecipient,
      message: finalMessage,
      time: 'Just Now',
      createdAt: new Date().toISOString(),
      isGroup: isGroupMsg,
      isSeen: false,
      seenAt: null,
      isFavorite: false,
      isArchived: false,
      attachment
    };

    const io = req.app.get('io');
    if (io) {
      if (isGroupMsg) {
        io.emit('receive_group_message', newMessageObj);
      } else {
        io.emit('receive_message', newMessageObj);
      }

      io.emit('new_notification', {
        recipient: targetRecipient,
        sender: senderName || 'Admin',
        message: finalMessage,
        isGroup: isGroupMsg,
        messageId: result.insertId,
        attachment
      });
    }

    return res.status(201).json({
      success: true,
      message: 'Sent',
      data: newMessageObj
    });

  } catch (err) {
    console.error('POST /chat/send ERROR:', err.message);

    if (req.file) {
      try {
        fs.unlinkSync(req.file.path);
      } catch (_) {}
    }

    return res.status(500).json({
      success: false,
      message: err.message
    });
  }
});

// 6. POST /api/chat/groups
router.post('/groups', async (req, res) => {
  const { groupName, createdBy, members } = req.body;

  if (!groupName || !members || !Array.isArray(members)) {
    return res.status(400).json({
      success: false,
      message: 'Group name and members array are required'
    });
  }

  try {
    const membersJson = JSON.stringify(members);
    const adminsJson = JSON.stringify([createdBy || 'Admin']);

    await db.query(
      `
        INSERT INTO chat_groups (group_name, created_by, members, admins)
        VALUES (?, ?, ?, ?)
      `,
      [groupName, createdBy || 'Admin', membersJson, adminsJson]
    );

    return res.status(201).json({
      success: true,
      message: 'Group created successfully'
    });

  } catch (err) {
    console.error('POST /chat/groups ERROR:', err.message);
    return res.status(500).json({
      success: false,
      message: err.message
    });
  }
});

// 7. PATCH /api/chat/groups/:id
router.patch('/groups/:id', async (req, res) => {
  const { groupName, members, admins } = req.body;

  const requesterName = req.user.fullName;
  try {
    if (groupName !== undefined || members !== undefined) {
      await refreshMeetingSchedules(req.app.get('io'));
    }
    const changed = await meetingSync.transaction(async (conn) => {
      const [groupRows] = await conn.query(
        `SELECT * FROM chat_groups WHERE id = ? FOR UPDATE`,
        [req.params.id]
      );

      if (groupRows.length === 0) {
        throw meetingSync.error(404, 'Group not found');
      }

      const group = groupRows[0];
      const currentAdmins = meetingSync.safeJsonArray(group.admins);

      if (!currentAdmins.includes(requesterName) && group.created_by !== requesterName) {
        throw meetingSync.error(403, 'Only group admins can edit this group.');
      }

      const updates = [];
      const values = [];

      const newGroupName = groupName === undefined ? group.group_name : meetingText(groupName, 'group name', 255);
      if (groupName !== undefined) {
        updates.push('group_name = ?');
        values.push(newGroupName);
      }

      if (members !== undefined) {
        meetingSync.selection(members);
        updates.push('members = ?');
        values.push(JSON.stringify(members));
      }

      if (admins !== undefined) {
        updates.push('admins = ?');
        values.push(JSON.stringify(admins));
      }

      if (updates.length === 0) {
        throw meetingSync.error(400, 'Nothing to update');
      }

      values.push(req.params.id);

      await conn.query(
        `
          UPDATE chat_groups
          SET ${updates.join(', ')}
          WHERE id = ?
        `,
        values
      );

      return (groupName !== undefined || members !== undefined) &&
        meetingSync.updateGroupMeetings(conn, group.group_name, newGroupName);
    });
    if (changed) req.app.get('io')?.emit('meeting_tracking_updated', { action: 'group_updated' });
    return res.json({
      success: true,
      message: 'Group updated successfully'
    });

  } catch (err) {
    console.error('PATCH /chat/groups/:id ERROR:', err.message);
    return res.status(err.statusCode || 500).json({
      success: false,
      message: err.message
    });
  }
});

function isOrganizer(meeting, user) {
  return meeting.organizer_id == null
    ? meetingSync.nameKey(meeting.host_name) === meetingSync.nameKey(user.fullName)
    : Number(meeting.organizer_id) === Number(user.id);
}

async function meetingsFor(user) {
  const [rows] = await db.query(
    `SELECT m.*, p.employee_name AS participant_name,
            DATE_FORMAT(m.start_at, '%Y-%m-%d %H:%i:%s') AS start_at,
            DATE_FORMAT(m.end_at, '%Y-%m-%d %H:%i:%s') AS end_at,
            DATE_FORMAT(m.started_at, '%Y-%m-%d %H:%i:%s') AS started_at,
            DATE_FORMAT(m.completed_at, '%Y-%m-%d %H:%i:%s') AS completed_at
     FROM scheduled_meetings m
     LEFT JOIN meeting_participants p ON p.meeting_id = m.id AND LOWER(TRIM(p.employee_name)) = ?
     ORDER BY m.id DESC`, [meetingSync.nameKey(user.fullName)],
  );
  const visible = [];
  for (const row of rows) {
    const canManage = isOrganizer(row, user);
    if (!canManage && !row.participant_name) {
      if (row.organizer_id != null || row.start_at || meetingSync.open(row)) continue;
      if (!(await meetingSync.expandParticipants(db, row)).has(meetingSync.nameKey(user.fullName))) continue;
    }
    const { participant_name, organizer_id, ...meeting } = row;
    visible.push({ ...meeting, can_manage: canManage });
  }
  return visible;
}

function meetingText(value, label, maxLength = Infinity) {
  if (typeof value !== 'string' || !value.trim() || value.trim().length > maxLength) {
    throw meetingSync.error(400, 'Enter a valid meeting ' + label + '.');
  }
  return value.trim();
}

function meetingEndpoint(handler) {
  return async (req, res) => {
    try {
      await handler(req, res);
    } catch (err) {
      if (!err.statusCode) console.error('Meeting request failed:', err);
      res.status(err.statusCode || 500).json({
        success: false, message: err.statusCode ? err.message : 'Could not process the meeting request.',
      });
    }
  };
}

async function meetingNotification(conn, sender, recipient, message, isGroup, type) {
  const [result] = await conn.query(
    'INSERT INTO notifications (sender_name, recipient_name, message, is_group, is_seen) VALUES (?, ?, ?, ?, 0)',
    [sender, recipient, message, Number(isGroup)],
  );
  return { recipient, sender, message, isGroup, messageId: result.insertId, type };
}

function publishMeeting(req, id, action, notifications = []) {
  const io = req.app.get('io');
  for (const payload of notifications) io?.emit('new_notification', payload);
  io?.emit('meeting_tracking_updated', { meetingId: Number(id), action });
}

router.post('/meetings', meetingEndpoint(async (req, res) => {
  const body = req.body || {};
  const title = meetingText(body.title, 'title', 255);
  const link = meetingText(body.meetingLink, 'link');
  const attendees = meetingSync.selection(body.selectedPersons) || [];
  const groups = meetingSync.selection(body.selectedGroups) || [];
  const schedule = meetingSync.resolveSchedule(body);
  const host = req.user.fullName;
  const { id, notifications } = await meetingSync.transaction(async (conn) => {
    const now = meetingSync.istNowString();
    if (schedule.endAt && schedule.endAt <= now) {
      throw meetingSync.error(400, 'The meeting end time must be in the future.');
    }
    const [result] = await conn.query(
      `INSERT INTO scheduled_meetings
        (title, meeting_time, meeting_link, host_name, organizer_id, attendees, \`groups\`,
         status, start_at, end_at, duration_mins, meeting_details)
       VALUES (?, ?, ?, ?, ?, ?, ?, 'Scheduled', ?, ?, ?, ?)`,
      [title, schedule.startAt, link, host, req.user.id, JSON.stringify(attendees), JSON.stringify(groups),
        schedule.startAt, schedule.endAt, schedule.durationMins, body.details == null ? null : String(body.details)],
    );
    const meeting = await meetingSync.lockMeeting(conn, result.insertId);
    await meetingSync.syncParticipants(conn, meeting, now, { validateGroups: true });

    const notifications = [];
    const info = `\n🕒 Time: ${schedule.startAt} IST\n🔗 Link: ${link}`;
    for (const attendee of attendees) {
      notifications.push(await meetingNotification(conn, host, attendee, '📅 Meeting Scheduled: ' + title + info, false, 'meeting'));
    }
    for (const group of groups) {
      notifications.push(await meetingNotification(conn, host, group, '📅 Group Meeting Scheduled: ' + title + info, true, 'meeting'));
    }
    return { id: meeting.id, notifications };
  });
  publishMeeting(req, id, 'created', notifications);
  res.status(201).json({ success: true, meetingId: id, message: 'Meeting scheduled & broadcasted successfully!' });
}));

function meetingAction(action, notify) {
  return meetingEndpoint(async (req, res) => {
    const requested = action || String(req.body?.status || '').trim().toLowerCase();
    const status = { active: 'Active', completed: 'Completed', rejected: 'Rejected' }[requested];
    if (!['Active', 'Completed', 'Rejected'].includes(status)) throw meetingSync.error(400, 'Choose a valid meeting status.');
    await refreshMeetingSchedules(req.app.get('io'));
    const notifications = await meetingSync.transaction(async (conn) => {
      const meeting = await meetingSync.lockMeeting(conn, req.params.id);
      if (!isOrganizer(meeting, req.user)) throw meetingSync.error(403, 'Only the organizer can change this meeting.');
      const now = meetingSync.istNowString();
      if (meeting.status === status) return null;
      if (meeting.end_at && meeting.end_at <= now) {
        throw meetingSync.error(409, meeting.status === 'Scheduled'
          ? 'Edit the schedule before starting this meeting. Its end time has passed.'
          : 'This meeting has ended.');
      }
      if (!meetingSync.open(meeting) ||
          (status === 'Completed' && meeting.status !== 'Active')) {
        throw meetingSync.error(409, 'This action is unavailable for this meeting.');
      }
      if (status === 'Active') {
        await meetingSync.activate(conn, meeting, now);
      } else {
        await meetingSync.finish(conn, meeting, status, now);
      }

      const notifications = [];
      if (notify) {
        const participants = await meetingSync.expandParticipants(conn, meeting);
        for (const { name } of participants.values()) {
          notifications.push(await meetingNotification(conn, req.user.fullName, name,
            `🔔 Meeting "${meeting.title}" has been marked as ${status} by ${req.user.fullName}.`, false, 'meeting_status'));
        }
      }
      return notifications;
    });
    if (notifications) publishMeeting(req, req.params.id, requested, notifications);
    res.json({ success: true, message: 'Meeting marked as ' + status });
  });
}

router.patch('/meetings/:id/status', meetingAction(null, true));
router.patch('/meetings/:id/complete', meetingAction('completed', false));
router.post('/meetings/:id/start', meetingAction('active', false));

router.patch('/meetings/:id', meetingEndpoint(async (req, res) => {
  const body = req.body || {};
  const attendees = meetingSync.selection(body.attendees);
  const groups = meetingSync.selection(body.groups);
  await refreshMeetingSchedules(req.app.get('io'));
  await meetingSync.transaction(async (conn) => {
    const meeting = await meetingSync.lockMeeting(conn, req.params.id);
    if (!isOrganizer(meeting, req.user)) throw meetingSync.error(403, 'Only the organizer can edit this meeting.');
    if (!meetingSync.open(meeting)) throw meetingSync.error(409, 'Only scheduled or active meetings can be edited.');

    const now = meetingSync.istNowString();
    if (meeting.status === 'Active' && meeting.end_at && meeting.end_at <= now) {
      throw meetingSync.error(409, 'This meeting has ended.');
    }
    const changesStart = body.startAt !== undefined || body.meetingTime !== undefined;
    const changesEnd = body.endAt !== undefined || body.durationMins !== undefined;
    const updates = {};
    if (changesStart || changesEnd) {
      const start = meetingSync.resolveSchedule({
        startAt: body.startAt ?? body.meetingTime ?? meeting.start_at ?? meeting.meeting_time,
      }).startAt;
      const schedule = meetingSync.resolveSchedule({
        startAt: start,
        endAt: changesEnd ? body.endAt : (start === meeting.start_at ? meeting.end_at : undefined),
        durationMins: changesEnd ? body.durationMins : (start !== meeting.start_at ? meeting.duration_mins : undefined),
      });
      if (meeting.status === 'Active' && start !== meeting.start_at) {
        throw meetingSync.error(409, 'The start time is fixed once the meeting begins.');
      }
      if (schedule.endAt && schedule.endAt <= now) {
        throw meetingSync.error(400, 'The meeting end time must be in the future.');
      }
      Object.assign(updates, {
        start_at: start, end_at: schedule.endAt, meeting_time: start, duration_mins: schedule.durationMins,
      });
    }
    if (body.title !== undefined) updates.title = meetingText(body.title, 'title', 255);
    if (body.meetingLink !== undefined) updates.meeting_link = meetingText(body.meetingLink, 'link');
    if (body.details !== undefined) updates.meeting_details = body.details == null ? null : String(body.details);
    if (attendees !== undefined) updates.attendees = JSON.stringify(attendees);
    if (groups !== undefined) updates.groups = JSON.stringify(groups);
    if (Object.keys(updates).length) {
      await conn.query('UPDATE scheduled_meetings SET ? WHERE id = ?', [updates, meeting.id]);
      Object.assign(meeting, updates);
    }
    await meetingSync.syncParticipants(conn, meeting, now, { validateGroups: groups !== undefined });
  });
  publishMeeting(req, req.params.id, 'updated');
  res.json({ success: true, message: 'Meeting updated successfully' });
}));

router.get('/meetings/scheduled', meetingEndpoint(async (req, res) => {
  await refreshMeetingSchedules(req.app.get('io'));
  res.json({ success: true, data: await meetingsFor(req.user) });
}));

router.get('/meetings/live/:employeeName', meetingEndpoint(async (req, res) => {
  if (meetingSync.nameKey(req.params.employeeName) !== meetingSync.nameKey(req.user.fullName)) {
    throw meetingSync.error(403, 'Meeting tracking is available for your own account.');
  }
  await refreshMeetingSchedules(req.app.get('io'));
  const data = await meetingSync.getLiveSessionsForEmployee(req.user.fullName, req.query.date);
  res.json({ success: true, data });
}));

// 11. PATCH /api/chat/edit/:id
router.patch('/edit/:id', async (req, res) => {
  const { newMessage } = req.body;

  if (newMessage === undefined || newMessage === null) {
    return res.status(400).json({
      success: false,
      message: 'newMessage is required'
    });
  }

  try {
    const [result] = await db.query(
      `UPDATE notifications SET message = ? WHERE id = ?`,
      [newMessage, req.params.id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({
        success: false,
        message: 'Message not found'
      });
    }

    const io = req.app.get('io');
    if (io) {
      io.emit('message_edited', {
        id: Number(req.params.id),
        message: newMessage
      });
    }

    return res.json({
      success: true,
      message: 'Message updated'
    });

  } catch (err) {
    console.error('PATCH /chat/edit/:id ERROR:', err.message);
    return res.status(500).json({
      success: false,
      message: err.message
    });
  }
});

// 12. PATCH /api/chat/:id
router.patch('/:id', async (req, res) => {
  const { id } = req.params;
  const { isFavorite, isSeen, isArchived } = req.body;

  if (isFavorite === undefined && isSeen === undefined && isArchived === undefined) {
    return res.status(400).json({
      success: false,
      message: 'Nothing to update'
    });
  }

  try {
    const updates = [];
    const values = [];

    if (isFavorite !== undefined) {
      updates.push('is_favorite = ?');
      values.push(isFavorite ? 1 : 0);
    }

    let seenAt = null;
    if (isSeen !== undefined) {
      seenAt = isSeen ? new Date() : null;
      updates.push('is_seen = ?', 'seen_at = ?');
      values.push(isSeen ? 1 : 0, seenAt);
    }

    if (isArchived !== undefined) {
      updates.push('is_archived = ?');
      values.push(isArchived ? 1 : 0);
    }

    values.push(id);

    const [result] = await db.query(
      `
        UPDATE notifications
        SET ${updates.join(', ')}
        WHERE id = ?
      `,
      values
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({
        success: false,
        message: 'Notification not found'
      });
    }

    const io = req.app.get('io');
    if (io) {
      if (isFavorite !== undefined) {
        io.emit('message_pin_changed', {
          id: Number(id),
          isFavorite: !!isFavorite
        });
      }

      if (isSeen !== undefined) {
        io.emit('message_seen_changed', {
          id: Number(id),
          isSeen: !!isSeen,
          seenAt: seenAt ? seenAt.toISOString() : null
        });
      }

      if (isArchived !== undefined) {
        io.emit('message_archive_changed', {
          id: Number(id),
          isArchived: !!isArchived
        });
      }
    }

    return res.json({
      success: true,
      message: 'Notification updated',
      data: {
        id: Number(id),
        ...(isFavorite !== undefined && { isFavorite: !!isFavorite }),
        ...(isSeen !== undefined && { isSeen: !!isSeen }),
        ...(isArchived !== undefined && { isArchived: !!isArchived })
      }
    });

  } catch (err) {
    console.error('PATCH /chat/:id ERROR:', err.message);
    return res.status(500).json({
      success: false,
      message: err.message
    });
  }
});

// 13. DELETE /api/chat/:id
router.delete('/:id', async (req, res) => {
  const { mode } = req.query;

  try {
    const [result] = await db.query(
      `DELETE FROM notifications WHERE id = ?`,
      [req.params.id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({
        success: false,
        message: 'Notification not found'
      });
    }

    return res.json({
      success: true,
      message: mode === 'everyone' ? 'Deleted for everyone' : 'Deleted for me'
    });

  } catch (err) {
    console.error('DELETE /chat/:id ERROR:', err.message);
    return res.status(500).json({
      success: false,
      message: err.message
    });
  }
});

router.get('/download/:filename', async (req, res) => {
  const filename = decodeURIComponent(req.params.filename).trim();
  const chatUploadDir = path.resolve(__dirname, '..', 'uploads', 'chat');
  
  const exactPath = path.join(chatUploadDir, filename);
  if (fs.existsSync(exactPath)) {
    return res.download(exactPath, filename);
  }

  try {
    if (!fs.existsSync(chatUploadDir)) {
      return res.status(404).json({ success: false, message: 'Upload directory missing' });
    }

    const files = fs.readdirSync(chatUploadDir);
    const matchedFile = files.find(f => 
      f === filename || 
      f.includes(filename) || 
      filename.includes(f.replace(/^\d+-\d+-/, ''))
    );

    if (matchedFile) {
      const actualPath = path.join(chatUploadDir, matchedFile);
      return res.download(actualPath, filename);
    }
  } catch (err) {
    console.error('File download search error:', err.message);
  }

  return res.status(404).json({ success: false, message: 'File not found on server' });
});

// ============================================================
// EXPORT
// ============================================================

module.exports = router;
module.exports.createNotification = createNotification;