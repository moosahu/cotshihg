const express = require('express');
const router = express.Router();
const { authenticate } = require('../middleware/auth.middleware');
const ctrl = require('../controllers/questionnaire.controller');

// Templates (coach)
router.post('/', authenticate, ctrl.createTemplate);
router.get('/', authenticate, ctrl.getMyTemplates);
router.put('/:id', authenticate, ctrl.updateTemplate);
router.delete('/:id', authenticate, ctrl.deleteTemplate);
router.put('/:id/set-default', authenticate, ctrl.setDefault);

// Assignments
router.post('/:templateId/assign/:bookingId', authenticate, ctrl.assignToBooking);
router.get('/assignments/booking/:bookingId', authenticate, ctrl.getBookingAssignments);
router.post('/assignments/:assignmentId/respond', authenticate, ctrl.submitAnswers);
router.get('/assignments/:assignmentId', authenticate, ctrl.getAssignment);

// Questionnaire sets & client fill
router.get('/sets', authenticate, ctrl.getActiveSets);
router.get('/sets/:setId/questions', authenticate, ctrl.getSetQuestionsForClient);
router.get('/my-response', authenticate, ctrl.getMyResponse);
router.post('/submit', authenticate, ctrl.submitResponse);
router.get('/client/:clientId', authenticate, ctrl.getClientResponse);

// Legacy flat questions route (kept for backward compat)
router.get('/questions', authenticate, ctrl.getActiveQuestions);

module.exports = router;
