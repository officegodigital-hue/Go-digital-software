// routes/chat.js

const express = require('express');
const router = express.Router();
const db = require('../config/db');

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
        isGroup: !!r.is_group,
        isSeen: !!r.is_seen,
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

    // MEETINGS
    let meetings = [];
    try {
      const [meetingRows] = await db.query(`SELECT * FROM scheduled_meetings`);
      meetings = meetingRows;
    } catch (_) {
      meetings = [];
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
    const [result] = await db.query(
      `
        UPDATE notifications
        SET is_seen = 1
        WHERE recipient_name = ?
          AND sender_name = ?
          AND is_seen = 0
      `,
      [recipientName, senderName]
    );

    const io = req.app.get('io');
    if (io) {
      io.emit('messages_seen', {
        recipientName,
        senderName,
        affectedRows: result.affectedRows
      });
    }

    return res.json({
      success: true,
      message: 'Messages marked as seen',
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
    let query = `
      UPDATE notifications
      SET is_seen = 1
      WHERE recipient_name = ?
        AND is_group = 1
        AND is_seen = 0
    `;
    const values = [groupName];

    if (employeeName) {
      query += ` AND sender_name != ?`;
      values.push(employeeName);
    }

    const [result] = await db.query(query, values);
    const io = req.app.get('io');

    if (io) {
      io.emit('group_messages_seen', {
        groupName,
        employeeName: employeeName || null,
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
      isGroup: isGroupMsg,
      isSeen: false,
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
  const { groupName, members, admins, requesterName } = req.body;

  try {
    const [groupRows] = await db.query(
      `SELECT * FROM chat_groups WHERE id = ?`,
      [req.params.id]
    );

    if (groupRows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Group not found'
      });
    }

    const group = groupRows[0];
    let currentAdmins = [];

    try {
      currentAdmins = JSON.parse(group.admins || '[]');
    } catch (_) {
      currentAdmins = [group.created_by];
    }

    if (!currentAdmins.includes(requesterName) && group.created_by !== requesterName) {
      return res.status(403).json({
        success: false,
        message: 'Only group admins can edit this group.'
      });
    }

    const updates = [];
    const values = [];

    if (groupName !== undefined) {
      updates.push('group_name = ?');
      values.push(groupName);
    }

    if (members !== undefined) {
      updates.push('members = ?');
      values.push(JSON.stringify(members));
    }

    if (admins !== undefined) {
      updates.push('admins = ?');
      values.push(JSON.stringify(admins));
    }

    if (updates.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Nothing to update'
      });
    }

    values.push(req.params.id);

    await db.query(
      `
        UPDATE chat_groups
        SET ${updates.join(', ')}
        WHERE id = ?
      `,
      values
    );

    return res.json({
      success: true,
      message: 'Group updated successfully'
    });

  } catch (err) {
    console.error('PATCH /chat/groups/:id ERROR:', err.message);
    return res.status(500).json({
      success: false,
      message: err.message
    });
  }
});

// 8. POST /api/chat/meetings
router.post('/meetings', async (req, res) => {
  const { title, meetingTime, meetingLink, hostName, selectedPersons, selectedGroups } = req.body;

  try {
    const attendees = Array.isArray(selectedPersons) ? selectedPersons : [];
    const groups = Array.isArray(selectedGroups) ? selectedGroups : [];

    await db.query(
      `
        INSERT INTO scheduled_meetings
        (title, meeting_time, meeting_link, host_name, attendees, groups, status)
        VALUES (?, ?, ?, ?, ?, ?, 'Active')
      `,
      [title, meetingTime, meetingLink, hostName || 'Admin', JSON.stringify(attendees), JSON.stringify(groups)]
    );

    const io = req.app.get('io');

    for (const attendee of attendees) {
      const meetingMessage = `📅 Meeting Scheduled: ${title}\n` +
        `🕒 Time: ${meetingTime}\n` +
        `🔗 Link: ${meetingLink}`;

      const [notificationResult] = await db.query(
        `
          INSERT INTO notifications (sender_name, recipient_name, message, is_group, is_seen)
          VALUES (?, ?, ?, 0, 0)
        `,
        [hostName || 'Admin', attendee, meetingMessage]
      );

      if (io) {
        io.emit('new_notification', {
          recipient: attendee,
          sender: hostName || 'Admin',
          message: meetingMessage,
          isGroup: false,
          messageId: notificationResult.insertId,
          type: 'meeting'
        });
      }
    }

    for (const groupName of groups) {
      const meetingMessage = `📅 Group Meeting Scheduled: ${title}\n` +
        `🕒 Time: ${meetingTime}\n` +
        `🔗 Link: ${meetingLink}`;

      const [notificationResult] = await db.query(
        `
          INSERT INTO notifications (sender_name, recipient_name, message, is_group, is_seen)
          VALUES (?, ?, ?, 1, 0)
        `,
        [hostName || 'Admin', groupName, meetingMessage]
      );

      if (io) {
        io.emit('new_notification', {
          recipient: groupName,
          sender: hostName || 'Admin',
          message: meetingMessage,
          isGroup: true,
          messageId: notificationResult.insertId,
          type: 'meeting'
        });
      }
    }

    return res.status(201).json({
      success: true,
      message: 'Meeting scheduled & broadcasted!'
    });

  } catch (err) {
    console.error('POST /chat/meetings ERROR:', err.message);
    return res.status(500).json({
      success: false,
      message: err.message
    });
  }
});

