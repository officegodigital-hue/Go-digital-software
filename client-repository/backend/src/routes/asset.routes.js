const express = require("express");
const multer = require("multer");
const path = require("path");
const fs = require("fs");

const router = express.Router();

const assetController = require("../controllers/asset.controller");
const { verifyToken, requireAdmin } = require("../middlewares/auth.middleware");

const uploadDir = path.join(__dirname, "../../uploads");

if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, uploadDir);
  },
  filename: function (req, file, cb) {
    const safeName = file.originalname.replace(/\s+/g, "-");
    const uniqueName =
      Date.now() + "-" + Math.round(Math.random() * 1e9) + "-" + safeName;

    cb(null, uniqueName);
  },
});

const upload = multer({
  storage,
  limits: {
    fileSize: 50 * 1024 * 1024,
  },
});

router.post(
  "/",
  verifyToken,
  requireAdmin,
  upload.fields([
    { name: "poster_design_file", maxCount: 10 },
    { name: "video_file", maxCount: 10 },
    { name: "landing_page_file", maxCount: 10 },
    { name: "website_file", maxCount: 10 },
    { name: "other_link_file", maxCount: 10 },

    { name: "photos_file", maxCount: 20 },
    { name: "portfolio_file", maxCount: 20 },
    { name: "packages_file", maxCount: 20 },

    { name: "mobile_application_file", maxCount: 10 },
    { name: "website_application_file", maxCount: 10 },
    { name: "web_application_file", maxCount: 10 },
  ]),
  assetController.createAsset
);

router.get(
  "/repository",
  verifyToken,
  requireAdmin,
  assetController.getRepository
);

router.get(
  "/clients",
  verifyToken,
  requireAdmin,
  assetController.getRepositoryClients
);

router.get(
  "/clients/:clientId",
  verifyToken,
  requireAdmin,
  assetController.getClientAssetDetails
);

router.put(
  "/clients/:clientId",
  verifyToken,
  requireAdmin,
  upload.fields([
    { name: "poster_design_file", maxCount: 10 },
    { name: "video_file", maxCount: 10 },
    { name: "landing_page_file", maxCount: 10 },
    { name: "website_file", maxCount: 10 },
    { name: "other_link_file", maxCount: 10 },

    { name: "photos_file", maxCount: 20 },
    { name: "portfolio_file", maxCount: 20 },
    { name: "packages_file", maxCount: 20 },

    { name: "mobile_application_file", maxCount: 10 },
    { name: "website_application_file", maxCount: 10 },
    { name: "web_application_file", maxCount: 10 },
  ]),
  assetController.updateClientAssetDetails
);

router.delete(
  "/clients/:clientId",
  verifyToken,
  requireAdmin,
  assetController.deleteClientAssetDetails
);

router.delete(
  "/deliverables/:id",
  verifyToken,
  requireAdmin,
  assetController.deleteDeliverable
);

module.exports = router;