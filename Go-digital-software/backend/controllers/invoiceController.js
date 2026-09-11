const Invoice = require('../models/invoiceModel');

exports.saveInvoice = async (req, res) => {
  try {
    const result = await Invoice.createInvoice(req.body);
    res.status(201).json({ message: "Invoice saved successfully", id: result.insertId });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};