const pool = require('../config/database');
const { successResponse, errorResponse } = require('../utils/response.utils');
const { sendPushNotification } = require('../utils/notifications.utils');
const { v4: uuidv4 } = require('uuid');
const { autoAssignOnBooking } = require('./questionnaire.controller');

exports.createBooking = async (req, res) => {
  try {
    const { therapist_id, session_type, scheduled_at, duration_minutes, notes } = req.body;

    const therapistResult = await pool.query(
      `SELECT t.*, u.fcm_token, u.name as therapist_name
       FROM therapists t JOIN users u ON u.id = t.user_id WHERE t.id=$1`,
      [therapist_id]
    );
    if (!therapistResult.rows[0]) return errorResponse(res, 'Therapist not found', 404);

    const therapist = therapistResult.rows[0];
    const priceMap = { chat: therapist.session_price_chat, voice: therapist.session_price_voice, video: therapist.session_price_video };
    const price = priceMap[session_type];

    const result = await pool.query(
      `INSERT INTO bookings (client_id, therapist_id, session_type, scheduled_at, duration_minutes, price, notes)
       VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
      [req.user.id, therapist_id, session_type, scheduled_at, duration_minutes || 60, price, notes]
    );

    // Notify therapist
    await sendPushNotification(
      therapist.fcm_token,
      'طلب جلسة جديد',
      `لديك طلب جلسة جديد من ${req.user.name}`,
      { type: 'new_booking', booking_id: result.rows[0].id }
    );

    successResponse(res, result.rows[0], 'Booking created', 201);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

exports.createInstantBooking = async (req, res) => {
  try {
    const { therapist_id, session_type } = req.body;

    const therapistResult = await pool.query(
      `SELECT t.*, u.fcm_token FROM therapists t JOIN users u ON u.id = t.user_id
       WHERE t.id=$1 AND t.is_available_instant=true`,
      [therapist_id]
    );
    if (!therapistResult.rows[0]) return errorResponse(res, 'Therapist not available for instant session', 400);

    const therapist = therapistResult.rows[0];
    const priceMap = { chat: therapist.session_price_chat, voice: therapist.session_price_voice, video: therapist.session_price_video };

    const result = await pool.query(
      `INSERT INTO bookings (client_id, therapist_id, session_type, scheduled_at, booking_type, price, status)
       VALUES ($1,$2,$3,NOW(),'instant',$4,'confirmed') RETURNING *`,
      [req.user.id, therapist_id, session_type, priceMap[session_type]]
    );

    const booking = result.rows[0];
    await autoAssignOnBooking(booking.id, booking.client_id, booking.therapist_id);

    successResponse(res, booking, 'Instant booking created', 201);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

exports.getMyBookings = async (req, res) => {
  try {
    const { status, role } = req.query;
    let query;
    const params = [req.user.id];

    if (req.user.role === 'therapist' || req.user.role === 'coach') {
      query = `SELECT b.*, u.name as client_name, u.avatar_url as client_avatar
               FROM bookings b JOIN users u ON u.id = b.client_id
               WHERE b.therapist_id = (SELECT id FROM therapists WHERE user_id=$1)`;
    } else {
      query = `SELECT b.*, u.name as therapist_name, u.avatar_url as therapist_avatar, t.rating
               FROM bookings b
               JOIN therapists t ON t.id = b.therapist_id
               JOIN users u ON u.id = t.user_id
               WHERE b.client_id=$1`;
    }

    if (status) {
      query += ` AND b.status=$2`;
      params.push(status);
    }

    query += ` ORDER BY b.created_at DESC`;

    const result = await pool.query(query, params);
    successResponse(res, result.rows);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

exports.getBookingById = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT b.*,
              client.name as client_name, client.avatar_url as client_avatar, client.phone as client_phone,
              therapist_user.name as therapist_name, therapist_user.avatar_url as therapist_avatar,
              t.specializations, t.rating
       FROM bookings b
       JOIN users client ON client.id = b.client_id
       JOIN therapists t ON t.id = b.therapist_id
       JOIN users therapist_user ON therapist_user.id = t.user_id
       WHERE b.id=$1 AND (b.client_id=$2 OR t.user_id=$2)`,
      [req.params.id, req.user.id]
    );

    if (!result.rows[0]) return errorResponse(res, 'Booking not found', 404);
    successResponse(res, result.rows[0]);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

exports.confirmBooking = async (req, res) => {
  try {
    const therapistResult = await pool.query('SELECT id FROM therapists WHERE user_id=$1 LIMIT 1', [req.user.id]);
    if (!therapistResult.rows[0]) return errorResponse(res, 'Therapist not found', 404);

    const result = await pool.query(
      `UPDATE bookings SET status='confirmed', updated_at=NOW()
       WHERE id=$1 AND therapist_id=$2 AND status='pending' RETURNING *`,
      [req.params.id, therapistResult.rows[0].id]
    );

    if (!result.rows[0]) return errorResponse(res, 'Booking not found or already processed', 404);

    // Auto-assign default questionnaire if coach has one set
    await autoAssignOnBooking(result.rows[0].id, result.rows[0].client_id, result.rows[0].therapist_id);

    // Notify client
    const bookingDetails = await pool.query('SELECT client_id FROM bookings WHERE id=$1', [req.params.id]);
    const clientResult = await pool.query('SELECT fcm_token, name FROM users WHERE id=$1', [bookingDetails.rows[0].client_id]);

    await sendPushNotification(
      clientResult.rows[0].fcm_token,
      'تم تأكيد موعدك',
      'تم تأكيد جلستك من قبل المعالج',
      { type: 'booking_confirmed', booking_id: req.params.id }
    );

    successResponse(res, result.rows[0], 'Booking confirmed');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

exports.cancelBooking = async (req, res) => {
  try {
    const result = await pool.query(
      `UPDATE bookings SET status='cancelled', updated_at=NOW()
       WHERE id=$1 AND (client_id=$2 OR therapist_id=(SELECT id FROM therapists WHERE user_id=$2))
       AND status IN ('pending','confirmed') RETURNING *`,
      [req.params.id, req.user.id]
    );

    if (!result.rows[0]) return errorResponse(res, 'Cannot cancel this booking', 400);
    successResponse(res, result.rows[0], 'Booking cancelled');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

exports.submitReview = async (req, res) => {
  try {
    const { rating, comment } = req.body;

    const bookingResult = await pool.query(
      'SELECT * FROM bookings WHERE id=$1 AND client_id=$2 AND status=$3',
      [req.params.id, req.user.id, 'completed']
    );

    if (!bookingResult.rows[0]) return errorResponse(res, 'Booking not found or not completed', 404);

    const booking = bookingResult.rows[0];

    await pool.query(
      'INSERT INTO reviews (booking_id, client_id, therapist_id, rating, comment) VALUES ($1,$2,$3,$4,$5)',
      [booking.id, req.user.id, booking.therapist_id, rating, comment]
    );

    // Update therapist average rating
    await pool.query(
      `UPDATE therapists SET
         rating = (SELECT AVG(rating) FROM reviews WHERE therapist_id=$1),
         total_reviews = (SELECT COUNT(*) FROM reviews WHERE therapist_id=$1)
       WHERE id=$1`,
      [booking.therapist_id]
    );

    successResponse(res, null, 'Review submitted');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};
