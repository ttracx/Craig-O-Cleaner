# App Store Connect Subscription Setup Guide

## Craig-O-Clean - Complete Subscription Configuration

**App**: Craig-O-Clean
**Bundle ID**: com.craigoclean.app
**Subscription Type**: Auto-Renewable Subscriptions

---

## 📋 Overview

Craig-O-Clean offers two subscription tiers:
1. **Monthly Subscription** - $4.99/month
2. **Yearly Subscription** - $39.99/year (Save 33%)

Both include:
- Unlimited automatic cleanups
- Advanced scheduling options
- Priority support
- All future feature updates

---

## Step 1: Create Subscription Group

### Navigate to Subscriptions

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Select "My Apps" → "Craig-O-Clean"
3. Click "Subscriptions" in the left sidebar
4. Click "+" or "Create" under "Subscription Groups"

### Subscription Group Details

#### Reference Name (Internal Only)
```
Craig-O-Clean Pro Subscriptions
```

#### App Name (Customer-Facing)
```
Craig-O-Clean Pro
```
*This is what customers see in their subscription management*

---

## Step 2: Create Monthly Subscription

### Click "+" in the Subscription Group

Select "Create Subscription"

### Subscription Configuration

#### **Product ID** (Cannot be changed after creation)
```
com.craigoclean.pro.monthly
```

#### **Reference Name** (Internal only, can be changed)
```
Craig-O-Clean Pro Monthly
```

---

### Subscription Duration

**Duration**: `1 Month`

---

### Subscription Prices

#### Base Price (US)
```
$4.99 USD
```

**Pricing Strategy**:
- Tier: Select the tier that equals $4.99
- Click "Add Pricing" for other territories
- Apple will auto-fill equivalent prices
- Review and adjust for major markets if needed

#### Recommended Pricing by Territory

| Territory | Price | Notes |
|-----------|-------|-------|
| United States | $4.99 | Base price |
| Canada | $6.99 CAD | Auto-filled |
| United Kingdom | £4.99 | Adjust to match expectations |
| European Union | €4.99 | Adjust to match expectations |
| Australia | $7.99 AUD | Auto-filled |
| Japan | ¥700 | Adjust to match expectations |

*Tip: Use "Equalize Prices" to auto-fill all territories based on exchange rates*

---

### Subscription Localizations

Click "+ Add Localization"

#### English (U.S.) - Required

**Display Name**:
```
Monthly Pro Access
```

**Description**:
```
Get unlimited access to all Craig-O-Clean Pro features with a monthly subscription.

✓ Unlimited automatic memory cleanups
✓ Advanced scheduling and automation
✓ Priority customer support
✓ All future features and updates

Cancel anytime. Subscription automatically renews unless auto-renew is turned off at least 24 hours before the end of the current period.
```

#### Additional Localizations (Optional but Recommended)

**Spanish (es-ES)**
Display Name: `Acceso Pro Mensual`

**French (fr-FR)**
Display Name: `Accès Pro Mensuel`

**German (de-DE)**
Display Name: `Monatlicher Pro-Zugang`

---

### Review Information

#### Screenshot for Review (1280x960 or larger)
- Upload a screenshot showing the subscription purchase flow
- Or screenshot of Pro features in action
- Must be actual app screenshot

#### Review Notes
```
This is a monthly auto-renewable subscription that grants access to Pro features:
- Unlimited automatic cleanups
- Advanced scheduling options
- Priority support

Free trial: 7 days
Price: $4.99/month

The subscription can be tested with sandbox test users.
```

---

### Subscription Free Trial

**Offer a Free Trial**: `YES` ✅

**Duration**: `7 days`

**Eligibility**:
- [x] New subscribers
- [ ] Existing subscribers (usually leave unchecked)
- [ ] Previous subscribers (optional)

---

### Promotional Offers (Optional)

You can add introductory offers or promotional offers:

**Introductory Offer** (Alternative to free trial):
- Type: Pay up front, Pay as you go, or Free trial
- Duration: 3 days, 1 week, 2 weeks, 1 month, etc.
- Price: Discounted or free

*Recommendation: Use the 7-day free trial as primary offer*

---

## Step 3: Create Yearly Subscription

### Click "+" in the Same Subscription Group

Select "Create Subscription"

### Subscription Configuration

