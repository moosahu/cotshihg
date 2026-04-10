const pool = require('../config/database');
const { successResponse, errorResponse } = require('../utils/response.utils');

// GET /api/v1/announcements/active  (public — called by the app on startup)
exports.getActive = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT * FROM announcements WHERE is_active = true ORDER BY created_at DESC LIMIT 1`
    );
    successResponse(res, result.rows[0] || null);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// GET /api/v1/admin/announcements
exports.getAll = async (req, res) => {
  try {
    const result = await pool.query(`SELECT * FROM announcements ORDER BY created_at DESC`);
    successResponse(res, result.rows);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// POST /api/v1/admin/announcements
exports.create = async (req, res) => {
  try {
    const { title, body, image_url, button_text, button_url } = req.body;
    if (!title) return errorResponse(res, 'title is required', 400);
    const result = await pool.query(
      `INSERT INTO announcements (title, body, image_url, button_text, button_url)
       VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [title, body || null, image_url || null, button_text || null, button_url || null]
    );
    successResponse(res, result.rows[0], 'Announcement created');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// PUT /api/v1/admin/announcements/:id
exports.update = async (req, res) => {
  try {
    const { title, body, image_url, button_text, button_url, is_active } = req.body;
    const result = await pool.query(
      `UPDATE announcements
       SET title=COALESCE($1,title), body=COALESCE($2,body),
           image_url=COALESCE($3,image_url), button_text=COALESCE($4,button_text),
           button_url=COALESCE($5,button_url),
           is_active=COALESCE($6,is_active)
       WHERE id=$7 RETURNING *`,
      [title, body, image_url, button_text, button_url, is_active, req.params.id]
    );
    if (!result.rows[0]) return errorResponse(res, 'Not found', 404);
    successResponse(res, result.rows[0], 'Updated');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// DELETE /api/v1/admin/announcements/:id
exports.remove = async (req, res) => {
  try {
    const result = await pool.query(
      `DELETE FROM announcements WHERE id=$1 RETURNING id`, [req.params.id]
    );
    if (!result.rows[0]) return errorResponse(res, 'Not found', 404);
    successResponse(res, null, 'Deleted');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};
