const pool = require('../config/database');
const { successResponse, errorResponse } = require('../utils/response.utils');

exports.initiatePayment = async (req, res) => {
  try {
    const { booking_id, provider = 'moyasar' } = req.body;

    const booking = await pool.query(
      'SELECT * FROM bookings WHERE id=$1 AND client_id=$2',
      [booking_id, req.user.id]
    );

    if (!booking.rows[0]) return errorResponse(res, 'Booking not found', 404);
    if (booking.rows[0].payment_status === 'paid') return errorResponse(res, 'Already paid', 400);

    const payment = await pool.query(
      `INSERT INTO payments (booking_id, user_id, amount, currency, provider)
       VALUES ($1,$2,$3,'SAR',$4) RETURNING *`,
      [booking_id, req.user.id, booking.rows[0].price, provider]
    );

    // In production: Call Moyasar/Stripe API to create payment intent
    const paymentData = {
      payment_id: payment.rows[0].id,
      amount: booking.rows[0].price,
      currency: 'SAR',
      // payment_url: result from Moyasar API
    };

    successResponse(res, paymentData, 'Payment initiated');
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

exports.paymentCallback = async (req, res) => {
  try {
    const { payment_id, status, provider_payment_id } = req.body;

    await pool.query(
      'UPDATE payments SET status=$1, provider_payment_id=$2 WHERE id=$3',
      [status, provider_payment_id, payment_id]
    );

    if (status === 'paid') {
      const payment = await pool.query('SELECT booking_id FROM payments WHERE id=$1', [payment_id]);
      await pool.query(
        'UPDATE bookings SET payment_status=$1, payment_id=$2 WHERE id=$3',
        ['paid', provider_payment_id, payment.rows[0].booking_id]
      );
    }

    res.json({ success: true });
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};

exports.getPaymentHistory = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT p.*, b.session_type, b.scheduled_at
       FROM payments p JOIN bookings b ON b.id = p.booking_id
       WHERE p.user_id=$1 ORDER BY p.created_at DESC`,
      [req.user.id]
    );
    successResponse(res, result.rows);
  } catch (err) {
    errorResponse(res, err.message, 500);
  }
};
