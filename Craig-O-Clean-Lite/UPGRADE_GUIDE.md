# Craig-O-Clean Upgrade System Guide

Complete guide to setting up the Stripe upgrade flow from Lite to Full version.

## Overview

The upgrade system works as follows:

1. **User clicks "Upgrade" in Lite app**
2. **Opens Stripe checkout in browser**
3. **User completes payment ($0.99)**
4. **Backend receives webhook from Stripe**
5. **License key generated and emailed**
6. **Full version download link provided**
7. **User installs Full version**

## Architecture

```
┌─────────────────┐
│  Lite App       │
│  (Menu Bar)     │
└────────┬────────┘
         │ Clicks "Upgrade"
         ▼
┌─────────────────┐
│ UpgradeView     │ Opens Stripe Checkout
│ (SwiftUI)       │ in default browser
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  Stripe Checkout (Web)              │
│  - Credit card form                 │
│  - Secure payment processing        │
│  - Returns success/cancel           │
└────────┬────────────────────────────┘
         │ On success
         ▼
┌─────────────────────────────────────┐
│  Stripe Webhook → Backend           │
│  1. Verify webhook signature        │
│  2. Generate license key            │
│  3. Save to database                │
│  4. Email license + download link   │
└────────┬────────────────────────────┘
         │
         ▼
┌─────────────────┐
│  User Email     │ License key + Download link
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Full Version   │ User downloads .dmg and installs
│  (craig-o-clean-full.dmg)
└─────────────────┘
```

## Setup Steps

### 1. Stripe Account Setup

#### Create Stripe Account
1. Go to https://stripe.com
2. Sign up (free)
3. Verify email and business details

#### Create Product
1. Go to https://dashboard.stripe.com/products
2. Click "Add product"
3. Fill in:
   - **Name**: Craig-O-Clean Full Version
   - **Description**: Unlock all features including browser tab management, advanced process control, and smart memory cleanup
   - **Pricing**: One-time payment
   - **Amount**: $0.99 USD
4. Click "Save product"
5. **Copy the Price ID** (starts with `price_`)

#### Get API Keys
1. Go to https://dashboard.stripe.com/apikeys
2. Copy:
   - **Publishable key** (starts with `pk_test_`)
   - **Secret key** (starts with `sk_test_`)
3. Keep these secure!

### 2. Backend Deployment

#### Option A: Deploy to Vercel (Easiest)

```bash
cd backend

# Install Vercel CLI
npm i -g vercel

# Login
vercel login

# Deploy
vercel

# Add environment variables in Vercel dashboard:
# https://vercel.com/your-project/settings/environment-variables
```

Add these environment variables in Vercel:
- `STRIPE_SECRET_KEY`
- `STRIPE_WEBHOOK_SECRET` (get after webhook setup)
- `STRIPE_PRICE_ID`
- `DATABASE_URL` (use Vercel Postgres or Supabase)
- `DOWNLOAD_URL`
- All other vars from `.env.example`

#### Option B: Deploy to Railway

```bash
cd backend

# Install Railway CLI
npm i -g @railway/cli

# Login
railway login

# Initialize
railway init

# Deploy
railway up

# Add environment variables
railway variables set STRIPE_SECRET_KEY=sk_test_...
railway variables set STRIPE_PRICE_ID=price_...
# ... etc
```

#### Option C: Your Own Server

```bash
cd backend

# Install dependencies
npm install

# Setup database
createdb craig_o_clean
psql craig_o_clean < schema.sql

# Configure .env file
cp .env.example .env
nano .env

# Start with PM2 (production)
npm i -g pm2
pm2 start index.js --name craig-o-clean-backend
pm2 save
pm2 startup
```

### 3. Stripe Webhook Setup

#### Create Webhook Endpoint
1. Go to https://dashboard.stripe.com/webhooks
2. Click "Add endpoint"
3. Enter URL: `https://your-backend-url.com/api/webhook/stripe`
4. Select events to listen for:
   - ✅ `checkout.session.completed`
   - ✅ `payment_intent.succeeded`
5. Click "Add endpoint"
6. **Copy the Signing secret** (starts with `whsec_`)
7. Add to backend environment as `STRIPE_WEBHOOK_SECRET`

#### Test Webhook Locally
```bash
# Install Stripe CLI
brew install stripe/stripe-brew/stripe

# Login
stripe login

# Forward webhooks to local server
stripe listen --forward-to localhost:3000/api/webhook/stripe

# In another terminal, trigger test event
stripe trigger checkout.session.completed
```

### 4. Database Setup

#### Option A: Vercel Postgres (Recommended)

1. Go to your Vercel project
2. Storage → Create Database → Postgres
3. Copy connection string
4. Add as `DATABASE_URL` environment variable
5. Table will be auto-created on first run

#### Option B: Supabase (Free tier)

