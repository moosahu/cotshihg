const admin = require('../config/firebase');
const pool = require('../config/database');

/**
 * Send a push notification via FCM AND save it to the notifications table.
 * @param {string|null} fcmToken
 * @param {string} title
 * @param {string} body
 * @param {object} data  — must contain 'type' and optionally 'booking_id'
 * @param {string} channelId — Android channel (default: 'general_channel')
 * @param {string|null} userId — if provided, saves the notification to DB for history
 */
const sendPushNotification = async (fcmToken, title, body, data = {}, channelId = 'general_channel', userId = null) => {
  // Save to DB for notification history (fire-and-forget)
  if (userId) {
    pool.query(
      `INSERT INTO notifications (user_id, title, body, type, booking_id)
       VALUES ($1, $2, $3, $4, $5)`,
      [userId, title, body, data.type || null, data.booking_id || null]
    ).catch(() => {});
  }

  if (!fcmToken) {
    console.warn(`📵 sendPush SKIPPED — no FCM token | title="${title}"`);
    return;
  }
  console.log(`📤 sendPush → token=${fcmToken.slice(0, 20)}... | title="${title}" | type=${data.type || '?'}`);

  try {
    await admin.messaging().send({
      token: fcmToken,
      notification: { title, body },
      data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
      android: {
        priority: 'high',
        notification: { channelId, priority: 'high', sound: 'default' },
      },
      apns: {
        headers: { 'apns-priority': '10', 'apns-push-type': 'alert' },
        payload: { aps: { alert: { title, body }, sound: 'default', badge: 1 } },
      },
    });
    console.log(`✅ sendPush SUCCESS | title="${title}"`);
  } catch (err) {
    console.error(`❌ sendPush FAILED | title="${title}" | error=${err.message || err}`);
  }
};

/**
 * Save a notification record to DB only (no push).
 * Used when we want history without sending FCM (e.g. when FCM is already sent separately).
 */
const saveNotification = (userId, title, body, type = null, bookingId = null) => {
  if (!userId) return;
  pool.query(
    `INSERT INTO notifications (user_id, title, body, type, booking_id) VALUES ($1,$2,$3,$4,$5)`,
    [userId, title, body, type, bookingId || null]
  ).catch(() => {});
};

module.exports = { sendPushNotification, saveNotification };
