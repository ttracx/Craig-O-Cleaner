# App Store Server Notifications Setup Guide

## Craig-O-Clean - Server-to-Server Notifications Configuration

**Purpose**: Receive real-time notifications about subscription events (renewals, cancellations, refunds, etc.)

---

## Overview

App Store Server Notifications provide real-time information about in-app purchase events, allowing Craig-O-Clean to:

- Update subscription status immediately when users subscribe/unsubscribe
- Handle refunds and billing issues automatically
- Prevent service interruption due to failed payments
- Track subscription metrics accurately

---

## Prerequisites

Before setting up, ensure you have:

1. ✅ A backend server with HTTPS endpoint (public URL)
2. ✅ Ability to receive POST requests from Apple's servers
3. ✅ SSL/TLS certificate (required - Apple only sends to HTTPS endpoints)
4. ✅ App Store Connect access with Admin or App Manager role

---

## Step 1: Prepare Your Backend Endpoint

### Option A: Using Your Own Backend

Create an endpoint that accepts POST requests from Apple:

```typescript
// Example: Node.js/Express endpoint
app.post('/api/appstore/notifications', express.raw({ type: 'application/json' }), async (req, res) => {
    try {
        const notification = req.body;

        // Verify signature (required for production)
        const isValid = await verifyAppleSignature(notification);
        if (!isValid) {
            return res.status(401).send('Invalid signature');
        }

        // Process notification
        await processNotification(notification);

        // Always return 200 OK to acknowledge receipt
        res.status(200).send('OK');
    } catch (error) {
        console.error('Notification processing error:', error);
        res.status(500).send('Processing error');
    }
});
```

**Requirements**:
- Must return HTTP 200 within 30 seconds
- Must be publicly accessible (no firewall restrictions)
- Must use HTTPS (TLS 1.2+)
- Must handle Apple's IP ranges (whitelist not required)

### Option B: Using Cloud Functions

**Vercel/Netlify Functions**:
```typescript
// api/appstore-notifications.ts
export default async function handler(req: Request) {
    if (req.method !== 'POST') {
        return new Response('Method not allowed', { status: 405 });
    }

    const notification = await req.json();
    // Process notification

    return new Response('OK', { status: 200 });
}
```

**AWS Lambda**:
```typescript
exports.handler = async (event) => {
    const notification = JSON.parse(event.body);
    // Process notification

    return {
        statusCode: 200,
        body: 'OK'
    };
};
```

---

## Step 2: Configure in App Store Connect

### Production Server URL

