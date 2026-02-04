# Deploy Craig-O-Clean Backend to craigoclean.com

Complete guide to deploying your webhook endpoint to https://craigoclean.com

## Quick Overview

**Webhook URL:** `https://craigoclean.com/api/webhook/stripe`

This is the URL you'll add to Stripe Dashboard to receive payment notifications.

---

## Option 1: Deploy to Vercel with Custom Domain (Recommended)

### Step 1: Deploy to Vercel

```bash
cd backend

# Install Vercel CLI if needed
npm i -g vercel

# Login to Vercel
vercel login

# Deploy
vercel
```

Follow the prompts:
- **Set up and deploy?** Y
- **Which scope?** Your account
- **Link to existing project?** N
- **Project name?** craig-o-clean-backend
- **Directory?** ./
- **Override settings?** N

### Step 2: Add Environment Variables

```bash
# Add production environment variables
vercel env add STRIPE_SECRET_KEY production
vercel env add STRIPE_WEBHOOK_SECRET production
vercel env add STRIPE_PRICE_ID production
vercel env add DATABASE_URL production
vercel env add SENDGRID_API_KEY production
vercel env add FROM_EMAIL production

# Or use Vercel Dashboard
# https://vercel.com/your-account/craig-o-clean-backend/settings/environment-variables
```

Copy values from `.env.production`

### Step 3: Add Custom Domain

**In Vercel Dashboard:**

1. Go to your project: https://vercel.com/your-account/craig-o-clean-backend
2. Click "Settings" → "Domains"
3. Add domain: `craigoclean.com`
4. Add subdomain: `api.craigoclean.com` (optional)

**Configure DNS:**

Add these DNS records in your domain registrar:

```
Type: A
Name: @
Value: 76.76.21.21

Type: CNAME
Name: www
Value: cname.vercel-dns.com
```

Or for subdomain approach:

```
Type: CNAME
Name: api
Value: cname.vercel-dns.com
```

**SSL Certificate:**
Vercel automatically provisions SSL certificates. Wait 5-10 minutes for DNS propagation.

### Step 4: Deploy to Production

```bash
# Deploy to production with custom domain
vercel --prod
```

### Step 5: Verify Deployment

```bash
# Test health endpoint
curl https://craigoclean.com/health

# Should return: {"status":"ok","service":"craig-o-clean-backend"}
```

---

## Option 2: Deploy to Railway with Custom Domain

### Step 1: Deploy to Railway

```bash
cd backend

# Install Railway CLI
npm i -g @railway/cli

# Login
railway login

# Initialize project
railway init

# Deploy
railway up
```

### Step 2: Add Environment Variables

```bash
# Add variables one by one
railway variables set STRIPE_SECRET_KEY=sk_live_...
railway variables set STRIPE_WEBHOOK_SECRET=whsec_...
railway variables set STRIPE_PRICE_ID=price_...
railway variables set DATABASE_URL=postgresql://...
railway variables set SENDGRID_API_KEY=SG...
railway variables set FROM_EMAIL=support@craigoclean.com
railway variables set NODE_ENV=production
railway variables set APP_URL=https://craigoclean.com

# Or use Railway Dashboard
# https://railway.app/project/your-project/variables
```

### Step 3: Add Custom Domain

**In Railway Dashboard:**

1. Go to your project
2. Click "Settings" → "Domains"
3. Click "Custom Domain"
4. Enter: `craigoclean.com`

**Configure DNS:**

Railway will provide DNS records. Add to your registrar:

```
Type: CNAME
Name: @
Value: your-project.railway.app

Type: CNAME
Name: www
Value: your-project.railway.app
```

### Step 4: Verify

```bash
curl https://craigoclean.com/health
```

---

## Option 3: Your Own Server (VPS/Dedicated)

### Prerequisites

- Ubuntu/Debian server with public IP
- Domain pointing to server
- Nginx installed
- Node.js 18+ installed
- PostgreSQL installed

### Step 1: Setup Server

```bash
# SSH into your server
ssh user@your-server-ip

# Update system
sudo apt update && sudo apt upgrade -y

# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# Install PostgreSQL
sudo apt install -y postgresql postgresql-contrib

# Install PM2 (process manager)
sudo npm install -g pm2

# Install Nginx
sudo apt install -y nginx
```

