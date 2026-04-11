const cron = require('node-cron');
const pool = require('../config/database');
const admin = require('../config/firebase');

/**
 * Sends FCM push notification to a user.
 */
async function sendPush(fcmToken, title, body, data = {}) {
  if (!fcmToken || !admin.apps.length) return;
  try {
    await admin.messaging().send({
      token: fcmToken,
      notification: { title, body },
      data,
      android: {
        priority: 'high',
        notification: { channelId: 'reminders', priority: 'high' },
      },
      apns: {
        headers: { 'apns-priority': '10', 'apns-push-type': 'alert' },
        payload: { aps: { alert: { title, body }, sound: 'default' } },
      },
    });
  } catch (err) {
    console.error('📵 Push failed:', err.message);
  }
}

/**
 * Check for sessions starting in ~24 hours (window: 23h50m – 24h10m).
 */
async function sendDayReminders() {
  try {
    const rows = await pool.query(`
      SELECT b.id AS booking_id, b.scheduled_at, b.session_type,
             u.name AS client_name, u.fcm_token AS client_token,
             cu.name AS coach_name, cu.fcm_token AS coach_token
        FROM bookings b
        JOIN users u ON u.id = b.client_id
        JOIN therapists t ON t.id = b.therapist_id
        JOIN users cu ON cu.id = t.user_id
       WHERE b.status IN ('confirmed','pending')
         AND b.scheduled_at BETWEEN NOW() + INTERVAL '23 hours 50 minutes'
                                 AND NOW() + INTERVAL '24 hours 10 minutes'
    `);

    for (const row of rows.rows) {
      const typeLabel = row.session_type === 'video' ? 'فيديو'
                      : row.session_type === 'voice'  ? 'صوتية' : 'دردشة';
      const reminderData = { type: 'session_reminder', booking_id: String(row.booking_id), reminder: '1day' };

      // Notify client
      await sendPush(
        row.client_token,
        '🗓️ تذكير بجلستك غداً',
        `لديك جلسة ${typeLabel} مع ${row.coach_name} غداً. لا تنسَ الاستعداد!`,
        reminderData,
      );

      // Notify coach
      await sendPush(
        row.coach_token,
        '🗓️ تذكير بجلسة غداً',
        `لديك جلسة ${typeLabel} مع ${row.client_name} غداً.`,
        reminderData,
      );
    }

    if (rows.rows.length > 0)
      console.log(`🔔 Sent ${rows.rows.length * 2} day-before reminders (client + coach)`);
  } catch (err) {
    console.error('Day-reminder job error:', err.message);
  }
}

/**
 * Check for sessions starting in ~30 minutes (window: 28m – 32m).
 */
async function sendHalfHourReminders() {
  try {
    const rows = await pool.query(`
      SELECT b.id AS booking_id, b.scheduled_at, b.session_type,
             u.name AS client_name, u.fcm_token AS client_token,
             cu.name AS coach_name, cu.fcm_token AS coach_token
        FROM bookings b
        JOIN users u ON u.id = b.client_id
        JOIN therapists t ON t.id = b.therapist_id
        JOIN users cu ON cu.id = t.user_id
       WHERE b.status IN ('confirmed','pending')
         AND b.scheduled_at BETWEEN NOW() + INTERVAL '28 minutes'
                                 AND NOW() + INTERVAL '32 minutes'
    `);

    for (const row of rows.rows) {
      const typeLabel = row.session_type === 'video' ? 'فيديو'
                      : row.session_type === 'voice'  ? 'صوتية' : 'دردشة';
      const reminderData = { type: 'session_reminder', booking_id: String(row.booking_id), reminder: '30min' };

      // Notify client
      await sendPush(
        row.client_token,
        '⏰ جلستك بعد 30 دقيقة',
        `جلستك ${typeLabel} مع ${row.coach_name} ستبدأ بعد 30 دقيقة. استعد الآن!`,
        reminderData,
      );

      // Notify coach
      await sendPush(
        row.coach_token,
        '⏰ جلسة بعد 30 دقيقة',
        `جلستك ${typeLabel} مع ${row.client_name} ستبدأ بعد 30 دقيقة.`,
        reminderData,
      );
    }

    if (rows.rows.length > 0)
      console.log(`🔔 Sent ${rows.rows.length * 2} 30-min reminders (client + coach)`);
  } catch (err) {
    console.error('30min-reminder job error:', err.message);
  }
}

/**
 * Start all reminder cron jobs.
 * Called once from server.js after the server starts.
 */
function startReminderJobs() {
  // Every 20 minutes — catches the 30-min window reliably
  cron.schedule('*/20 * * * *', sendHalfHourReminders);

  // Every hour at :00 — catches the 24-hour window reliably
  cron.schedule('0 * * * *', sendDayReminders);

  console.log('⏰ Reminder jobs scheduled');
}

module.exports = { startReminderJobs };
