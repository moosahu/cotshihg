const pool = require('../config/database');
const jwt = require('jsonwebtoken');
const { successResponse, errorResponse } = require('../utils/response.utils');

// POST /admin/login — email+password from env vars
exports.login = async (req, res) => {
  try {
    const { email, password } = req.body;
    const adminEmail = process.env.ADMIN_EMAIL || 'admin@coaching.app';
    const adminPassword = process.env.ADMIN_PASSWORD || 'Admin@2024!';

    if (email !== adminEmail || password !== adminPassword) {
      return errorResponse(res, 'بيانات الدخول غير صحيحة', 401);
    }

    const token = jwt.sign(
      { userId: 'admin', role: 'admin' },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
    );

    successResponse(res, { token }, 'تم تسجيل الدخول بنجاح');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// GET /admin/stats
exports.getStats = async (req, res) => {
  try {
    const [usersRes, therapistsRes, bookingsRes, paymentsRes, sessionTypesRes] = await Promise.all([
      pool.query("SELECT COUNT(*) FROM users WHERE role != 'admin'"),
      pool.query("SELECT COUNT(*) FROM users WHERE role IN ('therapist','coach')"),
      pool.query("SELECT COUNT(*) FROM bookings WHERE DATE(created_at) = CURRENT_DATE"),
      pool.query("SELECT COALESCE(SUM(amount),0) as total FROM payments WHERE status = 'paid'"),
      pool.query(`
        SELECT session_type, COUNT(*) as count
        FROM bookings
        WHERE status IN ('completed','confirmed','in_progress')
        GROUP BY session_type
      `),
    ]);

    const total = sessionTypesRes.rows.reduce((s, r) => s + parseInt(r.count), 0) || 1;
    const sessionTypes = sessionTypesRes.rows.map(r => ({
      name: r.session_type === 'video' ? 'فيديو' : r.session_type === 'voice' ? 'صوتي' : 'دردشة',
      value: Math.round(parseInt(r.count) / total * 100),
      color: r.session_type === 'video' ? '#1A6B72' : r.session_type === 'voice' ? '#F5A623' : '#FF6B35',
    }));

    successResponse(res, {
      totalUsers: parseInt(usersRes.rows[0].count),
      totalTherapists: parseInt(therapistsRes.rows[0].count),
      todaySessions: parseInt(bookingsRes.rows[0].count),
      totalRevenue: parseFloat(paymentsRes.rows[0].total),
      sessionTypes: sessionTypes.length > 0 ? sessionTypes : [
        { name: 'فيديو', value: 0, color: '#1A6B72' },
        { name: 'صوتي', value: 0, color: '#F5A623' },
      ],
    });
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// GET /admin/users
exports.getUsers = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, name, phone, email, gender, role, is_active, created_at,
              (SELECT COUNT(*) FROM bookings WHERE client_id = users.id) as sessions
       FROM users WHERE role != 'admin'
       ORDER BY created_at DESC`
    );
    successResponse(res, result.rows);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// PUT /admin/users/:id/role
exports.updateUserRole = async (req, res) => {
  try {
    const { id } = req.params;
    const { role } = req.body;
    if (!['client', 'coach', 'therapist', 'admin'].includes(role)) return errorResponse(res, 'دور غير صحيح', 400);
    const result = await pool.query(
      'UPDATE users SET role=$1, updated_at=NOW() WHERE id=$2 RETURNING id, name, role',
      [role, id]
    );
    if (!result.rows[0]) return errorResponse(res, 'المستخدم غير موجود', 404);

    // If promoted to coach/therapist, ensure therapists record exists
    if (role === 'coach' || role === 'therapist') {
      await pool.query(
        `INSERT INTO therapists (user_id, is_approved)
         VALUES ($1, true)
         ON CONFLICT (user_id) DO NOTHING`,
        [id]
      );
    }

    successResponse(res, result.rows[0]);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// PUT /admin/users/:id/ban
exports.toggleBanUser = async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query(
      'UPDATE users SET is_active = NOT is_active WHERE id = $1 RETURNING id, name, is_active',
      [id]
    );
    if (!result.rows[0]) return errorResponse(res, 'المستخدم غير موجود', 404);
    successResponse(res, result.rows[0]);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// GET /admin/therapists
exports.getTherapists = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT u.id, u.name, u.phone, u.is_active, u.created_at,
              t.specializations, t.rating, t.total_sessions, t.years_experience,
              t.session_price_chat, t.session_price_voice, t.session_price_video,
              t.discount_percent, t.is_approved, t.id as therapist_id
       FROM users u
       LEFT JOIN therapists t ON t.user_id = u.id
       WHERE u.role IN ('therapist', 'coach')
       ORDER BY u.created_at DESC`
    );
    successResponse(res, result.rows);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// PUT /admin/therapists/:id/pricing
exports.updateTherapistPricing = async (req, res) => {
  try {
    const { id } = req.params;
    const { session_price_chat, session_price_voice, session_price_video } = req.body;
    const result = await pool.query(
      `UPDATE therapists SET session_price_chat=$1, session_price_voice=$2, session_price_video=$3, updated_at=NOW()
       WHERE id=$4 RETURNING id, session_price_chat, session_price_voice, session_price_video`,
      [session_price_chat, session_price_voice, session_price_video, id]
    );
    if (!result.rows[0]) return errorResponse(res, 'الكوتش غير موجود', 404);
    successResponse(res, result.rows[0], 'تم تحديث الأسعار');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// PUT /admin/therapists/:id/discount
exports.updateTherapistDiscount = async (req, res) => {
  try {
    const { id } = req.params;
    const { discount_percent } = req.body;
    if (discount_percent < 0 || discount_percent > 100) return errorResponse(res, 'الخصم يجب أن يكون بين 0 و 100', 400);
    const result = await pool.query(
      `UPDATE therapists SET discount_percent=$1, updated_at=NOW() WHERE id=$2 RETURNING id, discount_percent`,
      [discount_percent, id]
    );
    if (!result.rows[0]) return errorResponse(res, 'الكوتش غير موجود', 404);
    successResponse(res, result.rows[0], 'تم تحديث الخصم');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// PUT /admin/therapists/:id/specializations
exports.updateTherapistSpecializations = async (req, res) => {
  try {
    const { id } = req.params;
    const { specializations } = req.body;
    if (!Array.isArray(specializations)) return errorResponse(res, 'specializations يجب أن تكون مصفوفة', 400);
    const result = await pool.query(
      `UPDATE therapists SET specializations=$1, updated_at=NOW() WHERE id=$2 RETURNING id, specializations`,
      [specializations, id]
    );
    if (!result.rows[0]) return errorResponse(res, 'الكوتش غير موجود', 404);
    successResponse(res, result.rows[0], 'تم تحديث التخصص');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// PUT /admin/therapists/:id/approve
exports.toggleApproveTherapist = async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query(
      'UPDATE therapists SET is_approved = NOT is_approved WHERE id = $1 RETURNING id, is_approved',
      [id]
    );
    if (!result.rows[0]) return errorResponse(res, 'الكوتش غير موجود', 404);
    successResponse(res, result.rows[0]);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// GET /admin/bookings
exports.getBookings = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT b.id, b.session_type, b.status, b.price, b.scheduled_at, b.created_at,
              b.payment_status, b.cancelled_by,
              c.name as client_name, c.phone as client_phone,
              u.name as therapist_name,
              p.id as payment_id, p.provider as payment_provider
       FROM bookings b
       LEFT JOIN users c ON c.id = b.client_id
       LEFT JOIN therapists t ON t.id = b.therapist_id
       LEFT JOIN users u ON u.id = t.user_id
       LEFT JOIN payments p ON p.booking_id = b.id AND p.status = 'paid'
       ORDER BY b.created_at DESC
       LIMIT 100`
    );
    successResponse(res, result.rows);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// POST /admin/bookings — admin creates booking for a client
exports.createBooking = async (req, res) => {
  try {
    const { client_id, therapist_id, scheduled_at, session_type, price, payment_method } = req.body;
    if (!client_id || !therapist_id || !scheduled_at || !session_type || !price || !payment_method) {
      return errorResponse(res, 'جميع الحقول مطلوبة', 400);
    }

    // Check slot not already taken
    const conflict = await pool.query(
      `SELECT id FROM bookings
       WHERE therapist_id=$1 AND status IN ('pending','confirmed')
       AND scheduled_at BETWEEN $2::timestamptz - INTERVAL '30 minutes' AND $2::timestamptz + INTERVAL '30 minutes'`,
      [therapist_id, scheduled_at]
    );
    if (conflict.rows[0]) return errorResponse(res, 'هذا الموعد محجوز بالفعل', 400);

    const isManual = payment_method === 'manual';
    const bookingStatus = isManual ? 'confirmed' : 'pending';
    const paymentStatus = isManual ? 'paid' : 'pending';

    // Create booking
    const booking = await pool.query(
      `INSERT INTO bookings (client_id, therapist_id, session_type, scheduled_at, duration_minutes, price, status, payment_status, notes)
       VALUES ($1,$2,$3,$4,60,$5,$6,$7,'حجز من الإدارة') RETURNING *`,
      [client_id, therapist_id, session_type, scheduled_at, price, bookingStatus, paymentStatus]
    );
    const bookingId = booking.rows[0].id;

    // Create payment record
    await pool.query(
      `INSERT INTO payments (booking_id, user_id, amount, currency, provider, provider_payment_id, status)
       VALUES ($1,$2,$3,'SAR',$4,$5,$6)`,
      [bookingId, client_id, price,
        isManual ? 'manual' : 'paymob',
        isManual ? `manual_${bookingId}` : `booking_${bookingId}`,
        paymentStatus]
    );

    const { sendPushNotification, saveNotification } = require('../utils/notifications.utils');
    const notifData = { type: 'new_booking', booking_id: String(bookingId) };

    // Notify client
    const clientRes = await pool.query('SELECT fcm_token FROM users WHERE id=$1', [client_id]);
    const clientToken = clientRes.rows[0]?.fcm_token;
    const clientTitle = isManual ? '✅ تم تأكيد حجزك' : '📅 لديك حجز جديد';
    const clientBody  = isManual ? 'تم حجز جلسة لك من قِبَل الإدارة' : 'تم إنشاء حجز لك — يرجى إتمام الدفع عبر التطبيق';
    await sendPushNotification(clientToken, clientTitle, clientBody, notifData).catch(() => {});
    saveNotification(client_id, clientTitle, clientBody, 'new_booking', String(bookingId));

    // Notify coach
    const coachRes = await pool.query(
      'SELECT u.id as user_id, u.fcm_token FROM therapists t JOIN users u ON u.id=t.user_id WHERE t.id=$1',
      [therapist_id]
    );
    await sendPushNotification(coachRes.rows[0]?.fcm_token, '📅 حجز جديد من الإدارة', 'تم إضافة حجز جديد في جدولك', notifData).catch(() => {});
    saveNotification(coachRes.rows[0]?.user_id, '📅 حجز جديد من الإدارة', 'تم إضافة حجز جديد في جدولك', 'new_booking', String(bookingId));

    successResponse(res, booking.rows[0], 'تم إنشاء الحجز بنجاح');
  } catch (err) {
    console.error('❌ Admin createBooking error:', err.message);
    errorResponse(res, err.message, 500);
  }
};

// PUT /admin/bookings/:id/cancel
exports.cancelBooking = async (req, res) => {
  try {
    const { id } = req.params;
    const { refund = false } = req.body; // optional: refund paid payment too

    // End any active session for this booking
    await pool.query(
      `UPDATE sessions SET status='ended', ended_at=NOW() WHERE booking_id=$1 AND status='active'`,
      [id]
    );
    const result = await pool.query(
      `UPDATE bookings SET status='cancelled', cancelled_by='admin', updated_at=NOW()
       WHERE id=$1 AND status NOT IN ('completed','cancelled')
       RETURNING id, status`,
      [id]
    );
    if (!result.rows[0]) return errorResponse(res, 'الحجز غير موجود أو لا يمكن إلغاؤه', 400);

    // Notify client and coach about cancellation
    try {
      const { sendPushNotification, saveNotification } = require('../utils/notifications.utils');
      const bookingInfo = await pool.query(
        `SELECT b.client_id, b.therapist_id, c.fcm_token AS client_token,
                u.id AS coach_user_id, u.fcm_token AS coach_token,
                p.payment_method, p.amount
         FROM bookings b
         JOIN users c ON c.id = b.client_id
         JOIN therapists t ON t.id = b.therapist_id
         LEFT JOIN payments p ON p.booking_id = b.id AND p.status = 'paid'
         JOIN users u ON u.id = t.user_id
         WHERE b.id=$1`, [id]
      );
      if (bookingInfo.rows[0]) {
        const r = bookingInfo.rows[0];
        const notifData = { type: 'booking_cancelled', booking_id: String(id) };

        // Build client body based on payment method
        const isOnlinePayment = ['card', 'apple_pay', 'online'].includes(r.payment_method);
        const hasPaidAmount = r.amount && parseFloat(r.amount) > 0;
        const clientBody = isOnlinePayment && hasPaidAmount
          ? 'تم إلغاء جلستك من قِبَل الإدارة\nسيتم رد المبلغ خلال 5-7 أيام عمل'
          : 'تم إلغاء جلستك من قِبَل الإدارة\nللاستفسار تواصل معنا: 966536011433';

        await sendPushNotification(r.client_token, '❌ تم إلغاء موعدك', clientBody, notifData).catch(() => {});
        saveNotification(r.client_id, '❌ تم إلغاء موعدك', clientBody, 'booking_cancelled', String(id));
        await sendPushNotification(r.coach_token, '❌ تم إلغاء حجز', 'تم إلغاء أحد الحجوزات من قِبَل الإدارة\nللاستفسار تواصل معنا: 966536011433', notifData).catch(() => {});
        saveNotification(r.coach_user_id, '❌ تم إلغاء حجز', 'تم إلغاء أحد الحجوزات من قِبَل الإدارة\nللاستفسار تواصل معنا: 966536011433', 'booking_cancelled', String(id));
      }
    } catch (_) {}

    // If refund requested, trigger refund on paid payment
    if (refund) {
      const payment = await pool.query(
        `SELECT * FROM payments WHERE booking_id=$1 AND status='paid' LIMIT 1`, [id]
      );
      if (payment.rows[0]) {
        // Re-use refundPayment logic inline
        const p = payment.rows[0];
        if (p.provider === 'manual') {
          await pool.query('UPDATE payments SET status=$1 WHERE id=$2', ['refunded', p.id]);
          await pool.query('UPDATE bookings SET payment_status=$1 WHERE id=$2', ['refunded', id]);
        } else if (p.provider === 'paymob') {
          // Fire and forget — refund via Paymob (same logic as refundPayment)
          try {
            const https = require('https');
            const host = process.env.PAYMOB_HOST || 'ksa.paymob.com';
            const amountHalala = Math.round(parseFloat(p.amount) * 100);
            function paymobHttp(method, path, body, authToken) {
              return new Promise((resolve) => {
                const raw = body ? JSON.stringify(body) : null;
                const headers = { 'Content-Type': 'application/json' };
                if (authToken) headers['Authorization'] = `Bearer ${authToken}`;
                else headers['Authorization'] = `Token ${process.env.PAYMOB_SECRET_KEY}`;
                if (raw) headers['Content-Length'] = Buffer.byteLength(raw);
                const options = { hostname: host, path, method, headers };
                const r = https.request(options, (res2) => {
                  let d = '';
                  res2.on('data', (c) => (d += c));
                  res2.on('end', () => { try { resolve(JSON.parse(d)); } catch { resolve({}); } });
                });
                r.on('error', () => resolve({}));
                if (raw) r.write(raw);
                r.end();
              });
            }
            const authRes = await paymobHttp('POST', '/api/auth/tokens', { api_key: process.env.PAYMOB_API_KEY });
            const authToken = authRes.token;
            const storedId = p.provider_payment_id || '';
            const numericId = parseInt(storedId);
            let refundResult = null;
            if (!isNaN(numericId) && numericId > 0) {
              refundResult = await paymobHttp('POST', '/api/acceptance/void_refund/refund', { transaction_id: numericId, amount_cents: amountHalala }, authToken);
            }
            if (!refundResult || !refundResult.id) {
              const txnsRes = await paymobHttp('GET', `/api/acceptance/transactions?page_size=100`, null, authToken);
              const txn = (txnsRes.results || []).find(t => t.success === true && !t.is_refunded && !t.is_voided && t.amount_cents === amountHalala);
              if (txn) refundResult = await paymobHttp('POST', '/api/acceptance/void_refund/refund', { transaction_id: txn.id, amount_cents: amountHalala }, authToken);
            }
            if (refundResult && refundResult.id) {
              await pool.query('UPDATE payments SET status=$1 WHERE id=$2', ['refunded', p.id]);
              await pool.query('UPDATE bookings SET payment_status=$1 WHERE id=$2', ['refunded', id]);
            }
          } catch (refundErr) {
            console.error('⚠️ Auto-refund failed:', refundErr.message);
            // Booking is still cancelled, refund can be done manually from payments page
          }
        }
      }
    }

    successResponse(res, result.rows[0], 'تم إلغاء الحجز');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// GET /admin/content
exports.getContent = async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM content ORDER BY created_at DESC'
    );
    successResponse(res, result.rows);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// POST /admin/content
exports.createContent = async (req, res) => {
  try {
    const { title_ar, content_type, category, is_free } = req.body;
    if (!title_ar) return errorResponse(res, 'العنوان مطلوب', 400);
    const result = await pool.query(
      `INSERT INTO content (title_ar, content_type, category, is_free, is_published)
       VALUES ($1, $2, $3, $4, false) RETURNING *`,
      [title_ar, content_type || 'article', category || 'تطوير ذاتي', is_free !== false]
    );
    successResponse(res, result.rows[0], 'تمت الإضافة');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// PUT /admin/content/:id/publish
exports.togglePublishContent = async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query(
      'UPDATE content SET is_published = NOT is_published WHERE id = $1 RETURNING id, title_ar, is_published',
      [id]
    );
    if (!result.rows[0]) return errorResponse(res, 'المحتوى غير موجود', 404);
    successResponse(res, result.rows[0]);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// DELETE /admin/content/:id
exports.deleteContent = async (req, res) => {
  try {
    const { id } = req.params;
    await pool.query('DELETE FROM content WHERE id = $1', [id]);
    successResponse(res, null, 'تم الحذف');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// POST /admin/payments/:id/refund
exports.refundPayment = async (req, res) => {
  try {
    const payment = await pool.query('SELECT * FROM payments WHERE id=$1', [req.params.id]);
    if (!payment.rows[0]) return errorResponse(res, 'Payment not found', 404);
    const p = payment.rows[0];
    if (p.status === 'refunded') return errorResponse(res, 'Already refunded', 400);
    if (p.status !== 'paid') return errorResponse(res, 'Payment not paid', 400);

    // Manual payments — just mark as refunded, no Paymob call needed
    if (p.provider === 'manual') {
      await pool.query('UPDATE payments SET status=$1 WHERE id=$2', ['refunded', p.id]);
      await pool.query(
        'UPDATE bookings SET payment_status=$1 WHERE id=(SELECT booking_id FROM payments WHERE id=$2)',
        ['refunded', p.id]
      );
      return successResponse(res, null, 'تم استرداد المبلغ اليدوي بنجاح');
    }

    // Call Paymob refund API
    if (p.provider === 'paymob') {
      const https = require('https');
      const host = process.env.PAYMOB_HOST || 'ksa.paymob.com';
      const amountHalala = Math.round(parseFloat(p.amount) * 100);

      function paymobHttp(method, path, body, authToken) {
        return new Promise((resolve) => {
          const raw = body ? JSON.stringify(body) : null;
          const headers = { 'Content-Type': 'application/json' };
          if (authToken) headers['Authorization'] = `Bearer ${authToken}`;
          else headers['Authorization'] = `Token ${process.env.PAYMOB_SECRET_KEY}`;
          if (raw) headers['Content-Length'] = Buffer.byteLength(raw);
          const options = { hostname: host, path, method, headers };
          const r = https.request(options, (res2) => {
            let d = '';
            res2.on('data', (c) => (d += c));
            res2.on('end', () => {
              try { resolve(JSON.parse(d)); }
              catch { resolve({ results: [], _raw: d.slice(0, 300) }); }
            });
          });
          r.on('error', (e) => resolve({ results: [], _error: e.message }));
          if (raw) r.write(raw);
          r.end();
        });
      }

      // Get old-style auth token (needed for /api/acceptance/ endpoints)
      const authRes = await paymobHttp('POST', '/api/auth/tokens', { api_key: process.env.PAYMOB_API_KEY });
      const authToken = authRes.token;
      console.log('🔑 Paymob auth token:', authToken ? 'OK' : `FAILED: ${JSON.stringify(authRes).slice(0, 200)}`);

      const paymobGet  = (path) => paymobHttp('GET', path, null, authToken);
      const paymobPost = (path, body) => paymobHttp('POST', path, body, authToken);

      // provider_payment_id: after callback = numeric transaction ID
      //                       before callback (old payments) = merchant_order_id string
      const storedId = p.provider_payment_id || '';
      let refundResult = null;

      const numericId = parseInt(storedId);
      if (!isNaN(numericId) && numericId > 0) {
        // Stored as numeric transaction ID — refund directly
        refundResult = await paymobPost('/api/acceptance/void_refund/refund', {
          transaction_id: numericId,
          amount_cents: amountHalala,
        });
      } else {
        // Try v1 intention refund (works with _fee_... or booking_... IDs)
        const bookingRes = await pool.query('SELECT booking_id FROM payments WHERE id=$1', [p.id]);
        const bookingId = bookingRes.rows[0]?.booking_id;
        const merchantOrderId = storedId.startsWith('booking_') ? storedId : `booking_${bookingId}`;

        // 1. Try querying all transactions and find by merchant_order_id
        // Search transactions by order ID from Paymob
        const allTxns = await paymobGet(`/api/acceptance/transactions?page_size=100`);
        console.log('🔍 Total txns:', allTxns.results?.length, '| amountHalala:', amountHalala);

        // Match: success + correct amount + not refunded + not voided + no parent (primary txn)
        let txn = allTxns.results?.find(t =>
          t.success === true &&
          !t.is_refunded &&
          !t.is_voided &&
          !t.has_parent_transaction &&
          t.amount_cents === amountHalala
        );

        // Fallback: allow has_parent_transaction if still not found
        if (!txn) {
          txn = allTxns.results?.find(t =>
            t.success === true && !t.is_refunded && !t.is_voided && t.amount_cents === amountHalala
          );
        }
        console.log('🔍 txn found:', txn?.id, '| order:', txn?.order?.id);

        if (!txn?.id) {
          throw new Error('لم يتم العثور على معاملة الدفع — يرجى الاسترداد يدوياً من لوحة باي موب KSA');
        }

        // Update DB with real transaction ID
        await pool.query('UPDATE payments SET provider_payment_id=$1 WHERE id=$2', [String(txn.id), p.id]);

        refundResult = await paymobPost('/api/acceptance/void_refund/refund', {
          transaction_id: txn.id,
          amount_cents: amountHalala,
        });
      }

      console.log('Paymob refund response:', JSON.stringify(refundResult));

      if (!refundResult || refundResult.success === false || (!refundResult.id && refundResult.detail)) {
        throw new Error(refundResult?.detail || refundResult?.message || 'فشل الاسترداد عبر Paymob');
      }
    }

    await pool.query('UPDATE payments SET status=$1 WHERE id=$2', ['refunded', p.id]);
    await pool.query(
      'UPDATE bookings SET payment_status=$1 WHERE id=(SELECT booking_id FROM payments WHERE id=$2)',
      ['refunded', p.id]
    );

    successResponse(res, null, 'تم استرداد المبلغ بنجاح عبر Paymob');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// GET /admin/payments
exports.getPayments = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT p.id, p.amount, p.currency, p.provider, p.provider_payment_id,
              p.status, p.created_at,
              u.name as user_name,
              b.session_type, b.scheduled_at
       FROM payments p
       LEFT JOIN users u ON u.id = p.user_id
       LEFT JOIN bookings b ON b.id = p.booking_id
       ORDER BY p.created_at DESC
       LIMIT 200`
    );
    successResponse(res, result.rows);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// ── Questionnaire Sets (admin CRUD) ──────────────────────────────────────────

// GET /admin/questionnaire/sets
exports.getQuestionnaireSets = async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT s.*,
             COUNT(q.id) FILTER (WHERE q.is_active = true) AS question_count
      FROM questionnaire_sets s
      LEFT JOIN questionnaire_questions q ON q.set_id = s.id
      GROUP BY s.id
      ORDER BY s.created_at ASC
    `);
    successResponse(res, result.rows);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// POST /admin/questionnaire/sets
exports.createQuestionnaireSet = async (req, res) => {
  try {
    const { name, description, specialization, timing } = req.body;
    if (!name) return errorResponse(res, 'name required', 400);
    const result = await pool.query(
      `INSERT INTO questionnaire_sets (name, description, specialization, timing)
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [name, description || null, specialization || null, timing || 'general']
    );
    successResponse(res, result.rows[0], 'Set created');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// PUT /admin/questionnaire/sets/:id
exports.updateQuestionnaireSet = async (req, res) => {
  try {
    const { name, description, specialization, timing, is_active } = req.body;
    const result = await pool.query(
      `UPDATE questionnaire_sets
       SET name=COALESCE($1,name),
           description=COALESCE($2,description),
           specialization=$3,
           timing=COALESCE($4,timing),
           is_active=COALESCE($5,is_active)
       WHERE id=$6 RETURNING *`,
      [name, description || null, specialization || null, timing, is_active, req.params.id]
    );
    if (!result.rows[0]) return errorResponse(res, 'Not found', 404);
    successResponse(res, result.rows[0]);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// DELETE /admin/questionnaire/sets/:id
exports.deleteQuestionnaireSet = async (req, res) => {
  try {
    await pool.query(`DELETE FROM questionnaire_sets WHERE id=$1`, [req.params.id]);
    successResponse(res, null, 'Deleted');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// GET /admin/questionnaire/sets/:setId/questions
exports.getSetQuestions = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT * FROM questionnaire_questions WHERE set_id=$1 ORDER BY order_index ASC, created_at ASC`,
      [req.params.setId]
    );
    successResponse(res, result.rows);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// POST /admin/questionnaire/sets/:setId/questions
exports.createSetQuestion = async (req, res) => {
  try {
    const { question_text, question_type = 'text', options, order_index = 0 } = req.body;
    if (!question_text) return errorResponse(res, 'question_text required', 400);
    const result = await pool.query(
      `INSERT INTO questionnaire_questions (set_id, question_text, question_type, options, order_index)
       VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [req.params.setId, question_text, question_type, options ? JSON.stringify(options) : null, order_index]
    );
    successResponse(res, result.rows[0], 'Question created');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// PUT /admin/questionnaire/questions/:id
exports.updateSetQuestion = async (req, res) => {
  try {
    const { question_text, question_type, options, order_index, is_active } = req.body;
    const result = await pool.query(
      `UPDATE questionnaire_questions
       SET question_text=COALESCE($1,question_text),
           question_type=COALESCE($2,question_type),
           options=COALESCE($3,options),
           order_index=COALESCE($4,order_index),
           is_active=COALESCE($5,is_active)
       WHERE id=$6 RETURNING *`,
      [question_text, question_type, options ? JSON.stringify(options) : null, order_index, is_active, req.params.id]
    );
    if (!result.rows[0]) return errorResponse(res, 'Not found', 404);
    successResponse(res, result.rows[0]);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// DELETE /admin/questionnaire/questions/:id
exports.deleteSetQuestion = async (req, res) => {
  try {
    await pool.query(`DELETE FROM questionnaire_questions WHERE id=$1`, [req.params.id]);
    successResponse(res, null, 'Deleted');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// GET /admin/questionnaire/responses — all clients who submitted
exports.getQuestionnaireResponses = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT u.id as client_id, u.name, u.phone,
              COUNT(r.id) as answered_count,
              MAX(r.created_at) as submitted_at
       FROM questionnaire_responses r
       JOIN users u ON u.id = r.client_id
       GROUP BY u.id, u.name, u.phone
       ORDER BY submitted_at DESC`
    );
    successResponse(res, result.rows);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// GET /admin/payout-requests
exports.getPayoutRequests = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT pr.*, u.name as coach_name, u.phone as coach_phone
       FROM payout_requests pr
       JOIN therapists t ON t.id = pr.therapist_id
       JOIN users u ON u.id = t.user_id
       ORDER BY pr.requested_at DESC`
    );
    successResponse(res, result.rows);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// POST /admin/payout-requests/:id/mark-paid
exports.markPayoutRequestPaid = async (req, res) => {
  try {
    const { admin_note } = req.body;
    const result = await pool.query(
      `UPDATE payout_requests SET status='paid', paid_at=NOW(), admin_note=$2
       WHERE id=$1 AND status='pending' RETURNING *`,
      [req.params.id, admin_note || null]
    );
    if (!result.rows[0]) return errorResponse(res, 'الطلب غير موجود أو تم معالجته', 404);

    // Mark related payments as payout_status='paid'
    const pr = result.rows[0];
    await pool.query(
      `UPDATE payments SET payout_status='paid', payout_date=NOW()
       WHERE booking_id IN (SELECT id FROM bookings WHERE therapist_id=$1)
       AND status='paid' AND payout_status='pending'`,
      [pr.therapist_id]
    );

    // Notify coach
    try {
      const coachRes = await pool.query(
        'SELECT u.fcm_token FROM therapists t JOIN users u ON u.id=t.user_id WHERE t.id=$1',
        [pr.therapist_id]
      );
      if (coachRes.rows[0]?.fcm_token) {
        const { sendPushNotification } = require('../utils/notifications.utils');
        await sendPushNotification(
          coachRes.rows[0].fcm_token,
          'تم تحويل مستحقاتك',
          `تم تحويل ${pr.amount} ر.س إلى حسابك البنكي`,
          { type: 'payout_paid' }
        );
      }
    } catch (_) {}

    successResponse(res, result.rows[0], 'تم تأكيد التحويل وإشعار الكوتش');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// PUT /admin/therapists/:id/commission-rate
exports.updateCoachRate = async (req, res) => {
  try {
    const { coach_rate } = req.body;
    const rate = parseInt(coach_rate);
    if (isNaN(rate) || rate < 0 || rate > 100) return errorResponse(res, 'نسبة غير صالحة (0-100)', 400);
    const result = await pool.query(
      'UPDATE therapists SET coach_rate=$1 WHERE id=$2 RETURNING id, coach_rate',
      [rate, req.params.id]
    );
    if (!result.rows[0]) return errorResponse(res, 'الكوتش غير موجود', 404);
    successResponse(res, result.rows[0], 'تم تحديث نسبة الكوتش');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// GET /admin/payouts — aggregate unpaid earnings per coach
exports.getCoachPayouts = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT
         t.id as therapist_id,
         u.name as coach_name,
         u.phone as coach_phone,
         t.coach_rate,
         COALESCE(SUM(CASE WHEN p.payout_status='pending' THEN p.coach_amount ELSE 0 END), 0) as pending_amount,
         COALESCE(SUM(CASE WHEN p.payout_status='paid' THEN p.coach_amount ELSE 0 END), 0) as paid_amount,
         COUNT(CASE WHEN p.payout_status='pending' THEN 1 END) as pending_sessions,
         MAX(p.payout_date) as last_payout_date
       FROM therapists t
       JOIN users u ON u.id = t.user_id
       LEFT JOIN bookings b ON b.therapist_id = t.id
       LEFT JOIN payments p ON p.booking_id = b.id AND p.status='paid'
       GROUP BY t.id, u.name, u.phone, t.coach_rate
       ORDER BY pending_amount DESC`
    );
    successResponse(res, result.rows);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// POST /admin/payouts/:therapistId/mark-paid — mark all pending payments as paid out
exports.markPayoutPaid = async (req, res) => {
  try {
    const { therapistId } = req.params;
    const { note } = req.body;

    const result = await pool.query(
      `UPDATE payments SET payout_status='paid', payout_date=NOW()
       WHERE booking_id IN (SELECT id FROM bookings WHERE therapist_id=$1)
       AND status='paid' AND payout_status='pending'
       RETURNING id`,
      [therapistId]
    );

    successResponse(res, { updated: result.rowCount, note }, `تم تأكيد تحويل ${result.rowCount} دفعة`);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};
