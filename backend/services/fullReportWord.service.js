// services/fullReportWord.service.js
// Builds a landscape DOCX where each page is a full-bleed image of the rendered
// deck page, so the Word document matches the branded template.
const { Document, Packer, Paragraph, ImageRun, PageOrientation } = require('docx');

async function buildDocxFromImages(images) {
  const children = images.map((img, i) => {
    const isPng = img.length > 24
      && img[0] === 0x89
      && img[1] === 0x50
      && img[2] === 0x4e
      && img[3] === 0x47;
    const sourceWidth = isPng ? img.readUInt32BE(16) : 16;
    const sourceHeight = isPng ? img.readUInt32BE(20) : 9;
    const scale = Math.min(960 / sourceWidth, 540 / sourceHeight);
    return new Paragraph({
      pageBreakBefore: i > 0,
      children: [new ImageRun({
        data: img,
        transformation: {
          width: Math.round(sourceWidth * scale),
          height: Math.round(sourceHeight * scale),
        },
      })],
    });
  });

  const doc = new Document({
    sections: [{
      properties: { page: { size: { orientation: PageOrientation.LANDSCAPE } } },
      children,
    }],
  });

  return Packer.toBuffer(doc);
}

module.exports = { buildDocxFromImages };
