const pool = require('../config/database');
const { successResponse, errorResponse } = require('../utils/response.utils');

exports.getTherapists = async (req, res) => {
  try {
    const { specialization, gender, language, min_price, max_price, instant, page = 1, limit = 10 } = req.query;
    const offset = (page - 1) * limit;

    let query = `
      SELECT t.*, u.name, u.avatar_url, u.gender
      FROM therapists t
      JOIN users u ON u.id = t.user_id
      WHERE t.is_approved = true AND u.is_active = true
    `;
    const params = [];
    let paramIndex = 1;

    if (specialization) {
      query += ` AND $${paramIndex} = ANY(t.specializations)`;
      params.push(specialization);
      paramIndex++;
    }
    if (gender) {
      query += ` AND u.gender = $${paramIndex}`;
      params.push(gender);
      paramIndex++;
    }
    if (instant === 'true') {
      query += ` AND t.is_available_instant = true`;
    }
    if (min_price) {
      query += ` AND t.session_price_video >= $${paramIndex}`;
      params.push(min_price);
      paramIndex++;
    }
    if (max_price) {
      query += ` AND t.session_price_video <= $${paramIndex}`;
      params.push(max_price);
      paramIndex++;
    }

    query += ` ORDER BY t.rating DESC LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
    params.push(limit, offset);

    const result = await pool.query(query, params);
    successResponse(res, result.rows);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

exports.getTherapistById = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT t.*, u.name, u.avatar_url, u.gender
       FROM therapists t JOIN users u ON u.id = t.user_id
       WHERE t.id = $1 AND t.is_approved = true`,
      [req.params.id]
    );
    if (!result.rows[0]) return errorResponse(res, 'Therapist not found', 404);
    successResponse(res, result.rows[0]);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

exports.getAvailability = async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM therapist_availability WHERE therapist_id=$1 AND is_active=true ORDER BY day_of_week, start_time',
      [req.params.id]
    );
    successResponse(res, result.rows);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

