# Craig-O-Clean Suite Billing Documentation

This document describes the billing implementation across all Craig-O-Clean Suite platforms.

## Overview

Craig-O-Clean Suite uses a freemium model with subscription-based monetization:

| Tier | Price | Trial | Features |
|------|-------|-------|----------|
| Free | $0 | - | View-only metrics and process list |
| Monthly | $0.99/month | 7 days | Full feature access |
| Yearly | $9.99/year | 7 days | Full feature access (2 months free) |

## Platform Billing Providers

| Platform | Primary Provider | Fallback | Backend Required |
|----------|-----------------|----------|------------------|
| Android | Google Play Billing | - | No |
| Windows (Store) | Microsoft Store IAP | - | No |
| Windows (Direct) | Stripe | - | Yes |
| Linux | Stripe | - | Yes |
| macOS | App Store IAP | - | No |

## Product IDs

### Google Play

```
craigoclean_monthly    # Monthly subscription
craigoclean_yearly     # Yearly subscription
```

### Microsoft Store

```
craigoclean_monthly    # Monthly subscription
craigoclean_yearly     # Yearly subscription
```

### Stripe

```
price_craigoclean_monthly    # Monthly price ID
price_craigoclean_yearly     # Yearly price ID
prod_craigoclean             # Product ID
```

## Android (Google Play Billing)

### Setup

1. Create subscription products in Google Play Console
2. Configure base plans with 7-day free trial offers
3. Integrate Google Play Billing Library v6+

### Implementation

```kotlin
// BillingRepository.kt
@Singleton
class BillingRepository @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val billingClient = BillingClient.newBuilder(context)
        .setListener(purchasesUpdatedListener)
        .enablePendingPurchases()
        .build()

    suspend fun queryProducts(): List<ProductDetails> {
        val params = QueryProductDetailsParams.newBuilder()
            .setProductList(
                listOf(
                    Product.newBuilder()
                        .setProductId("craigoclean_monthly")
                        .setProductType(ProductType.SUBS)
                        .build(),
                    Product.newBuilder()
                        .setProductId("craigoclean_yearly")
                        .setProductType(ProductType.SUBS)
                        .build()
                )
            )
            .build()

        return billingClient.queryProductDetails(params).productDetailsList
    }

    suspend fun purchase(activity: Activity, productDetails: ProductDetails) {
        val offerToken = productDetails.subscriptionOfferDetails
            ?.firstOrNull()?.offerToken ?: return

        val params = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(
                listOf(
                    ProductDetailsParams.newBuilder()
                        .setProductDetails(productDetails)
                        .setOfferToken(offerToken)
                        .build()
                )
            )
            .build()

        billingClient.launchBillingFlow(activity, params)
    }

    private fun handlePurchase(purchase: Purchase) {
        if (purchase.purchaseState == PurchaseState.PURCHASED) {
            if (!purchase.isAcknowledged) {
                acknowledgePurchase(purchase)
            }
            updateEntitlement(purchase)
        }
    }
}
```

### Trial Configuration

Configure trials in Google Play Console:
1. Go to Monetization > Subscriptions
2. Select base plan
3. Add offer with 7-day free trial

### Testing

Use test accounts in Google Play Console for testing purchases without real charges.

## Windows (Microsoft Store)

### Store IAP Implementation

```csharp
// BillingService.cs
public class BillingService
{
    private StoreContext _storeContext;

    public async Task InitializeAsync()
    {
        _storeContext = StoreContext.GetDefault();
    }

    public async Task<IReadOnlyList<StoreProduct>> GetProductsAsync()
    {
        string[] productIds = { "craigoclean_monthly", "craigoclean_yearly" };

        StoreProductQueryResult result = await _storeContext.GetStoreProductsAsync(
            new[] { "Durable", "Subscription" },
            productIds
        );

        return result.Products.Values.ToList();
    }

    public async Task<StorePurchaseResult> PurchaseAsync(string productId)
    {
        var result = await _storeContext.GetStoreProductsAsync(
            new[] { "Subscription" },
            new[] { productId }
        );

        if (result.Products.TryGetValue(productId, out var product))
        {
            return await product.RequestPurchaseAsync();
        }

        return null;
    }

    public async Task<bool> CheckEntitlementAsync()
    {
        var license = await _storeContext.GetAppLicenseAsync();

        foreach (var addOn in license.AddOnLicenses)
        {
            if (addOn.Value.IsActive &&
                (addOn.Key == "craigoclean_monthly" ||
                 addOn.Key == "craigoclean_yearly"))
            {
                return true;
            }
        }

        return false;
    }
}
```

