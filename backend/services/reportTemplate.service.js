'use strict';

const { execFile } = require('node:child_process');
const fsSync = require('node:fs');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const { promisify } = require('node:util');
const { pathToFileURL } = require('node:url');
const JSZip = require('jszip');
const { buildDocxFromImages } = require('./fullReportWord.service');

const execFileAsync = promisify(execFile);
const MAX_TEMPLATE_BYTES = 10 * 1024 * 1024;
const RELATIONSHIPS_NS = 'http://schemas.openxmlformats.org/package/2006/relationships';

function providerKey(value) {
  return String(value || '').toUpperCase().replace(/[^A-Z0-9]+/g, '_').replace(/^_+|_+$/g, '');
}

function canonicalProviderKey(value) {
  const key = providerKey(value);
  if (['GMB', 'GBP', 'GOOGLE_MY_BUSINESS', 'GOOGLE_BUSINESS_PROFILE_DASHBOARD'].includes(key)) {
    return 'GOOGLE_BUSINESS_PROFILE';
  }
  if (key === 'LINKEDIN_ORGANIC') return 'LINKEDIN';
  if (['TWITTER', 'X'].includes(key)) return 'TWITTER_X';
  return key;
}

function decodeXml(value) {
  return String(value || '')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&amp;/g, '&');
}

function escapeXml(value) {
  return String(value == null ? '' : value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

async function loadPowerPointTemplate(bytes) {
  if (!Buffer.isBuffer(bytes) || !bytes.length) {
    throw new Error('The active report template is empty.');
  }
  if (bytes.length > MAX_TEMPLATE_BYTES) {
    throw new Error('The active report template exceeds the 10 MB limit.');
  }
  const zip = await JSZip.loadAsync(bytes);
  if (!zip.file('ppt/presentation.xml') || !zip.file('[Content_Types].xml')) {
    throw new Error('The active report template is not a valid PowerPoint file.');
  }
  return zip;
}

// True when any slide contains a {{...}} placeholder the filler can replace.
async function templateHasPlaceholders(bytes) {
  try {
    const zip = await loadPowerPointTemplate(bytes);
    const slideFiles = Object.keys(zip.files).filter((name) =>
      /^ppt\/slides\/slide\d+\.xml$/.test(name),
    );
    const hasTokens = await Promise.all(
      slideFiles.map(async (name) =>
        (await zip.file(name).async('string')).includes('{{'),
      ),
    );
    return hasTokens.some(Boolean);
  } catch (_) {
    return false;
  }
}

// Accept any real PowerPoint file as a template. Placeholders are optional;
// when absent, the uploaded slides remain the report design unchanged.
async function validatePowerPointTemplate(bytes) {
  await loadPowerPointTemplate(bytes); // throws only if it is not a valid .pptx
  return templateHasPlaceholders(bytes);
}

function addField(fields, key, value, { overwrite = false } = {}) {
  if (value == null || typeof value === 'object') return;
  const normalized = String(key || '').trim().toLowerCase().replace(/[^a-z0-9_.-]+/g, '_');
  if (!normalized || (!overwrite && fields.has(normalized))) return;
  fields.set(normalized, String(value));
}

function numericMetric(value) {
  if (value == null) return null;
  const text = String(value).trim().replace(/,/g, '');
  const match = text.match(/^-?\d+(?:\.\d+)?/);
  if (!match) return null;
  const number = Number(match[0]);
  if (!Number.isFinite(number)) return null;
  if (/k$/i.test(text)) return number * 1000;
  if (/m$/i.test(text)) return number * 1000000;
  return number;
}

function monthOverMonth(current, previous) {
  const currentValue = numericMetric(current);
  const previousValue = numericMetric(previous);
  if (currentValue == null || previousValue == null || previousValue === 0) return null;
  const change = ((currentValue - previousValue) / previousValue) * 100;
  const rounded = Math.round(change * 10) / 10;
  if (rounded === 0) return '0% change';
  return `${Math.abs(rounded).toString().replace(/\.0$/, '')}% ${rounded > 0 ? 'increase' : 'decrease'}`;
}

function reportFields(payload) {
  const fields = new Map();
  addField(fields, 'client_name', payload.clientName);
  addField(fields, 'client_brand', payload.clientName);
  addField(fields, 'report_month', payload.reportMonthLabel || payload.report_month_label
    || monthYearLabel(payload.reportMonth, payload.reportYear));
  addField(fields, 'report_year', payload.reportYear);
  addField(fields, 'period_label', payload.periodLabel);
  addField(fields, 'date_range', payload.dateRange);
  addField(fields, 'prepared_by', payload.preparedBy);

  const cover = payload.cover_edits || payload.coverEdits || {};
  for (const [label, value] of Object.entries(cover)) {
    const key = label.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
    addField(fields, key, value, { overwrite: true });
  }

  for (const snapshot of Array.isArray(payload.snapshots) ? payload.snapshots : []) {
    const provider = canonicalProviderKey(snapshot?.provider).toLowerCase();
    const metrics = snapshot?.metrics;
    if (!provider || !metrics || typeof metrics !== 'object') continue;
    for (const [key, value] of Object.entries(metrics)) {
      if (key === 'export_overrides' || value == null || typeof value === 'object') continue;
      addField(fields, `${provider}_${key}`, value, { overwrite: true });
      addField(fields, key, value);
    }
  }

  const previousByProvider = new Map(
    (Array.isArray(payload.lastMonthSnapshots) ? payload.lastMonthSnapshots : [])
      .map((snapshot) => [canonicalProviderKey(snapshot?.provider).toLowerCase(), snapshot?.metrics]),
  );
  for (const snapshot of Array.isArray(payload.snapshots) ? payload.snapshots : []) {
    const provider = canonicalProviderKey(snapshot?.provider).toLowerCase();
    const currentMetrics = snapshot?.metrics;
    const previousMetrics = previousByProvider.get(provider);
    if (!provider || !currentMetrics || !previousMetrics
        || typeof currentMetrics !== 'object' || typeof previousMetrics !== 'object') continue;
    for (const [key, current] of Object.entries(currentMetrics)) {
      if (key === 'export_overrides' || typeof current === 'object') continue;
      const change = monthOverMonth(current, previousMetrics[key]);
      if (!change) continue;
      addField(fields, `${provider}_${key}_vs_last_month`, change, { overwrite: true });
      addField(fields, `${provider}_${key}_percentage_change`, change, { overwrite: true });
      addField(fields, `${key}_vs_last_month`, change);
      addField(fields, `${key}_percentage_change`, change);
    }
  }

  const slideEdits = payload.slide_edits || payload.slideEdits || {};
  for (const edits of Object.values(slideEdits)) {
    if (!edits || typeof edits !== 'object') continue;
    for (const [label, value] of Object.entries(edits)) {
      const key = label.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
      addField(fields, key, value, { overwrite: true });
    }
  }
  return fields;
}

function slideText(xml) {
  return [...String(xml).matchAll(/<a:t\b[^>]*>([\s\S]*?)<\/a:t>/g)]
    .map((match) => decodeXml(match[1]))
    .join(' ')
    .toLowerCase();
}

function slideTitle(xml) {
  return [...String(xml).matchAll(/<a:t\b[^>]*>([\s\S]*?)<\/a:t>/g)]
    .map((match) => decodeXml(match[1]).trim())
    .filter(Boolean)
    .slice(0, 8)
    .join(' ')
    .slice(0, 255);
}

function slideProvider(xml) {
  const textNodes = [...String(xml).matchAll(/<a:t\b[^>]*>([\s\S]*?)<\/a:t>/g)]
    .map((match) => decodeXml(match[1]).toLowerCase());
  const title = textNodes.slice(0, 8).join(' ');
  const allText = textNodes.join(' ');
  if (/client monthly report|channel summary|creatives published|creative showcase|next month plan/.test(title)) {
    return null;
  }
  const rules = [
    ['LOCAL_SEO', [/google business profile ranking|ranking by gmb|local seo/, /screenshot:local_seo|local_seo_/]],
    ['GOOGLE_BUSINESS_PROFILE', [/google business profile|google my business|gmb\s*\/\s*gbp/, /screenshot:google_business_profile|google_business_profile_/]],
    ['GOOGLE_ANALYTICS', [/google analytics|google analytics 4|ga4/, /google_analytics_|screenshot:google_analytics/]],
    ['GOOGLE_SEARCH_CONSOLE', [/google search console|search console/, /google_search_console_|screenshot:google_search_console/]],
    ['GOOGLE_ADS', [/google ads/, /google_ads_|screenshot:google_ads/]],
    ['META_ADS', [/meta ads/, /meta_ads_|screenshot:meta_ads/]],
    ['LINKEDIN_ADS', [/linkedin ads/, /linkedin_ads_|screenshot:linkedin_ads/]],
    ['YOUTUBE', [/youtube/, /youtube_|screenshot:youtube/]],
    ['FACEBOOK', [/facebook/, /facebook_|screenshot:facebook/]],
    ['INSTAGRAM', [/instagram/, /instagram_|screenshot:instagram/]],
    ['LINKEDIN', [/linkedin/, /linkedin_|screenshot:linkedin/]],
    ['TWITTER_X', [/twitter|x analytics/, /twitter_|twitter_x_|screenshot:twitter/]],
  ];
  return rules.find(([, patterns]) =>
    patterns.some((pattern) => pattern.test(title) || pattern.test(allText)))?.[0] || null;
}

function isSharedReportSlide(xml) {
  const title = slideTitle(xml).toLowerCase();
  return /client monthly report|channel summary|creatives published|creative showcase|next month plan/
    .test(title);
}

function slideHasFilledTemplateField(xml, fields) {
  for (const [paragraph] of xml.matchAll(/<a:p\b[^>]*>[\s\S]*?<\/a:p>/g)) {
    const text = [...paragraph.matchAll(/<a:t\b[^>]*>([\s\S]*?)<\/a:t>/g)]
      .map((match) => decodeXml(match[1])).join('');
    for (const [, key] of text.matchAll(/\{\{\s*([a-z0-9_.-]+)\s*\}\}/gi)) {
      if (fields.get(key.toLowerCase())?.trim()) return true;
    }
  }
  return false;
}
async function extractPowerPointTemplatePages(templateBytes) {
  const zip = await loadPowerPointTemplate(templateBytes);
  const presentation = await zip.file('ppt/presentation.xml')?.async('string');
  const relationships = await zip.file('ppt/_rels/presentation.xml.rels')?.async('string');
  if (!presentation || !relationships) {
    throw new Error('The active report template has no readable slide list.');
  }
  const slides = presentationSlides(presentation, relationships);
  const pages = [];
  for (const [index, slide] of slides.entries()) {
    const xml = zip.file(slide.slidePath);
    if (!xml) throw new Error('The active report template contains a missing slide.');
    const content = await xml.async('string');
    const title = slideTitle(content) || `Report page ${index + 1}`;
    const provider = slideProvider(content);
    const mandatory = /client monthly report|channel summary|creatives published|creative showcase|next month plan/i
      .test(title);
    pages.push({
      id: index + 1,
      provider_code: provider || (mandatory ? 'mandatory' : 'unknown'),
      page_title: title,
      required_static: mandatory ? 1 : 0,
    });
  }
  return pages;
}

async function extractPowerPointTemplateFields(templateBytes) {
  const zip = await loadPowerPointTemplate(templateBytes);
  const presentation = await zip.file('ppt/presentation.xml')?.async('string');
  const relationships = await zip.file('ppt/_rels/presentation.xml.rels')?.async('string');
  if (!presentation || !relationships) {
    throw new Error('The active report template has no readable slide list.');
  }
  const pages = presentationSlides(presentation, relationships);
  const fields = new Map();
  for (const [index, page] of pages.entries()) {
    const slide = zip.file(page.slidePath);
    if (!slide) throw new Error('The active report template contains a missing slide.');
    const xml = await slide.async('string');
    const title = slideTitle(xml) || `Report page ${index + 1}`;
    const text = [...xml.matchAll(/<a:t\b[^>]*>([\s\S]*?)<\/a:t>/g)]
      .map((match) => decodeXml(match[1]))
      .join('');
    for (const match of text.matchAll(/\{\{\s*(?!SCREENSHOT:)([a-z0-9_.-]+)\s*\}\}/gi)) {
      const key = match[1].toLowerCase();
      if (!fields.has(key)) {
        fields.set(key, {
          field_key: key,
          label: key.replace(/[_.-]+/g, ' '),
          page_order: index + 1,
          page_title: title,
          field_type: 'text',
        });
      }
    }
    for (const match of text.matchAll(/\{\{\s*SCREENSHOT:([^}]+)\s*\}\}/gi)) {
      const key = `screenshot:${providerKey(match[1]).toLowerCase()}`;
      if (!fields.has(key)) {
        fields.set(key, {
          field_key: key,
          label: `Screenshot: ${match[1].trim()}`,
          page_order: index + 1,
          page_title: title,
          field_type: 'image',
        });
      }
    }
  }
  return [...fields.values()];
}

function presentationSlides(presentationXml, relationshipsXml) {
  const targets = new Map();
  for (const relation of relationshipsXml.matchAll(/<Relationship\b[^>]*\/>/g)) {
    const id = relation[0].match(/\bId="([^"]+)"/)?.[1];
    const target = relation[0].match(/\bTarget="([^"]+)"/)?.[1];
    if (id && target) targets.set(id, target);
  }
  return [...presentationXml.matchAll(/<p:sldId\b[^>]*\/>/g)].map((match) => {
    const relationshipId = match[0].match(/\br:id="([^"]+)"/)?.[1];
    const target = targets.get(relationshipId);
    if (!target) throw new Error('The report template contains an invalid slide relationship.');
    const slidePath = target.startsWith('/')
      ? target.slice(1)
      : path.posix.normalize(path.posix.join('ppt', target));
    return { relationshipId, target, slidePath, node: match[0] };
  });
}

