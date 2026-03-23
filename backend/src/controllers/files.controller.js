const pool = require('../config/database');
const { successResponse, errorResponse } = require('../utils/response.utils');
const multer = require('multer');
const { CloudinaryStorage } = require('multer-storage-cloudinary');
const cloudinary = require('cloudinary').v2;

// ── Cloudinary config (env vars set in Render dashboard) ─────────────────────
cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key:    process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

const storage = new CloudinaryStorage({
  cloudinary,
  params: async (req, file) => ({
    folder: `coaching/bookings/${req.params.bookingId}`,
    resource_type: file.mimetype === 'application/pdf' ? 'raw' : 'image',
    public_id: `${Date.now()}-${file.originalname.replace(/[^a-zA-Z0-9.\-_]/g, '_')}`,
    allowed_formats: ['pdf', 'jpg', 'jpeg', 'png'],
  }),
});

const upload = multer({
  storage,
  limits: { fileSize: 20 * 1024 * 1024 }, // 20 MB
  fileFilter: (req, file, cb) => {
    const allowed = ['application/pdf', 'image/jpeg', 'image/png', 'image/jpg'];
    if (allowed.includes(file.mimetype)) cb(null, true);
    else cb(new Error('Only PDF and images are allowed'), false);
  },
});

exports.uploadMiddleware = upload.single('file');

// POST /api/v1/files/upload/:bookingId
exports.uploadFile = async (req, res) => {
  try {
    if (!req.file) return errorResponse(res, 'No file uploaded or invalid type', 400);
    const { bookingId } = req.params;

    const booking = await pool.query(
      `SELECT b.* FROM bookings b
       WHERE b.id=$1 AND (b.client_id=$2 OR b.therapist_id=(SELECT id FROM therapists WHERE user_id=$2))`,
      [bookingId, req.user.id]
    );
    if (!booking.rows[0]) return errorResponse(res, 'Booking not found', 404);

    // Cloudinary returns the public URL in req.file.path
    const result = await pool.query(
      `INSERT INTO session_files (booking_id, uploaded_by, file_name, file_path, file_size, mime_type)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
      [bookingId, req.user.id, req.file.originalname, req.file.path, req.file.size, req.file.mimetype]
    );

    successResponse(res, { ...result.rows[0], file_url: req.file.path }, 'File uploaded');
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
    // file_path IS the Cloudinary URL
    const rows = files.rows.map(f => ({ ...f, file_url: f.file_path }));
    successResponse(res, rows);
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

    // Delete from Cloudinary
    try {
      const url = file.rows[0].file_path;
      const match = url.match(/\/upload\/(?:v\d+\/)?(.+?)(?:\.[^.]+)?$/);
      if (match) {
        const isPdf = file.rows[0].mime_type === 'application/pdf';
        await cloudinary.uploader.destroy(match[1], {
          resource_type: isPdf ? 'raw' : 'image',
        });
      }
    } catch (_) { /* non-fatal */ }

    await pool.query(`DELETE FROM session_files WHERE id=$1`, [req.params.fileId]);
    successResponse(res, null, 'File deleted');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};
