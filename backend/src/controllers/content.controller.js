const pool = require('../config/database');
const { successResponse, errorResponse } = require('../utils/response.utils');

exports.getContent = async (req, res) => {
  try {
    const { type, category, page = 1, limit = 10 } = req.query;
    const offset = (page - 1) * limit;

    let query = 'SELECT * FROM content WHERE is_published=true';
    const params = [];
    let idx = 1;

    if (type) { query += ` AND content_type=$${idx}`; params.push(type); idx++; }
    if (category) { query += ` AND category=$${idx}`; params.push(category); idx++; }

    query += ` ORDER BY created_at DESC LIMIT $${idx} OFFSET $${idx + 1}`;
    params.push(limit, offset);

    const result = await pool.query(query, params);
    successResponse(res, result.rows);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

exports.getContentById = async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM content WHERE id=$1 AND is_published=true', [req.params.id]);
    if (!result.rows[0]) return errorResponse(res, 'Content not found', 404);
    successResponse(res, result.rows[0]);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

exports.getCategories = async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT DISTINCT category FROM content WHERE is_published=true AND category IS NOT NULL ORDER BY category'
    );
    successResponse(res, result.rows.map(r => r.category));
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};