function replaceParagraphTokens(xml, fields) {
  const runs = [...xml.matchAll(/<a:t\b([^>]*)>([\s\S]*?)<\/a:t>/g)].map((match) => ({
    attrs: match[1],
    text: decodeXml(match[2]),
  }));
  if (!runs.length) return xml;
  const combined = runs.map((run) => run.text).join('');
  const replacements = [...combined.matchAll(/\{\{\s*([a-z0-9_.:-]+)\s*\}\}/gi)];
  if (!replacements.length) return xml;

  const offsets = [];
  let total = 0;
  for (const run of runs) {
    offsets.push(total);
    total += run.text.length;
  }
  for (const match of replacements.reverse()) {
    const start = match.index;
    const end = start + match[0].length;
    const first = offsets.findIndex((offset, index) =>
      start >= offset && (start < offsets[index + 1] || index === runs.length - 1));
    const last = offsets.findIndex((offset, index) =>
      end - 1 >= offset && (end - 1 < offsets[index + 1] || index === runs.length - 1));
    const firstOffset = start - offsets[first];
    const lastOffset = end - offsets[last];
    if (first === last) {
      runs[first].text = runs[first].text.slice(0, firstOffset)
        + (fields.get(match[1].toLowerCase()) ?? '')
        + runs[first].text.slice(lastOffset);
      continue;
    }
    runs[first].text = runs[first].text.slice(0, firstOffset)
      + (fields.get(match[1].toLowerCase()) ?? '');
    for (let index = first + 1; index < last; index += 1) runs[index].text = '';
    runs[last].text = runs[last].text.slice(lastOffset);
  }

  let index = 0;
  return xml.replace(/<a:t\b([^>]*)>([\s\S]*?)<\/a:t>/g, () => {
    const run = runs[index++];
    return `<a:t${run.attrs}>${escapeXml(run.text)}</a:t>`;
  });
}

function xmlTextTokenReplacement(xml, fields) {
  return xml.replace(/<a:p\b[\s\S]*?<\/a:p>/g, (paragraph) =>
    replaceParagraphTokens(paragraph, fields));
}

// Conditional card visibility.
//
// A template card (a PowerPoint shape) can opt into "hide when empty" by
// including a marker token `{{?metric_key}}` in its text (e.g. a GMB SPEND card
// that holds `{{?gmb_spend}}`). When the referenced field has no value, the
// whole shape is removed so the exported report never shows an empty card.
// When the field DOES have a value, the shape is kept and the marker token is
// stripped so it never appears in the output. Templates that use no `{{?...}}`
// markers are unaffected (this is a no-op for them).
function applyConditionalShapes(xml, fields) {
  const withShapesRemoved = xml.replace(/<p:sp\b[\s\S]*?<\/p:sp>/g, (shape) => {
    const markers = [
      ...slideText(shape).matchAll(/\{\{\s*\?\s*([a-z0-9_.:-]+)\s*\}\}/gi),
    ];
    if (!markers.length) return shape;
    const anyEmpty = markers.some((match) => {
      const value = fields.get(match[1].toLowerCase());
      return value == null || String(value).trim() === '';
    });
    return anyEmpty ? '' : shape;
  });
  // Strip any surviving `{{?key}}` markers from kept shapes so the marker text
  // itself is never rendered (the normal token replacer ignores `?` tokens).
  return withShapesRemoved.replace(/\{\{\s*\?\s*[a-z0-9_.:-]+\s*\}\}/gi, '');
}

