'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const JSZip = require('jszip');
const PptxGenJS = require('pptxgenjs');

const {
  extractPowerPointTemplatePages,
  extractPowerPointTemplateFields,
  fillPowerPointTemplate,
  generateFromPowerPointTemplate,
} = require('../services/reportTemplate.service');

const onePixelPng = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l9sAAAAASUVORK5CYII=';

test('PPTX templates retain only selected provider pages and required shared pages', async () => {
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
  assert.equal(slides.length, 3);
  assert.match(selectedSlide, /Example Client/);
  assert.match(selectedSlide, /42/);
  assert.match(selectedSlide, /<p:pic>/);
  const imageDimensions = selectedSlide.match(
    /<p:pic>[\s\S]*?<a:ext cx="(\d+)" cy="(\d+)"/,
  );
  assert.ok(imageDimensions);
  assert.equal(imageDimensions[1], imageDimensions[2]);
  assert.equal(slides.length, 3); // removed slides remain orphaned, but are not rendered
  assert.match(await zip.file('ppt/slides/slide3.xml').async('string'), /Channel Summary/);
});

test('active PPTX pages expose provider pages and mandatory static pages', async () => {
  const source = new PptxGenJS();
  source.addSlide().addText('Google Ads Dashboard');
  source.addSlide().addText('Channel Summary');
  const sourceBytes = await source.write('nodebuffer');
  const sourceZip = await JSZip.loadAsync(sourceBytes);
  const sourceXml = await sourceZip.file('ppt/slides/slide1.xml').async('string');
  sourceZip.file('ppt/slides/slide1.xml', sourceXml
    .replace('name="Shape 1"', 'name="Card IMPRESSIONS"')
    .replace('name="Shape 5"', 'name="Card ACTIVE CAMPAIGNS"'));
  const templateBytes = await sourceZip.generateAsync({ type: 'nodebuffer' });

  const pages = await extractPowerPointTemplatePages(templateBytes);

  assert.equal(pages.length, 2);
  assert.equal(pages[0].provider_code, 'GOOGLE_ADS');
  assert.equal(pages[0].required_static, 0);
  assert.equal(pages[1].provider_code, 'mandatory');
  assert.equal(pages[1].required_static, 1);
});

test('PowerPoint export preserves an uploaded template without placeholders', async () => {
  const source = new PptxGenJS();
  source.addSlide().addText('Client-specific report design');
  const templateBytes = await source.write('nodebuffer');

  const output = await generateFromPowerPointTemplate(templateBytes, {}, 'pptx');
  const zip = await JSZip.loadAsync(output);
  const slide = await zip.file('ppt/slides/slide1.xml').async('string');

  assert.match(slide, /Client-specific report design/);
});

test('field extraction and replacement support dynamic keys split across PowerPoint text runs', async () => {
  const source = new PptxGenJS();
  const slide = source.addSlide();
  slide.addText([
    { text: 'Campaign: {{campaign_' },
    { text: 'title}}' },
  ]);
  slide.addText('{{SCREENSHOT:CAMPAIGN}}', { x: 1, y: 1, w: 6, h: 3 });
  const templateBytes = await source.write('nodebuffer');

  const fields = await extractPowerPointTemplateFields(templateBytes);
  const output = await fillPowerPointTemplate(templateBytes, {
    templateFields: { campaign_title: 'Spring launch' },
  });
  const zip = await JSZip.loadAsync(output);
  const slideXml = await zip.file('ppt/slides/slide1.xml').async('string');

  assert.deepEqual(fields.map((field) => field.field_key), [
    'campaign_title',
    'screenshot:campaign',
  ]);
  assert.match(slideXml, /Campaign: Spring launch/);
  assert.doesNotMatch(slideXml, /\{\{\s*campaign_title\s*\}\}/);
});

test('PPTX fields show month-over-month change from the previous report', async () => {
  const source = new PptxGenJS();
  const slide = source.addSlide();
  slide.addText('{{instagram_views_vs_last_month}}');
  const templateBytes = await source.write('nodebuffer');

  const output = await fillPowerPointTemplate(templateBytes, {
    snapshots: [{ provider: 'Instagram', metrics: { views: '800' } }],
    lastMonthSnapshots: [{ provider: 'Instagram', metrics: { views: '1,000' } }],
  });
  const zip = await JSZip.loadAsync(output);
  const slideXml = await zip.file('ppt/slides/slide1.xml').async('string');

  assert.match(slideXml, /20% decrease/);
});

