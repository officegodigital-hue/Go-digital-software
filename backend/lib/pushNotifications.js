// lib/pushNotifications.js
//
// Mobile push notifications (Firebase Cloud Messaging). They reach the phone
// even when the app is closed or removed from recent apps.
//
// Setup (once):
//   1. npm install firebase-admin
//   2. Firebase console → Project settings → Service accounts → "Generate new
//      private key". Save the JSON file on the server (never in git), e.g.
//      backend/config/firebase-service-account.json
//   3. .env:  FIREBASE_SERVICE_ACCOUNT=./config/firebase-service-account.json
//   4. server.js (after `io` is created and app.set('io', io)):
//        const push = require('./lib/pushNotifications');
//        app.use('/api/push', push.router);
//        push.attachIo(io);
//        push.startNotificationWatcher();
//
// What is pushed:
//   • Private chat        (socket event receive_message)
//   • Team group chat     (socket event receive_group_message) → every member
//   • Client group chat   (Employee Workspace team chat)       → client team
//   • Every row added to the `notifications` table (task assigned, review,
//     day planner …) → its recipient
//
// Without FIREBASE_SERVICE_ACCOUNT the module only logs a warning and the
// rest of the server works as before.

const express = require('express');
const path = require('path');
const db = require('../config/db');

// Android notification channels — must match lib/services/push_notification_service.dart.
// Each phone picks one in the app (Settings → Notification sound):
//   app   → GoDigital tone (android/app/src/main/res/raw/notification.mp3)
//   phone → the phone's own notification sound (changeable in phone settings)
const CHANNELS = {
  app: { channelId: 'godigital_alerts', sound: 'notification' },
  phone: { channelId: 'godigital_alerts_phone', sound: 'default' },
};
const soundModeOf = (v) => (String(v || '').toLowerCase() === 'phone' ? 'phone' : 'app');

// ── Firebase ────────────────────────────────────────────────────────────────
let messaging = null;
let initTried = false;
function fcm() {
  if (initTried) return messaging;
  initTried = true;
  try {
    const admin = require('firebase-admin');
    const file = process.env.FIREBASE_SERVICE_ACCOUNT;
    let credential;
    if (file) {
      // eslint-disable-next-line import/no-dynamic-require, global-require
      credential = admin.credential.cert(require(path.resolve(process.cwd(), file)));
    } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      credential = admin.credential.applicationDefault();
    } else {
      console.warn('Push: FIREBASE_SERVICE_ACCOUNT is not set — mobile push notifications are off.');
      return null;
    }
    if (!admin.apps.length) admin.initializeApp({ credential });
    messaging = admin.messaging();
    console.log('Push: Firebase Cloud Messaging ready');
  } catch (err) {
    console.warn('Push: Firebase could not start —', err.message);
    messaging = null;
  }
  return messaging;
}

// ── Device tokens ───────────────────────────────────────────────────────────
let tableReady = null;
function ensureTable() {
  if (!tableReady) {
    tableReady = db.query(
      `CREATE TABLE IF NOT EXISTS push_device_tokens (
         id INT AUTO_INCREMENT PRIMARY KEY,
         employee_name VARCHAR(255) NOT NULL,
         token VARCHAR(512) NOT NULL,
         platform VARCHAR(20) NULL,
         sound_mode VARCHAR(10) NOT NULL DEFAULT 'app',
         updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
         UNIQUE KEY uq_push_token (token),
         INDEX idx_push_employee (employee_name)
       )`,
    ).then(async () => {
      // Older table without the sound column.
      const [cols] = await db.query(
        `SELECT COLUMN_NAME AS c FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'push_device_tokens' AND COLUMN_NAME = 'sound_mode'`,
      );
      if (!cols.length) {
        await db.query("ALTER TABLE push_device_tokens ADD COLUMN sound_mode VARCHAR(10) NOT NULL DEFAULT 'app'");
      }
    }).catch((err) => {
      tableReady = null;
      throw err;
    });
  }
  return tableReady;
}

const key = (v) => String(v ?? '').trim().toLowerCase();

async function tokensFor(names) {
  const list = [...new Set(names.map(key).filter(Boolean))];
  if (!list.length) return [];
  await ensureTable();
  const [rows] = await db.query(
    `SELECT token, sound_mode FROM push_device_tokens
     WHERE EXISTS (SELECT 1 FROM employee_users u WHERE LOWER(TRIM(u.full_name))=LOWER(TRIM(employee_name)) AND u.is_active=1)
     AND LOWER(TRIM(employee_name)) IN (${list.map(() => '?').join(',')})`,
    list,
  );
  const byToken = new Map();
  for (const r of rows) byToken.set(r.token, soundModeOf(r.sound_mode));
  return [...byToken].map(([token, mode]) => ({ token, mode }));
}

