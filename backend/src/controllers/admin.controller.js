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
    const [usersRes, therapistsRes, bookingsRes, paymentsRes] = await Promise.all([
      pool.query("SELECT COUNT(*) FROM users WHERE role != 'admin'"),
      pool.query("SELECT COUNT(*) FROM users WHERE role = 'therapist'"),
      pool.query("SELECT COUNT(*) FROM bookings WHERE DATE(created_at) = CURRENT_DATE"),
      pool.query("SELECT COALESCE(SUM(amount),0) as total FROM payments WHERE status = 'completed'"),
    ]);

    successResponse(res, {
      totalUsers: parseInt(usersRes.rows[0].count),
      totalTherapists: parseInt(therapistsRes.rows[0].count),
      todaySessions: parseInt(bookingsRes.rows[0].count),
      totalRevenue: parseFloat(paymentsRes.rows[0].total),
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
              c.name as client_name, c.phone as client_phone,
              u.name as therapist_name
       FROM bookings b
       LEFT JOIN users c ON c.id = b.client_id
       LEFT JOIN therapists t ON t.id = b.therapist_id
       LEFT JOIN users u ON u.id = t.user_id
       ORDER BY b.created_at DESC
       LIMIT 100`
    );
    successResponse(res, result.rows);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// PUT /admin/bookings/:id/cancel
exports.cancelBooking = async (req, res) => {
  try {
    const { id } = req.params;
    // End any active session for this booking
    await pool.query(
      `UPDATE sessions SET status='ended', ended_at=NOW() WHERE booking_id=$1 AND status='active'`,
      [id]
    );
    const result = await pool.query(
      `UPDATE bookings SET status='cancelled', updated_at=NOW()
       WHERE id=$1 AND status NOT IN ('completed','cancelled')
       RETURNING id, status`,
      [id]
    );
    if (!result.rows[0]) return errorResponse(res, 'الحجز غير موجود أو لا يمكن إلغاؤه', 400);
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

    // Paymob refund: mark as refunded in DB.
    // Full refund via Paymob dashboard or Paymob refund API can be added here if needed.
    await pool.query('UPDATE payments SET status=$1 WHERE id=$2', ['refunded', p.id]);
    await pool.query(
      'UPDATE bookings SET payment_status=$1 WHERE id=(SELECT booking_id FROM payments WHERE id=$2)',
      ['refunded', p.id]
    );

    successResponse(res, null, 'تم استرداد المبلغ بنجاح');
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