function platformForReportLabel(label) {
  const text = decodeXml(String(label || '')).replace(/^\s*[●•]\s*/, '').trim().toLowerCase();
  if (/^gmb\s*\/\s*gbp$/.test(text)) return 'GOOGLE_BUSINESS_PROFILE';
  if (text === 'google analytics') return 'GOOGLE_ANALYTICS';
  if (text === 'google search console') return 'GOOGLE_SEARCH_CONSOLE';
  if (text === 'local seo') return 'LOCAL_SEO';
  if (text === 'google ads') return 'GOOGLE_ADS';
  if (text === 'meta ads') return 'META_ADS';
  if (text === 'linkedin ads') return 'LINKEDIN_ADS';
  if (text === 'linkedin' || text === 'linkedin (organic)') return 'LINKEDIN';
  if (text === 'instagram') return 'INSTAGRAM';
  if (text === 'facebook') return 'FACEBOOK';
  if (text === 'youtube') return 'YOUTUBE';
  if (text === 'twitter / x') return 'TWITTER_X';
  if (text === 'posters & videos' || text === 'creatives' || text === 'creative showcase') return 'CREATIVES';
  return null;
}

const REPORT_PROVIDER_ORDER = [
  'GOOGLE_ADS',
  'GOOGLE_BUSINESS_PROFILE',
  'META_ADS',
  'LINKEDIN_ADS',
  'INSTAGRAM',
  'FACEBOOK',
  'YOUTUBE',
  'LINKEDIN',
  'TWITTER_X',
  'CREATIVES',
];

function reportProviderPosition(provider) {
  const position = REPORT_PROVIDER_ORDER.indexOf(provider);
  return position === -1 ? REPORT_PROVIDER_ORDER.length : position;
}

function setPowerPointText(xml, value) {
  const text = escapeXml(String(value ?? ''));
  let replaced = false;
  if (/<a:t\b[^>]*>[\s\S]*?<\/a:t>/.test(xml)) {
    return xml.replace(/<a:t\b([^>]*)>[\s\S]*?<\/a:t>/g, (_match, attrs) => {
      if (replaced) return `<a:t${attrs}></a:t>`;
      replaced = true;
      return `<a:t${attrs}>${text}</a:t>`;
    });
  }
  if (!text) return xml;
  return xml.replace(/<a:endParaRPr\b[^>]*>|<\/a:p>/, (end) =>
    '<a:r><a:t>' + text + '</a:t></a:r>' + end);
}

function tableCells(rowXml) {
  return [...rowXml.matchAll(/<a:tc\b[\s\S]*?<\/a:tc>/g)].map((match) => match[0]);
}

function cellText(cellXml) {
  return [...String(cellXml).matchAll(/<a:t\b[^>]*>([\s\S]*?)<\/a:t>/g)]
    .map((match) => decodeXml(match[1]))
    .join(' ')
    .trim();
}

function setTableRowValues(row, values) {
  let column = 0;
  return row.replace(/<a:tc\b[\s\S]*?<\/a:tc>/g, (cell) => {
    const value = values[column++];
    return value == null ? cell : setPowerPointText(cell, value);
  });
}

function providerFieldPrefixes(provider) {
  const prefix = provider.toLowerCase();
  if (provider === 'GOOGLE_BUSINESS_PROFILE') {
    return [prefix, 'gmb', 'gbp', 'gmb_gbp'];
  }
  if (provider === 'TWITTER_X') return [prefix, 'twitter', 'x'];
  return [prefix];
}

function providerMetric(fields, provider, metricNames) {
  for (const prefix of providerFieldPrefixes(provider)) {
    for (const metric of metricNames) {
      const value = fields.get(`${prefix}_${metric}`);
      if (value != null && String(value).trim() !== '') return value;
    }
  }
  return '';
}

const ADDITIONAL_REPORT_CHANNELS = {
  GOOGLE_ANALYTICS: 'Google Analytics',
  GOOGLE_SEARCH_CONSOLE: 'Google Search Console',
  LOCAL_SEO: 'Local SEO',
};

function addMissingChannelRows(rows, activeProviders) {
  const providers = new Set(rows.map((row) => platformForReportLabel(cellText(tableCells(row)[0]))));
  return [...rows, ...Object.entries(ADDITIONAL_REPORT_CHANNELS)
    .filter(([key]) => activeProviders.has(key) && !providers.has(key))
    .map(([, label]) => setTableRowValues(rows[0], [label]))];
}

function populateChannelSummaryTable(tableXml, fields, activeProviders) {
  const rows = [...tableXml.matchAll(/<a:tr\b[\s\S]*?<\/a:tr>/g)].map((match) => match[0]);
  if (rows.length < 2 || !/channel/i.test(cellText(tableCells(rows[0])[0]))) return tableXml;
  const activeRows = addMissingChannelRows(rows.slice(1), activeProviders).filter((row) => {
    const provider = platformForReportLabel(cellText(tableCells(row)[0]));
    return provider && activeProviders.has(provider);
  }).sort((left, right) => (
    reportProviderPosition(platformForReportLabel(cellText(tableCells(left)[0])))
    - reportProviderPosition(platformForReportLabel(cellText(tableCells(right)[0])))
  )).map((row) => {
    const cells = tableCells(row);
    const provider = platformForReportLabel(cellText(cells[0]));
    const values = [
      null,
      providerMetric(fields, provider, ['impressions', 'search_impressions', 'reach', 'views']),
      providerMetric(fields, provider, ['clicks', 'website_clicks', 'link_clicks']),
      providerMetric(fields, provider, ['leads_calls', 'calls', 'leads', 'conversions']),
      providerMetric(fields, provider, ['spend', 'cost']),
      providerMetric(fields, provider, ['estimated_conversion_leads', 'est_conversion_leads', 'leads', 'conversions']),
    ];
    return setTableRowValues(row, values);
  });
  return tableXml.replace(rows.join(''), `${rows[0]}${activeRows.join('')}`);
}

function populateNextMonthPlanTable(tableXml, fields, activeProviders) {
  const rows = [...tableXml.matchAll(/<a:tr\b[\s\S]*?<\/a:tr>/g)].map((match) => match[0]);
  if (rows.length < 2 || !/channel/i.test(cellText(tableCells(rows[0])[0]))
      || !/action planned/i.test(cellText(tableCells(rows[0])[1]))) return tableXml;
  const activeRows = addMissingChannelRows(rows.slice(1), activeProviders).filter((row) => {
    const provider = platformForReportLabel(cellText(tableCells(row)[0]));
    return provider && activeProviders.has(provider);
  }).sort((left, right) => (
    reportProviderPosition(platformForReportLabel(cellText(tableCells(left)[0])))
    - reportProviderPosition(platformForReportLabel(cellText(tableCells(right)[0])))
  )).map((row) => {
    const cells = tableCells(row);
    const provider = platformForReportLabel(cellText(cells[0]));
    const prefixes = providerFieldPrefixes(provider);
    const planValue = (field) => prefixes
      .map((prefix) => fields.get(`${prefix}_${field}`))
      .find((value) => value != null && String(value).trim() !== '') || '';
    const values = [
      null,
      planValue('action_planned'),
      planValue('owner'),
      planValue('due'),
    ];
    return setTableRowValues(row, values);
  });
  return tableXml.replace(rows.join(''), `${rows[0]}${activeRows.join('')}`);
}

function fillLegacyNotes(xml, fields, labels) {
  const shapes = [...xml.matchAll(/<p:sp\b[\s\S]*?<\/p:sp>/g)].map(([shape]) => shape);
  for (const [label, key] of labels) {
    const index = shapes.findIndex((shape) => cellText(shape) === label);
    const target = index >= 0 ? shapes[index + 1] : null;
    const value = fields.get(key);
    if (target && !cellText(target) && value?.trim()) {
      xml = xml.replace(target, () => setPowerPointText(target, value));
    }
  }
  return xml;
}

function populateBestCreatives(xml, fields) {
  return xml.replace(/<a:tbl>[\s\S]*?<\/a:tbl>/g, (table) => {
    const rows = [...table.matchAll(/<a:tr\b[\s\S]*?<\/a:tr>/g)].map(([row]) => row);
    if (!/best creative/i.test(cellText(tableCells(rows[0])[0]))) return table;
    const columns = ['best_creative', 'platform', 'reach_views', 'engagement'];
    const populated = rows.slice(1).map((row, index) => {
      const values = columns.map((column) => fields.get('creatives_published_' + column + '_' + (index + 1)) || '');
      if (!values.some((value) => value.trim())) return '';
      return setTableRowValues(row, values);
    });
    return table.replace(rows.join(''), () => rows[0] + populated.join(''));
  });
}

function elementBounds(xml) {
  const origin = xml.match(/<a:off\b[^>]*\bx="(-?\d+)"[^>]*\by="(-?\d+)"/);
  const extent = xml.match(/<a:ext\b[^>]*\bcx="(\d+)"[^>]*\bcy="(\d+)"/);
  if (!origin || !extent) return null;
  return { x: Number(origin[1]), y: Number(origin[2]), w: Number(extent[1]), h: Number(extent[2]) };
}