exports.getBookedSlots = async (req, res) => {
  try {
    // Return scheduled_at for all pending/confirmed bookings in the next 30 days
    const result = await pool.query(
      `SELECT scheduled_at FROM bookings
       WHERE therapist_id=$1
         AND status IN ('pending','confirmed')
         AND scheduled_at >= NOW()
         AND scheduled_at <= NOW() + INTERVAL '30 days'`,
      [req.params.id]
    );
    const slots = result.rows.map(r => r.scheduled_at);
    successResponse(res, slots);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

exports.getReviews = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT r.*, u.name, u.avatar_url
       FROM reviews r JOIN users u ON u.id = r.client_id
       WHERE r.therapist_id=$1 ORDER BY r.created_at DESC LIMIT 20`,
      [req.params.id]
    );
    successResponse(res, result.rows);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

exports.updateProfile = async (req, res) => {
  try {
    const { bio, specializations, languages, years_experience, education, session_price_chat, session_price_voice, session_price_video } = req.body;

    let therapistResult = await pool.query('SELECT * FROM therapists WHERE user_id=$1', [req.user.id]);

    if (!therapistResult.rows[0]) {
      therapistResult = await pool.query(
        `INSERT INTO therapists (user_id, bio, specializations, languages, years_experience, education, session_price_chat, session_price_voice, session_price_video)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING *`,
        [req.user.id, bio, specializations, languages, years_experience, education, session_price_chat, session_price_voice, session_price_video]
      );
    } else {
      therapistResult = await pool.query(
        `UPDATE therapists SET bio=$1, specializations=$2, languages=$3, years_experience=$4, education=$5,
         session_price_chat=$6, session_price_voice=$7, session_price_video=$8, updated_at=NOW()
         WHERE user_id=$9 RETURNING *`,
        [bio, specializations, languages, years_experience, education, session_price_chat, session_price_voice, session_price_video, req.user.id]
      );
    }

    successResponse(res, therapistResult.rows[0], 'Profile updated');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

exports.getMyAvailability = async (req, res) => {
  try {
    const therapistResult = await pool.query('SELECT id FROM therapists WHERE user_id=$1', [req.user.id]);
    if (!therapistResult.rows[0]) return successResponse(res, []);
    const result = await pool.query(
      'SELECT * FROM therapist_availability WHERE therapist_id=$1 AND is_active=true ORDER BY day_of_week, start_time',
      [therapistResult.rows[0].id]
    );
    successResponse(res, result.rows);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

exports.updateAvailability = async (req, res) => {
  try {
    const { availability } = req.body; // array of { day_of_week, start_time, end_time }
    const therapistResult = await pool.query('SELECT id FROM therapists WHERE user_id=$1', [req.user.id]);
    if (!therapistResult.rows[0]) return errorResponse(res, 'Therapist profile not found', 404);

    const therapistId = therapistResult.rows[0].id;

    // Delete existing and re-insert
    await pool.query('DELETE FROM therapist_availability WHERE therapist_id=$1', [therapistId]);

    for (const slot of availability) {
      await pool.query(
        'INSERT INTO therapist_availability (therapist_id, day_of_week, start_time, end_time, specific_date) VALUES ($1,$2,$3,$4,$5)',
        [therapistId, slot.day_of_week, slot.start_time, slot.end_time, slot.specific_date || null]
      );
    }

    successResponse(res, null, 'Availability updated');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

exports.toggleInstantAvailability = async (req, res) => {
  try {
    const { is_available } = req.body;
    await pool.query(
      'UPDATE therapists SET is_available_instant=$1 WHERE user_id=$2',
      [is_available, req.user.id]
    );
    successResponse(res, null, `Instant availability ${is_available ? 'enabled' : 'disabled'}`);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// PUT /therapists/bank-details
exports.updateBankDetails = async (req, res) => {
  try {
    const { iban, bank_name, account_holder } = req.body;
    if (!iban) return errorResponse(res, 'IBAN مطلوب', 400);
    const cleaned = iban.replace(/\s/g, '').toUpperCase();
    if (!/^SA\d{22}$/.test(cleaned)) return errorResponse(res, 'IBAN غير صالح — يجب أن يبدأ بـ SA ويتكون من 24 رقماً', 400);

    await pool.query(
      'UPDATE therapists SET iban=$1, bank_name=$2, account_holder=$3 WHERE user_id=$4',
      [cleaned, bank_name || null, account_holder || null, req.user.id]
    );
    successResponse(res, { iban: cleaned, bank_name, account_holder }, 'تم حفظ بيانات البنك');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// GET /therapists/bank-details
exports.getBankDetails = async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT iban, bank_name, account_holder FROM therapists WHERE user_id=$1',
      [req.user.id]
    );
    successResponse(res, result.rows[0] || {});
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// POST /therapists/request-payout  (min 100 SAR)
exports.requestPayout = async (req, res) => {
  const MIN_PAYOUT = 100;
  try {
    const therapistRes = await pool.query(
      'SELECT id, iban, bank_name, account_holder, coach_rate FROM therapists WHERE user_id=$1',
      [req.user.id]
    );
    if (!therapistRes.rows[0]) return errorResponse(res, 'الملف الشخصي غير مكتمل', 404);
    const t = therapistRes.rows[0];

    if (!t.iban) return errorResponse(res, 'يرجى إضافة بيانات البنك (IBAN) أولاً', 400);

    // Check for existing pending request
    const existing = await pool.query(
      "SELECT id FROM payout_requests WHERE therapist_id=$1 AND status='pending'",
      [t.id]
    );
    if (existing.rows[0]) return errorResponse(res, 'يوجد طلب سحب معلق بالفعل', 400);

    // Calculate pending amount
    const coachRate = parseInt(t.coach_rate) || 70;
    const earningsRes = await pool.query(
      `SELECT COALESCE(SUM(
         CASE WHEN p.coach_amount > 0 THEN p.coach_amount
              ELSE p.amount * $2 / 100.0
         END
       ), 0) as pending
       FROM payments p
       JOIN bookings b ON b.id = p.booking_id
       WHERE b.therapist_id=$1 AND p.status='paid' AND p.payout_status='pending'`,
      [t.id, coachRate]
    );
    const pending = parseFloat(earningsRes.rows[0].pending);

    if (pending < MIN_PAYOUT) {
      return errorResponse(res, `الحد الأدنى للسحب ${MIN_PAYOUT} ر.س — رصيدك الحالي ${pending.toFixed(2)} ر.س`, 400);
    }

    const req2 = await pool.query(
      `INSERT INTO payout_requests (therapist_id, amount, iban, bank_name, account_holder)
       VALUES ($1,$2,$3,$4,$5) RETURNING *`,
      [t.id, pending.toFixed(2), t.iban, t.bank_name, t.account_holder]
    );

    successResponse(res, req2.rows[0], 'تم إرسال طلب السحب — سيتم التحويل خلال 1-3 أيام عمل');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// GET /therapists/payout-requests
exports.getMyPayoutRequests = async (req, res) => {
  try {
    const therapistRes = await pool.query('SELECT id FROM therapists WHERE user_id=$1', [req.user.id]);
    if (!therapistRes.rows[0]) return successResponse(res, []);

    const result = await pool.query(
      'SELECT * FROM payout_requests WHERE therapist_id=$1 ORDER BY requested_at DESC',
      [therapistRes.rows[0].id]
    );
    successResponse(res, result.rows);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};
