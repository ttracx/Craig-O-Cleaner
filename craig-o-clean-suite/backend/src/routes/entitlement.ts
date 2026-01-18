import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { EntitlementService } from '../services/entitlement.service.js';
import { TokenService } from '../services/token.service.js';
import {
  EntitlementResponse,
  RestoreSubscriptionSchema,
  RestoreSubscriptionInput,
  RestoreSubscriptionResponse,
  UnauthorizedError,
  BadRequestError,
} from '../types/index.js';

interface EntitlementRouteOptions {
  entitlementService: EntitlementService;
  tokenService: TokenService;
}

export const entitlementRoutes = async (
  fastify: FastifyInstance,
  options: EntitlementRouteOptions
): Promise<void> => {
  const { entitlementService, tokenService } = options;

  /**
   * GET /api/verify-entitlement
   * Verify the current user's entitlement status
   */
  fastify.get<{
    Reply: EntitlementResponse;
  }>(
    '/verify-entitlement',
    {
      onRequest: [fastify.authenticate],
      schema: {
        description: 'Verify subscription entitlement',
        tags: ['Entitlement'],
        security: [{ bearerAuth: [] }],
        response: {
          200: {
            type: 'object',
            properties: {
              valid: { type: 'boolean' },
              subscription: {
                type: 'object',
                nullable: true,
                properties: {
                  id: { type: 'string' },
                  status: { type: 'string' },
                  tier: { type: 'string' },
                  currentPeriodEnd: { type: 'string' },
                  cancelAtPeriodEnd: { type: 'boolean' },
                  trialEnd: { type: 'string', nullable: true },
                },
              },
              features: {
                type: 'object',
                properties: {
                  fullAccess: { type: 'boolean' },
                  offlineGracePeriodHours: { type: 'number' },
                },
              },
            },
          },
        },
      },
    },
    async (request, reply) => {
      const logger = request.log;

      if (!request.user) {
        throw new UnauthorizedError('Authentication required');
      }

      const { userId, email } = request.user;

      logger.info({ userId, email }, 'Verifying entitlement');

      const entitlement = await entitlementService.getEntitlementForUser(userId);

      logger.info({
        userId,
        valid: entitlement.valid,
        status: entitlement.subscription?.status,
      }, 'Entitlement verification complete');

      return reply.send(entitlement);
    }
  );

  /**
   * POST /api/restore-subscription
   * Restore subscription by email lookup
   */
  fastify.post<{
    Body: RestoreSubscriptionInput;
    Reply: RestoreSubscriptionResponse;
  }>(
    '/restore-subscription',
    {
      schema: {
        description: 'Restore subscription by email',
        tags: ['Entitlement'],
        body: {
          type: 'object',
          required: ['email'],
          properties: {
            email: {
              type: 'string',
              format: 'email',
              description: 'Email address associated with subscription',
            },
            platform: {
              type: 'string',
              enum: ['linux', 'windows'],
              description: 'Platform requesting restoration',
            },
          },
        },
        response: {
          200: {
            type: 'object',
            properties: {
              success: { type: 'boolean' },
              token: { type: 'string' },
              expiresAt: { type: 'string' },
              subscription: {
                type: 'object',
                properties: {
                  status: { type: 'string' },
                  tier: { type: 'string' },
                  currentPeriodEnd: { type: 'string' },
                },
              },
            },
          },
        },
      },
    },
    async (request, reply) => {
      const logger = request.log;

      // Validate request body
      const parseResult = RestoreSubscriptionSchema.safeParse(request.body);
      if (!parseResult.success) {
        throw new BadRequestError(parseResult.error.errors.map((e) => e.message).join(', '));
      }

      const { email, platform } = parseResult.data;

      logger.info({ email: email.substring(0, 3) + '***', platform }, 'Attempting subscription restoration');

      const result = await entitlementService.restoreSubscription(email, platform);

      logger.info({
        email: email.substring(0, 3) + '***',
        status: result.entitlement.status,
        tier: result.entitlement.tier,
      }, 'Subscription restored successfully');

      return reply.send({
        success: true,
        token: result.token,
        expiresAt: result.expiresAt.toISOString(),
        subscription: {
          status: result.entitlement.status,
          tier: result.entitlement.tier,
          currentPeriodEnd: result.entitlement.currentPeriodEnd.toISOString(),
        },
      });
    }
  );

  /**
   * POST /api/refresh-token
   * Refresh the entitlement token
   */
  fastify.post<{
    Reply: { token: string; expiresAt: string };
  }>(
    '/refresh-token',
    {
      onRequest: [fastify.authenticate],
      schema: {
        description: 'Refresh entitlement token',
        tags: ['Entitlement'],
        security: [{ bearerAuth: [] }],
        response: {
          200: {
            type: 'object',
            properties: {
              token: { type: 'string' },
              expiresAt: { type: 'string' },
            },
          },
        },
      },
    },
    async (request, reply) => {
      const logger = request.log;

      if (!request.user) {
        throw new UnauthorizedError('Authentication required');
      }

      const { userId } = request.user;

      logger.info({ userId }, 'Refreshing entitlement token');

      // First verify user still has valid entitlement
      const entitlement = await entitlementService.getEntitlementForUser(userId);
      if (!entitlement.valid) {
        throw new UnauthorizedError('No valid subscription found');
      }

      // Create new token
      const { token, expiresAt } = await tokenService.createEntitlementToken(userId);

      logger.info({ userId }, 'Token refreshed successfully');

      return reply.send({
        token,
        expiresAt: expiresAt.toISOString(),
      });
    }
  );

  /**
   * POST /api/revoke-token
   * Revoke all tokens for the current user
   */
  fastify.post<{
    Reply: { success: boolean; message: string };
  }>(
    '/revoke-token',
    {
      onRequest: [fastify.authenticate],
      schema: {
        description: 'Revoke all entitlement tokens',
        tags: ['Entitlement'],
        security: [{ bearerAuth: [] }],
        response: {
          200: {
            type: 'object',
            properties: {
              success: { type: 'boolean' },
              message: { type: 'string' },
            },
          },
        },
      },
    },
    async (request, reply) => {
      const logger = request.log;

      if (!request.user) {
        throw new UnauthorizedError('Authentication required');
      }

      const { userId } = request.user;

      logger.info({ userId }, 'Revoking all tokens');

      await tokenService.revokeAllUserTokens(userId);

      logger.info({ userId }, 'All tokens revoked');

      return reply.send({
        success: true,
        message: 'All tokens have been revoked',
      });
    }
  );
};
