const express = require('express');
const router = express.Router();
const therapistController = require('../controllers/therapist.controller');
const { authenticate, authorize } = require('../middleware/auth.middleware');

router.get('/', authenticate, therapistController.getTherapists);
router.get('/me/availability', authenticate, authorize('coach', 'therapist'), therapistController.getMyAvailability);
router.get('/:id', authenticate, therapistController.getTherapistById);
router.get('/:id/availability', authenticate, therapistController.getAvailability);
router.get('/:id/reviews', authenticate, therapistController.getReviews);
router.put('/profile', authenticate, authorize('coach', 'therapist'), therapistController.updateProfile);
router.put('/availability', authenticate, authorize('coach', 'therapist'), therapistController.updateAvailability);
router.put('/instant-availability', authenticate, authorize('coach', 'therapist'), therapistController.toggleInstantAvailability);

module.exports = router;
