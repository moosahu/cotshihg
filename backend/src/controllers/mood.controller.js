const pool = require('../config/database');
const { successResponse, errorResponse } = require('../utils/response.utils');

exports.logMood = async (req, res) => {
  try {
    const { mood_score, mood_label, note } = req.body;

    const result = await pool.query(
      'INSERT INTO mood_logs (user_id, mood_score, mood_label, note) VALUES ($1,$2,$3,$4) RETURNING *',
      [req.user.id, mood_score, mood_label, note]
    );

    successResponse(res, result.rows[0], 'Mood logged', 201);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

exports.getMoodHistory = async (req, res) => {
  try {
    const { days = 30 } = req.query;

    const result = await pool.query(
      `SELECT * FROM mood_logs
       WHERE user_id=$1 AND logged_at >= NOW() - INTERVAL '${parseInt(days)} days'
       ORDER BY logged_at DESC`,
      [req.user.id]
    );

    successResponse(res, result.rows);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

exports.getMoodStats = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT
         AVG(mood_score) as average_mood,
         MIN(mood_score) as min_mood,
         MAX(mood_score) as max_mood,
         COUNT(*) as total_entries,
         DATE_TRUNC('week', logged_at) as week,
         AVG(mood_score) as weekly_avg
       FROM mood_logs
       WHERE user_id=$1 AND logged_at >= NOW() - INTERVAL '90 days'
       GROUP BY DATE_TRUNC('week', logged_at)
       ORDER BY week DESC`,
      [req.user.id]
    );

    successResponse(res, result.rows);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};
