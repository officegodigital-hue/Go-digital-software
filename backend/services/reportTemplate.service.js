'use strict';

const { execFile } = require('node:child_process');
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

// Accept any real PowerPoint file as a template. Placeholders are no longer
// required: a template without them simply falls back to the built-in report
// at generation time (see generateReportFile). Returns whether it has tokens.
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

function reportFields(payload) {
  const fields = new Map();
  addField(fields, 'client_name', payload.clientName);
  addField(fields, 'client_brand', payload.clientName);
  addField(fields, 'report_month', payload.reportMonth);
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
    const provider = providerKey(snapshot?.provider).toLowerCase();
    const metrics = snapshot?.metrics;
    if (!provider || !metrics || typeof metrics !== 'object') continue;
    for (const [key, value] of Object.entries(metrics)) {
      if (key === 'export_overrides' || value == null || typeof value === 'object') continue;
      addField(fields, `${provider}_${key}`, value, { overwrite: true });
      addField(fields, key, value);
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

// Channel Summary is a single combined table listing every marketing channel
// in one grid. These prefixes/suffixes are the exact field keys the client app
// produces for that page (e.g. {{google_ads_impressions}}), derived from its
// channel labels. A channel with no entered summary value has its whole table
// row removed so the downloaded report shows only the channels that have data.
const CHANNEL_SUMMARY_PREFIXES = [
  'gmb_gbp',
  'google_ads',
  'meta_ads',
  'linkedin_ads',
  'instagram',
  'facebook',
  'youtube',
  'linkedin',
  'twitter_x',
];
const CHANNEL_SUMMARY_SUFFIXES = [
  'impressions',
  'clicks',
  'leads_calls',
  'spend',
  'estimated_conversion_leads',
];

// Returns the set of channel prefixes that have no Channel Summary value at all.
function emptyChannelSummaryPrefixes(fields) {
  const empty = new Set();
  for (const prefix of CHANNEL_SUMMARY_PREFIXES) {
    const hasValue = CHANNEL_SUMMARY_SUFFIXES.some((suffix) => {
      const value = fields.get(`${prefix}_${suffix}`);
      return value != null && String(value).trim() !== '';
    });
    if (!hasValue) empty.add(prefix);
  }
  return empty;
}

// Identifies which Channel Summary channel a table row belongs to by the exact
// {{prefix_suffix}} placeholder(s) it contains. Full-key matching keeps
// 'linkedin_ads' distinct from 'linkedin'. Returns null for non-summary rows
// (headers, totals) so they are never removed.
function channelSummaryRowPrefix(rowXml) {
  let text = '';
  for (const match of rowXml.matchAll(/<a:t\b[^>]*>([\s\S]*?)<\/a:t>/g)) {
    text += decodeXml(match[1]);
  }
  if (!text.includes('{{')) return null;
  for (const prefix of CHANNEL_SUMMARY_PREFIXES) {
    for (const suffix of CHANNEL_SUMMARY_SUFFIXES) {
      if (new RegExp(`\\{\\{\\s*${prefix}_${suffix}\\s*\\}\\}`, 'i').test(text)) {
        return prefix;
      }
    }
  }
  return null;
}

// Removes <a:tr> rows of the Channel Summary table for channels with no data.
// A no-op when there is no such table (text-box layouts) or nothing is empty.
function removeEmptyChannelSummaryRows(xml, emptyPrefixes) {
  if (!emptyPrefixes || emptyPrefixes.size === 0) return xml;
  return xml.replace(/<a:tr\b[\s\S]*?<\/a:tr>/g, (row) => {
    const prefix = channelSummaryRowPrefix(row);
    return prefix && emptyPrefixes.has(prefix) ? '' : row;
  });
}

function activeProviderKeys(payload) {
  const providers = new Set();
  const add = (value) => {
    const key = providerKey(value);
    if (key) providers.add(key);
  };
  for (const provider of Array.isArray(payload.providers) ? payload.providers : []) {
    add(typeof provider === 'string' ? provider : provider?.provider);
  }
  for (const snapshot of Array.isArray(payload.snapshots) ? payload.snapshots : []) {
    add(snapshot?.provider);
  }
  for (const screenshot of Array.isArray(payload.screenshots) ? payload.screenshots : []) {
    add(screenshot?.provider);
  }
  return providers;
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

function xmlTextTokenReplacement(xml, fields) {
  return xml.replace(/<a:t\b([^>]*)>([\s\S]*?)<\/a:t>/g, (_, attrs, encoded) => {
    const text = decodeXml(encoded).replace(/\{\{\s*([a-z0-9_.-]+)\s*\}\}/gi, (_token, key) =>
      fields.get(key.toLowerCase()) || '',
    );
    return `<a:t${attrs}>${escapeXml(text)}</a:t>`;
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

async function normalizeScreenshot(image) {
  const mimeType = String(image.mimeType || 'image/jpeg').toLowerCase();
  if (mimeType === 'image/png' || mimeType === 'image/jpeg') {
    const bytes = screenshotBytes(image);
    if (!bytes) return null;
    return { bytes, extension: mimeType === 'image/png' ? 'png' : 'jpg', contentType: mimeType };
  }
  if (mimeType !== 'image/webp') {
    throw new Error(`Unsupported screenshot type for the PowerPoint template: ${mimeType}`);
  }

  const bytes = screenshotBytes(image);
  if (!bytes) return null;
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
    return { bytes: Buffer.from(png), extension: 'png', contentType: 'image/png' };
  } finally {
    await browser.close();
  }
}

function imageRelationshipId(xml) {
  const ids = [...xml.matchAll(/\bId="rId(\d+)"/g)].map((match) => Number(match[1]));
  return `rId${Math.max(0, ...ids) + 1}`;
}

function pictureShape(shapeXml, relationshipId, imageName) {
  const transform = shapeXml.match(/<a:xfrm\b[^>]*>([\s\S]*?)<\/a:xfrm>/)?.[1];
  const off = transform?.match(/<a:off\b[^>]*\bx="(\d+)"[^>]*\by="(\d+)"[^>]*\/>/);
  const ext = transform?.match(/<a:ext\b[^>]*\bcx="(\d+)"[^>]*\bcy="(\d+)"[^>]*\/>/);
  const shapeId = shapeXml.match(/<p:cNvPr\b[^>]*\bid="(\d+)"/)?.[1];
  if (!off || !ext || !shapeId) {
    throw new Error('A screenshot placeholder must be a positioned PowerPoint text box.');
  }
  return `<p:pic><p:nvPicPr><p:cNvPr id="${shapeId}" name="${imageName}"/><p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr><p:nvPr/></p:nvPicPr><p:blipFill><a:blip r:embed="${relationshipId}"/><a:stretch><a:fillRect/></a:stretch></p:blipFill><p:spPr><a:xfrm><a:off x="${off[1]}" y="${off[2]}"/><a:ext cx="${ext[1]}" cy="${ext[2]}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr></p:pic>`;
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

async function removeUnusedProviderSlides(zip, presentationXml, presentationRels, contentTypes, payload) {
  const active = activeProviderKeys(payload);
  const slides = presentationSlides(presentationXml, presentationRels);
  const retained = [];
  let nextPresentation = presentationXml;
  let nextRelations = presentationRels;
  let nextTypes = contentTypes;

  for (const slide of slides) {
    const xml = zip.file(slide.slidePath);
    if (!xml) throw new Error('The report template is missing a referenced slide.');
    const provider = slideProvider(await xml.async('string'));
    const activeAliases = {
      GOOGLE_BUSINESS_PROFILE: ['GOOGLE_BUSINESS_PROFILE', 'GMB', 'GBP'],
      TWITTER: ['TWITTER', 'TWITTER_X', 'X'],
    };
    if (!provider || (activeAliases[provider] || [provider]).some((key) => active.has(key))) {
      retained.push(slide);
      continue;
    }
    nextPresentation = nextPresentation.replace(slide.node, '');
    const relationPattern = new RegExp(`<Relationship\\b(?=[^>]*\\bId="${slide.relationshipId}")[^>]*/>`);
    nextRelations = nextRelations.replace(relationPattern, '');
    zip.remove(slide.slidePath);
    const slideNumber = slide.slidePath.match(/slide(\d+)\.xml$/)?.[1];
    if (slideNumber) {
      zip.remove(`ppt/slides/_rels/slide${slideNumber}.xml.rels`);
      nextTypes = nextTypes.replace(
        new RegExp(`<Override\\b(?=[^>]*\\bPartName="/ppt/slides/slide${slideNumber}\\.xml")[^>]*/>`),
        '',
      );
    }
  }
  return { slides: retained, presentationXml: nextPresentation, presentationRels: nextRelations, contentTypes: nextTypes };
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
  const filtered = await removeUnusedProviderSlides(
    zip,
    presentationXml,
    presentationRels,
    initialContentTypes,
    payload,
  );
  const fields = reportFields(payload);
  const emptyChannels = emptyChannelSummaryPrefixes(fields);
  const imagesByProvider = new Map();
  for (const item of Array.isArray(payload.screenshots) ? payload.screenshots : []) {
    const key = providerKey(item?.provider);
    if (!key || !screenshotBytes(item)) continue;
    imagesByProvider.set(key, [...(imagesByProvider.get(key) || []), item]);
  }
  const usedImageCount = new Map();
  const slotCount = new Map();
  for (const slide of filtered.slides) {
    const xml = await zip.file(slide.slidePath).async('string');
    for (const shape of xml.matchAll(/<p:sp\b[\s\S]*?<\/p:sp>/g)) {
      const key = screenshotToken(shape[0]);
      if (key) slotCount.set(key, (slotCount.get(key) || 0) + 1);
    }
  }
  for (const [key, images] of imagesByProvider) {
    if ((slotCount.get(key) || 0) < images.length) {
      throw new Error(
        `The active template needs ${images.length} {{SCREENSHOT:${key}}} placeholders for the uploaded images.`,
      );
    }
  }

  let contentTypes = filtered.contentTypes;
  const normalizedImages = new Map();
  let imageNumber = 0;
  for (const slide of filtered.slides) {
    const slideNumber = slide.slidePath.match(/slide(\d+)\.xml$/)?.[1];
    if (!slideNumber) throw new Error('The report template contains an invalid slide file name.');
    let xml = await zip.file(slide.slidePath).async('string');
    const shapePattern = /<p:sp\b[\s\S]*?<\/p:sp>/g;
    const shapes = [...xml.matchAll(shapePattern)];
    for (const shapeMatch of shapes) {
      const provider = screenshotToken(shapeMatch[0]);
      if (!provider) continue;
      const imageIndex = usedImageCount.get(provider) || 0;
      const sourceImage = imagesByProvider.get(provider)?.[imageIndex];
      if (!sourceImage) {
        xml = xml.replace(shapeMatch[0], '');
        continue;
      }
      let normalized = normalizedImages.get(sourceImage);
      if (!normalized) {
        normalized = await normalizeScreenshot(sourceImage);
        if (!normalized?.bytes) throw new Error('A dashboard screenshot could not be decoded.');
        normalizedImages.set(sourceImage, normalized);
      }
      imageNumber += 1;
      const picture = await addSlideImage(
        zip,
        slideNumber,
        normalized,
        provider,
        shapeMatch[0],
        imageNumber,
      );
      xml = xml.replace(shapeMatch[0], picture);
      usedImageCount.set(provider, imageIndex + 1);
      contentTypes = ensureImageContentType(
        contentTypes,
        normalized.extension,
        normalized.contentType,
      );
    }
    xml = removeEmptyChannelSummaryRows(xml, emptyChannels);
    zip.file(slide.slidePath, xmlTextTokenReplacement(xml, fields));
  }
  zip.file(presentationPath, filtered.presentationXml);
  zip.file(relationsPath, filtered.presentationRels);
  zip.file(contentTypesPath, contentTypes);
  return zip.generateAsync({ type: 'nodebuffer', compression: 'DEFLATE' });
}

function toolPath(environmentKey, fallback) {
  return process.env[environmentKey] || fallback;
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

async function generateFromPowerPointTemplate(templateBytes, payload, format) {
  const filledTemplate = await fillPowerPointTemplate(templateBytes, payload);
  if (format === 'pptx') return filledTemplate;
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'godigital-report-'));
  try {
    const pptxPath = path.join(directory, 'report.pptx');
    await fs.writeFile(pptxPath, filledTemplate);
    const officePath = toolPath(
      'REPORT_OFFICE_CONVERTER_PATH',
      process.platform === 'win32' ? 'soffice.exe' : 'soffice',
    );
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
      throw new Error('The report template did not produce any pages for Word export.');
    }
    const images = await Promise.all(
      pageFiles.map((name) => fs.readFile(path.join(directory, name))),
    );
    return buildDocxFromImages(images);
  } finally {
    await fs.rm(directory, { recursive: true, force: true });
  }
}

module.exports = {
  MAX_TEMPLATE_BYTES,
  extractPowerPointTemplatePages,
  fillPowerPointTemplate,
  generateFromPowerPointTemplate,
  validatePowerPointTemplate,
  templateHasPlaceholders,
};