function legacyImageSlots(xml, provider) {
  return [...xml.matchAll(/<p:sp\b[\s\S]*?<\/p:sp>/g)].flatMap(([shape]) => {
    const name = shape.match(/<p:cNvPr\b[^>]*\bname="([^"]+)"/)?.[1];
    const slot = name?.match(/^((?:Poster|Video) [1-4]) frame$/i)?.[1];
    const key = slot ? 'CREATIVE_SHOWCASE_' + providerKey(slot)
      : name === 'Screenshot placeholder' ? provider : null;
    const bounds = elementBounds(shape);
    return key && bounds ? [{ shape, key, bounds }] : [];
  });
}

function removeLegacySlotDecorations(xml, frame, bounds, key, picture) {
  return xml.replace(/<p:sp\b[\s\S]*?<\/p:sp>/g, (shape) => {
    if (shape === frame) return picture;
    const point = elementBounds(shape);
    if (!point || point.x < bounds.x || point.x >= bounds.x + bounds.w
      || point.y < bounds.y || point.y >= bounds.y + bounds.h) return shape;
    if (picture && key.startsWith('CREATIVE_SHOWCASE_') && /^(poster|video) [1-4]$/i.test(cellText(shape))) {
      return shape;
    }
    return '';
  });
}

function visitSlideElements(xml, slide, visit) {
  return xml.replace(/<p:(sp|graphicFrame)\b[\s\S]*?<\/p:\1>/g, (element, kind) => {
    const id = element.match(/<p:cNvPr\b[^>]*\bid="(\d+)"/)?.[1];
    const bounds = elementBounds(element);
    if (!id || !bounds) return element;
    const key = slide + ':' + id;
    if (kind === 'sp') {
      if (!/<p:txBody>/.test(element)) return element;
      return visit(element, key, bounds);
    }
    const widths = [...element.matchAll(/<a:gridCol\b[^>]*\bw="(\d+)"/g)].map((match) => Number(match[1]));
    let y = bounds.y;
    let rowIndex = 0;
    const firstRow = element.match(/<a:tr\b[\s\S]*?<\/a:tr>/)?.[0];
    const namedRows = firstRow && /^channel$/i.test(cellText(tableCells(firstRow)[0]));
    return element.replace(/<a:tr\b[^>]*\bh="(\d+)"[^>]*>[\s\S]*?<\/a:tr>/g, (row, height) => {
      const originalName = namedRows && rowIndex > 0 ? platformForReportLabel(cellText(tableCells(row)[0])) : null;
      const rowKey = originalName || rowIndex;
      let x = bounds.x;
      let column = 0;
      const result = row.replace(/<a:tc\b[\s\S]*?<\/a:tc>/g, (cell) => {
        const w = widths[column] || 0;
        const edited = namedRows && (rowIndex === 0 || (originalName && column === 0)) ? cell
          : visit(cell, key + ':' + rowKey + ':' + column, { x, y, w, h: Number(height) });
        x += w;
        column += 1;
        return edited;
      });
      rowIndex += 1;
      y += Number(height);
      return result;
    });
  });
}

function editSlideElements(xml, slide, edits) {
  if (!edits || typeof edits !== 'object') return xml;
  return visitSlideElements(xml, slide, (element, key) => (
    typeof edits[key] === 'string' ? setPowerPointText(element, edits[key].slice(0, 4000)) : element
  ));
}

async function describeEditableSlides(bytes) {
  const zip = await JSZip.loadAsync(bytes);
  const [presentation, relationships] = await Promise.all([
    zip.file('ppt/presentation.xml').async('string'),
    zip.file('ppt/_rels/presentation.xml.rels').async('string'),
  ]);
  const size = presentation.match(/<p:sldSz\b[^>]*\bcx="(\d+)"[^>]*\bcy="(\d+)"/);
  const width = Number(size?.[1] || 9144000);
  const height = Number(size?.[2] || 6858000);
  return Promise.all(presentationSlides(presentation, relationships).map(async ({ slidePath }) => {
    const xml = await zip.file(slidePath).async('string');
    const slide = slidePath.match(/slide(\d+)\.xml$/)?.[1];
    const elements = [];
    visitSlideElements(xml, slide, (element, key, bounds) => {
      if (bounds.w > 0 && bounds.h > 0) {
        elements.push({ key, value: cellText(element),
          x: bounds.x / width, y: bounds.y / height, w: bounds.w / width, h: bounds.h / height });
      }
      return element;
    });
    for (const [picture] of xml.matchAll(/<p:pic\b[\s\S]*?<\/p:pic>/g)) {
      const target = picture.match(/\bname="Report screenshot ([A-Z0-9_]+)"/)?.[1];
      const bounds = elementBounds(picture);
      if (target && bounds) {
        elements.push({ target, x: bounds.x / width, y: bounds.y / height,
          w: bounds.w / width, h: bounds.h / height });
      }
    }
    return { elements, title: slideTitle(xml) };
  }));
}
function applyReportTableData(xml, fields, activeProviders) {
  const title = slideTitle(xml).toLowerCase();
  if (/creatives published/.test(title)) return populateBestCreatives(xml, fields);
  if (!/channel summary|next month plan/.test(title)) return xml;
  return xml.replace(/<a:tbl>[\s\S]*?<\/a:tbl>/g, (table) => (
    /channel summary/.test(title)
      ? populateChannelSummaryTable(table, fields, activeProviders)
      : populateNextMonthPlanTable(table, fields, activeProviders)
  ));
}

// The supplied cover design uses a separate background shape, text shape, and
// sometimes an image for each channel chip. Remove all parts of a chip as one
// unit so an inactive channel cannot leave behind an empty pill or icon.
function applyCoverPlatformFilter(xml, activeProviders) {
  if (!/client monthly report/.test(slideTitle(xml).toLowerCase())
    || !/channels covered/i.test(slideText(xml))) return xml;
  const slots = [
    ['GOOGLE_BUSINESS_PROFILE', 457200, 5376672],
    ['GOOGLE_ADS', 1865376, 5376672],
    ['META_ADS', 3273552, 5376672],
    ['LINKEDIN_ADS', 4681728, 5376672],
    ['INSTAGRAM', 6089904, 5376672],
    ['FACEBOOK', 457200, 5907024],
    ['YOUTUBE', 1865376, 5907024],
    ['LINKEDIN', 3273552, 5907024],
    ['TWITTER_X', 4681728, 5907024],
    ['CREATIVES', 6089904, 5907024],
  ];
  const inactiveSlots = slots.filter(([provider]) => !activeProviders.has(provider));
  const activeSlots = slots.filter(([provider]) => activeProviders.has(provider))
    .sort(([left], [right]) => reportProviderPosition(left) - reportProviderPosition(right));
  const compactTargets = new Map(activeSlots.map((slot, index) => [slot[0], slots[index]]));
  const slotForElement = (element) => {
    const position = element.match(/<a:off\b[^>]*\bx="(\d+)"[^>]*\by="(\d+)"/);
    if (!position) return null;
    const x = Number(position[1]);
    const y = Number(position[2]);
    return slots.find(([, slotX, slotY]) => x >= slotX - 50000 && x < slotX + 1000000
      && y >= slotY - 40000 && y < slotY + 490000) || null;
  };
  const transformElement = (element) => {
    const slot = slotForElement(element);
    if (!slot) return element;
    if (inactiveSlots.some(([provider]) => provider === slot[0])) return '';
    const target = compactTargets.get(slot[0]);
    if (!target || (target[1] === slot[1] && target[2] === slot[2])) return element;
    const deltaX = target[1] - slot[1];
    const deltaY = target[2] - slot[2];
    return element.replace(/<a:off x="(\d+)" y="(\d+)"/, (_match, x, y) =>
      `<a:off x="${Number(x) + deltaX}" y="${Number(y) + deltaY}"`);
  };
  const filtered = xml
    .replace(/<p:sp\b[\s\S]*?<\/p:sp>/g, transformElement)
    .replace(/<p:pic\b[\s\S]*?<\/p:pic>/g, transformElement);
  const additional = Object.entries(ADDITIONAL_REPORT_CHANNELS)
    .filter(([key]) => activeProviders.has(key));
  if (!additional.length) return filtered;
  let id = Math.max(0, ...[...filtered.matchAll(/<p:cNvPr\b[^>]*\bid="(\d+)"/g)].map((match) => Number(match[1])));
  const labels = additional.map(([, label], index) => {
    const slot = slots[activeSlots.length + index];
    const x = slot?.[1] || 457200 + (index * 2500000);
    const y = slot?.[2] || 6320000;
    return '<p:sp><p:nvSpPr><p:cNvPr id="' + (++id) + '" name="Channel label"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr>'
      + '<p:spPr><a:xfrm><a:off x="' + x + '" y="' + y + '"/><a:ext cx="1360000" cy="480000"/></a:xfrm></p:spPr>'
      + '<p:txBody><a:bodyPr anchor="ctr"/><a:lstStyle/><a:p><a:r><a:rPr sz="900" b="1"/><a:t>' + label
      + '</a:t></a:r></a:p></p:txBody></p:sp>';
  });
  return filtered.replace('</p:spTree>', () => labels.join('') + '</p:spTree>');
}

