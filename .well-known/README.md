# Apple Domain Verification

This directory contains the Apple domain verification file required for Sign In with Apple.

## Setup Instructions

### 1. Download Verification File from Apple

1. Go to **https://developer.apple.com/account/resources/identifiers/list**
2. Filter by **Services IDs**
3. Select `com.craigoclean.web`
4. Click **Configure** next to Sign In with Apple
5. Add domain: `craigoclean.com`
6. **Download** the verification file: `apple-developer-domain-association.txt`

### 2. Place File in This Directory

Copy the downloaded file to:
```
.well-known/apple-developer-domain-association.txt
```

### 3. Test Locally

Run the verification server:
```bash
npm run serve-domain-verification
```

Then test the endpoint:
```bash
curl http://localhost:3000/.well-known/apple-developer-domain-association.txt
```

### 4. Deploy to Production

The verification file must be accessible at:
```
https://craigoclean.com/.well-known/apple-developer-domain-association.txt
```

**Deployment Options:**

#### Option A: Static File Hosting (Recommended)
If you're using Vercel, Netlify, or similar:
- Add this `.well-known` folder to your web project's `public` directory
- Deploy normally - the file will be served automatically

#### Option B: Express/Node Server
- Deploy `domain-verification-server.js` to your production server
- Ensure it runs on your domain at port 80/443
- Configure SSL certificate for HTTPS

#### Option C: Nginx
Add this to your Nginx config:
```nginx
location /.well-known/apple-developer-domain-association.txt {
    alias /path/to/this/directory/apple-developer-domain-association.txt;
    add_header Content-Type text/plain;
}
```

### 5. Verify Domain in Apple Developer Portal

After deploying:
1. Go back to Sign In with Apple configuration
2. Click **Verify** next to your domain
3. Apple will check: `https://craigoclean.com/.well-known/apple-developer-domain-association.txt`
4. If successful, your domain will show as **Verified** ✓

## Troubleshooting

### Domain Verification Fails

**Check 1: File is accessible**
```bash
curl https://craigoclean.com/.well-known/apple-developer-domain-association.txt
```

Should return the verification content (not a 404 or error)

**Check 2: Content-Type is correct**
```bash
curl -I https://craigoclean.com/.well-known/apple-developer-domain-association.txt
```

Should include: `Content-Type: text/plain`

**Check 3: HTTPS is working**
- The URL MUST use HTTPS (not HTTP)
- SSL certificate must be valid
- No redirect loops

**Check 4: File content is exact**
- Don't modify the verification file
- No extra whitespace or newlines
- Exact content as downloaded from Apple

### Common Issues

1. **404 Not Found**: File not deployed or wrong path
2. **Mixed Content**: Ensure HTTPS, not HTTP
3. **CORS Errors**: Not applicable for this file, ignore browser CORS warnings
4. **Verification Timeout**: Check server response time (should be < 5 seconds)

## Security Notes

- ✅ **Safe to commit**: This file is public and meant to be accessible
- ✅ **Safe to share**: Contains no secrets or sensitive data
- ✅ **Safe to cache**: File content never changes once generated
- ❌ **Don't modify**: Must match Apple's generated content exactly

## File Location

This file should be accessible at:
```
https://[YOUR_DOMAIN]/.well-known/apple-developer-domain-association.txt
```

For Craig-O-Clean:
```
https://craigoclean.com/.well-known/apple-developer-domain-association.txt
```
