# Craig-O-Clean Backend - Stripe Integration

Simple Node.js backend for handling Stripe payments and delivering the full version download.

## Overview

This backend:
1. Creates Stripe checkout sessions
2. Handles Stripe webhooks for payment confirmation
3. Generates license keys
4. Validates license keys
5. Serves the full version download

## Quick Setup

### Prerequisites

- Node.js 18+ installed
- Stripe account (free to start)
- Domain for hosting (or use Vercel/Railway)

### Installation

```bash
npm install
```

### Environment Variables

Create `.env` file:

```bash
# Stripe Keys (get from https://dashboard.stripe.com/apikeys)
STRIPE_SECRET_KEY=sk_test_...
STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...

# Product Configuration
STRIPE_PRICE_ID=price_...  # Create product in Stripe Dashboard
PRODUCT_PRICE=19.99

# App Configuration
APP_NAME=Craig-O-Clean
APP_VERSION=2.0.0
DOWNLOAD_URL=https://downloads.neuralquantum.ai/craig-o-clean-full.dmg

# Database (optional - uses JSON file by default)
DATABASE_URL=postgresql://...

# Email (for sending license keys)
SENDGRID_API_KEY=SG...
FROM_EMAIL=support@neuralquantum.ai

# Server
PORT=3000
NODE_ENV=production
```

### Running Locally

```bash
npm run dev
```

Server runs on `http://localhost:3000`

## API Endpoints

### 1. Create Checkout Session

```bash
POST /api/checkout/create
Content-Type: application/json

{
  "email": "user@example.com" (optional),
  "clientReferenceId": "uuid-here"
}

Response:
{
  "checkoutUrl": "https://checkout.stripe.com/c/pay/cs_test_..."
}
```

### 2. Validate License

```bash
GET /api/license/validate?license_key=KEY_HERE

Response:
{
  "valid": true,
  "email": "user@example.com",
  "purchaseDate": "2026-02-03T18:00:00Z"
}
```

### 3. Check Payment Status

```bash
GET /api/payment/status?client_ref=UUID_HERE

Response:
{
  "paid": true,
  "license_key": "CRAIG-XXXX-XXXX-XXXX-XXXX"
}
```

### 4. Download Full Version

```bash
GET /api/download?license_key=KEY_HERE

Response: 302 Redirect to download URL or DMG file
```

### 5. Stripe Webhook

```bash
POST /api/webhook/stripe
Content-Type: application/json
Stripe-Signature: t=...,v1=...

(Stripe sends webhook events here)
```

## Stripe Setup

### 1. Create Product

1. Go to https://dashboard.stripe.com/products
2. Click "Add product"
3. Name: "Craig-O-Clean Full Version"
4. Price: $0.99 (one-time payment)
5. Copy the Price ID (starts with `price_`)
6. Add to `.env` as `STRIPE_PRICE_ID`

### 2. Create Checkout Link

Option A: Use Stripe Checkout Links
1. Go to https://dashboard.stripe.com/payment-links
2. Create new link for your product
3. Copy the link (e.g., `https://buy.stripe.com/...`)
4. Update `stripeCheckoutURL` in `UpgradeService.swift`

Option B: Use API (this backend)
- Backend creates checkout sessions dynamically
- More control over the flow

### 3. Setup Webhook

1. Go to https://dashboard.stripe.com/webhooks
2. Add endpoint: `https://your-domain.com/api/webhook/stripe`
3. Select events:
   - `checkout.session.completed`
   - `payment_intent.succeeded`
4. Copy webhook secret (starts with `whsec_`)
5. Add to `.env` as `STRIPE_WEBHOOK_SECRET`

## Deployment

### Vercel (Recommended)

```bash
# Install Vercel CLI
npm i -g vercel

# Deploy
vercel

# Add environment variables in Vercel dashboard
```

### Railway

```bash
# Install Railway CLI
npm i -g @railway/cli

# Login and deploy
railway login
railway up
```

### Docker

```bash
# Build
docker build -t craig-o-clean-backend .

# Run
docker run -p 3000:3000 --env-file .env craig-o-clean-backend
```

## License Key Generation

License keys are generated in format:
```
CRAIG-XXXX-XXXX-XXXX-XXXX
```

Algorithm:
1. Generate UUID v4
2. Hash with HMAC-SHA256 using secret
3. Encode to base32
4. Format with dashes

## Database Schema

### Licenses Table

```sql
CREATE TABLE licenses (
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

CREATE INDEX idx_license_key ON licenses(license_key);
CREATE INDEX idx_email ON licenses(email);
CREATE INDEX idx_client_ref ON licenses(client_reference_id);
```

## Testing

### Test with Stripe Test Cards

```bash
# Success
4242 4242 4242 4242

# Requires authentication
4000 0025 0000 3155

# Declined
4000 0000 0000 0002
```

### Test Webhook Locally

```bash
# Install Stripe CLI
brew install stripe/stripe-brew/stripe

# Login
stripe login

# Forward webhooks to local
stripe listen --forward-to localhost:3000/api/webhook/stripe

# Trigger test event
stripe trigger checkout.session.completed
```

## Email Templates

Located in `templates/`:

- `license-key.html` - Email with license key and download link
- `payment-failed.html` - Payment failure notification
- `refund.html` - Refund confirmation

## Security

### Best Practices

1. ✅ Always verify webhook signatures
2. ✅ Use HTTPS in production
3. ✅ Rate limit API endpoints
4. ✅ Validate license keys server-side
5. ✅ Never expose Stripe secret key
6. ✅ Log all payment events
7. ✅ Implement refund policy

### Rate Limiting

```javascript
// 10 requests per minute per IP
app.use('/api/', rateLimit({
  windowMs: 60 * 1000,
  max: 10
}));
```

## Monitoring

### Stripe Dashboard

- Monitor payments: https://dashboard.stripe.com/payments
- View customers: https://dashboard.stripe.com/customers
- Check webhooks: https://dashboard.stripe.com/webhooks

### Application Logs

```bash
# View logs
npm run logs

# Production (Vercel)
vercel logs
```

## Refund Policy

30-day money-back guarantee:

```bash
# Process refund via Stripe Dashboard or API
stripe refunds create --payment-intent pi_xxx

# License will be automatically deactivated via webhook
```

## Support

### Common Issues

**"Payment succeeded but no license received"**
- Check webhook delivery in Stripe Dashboard
- Verify email address is correct
- Check spam folder

**"License key invalid"**
- Ensure license key is copied correctly
- Check activation status in database
- Verify license hasn't been refunded

**"Download link not working"**
- Verify DMG file exists at download URL
- Check CDN/storage permissions
- Ensure license is validated before serving download

## Maintenance

### Update Full Version

1. Build new version of Craig-O-Clean Full
2. Upload to download location
3. Update version number in backend
4. All existing licenses automatically get access

### Database Backup

```bash
# PostgreSQL
pg_dump $DATABASE_URL > backup.sql

# Restore
psql $DATABASE_URL < backup.sql
```

## Cost Estimate

### Stripe Fees
- 2.9% + $0.30 per transaction
- For $0.99: ~$0.88 fee, you keep ~$19.11

### Hosting (Free Tier)
- Vercel: Free for hobby projects
- Railway: $5/month
- Supabase (DB): Free up to 500MB

**Total monthly cost**: $0-$5 for starting out

## Next Steps

1. Set up Stripe account
2. Deploy this backend
3. Configure webhook
4. Test with test card
5. Update `UpgradeService.swift` with your URLs
6. Build and distribute Lite version
7. Upload Full version to download location
8. Go live! 🚀

---

Made with ❤️ for Craig-O-Clean
