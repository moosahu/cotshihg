const admin = require('../config/firebase');

/**
 * Send a push notification via FCM.
 * @param {string} fcmToken
 * @param {string} title
 * @param {string} body
 * @param {object} data  — must contain 'type' key so the Flutter handler routes correctly
 * @param {string} channelId — Android channel (default: 'general_channel')
 */
const sendPushNotification = async (fcmToken, title, body, data = {}, channelId = 'general_channel') => {
  try {
    if (!fcmToken) {
      console.warn(`📵 sendPush SKIPPED — no FCM token | title="${title}"`);
      return;
    }
    console.log(`📤 sendPush → token=${fcmToken.slice(0,20)}... | title="${title}" | type=${data.type || '?'}`);

    await admin.messaging().send({
      token: fcmToken,
      notification: { title, body },
      data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
      android: {
        priority: 'high',
        notification: {
          channelId,
          priority: 'high',
          sound: 'default',
        },
      },
      apns: {
        headers: {
          'apns-priority': '10',
          'apns-push-type': 'alert',
        },
        payload: {
          aps: {
            alert: { title, body },
            sound: 'default',
            badge: 1,
          },
        },
      },
    });
    console.log(`✅ sendPush SUCCESS | title="${title}"`);
  } catch (err) {
    console.error(`❌ sendPush FAILED | title="${title}" | error=${err.message || err}`);
  }
};

module.exports = { sendPushNotification };
