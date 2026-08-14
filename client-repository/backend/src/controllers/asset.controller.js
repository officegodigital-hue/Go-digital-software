const db = require("../config/db");

function bodyValue(body, names, defaultValue = "") {
  for (const name of names) {
    if (body[name] !== undefined && body[name] !== null) {
      return body[name];
    }
  }

  return defaultValue;
}

function cleanValue(value) {
  if (value === undefined || value === null) return "";
  return String(value).trim();
}

function normalizeFilePath(filename) {
  if (!filename) return "";
  return `uploads/${filename}`;
}

function normalizeDeliverableType(type) {
  const value = cleanValue(type).toLowerCase().replace(/-/g, "_").replace(/\s+/g, "_");

  switch (value) {
    case "poster":
    case "poster_design":
      return "poster_design";

    case "video":
    case "videos":
      return "video";

    case "landing_page":
      return "landing_page";

    case "website":
    case "websites":
      return "website";

    case "other_link":
      return "other_link";

    case "photo":
    case "photos":
    case "image":
    case "images":
      return "photos";

    case "portfolio":
      return "portfolio";

    case "package":
    case "packages":
      return "packages";

    case "mobile_application":
    case "mobile_app":
      return "mobile_application";

    case "website_application":
    case "web_application":
    case "website_app":
    case "web_app":
      return "website_application";

    default:
      return value;
  }
}

function defaultTitleForType(type) {
  switch (normalizeDeliverableType(type)) {
    case "poster_design":
      return "Poster Design";
    case "video":
      return "Video";
    case "landing_page":
      return "Landing Page";
    case "website":
      return "Website";
    case "other_link":
      return "Other Link";
    case "photos":
      return "Photos";
    case "portfolio":
      return "APK File Upload";
    case "packages":
      return "Packages";
    case "mobile_application":
      return "Mobile Application";
    case "website_application":
      return "Website Application";
    default:
      return cleanValue(type).replace(/_/g, " ") || "Asset";
  }
}

function getUploadedFiles(req, fieldName) {
  if (!req.files) return [];
  return req.files[fieldName] || [];
}

function getFileFieldForType(type) {
  return `${normalizeDeliverableType(type)}_file`;
}

function buildFileQueues(req) {
  const queues = {};

  if (!req.files) return queues;

  for (const [fieldName, files] of Object.entries(req.files)) {
    const type = fieldName.replace(/_file$/, "");
    const normalizedType = normalizeDeliverableType(type);

    if (!queues[normalizedType]) {
      queues[normalizedType] = [];
    }

    queues[normalizedType].push(...files);
  }

  return queues;
}

function takeFileForType(fileQueues, type) {
  const normalizedType = normalizeDeliverableType(type);
  const queue = fileQueues[normalizedType] || [];

  if (queue.length === 0) return null;

  return queue.shift();
}

async function getCategoryIdFromRequest(body) {
  const rawCategoryId = bodyValue(body, ["category_id", "categoryId"], "");

  if (rawCategoryId) {
    return Number(rawCategoryId);
  }

  const categorySlug = cleanValue(
    bodyValue(body, ["category", "category_slug", "categorySlug"], "")
  );

  if (categorySlug) {
    const [rows] = await db.query(
      `SELECT id FROM categories WHERE slug = ? LIMIT 1`,
      [categorySlug]
    );

    if (rows.length > 0) {
      return rows[0].id;
    }
  }

  return 1;
}

