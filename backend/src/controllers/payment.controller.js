const https = require('https');
const crypto = require('crypto');
const pool = require('../config/database');
const { successResponse, errorResponse } = require('../utils/response.utils');

// ── Paymob Intention API helper ────────────────────────────────────────────────
const PAYMOB_HOST = process.env.PAYMOB_HOST || 'ksa.paymob.com';

function paymobRequest(method, path, body) {
  return new Promise((resolve, reject) => {
    const raw = body ? JSON.stringify(body) : '';
    const options = {
      hostname: PAYMOB_HOST,
      path,
      method,
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Token ${process.env.PAYMOB_SECRET_KEY}`,
        ...(raw ? { 'Content-Length': Buffer.byteLength(raw) } : {}),
      },
    };
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (c) => (data += c));
      res.on('end', () => {
        try { resolve(JSON.parse(data)); }
        catch { reject(new Error(`Paymob bad response: ${data}`)); }
      });
    });
    req.on('error', reject);
    if (raw) req.write(raw);
    req.end();
  });
}

// ── POST /api/v1/payments/initiate ────────────────────────────────────────────
exports.initiatePayment = async (req, res) => {
  try {
    const { booking_id } = req.body;

    const booking = await pool.query(
      'SELECT b.*, u.name as client_name, u.email as client_email, u.phone as client_phone FROM bookings b LEFT JOIN users u ON u.id=b.client_id WHERE b.id=$1 AND b.client_id=$2',
      [booking_id, req.user.id]
    );
    if (!booking.rows[0]) return errorResponse(res, 'Booking not found', 404);
    if (booking.rows[0].payment_status === 'paid') return errorResponse(res, 'Already paid', 400);

    const price = parseFloat(booking.rows[0].price) || 0;
    const amountHalala = Math.round(price * 100); // SAR → halala

    // Create payment intention (Paymob v1 API)
    const intention = await paymobRequest('POST', '/v1/intention/', {
      amount: amountHalala,
      currency: 'SAR',
      payment_methods: [
        parseInt(process.env.PAYMOB_INTEGRATION_ID),
        ...(process.env.PAYMOB_APPLE_PAY_INTEGRATION_ID
          ? [parseInt(process.env.PAYMOB_APPLE_PAY_INTEGRATION_ID)]
          : []),
      ],
      items: [
        {
          name: 'جلسة كوتشينج',
          amount: amountHalala,
          description: `حجز رقم ${booking_id}`,
          quantity: 1,
        },
      ],
      billing_data: {
        first_name: (booking.rows[0].client_name || 'Client').split(' ')[0],
        last_name: (booking.rows[0].client_name || 'Client').split(' ').slice(1).join(' ') || 'User',
        email: booking.rows[0].client_email || 'client@app.com',
        phone_number: booking.rows[0].client_phone || '+966500000000',
        apartment: 'N/A',
        floor: 'N/A',
        street: 'N/A',
        building: 'N/A',
        shipping_method: 'N/A',
        postal_code: 'N/A',
        city: 'N/A',
        country: 'SA',
        state: 'N/A',
      },
      customer: {
        first_name: (booking.rows[0].client_name || 'Client').split(' ')[0],
        last_name: (booking.rows[0].client_name || 'Client').split(' ').slice(1).join(' ') || 'User',
        email: booking.rows[0].client_email || 'client@app.com',
      },
      merchant_order_id: `booking_${booking_id}_${Date.now()}`,
      redirection_url: process.env.PAYMOB_REDIRECT_URL || 'https://your-backend.com/payment-result',
    });

    if (!intention.client_secret) {
      console.error('Paymob intention error:', JSON.stringify(intention));
      throw new Error(intention.message || intention.detail || 'Paymob intention creation failed');
    }

    // Save/update payment record
    const orderId = String(intention.id || '');
    const existing = await pool.query(
      `SELECT id FROM payments WHERE booking_id=$1 AND status='pending' LIMIT 1`,
      [booking_id]
    );
    if (existing.rows[0]) {
      await pool.query(
        'UPDATE payments SET provider_payment_id=$1 WHERE id=$2',
        [orderId, existing.rows[0].id]
      );
    } else {
      await pool.query(
        `INSERT INTO payments (booking_id, user_id, amount, currency, provider, provider_payment_id, status)
         VALUES ($1,$2,$3,'SAR','paymob',$4,'pending')`,
        [booking_id, req.user.id, price, orderId]
      );
    }

    successResponse(res, {
      client_secret: intention.client_secret,
      public_key: process.env.PAYMOB_PUBLIC_KEY,
      amount: price,
    }, 'Payment initiated');
  } catch (err) {
    console.error('❌ Payment initiate error:', err.message);
    errorResponse(res, err.message, 500);
  }
};

// ── POST /api/v1/payments/callback  (Paymob transaction callback) ─────────────
exports.callback = async (req, res) => {
  try {
    const data = req.body;
    const hmacSecret = process.env.PAYMOB_HMAC_SECRET;

    // Verify HMAC if configured
    if (hmacSecret) {
      const obj = data.obj || {};
      const concatenated = [
        obj.amount_cents, obj.created_at, obj.currency, obj.error_occured,
        obj.has_parent_transaction, obj.id, obj.integration_id, obj.is_3d_secure,
        obj.is_auth, obj.is_capture, obj.is_refunded, obj.is_standalone_payment,
        obj.is_voided, obj.order?.id, obj.owner, obj.pending,
        obj.source_data?.pan, obj.source_data?.sub_type, obj.source_data?.type,
        obj.success,
      ].join('');
      const expected = crypto.createHmac('sha512', hmacSecret).update(concatenated).digest('hex');
      const received = req.query.hmac || data.hmac;
      if (received && received !== expected) {
        console.warn('⚠️  Paymob HMAC mismatch');
        return res.status(400).json({ error: 'Invalid HMAC' });
      }
    }

    const obj = data.obj || {};
    const success = obj.success === true || obj.success === 'true';
    const orderId = String(obj.order?.id || '');

    if (orderId) {
      await pool.query(
        'UPDATE payments SET status=$1 WHERE provider_payment_id=$2',
        [success ? 'paid' : 'failed', orderId]
      );
      if (success) {
        const payment = await pool.query(
          'SELECT booking_id FROM payments WHERE provider_payment_id=$1 LIMIT 1',
          [orderId]
        );
        if (payment.rows[0]) {
          await pool.query(
            'UPDATE bookings SET payment_status=$1, payment_id=$2 WHERE id=$3',
            ['paid', orderId, payment.rows[0].booking_id]
          );
        }
      }
    }

    res.json({ received: true });
  } catch (err) {
    console.error('Paymob callback error:', err.message);
    res.status(500).json({ error: err.message });
  }
};

// ── GET /api/v1/payments/history ─────────────────────────────────────────────
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
