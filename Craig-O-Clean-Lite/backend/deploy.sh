#!/bin/bash

# Craig-O-Clean Backend Deployment Script
# Deploys to Vercel with custom domain craigoclean.com

set -e  # Exit on error

echo "🚀 Craig-O-Clean Backend Deployment"
echo "===================================="
echo ""

# Check if Vercel CLI is installed
if ! command -v vercel &> /dev/null; then
    echo "❌ Vercel CLI not found. Installing..."
    npm install -g vercel
fi

# Check if we're in the backend directory
if [ ! -f "package.json" ]; then
    echo "❌ Error: package.json not found. Please run this from the backend directory."
    exit 1
fi

echo "✅ Vercel CLI installed"
echo ""

# Login to Vercel
echo "📝 Logging in to Vercel..."
vercel login

echo ""
echo "📦 Installing dependencies..."
npm install

echo ""
echo "🌐 Deploying to Vercel..."
vercel --prod

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📋 Next Steps:"
echo ""
echo "1. Add custom domain in Vercel Dashboard:"
echo "   https://vercel.com/dashboard"
echo "   → Go to your project → Settings → Domains"
echo "   → Add: craigoclean.com"
echo ""
echo "2. Configure DNS (in your domain registrar):"
echo "   Type: A"
echo "   Name: @"
echo "   Value: 76.76.21.21"
echo ""
echo "3. Add environment variables in Vercel:"
echo "   vercel env add STRIPE_WEBHOOK_SECRET production"
echo "   vercel env add DATABASE_URL production"
echo "   vercel env add SENDGRID_API_KEY production"
echo "   vercel env add FROM_EMAIL production"
echo ""
echo "4. Setup Stripe webhook:"
echo "   URL: https://craigoclean.com/api/webhook/stripe"
echo "   Events: checkout.session.completed, payment_intent.succeeded"
echo ""
echo "5. Redeploy to apply changes:"
echo "   vercel --prod"
echo ""
echo "🎉 Your webhook endpoint:"
echo "   https://craigoclean.com/api/webhook/stripe"