### Direct Distribution (Stripe)

For builds distributed outside the Microsoft Store:

```csharp
// StripeBillingService.cs
public class StripeBillingService
{
    private readonly HttpClient _httpClient;
    private readonly string _backendUrl;

    public async Task<string> CreateCheckoutSessionAsync(string priceId)
    {
        var response = await _httpClient.PostAsJsonAsync(
            $"{_backendUrl}/create-checkout-session",
            new { priceId, platform = "windows" }
        );

        var result = await response.Content.ReadFromJsonAsync<CheckoutResponse>();
        return result.Url;
    }

    public async Task<bool> VerifyEntitlementAsync(string token)
    {
        var response = await _httpClient.GetAsync(
            $"{_backendUrl}/verify-entitlement?token={token}"
        );

        return response.IsSuccessStatusCode;
    }
}
```

## Linux (Stripe)

### Implementation

```dart
// billing_service.dart
class BillingService {
  final String _backendUrl;
  final SecureStorage _storage;

  Future<void> startCheckout(String priceId) async {
    final response = await http.post(
      Uri.parse('$_backendUrl/create-checkout-session'),
      body: jsonEncode({
        'priceId': priceId,
        'platform': 'linux',
        'returnUrl': 'craigoclean://billing/success',
      }),
    );

    final data = jsonDecode(response.body);
    await launchUrl(Uri.parse(data['url']));
  }

  Future<void> handleDeepLink(Uri uri) async {
    if (uri.path == '/billing/success') {
      final sessionId = uri.queryParameters['session_id'];
      await _verifyAndStoreEntitlement(sessionId);
    }
  }

  Future<bool> verifyEntitlement() async {
    final token = await _storage.read('entitlement_token');
    if (token == null) return false;

    final response = await http.get(
      Uri.parse('$_backendUrl/verify-entitlement'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      // Update offline grace period
      await _storage.write('last_verified', DateTime.now().toIso8601String());
      return true;
    }

    // Check offline grace period
    return _isOfflineGraceActive();
  }

  bool _isOfflineGraceActive() {
    final lastVerified = _storage.read('last_verified');
    if (lastVerified == null) return false;

    final lastDate = DateTime.parse(lastVerified);
    final gracePeriod = Duration(hours: 72);

    return DateTime.now().difference(lastDate) < gracePeriod;
  }
}
```

### Secure Token Storage

```dart
// secure_storage.dart
class SecureStorage {
  // Uses libsecret on GNOME, KWallet on KDE

  Future<void> write(String key, String value) async {
    // Platform channel to native code
    await _channel.invokeMethod('write', {
      'collection': 'craigoclean',
      'key': key,
      'value': value,
    });
  }

  Future<String?> read(String key) async {
    return await _channel.invokeMethod('read', {
      'collection': 'craigoclean',
      'key': key,
    });
  }
}
```

## Backend API (Stripe)

### Endpoints

#### Create Checkout Session

```
POST /api/create-checkout-session
Content-Type: application/json

{
  "priceId": "price_craigoclean_monthly",
  "platform": "linux",
  "returnUrl": "craigoclean://billing/success"
}

Response:
{
  "sessionId": "cs_xxx",
  "url": "https://checkout.stripe.com/..."
}
```

#### Verify Entitlement

```
GET /api/verify-entitlement
Authorization: Bearer <token>

Response:
{
  "valid": true,
  "subscription": {
    "id": "sub_xxx",
    "status": "active",
    "currentPeriodEnd": "2024-02-01T00:00:00Z",
    "cancelAtPeriodEnd": false
  }
}
```

#### Customer Portal

```
POST /api/customer-portal
Authorization: Bearer <token>

Response:
{
  "url": "https://billing.stripe.com/session/..."
}
```

### Webhook Handling

```typescript
// webhooks.ts
app.post('/webhooks/stripe', async (req, res) => {
  const sig = req.headers['stripe-signature'];
  const event = stripe.webhooks.constructEvent(req.body, sig, webhookSecret);

  switch (event.type) {
    case 'customer.subscription.created':
    case 'customer.subscription.updated':
      await handleSubscriptionUpdate(event.data.object);
      break;

    case 'customer.subscription.deleted':
      await handleSubscriptionDeleted(event.data.object);
      break;

    case 'invoice.payment_failed':
      await handlePaymentFailed(event.data.object);
      break;
  }

  res.json({ received: true });
});

async function handleSubscriptionUpdate(subscription: Stripe.Subscription) {
  await db.entitlements.upsert({
    where: { stripeCustomerId: subscription.customer },
    update: {
      status: mapSubscriptionStatus(subscription.status),
      currentPeriodEnd: new Date(subscription.current_period_end * 1000),
      cancelAtPeriodEnd: subscription.cancel_at_period_end,
    },
    create: {
      stripeCustomerId: subscription.customer,
      stripeSubscriptionId: subscription.id,
      status: mapSubscriptionStatus(subscription.status),
      currentPeriodEnd: new Date(subscription.current_period_end * 1000),
    },
  });
}
```