#### **Product ID**
```
com.craigoclean.pro.yearly
```

#### **Reference Name**
```
Craig-O-Clean Pro Yearly
```

---

### Subscription Duration

**Duration**: `1 Year`

---

### Subscription Prices

#### Base Price (US)
```
$39.99 USD
```

**Value Proposition**:
- Monthly: $4.99 × 12 = $59.88/year
- Yearly: $39.99/year
- **Savings: $19.89 (33% off)**

#### Recommended Pricing by Territory

| Territory | Price | Notes |
|-----------|-------|-------|
| United States | $39.99 | Base price |
| Canada | $54.99 CAD | Auto-filled |
| United Kingdom | £39.99 | Adjust if needed |
| European Union | €39.99 | Adjust if needed |
| Australia | $59.99 AUD | Auto-filled |
| Japan | ¥5,800 | Adjust if needed |

---

### Subscription Localizations

#### English (U.S.)

**Display Name**:
```
Yearly Pro Access
```

**Description**:
```
Get unlimited access to all Craig-O-Clean Pro features with a yearly subscription. Save 33% compared to monthly!

✓ Unlimited automatic memory cleanups
✓ Advanced scheduling and automation
✓ Priority customer support
✓ All future features and updates
✓ Best value - Save $19.89/year

Cancel anytime. Subscription automatically renews unless auto-renew is turned off at least 24 hours before the end of the current period.
```

---

### Review Information

**Screenshot**: Same as monthly (or show pricing comparison)

**Review Notes**:
```
This is a yearly auto-renewable subscription that grants access to Pro features:
- Unlimited automatic cleanups
- Advanced scheduling options
- Priority support

Free trial: 7 days
Price: $39.99/year (save 33% vs monthly)

The subscription can be tested with sandbox test users.
```

---

### Subscription Free Trial

**Offer a Free Trial**: `YES` ✅

**Duration**: `7 days`

**Eligibility**:
- [x] New subscribers
- [ ] Existing subscribers
- [ ] Previous subscribers

---

## Step 4: Configure Subscription Group Settings

### Back to Subscription Group Overview

#### App Name
```
Craig-O-Clean Pro
```

#### Subscription Group Display Name (Customer-Facing)
This appears in Settings → Apple ID → Subscriptions

**Display Name**:
```
Craig-O-Clean Pro
```

**Description** (Optional):
```
Unlock all Pro features with unlimited cleanups, advanced automation, and priority support.
```

---

### Subscription Group Metadata

#### Family Sharing

**Allow Family Sharing**: `NO` ❌

*Recommendation: Keep disabled unless you want families to share one subscription*

---

### Upgrade/Downgrade Paths

Apple automatically handles:
- **Upgrade**: Monthly → Yearly
  - User gets immediate access
  - Prorated credit applied
  - New subscription starts immediately

- **Downgrade**: Yearly → Monthly
  - Change takes effect at end of current period
  - User keeps yearly until it expires

**Default behavior is usually correct, no configuration needed.**

---

## Step 5: Set Up Billing Grace Period

### In Subscription Group Settings

Click "Set Up Billing Grace Period"

### Recommended Configuration

**Enable Billing Grace Period**: `YES` ✅

**Duration**: `16 days`

**Why Enable**:
- Retains subscribers during temporary billing issues
- Apple attempts to collect payment during grace period
- No interruption to your revenue if successful
- Reduces involuntary churn

**How It Works**:
1. Subscription fails to renew (expired card, insufficient funds)
2. User retains access for 16 days (grace period)
3. Apple attempts to collect payment
4. If successful: Subscription continues, no interruption
5. If fails: Subscription cancels after grace period

---

## Step 6: Submission Settings

### Streamlined Purchasing

**Status**: `Turned On` ✅ (Default and recommended)

**What it does**:
- Allows users to subscribe from outside your app
- Users can subscribe via App Store listing
- Users can resubscribe from Settings
- No configuration needed

**When to turn off**:
- Subscriptions with contingent pricing
- Win-back offers that require in-app context

*Recommendation: Keep ON for standard subscriptions*

---

## Step 7: Subscription Review Submission

### Before Submission Checklist

