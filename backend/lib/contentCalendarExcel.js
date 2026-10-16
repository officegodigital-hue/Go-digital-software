// lib/contentCalendarExcel.js — Content Calendar export template + import.
//
// Export: a styled blue & white .xlsx (opens directly in Google Sheets /
//         Excel). Grey-blue columns are locked keys, white columns are edited.
// Import: the same file back as .xlsx (Google Sheets → File → Download →
//         Microsoft Excel) or as .csv. Rows are matched by ID (or S.No).
//
// Needs:  npm install exceljs
// Loaded only when Export / Import is used, so the server still starts if
// the package is missing (you get a clear message instead of a crash).
let ExcelJS = null;
function excel() {
  if (!ExcelJS) {
    try {
      ExcelJS = require('exceljs');
    } catch (_) {
      throw new Error('The "exceljs" package is not installed on the server. Run: npm install exceljs');
    }
  }
  return ExcelJS;
}

const BLUE = 'FF0757D5';
const DEEP = 'FF0A3D91';
const NAVY = 'FF062F7A';
const TINT = 'FFEFF5FF';
const STRIPE = 'FFF7FAFF';
const KEY = 'FFE3ECFB';
const LINE = 'FFD6E2F5';
const INK = 'FF14213D';
const MUTED = 'FF64748B';

// key → { header, width, locked, date }
const COLUMNS = [
  { key: 'id', header: 'ID', width: 9, locked: true },
  { key: 's_no', header: 'S.No', width: 7, locked: true },
  { key: 'deliverable', header: 'Deliverable', width: 16, locked: true },
  { key: 'submit_date', header: 'Submit Date (YYYY-MM-DD)', width: 17, date: true },
  { key: 'hook_headline', header: 'Hook / Headline', width: 34 },
  { key: 'description_points', header: 'Description', width: 48 },
  { key: 'caption', header: 'Caption', width: 40 },
  { key: 'cta', header: 'CTA', width: 20 },
  { key: 'publish_date', header: 'Publish Date (YYYY-MM-DD)', width: 17, date: true },
  { key: 'notes', header: 'Notes', width: 30 },
];
const EDITABLE = COLUMNS.filter((c) => !c.locked).map((c) => c.key);
const HEADER_ROW = 6;

const pad = (n) => String(n).padStart(2, '0');
function ymd(value) {
  if (value === null || value === undefined || value === '') return '';
  if (value instanceof Date) {
    if (Number.isNaN(value.getTime())) return '';
    return `${value.getFullYear()}-${pad(value.getMonth() + 1)}-${pad(value.getDate())}`;
  }
  return String(value).slice(0, 10);
}

const norm = (v) => String(v ?? '').toLowerCase().replace(/[^a-z0-9]/g, '');
const HEADER_ALIASES = {
  id: 'id',
  sno: 's_no', slno: 's_no', serialno: 's_no', no: 's_no',
  deliverable: 'deliverable',
  submitdate: 'submit_date', submitdateyyyymmdd: 'submit_date', submit: 'submit_date',
  hookheadline: 'hook_headline', headline: 'hook_headline', hook: 'hook_headline',
  description: 'description_points', descriptionpoints: 'description_points',
  caption: 'caption',
  cta: 'cta',
  publishdate: 'publish_date', publishdateyyyymmdd: 'publish_date',
  notes: 'notes', note: 'notes',
};

