const express = require('express');
const router = express.Router();
const invoiceController = require('../controllers/invoiceController');

router.post('/save', invoiceController.saveInvoice);

module.exports = router;