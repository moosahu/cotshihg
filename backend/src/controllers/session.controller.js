const pool = require('../config/database');
const { successResponse, errorResponse } = require('../utils/response.utils');
const { v4: uuidv4 } = require('uuid');
const crypto = require('crypto');
const zlib = require('zlib');

// ─── Agora Token Builder (pure Node.js, no external packages) ───
const AGORA_APP_ID = process.env.AGORA_APP_ID && !process.env.AGORA_APP_ID.startsWith('your_')
  ? process.env.AGORA_APP_ID
  : '45772ce780f046808740a6d07c34781b';

const AGORA_APP_CERTIFICATE = process.env.AGORA_APP_CERTIFICATE && !process.env.AGORA_APP_CERTIFICATE.startsWith('your_')
  ? process.env.AGORA_APP_CERTIFICATE
  : '2c729394bb4e41298e5eb26ebd00c6bb';

function _crc32(buf) {
  let crc = 0xFFFFFFFF;
  for (let i = 0; i < buf.length; i++) {
    crc ^= buf[i];
    for (let j = 0; j < 8; j++) {
      crc = (crc >>> 1) ^ ((crc & 1) * 0xEDB88320);
    }
  }
  return (~crc) >>> 0;
}

function _uint32LE(v) {
  const b = Buffer.alloc(4);
  b.writeUInt32LE((v >>> 0), 0);
  return b;
}

function _packBytes(buf) {
  const len = Buffer.alloc(2);
  len.writeUInt16LE(buf.length, 0);
  return Buffer.concat([len, buf]);
}

function _packMessage(salt, ts, privileges) {
  const entries = Object.entries(privileges);
  const size = 4 + 4 + 2 + entries.length * 6;
  const buf = Buffer.alloc(size);
  let off = 0;
  buf.writeUInt32LE(salt, off); off += 4;
  buf.writeUInt32LE(ts, off); off += 4;
  buf.writeUInt16LE(entries.length, off); off += 2;
  for (const [k, v] of entries) {
    buf.writeUInt16LE(parseInt(k), off); off += 2;
    buf.writeUInt32LE((v >>> 0), off); off += 4;
  }
  return buf;
}

function generateAgoraToken(channelName, uid = 0) {
  try {
    const ts = (Math.floor(Date.now() / 1000) + 3600) >>> 0; // expire in 1h
    const salt = (Math.random() * 0xFFFFFFFF) >>> 0;
    const expireTime = ts;

    // privileges: kJoinChannel=1, kPublishAudioStream=2, kPublishVideoStream=3
    const privileges = { 1: expireTime, 2: expireTime, 3: expireTime };
    const m = _packMessage(salt, ts, privileges);

    // HMAC step 1: sign(appCertificate, appId + ts + salt)
    const signingInput = Buffer.concat([Buffer.from(AGORA_APP_ID), _uint32LE(ts), _uint32LE(salt)]);
    const signingKey = crypto.createHmac('sha256', AGORA_APP_CERTIFICATE).update(signingInput).digest();

    // HMAC step 2: sign(signingKey, channelName + uid + message)
    const signContent = Buffer.concat([Buffer.from(channelName), _uint32LE(uid), m]);
    const signature = crypto.createHmac('sha256', signingKey).update(signContent).digest();

    const packed = Buffer.concat([
      _packBytes(signature),
      _uint32LE(_crc32(Buffer.from(channelName))),
      _uint32LE(_crc32(_uint32LE(uid))),
      m,
    ]);

    return '006' + AGORA_APP_ID + zlib.deflateRawSync(packed).toString('base64');
  } catch (err) {
    console.error('Agora token generation failed:', err.message);
    return '';
  }
}
// ──────────────────────────────────────────────────────────────

exports.startSession = async (req, res) => {
  try {
    const booking = await pool.query(
      `SELECT b.* FROM bookings b
       WHERE b.id=$1
       AND (b.client_id=$2 OR b.therapist_id=(SELECT id FROM therapists WHERE user_id=$2))`,
      [req.params.bookingId, req.user.id]
    );

    if (!booking.rows[0]) return errorResponse(res, 'Booking not found', 404);

    // Return existing active session (idempotent)
    const existing = await pool.query(
      `SELECT * FROM sessions WHERE booking_id=$1 AND status='active'`,
      [req.params.bookingId]
    );

    if (existing.rows[0]) {
      const s = existing.rows[0];
      const newToken = generateAgoraToken(s.room_id, 0);
      return successResponse(res, { session: s, room_id: s.room_id, agora_token: newToken });
    }

    const roomId = uuidv4();
    const agoraToken = generateAgoraToken(roomId, 0);

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

    const newToken = generateAgoraToken(session.rows[0].room_id, 0);
    successResponse(res, { token: newToken, room_id: session.rows[0].room_id });
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};
