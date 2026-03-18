const pool = require('../config/database');
const { successResponse, errorResponse } = require('../utils/response.utils');
const { v4: uuidv4 } = require('uuid');
const { RtcTokenBuilder, RtcRole } = require('agora-access-token');

const AGORA_APP_ID = process.env.AGORA_APP_ID || '45772ce780f046808740a6d07c34781b';
const AGORA_APP_CERTIFICATE = process.env.AGORA_APP_CERTIFICATE || '2c729394bb4e41298e5eb26ebd00c6bb';
const TOKEN_EXPIRY_SECONDS = 3600; // 1 hour

const generateAgoraToken = (channelName, uid) => {
  const expireTime = Math.floor(Date.now() / 1000) + TOKEN_EXPIRY_SECONDS;
  return RtcTokenBuilder.buildTokenWithUid(
    AGORA_APP_ID,
    AGORA_APP_CERTIFICATE,
    channelName,
    uid,
    RtcRole.PUBLISHER,
    expireTime
  );
};

exports.startSession = async (req, res) => {
  try {
    const booking = await pool.query(
      `SELECT b.* FROM bookings b
       WHERE b.id=$1 AND b.status IN ('confirmed','pending')
       AND (b.client_id=$2 OR b.therapist_id=(SELECT id FROM therapists WHERE user_id=$2))`,
      [req.params.bookingId, req.user.id]
    );

    if (!booking.rows[0]) return errorResponse(res, 'Booking not found or not confirmed', 404);

    // Check if session already exists (idempotent)
    const existing = await pool.query(
      `SELECT * FROM sessions WHERE booking_id=$1 AND status='active'`,
      [req.params.bookingId]
    );

    if (existing.rows[0]) {
      const s = existing.rows[0];
      const newToken = generateAgoraToken(s.room_id, req.user.id);
      return successResponse(res, { session: s, room_id: s.room_id, agora_token: newToken });
    }

    const roomId = uuidv4();
    const agoraToken = generateAgoraToken(roomId, req.user.id);

    const session = await pool.query(
      `INSERT INTO sessions (booking_id, room_id, started_at, status, agora_token)
       VALUES ($1,$2,NOW(),'active',$3) RETURNING *`,
      [req.params.bookingId, roomId, agoraToken]
    );

    await pool.query(
      `UPDATE bookings SET status='in_progress', updated_at=NOW() WHERE id=$1`,
      [req.params.bookingId]
    );

    successResponse(res, { session: session.rows[0], room_id: roomId, agora_token: agoraToken });
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

exports.endSession = async (req, res) => {
  try {
    const result = await pool.query(
      `UPDATE sessions SET ended_at=NOW(), status='ended',
         duration_actual = EXTRACT(EPOCH FROM (NOW() - started_at))/60
       WHERE id=$1 RETURNING *`,
      [req.params.id]
    );

    if (!result.rows[0]) return errorResponse(res, 'Session not found', 404);

    await pool.query(
      `UPDATE bookings SET status='completed', updated_at=NOW() WHERE id=$1`,
      [result.rows[0].booking_id]
    );

    // Update therapist total sessions
    const booking = await pool.query('SELECT therapist_id FROM bookings WHERE id=$1', [result.rows[0].booking_id]);
    await pool.query(
      'UPDATE therapists SET total_sessions = total_sessions + 1 WHERE id=$1',
      [booking.rows[0].therapist_id]
    );

    successResponse(res, result.rows[0], 'Session ended');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

exports.getAgoraToken = async (req, res) => {
  try {
    const session = await pool.query(
      `SELECT s.* FROM sessions s
       JOIN bookings b ON b.id = s.booking_id
       WHERE s.booking_id=$1 AND s.status='active'
       AND (b.client_id=$2 OR b.therapist_id=(SELECT id FROM therapists WHERE user_id=$2))`,
      [req.params.bookingId, req.user.id]
    );

    if (!session.rows[0]) return errorResponse(res, 'Active session not found', 404);

    const newToken = generateAgoraToken(session.rows[0].room_id, req.user.id);
    successResponse(res, { token: newToken, room_id: session.rows[0].room_id });
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};
