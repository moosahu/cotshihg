const pool = require('../config/database');
const { successResponse, errorResponse } = require('../utils/response.utils');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

const uploadDir = path.join(__dirname, '../../uploads');
if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => {
    const unique = Date.now() + '-' + Math.round(Math.random() * 1e9);
    cb(null, unique + path.extname(file.originalname));
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 20 * 1024 * 1024 }, // 20MB
  fileFilter: (req, file, cb) => {
    const allowed = ['application/pdf', 'image/jpeg', 'image/png', 'image/jpg'];
    cb(null, allowed.includes(file.mimetype));
  },
});

exports.uploadMiddleware = upload.single('file');

// POST /api/v1/files/upload/:bookingId  (coach or client)
exports.uploadFile = async (req, res) => {
  try {
    if (!req.file) return errorResponse(res, 'No file uploaded or invalid type', 400);
    const { bookingId } = req.params;

    // Verify access to booking
    const booking = await pool.query(
      `SELECT b.* FROM bookings b
       WHERE b.id=$1 AND (b.client_id=$2 OR b.therapist_id=(SELECT id FROM therapists WHERE user_id=$2))`,
      [bookingId, req.user.id]
    );
    if (!booking.rows[0]) return errorResponse(res, 'Booking not found', 404);

    const result = await pool.query(
      `INSERT INTO session_files (booking_id, uploaded_by, file_name, file_path, file_size, mime_type)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
      [bookingId, req.user.id, req.file.originalname, req.file.filename, req.file.size, req.file.mimetype]
    );

    successResponse(res, result.rows[0], 'File uploaded');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// GET /api/v1/files/booking/:bookingId
exports.getBookingFiles = async (req, res) => {
  try {
    const { bookingId } = req.params;
    const booking = await pool.query(
      `SELECT b.* FROM bookings b
       WHERE b.id=$1 AND (b.client_id=$2 OR b.therapist_id=(SELECT id FROM therapists WHERE user_id=$2))`,
      [bookingId, req.user.id]
    );
    if (!booking.rows[0]) return errorResponse(res, 'Booking not found', 404);

    const files = await pool.query(
      `SELECT f.*, u.name AS uploader_name FROM session_files f
       JOIN users u ON u.id = f.uploaded_by
       WHERE f.booking_id=$1 ORDER BY f.created_at DESC`,
      [bookingId]
    );
    successResponse(res, files.rows);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// GET /api/v1/files/download/:fileId  — serves the file
exports.downloadFile = async (req, res) => {
  try {
    const file = await pool.query(`SELECT * FROM session_files WHERE id=$1`, [req.params.fileId]);
    if (!file.rows[0]) return errorResponse(res, 'File not found', 404);

    // Verify access
    const access = await pool.query(
      `SELECT b.* FROM bookings b WHERE b.id=$1 AND (b.client_id=$2 OR b.therapist_id=(SELECT id FROM therapists WHERE user_id=$2))`,
      [file.rows[0].booking_id, req.user.id]
    );
    if (!access.rows[0]) return errorResponse(res, 'Access denied', 403);

    const filePath = path.join(uploadDir, file.rows[0].file_path);
    if (!fs.existsSync(filePath)) return errorResponse(res, 'File not found on disk', 404);

    res.setHeader('Content-Disposition', `inline; filename="${file.rows[0].file_name}"`);
    res.setHeader('Content-Type', file.rows[0].mime_type);
    fs.createReadStream(filePath).pipe(res);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// DELETE /api/v1/files/:fileId
exports.deleteFile = async (req, res) => {
  try {
    const file = await pool.query(
      `SELECT * FROM session_files WHERE id=$1 AND uploaded_by=$2`,
      [req.params.fileId, req.user.id]
    );
    if (!file.rows[0]) return errorResponse(res, 'File not found', 404);

    const filePath = path.join(uploadDir, file.rows[0].file_path);
    if (fs.existsSync(filePath)) fs.unlinkSync(filePath);

    await pool.query(`DELETE FROM session_files WHERE id=$1`, [req.params.fileId]);
    successResponse(res, null, 'File deleted');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};
