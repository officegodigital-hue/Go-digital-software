const { pool } = require('../config/db');

/**
 * Checks if a user has access to a specific business.
 * Admins / main admins have full access. Others are verified via database tables.
 */
async function canAccessBusiness(user, businessId) {
  if (!user) return false;

  const userType = String(user.type || user.role || '').toLowerCase();
  const isMainAdmin = user.is_main_admin === true || user.is_main_admin === 1 || user.is_main_admin === '1';

  // Admins have access to all businesses
  if (userType === 'admin' || isMainAdmin) {
    return true;
  }

  try {
    // Check if the user is linked to the business in user_businesses table
    const [membership] = await pool.query(
      'SELECT 1 FROM user_businesses WHERE user_id = ? AND business_id = ? LIMIT 1',
      [user.id, businessId]
    );
    if (membership && membership.length > 0) {
      return true;
    }

    // Check if the user owns the business directly in the businesses table
    const [ownership] = await pool.query(
      'SELECT 1 FROM businesses WHERE id = ? AND (owner_id = ? OR user_id = ?) LIMIT 1',
      [businessId, user.id, user.id]
    );
    if (ownership && ownership.length > 0) {
      return true;
    }
  } catch (error) {
    console.error('Error verifying business access:', error);
  }

  return false;
}

/**
 * Express middleware to enforce business access.
 */
async function requireBusinessAccess(req, res, next) {
  const businessId = Number.parseInt(req.body?.businessId || req.params?.businessId, 10);
  
  if (!Number.isSafeInteger(businessId) || businessId < 1) {
    return res.status(400).json({ success: false, message: 'A valid business ID is required.' });
  }

  const allowed = await canAccessBusiness(req.user, businessId);
  if (!allowed) {
    return res.status(403).json({ success: false, message: 'You do not have access to this business.' });
  }

  req.businessId = businessId;
  next();
}

module.exports = {
  canAccessBusiness,
  requireBusinessAccess,
};
