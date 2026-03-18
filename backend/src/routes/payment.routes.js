const express = require('express');
const router = express.Router();
const paymentController = require('../controllers/payment.controller');
const { authenticate } = require('../middleware/auth.middleware');

router.post('/initiate', authenticate, paymentController.initiatePayment);
router.post('/callback', paymentController.paymentCallback);
router.get('/history', authenticate, paymentController.getPaymentHistory);

module.exports = router;
