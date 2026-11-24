const jwt = require('jsonwebtoken');

/**
 * Middleware to authenticate JWT tokens sent in the Authorization header.
 * Expects format: Bearer <token>
 */
function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({
      success: false,
      message: 'Access token required for authentication.',
    });
  }

  // Must match the secret used to SIGN tokens in routes/auth.js. When
  // process.env.JWT_SECRET is unset, both sides must fall back to the SAME
  // default, otherwise every token this middleware checks fails verification
  // and returns 403 "Invalid or expired access token."
  jwt.verify(token, process.env.JWT_SECRET || 'change-this-in-production-to-random-key', (err, user) => {
    if (err) {
      return res.status(403).json({
        success: false,
        message: 'Invalid or expired access token.',
      });
    }

    // Attach user payload to request object
    req.user = user;
    next();
  });
}

module.exports = {
  authenticateToken,
};