// Older GoDigital templates use a visible `[Enter]` prompt on the cover rather
// than a `{{field_name}}` token. Keep that design compatible with the current
// data model so a correctly completed report never exports a blank cover.
function applyLegacyCoverFields(xml, fields) {
  if (!/client monthly report/.test(slideTitle(xml).toLowerCase())) return xml;
  const mappings = [
    [/client\s*\/\s*brand/i, 'client_brand'],
    [/report month/i, 'report_month'],
    [/date range/i, 'date_range'],
    [/prepared by/i, 'prepared_by'],
  ];
  return xml.replace(/<p:sp\b[\s\S]*?<\/p:sp>/g, (shape) => {
    const mapping = mappings.find(([pattern]) => pattern.test(slideText(shape)));
    if (!mapping || !/\[enter\]/i.test(shape)) return shape;
    const value = fields.get(mapping[1]);
    if (value == null || String(value).trim() === '') return shape;
    return shape.replace(/\[enter\]/gi, escapeXml(String(value)));
  });
}

function monthYearLabel(month, year) {
  const number = Number(month);
  const names = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  if (number >= 1 && number <= 12) return `${names[number]}${year ? ` ${year}` : ''}`;
  return String(month || year || '').trim();
}

function applyLegacyReportFields(xml, fields) {
  const replacements = [
    [/\[client\]/gi, fields.get('client_name')],
    [/\[month\s+yyyy\]/gi, fields.get('report_month')],
    [/\[date\s+range\]/gi, fields.get('date_range')],
    [/\[account\]/gi, fields.get('account')],
    [/\[ad\s+account\]/gi, fields.get('ad_account')],
    [/\[profile\s+name\]/gi, fields.get('profile_name')],
    [/\[location\]/gi, fields.get('location')],
    [/\[handle\s*\/\s*page\s+url\]/gi, fields.get('handle') || fields.get('page_url')],
    [/\[company\s+page\s+url\]/gi, fields.get('company_page_url')],
    [/\[@handle\s*\/\s*profile\s+url\]/gi, fields.get('handle') || fields.get('profile_url')],
  ];
  return replacements.reduce((result, [pattern, value]) => (
    value == null || String(value).trim() === '' ? result : result.replace(pattern, escapeXml(String(value)))
  ), xml);
}

const CARD_METRIC_KEYS = {
  CREATIVES_PUBLISHED: {
    'posters / static posts': ['posters_static_posts'], carousels: ['carousels'],
    'reels / short videos': ['reels_short_videos'], 'long videos': ['long_videos'],
    'ad creatives': ['ad_creatives'], stories: ['stories'],
  },
  GOOGLE_BUSINESS_PROFILE: {
    'search impressions': ['search_impressions', 'total_impressions'],
    'maps impressions': ['maps_impressions'], calls: ['calls'],
    'website clicks': ['website_clicks'], 'est conversion leads': ['est_conversion_leads', 'estimated_leads'],
    bookings: ['bookings'], 'posts published': ['posts_published'], photos: ['photos_added'],
    'new reviews': ['new_reviews'], 'review replies': ['review_replies'],
  },
  GOOGLE_ADS: {
    'active campaigns': ['active_campaigns'], impressions: ['impressions'], clicks: ['clicks'],
    'ctr %': ['ctr'], 'spend': ['spend', 'cost'], 'conversions / leads': ['conversions_leads', 'conversions', 'leads'],
    'cost per lead': ['cost_per_lead', 'cpl'], calls: ['calls'], 'keywords optimized': ['keywords_optimized'],
  },
  META_ADS: {
    'active campaigns': ['active_campaigns'], 'reach / impression': ['reach_impressions', 'reach', 'impressions'],
    frequency: ['frequency'], 'est conversion leads': ['est_conversion_leads', 'conversions', 'leads'],
    'ctr %': ['ctr'], 'cpm': ['cpm'], 'spend': ['spend', 'cost'], leads: ['leads'],
    'cost per lead': ['cost_per_lead', 'cpl'], 'whatsapp / messages': ['whatsapp_messages'],
    'video views': ['video_views', 'views'],
  },
  LINKEDIN_ADS: {
    'active campaigns': ['active_campaigns'], leads: ['leads'], impressions: ['impressions'],
    'cost per lead': ['cost_per_lead', 'cpl'], clicks: ['clicks'],
    'est conversion leads': ['est_conversion_leads', 'conversions', 'leads'], 'ctr %': ['ctr'],
    engagements: ['engagements'], 'avg cpc': ['avg_cpc', 'average_cpc', 'cpc'],
    'video views': ['video_views', 'views'], cpm: ['cpm'], spend: ['spend', 'cost'],
  },
  INSTAGRAM: {
    followers: ['followers'], 'new followers': ['new_followers'],
    'impressions / reach / views': ['impressions_reach_views', 'views', 'impressions', 'reach'],
    engagement: ['engagement', 'interactions', 'accounts_engaged'], 'posts published': ['posts_published'],
    'reels published': ['reels_published'], stories: ['stories'],
  },
  FACEBOOK: {
    'page followers': ['page_followers', 'followers'], 'new followers': ['new_followers'],
    'impressions / reach/ views': ['impressions_reach_views', 'views', 'impressions', 'reach'],
    engagement: ['engagement', 'interactions'], 'posts published': ['posts_published'],
    'videos / reels': ['videos_reels'], stories: ['stories'],
  },
  YOUTUBE: {
    subscribers: ['subscribers'], 'new subscribers': ['new_subscribers'], impressions: ['impressions'],
    'impression ctr %': ['impression_ctr', 'ctr'], 'watch time (hrs)': ['watch_time_hours', 'watch_time'],
    'avg view duration': ['avg_view_duration'], 'videos published': ['videos_published'],
    'shorts published': ['shorts_published'], 'likes/ share': ['likes_shares', 'likes'],
    'top video views': ['top_video_views', 'views'],
  },
  LINKEDIN: {
    followers: ['followers'], 'new followers': ['new_followers'], impressions: ['impressions'],
    'engagement rate %': ['engagement_rate'], reposts: ['reposts'], clicks: ['clicks'],
    'posts published': ['posts_published'],
  },
  TWITTER_X: {
    followers: ['followers'], 'posts published': ['posts_published'], 'new followers': ['new_followers'],
    impressions: ['impressions'], 'engagement rate %': ['engagement_rate'], engagements: ['engagements'],
    'profile visits': ['profile_visits'], 'link clicks': ['link_clicks'],
  },
};

function normalCardLabel(label) {
  return String(label || '').toLowerCase()
    .replace(/[₹]/g, '').replace(/\s+/g, ' ').trim();
}

function cardData(fields, provider, label) {
  const candidates = CARD_METRIC_KEYS[provider]?.[normalCardLabel(label)];
  if (!candidates) return null;
  const prefix = provider.toLowerCase();
  for (const key of candidates) {
    const value = fields.get(`${prefix}_${key}`);
    if (value == null || String(value).trim() === '') continue;
    return {
      value: String(value),
      change: fields.get(`${prefix}_${key}_vs_last_month`)
        || fields.get(`${prefix}_${key}_percentage_change`) || '',
    };
  }
  return null;
}

function applyMetricCards(xml, fields) {
  const provider = /creatives published/i.test(slideTitle(xml)) ? 'CREATIVES_PUBLISHED' : slideProvider(xml);
  if (!provider || !CARD_METRIC_KEYS[provider]) return xml;
  const cards = [...xml.matchAll(/<p:sp\b[\s\S]*?<\/p:sp>/g)].map((match) => match[0])
    .map((shape) => {
      const name = shape.match(/<p:cNvPr\b[^>]*\bname="([^"]*)"/)?.[1] || '';
      const point = shape.match(/<a:off x="(\d+)" y="(\d+)"/);
      const size = shape.match(/<a:ext cx="(\d+)" cy="(\d+)"/);
      const label = name.match(/^Card\s+(.+)$/i)?.[1];
      return label && point ? {
        label,
        x: Number(point[1]),
        y: Number(point[2]),
        width: Number(size?.[1] || 3600000),
        height: Number(size?.[2] || 1600000),
        data: cardData(fields, provider, label),
      } : null;
    })
    .filter(Boolean);
  if (!cards.length) return xml;
  const cardAt = (element) => {
    const point = element.match(/<a:off x="(\d+)" y="(\d+)"/);
    if (!point) return null;
    const x = Number(point[1]);
    const y = Number(point[2]);
    return cards.find((card) => x >= card.x - 120000 && x < card.x + card.width + 120000
      && y >= card.y - 120000 && y < card.y + card.height + 120000) || null;
  };
  // Cards in the source template are a fixed grid. Once cards without a
  // value are removed, move every remaining card into the next grid position
  // in reading order so reports never contain an empty hole between cards.
  const readingOrder = [...cards].sort((left, right) => left.y - right.y || left.x - right.x);
  const compactTargets = new Map();
  readingOrder.filter((card) => card.data).forEach((card, index) => {
    compactTargets.set(card, readingOrder[index]);
  });
  const moveIntoCompactPosition = (shape, card) => {
    const target = compactTargets.get(card);
    if (!target || (target.x === card.x && target.y === card.y)) return shape;
    const deltaX = target.x - card.x;
    const deltaY = target.y - card.y;
    return shape.replace(/<a:off x="(\d+)" y="(\d+)"/, (_match, x, y) =>
      `<a:off x="${Number(x) + deltaX}" y="${Number(y) + deltaY}"`);
  };
  return xml.replace(/<p:sp\b[\s\S]*?<\/p:sp>/g, (shape) => {
    const card = cardAt(shape);
    if (!card) return shape;
    if (!card.data) return '';
    const text = slideText(shape).trim();
    let result = shape;
    if (text === '—') result = setPowerPointText(result, card.data.value);
    if (/vs last month:/i.test(text)) {
      result = result.replace(/vs last month:\s*_+\s*%/gi,
        `vs last month: ${escapeXml(card.data.change || '—')}`);
    }
    return moveIntoCompactPosition(result, card);
  });
}

