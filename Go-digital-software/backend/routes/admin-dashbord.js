const express = require("express");
const router = express.Router();
const db = require("../config/db");

router.get("/recent-notifications/:employeeName", async (req, res) => {
  const { employeeName } = req.params;

  try {
    const [rows] = await db.query(
      `
      SELECT
        id,
        sender_name,
        recipient_name,
        message,
        is_seen,
        created_at
      FROM notifications
      WHERE sender_name = ?
         OR recipient_name = ?
      ORDER BY created_at DESC
      LIMIT 3
      `,
      [employeeName, employeeName]
    );

    const notifications = rows.map((row) => {
      let preview = row.message;

      try {
        const msg = JSON.parse(row.message);
        preview =
          msg.preview ||
          msg.message ||
          msg.title ||
          row.message;
      } catch (_) {}

      return {
        id: row.id,
        sender: row.sender_name,
        recipient: row.recipient_name,
        preview,
        isSeen: row.is_seen,
        createdAt: row.created_at,
      };
    });

    res.json({
      success: true,
      data: notifications,
    });
  } catch (err) {
    console.error("Dashboard Notifications:", err);
    res.status(500).json({
      success: false,
      message: err.message,
    });
  }
});

module.exports = router;