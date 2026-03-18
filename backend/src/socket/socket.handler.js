const jwt = require('jsonwebtoken');
const pool = require('../config/database');

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

    // Call events
    socket.on('call_initiated', ({ booking_id, call_type }) => {
      socket.to(`booking_${booking_id}`).emit('incoming_call', {
        from: socket.user.id,
        from_name: socket.user.name,
        call_type,
        booking_id,
      });
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
