# Stripe Webhook Endpoint for craigoclean.com

## Your Webhook URL

**Production:** `https://craigoclean.com/api/webhook/stripe`

---

## Quick Deploy (2 Minutes)

```bash
cd backend

# Deploy to Vercel
./deploy.sh

# Add webhook secret after creating webhook in Stripe
vercel env add STRIPE_WEBHOOK_SECRET production
vercel env add DATABASE_URL production

# Redeploy
vercel --prod
```

---

## Setup Webhook in Stripe

1. **Go to:** https://dashboard.stripe.com/webhooks
2. **Click:** "Add endpoint"
3. **URL:** `https://craigoclean.com/api/webhook/stripe`
4. **Events:**
   - ✅ `checkout.session.completed`
   - ✅ `payment_intent.succeeded`
   - ✅ `charge.refunded`
5. **Copy webhook secret** (whsec_...)
6. **Add to Vercel:**
   ```bash
   vercel env add STRIPE_WEBHOOK_SECRET production
   # Paste whsec_... value
   vercel --prod
   ```

---

## Test Webhook

```bash
# Install Stripe CLI
brew install stripe/stripe-brew/stripe

# Test
stripe login
stripe trigger checkout.session.completed

# Check logs
vercel logs --follow
```

Expected output:
```
[WEBHOOK] Received webhook from Stripe
[WEBHOOK] Signature verified successfully
[WEBHOOK] Event type: checkout.session.completed
[PAYMENT] License created: CRAIG-XXXX-XXXX-XXXX-XXXX
```

---

## What This Webhook Does

1. ✅ Receives payment notification from Stripe
2. ✅ Verifies webhook signature (security)
3. ✅ Generates license key: `CRAIG-XXXX-XXXX-XXXX-XXXX`
4. ✅ Saves to database
5. ✅ Sends email with license + download link
6. ✅ Handles refunds (deactivates license)

---

## Your webhook is ready! 🚀

Just deploy and add the URL to Stripe Dashboard.