function getDeliverableConfig() {
  return [
    {
      type: "poster_design",
      title: "Poster Design",
      fileField: "poster_design_file",
      linkFields: ["poster_design_link", "posterDesignLink"],
      descriptionFields: ["poster_design_description", "posterDesignDescription"],
    },
    {
      type: "video",
      title: "Video",
      fileField: "video_file",
      linkFields: ["video_link", "videoLink"],
      descriptionFields: ["video_description", "videoDescription"],
    },
    {
      type: "landing_page",
      title: "Landing Page",
      fileField: "landing_page_file",
      linkFields: ["landing_page_link", "landingPageLink"],
      descriptionFields: ["landing_page_description", "landingPageDescription"],
    },
    {
      type: "website",
      title: "Website",
      fileField: "website_file",
      linkFields: ["website_link", "websiteLink"],
      descriptionFields: ["website_description", "websiteDescription"],
    },
    {
      type: "other_link",
      title: "Other Link",
      fileField: "other_link_file",
      linkFields: ["other_link", "otherLink", "other_link_link"],
      descriptionFields: ["other_link_description", "otherLinkDescription"],
    },
    {
      type: "photos",
      title: "Photos",
      fileField: "photos_file",
      linkFields: ["photos_link", "photosLink"],
      descriptionFields: ["photos_description", "photosDescription"],
    },
    {
      type: "portfolio",
      title: "Portfolio",
      fileField: "portfolio_file",
      linkFields: ["portfolio_link", "portfolioLink"],
      descriptionFields: ["portfolio_description", "portfolioDescription"],
    },
    {
      type: "packages",
      title: "Packages",
      fileField: "packages_file",
      linkFields: ["packages_link", "packagesLink"],
      descriptionFields: ["packages_description", "packagesDescription"],
    },
    {
      type: "mobile_application",
      title: "Mobile Application",
      fileField: "mobile_application_file",
      linkFields: ["mobile_application_link", "mobileApplicationLink"],
      descriptionFields: ["mobile_application_description", "mobileApplicationDescription"],
      credentialFields: {
        adminUrl: ["mobile_application_admin_url", "mobileApplicationAdminUrl"],
        userEmail: ["mobile_application_user_email", "mobileApplicationUserEmail"],
        password: ["mobile_application_password", "mobileApplicationPassword"],
      },
    },
    {
      type: "website_application",
      title: "Website Application",
      fileField: "website_application_file",
      linkFields: ["website_application_link", "websiteApplicationLink", "web_application_link"],
      descriptionFields: ["website_application_description", "websiteApplicationDescription", "web_application_description"],
      credentialFields: {
        adminUrl: ["website_application_admin_url", "websiteApplicationAdminUrl", "web_application_admin_url"],
        userEmail: ["website_application_user_email", "websiteApplicationUserEmail", "web_application_user_email"],
        password: ["website_application_password", "websiteApplicationPassword", "web_application_password"],
      },
    },
  ];
}

function parseJsonArray(value) {
  if (!value) return [];

  try {
    const parsed = typeof value === "string" ? JSON.parse(value) : value;
    return Array.isArray(parsed) ? parsed : [];
  } catch (error) {
    return [];
  }
}

function parseDeletedIds(value) {
  const raw = parseJsonArray(value);

  return raw
    .map((id) => Number(id))
    .filter((id) => Number.isInteger(id) && id > 0);
}

function normalizeDeliverableItem(rawItem) {
  const item = rawItem || {};
  const type = normalizeDeliverableType(
    item.deliverable_type || item.type || item.deliverableType || item.key
  );

  const title = cleanValue(item.title) || defaultTitleForType(type);

  return {
    id: Number(item.id || item.deliverable_id || 0) || 0,
    type,
    title,
    link: cleanValue(item.google_drive_link || item.link || item.googleDriveLink || item.url),
    description: cleanValue(item.description || item.desc || item.details),
    adminPanelUrl: cleanValue(item.admin_panel_url || item.adminPanelUrl || item.admin_url || item.adminUrl),
    userEmail: cleanValue(item.user_email || item.userEmail || item.email),
    passwordText: cleanValue(item.password_text || item.passwordText || item.password),
    fileCount: Number(item.file_count || item.fileCount || 0) || 0,
  };
}

function buildDeliverablesFromBody(body) {
  const jsonItems = parseJsonArray(body.deliverables);

  if (jsonItems.length > 0) {
    return jsonItems.map(normalizeDeliverableItem).filter((item) => item.type);
  }

  const configs = getDeliverableConfig();
  const items = [];

  for (const config of configs) {
    const link = cleanValue(bodyValue(body, config.linkFields, ""));
    const description = cleanValue(bodyValue(body, config.descriptionFields, ""));
    const adminPanelUrl = config.credentialFields
      ? cleanValue(bodyValue(body, config.credentialFields.adminUrl, ""))
      : "";
    const userEmail = config.credentialFields
      ? cleanValue(bodyValue(body, config.credentialFields.userEmail, ""))
      : "";
    const passwordText = config.credentialFields
      ? cleanValue(bodyValue(body, config.credentialFields.password, ""))
      : "";

    if (link || description || adminPanelUrl || userEmail || passwordText) {
      items.push({
        id: 0,
        type: config.type,
        title: config.title,
        link,
        description,
        adminPanelUrl,
        userEmail,
        passwordText,
      });
    }
  }

  return items;
}

