# Craig-O-Clean Upgrade System - Quick Checklist

Fast-track guide to get your upgrade system running. ✅

## Pre-Launch Checklist

### 1. Stripe Account (15 min)
- [ ] Create Stripe account at https://stripe.com
- [ ] Verify email and business info
- [ ] Complete account activation
- [ ] Switch to "Test mode" for testing

### 2. Create Product (5 min)
- [ ] Go to https://dashboard.stripe.com/products
- [ ] Create "Craig-O-Clean Full Version"
- [ ] Set price: $0.99 one-time
- [ ] Copy Price ID: `price_________________`
- [ ] Save for later

### 3. Get API Keys (2 min)
- [ ] Go to https://dashboard.stripe.com/apikeys
- [ ] Copy Publishable key: `pk_test_________________`
- [ ] Copy Secret key: `sk_test_________________`
- [ ] Store securely (don't commit to git!)

### 4. Deploy Backend (20 min)

**Option A: Vercel (Recommended)**
```bash
cd backend
npm install
vercel login
vercel
```

- [ ] Deployed to Vercel
- [ ] URL: `https://________________.vercel.app`
- [ ] Add environment variables in Vercel dashboard:
  - [ ] `STRIPE_SECRET_KEY`
  - [ ] `STRIPE_PRICE_ID`
  - [ ] `DATABASE_URL` (from Vercel Postgres)
  - [ ] `DOWNLOAD_URL`

**Option B: Railway**
```bash
cd backend
npm install
railway login
railway init
railway up
```

- [ ] Deployed to Railway
- [ ] URL: `https://________________.railway.app`
- [ ] Environment variables configured

### 5. Setup Database (10 min)

**Vercel Postgres:**
- [ ] Go to Vercel project → Storage
- [ ] Create Postgres database
- [ ] Copy connection string
- [ ] Add as `DATABASE_URL` environment variable
- [ ] Deploy to create tables automatically

**Or Supabase:**
- [ ] Create project at https://supabase.com
- [ ] Copy connection string (Session mode)
- [ ] Add as `DATABASE_URL`

### 6. Configure Webhook (10 min)
- [ ] Go to https://dashboard.stripe.com/webhooks
- [ ] Add endpoint: `https://your-backend.vercel.app/api/webhook/stripe`
- [ ] Select events:
  - [ ] `checkout.session.completed`
  - [ ] `payment_intent.succeeded`
- [ ] Copy webhook secret: `whsec_________________`
- [ ] Add to backend as `STRIPE_WEBHOOK_SECRET`
- [ ] Redeploy backend

### 7. Build Full Version (30 min)
```bash
cd Craig-O-Clean  # Full version directory

# Build
xcodebuild -scheme Craig-O-Clean -configuration Release build

# Archive
xcodebuild archive -scheme Craig-O-Clean \
  -archivePath ./build/Craig-O-Clean.xcarchive

# Export
xcodebuild -exportArchive \
  -archivePath ./build/Craig-O-Clean.xcarchive \
  -exportPath ./build \
  -exportOptionsPlist ExportOptions.plist
```

- [ ] Built successfully
- [ ] App works when tested locally
- [ ] Create DMG:
  ```bash
  hdiutil create -volname "Craig-O-Clean" \
    -srcfolder ./build/Craig-O-Clean.app \
    -ov -format UDZO \
    craig-o-clean-full.dmg
  ```

### 8. Upload Full Version (10 min)

**Option A: GitHub Releases**
```bash
gh release create v2.0.0 \
  craig-o-clean-full.dmg \
  --title "Craig-O-Clean Full v2.0.0"
```
- [ ] Uploaded to GitHub
- [ ] Download URL: `https://github.com/___/___/releases/download/v2.0.0/craig-o-clean-full.dmg`

**Option B: CDN**
- [ ] Upload to Cloudflare R2 / AWS S3 / DigitalOcean
- [ ] Make publicly accessible
- [ ] Copy URL: `https://________________`

### 9. Update Lite App (5 min)

Edit `Craig-O-Clean-Lite/UpgradeService.swift`:

```swift
private let stripeCheckoutURL = "https://buy.stripe.com/YOUR_LINK"
private let licenseValidationURL = "https://YOUR_BACKEND.vercel.app/api/license/validate"
private let downloadURL = "https://YOUR_BACKEND.vercel.app/api/download"
```

- [ ] Updated `stripeCheckoutURL`
- [ ] Updated `licenseValidationURL`
- [ ] Updated `downloadURL`
- [ ] Committed changes

### 10. Create Payment Link (5 min)
- [ ] Go to https://dashboard.stripe.com/payment-links
- [ ] Create new payment link
- [ ] Select your product
- [ ] Copy link: `https://buy.stripe.com/________________`
- [ ] Update in `UpgradeService.swift`

### 11. Test the Flow (15 min)

**Test Card**: `4242 4242 4242 4242`

- [ ] Build Lite app (`⌘R` in Xcode)
- [ ] Click "Upgrade" button
- [ ] Stripe checkout opens in browser
- [ ] Complete payment with test card
- [ ] Check backend logs for webhook
- [ ] Verify license in database:
  ```bash
  # Connect to your database
  psql $DATABASE_URL
  SELECT * FROM licenses;
  ```
- [ ] Verify download link works
- [ ] Test license validation
- [ ] End-to-end flow works! 🎉

### 12. Email Setup (Optional but Recommended)

**SendGrid:**
- [ ] Sign up at https://sendgrid.com
- [ ] Create API key
- [ ] Add to backend as `SENDGRID_API_KEY`
- [ ] Add `FROM_EMAIL`
- [ ] Test email sending

### 13. Go Live (When Ready)

**Switch to Production:**
- [ ] Activate Stripe account
- [ ] Get live API keys:
  - [ ] Live Publishable key: `pk_live_________________`
  - [ ] Live Secret key: `sk_live_________________`
- [ ] Create production webhook
- [ ] Update backend environment variables
- [ ] Set `NODE_ENV=production`
- [ ] Update Lite app with production URLs
- [ ] Build signed release version
- [ ] Distribute Lite app

## Quick Test Script

Run this to test your setup:

```bash
# Test backend health
curl https://your-backend.vercel.app/health

# Test checkout creation
curl -X POST https://your-backend.vercel.app/api/checkout/create \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","clientReferenceId":"test-123"}'

# Test license validation (after creating a test license)
curl "https://your-backend.vercel.app/api/license/validate?license_key=CRAIG-TEST-1234-5678-9012"
```

## Environment Variables Summary

Copy this checklist and fill in your values:

```bash
# Stripe
STRIPE_SECRET_KEY=sk_test_________________
STRIPE_PUBLISHABLE_KEY=pk_test_________________
STRIPE_WEBHOOK_SECRET=whsec_________________
STRIPE_PRICE_ID=price_________________

# URLs
APP_URL=https://________________
DOWNLOAD_URL=https://________________/craig-o-clean-full.dmg

# Database
DATABASE_URL=postgresql://________________

# Email (optional)
SENDGRID_API_KEY=SG.________________
FROM_EMAIL=support@neuralquantum.ai

# Server
PORT=3000
NODE_ENV=production
```

## Common Issues & Solutions

### ❌ "Webhook not working"
**Check:**
1. URL is publicly accessible
2. Webhook secret is correct
3. Events are selected in Stripe dashboard
4. Backend is deployed and running

**Test:**
```bash
# Use Stripe CLI
stripe listen --forward-to localhost:3000/api/webhook/stripe
stripe trigger checkout.session.completed
```

### ❌ "Download not working"
**Check:**
1. DMG file uploaded correctly
2. Download URL is public
3. License validation passes
4. File permissions are correct

**Test:**
```bash
# Direct download
curl -L https://your-download-url.com/craig-o-clean-full.dmg -o test.dmg
```

### ❌ "License validation failing"
**Check:**
1. Database connection works
2. License exists in database
3. Status is 'active'
4. API endpoint accessible

**Test:**
```bash
# Check database
psql $DATABASE_URL -c "SELECT * FROM licenses;"
```

## Timeline Estimate

| Task | Time | Cumulative |
|------|------|------------|
| Stripe setup | 20 min | 20 min |
| Backend deploy | 20 min | 40 min |
| Database setup | 10 min | 50 min |
| Webhook config | 10 min | 60 min |
| Build Full version | 30 min | 90 min |
| Upload DMG | 10 min | 100 min |
| Update Lite app | 5 min | 105 min |
| Testing | 15 min | 120 min |

**Total: ~2 hours** ⏱️

## Success Criteria

You're ready to launch when:

- ✅ Test card payment completes successfully
- ✅ Webhook receives and processes event
- ✅ License key generated and saved
- ✅ Download link works
- ✅ Full version installs and runs
- ✅ End-to-end flow tested 3+ times
- ✅ All environment variables configured
- ✅ Production keys ready to swap in

## Launch Day Checklist

- [ ] Switch to live Stripe keys
- [ ] Update all URLs to production
- [ ] Set `NODE_ENV=production`
- [ ] Test one more time with live mode
- [ ] Monitor first few transactions
- [ ] Have refund process ready
- [ ] Support email monitored

## Post-Launch Monitoring

**First 24 Hours:**
- [ ] Check Stripe dashboard every few hours
- [ ] Monitor backend logs
- [ ] Test download links
- [ ] Respond to any support emails

**First Week:**
- [ ] Review conversion rate (Lite → Full)
- [ ] Check refund requests
- [ ] Monitor error rates
- [ ] Gather user feedback

**Ongoing:**
- [ ] Weekly sales reports
- [ ] Monthly refund rate review
- [ ] Quarterly pricing review
- [ ] Continuous improvement

---

## Need Help?

- **Stripe Docs**: https://stripe.com/docs
- **Backend Issues**: Check logs in Vercel/Railway
- **Database Issues**: Check connection string
- **Email**: support@neuralquantum.ai

**You've got this! 🚀**
