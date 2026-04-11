const express = require('express');
const router = express.Router();
const adminController = require('../controllers/admin.controller');
const therapistController = require('../controllers/therapist.controller');
const jwt = require('jsonwebtoken');
const { errorResponse } = require('../utils/response.utils');

// Simple admin auth — verifies JWT has role='admin', no DB lookup needed
const adminAuth = (req, res, next) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return errorResponse(res, 'Unauthorized', 401);
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    if (decoded.role !== 'admin') return errorResponse(res, 'Access denied', 403);
    req.admin = decoded;
    next();
  } catch {
    return errorResponse(res, 'Invalid token', 401);
  }
};

router.post('/login', adminController.login);
router.get('/stats', adminAuth, adminController.getStats);
router.get('/users', adminAuth, adminController.getUsers);
router.put('/users/:id/role', adminAuth, adminController.updateUserRole);
router.put('/users/:id/ban', adminAuth, adminController.toggleBanUser);
router.get('/therapists', adminAuth, adminController.getTherapists);
router.put('/therapists/:id/approve', adminAuth, adminController.toggleApproveTherapist);
router.put('/therapists/:id/pricing', adminAuth, adminController.updateTherapistPricing);
router.put('/therapists/:id/discount', adminAuth, adminController.updateTherapistDiscount);
router.put('/therapists/:id/specializations', adminAuth, adminController.updateTherapistSpecializations);
router.put('/therapists/:id/commission-rate', adminAuth, adminController.updateCoachRate);
router.get('/bookings', adminAuth, adminController.getBookings);
router.post('/bookings', adminAuth, adminController.createBooking);
router.put('/bookings/:id/cancel', adminAuth, adminController.cancelBooking);
router.get('/therapists/:id/availability', adminAuth, therapistController.getAvailability);
router.get('/therapists/:id/booked-slots', adminAuth, therapistController.getBookedSlots);
router.get('/payments', adminAuth, adminController.getPayments);
router.post('/payments/:id/refund', adminAuth, adminController.refundPayment);
router.get('/content', adminAuth, adminController.getContent);
router.post('/content', adminAuth, adminController.createContent);
router.put('/content/:id/publish', adminAuth, adminController.togglePublishContent);
router.delete('/content/:id', adminAuth, adminController.deleteContent);

// Questionnaire sets (admin manages)
router.get('/questionnaire/sets', adminAuth, adminController.getQuestionnaireSets);
router.post('/questionnaire/sets', adminAuth, adminController.createQuestionnaireSet);
router.put('/questionnaire/sets/:id', adminAuth, adminController.updateQuestionnaireSet);
router.delete('/questionnaire/sets/:id', adminAuth, adminController.deleteQuestionnaireSet);
router.get('/questionnaire/sets/:setId/questions', adminAuth, adminController.getSetQuestions);
router.post('/questionnaire/sets/:setId/questions', adminAuth, adminController.createSetQuestion);
router.put('/questionnaire/questions/:id', adminAuth, adminController.updateSetQuestion);
router.delete('/questionnaire/questions/:id', adminAuth, adminController.deleteSetQuestion);
router.get('/questionnaire/responses', adminAuth, adminController.getQuestionnaireResponses);

router.get('/payouts', adminAuth, adminController.getCoachPayouts);
router.post('/payouts/:therapistId/mark-paid', adminAuth, adminController.markPayoutPaid);
router.get('/payout-requests', adminAuth, adminController.getPayoutRequests);
router.post('/payout-requests/:id/mark-paid', adminAuth, adminController.markPayoutRequestPaid);

// Chat — admin dispute review (decrypted)
const chatController = require('../controllers/chat.controller');
router.get('/bookings/:bookingId/messages', adminAuth, chatController.adminGetMessages);

// Announcements
const announcementController = require('../controllers/announcement.controller');
router.get('/announcements', adminAuth, announcementController.getAll);
router.post('/announcements', adminAuth, announcementController.create);
router.put('/announcements/:id', adminAuth, announcementController.update);
router.delete('/announcements/:id', adminAuth, announcementController.remove);
router.post('/announcements/upload-image', adminAuth, announcementController.uploadImageMiddleware, announcementController.uploadImage);

module.exports = router;
