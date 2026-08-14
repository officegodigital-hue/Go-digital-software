const express = require("express");
const router = express.Router();

const mobileController = require("../controllers/mobile.controller");
router.post("/login", mobileController.loginMobileApp);
router.get("/categories", mobileController.getCategories);
router.get("/clients", mobileController.getClientsByCategory);
router.get(
  "/clients/:clientId/deliverables",
  mobileController.getClientDeliverables
);

module.exports = router;