import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { PrismaClient } from '@prisma/client';
import { StripeService } from '../services/stripe.service.js';
import { CustomerPortalResponse, UnauthorizedError, NotFoundError, BadRequestError } from '../types/index.js';

interface PortalRouteOptions {
  prisma: PrismaClient;
  stripeService: StripeService;
}

export const portalRoutes = async (
  fastify: FastifyInstance,
  options: PortalRouteOptions
): Promise<void> => {
  const { prisma, stripeService } = options;

  /**
   * POST /api/customer-portal
   * Create a Stripe customer portal session
   */
  fastify.post<{
    Reply: CustomerPortalResponse;
    Body: { returnUrl?: string };
  }>(
    '/customer-portal',
    {
      onRequest: [fastify.authenticate],
      schema: {
        description: 'Create a Stripe customer portal session',
        tags: ['Portal'],
        security: [{ bearerAuth: [] }],
        body: {
          type: 'object',
          properties: {
            returnUrl: {
              type: 'string',
              format: 'uri',
              description: 'URL to redirect after portal session',
            },
          },
        },
        response: {
          200: {
            type: 'object',
            properties: {
              url: { type: 'string' },
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
      const { returnUrl } = request.body || {};

      logger.info({ userId }, 'Creating customer portal session');

      // Get user with Stripe customer ID
      const user = await prisma.user.findUnique({
        where: { id: userId },
      });

      if (!user) {
        throw new NotFoundError('User not found');
      }

      if (!user.stripeCustomerId) {
        throw new BadRequestError('No billing account found. Please subscribe first.');
      }

      // Create portal session
      const url = await stripeService.createPortalSession(
        user.stripeCustomerId,
        returnUrl
      );

      logger.info({ userId }, 'Portal session created');

      return reply.send({ url });
    }
  );

  /**
   * GET /api/billing-history
   * Get billing history for the current user
   */
  fastify.get<{
    Reply: {
      invoices: Array<{
        id: string;
        amount: number;
        currency: string;
        status: string;
        created: string;
        pdf: string | null;
      }>;
    };
  }>(
    '/billing-history',
    {
      onRequest: [fastify.authenticate],
      schema: {
        description: 'Get billing history',
        tags: ['Portal'],
        security: [{ bearerAuth: [] }],
        response: {
          200: {
            type: 'object',
            properties: {
              invoices: {
                type: 'array',
                items: {
                  type: 'object',
                  properties: {
                    id: { type: 'string' },
                    amount: { type: 'number' },
                    currency: { type: 'string' },
                    status: { type: 'string' },
                    created: { type: 'string' },
                    pdf: { type: 'string', nullable: true },
                  },
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

      const { userId } = request.user;

      logger.info({ userId }, 'Fetching billing history');

      const user = await prisma.user.findUnique({
        where: { id: userId },
      });

      if (!user?.stripeCustomerId) {
        return reply.send({ invoices: [] });
      }

      // Note: This would require additional Stripe API calls
      // For now, return empty array - implement if needed
      return reply.send({ invoices: [] });
    }
  );

  /**
   * POST /api/cancel-subscription
   * Cancel subscription at period end
   */
  fastify.post<{
    Reply: { success: boolean; cancelAt: string | null };
  }>(
    '/cancel-subscription',
    {
      onRequest: [fastify.authenticate],
      schema: {
        description: 'Cancel subscription at period end',
        tags: ['Portal'],
        security: [{ bearerAuth: [] }],
        response: {
          200: {
            type: 'object',
            properties: {
              success: { type: 'boolean' },
              cancelAt: { type: 'string', nullable: true },
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

      logger.info({ userId }, 'Canceling subscription');

      // Get active entitlement
      const entitlement = await prisma.entitlement.findFirst({
        where: {
          userId,
          status: { in: ['ACTIVE', 'TRIALING'] },
        },
      });

      if (!entitlement) {
        throw new NotFoundError('No active subscription found');
      }

      // Cancel via Stripe
      const subscription = await stripeService.cancelSubscription(
        entitlement.stripeSubscriptionId
      );

      // Update local record
      await prisma.entitlement.update({
        where: { id: entitlement.id },
        data: { cancelAtPeriodEnd: true },
      });

      const cancelAt = subscription.cancel_at
        ? new Date(subscription.cancel_at * 1000).toISOString()
        : null;

      logger.info({ userId, cancelAt }, 'Subscription canceled');

      return reply.send({
        success: true,
        cancelAt,
      });
    }
  );

  /**
   * POST /api/reactivate-subscription
   * Reactivate a canceled subscription
   */
  fastify.post<{
    Reply: { success: boolean };
  }>(
    '/reactivate-subscription',
    {
      onRequest: [fastify.authenticate],
      schema: {
        description: 'Reactivate a canceled subscription',
        tags: ['Portal'],
        security: [{ bearerAuth: [] }],
        response: {
          200: {
            type: 'object',
            properties: {
              success: { type: 'boolean' },
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

      logger.info({ userId }, 'Reactivating subscription');

      // Get canceled entitlement
      const entitlement = await prisma.entitlement.findFirst({
        where: {
          userId,
          cancelAtPeriodEnd: true,
          status: { in: ['ACTIVE', 'TRIALING'] },
        },
      });

      if (!entitlement) {
        throw new NotFoundError('No cancelable subscription found');
      }

      // Reactivate via Stripe
      await stripeService.reactivateSubscription(entitlement.stripeSubscriptionId);

      // Update local record
      await prisma.entitlement.update({
        where: { id: entitlement.id },
        data: { cancelAtPeriodEnd: false },
      });

      logger.info({ userId }, 'Subscription reactivated');

      return reply.send({ success: true });
    }
  );
};
