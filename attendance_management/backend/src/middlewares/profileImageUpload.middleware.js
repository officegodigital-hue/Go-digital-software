const fs = require('fs');
const path = require('path');
const multer = require('multer');

/**
 * Uploaded profile images will be stored here:
 *
 * backend/uploads/employee-profiles
 */
const uploadDirectory = path.resolve(
  __dirname,
  '../../uploads/employee-profiles',
);

/**
 * Create the upload directory automatically
 * when the backend starts.
 */
fs.mkdirSync(uploadDirectory, {
  recursive: true,
});

const MAX_FILE_SIZE_BYTES =
  5 * 1024 * 1024;

const allowedMimeTypes = new Set([
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/webp',
  'image/gif',
  'image/avif',
]);

const allowedExtensions = new Set([
  '.jpg',
  '.jpeg',
  '.png',
  '.webp',
  '.gif',
  '.avif',
]);

function createUploadError(
  statusCode,
  message,
) {
  const error = new Error(message);

  error.statusCode = statusCode;
  error.status = statusCode;

  return error;
}

function sanitizeFileName(
  fileName,
) {
  const extension = path
    .extname(fileName)
    .toLowerCase();

  const nameWithoutExtension = path
    .basename(
      fileName,
      extension,
    )
    .replace(
      /[^a-zA-Z0-9_-]/g,
      '-',
    )
    .replace(
      /-+/g,
      '-',
    )
    .replace(
      /^-|-$|_/g,
      '',
    )
    .slice(
      0,
      60,
    );

  return {
    extension,
    safeName:
      nameWithoutExtension ||
      'employee-profile',
  };
}

const storage = multer.diskStorage({
  destination: (
    req,
    file,
    callback,
  ) => {
    callback(
      null,
      uploadDirectory,
    );
  },

  filename: (
    req,
    file,
    callback,
  ) => {
    const {
      extension,
      safeName,
    } = sanitizeFileName(
      file.originalname,
    );

    const uniqueSuffix =
      `${Date.now()}-` +
      `${Math.round(
        Math.random() * 1000000000,
      )}`;

    const generatedFileName =
      `${safeName}-` +
      `${uniqueSuffix}` +
      `${extension}`;

    callback(
      null,
      generatedFileName,
    );
  },
});

const uploader = multer({
  storage,

  limits: {
    fileSize:
      MAX_FILE_SIZE_BYTES,

    files: 1,
  },

  fileFilter: (
    req,
    file,
    callback,
  ) => {
    const extension = path
      .extname(file.originalname)
      .toLowerCase();

    const mimeTypeAllowed =
      allowedMimeTypes.has(
        file.mimetype.toLowerCase(),
      );

    const extensionAllowed =
      allowedExtensions.has(
        extension,
      );

    if (
      !mimeTypeAllowed ||
      !extensionAllowed
    ) {
      return callback(
        createUploadError(
          400,
          'Select a valid JPG, JPEG, PNG, WEBP, GIF or AVIF image.',
        ),
      );
    }

    return callback(
      null,
      true,
    );
  },
});

/**
 * Multer middleware wrapper.
 *
 * Expected multipart field name:
 *
 * profile_image
 */
function profileImageUpload(
  req,
  res,
  next,
) {
  uploader.single(
    'profile_image',
  )(
    req,
    res,
    (error) => {
      if (!error) {
        return next();
      }

      if (
        error instanceof
        multer.MulterError
      ) {
        if (
          error.code ===
          'LIMIT_FILE_SIZE'
        ) {
          return next(
            createUploadError(
              400,
              'Profile image size cannot exceed 5 MB.',
            ),
          );
        }

        if (
          error.code ===
          'LIMIT_FILE_COUNT'
        ) {
          return next(
            createUploadError(
              400,
              'Only one profile image can be uploaded.',
            ),
          );
        }

        if (
          error.code ===
          'LIMIT_UNEXPECTED_FILE'
        ) {
          return next(
            createUploadError(
              400,
              'The upload field must be named profile_image.',
            ),
          );
        }

        return next(
          createUploadError(
            400,
            error.message ||
                'Unable to upload the profile image.',
          ),
        );
      }

      return next(error);
    },
  );
}

/**
 * Convert the uploaded filename into a URL
 * that can be stored in the employees table.
 */
function getProfileImageRelativeUrl(
  file,
) {
  if (
    !file ||
    !file.filename
  ) {
    return '';
  }

  return (
    '/uploads/employee-profiles/' +
    file.filename
  );
}

/**
 * Delete a newly uploaded image when the
 * remaining operation fails.
 */
function deleteUploadedProfileImage(
  file,
) {
  if (
    !file ||
    !file.path
  ) {
    return;
  }

  try {
    if (
      fs.existsSync(file.path)
    ) {
      fs.unlinkSync(file.path);
    }
  } catch (error) {
    console.error(
      'Unable to delete uploaded profile image:',
      error.message,
    );
  }
}

module.exports = {
  profileImageUpload,
  getProfileImageRelativeUrl,
  deleteUploadedProfileImage,
  uploadDirectory,
  MAX_FILE_SIZE_BYTES,
};