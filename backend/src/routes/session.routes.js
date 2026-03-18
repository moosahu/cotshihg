const express = require('express');
const router = express.Router();
const sessionController = require('../controllers/session.controller');
const { authenticate } = require('../middleware/auth.middleware');

router.post('/:bookingId/start', authenticate, sessionController.startSession);
router.post('/:id/end', authenticate, sessionController.endSession);
router.get('/:bookingId/token', authenticate, sessionController.getAgoraToken);

module.exports = router;