// ─── Export ────────────────────────────────────────────────────────────────
async function buildTemplate({ clientName, deliverable, rows, exportedBy = '' }) {
  const wb = new (excel().Workbook)();
  wb.creator = 'GoDigital';
  wb.created = new Date();

  const ws = wb.addWorksheet('Content Calendar', {
    views: [{ state: 'frozen', xSplit: 3, ySplit: HEADER_ROW, showGridLines: false }],
    properties: { tabColor: { argb: BLUE } },
  });
  ws.columns = COLUMNS.map((c) => ({ key: c.key, width: c.width }));
  const last = String.fromCharCode(64 + COLUMNS.length); // J

  const band = (row, text, { fill, size = 11, bold = false, italic = false, color = 'FFFFFFFF', height = 22 }) => {
    ws.mergeCells(`A${row}:${last}${row}`);
    const cell = ws.getCell(`A${row}`);
    cell.value = text;
    cell.font = { name: 'Arial', size, bold, italic, color: { argb: color } };
    cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: fill } };
    cell.alignment = { vertical: 'middle', horizontal: 'left', indent: 1, wrapText: true };
    ws.getRow(row).height = height;
  };

  const today = new Date();
  band(1, 'GoDigital  ·  Content Calendar', { fill: NAVY, size: 18, bold: true, height: 38 });
  band(2, `Client:  ${clientName}     ·     Deliverable:  ${deliverable}     ·     ${rows.length} row${rows.length === 1 ? '' : 's'}`,
    { fill: BLUE, size: 12, bold: true, height: 26 });
  band(3, `Exported ${ymd(today)}${exportedBy ? ` by ${exportedBy}` : ''}`,
    { fill: DEEP, size: 10, color: 'FFDCE8FF', height: 20 });
  band(4,
    'How to fill:  edit only the WHITE columns.  Keep ID, S.No and Deliverable as they are.  '
    + 'Dates as YYYY-MM-DD.  When done: File → Download → Microsoft Excel (.xlsx), then press "Import Sheet".',
    { fill: TINT, size: 10, italic: true, color: DEEP, height: 34 });
  ws.getRow(5).height = 6;

  // Header
  const header = ws.getRow(HEADER_ROW);
  COLUMNS.forEach((c, i) => {
    const cell = header.getCell(i + 1);
    cell.value = c.header;
    cell.font = { name: 'Arial', size: 10.5, bold: true, color: { argb: 'FFFFFFFF' } };
    cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: c.locked ? DEEP : BLUE } };
    cell.alignment = { vertical: 'middle', horizontal: 'center', wrapText: true };
    cell.border = {
      top: { style: 'thin', color: { argb: NAVY } },
      bottom: { style: 'medium', color: { argb: NAVY } },
      left: { style: 'thin', color: { argb: 'FF3B7BE0' } },
      right: { style: 'thin', color: { argb: 'FF3B7BE0' } },
    };
  });
  header.height = 30;

  // Data
  rows.forEach((r, idx) => {
    const rowNo = HEADER_ROW + 1 + idx;
    const row = ws.getRow(rowNo);
    const stripe = idx % 2 === 1;
    COLUMNS.forEach((c, i) => {
      const cell = row.getCell(i + 1);
      let v = r[c.key];
      if (c.date) v = ymd(v);
      cell.value = v === null || v === undefined ? '' : (c.key === 'id' || c.key === 's_no' ? Number(v) || v : String(v));
      cell.font = {
        name: 'Arial',
        size: 10,
        bold: c.key === 's_no' || c.key === 'hook_headline',
        color: { argb: c.locked ? MUTED : INK },
      };
      cell.fill = {
        type: 'pattern',
        pattern: 'solid',
        fgColor: { argb: c.locked ? KEY : stripe ? STRIPE : 'FFFFFFFF' },
      };
      cell.alignment = {
        vertical: 'top',
        horizontal: c.locked || c.date ? 'center' : 'left',
        wrapText: true,
      };
      cell.border = {
        top: { style: 'hair', color: { argb: LINE } },
        bottom: { style: 'thin', color: { argb: LINE } },
        left: { style: 'thin', color: { argb: LINE } },
        right: { style: 'thin', color: { argb: LINE } },
      };
      if (c.date) {
        cell.numFmt = '@';
        cell.dataValidation = {
          type: 'custom',
          allowBlank: true,
          formulae: [`OR(${cell.address}="",LEN(${cell.address})=10)`],
          showErrorMessage: true,
          errorTitle: 'Date format',
          error: 'Use YYYY-MM-DD, e.g. 2026-10-29',
        };
      }
    });
    row.height = 36;
  });

  // A few empty styled rows are NOT added: new rows are created with
  // "Add content" in the app so every row has an ID.
  ws.autoFilter = { from: { row: HEADER_ROW, column: 1 }, to: { row: HEADER_ROW, column: COLUMNS.length } };

  // Guide sheet
  const guide = wb.addWorksheet('How to use', {
    views: [{ showGridLines: false }],
    properties: { tabColor: { argb: DEEP } },
  });
  guide.getColumn(1).width = 4;
  guide.getColumn(2).width = 96;
  const steps = [
    ['GoDigital  ·  Content Calendar template', true],
    ['1.  Open this file in Google Sheets: drive.google.com → New → File upload, then "Open with Google Sheets" (or File → Import in a sheet).', false],
    ['2.  Fill only the WHITE columns: Submit Date, Hook / Headline, Description, Caption, CTA, Publish Date, Notes.', false],
    ['3.  Do not change ID, S.No or Deliverable (blue-grey columns) — they tell the app which row to update.', false],
    ['4.  Dates must be YYYY-MM-DD (for example 2026-10-29).', false],
    ['5.  Google Sheets: File → Download → Microsoft Excel (.xlsx).  (CSV also works.)', false],
    ['6.  In the app: Content Calendar → Import Sheet → choose the file → check the preview → Apply import.', false],
    ['New rows: add them in the app with "Add content" first, export again, then fill them here.', false],
  ];
  steps.forEach(([text, title], i) => {
    const cell = guide.getCell(`B${i + 2}`);
    cell.value = text;
    cell.alignment = { vertical: 'middle', wrapText: true, indent: 1 };
    if (title) {
      cell.font = { name: 'Arial', size: 16, bold: true, color: { argb: 'FFFFFFFF' } };
      cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: NAVY } };
      guide.getRow(i + 2).height = 36;
    } else {
      cell.font = { name: 'Arial', size: 11, color: { argb: INK } };
      cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: i % 2 ? 'FFFFFFFF' : TINT } };
      cell.border = { bottom: { style: 'thin', color: { argb: LINE } } };
      guide.getRow(i + 2).height = 30;
    }
  });

  return Buffer.from(await wb.xlsx.writeBuffer());
}

