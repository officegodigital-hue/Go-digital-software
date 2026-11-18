// services/fullReportWord.service.js
// Builds a landscape DOCX where each page is a full-bleed image of the rendered
// deck page, so the Word document matches the branded template.
const { Document, Packer, Paragraph, ImageRun, PageOrientation } = require('docx');

async function buildDocxFromImages(images) {
  const children = images.map((img, i) => new Paragraph({
    pageBreakBefore: i > 0,
    children: [new ImageRun({ data: img, transformation: { width: 960, height: 540 } })],
  }));

  const doc = new Document({
    sections: [{
      properties: { page: { size: { orientation: PageOrientation.LANDSCAPE } } },
      children,
    }],
  });

  return Packer.toBuffer(doc);
}

module.exports = { buildDocxFromImages };
