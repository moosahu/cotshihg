const pool = require('../config/database');
const { successResponse, errorResponse } = require('../utils/response.utils');

exports.getProfile = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT u.*, t.id as therapist_profile_id, t.bio, t.specializations, t.rating,
              t.session_price_video, t.session_price_voice, t.session_price_chat,
              t.is_available_instant, t.is_approved, t.years_experience
       FROM users u
       LEFT JOIN therapists t ON t.user_id = u.id
       WHERE u.id = $1`,
      [req.user.id]
    );
    successResponse(res, result.rows[0]);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

exports.updateProfile = async (req, res) => {
  try {
    const { name, email, gender, date_of_birth, avatar_url } = req.body;
    const result = await pool.query(
      `UPDATE users SET name=$1, email=$2, gender=$3, date_of_birth=$4, avatar_url=$5, updated_at=NOW()
       WHERE id=$6 RETURNING *`,
      [name, email, gender, date_of_birth, avatar_url, req.user.id]
    );
    successResponse(res, result.rows[0], 'Profile updated');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

exports.updateFCMToken = async (req, res) => {
  try {
    const { fcm_token } = req.body;
    await pool.query('UPDATE users SET fcm_token=$1 WHERE id=$2', [fcm_token, req.user.id]);
    successResponse(res, null, 'FCM token updated');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

exports.getNotifications = async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM notifications WHERE user_id=$1 ORDER BY created_at DESC LIMIT 50',
      [req.user.id]
    );
    successResponse(res, result.rows);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

exports.markNotificationRead = async (req, res) => {
  try {
    await pool.query(
      'UPDATE notifications SET is_read=true WHERE id=$1 AND user_id=$2',
      [req.params.id, req.user.id]
    );
    successResponse(res, null, 'Notification marked as read');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

exports.markAllNotificationsRead = async (req, res) => {
  try {
    await pool.query(
      'UPDATE notifications SET is_read=true WHERE user_id=$1 AND is_read=false',
      [req.user.id]
    );
    successResponse(res, null, 'All notifications marked as read');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};