// ─── Import ────────────────────────────────────────────────────────────────
function parseCsv(text) {
  const rows = [];
  let row = [];
  let cell = '';
  let quoted = false;
  const s = String(text || '').replace(/^﻿/, '');
  for (let i = 0; i < s.length; i += 1) {
    const ch = s[i];
    if (quoted) {
      if (ch === '"') {
        if (s[i + 1] === '"') { cell += '"'; i += 1; } else quoted = false;
      } else cell += ch;
    } else if (ch === '"') quoted = true;
    else if (ch === ',') { row.push(cell); cell = ''; }
    else if (ch === '\n' || ch === '\r') {
      if (ch === '\r' && s[i + 1] === '\n') i += 1;
      row.push(cell); rows.push(row); row = []; cell = '';
    } else cell += ch;
  }
  if (cell !== '' || row.length) { row.push(cell); rows.push(row); }
  return rows;
}

function cellText(v) {
  if (v === null || v === undefined) return '';
  if (v instanceof Date) return ymd(v);
  if (typeof v === 'object') {
    if (v.richText) return v.richText.map((t) => t.text).join('');
    if (v.text !== undefined) return String(v.text);
    if (v.result !== undefined) return cellText(v.result);
    return '';
  }
  return String(v);
}

async function readXlsx(base64) {
  const wb = new (excel().Workbook)();
  await wb.xlsx.load(Buffer.from(String(base64), 'base64'));
  const ws = wb.getWorksheet('Content Calendar') || wb.worksheets[0];
  if (!ws) return [];
  const out = [];
  ws.eachRow({ includeEmpty: true }, (row, rowNumber) => {
    const values = [];
    for (let c = 1; c <= Math.max(row.cellCount, COLUMNS.length); c += 1) {
      values.push(cellText(row.getCell(c).value));
    }
    out[rowNumber - 1] = values;
  });
  return out.map((r) => r || []);
}

