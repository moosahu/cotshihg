const express = require('express');
const router = express.Router();
const bookingController = require('../controllers/booking.controller');
const { authenticate, authorize } = require('../middleware/auth.middleware');

router.post('/', authenticate, authorize('client'), bookingController.createBooking);
router.post('/instant', authenticate, authorize('client'), bookingController.createInstantBooking);
router.get('/', authenticate, bookingController.getMyBookings);
router.get('/:id', authenticate, bookingController.getBookingById);
router.put('/:id/confirm', authenticate, authorize('therapist', 'coach'), bookingController.confirmBooking);
router.put('/:id/confirm-payment', authenticate, authorize('client'), bookingController.confirmAfterPayment);
router.put('/:id/cancel', authenticate, bookingController.cancelBooking);
router.post('/:id/review', authenticate, authorize('client'), bookingController.submitReview);

module.exports = router;