// Same message reaching us twice (socket + notifications table) → one push.
const recent = new Map();
function isDuplicate(recipient, sender, body) {
  const now = Date.now();
  for (const [k, at] of recent) if (now - at > 8000) recent.delete(k);
  const k = `${key(recipient)}|${key(sender)}|${String(body).slice(0, 60)}`;
  const k2 = `${key(recipient)}|${key(sender)}`;
  const dup = recent.has(k) || (recent.has(k2) && now - recent.get(k2) < 3000);
  recent.set(k, now);
  recent.set(k2, now);
  return dup;
}

/**
 * Send one notification to employees (by full name).
 * @param {string[]} names       recipients
 * @param {{title:string, body:string, data?:object, sender?:string}} msg
 */
async function sendToEmployees(names, { title, body, data = {}, sender = '' }) {
  const m = fcm();
  if (!m) return;
  const people = names.filter((n) => key(n) && key(n) !== key(sender))
    .filter((n) => !isDuplicate(n, sender, body));
  if (!people.length) return;
  try {
    const devices = await tokensFor(people);
    if (!devices.length) return;
    // Sender's profile photo on the right of the notification (like Zomato /
    // WhatsApp). Needs PUBLIC_API_URL so the phone can download it.
    const imageUrl = await avatarUrlFor(sender);
    const text = String(body || '').slice(0, 300);
    const payloadData = Object.fromEntries(
      Object.entries({ ...data, title, body: text }).map(([k, v]) => [k, String(v ?? '')]),
    );
    for (const mode of Object.keys(CHANNELS)) {
      const tokens = devices.filter((d) => d.mode === mode).map((d) => d.token);
      const channel = CHANNELS[mode];
      for (let i = 0; i < tokens.length; i += 500) {
        const batch = tokens.slice(i, i + 500);
        const res = await m.sendEachForMulticast({
          tokens: batch,
          notification: { title: String(title || 'GoDigital'), body: text },
          data: payloadData,
          android: {
            priority: 'high',
            notification: {
              channelId: channel.channelId,
              sound: channel.sound,
              defaultVibrateTimings: true,
              visibility: 'public',
              icon: 'ic_notification',  // android/app/src/main/res/drawable/ic_notification.png
              color: '#0052CC',          // GoDigital blue behind the small icon
              ...(imageUrl ? { imageUrl } : {}),
            },
          },
          apns: {
            headers: { 'apns-priority': '10' },
            payload: { aps: { sound: 'default', badge: 1 } },
          },
        });
        // Remove tokens of uninstalled apps / logged-out phones.
        const dead = [];
        res.responses.forEach((r, idx) => {
          const code = r.error?.code || '';
          if (code.includes('registration-token-not-registered') || code.includes('invalid-registration-token')
            || code.includes('invalid-argument')) {
            dead.push(batch[idx]);
          }
        });
        if (dead.length) {
          await db.query(
            `DELETE FROM push_device_tokens WHERE token IN (${dead.map(() => '?').join(',')})`,
            dead,
          );
        }
      }
    }
  } catch (err) {
    console.error('Push send failed:', err.message);
  }
}

// ── Sender photo for the notification ───────────────────────────────────────
const PUBLIC_API_URL = String(process.env.PUBLIC_API_URL || '').replace(/\/+$/, '');
const photoCache = new Map(); // name → { at, has }
async function avatarUrlFor(name) {
  const who = String(name || '').trim();
  if (!who || !PUBLIC_API_URL) return null;
  const k = key(who);
  const hit = photoCache.get(k);
  if (hit && Date.now() - hit.at < 10 * 60 * 1000) return hit.has ? hit.url : null;
  try {
    const [[row]] = await db.query(
      `SELECT profile_photo FROM employee_users WHERE LOWER(TRIM(full_name)) = ? LIMIT 1`,
      [k],
    );
    const has = !!(row && String(row.profile_photo || '').trim());
    const url = `${PUBLIC_API_URL}/api/push/avatar/${encodeURIComponent(who)}.jpg`;
    photoCache.set(k, { at: Date.now(), has, url });
    return has ? url : null;
  } catch (_) {
    return null;
  }
}

