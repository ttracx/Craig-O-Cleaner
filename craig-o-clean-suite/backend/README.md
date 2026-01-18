# Craig-O-Clean Suite Backend

Stripe billing backend for Craig-O-Clean Suite desktop application. Built with Fastify, TypeScript, Prisma, and PostgreSQL.

## Features

- Stripe Checkout integration with 7-day free trial
- Subscription management (monthly/yearly plans)
- JWT-based entitlement verification
- Webhook handling for subscription events
- Customer portal for billing management
- Rate limiting and security headers
- Health check endpoints for monitoring
- Docker support for development and production

## Prerequisites

- Node.js >= 18.0.0
- PostgreSQL 16+
- Stripe account with API keys
- Docker & Docker Compose (optional)

## Quick Start

### Local Development

1. **Install dependencies:**

```bash
npm install
```

2. **Set up environment variables:**

```bash
cp .env.example .env
# Edit .env with your configuration
```

3. **Start PostgreSQL (using Docker):**

```bash
docker compose up postgres -d
```

4. **Run database migrations:**

```bash
npm run prisma:migrate
```

5. **Start development server:**

```bash
npm run dev
```

### Using Docker Compose

Start all services including PostgreSQL:

```bash
# Production mode
docker compose up -d

# Development mode with hot reload
docker compose --profile dev up api-dev
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `NODE_ENV` | Environment (development/production/test) | development |
| `PORT` | Server port | 3000 |
| `HOST` | Server host | 0.0.0.0 |
| `DATABASE_URL` | PostgreSQL connection string | - |
| `STRIPE_SECRET_KEY` | Stripe secret API key | - |
| `STRIPE_WEBHOOK_SECRET` | Stripe webhook signing secret | - |
| `STRIPE_PRICE_MONTHLY` | Monthly price ID | price_craigoclean_monthly |
| `STRIPE_PRICE_YEARLY` | Yearly price ID | price_craigoclean_yearly |
| `JWT_SECRET` | JWT signing secret (min 32 chars) | - |
| `JWT_EXPIRES_IN` | JWT expiration time | 30d |
| `CORS_ORIGINS` | Allowed CORS origins (comma-separated) | http://localhost:3000 |
| `RATE_LIMIT_MAX` | Max requests per time window | 100 |
| `RATE_LIMIT_TIME_WINDOW` | Rate limit window (ms) | 60000 |
| `LOG_LEVEL` | Pino log level | info |
| `SUCCESS_URL` | Checkout success redirect URL | craigoclean://billing/success |
| `CANCEL_URL` | Checkout cancel redirect URL | craigoclean://billing/cancel |

## API Endpoints

### Health

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Full health check with DB status |
| GET | `/ready` | Readiness probe for k8s |
| GET | `/live` | Liveness probe for k8s |
| GET | `/metrics` | Basic metrics |

### Checkout

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| POST | `/api/create-checkout-session` | Create Stripe checkout | No |
| GET | `/api/checkout-session/:id` | Get checkout status | No |

### Entitlement

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| GET | `/api/verify-entitlement` | Verify subscription | Yes |
| POST | `/api/restore-subscription` | Restore by email | No |
| POST | `/api/refresh-token` | Refresh auth token | Yes |
| POST | `/api/revoke-token` | Revoke all tokens | Yes |

### Portal

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| POST | `/api/customer-portal` | Create portal session | Yes |
| GET | `/api/billing-history` | Get invoices | Yes |
| POST | `/api/cancel-subscription` | Cancel subscription | Yes |
| POST | `/api/reactivate-subscription` | Reactivate subscription | Yes |

### Webhooks

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/webhooks/stripe` | Stripe webhook handler |

## Authentication

The API uses JWT tokens for authentication. Include the token in the Authorization header:

```
Authorization: Bearer <token>
```

Tokens are issued after successful subscription creation or restoration.

## Stripe Products

Configure these products in your Stripe dashboard:

- **Monthly Plan** (`price_craigoclean_monthly`): $0.99/month with 7-day trial
- **Yearly Plan** (`price_craigoclean_yearly`): $9.99/year with 7-day trial

## Webhook Events

The following Stripe webhook events are handled:

- `customer.subscription.created` - New subscription
- `customer.subscription.updated` - Status/plan changes
- `customer.subscription.deleted` - Subscription canceled
- `invoice.payment_failed` - Payment failure
- `invoice.payment_succeeded` - Successful payment
- `checkout.session.completed` - Checkout completed

Configure your Stripe webhook endpoint to: `https://your-domain.com/webhooks/stripe`

## Scripts

| Script | Description |
|--------|-------------|
| `npm run dev` | Start development server with hot reload |
| `npm run build` | Build TypeScript to JavaScript |
| `npm start` | Start production server |
| `npm test` | Run tests with Vitest |
| `npm run test:coverage` | Run tests with coverage |
| `npm run lint` | Lint source files |
| `npm run lint:fix` | Fix linting issues |
| `npm run typecheck` | Type check without emitting |
| `npm run prisma:generate` | Generate Prisma client |
| `npm run prisma:migrate` | Run migrations (dev) |
| `npm run prisma:migrate:prod` | Deploy migrations (prod) |
| `npm run prisma:studio` | Open Prisma Studio |

## Database Schema

### Users
- `id` - Primary key (CUID)
- `email` - Unique email address
- `stripeCustomerId` - Stripe customer ID
- `platform` - User's platform (linux/windows)
- `createdAt`, `updatedAt` - Timestamps

### Entitlements
- `id` - Primary key (CUID)
- `userId` - Foreign key to User
- `stripeSubscriptionId` - Stripe subscription ID
- `status` - Subscription status enum
- `tier` - Subscription tier (FREE/MONTHLY/YEARLY)
- `currentPeriodStart`, `currentPeriodEnd` - Billing period
- `cancelAtPeriodEnd` - Cancellation flag
- `trialEnd` - Trial end date

### EntitlementTokens
- `id` - Primary key (CUID)
- `userId` - Foreign key to User
- `token` - JWT token (unique)
- `expiresAt` - Token expiration
- `revokedAt` - Revocation timestamp

### WebhookEvents
- `id` - Primary key (CUID)
- `stripeEventId` - Stripe event ID (unique)
- `eventType` - Event type string
- `processed` - Processing flag
- `payload` - JSON payload
- `error` - Error message if failed

## Deployment

### Docker

Build and run the production image:

```bash
docker build -t craigoclean-backend .
docker run -p 3000:3000 --env-file .env craigoclean-backend
```

### Environment-specific Notes

**Production:**
- Set `NODE_ENV=production`
- Use a strong `JWT_SECRET` (32+ characters)
- Configure proper `CORS_ORIGINS`
- Enable rate limiting
- Use `LOG_LEVEL=info` or `warn`

**Development:**
- Stripe CLI for webhook testing: `stripe listen --forward-to localhost:3000/webhooks/stripe`
- Use `LOG_LEVEL=debug` for verbose logging

## Error Handling

All errors return a consistent JSON format:

```json
{
  "statusCode": 400,
  "error": "Bad Request",
  "message": "Detailed error message",
  "code": "ERROR_CODE"
}
```

Common error codes:
- `VALIDATION_ERROR` - Request validation failed
- `UNAUTHORIZED` - Authentication required/failed
- `NOT_FOUND` - Resource not found
- `RATE_LIMIT_EXCEEDED` - Too many requests
- `STRIPE_ERROR` - Stripe API error
- `INTERNAL_ERROR` - Unexpected server error

## License

MIT
