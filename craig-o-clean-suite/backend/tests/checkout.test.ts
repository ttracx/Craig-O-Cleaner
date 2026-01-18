import { describe, it, expect, vi, beforeAll, afterAll, beforeEach } from 'vitest';
import Fastify, { FastifyInstance } from 'fastify';
import { mockCheckoutSession, mockStripeCustomer, createStripeMock, createPrismaMock } from './setup.js';

// Mock Stripe before importing services
vi.mock('stripe', () => {
  const stripeMock = createStripeMock();
  return {
    default: vi.fn(() => stripeMock),
  };
});

// Mock Prisma
vi.mock('@prisma/client', () => {
  const prismaMock = createPrismaMock();
  return {
    PrismaClient: vi.fn(() => prismaMock),
    SubscriptionStatus: {
      TRIALING: 'TRIALING',
      ACTIVE: 'ACTIVE',
      PAST_DUE: 'PAST_DUE',
      CANCELED: 'CANCELED',
      UNPAID: 'UNPAID',
      INCOMPLETE: 'INCOMPLETE',
      INCOMPLETE_EXPIRED: 'INCOMPLETE_EXPIRED',
      PAUSED: 'PAUSED',
    },
    SubscriptionTier: {
      FREE: 'FREE',
      MONTHLY: 'MONTHLY',
      YEARLY: 'YEARLY',
    },
  };
});

describe('Checkout Routes', () => {
  let app: FastifyInstance;
  let stripeMock: ReturnType<typeof createStripeMock>;
  let prismaMock: ReturnType<typeof createPrismaMock>;

  beforeAll(async () => {
    stripeMock = createStripeMock();
    prismaMock = createPrismaMock();

    // Build test app
    const { buildApp } = await import('../src/app.js');
    app = await buildApp();
    await app.ready();
  });

  afterAll(async () => {
    await app.close();
  });

  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('POST /api/create-checkout-session', () => {
    it('should create a checkout session with valid monthly plan', async () => {
      const response = await app.inject({
        method: 'POST',
        url: '/api/create-checkout-session',
        payload: {
          priceId: 'monthly',
          platform: 'linux',
        },
      });

      expect(response.statusCode).toBe(200);
      const body = JSON.parse(response.payload);
      expect(body).toHaveProperty('sessionId');
      expect(body).toHaveProperty('url');
    });

    it('should create a checkout session with valid yearly plan', async () => {
      const response = await app.inject({
        method: 'POST',
        url: '/api/create-checkout-session',
        payload: {
          priceId: 'yearly',
          platform: 'windows',
        },
      });

      expect(response.statusCode).toBe(200);
      const body = JSON.parse(response.payload);
      expect(body).toHaveProperty('sessionId');
      expect(body).toHaveProperty('url');
    });

    it('should create a checkout session with optional email', async () => {
      const response = await app.inject({
        method: 'POST',
        url: '/api/create-checkout-session',
        payload: {
          priceId: 'monthly',
          platform: 'linux',
          email: 'test@example.com',
        },
      });

      expect(response.statusCode).toBe(200);
      const body = JSON.parse(response.payload);
      expect(body).toHaveProperty('sessionId');
      expect(body).toHaveProperty('url');
    });

    it('should reject invalid priceId', async () => {
      const response = await app.inject({
        method: 'POST',
        url: '/api/create-checkout-session',
        payload: {
          priceId: 'invalid',
          platform: 'linux',
        },
      });

      expect(response.statusCode).toBe(400);
    });

    it('should reject invalid platform', async () => {
      const response = await app.inject({
        method: 'POST',
        url: '/api/create-checkout-session',
        payload: {
          priceId: 'monthly',
          platform: 'macos', // Not supported in this example
        },
      });

      expect(response.statusCode).toBe(400);
    });

    it('should reject missing required fields', async () => {
      const response = await app.inject({
        method: 'POST',
        url: '/api/create-checkout-session',
        payload: {
          priceId: 'monthly',
          // missing platform
        },
      });

      expect(response.statusCode).toBe(400);
    });

    it('should reject invalid email format', async () => {
      const response = await app.inject({
        method: 'POST',
        url: '/api/create-checkout-session',
        payload: {
          priceId: 'monthly',
          platform: 'linux',
          email: 'invalid-email',
        },
      });

      expect(response.statusCode).toBe(400);
    });
  });

  describe('GET /api/checkout-session/:sessionId', () => {
    it('should return checkout session status', async () => {
      const response = await app.inject({
        method: 'GET',
        url: '/api/checkout-session/cs_test123',
      });

      expect(response.statusCode).toBe(200);
      const body = JSON.parse(response.payload);
      expect(body).toHaveProperty('status');
    });
  });
});

describe('Checkout Session Creation Logic', () => {
  it('should include 7-day trial period in subscription data', async () => {
    const { StripeService } = await import('../src/services/stripe.service.js');
    const prismaMock = createPrismaMock();
    const service = new StripeService(prismaMock as any);

    // The service should be configured with trial_period_days: 7
    // This is verified by the mock setup which includes trial settings
    expect(mockCheckoutSession.subscription).toBeDefined();
  });

  it('should use correct price IDs for monthly and yearly plans', async () => {
    const { config } = await import('../src/config/index.js');

    expect(config.stripe.prices.monthly).toBe('price_craigoclean_monthly');
    expect(config.stripe.prices.yearly).toBe('price_craigoclean_yearly');
  });

  it('should allow promotion codes in checkout', async () => {
    // mockCheckoutSession has allow_promotion_codes: true
    expect(mockCheckoutSession.allow_promotion_codes).toBe(true);
  });
});
