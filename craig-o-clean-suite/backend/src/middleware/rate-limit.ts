import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { config } from '../config/index.js';

/**
 * Rate limit configuration types
 */
export interface RateLimitConfig {
  max: number;
  timeWindow: number;
  keyGenerator?: (request: FastifyRequest) => string;
  allowList?: string[];
  blockList?: string[];
  skipOnError?: boolean;
}

/**
 * In-memory rate limit store
 * For production, consider using Redis for distributed rate limiting
 */
interface RateLimitEntry {
  count: number;
  resetAt: number;
}

class RateLimitStore {
  private store = new Map<string, RateLimitEntry>();
  private cleanupInterval: NodeJS.Timeout | null = null;

  constructor() {
    // Clean up expired entries every minute
    this.cleanupInterval = setInterval(() => this.cleanup(), 60000);
  }

  get(key: string): RateLimitEntry | undefined {
    return this.store.get(key);
  }

  set(key: string, entry: RateLimitEntry): void {
    this.store.set(key, entry);
  }

  increment(key: string, timeWindow: number): RateLimitEntry {
    const now = Date.now();
    const existing = this.store.get(key);

    if (!existing || existing.resetAt < now) {
      // Create new entry
      const entry = {
        count: 1,
        resetAt: now + timeWindow,
      };
      this.store.set(key, entry);
      return entry;
    }

    // Increment existing entry
    existing.count++;
    return existing;
  }

  private cleanup(): void {
    const now = Date.now();
    for (const [key, entry] of this.store.entries()) {
      if (entry.resetAt < now) {
        this.store.delete(key);
      }
    }
  }

  close(): void {
    if (this.cleanupInterval) {
      clearInterval(this.cleanupInterval);
      this.cleanupInterval = null;
    }
    this.store.clear();
  }
}

// Singleton store instance
const store = new RateLimitStore();

/**
 * Default key generator - uses user ID if authenticated, otherwise IP
 */
const defaultKeyGenerator = (request: FastifyRequest): string => {
  if (request.user?.userId) {
    return `user:${request.user.userId}`;
  }
  return `ip:${request.ip}`;
};

/**
 * Create a custom rate limiter hook for specific routes
 */
export const createRateLimiter = (options: Partial<RateLimitConfig> = {}) => {
  const {
    max = config.rateLimit.max,
    timeWindow = config.rateLimit.timeWindow,
    keyGenerator = defaultKeyGenerator,
    allowList = [],
    blockList = [],
    skipOnError = true,
  } = options;

  return async (request: FastifyRequest, reply: FastifyReply): Promise<void> => {
    try {
      const key = keyGenerator(request);

      // Check block list
      if (blockList.includes(key)) {
        reply.status(403).send({
          statusCode: 403,
          error: 'Forbidden',
          message: 'Access denied',
          code: 'BLOCKED',
        });
        return;
      }

      // Check allow list
      if (allowList.includes(key)) {
        return;
      }

      // Get or create rate limit entry
      const entry = store.increment(key, timeWindow);

      // Set rate limit headers
      const remaining = Math.max(0, max - entry.count);
      const resetSeconds = Math.ceil((entry.resetAt - Date.now()) / 1000);

      reply.header('X-RateLimit-Limit', max.toString());
      reply.header('X-RateLimit-Remaining', remaining.toString());
      reply.header('X-RateLimit-Reset', resetSeconds.toString());

      // Check if rate limit exceeded
      if (entry.count > max) {
        reply.header('Retry-After', resetSeconds.toString());
        reply.status(429).send({
          statusCode: 429,
          error: 'Too Many Requests',
          message: `Rate limit exceeded. Try again in ${resetSeconds} seconds.`,
          code: 'RATE_LIMIT_EXCEEDED',
        });
        return;
      }
    } catch (err) {
      // If skipOnError is true, allow the request through on errors
      if (!skipOnError) {
        throw err;
      }
      request.log.error({ err }, 'Rate limit check failed');
    }
  };
};

/**
 * Stricter rate limiter for sensitive endpoints like auth
 */
export const authRateLimiter = createRateLimiter({
  max: 10,
  timeWindow: 60000, // 1 minute
  keyGenerator: (request) => {
    // Use email from body if available for auth endpoints
    const body = request.body as { email?: string } | undefined;
    if (body?.email) {
      return `auth:${body.email}`;
    }
    return `auth:${request.ip}`;
  },
});

/**
 * Rate limiter for checkout endpoints
 */
export const checkoutRateLimiter = createRateLimiter({
  max: 5,
  timeWindow: 60000, // 1 minute - prevent abuse of checkout session creation
});

/**
 * Rate limiter for API endpoints
 */
export const apiRateLimiter = createRateLimiter({
  max: config.rateLimit.max,
  timeWindow: config.rateLimit.timeWindow,
});

/**
 * Cleanup function for graceful shutdown
 */
export const closeRateLimitStore = (): void => {
  store.close();
};

/**
 * Rate limit plugin for Fastify
 */
export const rateLimitPlugin = async (
  fastify: FastifyInstance,
  options: Partial<RateLimitConfig> = {}
): Promise<void> => {
  const limiter = createRateLimiter(options);

  // Add hook to all routes
  fastify.addHook('preHandler', limiter);

  // Clean up on close
  fastify.addHook('onClose', () => {
    closeRateLimitStore();
  });
};
