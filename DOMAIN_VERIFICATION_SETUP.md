# Apple Domain Verification Setup Guide

Complete guide for setting up Apple Sign In domain verification for Craig-O-Clean.

## 🎯 Overview

Apple requires domain verification before you can use Sign In with Apple on the web. This involves:
1. Downloading a verification file from Apple Developer Portal
2. Hosting it at `https://craigoclean.com/.well-known/apple-developer-domain-association.txt`
3. Verifying the domain in Apple Developer Portal

## 📋 Step-by-Step Instructions

### Step 1: Access Apple Developer Portal

1. Go to **https://developer.apple.com/account**
2. Click **Certificates, Identifiers & Profiles**
3. Or go directly to: https://developer.apple.com/account/resources/identifiers/list

### Step 2: Find Your Services ID

1. At the top right, **change the dropdown from "App IDs" to "Services IDs"**
2. Look for: `com.craigoclean.web`
3. Click on it to open configuration

### Step 3: Configure Sign In with Apple

1. Check the box next to **"Sign In with Apple"** (if not already checked)
2. Click the **"Configure"** button (or **"Edit"** if already configured)
3. You'll see a configuration modal

### Step 4: Add Your Domain

In the configuration modal:

**Domains and Subdomains:**
1. Click the **"+"** button
2. Enter: `craigoclean.com` (without https:// or www)
3. Apple will generate a verification file

**Website URLs (Return URLs):**
1. Click the **"+"** button
2. Enter: `https://craigoclean.com/auth/apple/callback`
3. Or whatever callback URL your app uses

### Step 5: Download Verification File

1. After adding the domain, you'll see a **"Download"** link
2. Click it to download: `apple-developer-domain-association.txt`
3. **Save this file** - you'll need it in the next step

The file will look something like:
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ...
```

### Step 6: Place Verification File in Project

Move the downloaded file to your project:

```bash
# Copy the file to the .well-known directory
cp ~/Downloads/apple-developer-domain-association.txt .well-known/
```

Verify it's in the right place:
```bash
ls -la .well-known/apple-developer-domain-association.txt
```

### Step 7: Test Locally (Optional)

Install dependencies:
```bash
npm install
```

Start the verification server:
```bash
npm run serve-domain-verification
```

Test the endpoint:
```bash
curl http://localhost:3000/.well-known/apple-developer-domain-association.txt
```

You should see the verification code from the file.

### Step 8: Deploy to Production

You need to make the file accessible at:
```
https://craigoclean.com/.well-known/apple-developer-domain-association.txt
```

**Choose a deployment method:**

#### Option A: Vercel/Netlify (Recommended for Static Sites)

1. Add `.well-known` to your `public` folder (if using Next.js/React)
2. Deploy normally: `vercel --prod` or `netlify deploy --prod`
3. Verify: `curl https://craigoclean.com/.well-known/apple-developer-domain-association.txt`

#### Option B: Node.js Server (Express)

1. Deploy `domain-verification-server.js` to your production server
2. Run with: `node domain-verification-server.js`
3. Use PM2 or systemd for process management:
   ```bash
   # Using PM2
   npm install -g pm2
   pm2 start domain-verification-server.js --name "apple-domain-verification"
   pm2 save
   ```

#### Option C: Nginx

Add to your Nginx config:
```nginx
server {
    listen 443 ssl;
    server_name craigoclean.com;

    # SSL configuration
    ssl_certificate /path/to/certificate.crt;
    ssl_certificate_key /path/to/private.key;

    # Apple domain verification
    location /.well-known/apple-developer-domain-association.txt {
        alias /path/to/craig-o-clean/.well-known/apple-developer-domain-association.txt;
        add_header Content-Type text/plain;
        add_header Cache-Control "public, max-age=31536000";
    }

    # Your app configuration...
}
```

Then reload Nginx:
```bash
sudo nginx -t
sudo systemctl reload nginx
```

### Step 9: Verify Domain in Apple Developer Portal

Once the file is live on your domain:

1. Go back to Apple Developer Portal
2. Navigate to your Services ID configuration
3. In the Sign In with Apple settings, you should see your domain
4. Click **"Verify"** next to `craigoclean.com`
5. Apple will check: `https://craigoclean.com/.well-known/apple-developer-domain-association.txt`
6. If successful: ✅ **"Verified"** will appear next to your domain

### Step 10: Save Configuration

1. Click **"Continue"** in the Sign In with Apple configuration modal
2. Click **"Save"** on the Services ID page
3. You're done! 🎉

## ✅ Verification Checklist

Before clicking "Verify" in Apple Developer Portal, ensure:

- [ ] File is accessible via HTTPS (not HTTP)
- [ ] URL returns 200 OK status
- [ ] Content-Type is `text/plain`
- [ ] File content matches exactly what Apple provided (no modifications)
- [ ] No redirects (direct access to file)
- [ ] SSL certificate is valid
- [ ] Response time < 5 seconds

Test with:
```bash
# Test accessibility
curl -v https://craigoclean.com/.well-known/apple-developer-domain-association.txt

# Should return:
# - HTTP 200 OK
# - Content-Type: text/plain
# - The verification code
```

## 🚨 Troubleshooting

### "Domain verification failed"

**Check 1: Is the file accessible?**
```bash
curl https://craigoclean.com/.well-known/apple-developer-domain-association.txt
```

If you get 404: File not deployed correctly
If you get timeout: Server not responding
If you get SSL error: Certificate issues

**Check 2: Is HTTPS working?**
- Must use HTTPS, not HTTP
- SSL certificate must be valid and not expired
- No mixed content warnings

**Check 3: Is the content correct?**
```bash
# Compare local file with deployed file
diff .well-known/apple-developer-domain-association.txt <(curl -s https://craigoclean.com/.well-known/apple-developer-domain-association.txt)
```

Should show no differences.

**Check 4: Check response headers**
```bash
curl -I https://craigoclean.com/.well-known/apple-developer-domain-association.txt
```

Should include:
```
HTTP/2 200
content-type: text/plain
```

### "Cannot find Services ID"

- Make sure you're in **Services IDs**, not App IDs
- Services ID should be: `com.craigoclean.web`
- If it doesn't exist, create it:
  1. Click "+" button
  2. Select "Services IDs"
  3. Description: "Craig-O-Clean Web"
  4. Identifier: `com.craigoclean.web`

### "Domain already in use"

- Domain can only be verified for ONE Services ID
- Check if it's associated with another identifier
- Remove from old identifier first, then add to new one

### "File content invalid"

- Don't edit the downloaded file
- Don't add newlines or whitespace
- Re-download from Apple Developer Portal
- Use exact file content

## 📝 Notes

**Security:**
- ✅ This file is public - safe to commit to git
- ✅ Contains no secrets or credentials
- ✅ Can be cached indefinitely

**Maintenance:**
- File never expires
- Only needs to be updated if you remove and re-add the domain
- Can be deleted after verification (but keep it for re-verification)

**Multiple Domains:**
- You can verify multiple domains for the same Services ID
- Each domain needs its own verification file
- Subdomains need separate verification (e.g., `app.craigoclean.com`)

## 🔗 Related Files

- `domain-verification-server.js` - Express server to serve the file
- `.well-known/README.md` - Technical details about the .well-known directory
- `generate-apple-secret.js` - Script to generate client secret for Sign In with Apple
- `APPLE_SIGNIN_SETUP.md` - Complete Sign In with Apple setup guide

## 📚 Resources

- [Apple Sign In with Apple Documentation](https://developer.apple.com/sign-in-with-apple/)
- [Domain Verification Requirements](https://developer.apple.com/documentation/sign_in_with_apple/sign_in_with_apple_js/configuring_your_webpage_for_sign_in_with_apple)
- [Troubleshooting Guide](https://developer.apple.com/forums/tags/sign-in-with-apple)

## 🆘 Need Help?

If you're still having issues:
1. Check Apple Developer Forums
2. Review system status: https://developer.apple.com/system-status/
3. Contact Apple Developer Support
4. Check server logs for errors

---

**Last Updated:** January 2026
**For:** Craig-O-Clean macOS App
**Domain:** craigoclean.com
