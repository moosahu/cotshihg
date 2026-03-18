const pool = require('../config/database');
const { successResponse, errorResponse } = require('../utils/response.utils');
const { v4: uuidv4 } = require('uuid');
const { getIo } = require('../socket/socket.instance');
const crypto = require('crypto');
const zlib = require('zlib');

const AGORA_APP_ID = (process.env.AGORA_APP_ID && !process.env.AGORA_APP_ID.startsWith('your_'))
  ? process.env.AGORA_APP_ID
  : '45772ce780f046808740a6d07c34781b';

const AGORA_APP_CERTIFICATE = (process.env.AGORA_APP_CERTIFICATE && !process.env.AGORA_APP_CERTIFICATE.startsWith('your_'))
  ? process.env.AGORA_APP_CERTIFICATE
  : '2c729394bb4e41298e5eb26ebd00c6bb';

// ─── Try agora-access-token package first ───────────────────
let _pkgGenerateToken = null;
try {
  const { RtcTokenBuilder, RtcRole } = require('agora-access-token');
  _pkgGenerateToken = (channelName, uid) => {
    const expireTime = Math.floor(Date.now() / 1000) + 3600;
    return RtcTokenBuilder.buildTokenWithUid(
      AGORA_APP_ID, AGORA_APP_CERTIFICATE,
      channelName, uid, RtcRole.PUBLISHER, expireTime
    );
  };
  console.log('✅ agora-access-token package loaded');
} catch (e) {
  console.warn('⚠️  agora-access-token not found, using built-in implementation');
}

// ─── Pure Node.js fallback (Agora AccessToken v1) ───────────
function _crc32(buf) {
  const table = [];
  for (let i = 0; i < 256; i++) {
    let c = i;
    for (let j = 0; j < 8; j++) c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
    table[i] = c;
  }
  let crc = 0xFFFFFFFF;
  for (let i = 0; i < buf.length; i++) crc = table[(crc ^ buf[i]) & 0xFF] ^ (crc >>> 8);
  return (~crc) >>> 0;
}

function _u32(v) { const b = Buffer.alloc(4); b.writeUInt32LE(v >>> 0, 0); return b; }
function _u16(v) { const b = Buffer.alloc(2); b.writeUInt16LE(v & 0xFFFF, 0); return b; }

function _packContent(signature, crcChannel, crcUid, m) {
  return Buffer.concat([
    _u16(signature.length), signature,  // packString(signature)
    _u32(crcChannel),                   // packUint32(crcChannel)
    _u32(crcUid),                       // packUint32(crcUid)
    m,
  ]);
}

function _packMessage(salt, ts, privileges) {
  const entries = Object.entries(privileges).sort((a, b) => a[0] - b[0]);
  const size = 4 + 4 + 2 + entries.length * 6;
  const buf = Buffer.alloc(size);
  let off = 0;
  buf.writeUInt32LE(salt, off); off += 4;
  buf.writeUInt32LE(ts, off); off += 4;
  buf.writeUInt16LE(entries.length, off); off += 2;
  for (const [k, v] of entries) {
    buf.writeUInt16LE(parseInt(k), off); off += 2;
    buf.writeUInt32LE(v >>> 0, off); off += 4;
  }
  return buf;
}

function _builtinGenerateToken(channelName, uid) {
  const nowTs = Math.floor(Date.now() / 1000);
  const msgTs = (nowTs + 24 * 3600) >>> 0; // message timestamp = now + 24h
  const salt = (Math.random() * 0xFFFFFFFF) >>> 0;
  const expireTs = (nowTs + 3600) >>> 0;   // privilege expire = now + 1h

  // Publisher privileges: kJoinChannel=1, kPublishAudioStream=2, kPublishVideoStream=3, kPublishDataStream=4
  const privileges = { 1: expireTs, 2: 0, 3: 0, 4: 0 };
  const m = _packMessage(salt, msgTs, privileges);

  // Step 1: signingKey = HMAC-SHA256(appCertificate, appId + msgTs + salt)
  const signing1Input = Buffer.concat([Buffer.from(AGORA_APP_ID), _u32(msgTs), _u32(salt)]);
  const signingKey = crypto.createHmac('sha256', Buffer.from(AGORA_APP_CERTIFICATE)).update(signing1Input).digest();

  // Step 2: signature = HMAC-SHA256(signingKey, channelName + uid + m)
  const signing2Input = Buffer.concat([Buffer.from(channelName), _u32(uid), m]);
  const signature = crypto.createHmac('sha256', signingKey).update(signing2Input).digest();

  const crcChannel = _crc32(Buffer.from(channelName));
  const crcUid = _crc32(_u32(uid));

  const content = _packContent(signature, crcChannel, crcUid, m);
  const compressed = zlib.deflateRawSync(content);

  return '006' + AGORA_APP_ID + compressed.toString('base64');
}

function generateAgoraToken(channelName, uid = 0) {
  try {
    if (_pkgGenerateToken) return _pkgGenerateToken(channelName, uid);
    return _builtinGenerateToken(channelName, uid);
  } catch (err) {
    console.error('Token generation failed:', err.message);
    return '';
  }
}
// ─────────────────────────────────────────────────────────────

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
      return successResponse(res, { session: s, room_id: s.room_id, agora_token: generateAgoraToken(s.room_id) });
    }

    const roomId = uuidv4();
    const agoraToken = generateAgoraToken(roomId);

    const session = await pool.query(
      `INSERT INTO sessions (booking_id, room_id, started_at, status, agora_token)
       VALUES ($1,$2,NOW(),'active',$3) RETURNING *`,
      [req.params.bookingId, roomId, agoraToken]
    );

    await pool.query(
      `UPDATE bookings SET status='in_progress', updated_at=NOW() WHERE id=$1`,
      [req.params.bookingId]
    );

    // Notify coach via socket
    const therapistUser = await pool.query(
      `SELECT u.id, u.name FROM therapists t JOIN users u ON u.id=t.user_id WHERE t.id=$1`,
      [booking.rows[0].therapist_id]
    );
    if (therapistUser.rows[0]) {
      const io = getIo();
      const clientUser = await pool.query('SELECT name FROM users WHERE id=$1', [req.user.id]);
      io?.to(`user_${therapistUser.rows[0].id}`).emit('incoming_call', {
        booking_id: req.params.bookingId,
        from_name: clientUser.rows[0]?.name ?? 'عميل',
        call_type: booking.rows[0].session_type,
        room_id: roomId,
        agora_token: agoraToken,
      });
    }

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

    await pool.query(`UPDATE bookings SET status='completed', updated_at=NOW() WHERE id=$1`, [result.rows[0].booking_id]);

    const booking = await pool.query('SELECT therapist_id FROM bookings WHERE id=$1', [result.rows[0].booking_id]);
    await pool.query('UPDATE therapists SET total_sessions = total_sessions + 1 WHERE id=$1', [booking.rows[0].therapist_id]);

    successResponse(res, result.rows[0], 'Session ended');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

exports.getAgoraToken = async (req, res) => {
  try {
    const session = await pool.query(
      `SELECT s.* FROM sessions s JOIN bookings b ON b.id = s.booking_id
       WHERE s.booking_id=$1 AND s.status='active'
       AND (b.client_id=$2 OR b.therapist_id=(SELECT id FROM therapists WHERE user_id=$2))`,
      [req.params.bookingId, req.user.id]
    );
    if (!session.rows[0]) return errorResponse(res, 'Active session not found', 404);

    successResponse(res, { token: generateAgoraToken(session.rows[0].room_id), room_id: session.rows[0].room_id });
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};