1. **Go to App Store Connect**
   - Navigate to: [https://appstoreconnect.apple.com](https://appstoreconnect.apple.com)
   - Select "My Apps" → "Craig-O-Clean"

2. **Navigate to App Information**
   - Click "App Information" in the left sidebar
   - Scroll down to "App Store Server Notifications"

3. **Set Production Server URL**
   - Click "Set Up URL" under "Production Server URL"
   - Enter your production endpoint:
     ```
     https://api.craigoclean.com/api/appstore/notifications
     ```
   - Click "Save"

4. **Test Connection**
   - Apple will send a test notification immediately
   - Ensure your endpoint returns HTTP 200
   - Check Apple's status indicator (green = success)

### Sandbox Server URL (Recommended for Testing)

1. **Set Up Sandbox URL**
   - Click "Set Up URL" under "Sandbox Server URL"
   - Enter your sandbox/testing endpoint:
     ```
     https://api-dev.craigoclean.com/api/appstore/notifications
     ```
   - Or use the same URL with a query parameter:
     ```
     https://api.craigoclean.com/api/appstore/notifications?sandbox=true
     ```

2. **Test with TestFlight**
   - TestFlight purchases will trigger sandbox notifications
   - Test all subscription scenarios before production

---

## Step 3: Handle Notification Types

### Notification Structure

```json
{
  "signedPayload": "eyJhbGc..."
}
```

The `signedPayload` is a JSON Web Signature (JWS) that you must decode and verify.

### Key Notification Types

| Notification Type | Description | Action Required |
|------------------|-------------|-----------------|
| `SUBSCRIBED` | New subscription | Activate Pro features |
| `DID_RENEW` | Successful renewal | Extend subscription |
| `DID_FAIL_TO_RENEW` | Payment failed | Grace period handling |
| `DID_CHANGE_RENEWAL_STATUS` | User toggled auto-renew | Update UI status |
| `EXPIRED` | Subscription ended | Revoke Pro access |
| `REFUND` | Refund issued | Revoke Pro access |
| `PRICE_INCREASE_CONSENT` | Price change consent | Update pricing info |

### Processing Example

```typescript
async function processNotification(notification: any) {
    // Decode the JWS payload
    const payload = decodeJWS(notification.signedPayload);
    const { notificationType, data } = payload;

    // Extract transaction info
    const transactionInfo = decodeJWS(data.signedTransactionInfo);
    const originalTransactionId = transactionInfo.originalTransactionId;

    switch (notificationType) {
        case 'SUBSCRIBED':
            await activateSubscription(originalTransactionId);
            break;

        case 'DID_RENEW':
            await renewSubscription(originalTransactionId);
            break;

        case 'EXPIRED':
        case 'REFUND':
            await revokeSubscription(originalTransactionId);
            break;

        case 'DID_FAIL_TO_RENEW':
            await handleBillingIssue(originalTransactionId);
            break;

        // Handle other types...
    }
}
```

---

## Step 4: Verify Apple's Signature (Critical for Security)

Apple signs all notifications. You **must** verify signatures in production.

### Verification Steps

1. **Get Apple's Public Keys**
   ```
   https://api.storekit.itunes.apple.com/v1/certificates
   ```

2. **Decode JWS Header**
   - Extract the `x5c` field (certificate chain)
   - Get the signing certificate

3. **Verify Certificate Chain**
   - Verify against Apple's root CA
   - Check certificate is not revoked

4. **Verify Signature**
   - Use the public key to verify the payload signature

### Library Recommendations

**Node.js**:
```bash
npm install @apple/app-store-server-library
```

**Python**:
```bash
pip install appstoreserverlibrary
```

**Swift** (for server-side Swift):
```swift
// Use Apple's official Swift library
```

---

## Step 5: Testing

### Test Scenarios

1. **New Subscription**
   - Subscribe via TestFlight
   - Verify `SUBSCRIBED` notification received
   - Check Pro features activated

2. **Renewal**
   - Wait for subscription to renew (or use sandbox accelerated time)
   - Verify `DID_RENEW` notification
   - Check subscription extended

3. **Cancellation**
   - Cancel subscription
   - Verify `DID_CHANGE_RENEWAL_STATUS` notification
   - At expiration, verify `EXPIRED` notification

4. **Failed Payment**
   - Use a test card that fails
   - Verify `DID_FAIL_TO_RENEW` notification
   - Check grace period handling

5. **Refund**
   - Issue refund via App Store Connect
   - Verify `REFUND` notification
   - Check Pro access revoked

### Monitoring

- Log all incoming notifications
- Monitor response times (must be < 30s)
- Track notification delivery success rate
- Set up alerts for processing failures

---

## Step 6: Production Checklist

- [ ] Production endpoint is HTTPS with valid certificate
- [ ] Endpoint returns HTTP 200 within 30 seconds
- [ ] JWS signature verification implemented
- [ ] All notification types handled
- [ ] Database updated on each notification
- [ ] User subscription status synced in real-time
- [ ] Error handling and logging implemented
- [ ] Monitoring and alerts configured
- [ ] Sandbox testing completed successfully
- [ ] Production URL configured in App Store Connect

---

## Recommended Server URLs

Based on your setup, here are the recommended URLs:

### If Using Vercel
```
Production: https://craigoclean.com/api/appstore/notifications
Sandbox:    https://craigoclean.com/api/appstore/notifications?sandbox=true
```

### If Using AWS/Custom Server
```
Production: https://api.craigoclean.com/v1/appstore/notifications
Sandbox:    https://api-staging.craigoclean.com/v1/appstore/notifications
```

---

## Troubleshooting

### "Connection Failed" Error

**Causes**:
- Server not responding
- Firewall blocking Apple's IPs
- SSL certificate invalid
- Endpoint returning non-200 status

**Solutions**:
1. Test your endpoint with curl:
   ```bash
   curl -X POST https://api.craigoclean.com/api/appstore/notifications \
     -H "Content-Type: application/json" \
     -d '{"test": "notification"}'
   ```
2. Check server logs for incoming requests
3. Verify SSL certificate is valid
4. Ensure no rate limiting or DDoS protection blocking Apple

### Notifications Not Received

**Causes**:
- URL not saved in App Store Connect
- Endpoint returning errors
- Processing takes > 30 seconds

**Solutions**:
1. Re-save the URL in App Store Connect
2. Check server logs for errors
3. Optimize processing to be async/queued
4. Return 200 immediately, process asynchronously

---

## Security Best Practices

1. ✅ **Always verify JWS signatures** - Never trust unverified notifications
2. ✅ **Use HTTPS only** - Apple requires it
3. ✅ **Rate limit** - Prevent abuse (though Apple is trusted sender)
4. ✅ **Log everything** - Essential for debugging
5. ✅ **Handle duplicates** - Apple may retry, use transaction IDs for idempotency
6. ✅ **Validate payload structure** - Don't assume format
7. ✅ **Keep certificates updated** - Monitor Apple's cert updates

---

## Next Steps

1. **Build your backend endpoint** using the examples above
2. **Deploy to production** with HTTPS
3. **Configure URLs** in App Store Connect
4. **Test thoroughly** in sandbox
5. **Monitor** after production launch

---

## Resources

- **Apple Documentation**: https://developer.apple.com/documentation/appstoreservernotifications
- **Apple Server Library (Node.js)**: https://www.npmjs.com/package/@apple/app-store-server-library
- **Server Notifications Guide**: https://developer.apple.com/app-store/server-notifications/

---

**Document Version**: 1.0
**Last Updated**: January 20, 2026
