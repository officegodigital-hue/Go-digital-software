const express = require('express');
const router = express.Router();
const { authenticateToken } = require('./auth');
const controller = require('../controllers/hrmsWorkingDaysController');

router.use(authenticateToken);
router.use((req, res, next) => String(req.user && req.user.userType || '').toLowerCase() === 'admin'
  ? next() : res.status(403).json({ success: false, message: 'Admin access required' }));
router.get('/templates', controller.list);
router.post('/templates', controller.create);
router.put('/templates/:id', controller.update);
router.post('/templates/:id/archive', controller.archive);
module.exports = router;
