import express from 'express';
import Stripe from 'stripe';
import dotenv from 'dotenv';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import { randomUUID } from 'crypto';
import pg from 'pg';

dotenv.config();

const app = express();
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);
const PORT = process.env.PORT || 3000;

// Database setup
const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://localhost/craig_o_clean'
});

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// Rate limiting
const limiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 10 // 10 requests per minute
});
app.use('/api/', limiter);

// Homepage
app.get('/', (req, res) => {
  res.json({
    service: 'Craig-O-Clean Backend',
    version: '1.0.0',
    status: 'running',
    endpoints: {
      health: '/health',
      checkout: 'POST /api/checkout/create',
      webhook: 'POST /api/webhook/stripe',
      validateLicense: 'GET /api/license/validate?license_key=KEY',
      paymentStatus: 'GET /api/payment/status?client_ref=UUID',
      download: 'GET /api/download?license_key=KEY'
    },
    webhookUrl: 'https://craigoclean.com/api/webhook/stripe',
    documentation: 'https://github.com/neuralquantum/craig-o-clean'
  });
});

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'craig-o-clean-backend' });
});

// Create checkout session
app.post('/api/checkout/create', async (req, res) => {
  try {
    const { email, clientReferenceId } = req.body;

    const session = await stripe.checkout.sessions.create({
      payment_method_types: ['card'],
      line_items: [
        {
          price: process.env.STRIPE_PRICE_ID,
          quantity: 1,
        },
      ],
      mode: 'payment',
      success_url: `${process.env.APP_URL}/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${process.env.APP_URL}/cancelled`,
      customer_email: email,
      client_reference_id: clientReferenceId || randomUUID(),
      metadata: {
        product: 'Craig-O-Clean Full',
        version: process.env.APP_VERSION || '2.0.0'
      }
    });

    res.json({ checkoutUrl: session.url });
  } catch (error) {
    console.error('Checkout creation error:', error);
    res.status(500).json({ error: 'Failed to create checkout session' });
  }
});