function screenshotToken(shapeXml) {
  const match = slideText(shapeXml).match(/\{\{\s*screenshot\s*:\s*([^}]+)\s*\}\}/i);
  return match ? providerKey(match[1]) : null;
}

function screenshotBytes(image) {
  if (typeof image?.bytesBase64 !== 'string' || image.bytesBase64.length < 20) return null;
  const bytes = Buffer.from(image.bytesBase64, 'base64');
  if (!bytes.length) return null;
  return bytes;
}

function imageDimensions(bytes, extension) {
  if (extension === 'png' && bytes.length >= 24) {
    const dimensions = {
      width: bytes.readUInt32BE(16),
      height: bytes.readUInt32BE(20),
    };
    if (dimensions.width > 0 && dimensions.height > 0) return dimensions;
  }
  if (extension === 'jpg') {
    let offset = 2;
    while (offset + 9 < bytes.length) {
      if (bytes[offset] !== 0xff) {
        offset += 1;
        continue;
      }
      while (bytes[offset] === 0xff) offset += 1;
      const marker = bytes[offset];
      if (marker === 0xd8 || marker === 0xd9 || marker === 0x01
          || (marker >= 0xd0 && marker <= 0xd7)) {
        offset += 1;
        continue;
      }
      const segmentLength = bytes.readUInt16BE(offset + 1);
      if ([0xc0, 0xc1, 0xc2, 0xc3, 0xc5, 0xc6, 0xc7, 0xc9, 0xca, 0xcb, 0xcd, 0xce, 0xcf]
        .includes(marker)) {
        const dimensions = {
          height: bytes.readUInt16BE(offset + 4),
          width: bytes.readUInt16BE(offset + 6),
        };
        if (dimensions.width > 0 && dimensions.height > 0) return dimensions;
        break;
      }
      if (segmentLength < 2) break;
      offset += segmentLength + 1;
    }
  }
  throw new Error('A screenshot has invalid or unsupported image dimensions.');
}

async function normalizeScreenshot(image) {
  const bytes = screenshotBytes(image);
  if (!bytes) return null;
  let mimeType = String(image.mimeType || 'image/jpeg').toLowerCase();
  if (bytes.subarray(0, 8).toString('hex') === '89504e470d0a1a0a') mimeType = 'image/png';
  if (bytes.subarray(0, 3).toString('hex') === 'ffd8ff') mimeType = 'image/jpeg';
  if (bytes.toString('ascii', 0, 4) === 'RIFF' && bytes.toString('ascii', 8, 12) === 'WEBP') {
    mimeType = 'image/webp';
  }
  if (mimeType === 'image/png' || mimeType === 'image/jpeg') {
    const extension = mimeType === 'image/png' ? 'png' : 'jpg';
    const dimensions = imageDimensions(bytes, extension);
    return { bytes, extension, contentType: mimeType, ...dimensions };
  }
  if (mimeType !== 'image/webp') {
    throw new Error(`Unsupported screenshot type for the PowerPoint template: ${mimeType}`);
  }

  const puppeteer = require('puppeteer');
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage'],
  });
  try {
    const page = await browser.newPage();
    await page.setContent(
      `<img src="data:image/webp;base64,${bytes.toString('base64')}" style="max-width:100%;max-height:100%">`,
    );
    const imageElement = await page.$('img');
    await imageElement.evaluate((element) => element.decode());
    const png = await imageElement.screenshot({ type: 'png' });
    await page.close();
    const bytes = Buffer.from(png);
    const dimensions = imageDimensions(bytes, 'png');
    return { bytes, extension: 'png', contentType: 'image/png', ...dimensions };
  } finally {
    await browser.close();
  }
}

function imageRelationshipId(xml) {
  const ids = [...xml.matchAll(/\bId="rId(\d+)"/g)].map((match) => Number(match[1]));
  return `rId${Math.max(0, ...ids) + 1}`;
}

function pictureShape(shapeXml, relationshipId, imageName, image) {
  const transform = shapeXml.match(/<a:xfrm\b[^>]*>([\s\S]*?)<\/a:xfrm>/)?.[1];
  const off = transform?.match(/<a:off\b[^>]*\bx="(\d+)"[^>]*\by="(\d+)"[^>]*\/>/);
  const ext = transform?.match(/<a:ext\b[^>]*\bcx="(\d+)"[^>]*\bcy="(\d+)"[^>]*\/>/);
  const shapeId = shapeXml.match(/<p:cNvPr\b[^>]*\bid="(\d+)"/)?.[1];
  if (!off || !ext || !shapeId) {
    throw new Error('A screenshot placeholder must be a positioned PowerPoint text box.');
  }
  const boxX = Number(off[1]);
  const boxY = Number(off[2]);
  const boxWidth = Number(ext[1]);
  const boxHeight = Number(ext[2]);
  const scale = Math.min(
    boxWidth / image.width,
    boxHeight / image.height,
  );
  const width = Math.round(image.width * scale);
  const height = Math.round(image.height * scale);
  const x = Math.round(boxX + (boxWidth - width) / 2);
  const y = Math.round(boxY + (boxHeight - height) / 2);
  return `<p:pic><p:nvPicPr><p:cNvPr id="${shapeId}" name="${imageName}"/><p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr><p:nvPr/></p:nvPicPr><p:blipFill><a:blip r:embed="${relationshipId}"/><a:stretch><a:fillRect/></a:stretch></p:blipFill><p:spPr><a:xfrm><a:off x="${x}" y="${y}"/><a:ext cx="${width}" cy="${height}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr></p:pic>`;
}

async function addSlideImage(zip, slideNumber, image, provider, screenshot, imageNumber) {
  const relsPath = `ppt/slides/_rels/slide${slideNumber}.xml.rels`;
  let rels = zip.file(relsPath)
    ? await zip.file(relsPath).async('string')
    : `<Relationships xmlns="${RELATIONSHIPS_NS}"></Relationships>`;
  const relationshipId = imageRelationshipId(rels);
  const imagePath = `ppt/media/report_${slideNumber}_${imageNumber}.${image.extension}`;
  zip.file(imagePath, image.bytes);
  rels = rels.replace(
    '</Relationships>',
    `<Relationship Id="${relationshipId}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/report_${slideNumber}_${imageNumber}.${image.extension}"/></Relationships>`,
  );
  zip.file(relsPath, rels);
  return pictureShape(
    screenshot,
    relationshipId,
    `Report screenshot ${providerKey(provider) || imageNumber}`,
    image,
  );
}

function ensureImageContentType(contentTypes, extension, contentType) {
  const exists = new RegExp(`<Default\\b[^>]*Extension="${extension}"`, 'i').test(contentTypes);
  if (exists) return contentTypes;
  return contentTypes.replace(
    '</Types>',
    `<Default Extension="${extension}" ContentType="${contentType}"/></Types>`,
  );
}

