const express = require('express');
const router = express.Router();
const moodController = require('../controllers/mood.controller');
const { authenticate } = require('../middleware/auth.middleware');

router.post('/', authenticate, moodController.logMood);
router.get('/', authenticate, moodController.getMoodHistory);
router.get('/stats', authenticate, moodController.getMoodStats);

module.exports = router;
