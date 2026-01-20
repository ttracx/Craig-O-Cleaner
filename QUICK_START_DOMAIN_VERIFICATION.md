# 🚀 Quick Start: Apple Domain Verification

**Time Required:** 10-15 minutes

## TL;DR

1. Get file from Apple → 2. Put in `.well-known/` → 3. Deploy to domain → 4. Click "Verify" in Apple Portal

---

## Step 1: Download File from Apple (5 min)

Go to: **https://developer.apple.com/account/resources/identifiers/list**

1. Change dropdown to **"Services IDs"** (top right)
2. Click `com.craigoclean.web`
3. Check **"Sign In with Apple"** → Click **"Configure"**
4. Click **"+" next to "Domains and Subdomains"**
5. Enter: `craigoclean.com`
6. **Download** the `apple-developer-domain-association.txt` file
7. Also add return URL: `https://craigoclean.com/auth/apple/callback`
8. Click **"Continue"** → **"Save"**

## Step 2: Add File to Project (1 min)

```bash
# Copy the downloaded file
cp ~/Downloads/apple-developer-domain-association.txt .well-known/

# Verify it's there
cat .well-known/apple-developer-domain-association.txt
```

## Step 3: Test Locally (Optional - 2 min)

```bash
# Install Express
npm install

# Start server
npm run serve-domain-verification

# In another terminal, test it
curl http://localhost:3000/.well-known/apple-developer-domain-association.txt
```

## Step 4: Deploy to Production (5 min)

**Choose ONE method:**

### Method A: Vercel (Easiest)
```bash
# Copy to public folder (if using Next.js)
cp -r .well-known /path/to/your/nextjs/public/

# Deploy
vercel --prod

# Test
curl https://craigoclean.com/.well-known/apple-developer-domain-association.txt
```

### Method B: Node.js Server
```bash
# On your production server
git pull
npm install
pm2 start domain-verification-server.js --name apple-verification

# Test
curl https://craigoclean.com/.well-known/apple-developer-domain-association.txt
```

### Method C: Nginx
Add to `/etc/nginx/sites-available/craigoclean.com`:
```nginx
location /.well-known/apple-developer-domain-association.txt {
    alias /path/to/.well-known/apple-developer-domain-association.txt;
    add_header Content-Type text/plain;
}
```

Then:
```bash
sudo nginx -t && sudo systemctl reload nginx
```

## Step 5: Verify in Apple Portal (2 min)

1. Go back to: **https://developer.apple.com/account/resources/identifiers/list**
2. Services IDs → `com.craigoclean.web` → Configure Sign In with Apple
3. Click **"Verify"** next to `craigoclean.com`
4. Wait for green checkmark ✅
5. Click **"Continue"** → **"Save"**

---

## ✅ Done!

Your domain is now verified and ready for Sign In with Apple.

## 🚨 If Verification Fails

Run this command:
```bash
curl -v https://craigoclean.com/.well-known/apple-developer-domain-association.txt
```

**Must return:**
- ✅ HTTP 200 OK
- ✅ Content-Type: text/plain
- ✅ The verification code (long string)

**Common Issues:**
- ❌ 404: File not deployed → Check deployment
- ❌ SSL Error: Certificate issue → Fix HTTPS
- ❌ Timeout: Server down → Check server status
- ❌ Wrong content: File modified → Re-download from Apple

---

**Need detailed instructions?** See `DOMAIN_VERIFICATION_SETUP.md`

**Files Created:**
- `.well-known/apple-developer-domain-association.txt` ← Put the file here
- `domain-verification-server.js` ← Server to serve the file
- `DOMAIN_VERIFICATION_SETUP.md` ← Detailed guide