// Stripe webhook handler
// IMPORTANT: This must use raw body for signature verification
app.post('/api/webhook/stripe', express.raw({ type: 'application/json' }), async (req, res) => {
  const sig = req.headers['stripe-signature'];
  let event;

  // Log webhook attempt
  console.log('[WEBHOOK] Received webhook from Stripe');
  console.log('[WEBHOOK] Signature:', sig ? 'Present' : 'Missing');

  try {
    event = stripe.webhooks.constructEvent(
      req.body,
      sig,
      process.env.STRIPE_WEBHOOK_SECRET
    );
    console.log('[WEBHOOK] Signature verified successfully');
  } catch (err) {
    console.error('[WEBHOOK] Signature verification failed:', err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  console.log('[WEBHOOK] Event type:', event.type);

  // Handle the event
  try {
    switch (event.type) {
      case 'checkout.session.completed':
        const session = event.data.object;
        console.log('[WEBHOOK] Processing checkout.session.completed:', session.id);
        await handleSuccessfulPayment(session);
        console.log('[WEBHOOK] Payment handled successfully');
        break;

      case 'payment_intent.succeeded':
        const paymentIntent = event.data.object;
        console.log('[WEBHOOK] PaymentIntent succeeded:', paymentIntent.id);
        break;

      case 'charge.refunded':
        const charge = event.data.object;
        console.log('[WEBHOOK] Refund processed:', charge.id);
        await handleRefund(charge);
        break;

      default:
        console.log(`[WEBHOOK] Unhandled event type: ${event.type}`);
    }

    res.json({ received: true, event: event.type });
  } catch (error) {
    console.error('[WEBHOOK] Error processing event:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Handle successful payment
async function handleSuccessfulPayment(session) {
  try {
    const licenseKey = generateLicenseKey();
    const email = session.customer_email || session.customer_details?.email;

    console.log(`[PAYMENT] Creating license for ${email}`);

    // Check if license already exists for this session
    const existing = await pool.query(
      'SELECT license_key FROM licenses WHERE stripe_session_id = $1',
      [session.id]
    );

    if (existing.rows.length > 0) {
      console.log('[PAYMENT] License already exists for this session');
      return;
    }

    // Save to database
    await pool.query(
      `INSERT INTO licenses (license_key, email, stripe_session_id, stripe_payment_intent_id,
       client_reference_id, amount, currency, status)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
      [
        licenseKey,
        email,
        session.id,
        session.payment_intent,
        session.client_reference_id,
        session.amount_total,
        session.currency,
        'active'
      ]
    );

    console.log(`[PAYMENT] License created: ${licenseKey}`);

    // Send email with license key
    await sendLicenseEmail(email, licenseKey);

    console.log(`[PAYMENT] Email sent to ${email}`);
  } catch (error) {
    console.error('[PAYMENT] Error handling successful payment:', error);
    throw error;
  }
}

// Handle refund
async function handleRefund(charge) {
  try {
    const paymentIntentId = charge.payment_intent;

    console.log(`[REFUND] Processing refund for payment intent: ${paymentIntentId}`);

    // Find and deactivate license
    const result = await pool.query(
      `UPDATE licenses SET status = $1 WHERE stripe_payment_intent_id = $2 RETURNING license_key, email`,
      ['refunded', paymentIntentId]
    );

    if (result.rows.length > 0) {
      const { license_key, email } = result.rows[0];
      console.log(`[REFUND] License ${license_key} deactivated for ${email}`);

      // Send refund confirmation email
      await sendRefundEmail(email, license_key);
    }
  } catch (error) {
    console.error('[REFUND] Error processing refund:', error);
  }
}

// Send refund email
async function sendRefundEmail(email, licenseKey) {
  console.log(`[EMAIL] Refund confirmation sent to ${email} for license ${licenseKey}`);
  // TODO: Implement actual email sending
}

// Generate license key
function generateLicenseKey() {
  const segments = 4;
  const segmentLength = 4;
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // No ambiguous characters

  let key = 'CRAIG';
  for (let i = 0; i < segments; i++) {
    key += '-';
    for (let j = 0; j < segmentLength; j++) {
      key += chars.charAt(Math.floor(Math.random() * chars.length));
    }
  }

  return key;
}

// Send license email
async function sendLicenseEmail(email, licenseKey) {
  // TODO: Implement email sending via SendGrid or similar
  console.log(`Email sent to ${email} with license: ${licenseKey}`);

  // For now, just log. In production, use:
  // - SendGrid
  // - AWS SES
  // - Mailgun
  // etc.
}

// Validate license
app.get('/api/license/validate', async (req, res) => {
  try {
    const { license_key } = req.query;

    if (!license_key) {
      return res.status(400).json({ error: 'License key required' });
    }

    const result = await pool.query(
      `SELECT email, created_at, status, last_validated_at
       FROM licenses
       WHERE license_key = $1 AND status = 'active'`,
      [license_key]
    );

    if (result.rows.length === 0) {
      return res.json({ valid: false });
    }

    // Update last validated timestamp
    await pool.query(
      `UPDATE licenses SET last_validated_at = NOW() WHERE license_key = $1`,
      [license_key]
    );

    const license = result.rows[0];
    res.json({
      valid: true,
      email: license.email,
      purchaseDate: license.created_at,
      lastValidated: new Date()
    });
  } catch (error) {
    console.error('License validation error:', error);
    res.status(500).json({ error: 'Validation failed' });
  }
});

// Check payment status
app.get('/api/payment/status', async (req, res) => {
  try {
    const { client_ref } = req.query;

    if (!client_ref) {
      return res.status(400).json({ error: 'Client reference required' });
    }

    const result = await pool.query(
      `SELECT license_key, status FROM licenses WHERE client_reference_id = $1`,
      [client_ref]
    );

    if (result.rows.length === 0) {
      return res.json({ paid: false });
    }

    const license = result.rows[0];
    res.json({
      paid: license.status === 'active',
      license_key: license.license_key
    });
  } catch (error) {
    console.error('Payment status error:', error);
    res.status(500).json({ error: 'Status check failed' });
  }
});

// Download endpoint
app.get('/api/download', async (req, res) => {
  try {
    const { license_key } = req.query;

    // Validate license
    const result = await pool.query(
      `SELECT status FROM licenses WHERE license_key = $1`,
      [license_key]
    );

    if (result.rows.length === 0 || result.rows[0].status !== 'active') {
      return res.status(403).json({ error: 'Invalid or inactive license' });
    }

    // Redirect to download URL
    res.redirect(process.env.DOWNLOAD_URL);
  } catch (error) {
    console.error('Download error:', error);
    res.status(500).json({ error: 'Download failed' });
  }
});

// Initialize database
async function initDatabase() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS licenses (
        id SERIAL PRIMARY KEY,
        license_key VARCHAR(255) UNIQUE NOT NULL,
        email VARCHAR(255) NOT NULL,
        stripe_session_id VARCHAR(255) UNIQUE,
        stripe_payment_intent_id VARCHAR(255),
        client_reference_id VARCHAR(255),
        amount INTEGER NOT NULL,
        currency VARCHAR(3) DEFAULT 'usd',
        status VARCHAR(50) DEFAULT 'active',
        created_at TIMESTAMP DEFAULT NOW(),
        activated_at TIMESTAMP,
        last_validated_at TIMESTAMP
      );

      CREATE INDEX IF NOT EXISTS idx_license_key ON licenses(license_key);
      CREATE INDEX IF NOT EXISTS idx_email ON licenses(email);
      CREATE INDEX IF NOT EXISTS idx_client_ref ON licenses(client_reference_id);
    `);
    console.log('Database initialized');
  } catch (error) {
    console.error('Database initialization error:', error);
  }
}

// Start server
app.listen(PORT, async () => {
  await initDatabase();
  console.log(`Craig-O-Clean backend running on port ${PORT}`);
  console.log(`Stripe: ${process.env.STRIPE_SECRET_KEY ? 'Configured' : 'NOT configured'}`);
  console.log(`Database: ${process.env.DATABASE_URL ? 'Connected' : 'Using default'}`);
});

export default app;