- [x] Subscription group created
- [x] Monthly subscription configured with 7-day trial
- [x] Yearly subscription configured with 7-day trial
- [x] Prices set for all major territories
- [x] Descriptions written in English
- [x] Screenshots uploaded
- [x] Review notes provided
- [x] Billing grace period enabled (16 days)
- [x] Streamlined purchasing enabled

### Submit with First App Version

**IMPORTANT**: You must submit subscriptions with your first app version.

#### In App Store Connect

1. Go to "App Store" tab
2. Select your version (e.g., "3.0 - Prepare for Submission")
3. Scroll to "In-App Purchases and Subscriptions"
4. Click "Add" or "+"
5. Select both:
   - Craig-O-Clean Pro Monthly
   - Craig-O-Clean Pro Yearly
6. Save

**The subscriptions will be reviewed together with your app.**

---

## Step 8: Testing Subscriptions

### Create Sandbox Test Users

1. **App Store Connect** → Users and Access → Sandbox Testers
2. Click "+"
3. Fill in test user details:
   - First Name: Test
   - Last Name: User
   - Email: testuser+craigoclean@yourdomain.com
   - Password: (secure password)
   - Country/Region: United States
   - App Store Territory: United States

**Create multiple test users for different scenarios**

### Test on Device

1. **Sign out of App Store** on test device
2. **Do NOT sign into sandbox in Settings**
3. **Launch your app** (TestFlight or Xcode build)
4. **Trigger subscription purchase**
5. **App Store will prompt** for sandbox credentials
6. **Sign in with test user**
7. **Complete purchase** (no charge, instant approval)

### Test Scenarios

- [x] Free trial starts correctly
- [x] Subscription renews (accelerated in sandbox)
- [x] Cancellation works
- [x] Restore purchases works
- [x] Upgrade Monthly → Yearly
- [x] Downgrade Yearly → Monthly
- [x] Expired subscription revokes access

### Sandbox Time Acceleration

Sandbox subscriptions renew much faster:
- 1 month subscription → Renews every 5 minutes
- 1 year subscription → Renews every 1 hour
- Free trial duration → Normal time (7 days = 7 days)

**Max 6 renewals** in sandbox, then subscription expires automatically.

---

## Step 9: Production Monitoring

### After Approval

#### Sales and Trends
- Monitor subscription metrics
- Track trial conversions
- Analyze churn rate

#### Subscription Reports
- Active subscriptions
- Renewal rates
- Cancellation reasons

#### Customer Support
- Handle subscription issues
- Assist with billing problems
- Process refund requests

---

## 📊 Subscription Metadata Summary

### Monthly Subscription

| Field | Value |
|-------|-------|
| **Product ID** | com.craigoclean.pro.monthly |
| **Display Name** | Monthly Pro Access |
| **Duration** | 1 Month |
| **Price** | $4.99 USD |
| **Free Trial** | 7 Days |
| **Family Sharing** | No |

### Yearly Subscription

| Field | Value |
|-------|-------|
| **Product ID** | com.craigoclean.pro.yearly |
| **Display Name** | Yearly Pro Access |
| **Duration** | 1 Year |
| **Price** | $39.99 USD (33% off) |
| **Free Trial** | 7 Days |
| **Family Sharing** | No |

---

## 💡 Best Practices

### Pricing Strategy

1. **Monthly**: Entry-level pricing ($4.99)
   - Low barrier to entry
   - Monthly commitment flexibility
   - Good for trial conversions

2. **Yearly**: Best value ($39.99)
   - 33% discount vs monthly
   - Clear savings message
   - Better LTV per customer

### Trial Period

**7 Days** is optimal:
- Long enough for users to experience value
- Short enough to maintain urgency
- Industry standard for utilities

### Grace Period

**16 Days** recommended:
- Maximum time for payment recovery
- Reduces involuntary churn
- Apple handles retry attempts
- No downside to enabling

### Display Names

Keep them simple and clear:
- ✅ "Monthly Pro Access"
- ✅ "Yearly Pro Access"
- ❌ "Craig-O-Clean Pro Monthly Subscription Plan"
- ❌ "1 Month Auto-Renewable"

---

## 🔍 Review Guidelines

### What Apple Reviews

- Subscription descriptions match app functionality
- Prices are clearly displayed in app
- Terms and conditions visible
- Cancellation information clear
- Restore purchases available
- No misleading claims

### Common Rejection Reasons

