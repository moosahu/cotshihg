const express = require('express');
const router = express.Router();
const therapistController = require('../controllers/therapist.controller');
const { authenticate, authorize } = require('../middleware/auth.middleware');

router.get('/', authenticate, therapistController.getTherapists);
router.get('/:id', authenticate, therapistController.getTherapistById);
router.get('/:id/availability', authenticate, therapistController.getAvailability);
router.get('/:id/reviews', authenticate, therapistController.getReviews);
router.put('/profile', authenticate, authorize('therapist'), therapistController.updateProfile);
router.put('/availability', authenticate, authorize('therapist'), therapistController.updateAvailability);
router.put('/instant-availability', authenticate, authorize('therapist'), therapistController.toggleInstantAvailability);

module.exports = router;
