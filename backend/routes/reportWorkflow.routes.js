'use strict';

const express = require('express');
const multer = require('multer');
const { authenticateToken } = require('../middleware/auth.middleware');
const db = require('../config/db');
const { reportAccessType } = require('../lib/reportTaskAccess');
const {
  addField,
  createDraft,
  deleteField,
  deleteScreenshot,
  getHistory,
  getClientWorkspace,
  getDraftPreview,
  exportDraft,
  getTemplatePages,
  getTemplates,
  listFields,
  listScreenshots,
  readScreenshot,
  replaceScreenshot,
  submitDraft,
  updateField,
  updateScreenshot,
  uploadScreenshots,
} = require('../controllers/reportWorkflow.controller');

const router = express.Router();
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024, files: 12 },
});
const parseScreenshots = (req, res, next) => {
  upload.array('screenshots', 12)(req, res, (error) => {
    if (!error) return next();
    if (error.code === 'LIMIT_FILE_SIZE') {
      return res.status(413).json({
        success: false,
        message: 'Each screenshot must be 10 MB or smaller.',
      });
    }
    if (error.code === 'LIMIT_UNEXPECTED_FILE' || error.code === 'LIMIT_FILE_COUNT') {
      return res.status(400).json({
        success: false,
        message: 'Upload up to 12 screenshots using the screenshots field.',
      });
    }
    return next(error);
  });
};
const parseScreenshot = (req, res, next) => {
  upload.single('screenshot')(req, res, (error) => {
    if (!error) return next();
    if (error.code === 'LIMIT_FILE_SIZE') {
      return res.status(413).json({
        success: false,
        message: 'A screenshot must be 10 MB or smaller.',
      });
    }
    if (error.code === 'LIMIT_UNEXPECTED_FILE') {
      return res.status(400).json({
        success: false,
        message: 'Upload the replacement using the screenshot field.',
      });
    }
    return next(error);
  });
};

router.use(authenticateToken);
router.use(async (req, res, next) => {
  try {
    const accessType = await reportAccessType(db, req.user);
    if (accessType === 'none') {
      return res.status(403).json({
        success: false,
        message: 'Report access has not been granted to this account.',
      });
    }
    req.user.reportAccessType = accessType;
    return next();
  } catch (error) {
    return next(error);
  }
});

router.get('/templates', getTemplates);
router.get('/templates/:templateId/pages', getTemplatePages);
router.get('/history', getHistory);
router.get('/clients/:clientId/workspace', getClientWorkspace);
router.post('/drafts', createDraft);
router.get('/drafts/:draftId/preview', getDraftPreview);
router.post('/drafts/:draftId/submit', submitDraft);
router.post('/drafts/:draftId/export/:format', exportDraft);
router.get('/drafts/:draftId/screenshots', listScreenshots);
router.post('/drafts/:draftId/screenshots', parseScreenshots, uploadScreenshots);
router.get('/drafts/:draftId/screenshots/:screenshotId/image', readScreenshot);
router.put('/drafts/:draftId/screenshots/:screenshotId', parseScreenshot, replaceScreenshot);
router.patch('/drafts/:draftId/screenshots/:screenshotId/provider', updateScreenshot);
router.patch('/drafts/:draftId/screenshots/:screenshotId', updateScreenshot);
router.delete('/drafts/:draftId/screenshots/:screenshotId', deleteScreenshot);
router.get('/drafts/:draftId/fields', listFields);
router.post('/drafts/:draftId/fields', addField);
router.patch('/drafts/:draftId/fields/:fieldId', updateField);
router.delete('/drafts/:draftId/fields/:fieldId', deleteField);

router.use((error, req, res, next) => {
  if (res.headersSent) return next(error);
  const status = Number.isInteger(error.status) && error.status >= 400 && error.status <= 599
    ? error.status
    : 500;
  if (status >= 500) {
    console.error('Report workflow request failed:', error.stack || error.message);
  }
  return res.status(status).json({
    success: false,
    message: status < 500 ? error.message : 'Unable to complete the report workflow request.',
  });
});

module.exports = router;