### Step 2: Deploy Application

```bash
# Clone or upload your code
cd /var/www
sudo git clone your-repo craig-o-clean-backend
cd craig-o-clean-backend/backend

# Install dependencies
npm install --production

# Create .env file
sudo nano .env
# Paste production values from .env.production

# Start with PM2
pm2 start index.js --name craig-o-clean-backend
pm2 save
pm2 startup

# Check it's running
pm2 status
```

### Step 3: Configure Nginx

```bash
# Create Nginx config
sudo nano /etc/nginx/sites-available/craigoclean.com
```

Paste this configuration:

```nginx
# HTTP to HTTPS redirect
server {
    listen 80;
    listen [::]:80;
    server_name craigoclean.com www.craigoclean.com;
    return 301 https://$server_name$request_uri;
}

# HTTPS server
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name craigoclean.com www.craigoclean.com;

    # SSL Configuration (Let's Encrypt)
    ssl_certificate /etc/letsencrypt/live/craigoclean.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/craigoclean.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    # API proxy
    location /api/ {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;

        # Important for Stripe webhooks
        proxy_set_header Stripe-Signature $http_stripe_signature;
        client_max_body_size 10M;
    }

    # Health check
    location /health {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
    }

    # Static files (optional)
    location / {
        root /var/www/craigoclean.com;
        try_files $uri $uri/ =404;
    }
}
```

Enable the site:

```bash
# Enable site
sudo ln -s /etc/nginx/sites-available/craigoclean.com /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx
```

### Step 4: Setup SSL with Let's Encrypt

```bash
# Install Certbot
sudo apt install -y certbot python3-certbot-nginx

# Get SSL certificate
sudo certbot --nginx -d craigoclean.com -d www.craigoclean.com

# Follow prompts, choose to redirect HTTP to HTTPS

# Test renewal
sudo certbot renew --dry-run
```

### Step 5: Setup Database

```bash
# Create database
sudo -u postgres psql
CREATE DATABASE craig_o_clean_production;
CREATE USER craig_admin WITH PASSWORD 'your-secure-password';
GRANT ALL PRIVILEGES ON DATABASE craig_o_clean_production TO craig_admin;
\q

# Update DATABASE_URL in .env
nano /var/www/craig-o-clean-backend/backend/.env
# DATABASE_URL=postgresql://craig_admin:your-secure-password@localhost/craig_o_clean_production

# Restart app
pm2 restart craig-o-clean-backend
```

---

## Configure Stripe Webhook

Once your backend is deployed to https://craigoclean.com:

### Step 1: Add Webhook in Stripe Dashboard

1. Go to https://dashboard.stripe.com/webhooks
2. Click "Add endpoint"
3. Enter endpoint URL:
   ```
   https://craigoclean.com/api/webhook/stripe
   ```
4. Select events to listen for:
   - ✅ `checkout.session.completed`
   - ✅ `payment_intent.succeeded`
   - ✅ `charge.refunded`
5. Click "Add endpoint"

### Step 2: Get Webhook Secret

1. Click on the newly created webhook
2. Click "Reveal" under "Signing secret"
3. Copy the secret (starts with `whsec_`)
4. Add to your environment:
   ```bash
   # Vercel
   vercel env add STRIPE_WEBHOOK_SECRET production
   # Enter the whsec_... value

   # Railway
   railway variables set STRIPE_WEBHOOK_SECRET=whsec_...

   # Own server
   nano /var/www/craig-o-clean-backend/backend/.env
   # Update STRIPE_WEBHOOK_SECRET=whsec_...
   pm2 restart craig-o-clean-backend
   ```

### Step 3: Test Webhook

**Use Stripe CLI:**

```bash
# Install Stripe CLI
brew install stripe/stripe-brew/stripe

# Login
stripe login

# Test webhook
stripe trigger checkout.session.completed

# Or send test event from Dashboard
# Go to webhook settings → "Send test webhook"
```

**Check logs:**

```bash
# Vercel
vercel logs --follow

# Railway
railway logs

# Own server
pm2 logs craig-o-clean-backend
```

