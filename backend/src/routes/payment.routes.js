const express = require('express');
const router = express.Router();
const paymentController = require('../controllers/payment.controller');
const { authenticate } = require('../middleware/auth.middleware');

// Paymob transaction callback (called by Paymob server — no auth)
router.post('/callback', paymentController.callback);

router.post('/initiate', authenticate, paymentController.initiatePayment);
router.get('/history', authenticate, paymentController.getPaymentHistory);

module.exports = router;
