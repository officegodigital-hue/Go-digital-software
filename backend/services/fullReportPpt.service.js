// services/fullReportPpt.service.js
// Builds a PPTX where each slide is a full-bleed image of the rendered deck page,
// so the PowerPoint matches the branded template exactly.
const pptxgen = require('pptxgenjs');

async function buildPptxFromImages(images) {
  const pptx = new pptxgen();
  pptx.defineLayout({ name: 'DECK', width: 13.333, height: 7.5 });
  pptx.layout = 'DECK';
  for (const img of images) {
    const slide = pptx.addSlide();
    slide.addImage({
      data: 'data:image/png;base64,' + img.toString('base64'),
      x: 0, y: 0, w: 13.333, h: 7.5,
    });
  }
  return pptx.write('nodebuffer');
}

module.exports = { buildPptxFromImages };
