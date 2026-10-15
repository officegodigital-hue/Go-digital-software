// backend/routes/contentCalendarSheet.js
// CSV helpers for the Content Calendar export/import (Google Sheets / Excel template).
// No external packages needed.

// Template columns, in order. ROW ID lets an import find the exact row again.
const TEMPLATE_COLUMNS = [
  { key: 'id', header: 'ROW ID (do not edit)' },
  { key: 'deliverable', header: 'DELIVERABLE' },
  { key: 's_no', header: 'S.NO' },
  { key: 'submit_date', header: 'SUBMIT DATE (YYYY-MM-DD)' },
  { key: 'hook_headline', header: 'HOOK / HEADLINE' },
  { key: 'description_points', header: 'DESCRIPTION' },
  { key: 'caption', header: 'CAPTION' },
  { key: 'cta', header: 'CTA' },
  { key: 'publish_date', header: 'POST DATE (YYYY-MM-DD)' },
  { key: 'notes', header: 'NOTES' },
];

// Columns an import is allowed to change.
const EDITABLE_KEYS = ['submit_date', 'hook_headline', 'description_points', 'caption', 'cta', 'publish_date', 'notes'];
const DATE_KEYS = new Set(['submit_date', 'publish_date']);

// Header text (any case, extra spaces, brackets) → field key.
const HEADER_ALIASES = {
  id: ['row id', 'rowid', 'id', 'row id do not edit'],
  deliverable: ['deliverable', 'category', 'task', 'content type'],
  s_no: ['s.no', 's no', 'sno', 's.no.', 'serial no', 'serial number', 'no', '#'],
  submit_date: ['submit date', 'submission date', 'submit'],
  hook_headline: ['hook / headline', 'hook/headline', 'hook', 'headline', 'hook headline', 'hook / heading'],
  description_points: ['description', 'description points', 'desc'],
  caption: ['caption'],
  cta: ['cta', 'call to action'],
  publish_date: ['post date', 'publish date', 'posting date', 'post'],
  notes: ['notes', 'note', 'remarks'],
};

function normalizeHeader(h) {
  return (h || '')
    .toString()
    .replace(/^﻿/, '')
    .toLowerCase()
    .replace(/\(.*?\)/g, ' ') // drop "(YYYY-MM-DD)" / "(do not edit)"
    .replace(/\s+/g, ' ')
    .trim();
}

function mapHeaders(headerRow) {
  const map = {}; // key → column index
  headerRow.forEach((h, idx) => {
    const n = normalizeHeader(h);
    if (!n) return;
    for (const [key, aliases] of Object.entries(HEADER_ALIASES)) {
      if (map[key] === undefined && aliases.includes(n)) {
        map[key] = idx;
        return;
      }
    }
  });
  return map;
}