function itemHasData(item, file) {
  return Boolean(
    item.link ||
      item.description ||
      item.adminPanelUrl ||
      item.userEmail ||
      item.passwordText ||
      file
  );
}

function itemForFile(item, file) {
  const description = item.description || "";

  return {
    ...item,
    description:
      file && (!description || description.startsWith("Selected files:"))
        ? `Selected file: ${file.originalname}`
        : description,
  };
}

function takeFilesForItem(fileQueues, item) {
  const normalizedType = normalizeDeliverableType(item.type);
  const queue = fileQueues[normalizedType] || [];

  if (queue.length === 0) return [];

  if (item.fileCount && item.fileCount > 0) {
    return queue.splice(0, item.fileCount);
  }

  // Asset Upload sends one JSON deliverable with multiple files for these
  // sections. If fileCount is missing, save all queued files for that type.
  if (
    item.id === 0 &&
    ["photos", "packages", "portfolio"].includes(normalizedType)
  ) {
    return queue.splice(0, queue.length);
  }

  return [queue.shift()];
}

function fileValues(file) {
  if (!file) {
    return {
      filePath: null,
      fileName: null,
      mimeType: null,
    };
  }

  return {
    filePath: normalizeFilePath(file.filename),
    fileName: file.originalname,
    mimeType: file.mimetype,
  };
}

async function insertDeliverable({
  assetId,
  clientId,
  categoryId,
  item,
  file,
}) {
  const { filePath, fileName, mimeType } = fileValues(file);
  const finalTitle = fileName ? `${item.title} - ${fileName}` : item.title;

  const [result] = await db.query(
    `
    INSERT INTO deliverables
    (
      asset_id,
      client_id,
      category_id,
      deliverable_type,
      title,
      google_drive_link,
      description,
      file_path,
      file_name,
      mime_type,
      status
    )
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'uploaded')
    `,
    [
      assetId,
      clientId,
      categoryId,
      item.type,
      finalTitle,
      item.link || "",
      item.description || "",
      filePath,
      fileName,
      mimeType,
    ]
  );

  return result.insertId;
}

async function updateDeliverable({
  deliverableId,
  clientId,
  item,
  file,
}) {
  if (file) {
    const { filePath, fileName, mimeType } = fileValues(file);
    const finalTitle = fileName ? `${item.title} - ${fileName}` : item.title;

    await db.query(
      `
      UPDATE deliverables
      SET
        deliverable_type = ?,
        title = ?,
        google_drive_link = ?,
        description = ?,
        file_path = ?,
        file_name = ?,
        mime_type = ?,
        status = 'uploaded'
      WHERE id = ? AND client_id = ?
      `,
      [
        item.type,
        finalTitle,
        item.link || "",
        item.description || "",
        filePath,
        fileName,
        mimeType,
        deliverableId,
        clientId,
      ]
    );
  } else {
    await db.query(
      `
      UPDATE deliverables
      SET
        deliverable_type = ?,
        title = ?,
        google_drive_link = ?,
        description = ?,
        status = 'uploaded'
      WHERE id = ? AND client_id = ?
      `,
      [
        item.type,
        item.title,
        item.link || "",
        item.description || "",
        deliverableId,
        clientId,
      ]
    );
  }
}

async function upsertCredentials(deliverableId, item) {
  await db.query(`DELETE FROM app_credentials WHERE deliverable_id = ?`, [
    deliverableId,
  ]);

  if (!item.adminPanelUrl && !item.userEmail && !item.passwordText) return;

  await db.query(
    `
    INSERT INTO app_credentials
    (
      deliverable_id,
      admin_panel_url,
      user_email,
      password_text
    )
    VALUES (?, ?, ?, ?)
    `,
    [deliverableId, item.adminPanelUrl, item.userEmail, item.passwordText]
  );
}

async function ensureAsset(clientId, body) {
  const [assetRows] = await db.query(
    `
    SELECT id, category_id
    FROM assets
    WHERE client_id = ?
    ORDER BY id DESC
    LIMIT 1
    `,
    [clientId]
  );

  if (assetRows.length > 0) {
    return {
      assetId: assetRows[0].id,
      categoryId: assetRows[0].category_id,
    };
  }

  const categoryId = await getCategoryIdFromRequest(body);

  const [assetResult] = await db.query(
    `
    INSERT INTO assets
    (
      client_id,
      category_id,
      status
    )
    VALUES (?, ?, 'uploaded')
    `,
    [clientId, categoryId]
  );

  return {
    assetId: assetResult.insertId,
    categoryId,
  };
}