async function fillPowerPointTemplate(templateBytes, payload = {}) {
  const zip = await loadPowerPointTemplate(templateBytes);
  const presentationPath = 'ppt/presentation.xml';
  const relationsPath = 'ppt/_rels/presentation.xml.rels';
  const contentTypesPath = '[Content_Types].xml';
  const [presentationXml, presentationRels, initialContentTypes] = await Promise.all([
    zip.file(presentationPath).async('string'),
    zip.file(relationsPath).async('string'),
    zip.file(contentTypesPath).async('string'),
  ]);
  const fields = reportFields(payload);
  const extraFields = payload.templateFields || payload.template_fields || {};
  if (extraFields && typeof extraFields === 'object' && !Array.isArray(extraFields)) {
    for (const [key, value] of Object.entries(extraFields)) {
      addField(fields, key, value, { overwrite: true });
    }
  }
  const imagesByProvider = new Map();
  for (const item of Array.isArray(payload.screenshots) ? payload.screenshots : []) {
    const key = providerKey(item?.provider);
    if (!key) throw new Error('Each uploaded screenshot needs a provider mapping.');
    if (!screenshotBytes(item)) {
      throw new Error(`The uploaded ${key} screenshot has invalid image data.`);
    }
    imagesByProvider.set(key, [...(imagesByProvider.get(key) || []), item]);
  }
  const placedImages = new Set();
  const creativeSlots = ['POSTER_1', 'POSTER_2', 'POSTER_3', 'POSTER_4',
    'VIDEO_1', 'VIDEO_2', 'VIDEO_3', 'VIDEO_4'];
  const creativeImages = imagesByProvider.get('CREATIVE_SHOWCASE') || [];
  let creativeSlotIndex = 0;
  const slides = presentationSlides(presentationXml, presentationRels);
  let contentTypes = initialContentTypes;
  let imageNumber = 0;
  async function placeImage(source, slideNumber, provider, box) {
    const image = await normalizeScreenshot(source);
    if (!image?.bytes) throw new Error('An uploaded report image could not be decoded.');
    const picture = await addSlideImage(zip, slideNumber, image, provider, box, ++imageNumber);
    contentTypes = ensureImageContentType(contentTypes, image.extension, image.contentType);
    placedImages.add(source);
    return picture;
  }
  const uploadedProviders = new Set([...imagesByProvider.keys()].map(canonicalProviderKey));
  const providersWithContent = new Set([
    ...(Array.isArray(payload.selectedProviders) ? payload.selectedProviders : [])
      .map((provider) => canonicalProviderKey(typeof provider === 'string' ? provider : provider?.provider))
      .filter(Boolean),
    ...(Array.isArray(payload.providers) ? payload.providers : [])
      .map((provider) => canonicalProviderKey(typeof provider === 'string' ? provider : provider?.provider))
      .filter(Boolean),
    ...(Array.isArray(payload.snapshots) ? payload.snapshots : [])
      .map((snapshot) => canonicalProviderKey(snapshot?.provider))
      .filter(Boolean),
  ]);
  // Persisted reports keep selectedProviders even when their binary screenshot
  // data is no longer part of a later preview request. Use that selection for
  // table rows first; otherwise fall back to the screenshot/provider content.
  const selectedProviders = new Set(
    (Array.isArray(payload.selectedProviders) ? payload.selectedProviders : [])
      .map((provider) => canonicalProviderKey(typeof provider === 'string' ? provider : provider?.provider))
      .filter(Boolean),
  );
  const activeProviders = Array.isArray(payload.selectedProviders)
    ? selectedProviders
    : (uploadedProviders.size
      ? new Set([...uploadedProviders].map(canonicalProviderKey))
      : providersWithContent);
  for (const provider of uploadedProviders) activeProviders.add(provider);
  if (!Array.isArray(payload.selectedProviders)) {
    for (const provider of REPORT_PROVIDER_ORDER) {
      if (providerFieldPrefixes(provider).some((prefix) => [...fields].some(([key, value]) =>
        key.startsWith(prefix + '_') && value.trim()))) activeProviders.add(provider);
    }
  }
  if (activeProviders.has('CREATIVE_SHOWCASE') || activeProviders.has('CREATIVES_PUBLISHED')) {
    activeProviders.add('CREATIVES');
  }
  const providerAliases = {
    GOOGLE_BUSINESS_PROFILE: ['GOOGLE_BUSINESS_PROFILE', 'GMB', 'GBP'],
    TWITTER_X: ['TWITTER_X', 'TWITTER', 'X'],
  };
  const removedSlideNodes = [];
  for (const slide of slides) {
    const slideNumber = slide.slidePath.match(/slide(\d+)\.xml$/)?.[1];
    if (!slideNumber) throw new Error('The report template contains an invalid slide file name.');
    let xml = await zip.file(slide.slidePath).async('string');
    const slideScreenshotProviders = [
      ...slideText(xml).matchAll(/\{\{\s*screenshot\s*:\s*([^}]+?)\s*\}\}/gi),
    ].map((match) => providerKey(match[1])).filter(Boolean);
    const provider = slideProvider(xml);
    const matchingProviderKeys = providerAliases[provider] || [provider];
    const hasActiveProvider = provider != null
      && matchingProviderKeys.some((key) => activeProviders.has(key));
    const hasFilledTemplateField = slideHasFilledTemplateField(xml, fields);
    const title = slideTitle(xml);
    const legacySlots = legacyImageSlots(xml, provider);
    const hasLegacyImages = legacySlots.some(({ key }) => key.startsWith('CREATIVE_SHOWCASE_')
      ? creativeImages.some((image) => key.endsWith('_' + providerKey(image.slot)))
      : imagesByProvider.has(key));
    const hasEmptyMetricCards = /name="Card [^"]+"/.test(xml) && provider && CARD_METRIC_KEYS[provider]
      && !legacySlots.length && !/<a:tbl>/.test(xml)
      && !Object.keys(CARD_METRIC_KEYS[provider]).some((label) => cardData(fields, provider, label));
    const creativeData = [...fields].some(([key, value]) => key.startsWith('creatives_published_') && value.trim());
    const sharedSlide = isSharedReportSlide(xml);
    if ((!title && !slideScreenshotProviders.length && !hasFilledTemplateField)
        || (provider != null && !hasActiveProvider)
        || (hasEmptyMetricCards && !hasFilledTemplateField)
        || (/creatives published/i.test(title) && !creativeData && !hasFilledTemplateField)
        || (/creative showcase/i.test(title) && !creativeImages.length && !hasFilledTemplateField
          && !slideScreenshotProviders.some((key) => imagesByProvider.has(key)))
        || (legacySlots.length && provider && !hasLegacyImages && !hasFilledTemplateField
          && !slideScreenshotProviders.length)
        || (provider == null && !hasFilledTemplateField && slideScreenshotProviders.length
          && !slideScreenshotProviders.some((key) => uploadedProviders.has(key)
            || (creativeImages.length && creativeSlots.includes(key.replace(/^CREATIVE_SHOWCASE_/, '')))))
        || (provider == null && !sharedSlide && !hasFilledTemplateField
          && slideScreenshotProviders.isEmpty)) {
      removedSlideNodes.push(slide.node);
      continue;
    }
    for (const { shape, key, bounds } of legacySlots) {
      const slot = key.replace(/^CREATIVE_SHOWCASE_/, '');
      const source = key === slot
        ? imagesByProvider.get(key)?.find((image) => !placedImages.has(image))
        : creativeImages.find((image) => providerKey(image.slot) === slot && !placedImages.has(image));
      const picture = source ? await placeImage(source, slideNumber, key, shape) : '';
      xml = removeLegacySlotDecorations(xml, shape, bounds, key, picture);
    }
    const shapePattern = /<p:sp\b[\s\S]*?<\/p:sp>/g;
    const shapes = [...xml.matchAll(shapePattern)];
    for (const shapeMatch of shapes) {
      const provider = screenshotToken(shapeMatch[0]);
      if (!provider) continue;
      const namedSlot = provider.replace(/^CREATIVE_SHOWCASE_/, '');
      const slot = provider === 'CREATIVE_SHOWCASE'
        ? creativeSlots[creativeSlotIndex++]
        : creativeSlots.includes(namedSlot) ? namedSlot : null;
      const sourceImage = slot
        ? creativeImages.find((image) => !placedImages.has(image) && providerKey(image.slot) === slot)
          || creativeImages.find((image) => !placedImages.has(image) && !image.slot)
          || imagesByProvider.get(provider)?.find((image) => !placedImages.has(image) && !image.slot)
        : imagesByProvider.get(provider)?.find((image) => !placedImages.has(image));
      if (!sourceImage) {
        xml = xml.replace(shapeMatch[0], '');
        continue;
      }
      const imageLabel = sourceImage.slot ? 'CREATIVE_SHOWCASE_' + providerKey(sourceImage.slot) : provider;
      const picture = await placeImage(sourceImage, slideNumber, imageLabel, shapeMatch[0]);
      xml = xml.replace(shapeMatch[0], picture);
    }
    xml = applyCoverPlatformFilter(xml, activeProviders);
    xml = applyLegacyCoverFields(xml, fields);
    xml = applyLegacyReportFields(xml, fields);
    xml = applyReportTableData(xml, fields, activeProviders);
    if (/next month plan/i.test(title)) {
      xml = fillLegacyNotes(xml, fields, [
        ['Approvals & inputs needed', 'approvals_inputs_needed'], ['Remarks', 'remarks'],
      ]);
    }
    xml = applyMetricCards(xml, fields);
    xml = applyConditionalShapes(xml, fields);
    xml = xmlTextTokenReplacement(xml, fields);
    zip.file(slide.slidePath, editSlideElements(xml, slideNumber, payload.powerPointEdits));
  }
  // Drop the removed provider slides from the presentation's slide list. Only
  // the <p:sldId> reference is removed; the orphaned slide part is harmless and
  // simply no longer rendered, which keeps the file valid.
  let finalPresentationXml = presentationXml;
  for (const node of removedSlideNodes) {
    finalPresentationXml = finalPresentationXml.replace(node, '');
  }
  let finalPresentationRels = presentationRels;
  const fallbackImages = [
    ...(imagesByProvider.get('INSTAGRAM') || []).map((image) => ({ image, title: 'Instagram Dashboard' })),
    ...creativeImages.map((image) => ({ image, title: 'Creative Showcase' })),
  ].filter(({ image }) => !placedImages.has(image));
  if (fallbackImages.length) {
    const size = presentationXml.match(/<p:sldSz\b[^>]*\bcx="(\d+)"[^>]*\bcy="(\d+)"/);
    const width = Number(size?.[1] || 9144000);
    const height = Number(size?.[2] || 6858000);
    const margin = Math.round(width * 0.04);
    const headingHeight = Math.round(height * 0.13);
    const sourceRels = slides.length && zip.file(slides[0].slidePath.replace(/([^/]+)$/, '_rels/$1.rels'));
    const layout = sourceRels && (await sourceRels.async('string'))
      .match(/<Relationship\b[^>]*Type="[^"]*\/slideLayout"[^>]*\/>/)?.[0];
    let number = Math.max(0, ...Object.keys(zip.files)
      .map((name) => Number(name.match(/^ppt\/slides\/slide(\d+)\.xml$/)?.[1] || 0)));
    let id = Math.max(255, ...slides.map(({ node }) => Number(node.match(/\sid="(\d+)"/)?.[1] || 0)));
    const relationshipType = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
    for (const { image, title } of fallbackImages) {
      const name = 'slide' + (++number) + '.xml';
      const relation = imageRelationshipId(finalPresentationRels);
      finalPresentationRels = finalPresentationRels.replace('</Relationships>',
        '<Relationship Id="' + relation + '" Type="' + relationshipType
          + '/slide" Target="slides/' + name + '"/></Relationships>');
      finalPresentationXml = finalPresentationXml.replace('</p:sldIdLst>',
        '<p:sldId id="' + (++id) + '" r:id="' + relation + '"/></p:sldIdLst>');
      contentTypes = contentTypes.replace('</Types>',
        '<Override PartName="/ppt/slides/' + name
          + '" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/></Types>');
      zip.file('ppt/slides/_rels/' + name + '.rels',
        '<Relationships xmlns="' + RELATIONSHIPS_NS + '">' + (layout || '') + '</Relationships>');
      const label = escapeXml(image.slot ? title + ' - ' + image.slot : title);
      const heading = '<p:sp><p:nvSpPr><p:cNvPr id="2" name="Title"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr>'
        + '<p:spPr><a:xfrm><a:off x="' + margin + '" y="0"/><a:ext cx="' + (width - 2 * margin)
        + '" cy="' + headingHeight + '"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>'
        + '<p:txBody><a:bodyPr anchor="ctr"/><a:lstStyle/><a:p><a:r><a:rPr sz="2800" b="1"/>'
        + '<a:t>' + label + '</a:t></a:r></a:p></p:txBody></p:sp>';
      const box = '<p:cNvPr id="3"/><a:xfrm><a:off x="' + margin + '" y="' + headingHeight
        + '"/><a:ext cx="' + (width - 2 * margin) + '" cy="' + (height - headingHeight - Math.round(height * 0.04))
        + '"/></a:xfrm>';
      const imageLabel = image.slot ? 'CREATIVE_SHOWCASE_' + providerKey(image.slot) : image.provider;
      const picture = await placeImage(image, number, imageLabel, box);
      zip.file('ppt/slides/' + name,
        '<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"'
        + ' xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="' + relationshipType
        + '" showMasterSp="0"><p:cSld><p:bg><p:bgPr><a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill>'
        + '<a:effectLst/></p:bgPr></p:bg><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/>'
        + '<p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>' + heading + picture
        + '</p:spTree></p:cSld></p:sld>');
    }
  }
  // Footer prompts live on the shared slide layout rather than individual
  // slides in the supplied template. Apply the same client/month replacement
  // there so every exported page shows the actual report identity.
  for (const path of Object.keys(zip.files).filter((name) => /^ppt\/slideLayouts\/[^/]+\.xml$/i.test(name))) {
    const layout = await zip.file(path).async('string');
    zip.file(path, applyLegacyReportFields(layout, fields));
  }
  zip.file(presentationPath, finalPresentationXml);
  zip.file(relationsPath, finalPresentationRels);
  zip.file(contentTypesPath, contentTypes);
  return zip.generateAsync({ type: 'nodebuffer', compression: 'DEFLATE' });
}