/** [[cells]] → { columns: [key|null], records: [{ line, values }] } */
function toRecords(grid) {
  const headerIdx = grid.findIndex((r) => r.some((c) => ['id', 'sno'].includes(norm(c))));
  if (headerIdx < 0) return { error: 'Could not find the header row (ID / S.No). Use the exported template.' };
  const columns = grid[headerIdx].map((h) => HEADER_ALIASES[norm(h)] || null);
  const records = [];
  for (let i = headerIdx + 1; i < grid.length; i += 1) {
    const cells = grid[i] || [];
    if (!cells.some((c) => String(c ?? '').trim() !== '')) continue;
    const values = {};
    columns.forEach((key, j) => { if (key) values[key] = String(cells[j] ?? '').trim(); });
    records.push({ line: i + 1, values });
  }
  return { columns, records };
}

function parseDate(text) {
  const s = String(text || '').trim();
  if (!s) return { value: null };
  let m = s.match(/^(\d{4})-(\d{1,2})-(\d{1,2})/);
  if (m) return { value: `${m[1]}-${pad(m[2])}-${pad(m[3])}` };
  m = s.match(/^(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})$/); // DD/MM/YYYY
  if (m) return { value: `${m[3]}-${pad(m[2])}-${pad(m[1])}` };
  if (/^\d{5}$/.test(s)) { // spreadsheet serial number
    const d = new Date(Date.UTC(1899, 11, 30) + Number(s) * 86400000);
    return { value: `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}` };
  }
  return { error: `"${s}" is not a date (use YYYY-MM-DD)` };
}

/**
 * Compare the uploaded rows with the database rows.
 * dbRows: full content_calendar rows of this client + deliverable.
 * Returns { updates: [{ id, fields }], skipped: [{ line, reason }], columns: [header labels] }
 */
function planUpdates(parsed, dbRows) {
  if (parsed.error) return { error: parsed.error };
  const present = EDITABLE.filter((k) => parsed.columns.includes(k));
  if (!present.length) return { error: 'No editable columns found (Hook / Headline, Description, Caption …).' };
  const byId = new Map(dbRows.map((r) => [Number(r.id), r]));
  const bySno = new Map(dbRows.map((r) => [Number(r.s_no), r]));
  const updates = [];
  const skipped = [];
  const seen = new Set();
  for (const rec of parsed.records) {
    const v = rec.values;
    const id = Number(v.id);
    const target = (id && byId.get(id)) || (!v.id && Number(v.s_no) && bySno.get(Number(v.s_no))) || null;
    if (!target) {
      skipped.push({ line: rec.line, reason: v.id ? `ID ${v.id} is not in this ${dbRows[0]?.deliverable || 'sheet'}` : 'No matching ID / S.No' });
      continue;
    }
    if (seen.has(target.id)) {
      skipped.push({ line: rec.line, reason: `ID ${target.id} appears twice — only the first is used` });
      continue;
    }
    seen.add(target.id);
    const fields = {};
    let bad = null;
    for (const key of present) {
      let next = v[key] ?? '';
      if (key === 'submit_date' || key === 'publish_date') {
        const d = parseDate(next);
        if (d.error) { bad = d.error; break; }
        next = d.value;
        if ((next || '') !== ymd(target[key])) fields[key] = next;
      } else {
        const current = String(target[key === 'description_points' ? 'description' : key] ?? '');
        if (next !== current) fields[key] = next;
      }
    }
    if (bad) { skipped.push({ line: rec.line, reason: bad }); continue; }
    if (Object.keys(fields).length) updates.push({ id: target.id, fields });
  }
  const labels = COLUMNS.filter((c) => present.includes(c.key)).map((c) => c.header.replace(/ \(YYYY-MM-DD\)/, ''));
  return { updates, skipped, columns: labels };
}

async function parseUpload({ csv, xlsx_base64: xlsx }) {
  if (xlsx) return toRecords(await readXlsx(xlsx));
  if (typeof csv === 'string') return toRecords(parseCsv(csv));
  return { error: 'Upload an .xlsx or .csv file' };
}

module.exports = { buildTemplate, parseUpload, planUpdates, COLUMNS };
