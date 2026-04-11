const pool = require('../config/database');
const { successResponse, errorResponse } = require('../utils/response.utils');
const { sendPushNotification, saveNotification } = require('../utils/notifications.utils');
const { v4: uuidv4 } = require('uuid');
const { autoAssignOnBooking } = require('./questionnaire.controller');

exports.createBooking = async (req, res) => {
  try {
    const { therapist_id, session_type, scheduled_at, duration_minutes, notes } = req.body;

    const therapistResult = await pool.query(
      `SELECT t.*, u.id as user_id, u.fcm_token, u.name as therapist_name
       FROM therapists t JOIN users u ON u.id = t.user_id WHERE t.id=$1`,
      [therapist_id]
    );
    if (!therapistResult.rows[0]) return errorResponse(res, 'Therapist not found', 404);

    const therapist = therapistResult.rows[0];
    const priceMap = { chat: therapist.session_price_chat, voice: therapist.session_price_voice, video: therapist.session_price_video };
    const basePrice = parseFloat(priceMap[session_type] || 0);
    const discount = parseInt(therapist.discount_percent || 0);
    const price = discount > 0 ? +(basePrice * (1 - discount / 100)).toFixed(2) : basePrice;

    const conflict = await pool.query(
      `SELECT id FROM bookings
       WHERE therapist_id=$1
       AND status IN ('pending','confirmed')
       AND scheduled_at BETWEEN $2::timestamptz - INTERVAL '30 minutes' AND $2::timestamptz + INTERVAL '30 minutes'`,
      [therapist_id, scheduled_at]
    );
    if (conflict.rows[0]) return errorResponse(res, 'هذا الموعد محجوز مسبقاً', 409);

    const result = await pool.query(
      `INSERT INTO bookings (client_id, therapist_id, session_type, scheduled_at, duration_minutes, price, notes)
       VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
      [req.user.id, therapist_id, session_type, scheduled_at, duration_minutes || 60, price, notes]
    );

    // Notify therapist
    const bookingId = result.rows[0].id;
    await sendPushNotification(
      therapist.fcm_token,
      'طلب جلسة جديد',
      `لديك طلب جلسة جديد من ${req.user.name}`,
      { type: 'new_booking', booking_id: bookingId }
    );
    saveNotification(therapist.user_id, 'طلب جلسة جديد', `لديك طلب جلسة جديد من ${req.user.name}`, 'new_booking', bookingId);

    successResponse(res, result.rows[0], 'Booking created', 201);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

exports.createInstantBooking = async (req, res) => {
  try {
    const { therapist_id, session_type } = req.body;

    const therapistResult = await pool.query(
      `SELECT t.*, u.fcm_token FROM therapists t JOIN users u ON u.id = t.user_id
       WHERE t.id=$1 AND t.is_available_instant=true`,
      [therapist_id]
    );
    if (!therapistResult.rows[0]) return errorResponse(res, 'Therapist not available for instant session', 400);

    const therapist = therapistResult.rows[0];
    const priceMap = { chat: therapist.session_price_chat, voice: therapist.session_price_voice, video: therapist.session_price_video };
    const basePrice = parseFloat(priceMap[session_type] || 0);
    const discount = parseInt(therapist.discount_percent || 0);
    const price = discount > 0 ? +(basePrice * (1 - discount / 100)).toFixed(2) : basePrice;

    const result = await pool.query(
      `INSERT INTO bookings (client_id, therapist_id, session_type, scheduled_at, booking_type, price, status)
       VALUES ($1,$2,$3,NOW(),'instant',$4,'confirmed') RETURNING *`,
      [req.user.id, therapist_id, session_type, price]
    );

    const booking = result.rows[0];
    await autoAssignOnBooking(booking.id, booking.client_id, booking.therapist_id);

    successResponse(res, booking, 'Instant booking created', 201);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

exports.getCoachDashboardStats = async (req, res) => {
  try {
    const therapistRow = await pool.query(
      'SELECT id, rating FROM therapists WHERE user_id=$1', [req.user.id]
    );
    if (!therapistRow.rows[0]) return errorResponse(res, 'Coach not found', 404);
    const therapistId = therapistRow.rows[0].id;
    const rating = therapistRow.rows[0].rating;

    const [todayRes, weekRes, earningsRes, todaySessionsRes, pendingRes] = await Promise.all([
      // جلسات اليوم
      pool.query(
        `SELECT COUNT(*) FROM bookings
         WHERE therapist_id=$1 AND status IN ('confirmed','completed','in_progress')
         AND scheduled_at::date = CURRENT_DATE`,
        [therapistId]
      ),
      // جلسات هذا الأسبوع
      pool.query(
        `SELECT COUNT(*) FROM bookings
         WHERE therapist_id=$1 AND status IN ('confirmed','completed','in_progress')
         AND scheduled_at >= date_trunc('week', NOW())
         AND scheduled_at < date_trunc('week', NOW()) + INTERVAL '7 days'`,
        [therapistId]
      ),
      // أرباح هذا الأسبوع
      pool.query(
        `SELECT COALESCE(SUM(p.amount),0) as total
         FROM payments p
         JOIN bookings b ON b.id = p.booking_id
         WHERE b.therapist_id=$1 AND p.status='paid'
         AND p.created_at >= date_trunc('week', NOW())`,
        [therapistId]
      ),
      // جلسات اليوم مع اسم العميل
      pool.query(
        `SELECT b.id, b.session_type, b.scheduled_at, b.status, u.name as client_name
         FROM bookings b JOIN users u ON u.id = b.client_id
         WHERE b.therapist_id=$1 AND status IN ('confirmed','in_progress')
         AND b.scheduled_at::date = CURRENT_DATE
         ORDER BY b.scheduled_at ASC`,
        [therapistId]
      ),
      // الطلبات المعلقة
      pool.query(
        `SELECT COUNT(*) FROM bookings WHERE therapist_id=$1 AND status='pending'`,
        [therapistId]
      ),
    ]);

    successResponse(res, {
      today_count: parseInt(todayRes.rows[0].count),
      week_count: parseInt(weekRes.rows[0].count),
      week_earnings: parseFloat(earningsRes.rows[0].total),
      rating: rating ? parseFloat(rating).toFixed(1) : null,
      today_sessions: todaySessionsRes.rows,
      pending_count: parseInt(pendingRes.rows[0].count),
    });
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

exports.getMyBookings = async (req, res) => {
  try {
    const { status, role } = req.query;
    let query;
    const params = [req.user.id];

    if (req.user.role === 'therapist' || req.user.role === 'coach') {
      query = `SELECT b.*, u.name as client_name, u.avatar_url as client_avatar
               FROM bookings b JOIN users u ON u.id = b.client_id
               WHERE b.therapist_id = (SELECT id FROM therapists WHERE user_id=$1)`;
    } else {
      query = `SELECT b.*, u.name as therapist_name, u.avatar_url as therapist_avatar, t.rating
               FROM bookings b
               JOIN therapists t ON t.id = b.therapist_id
               JOIN users u ON u.id = t.user_id
               WHERE b.client_id=$1`;
    }

    if (status) {
      query += ` AND b.status=$2`;
      params.push(status);
    }

    query += ` ORDER BY b.created_at DESC`;

    const result = await pool.query(query, params);
    successResponse(res, result.rows);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

exports.getBookingById = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT b.*,
              client.name as client_name, client.avatar_url as client_avatar, client.phone as client_phone,
              therapist_user.name as therapist_name, therapist_user.avatar_url as therapist_avatar,
              t.specializations, t.rating
       FROM bookings b
       JOIN users client ON client.id = b.client_id
       JOIN therapists t ON t.id = b.therapist_id
       JOIN users therapist_user ON therapist_user.id = t.user_id
       WHERE b.id=$1 AND (b.client_id=$2 OR t.user_id=$2)`,
      [req.params.id, req.user.id]
    );

    if (!result.rows[0]) return errorResponse(res, 'Booking not found', 404);
    successResponse(res, result.rows[0]);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

exports.confirmBooking = async (req, res) => {
  try {
    const therapistResult = await pool.query('SELECT id FROM therapists WHERE user_id=$1 LIMIT 1', [req.user.id]);
    if (!therapistResult.rows[0]) return errorResponse(res, 'Therapist not found', 404);

    const result = await pool.query(
      `UPDATE bookings SET status='confirmed', updated_at=NOW()
       WHERE id=$1 AND therapist_id=$2 AND status='pending' RETURNING *`,
      [req.params.id, therapistResult.rows[0].id]
    );

    if (!result.rows[0]) return errorResponse(res, 'Booking not found or already processed', 404);

    // Auto-assign default questionnaire if coach has one set
    await autoAssignOnBooking(result.rows[0].id, result.rows[0].client_id, result.rows[0].therapist_id);

    // Notify client
    const clientId = result.rows[0].client_id;
    const clientResult = await pool.query('SELECT fcm_token FROM users WHERE id=$1', [clientId]);
    await sendPushNotification(
      clientResult.rows[0]?.fcm_token,
      'تم تأكيد موعدك',
      'تم تأكيد جلستك من قبل الكوتش',
      { type: 'booking_confirmed', booking_id: req.params.id }
    );
    saveNotification(clientId, 'تم تأكيد موعدك', 'تم تأكيد جلستك من قبل الكوتش', 'booking_confirmed', req.params.id);

    successResponse(res, result.rows[0], 'Booking confirmed');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

exports.cancelBooking = async (req, res) => {
  try {
    console.log(`🔴 cancelBooking: id=${req.params.id} user=${req.user.id} role=${req.user.role}`);
    const isAdmin = req.user.role === 'admin';
    const isCoachRole = ['therapist', 'coach'].includes(req.user.role);
    const cancelledBy = isAdmin ? 'admin' : (isCoachRole ? 'coach' : 'client');
    const result = await pool.query(
      `UPDATE bookings SET status='cancelled', cancelled_by=$3, updated_at=NOW()
       WHERE id=$1 AND (client_id=$2 OR therapist_id=(SELECT id FROM therapists WHERE user_id=$2)
         OR $2 IN (SELECT id FROM users WHERE role='admin'))
       AND status IN ('pending','confirmed') RETURNING *`,
      [req.params.id, req.user.id, cancelledBy]
    );
    console.log(`🔴 cancelBooking result: ${result.rowCount} rows`);

    if (!result.rows[0]) return errorResponse(res, 'لا يمكن إلغاء هذا الحجز', 400);

    // Clean up any pending payment records for this booking
    await pool.query(
      `DELETE FROM payments WHERE booking_id=$1 AND status='pending'`,
      [req.params.id]
    );

    // Notify the other party about cancellation
    try {
      const booking = result.rows[0];
      const notifData = { type: 'booking_cancelled', booking_id: String(req.params.id) };

      const clientRes = await pool.query('SELECT name, fcm_token FROM users WHERE id=$1', [booking.client_id]);
      const coachRes = await pool.query(
        'SELECT u.name, u.fcm_token FROM therapists t JOIN users u ON u.id=t.user_id WHERE t.id=$1',
        [booking.therapist_id]
      );

      const clientUser = clientRes.rows[0];
      const coachUser = coachRes.rows[0];
      const cancellerIsCoach = isCoachRole;

      if (cancellerIsCoach) {
        // Coach cancelled → notify client
        await sendPushNotification(clientUser?.fcm_token, '❌ تم إلغاء موعدك', `تم إلغاء جلستك مع ${coachUser?.name ?? 'الكوتش'}`, notifData);
        saveNotification(booking.client_id, '❌ تم إلغاء موعدك', `تم إلغاء جلستك مع ${coachUser?.name ?? 'الكوتش'}`, 'booking_cancelled', req.params.id);
      } else {
        // Client or admin cancelled → notify coach
        const coachUserIdRes = await pool.query('SELECT user_id FROM therapists WHERE id=$1', [booking.therapist_id]);
        const coachUserId = coachUserIdRes.rows[0]?.user_id;
        await sendPushNotification(coachUser?.fcm_token, '❌ تم إلغاء حجز', `ألغى ${isAdmin ? 'الإدارة' : (clientUser?.name ?? 'العميل')} الجلسة المقررة`, notifData);
        saveNotification(coachUserId, '❌ تم إلغاء حجز', `ألغى ${isAdmin ? 'الإدارة' : (clientUser?.name ?? 'العميل')} الجلسة المقررة`, 'booking_cancelled', req.params.id);
        // If admin cancelled, notify client too
        if (isAdmin) {
          await sendPushNotification(clientUser?.fcm_token, '❌ تم إلغاء موعدك', 'تم إلغاء جلستك من قِبَل الإدارة', notifData);
          saveNotification(booking.client_id, '❌ تم إلغاء موعدك', 'تم إلغاء جلستك من قِبَل الإدارة', 'booking_cancelled', req.params.id);
        }
      }
    } catch (_) {}

    successResponse(res, result.rows[0], 'Booking cancelled');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

exports.confirmAfterPayment = async (req, res) => {
  try {
    const result = await pool.query(
      `UPDATE bookings SET status='confirmed', payment_status='paid', updated_at=NOW()
       WHERE id=$1 AND client_id=$2 AND status='pending' RETURNING *`,
      [req.params.id, req.user.id]
    );
    if (!result.rows[0]) return errorResponse(res, 'Booking not found', 404);

    // Mark payment record as paid
    await pool.query(
      `UPDATE payments SET status='paid' WHERE booking_id=$1 AND status='pending'`,
      [req.params.id]
    );

    // Notify coach that payment completed and booking is confirmed
    try {
      const booking = result.rows[0];
      const clientRes = await pool.query('SELECT name FROM users WHERE id=$1', [booking.client_id]);
      const coachRes = await pool.query(
        'SELECT u.fcm_token FROM therapists t JOIN users u ON u.id=t.user_id WHERE t.id=$1',
        [booking.therapist_id]
      );
      await sendPushNotification(
        coachRes.rows[0]?.fcm_token,
        '💳 تأكيد حجز جديد',
        `أتم ${clientRes.rows[0]?.name ?? 'العميل'} الدفع وتم تأكيد الجلسة`,
        { type: 'new_booking', booking_id: String(req.params.id) }
      );
    } catch (_) {}

    successResponse(res, result.rows[0], 'Booking confirmed');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

exports.submitReview = async (req, res) => {
  try {
    const { rating, comment } = req.body;

    const bookingResult = await pool.query(
      'SELECT * FROM bookings WHERE id=$1 AND client_id=$2 AND status=$3',
      [req.params.id, req.user.id, 'completed']
    );

    if (!bookingResult.rows[0]) return errorResponse(res, 'Booking not found or not completed', 404);

    const booking = bookingResult.rows[0];

    await pool.query(
      'INSERT INTO reviews (booking_id, client_id, therapist_id, rating, comment) VALUES ($1,$2,$3,$4,$5)',
      [booking.id, req.user.id, booking.therapist_id, rating, comment]
    );

    // Update therapist average rating
    await pool.query(
      `UPDATE therapists SET
         rating = (SELECT AVG(rating) FROM reviews WHERE therapist_id=$1),
         total_reviews = (SELECT COUNT(*) FROM reviews WHERE therapist_id=$1)
       WHERE id=$1`,
      [booking.therapist_id]
    );

    successResponse(res, null, 'Review submitted');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};
