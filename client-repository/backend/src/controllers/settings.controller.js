const bcrypt = require("bcryptjs");
const db = require("../config/db");

/* GET SETTINGS DATA */
exports.getSettings = async (req, res) => {
  try {
    const [adminRows] = await db.query(
      `SELECT id, name, email FROM users ORDER BY id ASC LIMIT 1`
    );

    const [mobileRows] = await db.query(
      `SELECT id, app_username FROM mobile_app_settings WHERE id = 1 LIMIT 1`
    );

    const [sessionRows] = await db.query(
      `
      SELECT 
        id,
        device_name,
        device_type,
        device_id,
        DATE_FORMAT(last_active, '%d %b %Y, %h:%i %p') AS last_active
      FROM mobile_app_sessions
      WHERE status = 'active'
      ORDER BY last_active DESC
      `
    );

    res.json({
      success: true,
      data: {
        admin: adminRows[0] || {
          id: 1,
          name: "Admin User",
          email: "admin@godigital.com",
        },
        mobile_app: mobileRows[0] || {
          id: 1,
          app_username: "client@godigital.com",
        },
        mobile_sessions: sessionRows,
      },
    });
  } catch (error) {
    console.error("Get Settings Error:", error);

    res.status(500).json({
      success: false,
      message: error.message || "Server error",
    });
  }
};

/* UPDATE ADMIN PROFILE */
exports.updateAdminProfile = async (req, res) => {
  try {
    const { name, email, password } = req.body;

    if (!name || !email) {
      return res.status(400).json({
        success: false,
        message: "Name and email are required",
      });
    }

    const [adminRows] = await db.query(
      `SELECT id FROM users ORDER BY id ASC LIMIT 1`
    );

    if (adminRows.length === 0) {
      return res.status(404).json({
        success: false,
        message: "Admin user not found",
      });
    }

    const adminId = adminRows[0].id;

    if (password && password.trim() !== "") {
      const hashedPassword = await bcrypt.hash(password, 10);

      await db.query(
        `UPDATE users SET name = ?, email = ?, password = ? WHERE id = ?`,
        [name, email, hashedPassword, adminId]
      );
    } else {
      await db.query(
        `UPDATE users SET name = ?, email = ? WHERE id = ?`,
        [name, email, adminId]
      );
    }

    res.json({
      success: true,
      message: "Admin profile updated successfully",
    });
  } catch (error) {
    console.error("Update Admin Profile Error:", error);

    res.status(500).json({
      success: false,
      message: error.message || "Server error",
    });
  }
};

/* UPDATE MOBILE APP LOGIN */
exports.updateMobileCredentials = async (req, res) => {
  try {
    const { app_username, app_password } = req.body;

    if (!app_username) {
      return res.status(400).json({
        success: false,
        message: "Mobile app username is required",
      });
    }

    if (app_password && app_password.trim() !== "") {
      const hashedPassword = await bcrypt.hash(app_password, 10);

      await db.query(
        `
        INSERT INTO mobile_app_settings (id, app_username, app_password_hash)
        VALUES (1, ?, ?)
        ON DUPLICATE KEY UPDATE
        app_username = VALUES(app_username),
        app_password_hash = VALUES(app_password_hash)
        `,
        [app_username, hashedPassword]
      );
    } else {
      await db.query(
        `
        INSERT INTO mobile_app_settings (id, app_username)
        VALUES (1, ?)
        ON DUPLICATE KEY UPDATE
        app_username = VALUES(app_username)
        `,
        [app_username]
      );
    }

    res.json({
      success: true,
      message: "Mobile app login updated successfully",
    });
  } catch (error) {
    console.error("Update Mobile Login Error:", error);

    res.status(500).json({
      success: false,
      message: error.message || "Server error",
    });
  }
};

/* GET MOBILE APP DEVICES */
exports.getMobileSessions = async (req, res) => {
  try {
    const [rows] = await db.query(
      `
      SELECT 
        id,
        device_name,
        device_type,
        device_id,
        DATE_FORMAT(last_active, '%d %b %Y, %h:%i %p') AS last_active
      FROM mobile_app_sessions
      WHERE status = 'active'
      ORDER BY last_active DESC
      `
    );

    res.json({
      success: true,
      data: rows,
    });
  } catch (error) {
    console.error("Get Mobile Sessions Error:", error);

    res.status(500).json({
      success: false,
      message: error.message || "Server error",
    });
  }
};

/* REMOVE ONE MOBILE DEVICE */
exports.removeMobileSession = async (req, res) => {
  try {
    const { id } = req.params;

    await db.query(
      `UPDATE mobile_app_sessions SET status = 'removed' WHERE id = ?`,
      [id]
    );

    res.json({
      success: true,
      message: "Mobile device removed successfully",
    });
  } catch (error) {
    console.error("Remove Mobile Session Error:", error);

    res.status(500).json({
      success: false,
      message: error.message || "Server error",
    });
  }
};

/* REMOVE ALL MOBILE DEVICES */
exports.removeAllMobileSessions = async (req, res) => {
  try {
    await db.query(
      `UPDATE mobile_app_sessions SET status = 'removed' WHERE status = 'active'`
    );

    res.json({
      success: true,
      message: "All mobile devices removed successfully",
    });
  } catch (error) {
    console.error("Remove All Mobile Sessions Error:", error);

    res.status(500).json({
      success: false,
      message: error.message || "Server error",
    });
  }
};