test('shared summary and plan tables retain only uploaded platforms and populate metrics', async () => {
  const source = new PptxGenJS();
  const summary = source.addSlide();
  summary.addText('Channel Summary');
  summary.addTable([
    ['Channel', 'Impressions', 'Clicks', 'Leads / Calls', 'Spend (₹)', 'Estimated Conversion leads'],
    ['GMB / GBP', '', '', '', '', ''],
    ['Google Ads', '', '', '', '', ''],
    ['Meta Ads', '', '', '', '', ''],
    ['LinkedIn Ads', '', '', '', '', ''],
  ], { x: 0.5, y: 1, w: 9, border: { color: 'CCCCCC', pt: 1 } });
  const plan = source.addSlide();
  plan.addText('Next Month Plan');
  plan.addTable([
    ['Channel', 'Action planned', 'Owner', 'Due'],
    ['GMB / GBP', '', '', ''],
    ['Google Ads', '', '', ''],
    ['Meta Ads', '', '', ''],
    ['LinkedIn Ads', '', '', ''],
  ], { x: 0.5, y: 1, w: 8, border: { color: 'CCCCCC', pt: 1 } });
  const templateBytes = await source.write('nodebuffer');

  const output = await fillPowerPointTemplate(templateBytes, {
    screenshots: [{ provider: 'GOOGLE_ADS', bytesBase64: onePixelPng, mimeType: 'image/png' }, {
      provider: 'LINKEDIN_ADS', bytesBase64: onePixelPng, mimeType: 'image/png',
    }],
    templateFields: {
      gmb_impressions: '5,000',
      gmb_clicks: '120',
      google_ads_impressions: '1,250',
      google_ads_clicks: '88',
      linkedin_ads_impressions: '900',
      linkedin_ads_spend: '₹500',
      google_business_profile_action_planned: 'Update profile',
      google_ads_action_planned: 'Optimise campaign',
      linkedin_ads_owner: 'Alex',
    },
    powerPointEdits: { '2:3:GOOGLE_ADS:1': 'Review campaign' },
  });
  const zip = await JSZip.loadAsync(output);
  const summaryXml = await zip.file('ppt/slides/slide1.xml').async('string');
  const planXml = await zip.file('ppt/slides/slide2.xml').async('string');

  assert.match(summaryXml, /5,000/);
  assert.match(summaryXml, /<a:tr\b[^>]*>(?:(?!<\/a:tr>)[\s\S])*5,000(?:(?!<\/a:tr>)[\s\S])*<\/a:tr>/);
  assert.match(summaryXml, /1,250/);
  assert.ok(summaryXml.indexOf('Google Ads') < summaryXml.indexOf('GMB / GBP'));
  assert.match(summaryXml, /900/);
  assert.doesNotMatch(summaryXml, />Meta Ads</);
  assert.match(planXml, /Update profile/);
  assert.match(planXml, /Review campaign/);
  assert.match(planXml, /Alex/);
  assert.doesNotMatch(planXml, />Meta Ads</);
});

test('legacy cover [Enter] prompts are populated from report fields', async () => {
  const source = new PptxGenJS();
  const slide = source.addSlide();
  slide.addText('CLIENT MONTHLY REPORT');
  slide.addText('CLIENT / BRAND\n[Enter]');
  slide.addText('REPORT MONTH\n[Enter]');
  const templateBytes = await source.write('nodebuffer');

  const output = await fillPowerPointTemplate(templateBytes, {
    clientName: 'Elite Dress Spa',
    reportMonth: 'December 2026',
  });
  const zip = await JSZip.loadAsync(output);
  const xml = await zip.file('ppt/slides/slide1.xml').async('string');

  assert.match(xml, /Elite Dress Spa/);
  assert.match(xml, /December 2026/);
  assert.doesNotMatch(xml, /\[Enter\]/);
});