function buildFileUrl(req, filePath) {
  if (!filePath) return "";
  return `${req.protocol}://${req.get("host")}/${filePath}`;
}

/* CREATE ASSET */
exports.createAsset = async (req, res) => {
  try {
    const body = req.body;

    const clientName = cleanValue(
      bodyValue(body, ["client_name", "clientName", "company_name", "companyName"])
    );

    const shortName = cleanValue(
      bodyValue(body, ["short_name", "shortName"], "")
    );

    if (!clientName) {
      return res.status(400).json({
        success: false,
        message: "Client name is required",
      });
    }

    const categoryId = await getCategoryIdFromRequest(body);

    const [clientResult] = await db.query(
      `
      INSERT INTO clients
      (
        client_name,
        short_name,
        category_id,
        status
      )
      VALUES (?, ?, ?, 'active')
      `,
      [clientName, shortName || clientName, categoryId]
    );

    const clientId = clientResult.insertId;

    const [assetResult] = await db.query(
      `
      INSERT INTO assets
      (
        client_id,
        category_id,
        status
      )
      VALUES (?, ?, 'uploaded')
      `,
      [clientId, categoryId]
    );

    const assetId = assetResult.insertId;
    const deliverables = buildDeliverablesFromBody(body);
    const fileQueues = buildFileQueues(req);

    let insertedCount = 0;

    if (deliverables.length > 0) {
      for (const item of deliverables) {
        const files = takeFilesForItem(fileQueues, item);

        if (files.length > 0) {
          for (const file of files) {
            const fileItem = itemForFile(item, file);

            if (!itemHasData(fileItem, file)) continue;

            const deliverableId = await insertDeliverable({
              assetId,
              clientId,
              categoryId,
              item: fileItem,
              file,
            });

            await upsertCredentials(deliverableId, fileItem);
            insertedCount++;
          }

          continue;
        }

        if (!itemHasData(item, null)) continue;

        const deliverableId = await insertDeliverable({
          assetId,
          clientId,
          categoryId,
          item,
          file: null,
        });

        await upsertCredentials(deliverableId, item);
        insertedCount++;
      }
    } else {
      const configs = getDeliverableConfig();

      for (const config of configs) {
        const link = cleanValue(bodyValue(body, config.linkFields, ""));
        const description = cleanValue(bodyValue(body, config.descriptionFields, ""));
        const files = getUploadedFiles(req, config.fileField);
        const adminPanelUrl = config.credentialFields
          ? cleanValue(bodyValue(body, config.credentialFields.adminUrl, ""))
          : "";
        const userEmail = config.credentialFields
          ? cleanValue(bodyValue(body, config.credentialFields.userEmail, ""))
          : "";
        const passwordText = config.credentialFields
          ? cleanValue(bodyValue(body, config.credentialFields.password, ""))
          : "";

        const baseItem = {
          id: 0,
          type: config.type,
          title: config.title,
          link,
          description,
          adminPanelUrl,
          userEmail,
          passwordText,
        };

        if (files.length > 0) {
          for (const file of files) {
            const deliverableId = await insertDeliverable({
              assetId,
              clientId,
              categoryId,
              item: baseItem,
              file,
            });

            await upsertCredentials(deliverableId, baseItem);
            insertedCount++;
          }
        } else if (itemHasData(baseItem, null)) {
          const deliverableId = await insertDeliverable({
            assetId,
            clientId,
            categoryId,
            item: baseItem,
            file: null,
          });

          await upsertCredentials(deliverableId, baseItem);
          insertedCount++;
        }
      }
    }

    res.json({
      success: true,
      message: "Asset uploaded successfully",
      data: {
        client_id: clientId,
        asset_id: assetId,
        deliverable_count: insertedCount,
      },
    });
  } catch (error) {
    console.error("Create Asset Error:", error);

    res.status(500).json({
      success: false,
      message: error.message || "Server error",
    });
  }
};

