const bcrypt = require("bcryptjs");
const db = require("../config/db");

const DIGITAL_MARKETING_TYPES = [
  "poster_design",
  "video",
  "landing_page",
  "website",
  "other_link",
  "packages",
  "portfolio",
  "photos",
];

const SOFTWARE_DEVELOPMENT_TYPES = [
  "mobile_application",
  "mobile-app",
  "mobile_app",
  "website_application",
  "website-app",
  "website_app",
  "web_application",
  "web-app",
  "web_app",
];

function getTypesByCategory(category) {
  if (category === "software-development") {
    return SOFTWARE_DEVELOPMENT_TYPES;
  }

  return DIGITAL_MARKETING_TYPES;
}

function getCategoryName(category) {
  if (category === "software-development") {
    return "Software Development";
  }

  return "Digital Marketing";
}

function getCategoryId(category) {
  if (category === "software-development") {
    return 2;
  }

  return 1;
}

function normalizeFilePath(filePath) {
  if (!filePath) return "";

  return filePath.replace(/\\/g, "/").replace(/^\/+/, "");
}

function buildFileUrl(req, filePath) {
  const cleanPath = normalizeFilePath(filePath);

  if (!cleanPath) return "";

  const baseUrl = `${req.protocol}://${req.get("host")}`;

  return `${baseUrl}/${cleanPath}`;
}

/* MOBILE APP LOGIN */
exports.loginMobileApp = async (req, res) => {
  try {
    const { username, password, device_name, device_type, device_id } = req.body;

    if (!username || !password) {
      return res.status(400).json({
        success: false,
        message: "Username and password are required",
      });
    }

    const [rows] = await db.query(
      `
      SELECT app_username, app_password_hash
      FROM mobile_app_settings
      WHERE id = 1
      LIMIT 1
      `
    );

    if (rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: "Mobile app login not configured",
      });
    }

    const settings = rows[0];

    if (settings.app_username !== username) {
      return res.status(401).json({
        success: false,
        message: "Invalid username or password",
      });
    }

    if (!settings.app_password_hash) {
      return res.status(400).json({
        success: false,
        message: "Mobile app password not set. Please set it from Admin Settings.",
      });
    }

    const isPasswordValid = await bcrypt.compare(
      password,
      settings.app_password_hash
    );

    if (!isPasswordValid) {
      return res.status(401).json({
        success: false,
        message: "Invalid username or password",
      });
    }

    await db.query(
      `
      INSERT INTO mobile_app_sessions
      (device_name, device_type, device_id, status)
      VALUES (?, ?, ?, 'active')
      `,
      [
        device_name || "Mobile App",
        device_type || "Android",
        device_id || `device-${Date.now()}`,
      ]
    );

    res.json({
      success: true,
      message: "Mobile app login successful",
      data: {
        username: settings.app_username,
      },
    });
  } catch (error) {
    console.error("Mobile Login Error:", error);

    res.status(500).json({
      success: false,
      message: error.message || "Server error",
    });
  }
};

/* GET CATEGORIES */
exports.getCategories = async (req, res) => {
  try {
    res.json({
      success: true,
      data: [
        {
          id: 1,
          category_name: "Digital Marketing",
          slug: "digital-marketing",
        },
        {
          id: 2,
          category_name: "Software Development",
          slug: "software-development",
        },
      ],
    });
  } catch (error) {
    console.error("Mobile Categories Error:", error);

    res.status(500).json({
      success: false,
      message: error.message || "Server error",
    });
  }
};

/* GET CLIENT FOLDERS BY CATEGORY */
exports.getClientsByCategory = async (req, res) => {
  try {
    const { category } = req.query;

    if (!category) {
      return res.status(400).json({
        success: false,
        message: "Category slug is required",
      });
    }

    const allowedTypes = getTypesByCategory(category);
    const categoryName = getCategoryName(category);

    const [rows] = await db.query(
      `
      SELECT 
        c.id AS client_id,
        c.client_name,
        c.short_name,
        ? AS category_name,
        ? AS slug,
        COUNT(d.id) AS deliverable_count
      FROM clients c
      INNER JOIN deliverables d 
        ON d.client_id = c.id
        AND d.status = 'uploaded'
        AND d.deliverable_type IN (?)
      WHERE c.status = 'active'
      GROUP BY c.id, c.client_name, c.short_name
      ORDER BY c.client_name ASC
      `,
      [categoryName, category, allowedTypes]
    );

    res.json({
      success: true,
      data: rows,
    });
  } catch (error) {
    console.error("Mobile Clients Error:", error);

    res.status(500).json({
      success: false,
      message: error.message || "Server error",
    });
  }
};

/* GET CLIENT DELIVERABLES BY CATEGORY */
exports.getClientDeliverables = async (req, res) => {
  try {
    const { clientId } = req.params;
    const { category } = req.query;

    const finalCategory = category || "digital-marketing";
    const allowedTypes = getTypesByCategory(finalCategory);
    const categoryName = getCategoryName(finalCategory);
    const categoryId = getCategoryId(finalCategory);

    const [clientRows] = await db.query(
      `
      SELECT 
        id AS client_id,
        client_name,
        short_name
      FROM clients
      WHERE id = ?
      AND status = 'active'
      LIMIT 1
      `,
      [clientId]
    );

    if (clientRows.length === 0) {
      return res.status(404).json({
        success: false,
        message: "Client not found",
      });
    }

    const [rows] = await db.query(
      `
      SELECT
        d.id,
        d.asset_id,
        d.client_id,
        d.category_id,
        d.deliverable_type,
        d.title,
        d.google_drive_link,
        d.description,
        d.file_path,
        d.file_name,
        d.mime_type,
        d.status,
        DATE_FORMAT(d.created_at, '%d %b %Y, %h:%i %p') AS added_on,
        DATE_FORMAT(d.updated_at, '%d %b %Y, %h:%i %p') AS updated_on,
        ac.admin_panel_url,
        ac.user_email,
        ac.password_text
      FROM deliverables d
      LEFT JOIN app_credentials ac 
        ON ac.deliverable_id = d.id
      WHERE d.client_id = ?
      AND d.status = 'uploaded'
      AND d.deliverable_type IN (?)
      ORDER BY d.id DESC
      `,
      [clientId, allowedTypes]
    );

    const deliverables = rows.map((item) => {
      const fileUrl = item.file_path ? buildFileUrl(req, item.file_path) : "";
      const finalLink = item.google_drive_link || fileUrl || "";

      return {
        ...item,
        category_id: item.category_id || categoryId,
        category_name: categoryName,
        slug: finalCategory,
        google_drive_link: finalLink,
        file_url: fileUrl,
        file_name: item.file_name || "",
        mime_type: item.mime_type || "",
      };
    });

    res.json({
      success: true,
      data: {
        client: {
          ...clientRows[0],
          category_id: categoryId,
          category_name: categoryName,
          slug: finalCategory,
        },
        deliverables,
      },
    });
  } catch (error) {
    console.error("Mobile Deliverables Error:", error);

    res.status(500).json({
      success: false,
      message: error.message || "Server error",
    });
  }
};