1. Go to https://supabase.com
2. Create new project
3. Go to Settings → Database
4. Copy connection string (Session mode)
5. Add as `DATABASE_URL`

#### Option C: Local PostgreSQL

```bash
# Install PostgreSQL
brew install postgresql
brew services start postgresql

# Create database
createdb craig_o_clean

# Set DATABASE_URL
export DATABASE_URL="postgresql://localhost/craig_o_clean"
```

### 5. Update Lite App Configuration

Edit `Craig-O-Clean-Lite/UpgradeService.swift`:

```swift
// Update these URLs with your backend
private let stripeCheckoutURL = "https://buy.stripe.com/your-link"
private let licenseValidationURL = "https://your-backend.vercel.app/api/license/validate"
private let downloadURL = "https://your-backend.vercel.app/api/download"
```

**Two options for checkout:**

**Option A: Direct Stripe Payment Link (Easier)**
1. Go to https://dashboard.stripe.com/payment-links
2. Create new link for your product
3. Copy link (e.g., `https://buy.stripe.com/...`)
4. Use this as `stripeCheckoutURL`

**Option B: Backend Checkout Session (More control)**
```swift
// In UpgradeService.swift, add:
func createCheckoutSession(email: String?, completion: @escaping (String?) -> Void) {
    let url = URL(string: "https://your-backend.vercel.app/api/checkout/create")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let body: [String: Any] = [
        "email": email ?? "",
        "clientReferenceId": UUID().uuidString
    ]
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)

    URLSession.shared.dataTask(with: request) { data, _, _ in
        guard let data = data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let checkoutUrl = json["checkoutUrl"] as? String else {
            completion(nil)
            return
        }
        completion(checkoutUrl)
    }.resume()
}
```

### 6. Build and Sign Full Version

```bash
cd Craig-O-Clean  # Full version

# Archive
xcodebuild archive \
  -scheme Craig-O-Clean \
  -archivePath ./build/Craig-O-Clean.xcarchive

# Export as Developer ID Application
xcodebuild -exportArchive \
  -archivePath ./build/Craig-O-Clean.xcarchive \
  -exportPath ./build \
  -exportOptionsPlist ExportOptions.plist

# Create DMG
hdiutil create -volname "Craig-O-Clean" \
  -srcfolder ./build/Craig-O-Clean.app \
  -ov -format UDZO \
  craig-o-clean-full.dmg

# Notarize (requires Apple Developer account)
xcrun notarytool submit craig-o-clean-full.dmg \
  --apple-id your@email.com \
  --team-id YOUR_TEAM_ID \
  --password YOUR_APP_PASSWORD \
  --wait

# Staple notarization
xcrun stapler staple craig-o-clean-full.dmg
```

### 7. Upload Full Version

Upload `craig-o-clean-full.dmg` to:

**Option A: CDN (Recommended)**
- Cloudflare R2 (free tier)
- AWS S3 + CloudFront
- DigitalOcean Spaces

**Option B: GitHub Releases**
```bash
# Create GitHub release
gh release create v2.0.0 \
  craig-o-clean-full.dmg \
  --title "Craig-O-Clean Full v2.0.0" \
  --notes "Full version with all features"
```

**Option C: Direct on backend server**
```bash
# Upload to server
scp craig-o-clean-full.dmg user@server:/var/www/downloads/

# Make accessible
chmod 644 /var/www/downloads/craig-o-clean-full.dmg
```

Update `DOWNLOAD_URL` in backend `.env` to point to this file.

### 8. Email Configuration (Optional but Recommended)

#### SendGrid Setup
1. Go to https://sendgrid.com
2. Sign up (free tier: 100 emails/day)
3. Create API key
4. Add to backend as `SENDGRID_API_KEY`

#### Create Email Template
Create `backend/templates/license-key.html`:

```html
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: -apple-system, sans-serif; line-height: 1.6; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
              color: white; padding: 30px; text-align: center; }
    .content { padding: 30px; background: #f7f7f7; }
    .license-box { background: white; border: 2px solid #667eea;
                   padding: 20px; margin: 20px 0; text-align: center;
                   font-size: 24px; font-weight: bold; letter-spacing: 2px; }
    .button { display: inline-block; background: #667eea; color: white;
              padding: 15px 30px; text-decoration: none; border-radius: 5px;
              margin: 20px 0; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>🎉 Welcome to Craig-O-Clean Full!</h1>
    </div>
    <div class="content">
      <p>Thank you for upgrading! Here's your license key:</p>

      <div class="license-box">
        {{LICENSE_KEY}}
      </div>

      <p>To get started:</p>
      <ol>
        <li>Click the button below to download Craig-O-Clean Full</li>
        <li>Open the downloaded .dmg file</li>
        <li>Drag Craig-O-Clean to your Applications folder</li>
        <li>Launch and enjoy all features!</li>
      </ol>

      <center>
        <a href="{{DOWNLOAD_URL}}" class="button">Download Full Version</a>
      </center>

      <p><small>Your license key has been saved and will work automatically.
      Keep this email for your records.</small></p>

      <p>Questions? Email us at support@neuralquantum.ai</p>
    </div>
  </div>
</body>
</html>
```

