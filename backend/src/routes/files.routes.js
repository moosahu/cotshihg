const express = require('express');
const router = express.Router();
const { authenticate } = require('../middleware/auth.middleware');
const ctrl = require('../controllers/files.controller');

router.post('/upload/:bookingId', authenticate, ctrl.uploadMiddleware, ctrl.uploadFile);
router.get('/booking/:bookingId', authenticate, ctrl.getBookingFiles);
router.delete('/:fileId', authenticate, ctrl.deleteFile);

module.exports = router;
