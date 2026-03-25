const pool = require('../config/database');
const { successResponse, errorResponse } = require('../utils/response.utils');

// POST /api/v1/questionnaires  — coach creates template
exports.createTemplate = async (req, res) => {
  try {
    const { title, description, questions } = req.body;
    if (!title || !questions?.length) return errorResponse(res, 'Title and questions required', 400);

    const therapist = await pool.query(`SELECT id FROM therapists WHERE user_id=$1`, [req.user.id]);
    if (!therapist.rows[0]) return errorResponse(res, 'Coach profile not found', 404);

    const result = await pool.query(
      `INSERT INTO questionnaire_templates (therapist_id, title, description, questions)
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [therapist.rows[0].id, title, description || null, JSON.stringify(questions)]
    );
    successResponse(res, result.rows[0], 'Template created');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// GET /api/v1/questionnaires  — list coach's templates
exports.getMyTemplates = async (req, res) => {
  try {
    const therapist = await pool.query(`SELECT id FROM therapists WHERE user_id=$1`, [req.user.id]);
    if (!therapist.rows[0]) return successResponse(res, []);

    const templates = await pool.query(
      `SELECT * FROM questionnaire_templates WHERE therapist_id=$1 ORDER BY created_at DESC`,
      [therapist.rows[0].id]
    );
    successResponse(res, templates.rows);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// PUT /api/v1/questionnaires/:id
exports.updateTemplate = async (req, res) => {
  try {
    const { title, description, questions } = req.body;
    const therapist = await pool.query(`SELECT id FROM therapists WHERE user_id=$1`, [req.user.id]);

    const result = await pool.query(
      `UPDATE questionnaire_templates SET title=$1, description=$2, questions=$3, updated_at=NOW()
       WHERE id=$4 AND therapist_id=$5 RETURNING *`,
      [title, description || null, JSON.stringify(questions), req.params.id, therapist.rows[0]?.id]
    );
    if (!result.rows[0]) return errorResponse(res, 'Template not found', 404);
    successResponse(res, result.rows[0]);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// DELETE /api/v1/questionnaires/:id
exports.deleteTemplate = async (req, res) => {
  try {
    const therapist = await pool.query(`SELECT id FROM therapists WHERE user_id=$1`, [req.user.id]);
    await pool.query(
      `DELETE FROM questionnaire_templates WHERE id=$1 AND therapist_id=$2`,
      [req.params.id, therapist.rows[0]?.id]
    );
    successResponse(res, null, 'Deleted');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// POST /api/v1/questionnaires/:templateId/assign/:bookingId  — coach sends to client
exports.assignToBooking = async (req, res) => {
  try {
    const { templateId, bookingId } = req.params;

    const booking = await pool.query(
      `SELECT b.*, b.client_id FROM bookings b
       WHERE b.id=$1 AND b.therapist_id=(SELECT id FROM therapists WHERE user_id=$2)`,
      [bookingId, req.user.id]
    );
    if (!booking.rows[0]) return errorResponse(res, 'Booking not found', 404);

    // Prevent duplicate assignment
    const existing = await pool.query(
      `SELECT id FROM questionnaire_assignments WHERE template_id=$1 AND booking_id=$2`,
      [templateId, bookingId]
    );
    if (existing.rows[0]) return errorResponse(res, 'Already assigned', 409);

    const result = await pool.query(
      `INSERT INTO questionnaire_assignments (template_id, booking_id, client_id)
       VALUES ($1, $2, $3) RETURNING *`,
      [templateId, bookingId, booking.rows[0].client_id]
    );
    successResponse(res, result.rows[0], 'Questionnaire sent to client');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// GET /api/v1/questionnaires/assignments/booking/:bookingId  — list assignments for booking
exports.getBookingAssignments = async (req, res) => {
  try {
    const { bookingId } = req.params;

    // Accessible by coach or client
    const access = await pool.query(
      `SELECT b.* FROM bookings b WHERE b.id=$1
       AND (b.client_id=$2 OR b.therapist_id=(SELECT id FROM therapists WHERE user_id=$2))`,
      [bookingId, req.user.id]
    );
    if (!access.rows[0]) return errorResponse(res, 'Access denied', 403);

    const assignments = await pool.query(
      `SELECT qa.*, qt.title, qt.description, qt.questions
       FROM questionnaire_assignments qa
       JOIN questionnaire_templates qt ON qt.id = qa.template_id
       WHERE qa.booking_id=$1 ORDER BY qa.assigned_at DESC`,
      [bookingId]
    );
    successResponse(res, assignments.rows);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// POST /api/v1/questionnaires/assignments/:assignmentId/respond  — client submits answers
exports.submitAnswers = async (req, res) => {
  try {
    const { answers } = req.body;
    const assignment = await pool.query(
      `SELECT * FROM questionnaire_assignments WHERE id=$1 AND client_id=$2`,
      [req.params.assignmentId, req.user.id]
    );
    if (!assignment.rows[0]) return errorResponse(res, 'Assignment not found', 404);
    if (assignment.rows[0].status === 'completed') return errorResponse(res, 'Already submitted', 409);

    const result = await pool.query(
      `UPDATE questionnaire_assignments SET answers=$1, status='completed', completed_at=NOW()
       WHERE id=$2 RETURNING *`,
      [JSON.stringify(answers), req.params.assignmentId]
    );
    successResponse(res, result.rows[0], 'Answers submitted');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// GET /api/v1/questionnaires/assignments/:assignmentId  — get full assignment with answers
exports.getAssignment = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT qa.*, qt.title, qt.description, qt.questions
       FROM questionnaire_assignments qa
       JOIN questionnaire_templates qt ON qt.id = qa.template_id
       WHERE qa.id=$1`,
      [req.params.assignmentId]
    );
    if (!result.rows[0]) return errorResponse(res, 'Not found', 404);

    // Verify access (coach or client)
    const assignment = result.rows[0];
    const access = await pool.query(
      `SELECT b.* FROM bookings b WHERE b.id=$1
       AND (b.client_id=$2 OR b.therapist_id=(SELECT id FROM therapists WHERE user_id=$2))`,
      [assignment.booking_id, req.user.id]
    );
    if (!access.rows[0]) return errorResponse(res, 'Access denied', 403);

    successResponse(res, assignment);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// Internal helper — auto-assign default questionnaire on booking
exports.autoAssignOnBooking = async (bookingId, clientId, therapistId) => {
  try {
    // Find the therapist's "default" questionnaire (first one, or marked default)
    const template = await pool.query(
      `SELECT id FROM questionnaire_templates WHERE therapist_id=$1 AND is_default=true LIMIT 1`,
      [therapistId]
    );
    if (!template.rows[0]) return; // No default questionnaire set

    await pool.query(
      `INSERT INTO questionnaire_assignments (template_id, booking_id, client_id)
       VALUES ($1, $2, $3) ON CONFLICT DO NOTHING`,
      [template.rows[0].id, bookingId, clientId]
    );
    console.log(`Auto-assigned questionnaire to booking ${bookingId}`);
  } catch (err) {
    console.error('Auto-assign questionnaire error:', err.message);
  }
};

// PUT /api/v1/questionnaires/:id/set-default  — mark as default (auto-send on booking)
exports.setDefault = async (req, res) => {
  try {
    const therapist = await pool.query(`SELECT id FROM therapists WHERE user_id=$1`, [req.user.id]);
    if (!therapist.rows[0]) return errorResponse(res, 'Not found', 404);

    // Clear existing default
    await pool.query(
      `UPDATE questionnaire_templates SET is_default=false WHERE therapist_id=$1`,
      [therapist.rows[0].id]
    );

    // Set new default
    const result = await pool.query(
      `UPDATE questionnaire_templates SET is_default=true WHERE id=$1 AND therapist_id=$2 RETURNING *`,
      [req.params.id, therapist.rows[0].id]
    );
    if (!result.rows[0]) return errorResponse(res, 'Template not found', 404);
    successResponse(res, result.rows[0], 'Set as default questionnaire');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// ── Admin-questionnaire: client fills once, coach reads ───────────────────────

// GET /api/v1/questionnaire/sets?specialization=X&timing=before
// يرجع قائمة الاستبيانات المتاحة مع عدد الأسئلة وعدد إجابات العميل
exports.getActiveSets = async (req, res) => {
  try {
    const { specialization, timing } = req.query;
    let whereClause = `s.is_active = true`;
    const params = [req.user.id];
    let paramIdx = 2;

    if (timing) {
      whereClause += ` AND s.timing = $${paramIdx++}`;
      params.push(timing);
    }
    if (specialization) {
      whereClause += ` AND (s.specialization IS NULL OR s.specialization = $${paramIdx++})`;
      params.push(specialization);
    }

    const result = await pool.query(
      `SELECT s.*,
              COUNT(DISTINCT q.id) FILTER (WHERE q.is_active = true) AS question_count,
              COUNT(DISTINCT r.id) AS answered_count
       FROM questionnaire_sets s
       LEFT JOIN questionnaire_questions q ON q.set_id = s.id AND q.is_active = true
       LEFT JOIN questionnaire_responses r ON r.question_id = q.id AND r.client_id = $1
       WHERE ${whereClause}
       GROUP BY s.id
       ORDER BY s.timing ASC, s.created_at ASC`,
      params
    );
    successResponse(res, result.rows);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// GET /api/v1/questionnaire/sets/:setId/questions — questions + client's existing answers
exports.getSetQuestionsForClient = async (req, res) => {
  try {
    const questions = await pool.query(
      `SELECT q.*, r.answer as existing_answer
       FROM questionnaire_questions q
       LEFT JOIN questionnaire_responses r ON r.question_id = q.id AND r.client_id = $1
       WHERE q.set_id = $2 AND q.is_active = true
       ORDER BY q.order_index ASC`,
      [req.user.id, req.params.setId]
    );
    successResponse(res, questions.rows);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// GET /api/v1/questionnaire/questions?specialization=X
// (legacy — kept for backward compat)
exports.getActiveQuestions = async (req, res) => {
  try {
    const { specialization } = req.query;
    const result = specialization
      ? await pool.query(
          `SELECT q.* FROM questionnaire_questions q
           JOIN questionnaire_sets s ON s.id = q.set_id
           WHERE q.is_active=true AND (s.specialization IS NULL OR s.specialization=$1)
           ORDER BY q.order_index ASC`,
          [specialization]
        )
      : await pool.query(
          `SELECT * FROM questionnaire_questions WHERE is_active=true ORDER BY order_index ASC`
        );
    successResponse(res, result.rows);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// GET /api/v1/questionnaire/my-response  — client checks their own answers
exports.getMyResponse = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT r.*, q.question_text, q.question_type, q.options
       FROM questionnaire_responses r
       JOIN questionnaire_questions q ON q.id = r.question_id
       WHERE r.client_id=$1 ORDER BY q.order_index ASC`,
      [req.user.id]
    );
    successResponse(res, result.rows);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// POST /api/v1/questionnaire/submit  — client submits/updates answers
// body: { answers: [ { question_id, answer } ] }
exports.submitResponse = async (req, res) => {
  try {
    const { answers } = req.body;
    if (!Array.isArray(answers) || answers.length === 0)
      return errorResponse(res, 'answers array required', 400);

    for (const { question_id, answer } of answers) {
      await pool.query(
        `INSERT INTO questionnaire_responses (client_id, question_id, answer)
         VALUES ($1, $2, $3)
         ON CONFLICT (client_id, question_id) DO UPDATE SET answer=$3, created_at=NOW()`,
        [req.user.id, question_id, answer]
      );
    }
    successResponse(res, null, 'Submitted');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// GET /api/v1/questionnaire/client/:clientId  — coach views a client's answers
exports.getClientResponse = async (req, res) => {
  try {
    // Ensure requester is a coach with at least one booking with this client
    const access = await pool.query(
      `SELECT 1 FROM bookings b
       JOIN therapists t ON t.id = b.therapist_id
       WHERE t.user_id=$1 AND b.client_id=$2 LIMIT 1`,
      [req.user.id, req.params.clientId]
    );
    if (!access.rows[0]) return errorResponse(res, 'Access denied', 403);

    const result = await pool.query(
      `SELECT r.*, q.question_text, q.question_type, q.options,
              s.name as set_name, s.timing as set_timing
       FROM questionnaire_responses r
       JOIN questionnaire_questions q ON q.id = r.question_id
       LEFT JOIN questionnaire_sets s ON s.id = q.set_id
       WHERE r.client_id=$1 ORDER BY s.timing ASC, q.order_index ASC`,
      [req.params.clientId]
    );

    const client = await pool.query(
      `SELECT id, name, phone FROM users WHERE id=$1`, [req.params.clientId]
    );

    // Also fetch set_assignment answers this coach sent to this client
    const assignments = await pool.query(
      `SELECT sa.id, sa.status, sa.answers, sa.assigned_at, sa.completed_at,
              sa.set_id, qs.name as set_name, qs.timing
       FROM set_assignments sa
       JOIN questionnaire_sets qs ON qs.id = sa.set_id
       WHERE sa.client_id=$1 AND sa.coach_id=$2
       ORDER BY sa.assigned_at DESC`,
      [req.params.clientId, req.user.id]
    );

    // For completed assignments, enrich answers with question text
    for (const assignment of assignments.rows) {
      if (assignment.status === 'completed' && assignment.answers && Object.keys(assignment.answers).length > 0) {
        const questions = await pool.query(
          `SELECT id, question_text, question_type FROM questionnaire_questions
           WHERE set_id=$1 AND is_active=true ORDER BY order_index ASC`,
          [assignment.set_id]
        );
        assignment.qa_pairs = questions.rows.map(q => ({
          question: q.question_text,
          type: q.question_type,
          answer: assignment.answers[q.id] || '—',
        }));
      }
    }

    successResponse(res, {
      client: client.rows[0],
      responses: result.rows,
      assignments: assignments.rows,
    });
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// ── Set Assignments (coach sends → client fills) ──────────────────────────────

// POST /api/v1/questionnaires/sets/:setId/send/:bookingId — coach sends set to client
exports.sendSetToClient = async (req, res) => {
  try {
    const { setId, bookingId } = req.params;
    const booking = await pool.query(
      `SELECT b.client_id FROM bookings b
       JOIN therapists t ON t.id = b.therapist_id
       WHERE b.id=$1 AND t.user_id=$2`,
      [bookingId, req.user.id]
    );
    if (!booking.rows[0]) return errorResponse(res, 'Booking not found', 404);

    const result = await pool.query(
      `INSERT INTO set_assignments (set_id, booking_id, client_id, coach_id)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (set_id, booking_id) DO NOTHING RETURNING *`,
      [setId, bookingId, booking.rows[0].client_id, req.user.id]
    );
    successResponse(res, result.rows[0] || null, 'Questionnaire sent');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// GET /api/v1/questionnaires/my-assignments — client gets pending/completed assignments
exports.getMyAssignments = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT sa.*, qs.name as set_name, qs.description as set_description, qs.timing,
              u.name as coach_name
       FROM set_assignments sa
       JOIN questionnaire_sets qs ON qs.id = sa.set_id
       JOIN users u ON u.id = sa.coach_id
       WHERE sa.client_id=$1
       ORDER BY sa.assigned_at DESC`,
      [req.user.id]
    );
    successResponse(res, result.rows);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// POST /api/v1/questionnaires/set-assignments/:id/complete — client submits answers
exports.completeAssignment = async (req, res) => {
  try {
    const { answers } = req.body; // { question_id: answer, ... }
    if (!answers) return errorResponse(res, 'answers required', 400);

    const assignment = await pool.query(
      `SELECT * FROM set_assignments WHERE id=$1 AND client_id=$2`,
      [req.params.id, req.user.id]
    );
    if (!assignment.rows[0]) return errorResponse(res, 'Assignment not found', 404);

    const result = await pool.query(
      `UPDATE set_assignments SET answers=$1, status='completed', completed_at=NOW()
       WHERE id=$2 RETURNING *`,
      [JSON.stringify(answers), req.params.id]
    );
    successResponse(res, result.rows[0], 'Submitted');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

// GET /api/v1/questionnaires/booking/:bookingId/assignments — coach sees assignments for booking
exports.getBookingSetAssignments = async (req, res) => {
  try {
    const access = await pool.query(
      `SELECT 1 FROM bookings b JOIN therapists t ON t.id=b.therapist_id
       WHERE b.id=$1 AND t.user_id=$2`,
      [req.params.bookingId, req.user.id]
    );
    if (!access.rows[0]) return errorResponse(res, 'Access denied', 403);

    const result = await pool.query(
      `SELECT sa.*, qs.name as set_name, qs.timing
       FROM set_assignments sa
       JOIN questionnaire_sets qs ON qs.id = sa.set_id
       WHERE sa.booking_id=$1 ORDER BY sa.assigned_at DESC`,
      [req.params.bookingId]
    );
    successResponse(res, result.rows);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};
