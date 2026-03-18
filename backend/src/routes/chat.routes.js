const express = require('express');
const router = express.Router();
const chatController = require('../controllers/chat.controller');
const { authenticate } = require('../middleware/auth.middleware');

router.get('/:bookingId/messages', authenticate, chatController.getMessages);
router.post('/:bookingId/messages', authenticate, chatController.sendMessage);
router.put('/:bookingId/read', authenticate, chatController.markAsRead);

module.exports = router;