## Entitlement State Machine

```
┌─────────┐
│  Free   │◄────────────────────────────────────┐
└────┬────┘                                      │
     │ Start Trial                               │
     ▼                                           │
┌─────────────┐                                  │
│ Trial Active │──────Trial Expires─────────────┤
└──────┬──────┘                                  │
       │ Subscribe                               │
       ▼                                         │
┌────────────┐                                   │
│ Subscribed │◄──────────────────────┐          │
└─────┬──────┘                       │          │
      │                              │          │
      ├──Payment Failed──►┌─────────────────┐   │
      │                   │ Grace Period    │───┤
      │                   └─────────────────┘   │
      │                              │          │
      │                   Payment Recovered     │
      │                              │          │
      │◄─────────────────────────────┘          │
      │                                         │
      │ Cancel/Expire                           │
      ▼                                         │
┌─────────────────┐                             │
│ Sub Expired     │─────────────────────────────┘
└─────────────────┘
      │
      │ Re-subscribe
      │
      ▼
┌────────────┐
│ Subscribed │
└────────────┘
```

## Trial Implementation

### Store-Managed Trials (Android, Windows Store)

- Configured in store console
- Automatically managed by platform
- No custom logic needed

### API-Managed Trials (Stripe)

```typescript
// Create subscription with trial
const subscription = await stripe.subscriptions.create({
  customer: customerId,
  items: [{ price: priceId }],
  trial_period_days: 7,
  payment_behavior: 'default_incomplete',
  expand: ['latest_invoice.payment_intent'],
});
```

## Offline Support

### Store-Based (Android, Windows)

- Licenses cached by platform
- Periodic re-validation by store
- Limited offline access built-in

### Stripe-Based (Linux, Direct Windows)

- Token stored in secure keychain
- 72-hour offline grace period
- Re-verification on network availability

```dart
bool canUseFeature(Feature feature) {
  if (isOnline) {
    return verifyEntitlementOnline();
  }

  // Offline check
  if (lastVerified == null) return false;

  final offlineGrace = Duration(hours: 72);
  if (DateTime.now().difference(lastVerified) > offlineGrace) {
    return false; // Grace period expired
  }

  return cachedEntitlement.isActive;
}
```

## Restore Purchases

### Android

```kotlin
suspend fun restorePurchases() {
    val params = QueryPurchasesParams.newBuilder()
        .setProductType(ProductType.SUBS)
        .build()

    val result = billingClient.queryPurchasesAsync(params)

    for (purchase in result.purchasesList) {
        if (purchase.purchaseState == PurchaseState.PURCHASED) {
            updateEntitlement(purchase)
        }
    }
}
```

### Windows Store

```csharp
public async Task RestorePurchasesAsync()
{
    var license = await _storeContext.GetAppLicenseAsync();
    UpdateEntitlementFromLicense(license);
}
```

### Stripe

```dart
Future<void> restorePurchases() async {
  // Check if user has existing subscription via email lookup
  final email = await promptForEmail();

  final response = await http.post(
    Uri.parse('$_backendUrl/restore-subscription'),
    body: jsonEncode({'email': email}),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    await _storage.write('entitlement_token', data['token']);
    await verifyEntitlement();
  }
}
```

## Testing

### Android

1. Create test accounts in Play Console
2. Use `com.android.vending.billing.DEBUG` for debug builds
3. Test with license testing accounts

### Windows

1. Use Windows App Certification Kit
2. Test with developer accounts
3. Simulate subscription states

### Stripe

1. Use Stripe test mode and test cards
2. Test webhook events with Stripe CLI
3. Simulate subscription lifecycle events

## Analytics Events

Track these events for billing analytics:

- `paywall_shown`
- `plan_selected`
- `purchase_started`
- `purchase_completed`
- `purchase_failed`
- `purchase_cancelled`
- `subscription_restored`
- `trial_started`
- `trial_expired`
- `subscription_expired`
