const express = require('express');
const router = express.Router();
const rateLimit = require('express-rate-limit');
const authController = require('../controllers/auth.controller');
const { authenticate } = require('../middleware/auth.middleware');

// Strict limiter for OTP — 5 requests per 15 min per IP
const otpLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  message: { success: false, message: 'طلبات كثيرة جداً، حاول بعد 15 دقيقة' },
  standardHeaders: true,
  legacyHeaders: false,
});

router.post('/send-otp', otpLimiter, authController.sendOTP);
router.post('/verify-otp', authController.verifyOTP);
router.post('/register', authenticate, authController.register);
router.post('/refresh-token', authController.refreshToken);
router.post('/logout', authenticate, authController.logout);

module.exports = router;