You should see:
```
[WEBHOOK] Received webhook from Stripe
[WEBHOOK] Signature verified successfully
[WEBHOOK] Event type: checkout.session.completed
[WEBHOOK] Processing checkout.session.completed: cs_test_...
[PAYMENT] Creating license for user@example.com
[PAYMENT] License created: CRAIG-XXXX-XXXX-XXXX-XXXX
[PAYMENT] Email sent to user@example.com
[WEBHOOK] Payment handled successfully
```

---

## Update Lite App Configuration

After deployment, update `UpgradeService.swift`:

```swift
// Production URLs
private let stripeCheckoutURL = "https://buy.stripe.com/YOUR_LIVE_LINK"
private let licenseValidationURL = "https://craigoclean.com/api/license/validate"
private let downloadURL = "https://craigoclean.com/api/download"
```

Or if using backend checkout:

```swift
private let checkoutCreateURL = "https://craigoclean.com/api/checkout/create"
```

---

## Monitoring & Logs

### Vercel

```bash
# Real-time logs
vercel logs --follow

# Specific deployment
vercel logs [deployment-url]

# Or use Vercel Dashboard
# https://vercel.com/your-account/craig-o-clean-backend/logs
```

### Railway

```bash
# Real-time logs
railway logs

# Or use Railway Dashboard
# https://railway.app/project/your-project/deployments
```

### Own Server

```bash
# PM2 logs
pm2 logs craig-o-clean-backend

# Nginx access logs
sudo tail -f /var/log/nginx/access.log

# Nginx error logs
sudo tail -f /var/log/nginx/error.log

# Application logs (if using file logging)
tail -f /var/www/craig-o-clean-backend/backend/logs/app.log
```

---

## Testing Checklist

After deployment, test these endpoints:

```bash
# Health check
curl https://craigoclean.com/health
# Should return: {"status":"ok","service":"craig-o-clean-backend"}

# Test checkout creation (optional)
curl -X POST https://craigoclean.com/api/checkout/create \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","clientReferenceId":"test-123"}'
# Should return: {"checkoutUrl":"https://checkout.stripe.com/..."}

# Test license validation (after creating test license)
curl "https://craigoclean.com/api/license/validate?license_key=CRAIG-TEST-1234-5678-9012"
# Should return: {"valid":false} or {"valid":true,...}
```

---

## Troubleshooting

### Webhook Not Receiving Events

**Check:**
1. URL is correct: `https://craigoclean.com/api/webhook/stripe`
2. SSL certificate is valid (visit in browser)
3. Webhook secret is correct in environment
4. Firewall allows incoming HTTPS
5. Application is running

**Test:**
```bash
# Check if endpoint is accessible
curl -X POST https://craigoclean.com/api/webhook/stripe \
  -H "Content-Type: application/json" \
  -d '{"test":"data"}'
# Should return error about signature, which means endpoint is reachable
```

### Database Connection Issues

**Check:**
```bash
# Verify DATABASE_URL format
postgresql://username:password@host:port/database

# Test connection from server
psql $DATABASE_URL -c "SELECT 1;"
```

### SSL Certificate Issues

**Check:**
```bash
# Test SSL
curl -I https://craigoclean.com

# Check certificate
openssl s_client -connect craigoclean.com:443 -servername craigoclean.com
```

---

## Production Checklist

Before going live:

- [ ] Backend deployed to https://craigoclean.com
- [ ] SSL certificate active and valid
- [ ] All environment variables set (production)
- [ ] Database connected and initialized
- [ ] Webhook endpoint added in Stripe
- [ ] Webhook secret configured
- [ ] Test payment successful
- [ ] License generated correctly
- [ ] Email sending works
- [ ] Download link accessible
- [ ] Logs monitored
- [ ] Error tracking setup (optional: Sentry)
- [ ] Backup strategy configured

---

## Next Steps

1. ✅ Deploy backend to craigoclean.com
2. ✅ Add webhook in Stripe Dashboard
3. ✅ Test with Stripe test mode
4. ✅ Switch to live Stripe keys
5. ✅ Update Lite app with production URLs
6. ✅ Launch! 🚀

**Your webhook endpoint is ready at:**
**`https://craigoclean.com/api/webhook/stripe`**

Add this URL to Stripe Dashboard and you're good to go!
