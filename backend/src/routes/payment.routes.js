const express = require('express');
const router = express.Router();
const paymentController = require('../controllers/payment.controller');
const { authenticate } = require('../middleware/auth.middleware');

// Webhook must use raw body (before JSON parsing)
router.post('/webhook', express.raw({ type: 'application/json' }), paymentController.webhook);

router.post('/initiate', authenticate, paymentController.initiatePayment);
router.get('/history', authenticate, paymentController.getPaymentHistory);

module.exports = router;