1. **Incomplete metadata**
   - Missing descriptions or screenshots
   - Unclear pricing in app

2. **Misleading information**
   - Subscription benefits not in app
   - Exaggerated claims

3. **Poor user experience**
   - Difficult to cancel
   - Hidden terms
   - Confusing pricing

### Prevention

- [x] Show pricing clearly in paywall
- [x] Display trial duration prominently
- [x] Include terms and privacy links
- [x] Implement "Restore Purchases"
- [x] Show subscription status in settings
- [x] Allow easy cancellation (via Settings)

---

## 📝 Copy/Paste Ready Content

### Terms & Conditions (for app)

```
SUBSCRIPTION TERMS

Craig-O-Clean Pro offers two auto-renewable subscription options:
• Monthly: $4.99/month
• Yearly: $39.99/year (save 33%)

FREE TRIAL
New subscribers receive a 7-day free trial. Your subscription will automatically begin after the trial period ends.

BILLING
• Payment charged to Apple ID at confirmation of purchase
• Subscription automatically renews unless canceled at least 24 hours before the end of the current period
• Account charged for renewal within 24 hours prior to the end of current period
• Subscriptions may be managed and auto-renewal turned off in Account Settings after purchase
• No cancellation of current subscription allowed during active period

CANCELLATION
You can cancel your subscription at any time through your Apple ID settings. Cancellation takes effect at the end of the current billing period.

Privacy Policy: https://craigoclean.com/privacy
Terms of Service: https://craigoclean.com/terms
```

### In-App Paywall Copy

**Header**:
```
Unlock Craig-O-Clean Pro
```

**Subheader**:
```
7-Day Free Trial, Then Choose Your Plan
```

**Features List**:
```
✓ Unlimited Automatic Cleanups
✓ Advanced Scheduling & Automation
✓ Priority Customer Support
✓ All Future Features & Updates
```

**Pricing Display**:
```
Monthly: $4.99/month
Yearly: $39.99/year (Save 33%)

Start 7-Day Free Trial
```

**Fine Print**:
```
Subscriptions automatically renew unless canceled at least 24 hours before the end of the current period. Manage subscriptions in Settings.

Terms of Service | Privacy Policy | Restore Purchases
```

---

## ✅ Final Checklist

### Before Submitting

- [ ] Subscription group created: "Craig-O-Clean Pro Subscriptions"
- [ ] Monthly subscription: com.craigoclean.pro.monthly ($4.99)
- [ ] Yearly subscription: com.craigoclean.pro.yearly ($39.99)
- [ ] Both subscriptions have 7-day free trial
- [ ] Prices set for all major territories
- [ ] English descriptions complete
- [ ] Screenshots uploaded for both
- [ ] Review notes provided
- [ ] Billing grace period enabled (16 days)
- [ ] Streamlined purchasing enabled
- [ ] Subscriptions added to app version
- [ ] Tested with sandbox users
- [ ] Paywall implemented in app
- [ ] Restore purchases implemented
- [ ] Terms & conditions accessible in app

---

## 🆘 Troubleshooting

### "Subscription not appearing in app"

**Cause**: Product IDs don't match

**Solution**:
1. Verify product IDs in App Store Connect
2. Check product IDs in your app code
3. Ensure exact match (case-sensitive)

### "Cannot connect to iTunes Store" (sandbox)

**Cause**: Using production environment

**Solution**:
1. Check StoreKit configuration
2. Ensure app is configured for sandbox
3. Verify test user credentials

### "Subscription unavailable"

**Cause**: Banking info not configured

**Solution**:
1. Complete tax and banking info in App Store Connect
2. Agreements must be signed
3. Wait 24 hours for processing

---

## 📚 Resources

- **Subscription Guide**: https://developer.apple.com/app-store/subscriptions/
- **In-App Purchase Documentation**: https://developer.apple.com/in-app-purchase/
- **Sandbox Testing**: https://developer.apple.com/documentation/storekit/in-app_purchase/testing_in-app_purchases_with_sandbox
- **App Store Review Guidelines**: https://developer.apple.com/app-store/review/guidelines/#in-app-purchase

---

**Document Version**: 1.0
**Last Updated**: January 20, 2026
**Products**:
- com.craigoclean.pro.monthly ($4.99/month)
- com.craigoclean.pro.yearly ($39.99/year)
