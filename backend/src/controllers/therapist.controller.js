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
        'INSERT INTO therapist_availability (therapist_id, day_of_week, start_time, end_time) VALUES ($1,$2,$3,$4)',
        [therapistId, slot.day_of_week, slot.start_time, slot.end_time]
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
