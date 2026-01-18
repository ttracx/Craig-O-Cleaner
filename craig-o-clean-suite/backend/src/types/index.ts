import { FastifyRequest, FastifyReply } from 'fastify';
import { SubscriptionStatus, SubscriptionTier } from '@prisma/client';
import { z } from 'zod';

// ============================================================================
// Request/Response Types
// ============================================================================

export interface AuthenticatedRequest extends FastifyRequest {
  user: {
    userId: string;
    email: string;
  };
}

// ============================================================================
// Checkout Types
// ============================================================================

export const CreateCheckoutSessionSchema = z.object({
  priceId: z.enum(['monthly', 'yearly']),
  platform: z.enum(['linux', 'windows']),
  email: z.string().email().optional(),
  returnUrl: z.string().url().optional(),
});

export type CreateCheckoutSessionInput = z.infer<typeof CreateCheckoutSessionSchema>;

export interface CreateCheckoutSessionResponse {
  sessionId: string;
  url: string;
}

// ============================================================================
// Entitlement Types
// ============================================================================

export interface EntitlementResponse {
  valid: boolean;
  subscription: {
    id: string;
    status: SubscriptionStatus;
    tier: SubscriptionTier;
    currentPeriodEnd: string;
    cancelAtPeriodEnd: boolean;
    trialEnd: string | null;
  } | null;
  features: {
    fullAccess: boolean;
    offlineGracePeriodHours: number;
  };
}

export const VerifyEntitlementQuerySchema = z.object({
  includeDetails: z.enum(['true', 'false']).optional(),
});

export type VerifyEntitlementQuery = z.infer<typeof VerifyEntitlementQuerySchema>;

// ============================================================================
// Portal Types
// ============================================================================

export interface CustomerPortalResponse {
  url: string;
}

// ============================================================================
// Restore Types
// ============================================================================

export const RestoreSubscriptionSchema = z.object({
  email: z.string().email(),
  platform: z.enum(['linux', 'windows']).optional(),
});

export type RestoreSubscriptionInput = z.infer<typeof RestoreSubscriptionSchema>;

export interface RestoreSubscriptionResponse {
  success: boolean;
  token: string;
  expiresAt: string;
  subscription: {
    status: SubscriptionStatus;
    tier: SubscriptionTier;
    currentPeriodEnd: string;
  };
}

// ============================================================================
// Webhook Types
// ============================================================================

export interface WebhookResponse {
  received: boolean;
}

// ============================================================================
// Error Types
// ============================================================================

export interface ErrorResponse {
  statusCode: number;
  error: string;
  message: string;
  code?: string;
}

export class AppError extends Error {
  statusCode: number;
  code?: string;

  constructor(message: string, statusCode: number = 500, code?: string) {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
    this.name = 'AppError';
  }
}

export class NotFoundError extends AppError {
  constructor(message: string = 'Resource not found') {
    super(message, 404, 'NOT_FOUND');
    this.name = 'NotFoundError';
  }
}

export class UnauthorizedError extends AppError {
  constructor(message: string = 'Unauthorized') {
    super(message, 401, 'UNAUTHORIZED');
    this.name = 'UnauthorizedError';
  }
}

export class BadRequestError extends AppError {
  constructor(message: string = 'Bad request') {
    super(message, 400, 'BAD_REQUEST');
    this.name = 'BadRequestError';
  }
}

export class ConflictError extends AppError {
  constructor(message: string = 'Resource already exists') {
    super(message, 409, 'CONFLICT');
    this.name = 'ConflictError';
  }
}

// ============================================================================
// Stripe Event Mapping Types
// ============================================================================

export const STRIPE_STATUS_MAP: Record<string, SubscriptionStatus> = {
  trialing: 'TRIALING',
  active: 'ACTIVE',
  past_due: 'PAST_DUE',
  canceled: 'CANCELED',
  unpaid: 'UNPAID',
  incomplete: 'INCOMPLETE',
  incomplete_expired: 'INCOMPLETE_EXPIRED',
  paused: 'PAUSED',
} as const;

// ============================================================================
// JWT Types
// ============================================================================

export interface JWTPayload {
  userId: string;
  email: string;
  iat?: number;
  exp?: number;
}

// ============================================================================
// Health Check Types
// ============================================================================

export interface HealthCheckResponse {
  status: 'ok' | 'degraded' | 'error';
  timestamp: string;
  uptime: number;
  version: string;
  database: {
    status: 'connected' | 'disconnected';
    latency?: number;
  };
}
