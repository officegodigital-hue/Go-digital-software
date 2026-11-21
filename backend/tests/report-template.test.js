'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const JSZip = require('jszip');
const PptxGenJS = require('pptxgenjs');

const {
  extractPowerPointTemplatePages,
  fillPowerPointTemplate,
  generateFromPowerPointTemplate,
} = require('../services/reportTemplate.service');

const onePixelPng = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l9sAAAAASUVORK5CYII=';

test('shared PPTX templates replace fields, insert screenshots, and omit inactive provider slides', async () => {
  const source = new PptxGenJS();
  const selected = source.addSlide();
  selected.addText('Google Ads');
  selected.addText('Client: {{client_name}}');
  selected.addText('Clicks: {{google_ads_clicks}}');
  selected.addText('{{SCREENSHOT:GOOGLE_ADS}}', { x: 1, y: 1, w: 6, h: 3 });
  const inactive = source.addSlide();
  inactive.addText('Meta Ads');
  inactive.addText('Clicks: {{meta_ads_clicks}}');
  const summary = source.addSlide();
  summary.addText('Channel Summary');

  const templateBytes = await source.write('nodebuffer');
  const output = await fillPowerPointTemplate(templateBytes, {
    clientName: 'Example Client',
    providers: [{ provider: 'GOOGLE_ADS' }],
    snapshots: [{ provider: 'GOOGLE_ADS', metrics: { clicks: '42' } }],
    screenshots: [{
      provider: 'GOOGLE_ADS',
      bytesBase64: onePixelPng,
      mimeType: 'image/png',
    }],
  });
  const zip = await JSZip.loadAsync(output);
  const presentation = await zip.file('ppt/presentation.xml').async('string');
  const slides = Object.keys(zip.files).filter((name) => /^ppt\/slides\/slide\d+\.xml$/.test(name));
  const selectedSlide = await zip.file('ppt/slides/slide1.xml').async('string');

  assert.equal((presentation.match(/<p:sldId\b/g) || []).length, 2);
  assert.equal(slides.length, 2);
  assert.match(selectedSlide, /Example Client/);
  assert.match(selectedSlide, /42/);
  assert.match(selectedSlide, /<p:pic>/);
  assert.equal(zip.file('ppt/slides/slide2.xml'), null);
});

test('active PPTX pages expose provider pages and mandatory static pages', async () => {
  const source = new PptxGenJS();
  source.addSlide().addText('Google Ads Dashboard');
  source.addSlide().addText('Channel Summary');
  const templateBytes = await source.write('nodebuffer');

  const pages = await extractPowerPointTemplatePages(templateBytes);

  assert.equal(pages.length, 2);
  assert.equal(pages[0].provider_code, 'GOOGLE_ADS');
  assert.equal(pages[0].required_static, 0);
  assert.equal(pages[1].provider_code, 'mandatory');
  assert.equal(pages[1].required_static, 1);
});

test('shared-template PDF export reports a missing Office runtime explicitly', async () => {
  const source = new PptxGenJS();
  source.addSlide().addText('Client: {{client_name}}');
  const templateBytes = await source.write('nodebuffer');
  const previous = process.env.REPORT_OFFICE_CONVERTER_PATH;
  process.env.REPORT_OFFICE_CONVERTER_PATH = 'missing-office-runtime-for-test';
  try {
    await assert.rejects(
      generateFromPowerPointTemplate(templateBytes, {}, 'pdf'),
      /LibreOffice is required/,
    );
  } finally {
    if (previous == null) {
      delete process.env.REPORT_OFFICE_CONVERTER_PATH;
    } else {
      process.env.REPORT_OFFICE_CONVERTER_PATH = previous;
    }
  }
});
