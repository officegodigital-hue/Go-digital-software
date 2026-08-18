const {
  getProfileImageRelativeUrl,
  deleteUploadedProfileImage,
} = require(
  '../middlewares/profileImageUpload.middleware',
);

function createHttpError(
  statusCode,
  message,
) {
  const error = new Error(message);

  error.statusCode = statusCode;
  error.status = statusCode;

  return error;
}

/**
 * Get the public backend URL.
 *
 * Local example:
 * http://localhost:3000
 *
 * Production can be configured using:
 * PUBLIC_BASE_URL=https://api.example.com
 */
function getPublicBaseUrl(req) {
  const configuredBaseUrl =
    String(
      process.env.PUBLIC_BASE_URL || '',
    ).trim();

  if (configuredBaseUrl !== '') {
    return configuredBaseUrl.replace(
      /\/+$/,
      '',
    );
  }

  const protocol =
    req.protocol || 'http';

  const host =
    req.get('host') ||
    'localhost:3000';

  return `${protocol}://${host}`;
}

/**
 * POST /api/v1/admin/employees/profile-image
 *
 * Content-Type:
 * multipart/form-data
 *
 * Field name:
 * profile_image
 */
async function uploadEmployeeProfileImage(
  req,
  res,
  next,
) {
  try {
    if (!req.file) {
      throw createHttpError(
        400,
        'Select a profile image to upload.',
      );
    }

    const relativeUrl =
      getProfileImageRelativeUrl(
        req.file,
      );

    if (relativeUrl === '') {
      throw createHttpError(
        500,
        'Unable to generate the profile image URL.',
      );
    }

    const absoluteUrl =
      `${getPublicBaseUrl(req)}` +
      `${relativeUrl}`;

    return res.status(201).json({
      success: true,

      message:
        'Profile image uploaded successfully.',

      data: {
        profile_image_url:
          absoluteUrl,

        relative_url:
          relativeUrl,

        file_name:
          req.file.filename,

        original_file_name:
          req.file.originalname,

        mime_type:
          req.file.mimetype,

        file_size:
          req.file.size,
      },

      profile_image_url:
        absoluteUrl,
    });
  } catch (error) {
    /**
     * Remove the uploaded file if another
     * part of the upload process fails.
     */
    deleteUploadedProfileImage(
      req.file,
    );

    return next(error);
  }
}

module.exports = {
  uploadEmployeeProfileImage,
};  