// ── Message text ────────────────────────────────────────────────────────────
function plainText(raw) {
  if (raw == null) return '';
  let value = raw;
  if (typeof value === 'string') {
    const t = value.trim();
    if (t.startsWith('{')) {
      try { value = JSON.parse(t); } catch (_) { return t; }
    } else {
      return t;
    }
  }
  if (typeof value === 'object') {
    if (value.type === 'file') return `📎 ${value.fileName || value.name || 'Shared a file'}`;
    return String(value.preview || value.text || value.message || value.title || 'New message');
  }
  return String(value);
}

// ── Team chat groups (members) ──────────────────────────────────────────────
let groupTable;
async function groupMembers(groupName) {
  if (groupTable === undefined) {
    try {
      const [rows] = await db.query(
        `SELECT TABLE_NAME AS t FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND COLUMN_NAME IN ('group_name', 'members')
         GROUP BY TABLE_NAME HAVING COUNT(*) = 2`,
      );
      groupTable = rows[0]?.t || null;
    } catch (_) {
      groupTable = null;
    }
  }
  if (!groupTable) return [];
  const [rows] = await db.query(
    `SELECT * FROM \`${groupTable}\` WHERE LOWER(TRIM(group_name)) = LOWER(TRIM(?)) LIMIT 1`,
    [groupName],
  );
  const g = rows[0];
  if (!g) return [];
  const out = [];
  try {
    const members = typeof g.members === 'string' ? JSON.parse(g.members || '[]') : (g.members || []);
    if (Array.isArray(members)) out.push(...members.map(String));
  } catch (_) { /* ignore */ }
  if (g.created_by) out.push(String(g.created_by));
  return out;
}

// ── Socket.IO hook: every chat emit also becomes a push ─────────────────────
function onEmit(event, payload) {
  if (!payload || typeof payload !== 'object') return;
  const sender = String(payload.senderName || '').trim();
  const body = plainText(payload.message);
  if (event === 'receive_message') {
    const to = String(payload.recipientName || '').trim();
    if (!to) return;
    sendToEmployees([to], {
      title: sender || 'New message',
      body,
      sender,
      data: { type: 'chat', chat: sender, isGroup: '0' },
    });
  } else if (event === 'receive_group_message') {
    const group = String(payload.recipientName || payload.groupName || payload.groupId || '').trim();
    if (!group) return;
    groupMembers(group).then((members) => sendToEmployees(members, {
      title: `${sender} • ${group}`,
      body,
      sender,
      data: { type: 'group', chat: group, isGroup: '1' },
    })).catch((err) => console.error('Push group lookup failed:', err.message));
  }
}

const seenPayloads = new WeakSet();
function attachIo(io) {
  if (!io || io.__pushAttached) return;
  io.__pushAttached = true;
  fcm();
  const hook = (event, args) => {
    const payload = args[0];
    if (payload && typeof payload === 'object') {
      if (seenPayloads.has(payload)) return; // same object emitted to several rooms
      seenPayloads.add(payload);
    }
    try { onEmit(event, payload); } catch (err) { console.error('Push hook error:', err.message); }
  };
  const wrapOperator = (op) => {
    if (!op || op.__pushWrapped) return op;
    const emit = op.emit.bind(op);
    op.emit = (event, ...args) => { hook(event, args); return emit(event, ...args); };
    const to = op.to?.bind(op);
    if (to) op.to = (...a) => wrapOperator(to(...a));
    const inn = op.in?.bind(op);
    if (inn) op.in = (...a) => wrapOperator(inn(...a));
    op.__pushWrapped = true;
    return op;
  };
  const emit = io.emit.bind(io);
  io.emit = (event, ...args) => { hook(event, args); return emit(event, ...args); };
  for (const name of ['to', 'in', 'except']) {
    const fn = io[name]?.bind(io);
    if (fn) io[name] = (...a) => wrapOperator(fn(...a));
  }
  // socket.broadcast.emit / socket.to(..).emit from inside socket handlers
  io.on('connection', (socket) => {
    const sEmitTo = socket.to.bind(socket);
    socket.to = (...a) => wrapOperator(sEmitTo(...a));
  });
}