/* GET REPOSITORY */
exports.getRepository = async (req, res) => {
  try {
    const [rows] = await db.query(
      `
      SELECT
        c.id AS client_id,
        c.client_name,
        c.short_name,
        c.status,
        COUNT(d.id) AS deliverable_count,
        DATE_FORMAT(MAX(d.updated_at), '%d %b %Y, %h:%i %p') AS last_modified
      FROM clients c
      LEFT JOIN deliverables d ON d.client_id = c.id
      WHERE c.status = 'active'
      GROUP BY c.id, c.client_name, c.short_name, c.status
      ORDER BY c.id DESC
      `
    );

    res.json({
      success: true,
      data: rows,
    });
  } catch (error) {
    console.error("Get Repository Error:", error);

    res.status(500).json({
      success: false,
      message: error.message || "Server error",
    });
  }
};

/* GET CLIENTS */
exports.getRepositoryClients = async (req, res) => {
  try {
    const [rows] = await db.query(
      `
      SELECT
        id,
        client_name,
        short_name,
        category_id,
        status
      FROM clients
      WHERE status = 'active'
      ORDER BY client_name ASC
      `
    );

    res.json({
      success: true,
      data: rows,
    });
  } catch (error) {
    console.error("Get Clients Error:", error);

    res.status(500).json({
      success: false,
      message: error.message || "Server error",
    });
  }
};

/* GET CLIENT ASSET DETAILS */
exports.getClientAssetDetails = async (req, res) => {
  try {
    const { clientId } = req.params;

    const [clientRows] = await db.query(
      `
      SELECT
        id AS client_id,
        client_name,
        short_name,
        category_id,
        status
      FROM clients
      WHERE id = ? AND status = 'active'
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

    const [deliverableRows] = await db.query(
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
      LEFT JOIN app_credentials ac ON ac.deliverable_id = d.id
      WHERE d.client_id = ?
      AND d.status = 'uploaded'
      ORDER BY d.id DESC
      `,
      [clientId]
    );

    const deliverables = deliverableRows.map((item) => ({
      ...item,
      file_url: buildFileUrl(req, item.file_path),
    }));

    res.json({
      success: true,
      data: {
        client: clientRows[0],
        deliverables,
      },
    });
  } catch (error) {
    console.error("Get Client Details Error:", error);

    res.status(500).json({
      success: false,
      message: error.message || "Server error",
    });
  }
};

