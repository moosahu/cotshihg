const pool = require('../config/database');
const { successResponse, errorResponse } = require('../utils/response.utils');

exports.getMessages = async (req, res) => {
  try {
    const { page = 1, limit = 50 } = req.query;
    const offset = (page - 1) * limit;

    // Verify access
    const booking = await pool.query(
      `SELECT * FROM bookings WHERE id=$1
       AND (client_id=$2 OR therapist_id=(SELECT id FROM therapists WHERE user_id=$2))`,
      [req.params.bookingId, req.user.id]
    );
    if (!booking.rows[0]) return errorResponse(res, 'Access denied', 403);

    const result = await pool.query(
      `SELECT m.*, u.name as sender_name, u.avatar_url as sender_avatar
       FROM messages m JOIN users u ON u.id = m.sender_id
       WHERE m.booking_id=$1 ORDER BY m.created_at DESC LIMIT $2 OFFSET $3`,
      [req.params.bookingId, limit, offset]
    );

    successResponse(res, result.rows.reverse());
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

exports.sendMessage = async (req, res) => {
  try {
    const { content, message_type = 'text', media_url } = req.body;

    const booking = await pool.query(
      `SELECT * FROM bookings WHERE id=$1
       AND (client_id=$2 OR therapist_id=(SELECT id FROM therapists WHERE user_id=$2))`,
      [req.params.bookingId, req.user.id]
    );
    if (!booking.rows[0]) return errorResponse(res, 'Access denied', 403);

    const result = await pool.query(
      `INSERT INTO messages (booking_id, sender_id, content, message_type, media_url)
       VALUES ($1,$2,$3,$4,$5) RETURNING *`,
      [req.params.bookingId, req.user.id, content, message_type, media_url]
    );

    successResponse(res, result.rows[0], 'Message sent', 201);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

exports.markAsRead = async (req, res) => {
  try {
    await pool.query(
      `UPDATE messages SET is_read=true
       WHERE booking_id=$1 AND sender_id != $2`,
      [req.params.bookingId, req.user.id]
    );
    successResponse(res, null, 'Messages marked as read');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};
