const pool = require('../config/database');
const admin = require('../config/firebase');
const { generateToken } = require('../utils/jwt.utils');
const { successResponse, errorResponse } = require('../utils/response.utils');
const bcrypt = require('bcryptjs');

exports.sendOTP = async (req, res) => {
  try {
    const { phone } = req.body;
    if (!phone) return errorResponse(res, 'Phone number required');
    // OTP is handled by Firebase on client side
    // Here we just validate the phone format
    successResponse(res, { phone }, 'OTP sent via Firebase');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

exports.verifyOTP = async (req, res) => {
  try {
    const { firebaseToken, phone } = req.body;
    if (!firebaseToken) return errorResponse(res, 'Firebase token required');

    // Verify Firebase token
    const decodedToken = await admin.auth().verifyIdToken(firebaseToken);
    const phoneFromToken = decodedToken.phone_number;

    // Check if user exists
    let userResult = await pool.query('SELECT * FROM users WHERE phone = $1', [phoneFromToken]);
    let user = userResult.rows[0];
    let isNewUser = false;

    if (!user) {
      // Create new user
      const insertResult = await pool.query(
        'INSERT INTO users (phone) VALUES ($1) RETURNING *',
        [phoneFromToken]
      );
      user = insertResult.rows[0];
      isNewUser = true;
    }

    const token = generateToken(user.id, user.role);

    successResponse(res, { token, user, isNewUser }, 'Login successful');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

exports.register = async (req, res) => {
  try {
    const { name, email, gender, date_of_birth, role } = req.body;
    const userId = req.user?.id;

    if (!userId) return errorResponse(res, 'Unauthorized', 401);

    const result = await pool.query(
      `UPDATE users SET name=$1, email=$2, gender=$3, date_of_birth=$4, role=$5, updated_at=NOW()
       WHERE id=$6 RETURNING *`,
      [name, email, gender, date_of_birth, role || 'client', userId]
    );

    successResponse(res, result.rows[0], 'Profile completed');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

exports.refreshToken = async (req, res) => {
  try {
    const { token } = req.body;
    const { verifyToken } = require('../utils/jwt.utils');
    const decoded = verifyToken(token);
    const newToken = generateToken(decoded.userId, decoded.role);
    successResponse(res, { token: newToken }, 'Token refreshed');
  } catch (err) {
    errorResponse(res, 'Invalid token', 401);
  }
};

exports.logout = async (req, res) => {
  try {
    // Clear FCM token
    await pool.query('UPDATE users SET fcm_token=NULL WHERE id=$1', [req.user.id]);
    successResponse(res, null, 'Logged out successfully');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};