### 9. Testing the Flow

#### Test with Stripe Test Cards

**Success:**
```
Card: 4242 4242 4242 4242
Exp: Any future date
CVC: Any 3 digits
```

**Requires 3D Secure:**
```
Card: 4000 0025 0000 3155
```

**Declined:**
```
Card: 4000 0000 0000 0002
```

#### Test Flow
1. Build Lite app
2. Click "Upgrade" button
3. Use test card in Stripe checkout
4. Check backend logs for webhook
5. Verify license created in database
6. Check download link works

### 10. Go Live

#### Switch to Production

1. **Stripe**:
   - Activate your account
   - Use live API keys (start with `sk_live_`, `pk_live_`)
   - Update webhook with live secret

2. **Backend**:
   - Set `NODE_ENV=production`
   - Use production database
   - Enable SSL/HTTPS
   - Set up monitoring (Sentry, LogRocket)

3. **App**:
   - Update URLs to production backend
   - Build release version
   - Sign and notarize
   - Distribute Lite version

## Pricing Strategy

### Suggested Pricing
- **Lite**: Free
- **Full**: $0.99 one-time

### Why This Works
- Low barrier to entry (free Lite)
- Fair price for full features
- No subscription fatigue
- Lifetime access incentive

### Optional: Volume Licensing
```javascript
// In backend/index.js
const pricing = {
  single: 1999,      // $0.99
  family_5: 4999,    // $49.99 for 5 licenses
  team_10: 7999,     // $79.99 for 10 licenses
  enterprise: 19999  // $199.99 for 50 licenses
};
```

## Support & Refunds

### 30-Day Money-Back Guarantee

Add refund handling:

```javascript
// backend/index.js
app.post('/api/refund/request', async (req, res) => {
  const { license_key, reason } = req.body;

  // Get license
  const license = await pool.query(
    'SELECT * FROM licenses WHERE license_key = $1',
    [license_key]
  );

  // Check if within 30 days
  const daysSincePurchase =
    (Date.now() - new Date(license.rows[0].created_at)) / (1000 * 60 * 60 * 24);

  if (daysSincePurchase > 30) {
    return res.status(400).json({ error: 'Refund period expired' });
  }

  // Process refund via Stripe
  await stripe.refunds.create({
    payment_intent: license.rows[0].stripe_payment_intent_id
  });

  // Deactivate license
  await pool.query(
    'UPDATE licenses SET status = $1 WHERE license_key = $2',
    ['refunded', license_key]
  );

  res.json({ success: true });
});
```

## Analytics & Metrics

### Track Important Metrics

```javascript
// Add to backend
import Analytics from 'analytics-node';
const analytics = new Analytics('YOUR_SEGMENT_KEY');

// Track events
analytics.track({
  userId: email,
  event: 'License Purchased',
  properties: {
    licenseKey: licenseKey,
    amount: session.amount_total / 100,
    currency: session.currency
  }
});
```

**Key Metrics to Monitor:**
- Conversion rate (Lite → Full)
- Average time to upgrade
- Refund rate
- MRR (if you add subscriptions later)
- Customer acquisition cost

## Troubleshooting

### Common Issues

**"Webhook not receiving events"**
- Check webhook URL is correct
- Verify endpoint is publicly accessible
- Check Stripe webhook logs
- Ensure webhook secret is correct

**"License validation failing"**
- Check database connection
- Verify license key format
- Check license status (active vs refunded)
- Review server logs

**"Download link broken"**
- Verify DMG file uploaded correctly
- Check CDN/storage permissions
- Test direct URL access
- Verify DOWNLOAD_URL is correct

## Security Best Practices

✅ **DO:**
- Always verify webhook signatures
- Use HTTPS in production
- Store API keys in environment variables
- Rate limit API endpoints
- Log all transactions
- Validate license keys server-side
- Use prepared statements for SQL

❌ **DON'T:**
- Commit API keys to git
- Trust client-side validation
- Skip webhook verification
- Expose admin endpoints
- Store credit card data
- Use GET for sensitive operations

## Next Steps

1. ✅ Complete Stripe account setup
2. ✅ Deploy backend to Vercel/Railway
3. ✅ Configure webhook
4. ✅ Test with test cards
5. ✅ Build and sign Full version
6. ✅ Upload to CDN
7. ✅ Update Lite app URLs
8. ✅ Test end-to-end flow
9. ✅ Switch to live mode
10. ✅ Launch! 🚀

---

Questions? Issues? Email: support@neuralquantum.ai
