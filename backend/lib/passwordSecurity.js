// lib/passwordSecurity.js
//
// Passwords are stored two ways in employee_users:
//   password      → bcrypt hash (one-way). Used for login. Nobody can read it.
//   password_enc  → AES-256-GCM encrypted copy. Only this server can decrypt it,
//                   and only for a Main Admin (Admin Panel → "show password").
//
// Set PASSWORD_ENC_KEY in .env (64 hex characters) — generate one with:
//   node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
// Keep it secret and never change it, or stored copies cannot be decrypted
// (login keeps working; the admin just sets a new password).
//
// Existing plain-text passwords are converted automatically at startup.

const crypto = require('crypto');
const bcrypt = require('bcrypt');
const db = require('../config/db');

const BCRYPT_ROUNDS = 12;
const isBcryptHash = (v) => typeof v === 'string' && /^\$2[aby]\$\d{2}\$/.test(v);

let cachedKey = null;
function encKey() {
  if (cachedKey) return cachedKey;
  const raw = String(process.env.PASSWORD_ENC_KEY || '').trim();
  if (/^[0-9a-fA-F]{64}$/.test(raw)) {
    cachedKey = Buffer.from(raw, 'hex');
  } else {
    if (raw) console.warn('PASSWORD_ENC_KEY must be 64 hex characters — using a key derived from JWT_SECRET.');
    else console.warn('PASSWORD_ENC_KEY is not set — using a key derived from JWT_SECRET. Set PASSWORD_ENC_KEY in .env.');
    const secret = process.env.JWT_SECRET || 'change-this-in-production-to-random-key';
    cachedKey = crypto.scryptSync(secret, 'godigital-password-enc', 32);
  }
  return cachedKey;
}

/** One-way hash for login. */
async function hashPassword(plain) {
  return bcrypt.hash(String(plain), BCRYPT_ROUNDS);
}

/** Login check. Works for bcrypt hashes and (until migrated) old plain text. */
async function verifyPassword(plain, stored) {
  if (!stored) return { ok: false, legacy: false };
  if (isBcryptHash(stored)) {
    return { ok: await bcrypt.compare(String(plain), stored), legacy: false };
  }
  // Old plain-text value: constant-time compare.
  const a = Buffer.from(String(plain));
  const b = Buffer.from(String(stored));
  const ok = a.length === b.length && crypto.timingSafeEqual(a, b);
  return { ok, legacy: true };
}

/** Reversible copy for the Main Admin view: "v1:iv:tag:data" (base64). */
function encryptPassword(plain) {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', encKey(), iv);
  const data = Buffer.concat([cipher.update(String(plain), 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return `v1:${iv.toString('base64')}:${tag.toString('base64')}:${data.toString('base64')}`;
}

function decryptPassword(value) {
  try {
    const [v, iv, tag, data] = String(value || '').split(':');
    if (v !== 'v1' || !iv || !tag || !data) return null;
    const decipher = crypto.createDecipheriv('aes-256-gcm', encKey(), Buffer.from(iv, 'base64'));
    decipher.setAuthTag(Buffer.from(tag, 'base64'));
    return Buffer.concat([decipher.update(Buffer.from(data, 'base64')), decipher.final()]).toString('utf8');
  } catch (_) {
    return null; // wrong key or tampered value
  }
}

/** Both columns for a new / changed password. */
async function passwordColumns(plain) {
  return { hash: await hashPassword(plain), enc: encryptPassword(plain) };
}

/** Save a new password for one user (hash + encrypted copy). */
async function setUserPassword(conn, userId, plain) {
  const { hash, enc } = await passwordColumns(plain);
  await (conn || db).query(
    'UPDATE employee_users SET password = ?, password_enc = ? WHERE id = ?',
    [hash, enc, userId],
  );
}

// ── Schema + one-time migration of plain-text passwords ──
let ready = null;
function ensurePasswordSecurity() {
  if (!ready) {
    ready = (async () => {
      const [cols] = await db.query(
        `SELECT COLUMN_NAME AS c, CHARACTER_MAXIMUM_LENGTH AS len, IS_NULLABLE AS nullable
         FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'employee_users'
           AND COLUMN_NAME IN ('password', 'password_enc')`,
      );
      const byName = new Map(cols.map((r) => [r.c, r]));
      const pw = byName.get('password');
      if (pw && Number(pw.len) > 0 && Number(pw.len) < 100) {
        await db.query(
          `ALTER TABLE employee_users MODIFY password VARCHAR(255) ${pw.nullable === 'NO' ? 'NOT NULL' : 'NULL'}`,
        );
        console.log('Password security: widened employee_users.password for hashes');
      }
      if (!byName.has('password_enc')) {
        await db.query('ALTER TABLE employee_users ADD COLUMN password_enc TEXT NULL');
        console.log('Password security: added employee_users.password_enc');
      }

      // Convert every remaining plain-text password.
      const [rows] = await db.query(
        "SELECT id, password FROM employee_users WHERE password IS NOT NULL AND password <> '' AND password NOT LIKE '$2%'",
      );
      let converted = 0;
      for (const r of rows) {
        if (isBcryptHash(r.password)) continue;
        const { hash, enc } = await passwordColumns(r.password);
        // Only if it was not changed meanwhile.
        const [res] = await db.query(
          'UPDATE employee_users SET password = ?, password_enc = ? WHERE id = ? AND password = ?',
          [hash, enc, r.id, r.password],
        );
        converted += res.affectedRows || 0;
      }
      if (converted) console.log(`Password security: ${converted} plain-text password(s) hashed and encrypted`);
    })().catch((err) => {
      ready = null; // retry next time
      console.error('Password security setup failed:', err.message);
    });
  }
  return ready;
}

module.exports = {
  isBcryptHash,
  hashPassword,
  verifyPassword,
  encryptPassword,
  decryptPassword,
  passwordColumns,
  setUserPassword,
  ensurePasswordSecurity,
};
