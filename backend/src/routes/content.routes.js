const express = require('express');
const router = express.Router();
const contentController = require('../controllers/content.controller');
const { authenticate } = require('../middleware/auth.middleware');

router.get('/', authenticate, contentController.getContent);
router.get('/:id', authenticate, contentController.getContentById);
router.get('/categories', authenticate, contentController.getCategories);

module.exports = router;
