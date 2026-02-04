# Quick Deploy Guide - Get Live in 15 Minutes

## You Have Everything Already! ✅

- ✅ Stripe live keys configured
- ✅ Backend code ready
- ✅ Lite app with upgrade button
- ✅ Domain: craigoclean.com

## Deploy in 3 Commands

### 1. Deploy Backend (2 min)

```bash
cd "/Volumes/VibeStore/Craig-O-Cleaner/Craig-O-Clean-Lite/backend"
./deploy.sh
```

This will:
- Install Vercel CLI
- Deploy to Vercel
- Give you a URL like: `your-project.vercel.app`

### 2. Add Custom Domain (5 min)

**In Vercel Dashboard:**
1. Go to: https://vercel.com/dashboard
2. Click your project
3. Settings → Domains
4. Add: `craigoclean.com`

**In Your Domain Registrar:**
```
Type: A, Name: @, Value: 76.76.21.21
Type: CNAME, Name: www, Value: cname.vercel-dns.com
```

Wait 5 minutes for DNS.

### 3. Setup Stripe Webhook (3 min)

**Create Payment Link:**
1. Go to: https://dashboard.stripe.com/payment-links
2. Create link for product: `prod_Ts65Xjsu8Xbsb1`
3. Set price: $0.99
4. **Copy the link**
5. Update `UpgradeService.swift` line 12 with your link

**Add Webhook:**
1. Go to: https://dashboard.stripe.com/webhooks
2. Add endpoint: `https://craigoclean.com/api/webhook/stripe`
3. Events: `checkout.session.completed`
4. **Copy webhook secret** (whsec_...)

**Add to Vercel:**
```bash
vercel env add STRIPE_WEBHOOK_SECRET production
# Paste whsec_... value

vercel env add DATABASE_URL production
# Use Vercel Postgres or Supabase URL

vercel --prod
```

---

## Test (2 min)

```bash
# Build Lite app
# In Xcode: ⌘R

# Click "Upgrade" → Use test card:
# 4242 4242 4242 4242

# Check logs:
vercel logs --follow
```

---

## You're Live! 🎉

**Webhook:** `https://craigoclean.com/api/webhook/stripe`
**Ready to accept:** $0.99 payments
**Delivers:** License key + Full version download

---

## Need Help?

- **Full Guide:** `DEPLOYMENT_GUIDE.md`
- **Webhook Details:** `backend/README_WEBHOOK.md`
- **Checklist:** `UPGRADE_CHECKLIST.md`

**Total Time:** ~15 minutes
**Cost:** $0 (Vercel free tier)
**Revenue Potential:** Unlimited! 💰
