const pool = require('../config/database');
const { successResponse, errorResponse } = require('../utils/response.utils');
const Stripe = require('stripe');

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);

// POST /api/v1/payments/initiate
exports.initiatePayment = async (req, res) => {
  try {
    const { booking_id } = req.body;

    const booking = await pool.query(
      'SELECT * FROM bookings WHERE id=$1 AND client_id=$2',
      [booking_id, req.user.id]
    );

    if (!booking.rows[0]) return errorResponse(res, 'Booking not found', 404);
    if (booking.rows[0].payment_status === 'paid') return errorResponse(res, 'Already paid', 400);

    const price = parseFloat(booking.rows[0].price) || 0;
    const amountHalala = Math.round(price * 100); // SAR → halala (smallest unit)

    const paymentIntent = await stripe.paymentIntents.create({
      amount: amountHalala,
      currency: 'sar',
      metadata: { booking_id, user_id: String(req.user.id) },
    });

    // Save/update payment record (one record per booking)
    const existing = await pool.query(
      `SELECT id FROM payments WHERE booking_id=$1 AND status='pending' LIMIT 1`,
      [booking_id]
    );
    if (existing.rows[0]) {
      await pool.query(
        'UPDATE payments SET provider_payment_id=$1, updated_at=NOW() WHERE id=$2',
        [paymentIntent.id, existing.rows[0].id]
      );
    } else {
      await pool.query(
        `INSERT INTO payments (booking_id, user_id, amount, currency, provider, provider_payment_id, status)
         VALUES ($1,$2,$3,'SAR','stripe',$4,'pending')`,
        [booking_id, req.user.id, price, paymentIntent.id]
      );
    }

    successResponse(res, {
      client_secret: paymentIntent.client_secret,
      publishable_key: process.env.STRIPE_PUBLISHABLE_KEY,
      amount: price,
    }, 'Payment initiated');
  } catch (err) {
    console.error('❌ Payment initiate error:', err.message, err.stack);
    errorResponse(res, err.message, 500);
  }
};

// POST /api/v1/payments/webhook  (raw body — no JSON middleware)
exports.webhook = async (req, res) => {
  const sig = req.headers['stripe-signature'];
  let event;
  try {
    event = stripe.webhooks.constructEvent(req.body, sig, process.env.STRIPE_WEBHOOK_SECRET);
  } catch (err) {
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  try {
    if (event.type === 'payment_intent.succeeded') {
      const pi = event.data.object;
      const bookingId = pi.metadata.booking_id;

      await pool.query(
        'UPDATE payments SET status=$1 WHERE provider_payment_id=$2',
        ['paid', pi.id]
      );
      await pool.query(
        'UPDATE bookings SET payment_status=$1, payment_id=$2 WHERE id=$3',
        ['paid', pi.id, bookingId]
      );
    }

    if (event.type === 'payment_intent.payment_failed') {
      const pi = event.data.object;
      await pool.query(
        'UPDATE payments SET status=$1 WHERE provider_payment_id=$2',
        ['failed', pi.id]
      );
    }
  } catch (err) {
    console.error('Webhook processing error:', err.message);
  }

  res.json({ received: true });
};

// GET /api/v1/payments/history
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
