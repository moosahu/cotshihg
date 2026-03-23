const jwt = require('jsonwebtoken');
const pool = require('../config/database');
const admin = require('../config/firebase');

const socketHandler = (io) => {
  // Auth middleware for socket
  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth.token;
      if (!token) return next(new Error('Authentication required'));

      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      const result = await pool.query('SELECT * FROM users WHERE id=$1', [decoded.userId]);
      if (!result.rows[0]) return next(new Error('User not found'));

      socket.user = result.rows[0];
      next();
    } catch (err) {
      next(new Error('Invalid token'));
    }
  });

  io.on('connection', (socket) => {
    console.log(`🔌 User connected: ${socket.user.id}`);

    // Join personal room
    socket.join(`user_${socket.user.id}`);

    // Join booking chat room
    socket.on('join_booking', async (bookingId) => {
      const booking = await pool.query(
        `SELECT * FROM bookings WHERE id=$1
         AND (client_id=$2 OR therapist_id=(SELECT id FROM therapists WHERE user_id=$2))`,
        [bookingId, socket.user.id]
      );
      if (booking.rows[0]) {
        socket.join(`booking_${bookingId}`);
        socket.emit('joined_booking', { booking_id: bookingId });
      }
    });

    // Send chat message
    socket.on('send_message', async (data) => {
      const { booking_id, content, message_type = 'text', media_url } = data;

      try {
        const result = await pool.query(
          `INSERT INTO messages (booking_id, sender_id, content, message_type, media_url)
           VALUES ($1,$2,$3,$4,$5) RETURNING *`,
          [booking_id, socket.user.id, content, message_type, media_url]
        );

        const message = {
          ...result.rows[0],
          sender_name: socket.user.name,
          sender_avatar: socket.user.avatar_url,
        };

        // Broadcast to booking room
        io.to(`booking_${booking_id}`).emit('new_message', message);
      } catch (err) {
        socket.emit('error', { message: 'Failed to send message' });
      }
    });

    // Typing indicator
    socket.on('typing', ({ booking_id, is_typing }) => {
      socket.to(`booking_${booking_id}`).emit('user_typing', {
        user_id: socket.user.id,
        is_typing,
      });
    });

    // Call events — emit to coach's personal room + FCM for background
    socket.on('call_initiated', async ({ booking_id, call_type }) => {
      try {
        const booking = await pool.query(
          `SELECT t.user_id AS coach_user_id, u.fcm_token
           FROM bookings b
           JOIN therapists t ON t.id = b.therapist_id
           JOIN users u ON u.id = t.user_id
           WHERE b.id = $1`,
          [booking_id]
        );
        if (booking.rows[0]) {
          const { coach_user_id, fcm_token } = booking.rows[0];

          // Real-time socket (app in foreground)
          io.to(`user_${coach_user_id}`).emit('incoming_call', {
            booking_id,
            from_name: socket.user.name,
            call_type,
          });

          // FCM push (app in background/killed)
          if (fcm_token && admin.apps.length > 0) {
            const isVoice = call_type === 'voice';
            const title = isVoice ? '📞 مكالمة صوتية واردة' : '📹 مكالمة فيديو واردة';
            const body = `${socket.user.name || 'عميل'} يطلب ${isVoice ? 'مكالمة صوتية' : 'مكالمة فيديو'}`;
            admin.messaging().send({
              token: fcm_token,
              data: {
                type: 'incoming_call',
                booking_id: String(booking_id),
                from_name: socket.user.name || 'عميل',
                call_type: call_type || 'video',
              },
              android: {
                priority: 'high',
                notification: {
                  title,
                  body,
                  channelId: 'incoming_call_channel',
                  priority: 'max',
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
                    'content-available': 1,
                    category: 'INCOMING_CALL',
                  },
                },
              },
            }).then(() => {
              console.log(`📱 FCM sent to coach ${coach_user_id}`);
            }).catch((err) => {
              console.error('❌ FCM error:', err.message);
            });
          } else {
            console.warn(`⚠️ No FCM token for coach ${coach_user_id}`);
          }
        }
      } catch (_) {}
    });

    socket.on('call_accepted', ({ booking_id }) => {
      socket.to(`booking_${booking_id}`).emit('call_accepted', { booking_id });
    });

    socket.on('call_rejected', ({ booking_id }) => {
      socket.to(`booking_${booking_id}`).emit('call_rejected', { booking_id });
    });

    socket.on('call_ended', ({ booking_id }) => {
      io.to(`booking_${booking_id}`).emit('call_ended', { booking_id });
    });

    socket.on('disconnect', () => {
      console.log(`🔌 User disconnected: ${socket.user.id}`);
    });
  });
};

module.exports = socketHandler;
