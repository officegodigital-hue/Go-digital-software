// services/fullReportRender.service.js
// Renders the branded report HTML (from reportHtml.service) into real files:
//   - PDF  : one 1280x720 page per slide, via Puppeteer
//   - PNGs : one image per slide (used to build PPTX / DOCX that match the deck)
const puppeteer = require('puppeteer');

const SLIDE_W = 1280;
const SLIDE_H = 720;

let browserPromise = null;
// Reuse one browser across requests; relaunch if it died.
async function getBrowser() {
  if (browserPromise) {
    try {
      const b = await browserPromise;
      if (b && b.isConnected()) return b;
    } catch (_) { /* fall through to relaunch */ }
  }
  browserPromise = puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage'],
  });
  return browserPromise;
}

async function withPage(html, fn) {
  const browser = await getBrowser();
  const page = await browser.newPage();
  try {
    await page.setViewport({ width: SLIDE_W, height: SLIDE_H, deviceScaleFactor: 2 });
    await page.setContent(html, { waitUntil: 'networkidle0', timeout: 60000 });
    return await fn(page);
  } finally {
    await page.close().catch(() => {});
  }
}

// Render the whole deck to a single PDF buffer.
async function renderHtmlToPdf(html) {
  return withPage(html, (page) => page.pdf({
    width: `${SLIDE_W}px`,
    height: `${SLIDE_H}px`,
    printBackground: true,
    pageRanges: '',
    margin: { top: 0, right: 0, bottom: 0, left: 0 },
  }));
}

// Render each .slide element to a PNG buffer (array, in document order).
async function renderHtmlToImages(html) {
  return withPage(html, async (page) => {
    const handles = await page.$$('.slide');
    const images = [];
    for (const handle of handles) {
      const buf = await handle.screenshot({ type: 'png' });
      images.push(buf);
    }
    return images;
  });
}

async function closeBrowser() {
  if (browserPromise) {
    try { const b = await browserPromise; await b.close(); } catch (_) {}
    browserPromise = null;
  }
}

module.exports = { renderHtmlToPdf, renderHtmlToImages, closeBrowser, SLIDE_W, SLIDE_H };
