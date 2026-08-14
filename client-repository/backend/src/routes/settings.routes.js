const express = require("express");
const router = express.Router();

const settingsController = require("../controllers/settings.controller");
const { verifyToken, requireAdmin } = require("../middlewares/auth.middleware");

/* GET SETTINGS */
router.get(
  "/",
  verifyToken,
  requireAdmin,
  settingsController.getSettings
);

/* UPDATE ADMIN PROFILE */
router.put(
  "/admin-profile",
  verifyToken,
  requireAdmin,
  settingsController.updateAdminProfile
);

/* UPDATE MOBILE APP LOGIN */
router.put(
  "/mobile-credentials",
  verifyToken,
  requireAdmin,
  settingsController.updateMobileCredentials
);

/* GET MOBILE APP ACTIVE DEVICES */
router.get(
  "/mobile-sessions",
  verifyToken,
  requireAdmin,
  settingsController.getMobileSessions
);

/* REMOVE ONE MOBILE DEVICE */
router.delete(
  "/mobile-sessions/:id",
  verifyToken,
  requireAdmin,
  settingsController.removeMobileSession
);

/* REMOVE ALL MOBILE DEVICES */
router.delete(
  "/mobile-sessions",
  verifyToken,
  requireAdmin,
  settingsController.removeAllMobileSessions
);

module.exports = router;