/* UPDATE CLIENT ASSET DETAILS */
exports.updateClientAssetDetails = async (req, res) => {
  try {
    const { clientId } = req.params;
    const body = req.body;

    const clientName = cleanValue(
      bodyValue(body, ["client_name", "clientName", "company_name", "companyName"])
    );

    const shortName = cleanValue(
      bodyValue(body, ["short_name", "shortName"], "")
    );

    const [clientCheck] = await db.query(
      `SELECT id FROM clients WHERE id = ? AND status = 'active' LIMIT 1`,
      [clientId]
    );

    if (clientCheck.length === 0) {
      return res.status(404).json({
        success: false,
        message: "Client not found",
      });
    }

    if (clientName) {
      await db.query(
        `
        UPDATE clients
        SET client_name = ?, short_name = ?
        WHERE id = ?
        `,
        [clientName, shortName || clientName, clientId]
      );
    }

    const { assetId, categoryId } = await ensureAsset(clientId, body);

    const deletedDeliverableIds = parseDeletedIds(body.deleted_deliverable_ids);

    if (deletedDeliverableIds.length > 0) {
      await db.query(
        `DELETE FROM app_credentials WHERE deliverable_id IN (?)`,
        [deletedDeliverableIds]
      );

      await db.query(
        `DELETE FROM deliverables WHERE id IN (?) AND client_id = ?`,
        [deletedDeliverableIds, clientId]
      );
    }

    const deliverables = buildDeliverablesFromBody(body);
    const fileQueues = buildFileQueues(req);

    let changedCount = 0;

    if (deliverables.length > 0) {
      for (const item of deliverables) {
        const files = takeFilesForItem(fileQueues, item);

        if (files.length > 0) {
          for (let index = 0; index < files.length; index++) {
            const file = files[index];
            const fileItem = itemForFile(item, file);

            if (!itemHasData(fileItem, file)) continue;

            let deliverableId = index === 0 ? item.id : 0;

            if (deliverableId > 0) {
              const [existingRows] = await db.query(
                `SELECT id FROM deliverables WHERE id = ? AND client_id = ? LIMIT 1`,
                [deliverableId, clientId]
              );

              if (existingRows.length > 0) {
                await updateDeliverable({
                  deliverableId,
                  clientId,
                  item: fileItem,
                  file,
                });
              } else {
                deliverableId = await insertDeliverable({
                  assetId,
                  clientId,
                  categoryId,
                  item: fileItem,
                  file,
                });
              }
            } else {
              deliverableId = await insertDeliverable({
                assetId,
                clientId,
                categoryId,
                item: fileItem,
                file,
              });
            }

            await upsertCredentials(deliverableId, fileItem);
            changedCount++;
          }

          continue;
        }

        if (!itemHasData(item, null)) continue;

        let deliverableId = item.id;

        if (deliverableId > 0) {
          const [existingRows] = await db.query(
            `SELECT id FROM deliverables WHERE id = ? AND client_id = ? LIMIT 1`,
            [deliverableId, clientId]
          );

          if (existingRows.length > 0) {
            await updateDeliverable({
              deliverableId,
              clientId,
              item,
              file: null,
            });
          } else {
            deliverableId = await insertDeliverable({
              assetId,
              clientId,
              categoryId,
              item,
              file: null,
            });
          }
        } else {
          deliverableId = await insertDeliverable({
            assetId,
            clientId,
            categoryId,
            item,
            file: null,
          });
        }

        await upsertCredentials(deliverableId, item);
        changedCount++;
      }
    } else {
      const configs = getDeliverableConfig();

      for (const config of configs) {
        const link = cleanValue(bodyValue(body, config.linkFields, ""));
        const description = cleanValue(bodyValue(body, config.descriptionFields, ""));
        const files = getUploadedFiles(req, config.fileField);
        const adminPanelUrl = config.credentialFields
          ? cleanValue(bodyValue(body, config.credentialFields.adminUrl, ""))
          : "";
        const userEmail = config.credentialFields
          ? cleanValue(bodyValue(body, config.credentialFields.userEmail, ""))
          : "";
        const passwordText = config.credentialFields
          ? cleanValue(bodyValue(body, config.credentialFields.password, ""))
          : "";

        const baseItem = {
          id: 0,
          type: config.type,
          title: config.title,
          link,
          description,
          adminPanelUrl,
          userEmail,
          passwordText,
        };

        if (files.length > 0) {
          for (const file of files) {
            const deliverableId = await insertDeliverable({
              assetId,
              clientId,
              categoryId,
              item: baseItem,
              file,
            });

            await upsertCredentials(deliverableId, baseItem);
            changedCount++;
          }
        } else if (itemHasData(baseItem, null)) {
          const deliverableId = await insertDeliverable({
            assetId,
            clientId,
            categoryId,
            item: baseItem,
            file: null,
          });

          await upsertCredentials(deliverableId, baseItem);
          changedCount++;
        }
      }
    }

    res.json({
      success: true,
      message: "Client asset updated successfully",
      data: {
        changed_count: changedCount,
      },
    });
  } catch (error) {
    console.error("Update Client Asset Error:", error);

    res.status(500).json({
      success: false,
      message: error.message || "Server error",
    });
  }
};

/* DELETE CLIENT */
exports.deleteClientAssetDetails = async (req, res) => {
  try {
    const { clientId } = req.params;

    const [deliverables] = await db.query(
      `SELECT id FROM deliverables WHERE client_id = ?`,
      [clientId]
    );

    const deliverableIds = deliverables.map((item) => item.id);

    if (deliverableIds.length > 0) {
      await db.query(`DELETE FROM app_credentials WHERE deliverable_id IN (?)`, [
        deliverableIds,
      ]);

      await db.query(`DELETE FROM deliverables WHERE client_id = ?`, [clientId]);
    }

    await db.query(`DELETE FROM assets WHERE client_id = ?`, [clientId]);

    await db.query(`UPDATE clients SET status = 'inactive' WHERE id = ?`, [
      clientId,
    ]);

    res.json({
      success: true,
      message: "Client deleted successfully",
    });
  } catch (error) {
    console.error("Delete Client Error:", error);

    res.status(500).json({
      success: false,
      message: error.message || "Server error",
    });
  }
};

/* DELETE DELIVERABLE */
exports.deleteDeliverable = async (req, res) => {
  try {
    const { id } = req.params;

    await db.query(`DELETE FROM app_credentials WHERE deliverable_id = ?`, [id]);
    await db.query(`DELETE FROM deliverables WHERE id = ?`, [id]);

    res.json({
      success: true,
      message: "Deliverable deleted successfully",
    });
  } catch (error) {
    console.error("Delete Deliverable Error:", error);

    res.status(500).json({
      success: false,
      message: error.message || "Server error",
    });
  }
};
