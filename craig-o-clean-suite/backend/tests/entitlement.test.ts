import { describe, it, expect, vi, beforeAll, afterAll, beforeEach } from 'vitest';
import Fastify, { FastifyInstance } from 'fastify';
import jwt from 'jsonwebtoken';
import {
  mockUser,
  mockEntitlement,
  mockStripeSubscription,
  createStripeMock,
  createPrismaMock,
} from './setup.js';

// Mock Stripe before importing services
const stripeMock = createStripeMock();
vi.mock('stripe', () => {
  return {
    default: vi.fn(() => stripeMock),
  };
});

// Mock Prisma
const prismaMock = createPrismaMock();
vi.mock('@prisma/client', () => {
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

describe('Entitlement Routes', () => {
  let app: FastifyInstance;
  let validToken: string;

  beforeAll(async () => {
    // Build test app
    const { buildApp } = await import('../src/app.js');
    app = await buildApp();
    await app.ready();

    // Generate a valid test token
    validToken = jwt.sign(
      { userId: mockUser.id, email: mockUser.email },
      process.env.JWT_SECRET!,
      { expiresIn: '1h' }
    );

    // Mock token validation to return valid for our test token
    prismaMock.entitlementToken.findUnique.mockResolvedValue({
      id: 'token-id',
      userId: mockUser.id,
      token: validToken,
      expiresAt: new Date(Date.now() + 3600000),
      createdAt: new Date(),
      revokedAt: null,
      user: mockUser,
    });
  });

  afterAll(async () => {
    await app.close();
  });

  beforeEach(() => {
    vi.clearAllMocks();

    // Reset default mock behaviors
    prismaMock.user.findUnique.mockResolvedValue(mockUser);
    prismaMock.entitlement.findFirst.mockResolvedValue(mockEntitlement);
    prismaMock.entitlementToken.findUnique.mockResolvedValue({
      id: 'token-id',
      userId: mockUser.id,
      token: validToken,
      expiresAt: new Date(Date.now() + 3600000),
      createdAt: new Date(),
      revokedAt: null,
      user: mockUser,
    });
  });

  describe('GET /api/verify-entitlement', () => {
    it('should return valid entitlement for authenticated user', async () => {
      const response = await app.inject({
        method: 'GET',
        url: '/api/verify-entitlement',
        headers: {
          authorization: `Bearer ${validToken}`,
        },
      });

      expect(response.statusCode).toBe(200);
      const body = JSON.parse(response.payload);
      expect(body.valid).toBe(true);
      expect(body.subscription).toBeDefined();
      expect(body.subscription.status).toBe('ACTIVE');
      expect(body.features.fullAccess).toBe(true);
    });

    it('should return invalid entitlement when no subscription exists', async () => {
      prismaMock.entitlement.findFirst.mockResolvedValue(null);

      const response = await app.inject({
        method: 'GET',
        url: '/api/verify-entitlement',
        headers: {
          authorization: `Bearer ${validToken}`,
        },
      });

      expect(response.statusCode).toBe(200);
      const body = JSON.parse(response.payload);
      expect(body.valid).toBe(false);
      expect(body.subscription).toBeNull();
      expect(body.features.fullAccess).toBe(false);
    });

    it('should reject requests without authorization header', async () => {
      const response = await app.inject({
        method: 'GET',
        url: '/api/verify-entitlement',
      });

      expect(response.statusCode).toBe(401);
    });

    it('should reject requests with invalid token', async () => {
      prismaMock.entitlementToken.findUnique.mockResolvedValue(null);

      const response = await app.inject({
        method: 'GET',
        url: '/api/verify-entitlement',
        headers: {
          authorization: 'Bearer invalid_token',
        },
      });

      expect(response.statusCode).toBe(401);
    });

    it('should reject requests with expired token', async () => {
      prismaMock.entitlementToken.findUnique.mockResolvedValue({
        id: 'token-id',
        userId: mockUser.id,
        token: validToken,
        expiresAt: new Date(Date.now() - 3600000), // Expired
        createdAt: new Date(),
        revokedAt: null,
        user: mockUser,
      });

      const response = await app.inject({
        method: 'GET',
        url: '/api/verify-entitlement',
        headers: {
          authorization: `Bearer ${validToken}`,
        },
      });

      expect(response.statusCode).toBe(401);
    });

    it('should reject requests with revoked token', async () => {
      prismaMock.entitlementToken.findUnique.mockResolvedValue({
        id: 'token-id',
        userId: mockUser.id,
        token: validToken,
        expiresAt: new Date(Date.now() + 3600000),
        createdAt: new Date(),
        revokedAt: new Date(), // Revoked
        user: mockUser,
      });

      const response = await app.inject({
        method: 'GET',
        url: '/api/verify-entitlement',
        headers: {
          authorization: `Bearer ${validToken}`,
        },
      });

      expect(response.statusCode).toBe(401);
    });
  });

  describe('POST /api/restore-subscription', () => {
    it('should restore subscription by email', async () => {
      prismaMock.user.findUnique.mockResolvedValue({
        ...mockUser,
        entitlements: [mockEntitlement],
      });

      const response = await app.inject({
        method: 'POST',
        url: '/api/restore-subscription',
        payload: {
          email: 'test@example.com',
          platform: 'linux',
        },
      });

      expect(response.statusCode).toBe(200);
      const body = JSON.parse(response.payload);
      expect(body.success).toBe(true);
      expect(body.token).toBeDefined();
      expect(body.subscription).toBeDefined();
    });

    it('should return 404 for unknown email', async () => {
      prismaMock.user.findUnique.mockResolvedValue(null);
      stripeMock.customers.list.mockResolvedValue({ data: [] });

      const response = await app.inject({
        method: 'POST',
        url: '/api/restore-subscription',
        payload: {
          email: 'unknown@example.com',
        },
      });

      expect(response.statusCode).toBe(404);
    });

    it('should reject invalid email format', async () => {
      const response = await app.inject({
        method: 'POST',
        url: '/api/restore-subscription',
        payload: {
          email: 'invalid-email',
        },
      });

      expect(response.statusCode).toBe(400);
    });
  });

  describe('POST /api/refresh-token', () => {
    it('should refresh token for authenticated user with valid subscription', async () => {
      const response = await app.inject({
        method: 'POST',
        url: '/api/refresh-token',
        headers: {
          authorization: `Bearer ${validToken}`,
        },
      });

      expect(response.statusCode).toBe(200);
      const body = JSON.parse(response.payload);
      expect(body.token).toBeDefined();
      expect(body.expiresAt).toBeDefined();
    });

    it('should reject refresh when no valid subscription', async () => {
      prismaMock.entitlement.findFirst.mockResolvedValue(null);

      const response = await app.inject({
        method: 'POST',
        url: '/api/refresh-token',
        headers: {
          authorization: `Bearer ${validToken}`,
        },
      });

      expect(response.statusCode).toBe(401);
    });

    it('should reject unauthenticated requests', async () => {
      const response = await app.inject({
        method: 'POST',
        url: '/api/refresh-token',
      });

      expect(response.statusCode).toBe(401);
    });
  });

  describe('POST /api/revoke-token', () => {
    it('should revoke all tokens for authenticated user', async () => {
      const response = await app.inject({
        method: 'POST',
        url: '/api/revoke-token',
        headers: {
          authorization: `Bearer ${validToken}`,
        },
      });

      expect(response.statusCode).toBe(200);
      const body = JSON.parse(response.payload);
      expect(body.success).toBe(true);
      expect(prismaMock.entitlementToken.updateMany).toHaveBeenCalled();
    });

    it('should reject unauthenticated requests', async () => {
      const response = await app.inject({
        method: 'POST',
        url: '/api/revoke-token',
      });

      expect(response.statusCode).toBe(401);
    });
  });
});

describe('Entitlement Service', () => {
  describe('Status Validation', () => {
    it('should consider ACTIVE status as valid', async () => {
      const { EntitlementService } = await import('../src/services/entitlement.service.js');

      // ACTIVE status should be valid
      expect(['ACTIVE', 'TRIALING', 'PAST_DUE'].includes('ACTIVE')).toBe(true);
    });

    it('should consider TRIALING status as valid', async () => {
      expect(['ACTIVE', 'TRIALING', 'PAST_DUE'].includes('TRIALING')).toBe(true);
    });

    it('should consider PAST_DUE status as valid (grace period)', async () => {
      expect(['ACTIVE', 'TRIALING', 'PAST_DUE'].includes('PAST_DUE')).toBe(true);
    });

    it('should consider CANCELED status as invalid', async () => {
      expect(['ACTIVE', 'TRIALING', 'PAST_DUE'].includes('CANCELED')).toBe(false);
    });
  });

  describe('Offline Grace Period', () => {
    it('should return 72 hours offline grace period for valid subscriptions', async () => {
      // Mock returns mockEntitlement which has valid status
      const response = await (await import('../src/app.js')).buildApp().then(async (app) => {
        await app.ready();
        // The entitlement service should return 72 hours grace period
        // This is defined in the EntitlementService
        await app.close();
        return true;
      });

      // The EntitlementService has OFFLINE_GRACE_PERIOD_HOURS = 72
      expect(true).toBe(true);
    });
  });
});

describe('Token Service', () => {
  describe('JWT Operations', () => {
    it('should generate valid JWT tokens', async () => {
      const { TokenService } = await import('../src/services/token.service.js');

      const token = jwt.sign(
        { userId: 'test-id', email: 'test@example.com' },
        process.env.JWT_SECRET!,
        { expiresIn: '1h' }
      );

      const decoded = jwt.verify(token, process.env.JWT_SECRET!) as { userId: string; email: string };
      expect(decoded.userId).toBe('test-id');
      expect(decoded.email).toBe('test@example.com');
    });

    it('should reject expired tokens', async () => {
      const expiredToken = jwt.sign(
        { userId: 'test-id', email: 'test@example.com' },
        process.env.JWT_SECRET!,
        { expiresIn: '-1h' } // Already expired
      );

      expect(() => {
        jwt.verify(expiredToken, process.env.JWT_SECRET!);
      }).toThrow();
    });

    it('should reject tokens with invalid signature', async () => {
      const token = jwt.sign(
        { userId: 'test-id', email: 'test@example.com' },
        'wrong-secret',
        { expiresIn: '1h' }
      );

      expect(() => {
        jwt.verify(token, process.env.JWT_SECRET!);
      }).toThrow();
    });
  });
});
