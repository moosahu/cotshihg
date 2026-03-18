const admin = require('../config/firebase');

const sendPushNotification = async (fcmToken, title, body, data = {}) => {
  try {
    if (!fcmToken) return;

    await admin.messaging().send({
      token: fcmToken,
      notification: { title, body },
      data,
      android: { priority: 'high' },
      apns: { payload: { aps: { sound: 'default', badge: 1 } } },
    });
  } catch (err) {
    console.error('Push notification error:', err);
  }
};

module.exports = { sendPushNotification };