test('metric-card slides populate values and remove empty cards', async () => {
  const source = new PptxGenJS();
  const slide = source.addSlide();
  slide.addText('Google Ads');
  slide.addShape(source.ShapeType.roundRect, { x: 0.5, y: 1, w: 3, h: 1, name: 'Card IMPRESSIONS' });
  slide.addText('IMPRESSIONS', { x: 0.6, y: 1.1, w: 2, h: 0.2 });
  slide.addText('—', { x: 0.6, y: 1.4, w: 2, h: 0.2 });
  slide.addText('vs last month: ____ %', { x: 0.6, y: 1.7, w: 2.5, h: 0.2 });
  slide.addShape(source.ShapeType.roundRect, { x: 4, y: 1, w: 3, h: 1, name: 'Card ACTIVE CAMPAIGNS' });
  slide.addText('ACTIVE CAMPAIGNS', { x: 4.1, y: 1.1, w: 2.5, h: 0.2 });
  slide.addText('—', { x: 4.1, y: 1.4, w: 2, h: 0.2 });
  const sourceBytes = await source.write('nodebuffer');
  const sourceZip = await JSZip.loadAsync(sourceBytes);
  const sourceXml = await sourceZip.file('ppt/slides/slide1.xml').async('string');
  sourceZip.file('ppt/slides/slide1.xml', sourceXml
    .replace('name="Shape 1"', 'name="Card IMPRESSIONS"')
    .replace('name="Shape 5"', 'name="Card ACTIVE CAMPAIGNS"'));
  const templateBytes = await sourceZip.generateAsync({ type: 'nodebuffer' });

  const output = await fillPowerPointTemplate(templateBytes, {
    snapshots: [{ provider: 'GOOGLE_ADS', metrics: { impressions: '1,200' } }],
    lastMonthSnapshots: [{ provider: 'GOOGLE_ADS', metrics: { impressions: '1,000' } }],
  });
  const zip = await JSZip.loadAsync(output);
  const xml = await zip.file('ppt/slides/slide1.xml').async('string');

  assert.match(xml, /1,200/);
  assert.match(xml, /20% increase/);
  assert.doesNotMatch(xml, /ACTIVE CAMPAIGNS/);
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

test('PowerPoint includes Instagram screenshots and keeps named poster slots', async () => {
  const source = new PptxGenJS();
  source.addSlide().addText('Client Monthly Report');
  const instagram = source.addSlide();
  instagram.addText('Instagram Dashboard');
  instagram.addText('{{SCREENSHOT:INSTAGRAM}}', { x: 1, y: 1, w: 6, h: 3 });
  const showcase = source.addSlide();
  showcase.addText('Creative Showcase');
  showcase.addText('{{SCREENSHOT:CREATIVE_SHOWCASE}}', { x: 1, y: 1, w: 3, h: 3 });
  showcase.addText('{{SCREENSHOT:CREATIVE_SHOWCASE}}', { x: 5, y: 1, w: 3, h: 3 });
  const image = { bytesBase64: onePixelPng, mimeType: 'image/png' };
  const deck = await fillPowerPointTemplate(await source.write('nodebuffer'), {
    selectedProviders: ['CREATIVE_SHOWCASE'],
    screenshots: [
      { ...image, provider: 'INSTAGRAM' },
      { ...image, provider: 'INSTAGRAM' },
      { ...image, provider: 'CREATIVE_SHOWCASE', slot: 'Poster 2' },
      { ...image, provider: 'CREATIVE_SHOWCASE', slot: 'Poster 4' },
    ],
  });
  const zip = await JSZip.loadAsync(deck);
  const presentation = await zip.file('ppt/presentation.xml').async('string');
  assert.equal([...presentation.matchAll(/<p:sldId\b/g)].length, 5);
  const readSlide = (number) => zip.file('ppt/slides/slide' + number + '.xml').async('string');
  assert.match(await readSlide(2), /<p:pic>/);
  const creative = await readSlide(3);
  assert.equal([...creative.matchAll(/<p:pic>/g)].length, 1);
  assert.match(creative, /<a:off x="4572000" y="914400"\/>/);
  assert.match(await readSlide(4), /Instagram Dashboard.*<p:pic>/);
  assert.match(await readSlide(5), /Creative Showcase - Poster 4.*<p:pic>/);
});
