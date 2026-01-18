import Fastify, { FastifyInstance } from 'fastify';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import sensible from '@fastify/sensible';
import rateLimit from '@fastify/rate-limit';
import { PrismaClient } from '@prisma/client';

import { config } from './config/index.js';
import { errorHandler, notFoundHandler } from './middleware/error.js';
import { authPlugin } from './middleware/auth.js';
import { createStripeService } from './services/stripe.service.js';
import { createTokenService } from './services/token.service.js';
import { createEntitlementService } from './services/entitlement.service.js';
import { checkoutRoutes } from './routes/checkout.js';
import { webhookRoutes } from './routes/webhooks.js';
import { entitlementRoutes } from './routes/entitlement.js';
import { portalRoutes } from './routes/portal.js';
import { healthRoutes } from './routes/health.js';

// Extend Fastify types for raw body support
declare module 'fastify' {
  interface FastifyRequest {
    rawBody?: Buffer | string;
  }
}

export const buildApp = async (): Promise<FastifyInstance> => {
  // Initialize Prisma client
  const prisma = new PrismaClient({
    log: config.server.isDev
      ? ['query', 'info', 'warn', 'error']
      : ['error'],
  });

  // Initialize services
  const stripeService = createStripeService(prisma);
  const tokenService = createTokenService(prisma);
  const entitlementService = createEntitlementService(prisma, stripeService, tokenService);

  // Create Fastify instance
  const app = Fastify({
    logger: {
      level: config.logging.level,
      transport: config.server.isDev
        ? {
            target: 'pino-pretty',
            options: {
              colorize: true,
              translateTime: 'HH:MM:ss Z',
              ignore: 'pid,hostname',
            },
          }
        : undefined,
    },
    trustProxy: true,
    // Disable default body parsing for webhook route to get raw body
    bodyLimit: 1048576, // 1MB
  });

  // Add content type parser for raw body (needed for Stripe webhooks)
  app.addContentTypeParser(
    'application/json',
    { parseAs: 'buffer' },
    (req, body, done) => {
      // Store raw body for webhook signature verification
      req.rawBody = body;

      try {
        const json = JSON.parse(body.toString());
        done(null, json);
      } catch (err) {
        done(err as Error, undefined);
      }
    }
  );

  // Register plugins
  await app.register(sensible);

  // CORS configuration for desktop apps
  await app.register(cors, {
    origin: (origin, callback) => {
      // Allow requests with no origin (desktop apps, curl, etc.)
      if (!origin) {
        callback(null, true);
        return;
      }

      // Check if origin is in allowed list
      const allowed = config.cors.origins.some((allowedOrigin) => {
        if (allowedOrigin.includes('*')) {
          const regex = new RegExp(allowedOrigin.replace('*', '.*'));
          return regex.test(origin);
        }
        return origin === allowedOrigin || origin.startsWith(allowedOrigin);
      });

      callback(null, allowed);
    },
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
    exposedHeaders: ['X-RateLimit-Limit', 'X-RateLimit-Remaining', 'X-RateLimit-Reset'],
  });

  // Security headers
  await app.register(helmet, {
    contentSecurityPolicy: false, // Disable for API
    crossOriginEmbedderPolicy: false,
  });

  // Rate limiting
  await app.register(rateLimit, {
    max: config.rateLimit.max,
    timeWindow: config.rateLimit.timeWindow,
    errorResponseBuilder: (request, context) => ({
      statusCode: 429,
      error: 'Too Many Requests',
      message: `Rate limit exceeded. Try again in ${Math.ceil(context.ttl / 1000)} seconds.`,
      code: 'RATE_LIMIT_EXCEEDED',
    }),
    keyGenerator: (request) => {
      // Use user ID if authenticated, otherwise IP
      return request.user?.userId || request.ip;
    },
    // Exempt webhook endpoint from rate limiting (Stripe handles its own rate limiting)
    allowList: (request) => {
      return request.url.startsWith('/webhooks/');
    },
  });

  // Register auth plugin
  await app.register(authPlugin, { tokenService });

  // Set error handler
  app.setErrorHandler(errorHandler);
  app.setNotFoundHandler(notFoundHandler);

  // Register routes
  await app.register(healthRoutes, { prisma });
  await app.register(checkoutRoutes, { prefix: '/api', stripeService, tokenService });
  await app.register(webhookRoutes, { prefix: '/webhooks', prisma, stripeService, entitlementService });
  await app.register(entitlementRoutes, { prefix: '/api', entitlementService, tokenService });
  await app.register(portalRoutes, { prefix: '/api', prisma, stripeService });

  // Connect to database on startup
  app.addHook('onReady', async () => {
    try {
      await prisma.$connect();
      app.log.info('Database connected');
    } catch (err) {
      app.log.error(err, 'Failed to connect to database');
      throw err;
    }
  });

  // Disconnect from database on close
  app.addHook('onClose', async () => {
    await prisma.$disconnect();
    app.log.info('Database disconnected');
  });

  return app;
};
