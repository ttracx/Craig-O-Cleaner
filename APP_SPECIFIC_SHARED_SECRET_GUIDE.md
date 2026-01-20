# App-Specific Shared Secret Setup Guide

## Craig-O-Clean - Receipt Verification Configuration

**Purpose**: Securely verify App Store receipts for auto-renewable subscriptions

---

## What is an App-Specific Shared Secret?

An **app-specific shared secret** is a unique code used to verify receipts from the App Store for **only this app's auto-renewable subscriptions**.

### Why Use It?

1. **Security**: Keep your primary shared secret private
2. **App Transfer**: Essential if you transfer the app to another developer
3. **Isolation**: Separate receipt verification per app in your account
4. **Best Practice**: Recommended by Apple for production apps

---

## When You Need It

You need an app-specific shared secret if:

- ✅ Your app has **auto-renewable subscriptions** (Craig-O-Clean does!)
- ✅ You're verifying receipts on your backend server
- ✅ You want to isolate this app's subscription verification
- ✅ You plan to transfer the app to another developer in the future

---

## Step 1: Generate App-Specific Shared Secret

### In App Store Connect

1. **Navigate to Your App**
   - Go to [App Store Connect](https://appstoreconnect.apple.com)
   - Select "My Apps" → "Craig-O-Clean"

2. **Go to App Information**
   - Click "App Information" in the left sidebar
   - Scroll to "App-Specific Shared Secret"

3. **Generate Secret**
   - Click "Manage"
   - Click "Generate" or "Generate App-Specific Shared Secret"
   - **IMPORTANT**: Copy the secret immediately - you can't view it again!

4. **Store Securely**
   - The secret looks like: `a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6`
   - Save it in your password manager
   - Add it to your backend environment variables

---

## Step 2: Configure in Your Backend

### Environment Variables

Add the secret to your backend configuration:

```bash
# .env (DO NOT COMMIT THIS FILE)
APP_STORE_SHARED_SECRET=a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6
APP_STORE_VERIFY_URL_PRODUCTION=https://buy.itunes.apple.com/verifyReceipt
APP_STORE_VERIFY_URL_SANDBOX=https://sandbox.itunes.apple.com/verifyReceipt
```

### Example: Node.js/TypeScript

```typescript
// config/appstore.ts
export const appStoreConfig = {
    sharedSecret: process.env.APP_STORE_SHARED_SECRET!,
    verifyReceiptURL: {
        production: 'https://buy.itunes.apple.com/verifyReceipt',
        sandbox: 'https://sandbox.itunes.apple.com/verifyReceipt'
    }
};

// services/receipt-verification.ts
import axios from 'axios';
import { appStoreConfig } from '../config/appstore';

interface ReceiptVerificationRequest {
    'receipt-data': string;
    'password': string;
    'exclude-old-transactions': boolean;
}

interface ReceiptVerificationResponse {
    status: number;
    environment: 'Production' | 'Sandbox';
    receipt: any;
    latest_receipt_info?: any[];
    pending_renewal_info?: any[];
}

export async function verifyReceipt(
    receiptData: string,
    useSandbox: boolean = false
): Promise<ReceiptVerificationResponse> {
    const url = useSandbox
        ? appStoreConfig.verifyReceiptURL.sandbox
        : appStoreConfig.verifyReceiptURL.production;

    const requestBody: ReceiptVerificationRequest = {
        'receipt-data': receiptData,
        'password': appStoreConfig.sharedSecret, // App-specific shared secret
        'exclude-old-transactions': true
    };

    try {
        const response = await axios.post<ReceiptVerificationResponse>(
            url,
            requestBody,
            {
                headers: { 'Content-Type': 'application/json' },
                timeout: 30000
            }
        );

        // Handle sandbox redirect (status 21007)
        if (response.data.status === 21007 && !useSandbox) {
            // Receipt is from sandbox, retry with sandbox URL
            return verifyReceipt(receiptData, true);
        }

        return response.data;
    } catch (error) {
        console.error('Receipt verification failed:', error);
        throw new Error('Failed to verify receipt');
    }
}
```

---

## Step 3: Verify Receipts

### Receipt Verification Flow

```
┌─────────────┐
│   iOS App   │
└──────┬──────┘
       │ 1. Purchase subscription
       │
       ▼
┌─────────────┐
│  App Store  │
└──────┬──────┘
       │ 2. Return receipt
       │
       ▼
┌─────────────┐
│   iOS App   │
└──────┬──────┘
       │ 3. Send receipt to backend
       │
       ▼
┌─────────────┐
│   Backend   │──────┐
└─────────────┘      │ 4. Verify with Apple
                     │    + shared secret
                     ▼
              ┌─────────────┐
              │  App Store  │
              │   Server    │
              └──────┬──────┘
                     │ 5. Return verification result
                     ▼
              ┌─────────────┐
              │   Backend   │
              └──────┬──────┘
                     │ 6. Grant/revoke access
                     ▼
              ┌─────────────┐
              │  Database   │
              └─────────────┘
```

### Status Codes

| Code | Meaning | Action |
|------|---------|--------|
| 0 | Valid receipt | ✅ Grant access |
| 21000 | Malformed request | ❌ Reject |
| 21002 | Receipt malformed | ❌ Reject |
| 21003 | Receipt not authenticated | ❌ Reject |
| 21004 | Shared secret mismatch | ⚠️ Check secret |
| 21005 | Server error | 🔄 Retry |
| 21007 | Sandbox receipt in production | 🔄 Retry with sandbox |
| 21008 | Production receipt in sandbox | 🔄 Retry with production |

---

## Step 4: Handle Subscription Status

### Extract Subscription Info

```typescript
interface SubscriptionInfo {
    productId: string;
    transactionId: string;
    originalTransactionId: string;
    purchaseDate: Date;
    expiresDate: Date;
    isActive: boolean;
    autoRenewStatus: boolean;
}

function parseReceiptInfo(response: ReceiptVerificationResponse): SubscriptionInfo {
    if (response.status !== 0) {
        throw new Error(`Invalid receipt: status ${response.status}`);
    }

    // Get latest subscription info
    const latestInfo = response.latest_receipt_info?.[0];
    if (!latestInfo) {
        throw new Error('No subscription info found');
    }

    const expiresDate = new Date(parseInt(latestInfo.expires_date_ms));
    const isActive = expiresDate > new Date();

    return {
        productId: latestInfo.product_id,
        transactionId: latestInfo.transaction_id,
        originalTransactionId: latestInfo.original_transaction_id,
        purchaseDate: new Date(parseInt(latestInfo.purchase_date_ms)),
        expiresDate,
        isActive,
        autoRenewStatus: response.pending_renewal_info?.[0]?.auto_renew_status === '1'
    };
}
```

### Update User Subscription

```typescript
async function updateUserSubscription(
    userId: string,
    subscriptionInfo: SubscriptionInfo
) {
    await database.subscriptions.upsert({
        where: { userId },
        update: {
            productId: subscriptionInfo.productId,
            transactionId: subscriptionInfo.transactionId,
            originalTransactionId: subscriptionInfo.originalTransactionId,
            expiresAt: subscriptionInfo.expiresDate,
            isActive: subscriptionInfo.isActive,
            autoRenewEnabled: subscriptionInfo.autoRenewStatus,
            updatedAt: new Date()
        },
        create: {
            userId,
            productId: subscriptionInfo.productId,
            transactionId: subscriptionInfo.transactionId,
            originalTransactionId: subscriptionInfo.originalTransactionId,
            purchasedAt: subscriptionInfo.purchaseDate,
            expiresAt: subscriptionInfo.expiresDate,
            isActive: subscriptionInfo.isActive,
            autoRenewEnabled: subscriptionInfo.autoRenewStatus
        }
    });
}
```

---

## Step 5: API Endpoint Example

### Complete Verification Endpoint

```typescript
// api/subscriptions/verify.ts
import { Request, Response } from 'express';
import { verifyReceipt, parseReceiptInfo, updateUserSubscription } from '../services';

export async function verifySubscription(req: Request, res: Response) {
    try {
        const { receiptData, userId } = req.body;

        // Validate input
        if (!receiptData || !userId) {
            return res.status(400).json({
                error: 'Missing receiptData or userId'
            });
        }

        // Verify receipt with Apple
        const verificationResponse = await verifyReceipt(receiptData);

        // Parse subscription info
        const subscriptionInfo = parseReceiptInfo(verificationResponse);

        // Update database
        await updateUserSubscription(userId, subscriptionInfo);

        // Return result to client
        return res.status(200).json({
            success: true,
            subscription: {
                isActive: subscriptionInfo.isActive,
                expiresAt: subscriptionInfo.expiresDate.toISOString(),
                autoRenewEnabled: subscriptionInfo.autoRenewStatus,
                productId: subscriptionInfo.productId
            }
        });

    } catch (error) {
        console.error('Subscription verification error:', error);
        return res.status(500).json({
            error: 'Failed to verify subscription'
        });
    }
}
```

---

## Security Best Practices

### 1. Protect Your Shared Secret

```bash
# ✅ GOOD: Use environment variables
password: process.env.APP_STORE_SHARED_SECRET

# ❌ BAD: Hardcode in source
password: 'a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6'
```

### 2. Never Expose to Client

```typescript
// ✅ GOOD: Verify on backend
// Server: Keeps secret secure
app.post('/api/verify-receipt', verifySubscription);

// ❌ BAD: Verify on client
// iOS App: Exposes secret in compiled binary
```

### 3. Use HTTPS Only

```typescript
// ✅ GOOD: HTTPS endpoint
https://api.craigoclean.com/api/verify-receipt

// ❌ BAD: HTTP endpoint
http://api.craigoclean.com/api/verify-receipt
```

### 4. Handle Sandbox/Production

```typescript
// ✅ GOOD: Auto-detect environment
if (response.status === 21007) {
    return verifyReceipt(receiptData, true); // Retry sandbox
}

// ❌ BAD: Assume environment
const url = appStoreConfig.verifyReceiptURL.production;
```

### 5. Log Without Exposing

```typescript
// ✅ GOOD: Log outcome without secret
console.log('Receipt verification:', {
    status: response.status,
    environment: response.environment,
    hasSecret: !!appStoreConfig.sharedSecret
});

// ❌ BAD: Log secret
console.log('Receipt verification with secret:', appStoreConfig.sharedSecret);
```

---

## Testing

### Test in Sandbox

1. **Create Sandbox Test User**
   - App Store Connect → Users and Access → Sandbox Testers
   - Create test Apple ID for testing

2. **Test Purchase**
   - Sign in with sandbox test user on device
   - Make in-app purchase in TestFlight build
   - Verify receipt on backend with sandbox URL

3. **Verify Shared Secret Works**
   ```bash
   curl -X POST https://sandbox.itunes.apple.com/verifyReceipt \
     -H "Content-Type: application/json" \
     -d '{
       "receipt-data": "BASE64_RECEIPT_DATA",
       "password": "YOUR_SHARED_SECRET",
       "exclude-old-transactions": true
     }'
   ```

---

## Troubleshooting

### Status 21004: Shared Secret Mismatch

**Cause**: Wrong shared secret provided

**Solution**:
1. Regenerate shared secret in App Store Connect
2. Update backend environment variable
3. Redeploy backend
4. Test again

### Status 21007/21008: Environment Mismatch

**Cause**: Using production URL for sandbox receipt (or vice versa)

**Solution**: Implement auto-retry logic shown in code examples

### Empty latest_receipt_info

**Cause**: Receipt has no active subscriptions

**Solution**: Check if subscription expired or was canceled

---

## Production Checklist

- [ ] App-specific shared secret generated in App Store Connect
- [ ] Shared secret stored securely in environment variables
- [ ] Backend receipt verification endpoint implemented
- [ ] HTTPS endpoint configured
- [ ] Sandbox/production auto-detection implemented
- [ ] All status codes handled
- [ ] Error logging implemented
- [ ] Tested with sandbox test user
- [ ] Database schema supports subscription data
- [ ] iOS app sends receipts to backend for verification

---

## Craig-O-Clean Configuration

### Product IDs
```
Monthly: com.craigoclean.pro.monthly
Yearly:  com.craigoclean.pro.yearly
```

### Recommended Backend Endpoints
```
POST /api/subscriptions/verify
POST /api/subscriptions/status
GET  /api/subscriptions/check/:userId
```

---

## Additional Resources

- **Apple Receipt Validation Guide**: https://developer.apple.com/documentation/appstorereceipts/verifyreceipt
- **App-Specific Shared Secret**: https://help.apple.com/app-store-connect/#/devf341c0f01
- **Receipt Validation Best Practices**: https://developer.apple.com/documentation/storekit/in-app_purchase/validating_receipts_with_the_app_store

---

**Important Notes**:

1. **Migration to App Store Server API**: Apple is transitioning from receipt validation to the App Store Server API (v2). For new apps, consider implementing the App Store Server API instead. However, receipt validation will continue to work.

2. **Deprecation Timeline**: Receipt validation is not deprecated yet, but plan for eventual migration to App Store Server API.

3. **Backwards Compatibility**: Keep receipt validation for users on older iOS versions.

---

**Document Version**: 1.0
**Last Updated**: January 20, 2026