// 9. PATCH /api/chat/meetings/:id/status
router.patch('/meetings/:id/status', async (req, res) => {
  const { status, actionBy } = req.body;

  try {
    const [meetingRows] = await db.query(
      `SELECT * FROM scheduled_meetings WHERE id = ?`,
      [req.params.id]
    );

    if (meetingRows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Meeting not found'
      });
    }

    const meeting = meetingRows[0];

    await db.query(
      `UPDATE scheduled_meetings SET status = ? WHERE id = ?`,
      [status, req.params.id]
    );

    let attendees = [];
    try {
      attendees = JSON.parse(meeting.attendees || '[]');
    } catch (_) {
      attendees = [];
    }

    const io = req.app.get('io');

    for (const attendee of attendees) {
      const notificationMessage = `🔔 Meeting "${meeting.title}" has been marked as ${status} by ${actionBy || meeting.host_name}.`;

      const [result] = await db.query(
        `
          INSERT INTO notifications (sender_name, recipient_name, message, is_group)
          VALUES (?, ?, ?, 0)
        `,
        [actionBy || meeting.host_name, attendee, notificationMessage]
      );

      if (io) {
        io.emit('new_notification', {
          recipient: attendee,
          sender: actionBy || meeting.host_name,
          message: notificationMessage,
          messageId: result.insertId,
          type: 'meeting_status'
        });
      }
    }

    return res.json({
      success: true,
      message: `Meeting marked as ${status}`
    });

  } catch (err) {
    console.error('PATCH /chat/meetings/:id/status ERROR:', err.message);
    return res.status(500).json({
      success: false,
      message: err.message
    });
  }
});

// 10. PATCH /api/chat/meetings/:id/complete
router.patch('/meetings/:id/complete', async (req, res) => {
  try {
    await db.query(
      `UPDATE scheduled_meetings SET status = 'Completed' WHERE id = ?`,
      [req.params.id]
    );

    return res.json({
      success: true,
      message: 'Meeting marked as completed'
    });

  } catch (err) {
    console.error('PATCH /chat/meetings/:id/complete ERROR:', err.message);
    return res.status(500).json({
      success: false,
      message: err.message
    });
  }
});

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

    if (isSeen !== undefined) {
      updates.push('is_seen = ?');
      values.push(isSeen ? 1 : 0);
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
          isSeen: !!isSeen
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
  const filename = decodeURIComponent(req.params.filename);
  const chatUploadDir = path.join(__dirname, '..', 'uploads', 'chat');
  const filePath = path.join(chatUploadDir, filename);

  if (fs.existsSync(filePath)) {
    return res.download(filePath, filename);
  }

  try {
    const files = fs.readdirSync(chatUploadDir);
    const matchedFile = files.find(f => f.endsWith(`-${filename}`) || f === filename);
    if (matchedFile) {
      return res.download(path.join(chatUploadDir, matchedFile), filename);
    }
  } catch (err) {
    console.error('File search error:', err);
  }

  return res.status(404).json({ success: false, message: 'File not found on server' });
});

// ============================================================
// EXPORT
// ============================================================

module.exports = router;
module.exports.createNotification = createNotification;