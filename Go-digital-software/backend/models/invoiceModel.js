const db = require('../config/db');

exports.createInvoice = async (data) => {
  const query = 'INSERT INTO invoices (invoice_no, client_name, total_amount, paid_amount, balance_amount) VALUES (?, ?, ?, ?, ?)';
  const [result] = await db.execute(query, [data.invoiceNo, data.clientName, data.total, data.paid, data.balance]);
  return result;
};