function toolPath(environmentKey, fallback) {
  return process.env[environmentKey] || fallback;
}

function officeConverterPath() {
  const configured = String(process.env.REPORT_OFFICE_CONVERTER_PATH || '').trim();
  if (configured) return configured;
  if (process.platform !== 'win32') return 'soffice';
  const candidates = [
    'C:\\Program Files\\LibreOffice\\program\\soffice.com',
    'C:\\Program Files (x86)\\LibreOffice\\program\\soffice.com',
    'C:\\Program Files\\LibreOffice\\program\\soffice.exe',
    'C:\\Program Files (x86)\\LibreOffice\\program\\soffice.exe',
  ];
  return candidates.find((candidate) => fsSync.existsSync(candidate)) || 'soffice.exe';
}

async function runTool(command, args, label) {
  try {
    return await execFileAsync(command, args, {
      timeout: 180000,
      maxBuffer: 10 * 1024 * 1024,
      windowsHide: true,
    });
  } catch (error) {
    if (error.code === 'ENOENT') {
      throw new Error(
        `${label} is required for reports using the shared PowerPoint template. Configure ${label === 'LibreOffice' ? 'REPORT_OFFICE_CONVERTER_PATH' : 'REPORT_PDF_RENDERER_PATH'}.`,
      );
    }
    const detail = error.stderr?.toString().trim() || error.message;
    throw new Error(`${label} could not convert the report: ${detail}`);
  }
}

async function withPowerPointPdf(powerPointBytes, callback) {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'godigital-report-'));
  try {
    const pptxPath = path.join(directory, 'report.pptx');
    await fs.writeFile(pptxPath, powerPointBytes);
    const officePath = officeConverterPath();
    await runTool(
      officePath,
      [
        '--headless',
        `-env:UserInstallation=${pathToFileURL(path.join(directory, 'office-profile')).href}`,
        '--convert-to',
        'pdf',
        '--outdir',
        directory,
        pptxPath,
      ],
      'LibreOffice',
    );
    const pdfPath = path.join(directory, 'report.pdf');
    const pdf = await fs.readFile(pdfPath);
    return await callback({ directory, pdfPath, pdf });
  } finally {
    await fs.rm(directory, { recursive: true, force: true });
  }
}

async function renderPowerPointTemplatePreview(templateBytes) {
  await loadPowerPointTemplate(templateBytes);
  return withPowerPointPdf(templateBytes, ({ pdf }) => pdf);
}

async function generateFromPowerPointTemplate(templateBytes, payload, format) {
  const filledTemplate = await fillPowerPointTemplate(templateBytes, payload);
  if (format === 'pptx') return filledTemplate;
  return withPowerPointPdf(filledTemplate, async ({ directory, pdfPath, pdf }) => {
    if (format === 'pdf') return pdf;

    const imagePrefix = path.join(directory, 'report-page');
    const rendererPath = toolPath(
      'REPORT_PDF_RENDERER_PATH',
      process.platform === 'win32' ? 'pdftoppm.exe' : 'pdftoppm',
    );
    await runTool(
      rendererPath,
      ['-png', '-r', '120', pdfPath, imagePrefix],
      'Poppler pdftoppm',
    );
    const pageFiles = (await fs.readdir(directory))
      .filter((name) => /^report-page-\d+\.png$/i.test(name))
      .sort((left, right) =>
        Number(left.match(/-(\d+)\.png$/i)?.[1])
        - Number(right.match(/-(\d+)\.png$/i)?.[1]),
      );
    if (!pageFiles.length) {
      throw new Error('The report template did not produce any slide images.');
    }
    const images = await Promise.all(
      pageFiles.map((name) => fs.readFile(path.join(directory, name))),
    );
    if (format === 'editor') {
      const descriptions = await describeEditableSlides(filledTemplate);
      return images.map((image, index) => ({ ...descriptions[index], image: image.toString('base64') }));
    }
    return format === 'slides' ? images : buildDocxFromImages(images);
  });
}

module.exports = {
  MAX_TEMPLATE_BYTES,
  extractPowerPointTemplatePages,
  extractPowerPointTemplateFields,
  fillPowerPointTemplate,
  generateFromPowerPointTemplate,
  renderPowerPointTemplatePreview,
  validatePowerPointTemplate,
  templateHasPlaceholders,
};

