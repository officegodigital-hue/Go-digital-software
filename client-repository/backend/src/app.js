const express = require("express");
const cors = require("cors");
const path = require("path");

const authRoutes = require("./routes/auth.routes");
const assetRoutes = require("./routes/asset.routes");
const mobileRoutes = require("./routes/mobile.routes");
const settingsRoutes = require("./routes/settings.routes");

const app = express();

app.use(cors());
app.use(express.json());

app.use("/uploads", express.static(path.join(__dirname, "../uploads")));

app.get("/", (req, res) => {
  res.json({
    success: true,
    message: "Go Digital Repository Backend Running",
  });
});

app.use("/api/auth", authRoutes);
app.use("/api/assets", assetRoutes);
app.use("/api/mobile", mobileRoutes);
app.use("/api/settings", settingsRoutes);

module.exports = app;