// ── Watch the notifications table (task / review / planner alerts) ──────────
let watcher = null;
function startNotificationWatcher(intervalMs = 5000) {
  if (watcher) return;
  let lastId = null;
  const tick = async () => {
    if (!fcm()) return;
    try {
      if (lastId === null) {
        const [[row]] = await db.query('SELECT COALESCE(MAX(id), 0) AS id FROM notifications');
        lastId = Number(row?.id) || 0;
        return;
      }
      const [rows] = await db.query(
        `SELECT id, sender_name, recipient_name, message FROM notifications
         WHERE id > ? ORDER BY id ASC LIMIT 200`,
        [lastId],
      );
      for (const r of rows) {
        lastId = Math.max(lastId, Number(r.id) || 0);
        const to = String(r.recipient_name || '').trim();
        const from = String(r.sender_name || '').trim();
        if (!to || key(to) === key(from)) continue;
        await sendToEmployees([to], {
          title: from ? `GoDigital • ${from}` : 'GoDigital',
          body: plainText(r.message),
          sender: from,
          data: { type: 'notification', id: r.id },
        });
      }
    } catch (err) {
      if (!/doesn't exist/i.test(err.message)) console.error('Push watcher error:', err.message);
    }
  };
  watcher = setInterval(tick, intervalMs);
  tick();
}

// ── Routes: the app registers its device token after login ──────────────────
const router = express.Router();
router.use(express.json());

// POST /api/push/register { employee, token, platform }
router.post('/register', async (req, res) => {
  const employee = String(req.body.employee || '').trim();
  const token = String(req.body.token || '').trim();
  const platform = String(req.body.platform || '').trim().slice(0, 20);
  // Only change the saved sound when the app sends one.
  const soundMode = req.body.soundMode == null ? null : soundModeOf(req.body.soundMode);
  if (!employee || !token) {
    return res.status(400).json({ success: false, message: 'employee and token are required' });
  }
  try {
    await ensureTable();
    // One phone = one person: re-login with another account moves the token.
    await db.query(
      `INSERT INTO push_device_tokens (employee_name, token, platform, sound_mode) VALUES (?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE employee_name = VALUES(employee_name), platform = VALUES(platform),
         sound_mode = IF(?, VALUES(sound_mode), sound_mode), updated_at = CURRENT_TIMESTAMP`,
      [employee, token, platform || null, soundMode || 'app', soundMode ? 1 : 0],
    );
    return res.json({ success: true, enabled: !!fcm() });
  } catch (err) {
    console.error('POST /push/register ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/push/avatar/:name.jpg — profile photo as an image (for notifications)
router.get('/avatar/:name', async (req, res) => {
  const name = String(req.params.name || '').replace(/\.(jpg|jpeg|png)$/i, '').trim();
  try {
    const [[row]] = await db.query(
      'SELECT profile_photo FROM employee_users WHERE LOWER(TRIM(full_name)) = ? LIMIT 1',
      [key(name)],
    );
    const raw = String(row?.profile_photo || '').trim();
    if (!raw) return res.status(404).end();
    const m = raw.match(/^data:(image\/[a-z+]+);base64,(.*)$/i);
    const type = m ? m[1] : 'image/jpeg';
    const buf = Buffer.from(m ? m[2] : raw, 'base64');
    res.set('Content-Type', type);
    res.set('Cache-Control', 'public, max-age=600');
    return res.send(buf);
  } catch (err) {
    return res.status(500).end();
  }
});

// POST /api/push/unregister { token }  (on logout)
router.post('/unregister', async (req, res) => {
  const token = String(req.body.token || '').trim();
  if (!token) return res.status(400).json({ success: false, message: 'token is required' });
  try {
    await ensureTable();
    await db.query('DELETE FROM push_device_tokens WHERE token = ?', [token]);
    return res.json({ success: true });
  } catch (err) {
    console.error('POST /push/unregister ERROR:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/push/test { employee } — sends a test notification to that person.
router.post('/test', async (req, res) => {
  const employee = String(req.body.employee || '').trim();
  if (!employee) return res.status(400).json({ success: false, message: 'employee is required' });
  if (!fcm()) return res.status(503).json({ success: false, message: 'Firebase is not configured on the server' });
  const tokens = await tokensFor([employee]).catch(() => []);
  await sendToEmployees([employee], {
    title: 'GoDigital',
    body: 'Test notification — push is working 🎉',
    data: { type: 'test' },
  });
  return res.json({ success: true, devices: tokens.length, sound: tokens.map((t) => t.mode) });
});

module.exports = {
  router,
  attachIo,
  startNotificationWatcher,
  sendToEmployees,
  plainText,
};
