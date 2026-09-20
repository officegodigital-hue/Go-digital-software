const { PDFDocument, StandardFonts, rgb } = require('pdf-lib');

function money(value) {
  return `Rs. ${Number(value || 0).toLocaleString('en-IN', {maximumFractionDigits: 2})}`;
}

async function buildPayslipPdf(row) {
  const doc = await PDFDocument.create();
  const page = doc.addPage([595.28, 841.89]);
  const regular = await doc.embedFont(StandardFonts.Helvetica);
  const bold = await doc.embedFont(StandardFonts.HelveticaBold);
  const black = rgb(0.08, 0.1, 0.16);
  const navy = rgb(0.03, 0.2, 0.51);
  const pale = rgb(0.93, 0.96, 1);
  const line = rgb(0.72, 0.76, 0.83);
  const left = 42, width = 511;
  const text = (value, x, y, size = 9, font = regular, color = black) => page.drawText(String(value ?? '-'), {x, y, size, font, color});
  const rule = (x1, y1, x2, y2, thickness = 0.7) => page.drawLine({start:{x:x1,y:y1},end:{x:x2,y:y2},thickness,color:line});
  const cell = (label, value, x, y, labelWidth = 95, cellWidth = 255) => {
    text(label, x + 8, y - 17, 8, bold);
    text(value || '-', x + labelWidth, y - 17, 8.5);
    rule(x, y - 28, x + cellWidth, y - 28);
  };

  page.drawRectangle({x:left,y:776,width,height:36,color:navy});
  text('GO DIGITAL', left + 12, 789, 13, bold, rgb(1,1,1));
  text(`Salary Slip For The Month - ${row.pay_month}/${row.pay_year}`, left + 165, 789, 13, bold, rgb(1,1,1));

  let y = 765;
  const detailRows = [
    ['Employee Name', row.full_name || 'Employee', 'Department', row.department || '-'],
    ['Employee Code', row.employee_code || row.employee_user_id, 'Designation', row.department || '-'],
    ['D.O.J', row.date_of_join || '-', 'Grade', row.grade || '-'],
    ['Location', row.location || '-', 'Monthly CTC', money(row.monthly_salary)],
    ['Bank A/C number', row.bank_account || '-', 'Aadhar No.', row.aadhar_no || '-'],
    ['PAN NO.', row.pan_no || '-', 'Net Days Payable', row.paid_days ?? '-'],
    ['PF No.', row.pf_no || '-', 'LOP Days', row.lop_days ?? 0],
    ['ESIC NO.', row.esic_no || '-', 'PF Employer Contribution', money(0)],
    ['UAN NO.', row.uan_no || '-', 'ESIC Employer Contribution', money(0)],
  ];
  for (const r of detailRows) { cell(r[0], r[1], left, y); cell(r[2], r[3], left + 255, y, 130, 256); y -= 28; }
  rule(left, 765, left, y, 0.8); rule(left+255,765,left+255,y,0.8); rule(left+511,765,left+511,y,0.8); rule(left,765,left+511,765,0.8);

  y -= 12;
  page.drawRectangle({x:left,y:y-26,width,height:26,color:pale});
  const xs = [left,left+180,left+270,left+450,left+511];
  ['Earnings','Amt. (INR)','Deductions','Amt. (INR)'].forEach((v,i)=>text(v,xs[i]+7,y-17,8.5,bold,navy));
  const earnings = [
    ['Basic Salary', money(row.monthly_salary), 'Leave Deduction', money(row.deductions)],
    ['House Rent Allowance', money(0), 'PF Employee Contribution', money(0)],
    ['Other Allowance', money(0), 'ESIC Employee Contribution', money(0)],
    ['OT/Night Shift Allowance', money(0), 'Professional Tax', money(0)],
    ['Arrears', money(0), 'Income Tax', money(0)],
    ['Miscellaneous Earnings', money(0), 'Miscellaneous Deductions', money(0)],
  ];
  y -= 26;
  for (const r of earnings) {
    r.forEach((v,i)=>text(v,xs[i]+7,y-17,8));
    rule(left,y-26,left+width,y-26); y -= 26;
  }
  page.drawRectangle({x:left,y:y-30,width,height:30,color:pale});
  text('Total Earnings (A)',left+7,y-19,9,bold); text(money(row.monthly_salary),xs[1]+7,y-19,9,bold);
  text('Total Deductions (B)',xs[2]+7,y-19,9,bold); text(money(row.deductions),xs[3]+7,y-19,9,bold);
  y -= 30;
  for (const x of xs) rule(x,y+212,x,y,0.8);
  rule(left,y,left+width,y,0.8);

  page.drawRectangle({x:left,y:y-48,width,height:48,color:navy});
  text('Total Net Payable (A - B)', left + 18, y - 30, 12, bold, rgb(1,1,1));
  text(money(row.net_pay), left + 405, y - 30, 12, bold, rgb(1,1,1));
  text('This is a system generated pay slip and hence company signature is not required.', left, y - 72, 8, regular, rgb(.35,.39,.48));
  return Buffer.from(await doc.save());
}

module.exports = { buildPayslipPdf };