// RFC 4180 CSV parser: quoted fields, escaped quotes, commas/newlines inside quotes, CRLF.
function parseCsv(text) {
  const src = (text || '').toString().replace(/^﻿/, '');
  const rows = [];
  let row = [];
  let field = '';
  let inQuotes = false;

  for (let i = 0; i < src.length; i++) {
    const c = src[i];
    if (inQuotes) {
      if (c === '"') {
        if (src[i + 1] === '"') {
          field += '"';
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field += c;
      }
      continue;
    }
    if (c === '"') inQuotes = true;
    else if (c === ',') {
      row.push(field);
      field = '';
    } else if (c === '\n' || c === '\r') {
      if (c === '\r' && src[i + 1] === '\n') i++;
      row.push(field);
      rows.push(row);
      row = [];
      field = '';
    } else field += c;
  }
  if (field.length || row.length) {
    row.push(field);
    rows.push(row);
  }
  return rows;
}

function csvCell(v) {
  const s = v === null || v === undefined ? '' : v.toString();
  return /[",\r\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

function toCsv(rows) {
  const lines = [TEMPLATE_COLUMNS.map(c => csvCell(c.header)).join(',')];
  for (const r of rows) lines.push(TEMPLATE_COLUMNS.map(c => csvCell(r[c.key])).join(','));
  // BOM so Excel opens UTF-8 (Tamil text, emojis) correctly; Google Sheets ignores it.
  return '﻿' + lines.join('\r\n') + '\r\n';
}

const MONTHS = { jan: 1, feb: 2, mar: 3, apr: 4, may: 5, jun: 6, jul: 7, aug: 8, sep: 9, sept: 9, oct: 10, nov: 11, dec: 12 };

function isoIfValid(y, m, d) {
  y = Number(y);
  m = Number(m);
  d = Number(d);
  if (y < 100) y += 2000;
  const dt = new Date(Date.UTC(y, m - 1, d));
  if (dt.getUTCFullYear() !== y || dt.getUTCMonth() !== m - 1 || dt.getUTCDate() !== d) return null;
  return `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
}

// Returns { value: 'YYYY-MM-DD' | null } or { error }.
// Accepts 2026-11-05, 2026/11/05, 05/11/2026 (day first, Indian format), 5-11-2026,
// 05.11.2026, 05 Nov 2026, 5-Nov-2026, Nov 5 2026. Blank → null (clears the date).
function parseSheetDate(raw) {
  const s = (raw || '').toString().trim();
  if (!s) return { value: null };
  let m;
  if ((m = s.match(/^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})(?:[ T].*)?$/))) {
    const v = isoIfValid(m[1], m[2], m[3]);
    return v ? { value: v } : { error: `"${s}" is not a real date` };
  }
  if ((m = s.match(/^(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})$/))) {
    const v = isoIfValid(m[3], m[2], m[1]);
    return v ? { value: v } : { error: `"${s}" is not a real date (use DD/MM/YYYY)` };
  }
  if ((m = s.match(/^(\d{1,2})[\s-]+([A-Za-z]{3,9})[\s,-]+(\d{2,4})$/))) {
    const mo = MONTHS[m[2].slice(0, 4).toLowerCase()] || MONTHS[m[2].slice(0, 3).toLowerCase()];
    const v = mo && isoIfValid(m[3], mo, m[1]);
    return v ? { value: v } : { error: `"${s}" is not a real date` };
  }
  if ((m = s.match(/^([A-Za-z]{3,9})[\s-]+(\d{1,2}),?[\s-]+(\d{2,4})$/))) {
    const mo = MONTHS[m[1].slice(0, 4).toLowerCase()] || MONTHS[m[1].slice(0, 3).toLowerCase()];
    const v = mo && isoIfValid(m[3], mo, m[2]);
    return v ? { value: v } : { error: `"${s}" is not a real date` };
  }
  return { error: `"${s}" is not a date (use YYYY-MM-DD)` };
}

/**
 * Turn CSV text into a list of updates against the client's existing rows.
 * existingRows: [{ id, deliverable, s_no }]
 * defaultDeliverable: used when the sheet has no DELIVERABLE column.
 * Returns { updates: [{ id, deliverable, s_no, fields }], skipped: [{ line, reason }], columns: [keys] }
 */
function planImport(csvText, existingRows, defaultDeliverable) {
  const table = parseCsv(csvText).filter(r => r.some(c => (c || '').toString().trim() !== ''));
  if (table.length === 0) return { error: 'The file is empty.' };

  const headers = mapHeaders(table[0]);
  const editable = EDITABLE_KEYS.filter(k => headers[k] !== undefined);
  if (headers.id === undefined && headers.s_no === undefined) {
    return { error: 'No "S.NO" or "ROW ID" column found. Use the exported template.' };
  }
  if (editable.length === 0) {
    return { error: 'No content columns found (Hook / Description / Caption / CTA / dates / Notes).' };
  }

  const byId = new Map();
  const byKey = new Map();
  for (const r of existingRows) {
    byId.set(String(r.id), r);
    byKey.set(`${(r.deliverable || '').toString().trim().toUpperCase()}|${Number(r.s_no)}`, r);
  }

  const updates = [];
  const skipped = [];
  const touched = new Set();

  for (let i = 1; i < table.length; i++) {
    const cells = table[i];
    const line = i + 1; // spreadsheet row number
    const cell = key => (headers[key] === undefined ? undefined : (cells[headers[key]] ?? '').toString().trim());

    let target = null;
    const idVal = cell('id');
    if (idVal) target = byId.get(idVal) || null;
    if (!target) {
      const sno = Number(cell('s_no'));
      const deliv = (cell('deliverable') || defaultDeliverable || '').toUpperCase();
      if (sno && deliv) target = byKey.get(`${deliv}|${sno}`) || null;
      if (!target) {
        skipped.push({
          line,
          reason: !sno
            ? 'No S.NO'
            : !deliv
              ? 'No DELIVERABLE'
              : `${cell('deliverable') || defaultDeliverable} #${sno} is not in this calendar`,
        });
        continue;
      }
    }
    if (touched.has(target.id)) {
      skipped.push({ line, reason: `Duplicate of ${target.deliverable} #${target.s_no} — first one used` });
      continue;
    }

    const fields = {};
    let badDate = null;
    for (const key of editable) {
      const v = cell(key);
      if (DATE_KEYS.has(key)) {
        const parsed = parseSheetDate(v);
        if (parsed.error) {
          badDate = `${key === 'submit_date' ? 'Submit date' : 'Post date'} ${parsed.error}`;
          break;
        }
        fields[key] = parsed.value;
      } else {
        fields[key] = v;
      }
    }
    if (badDate) {
      skipped.push({ line, reason: badDate });
      continue;
    }

    touched.add(target.id);
    updates.push({ id: target.id, deliverable: target.deliverable, s_no: target.s_no, fields });
  }

  return { updates, skipped, columns: editable };
}

module.exports = { TEMPLATE_COLUMNS, EDITABLE_KEYS, parseCsv, toCsv, parseSheetDate, planImport, mapHeaders };

