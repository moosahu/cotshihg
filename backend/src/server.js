const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const path = require('path');
const { createServer } = require('http');
const { Server } = require('socket.io');
require('dotenv').config();

const authRoutes = require('./routes/auth.routes');
const adminRoutes = require('./routes/admin.routes');
const userRoutes = require('./routes/user.routes');
const therapistRoutes = require('./routes/therapist.routes');
const sessionRoutes = require('./routes/session.routes');
const bookingRoutes = require('./routes/booking.routes');
const chatRoutes = require('./routes/chat.routes');
const contentRoutes = require('./routes/content.routes');
const paymentRoutes = require('./routes/payment.routes');
const moodRoutes = require('./routes/mood.routes');
const filesRoutes = require('./routes/files.routes');
const questionnaireRoutes = require('./routes/questionnaire.routes');

const socketHandler = require('./socket/socket.handler');
const socketInstance = require('./socket/socket.instance');
const errorHandler = require('./middleware/error.middleware');
const rateLimiter = require('./middleware/rateLimit.middleware');
const runMigration = require('./database/migrate');
const { startReminderJobs } = require('./jobs/reminder.job');

const app = express();
const httpServer = createServer(app);

const io = new Server(httpServer, {
  cors: {
    origin: process.env.CLIENT_URL || '*',
    methods: ['GET', 'POST'],
  },
});

// Middleware
app.use(helmet());
app.use(cors());
app.use(morgan('dev'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(rateLimiter);


// Routes
app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/admin', adminRoutes);
app.use('/api/v1/users', userRoutes);
app.use('/api/v1/therapists', therapistRoutes);
app.use('/api/v1/sessions', sessionRoutes);
app.use('/api/v1/bookings', bookingRoutes);
app.use('/api/v1/chat', chatRoutes);
app.use('/api/v1/content', contentRoutes);
app.use('/api/v1/payments', paymentRoutes);
app.use('/api/v1/mood', moodRoutes);
app.use('/api/v1/files', filesRoutes);
app.use('/api/v1/questionnaires', questionnaireRoutes);

app.get('/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// Socket.io
socketInstance.setIo(io);
socketHandler(io);

// Error Handler
app.use(errorHandler);

const PORT = process.env.PORT || 3000;
httpServer.listen(PORT, async () => {
  console.log(`🚀 Server running on port ${PORT}`);
  await runMigration();
  startReminderJobs();
});

module.exports = { app, io };
