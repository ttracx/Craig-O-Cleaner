import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { StripeService } from '../services/stripe.service.js';
import { TokenService } from '../services/token.service.js';
import {
  CreateCheckoutSessionSchema,
  CreateCheckoutSessionInput,
  CreateCheckoutSessionResponse,
  BadRequestError,
} from '../types/index.js';

interface CheckoutRouteOptions {
  stripeService: StripeService;
  tokenService: TokenService;
}

export const checkoutRoutes = async (
  fastify: FastifyInstance,
  options: CheckoutRouteOptions
): Promise<void> => {
  const { stripeService, tokenService } = options;

  /**
   * POST /api/create-checkout-session
   * Create a Stripe checkout session for subscription
   */
  fastify.post<{
    Body: CreateCheckoutSessionInput;
    Reply: CreateCheckoutSessionResponse;
  }>(
    '/create-checkout-session',
    {
      schema: {
        description: 'Create a Stripe checkout session for subscription',
        tags: ['Checkout'],
        body: {
          type: 'object',
          required: ['priceId', 'platform'],
          properties: {
            priceId: {
              type: 'string',
              enum: ['monthly', 'yearly'],
              description: 'Subscription tier',
            },
            platform: {
              type: 'string',
              enum: ['linux', 'windows'],
              description: 'Platform initiating the checkout',
            },
            email: {
              type: 'string',
              format: 'email',
              description: 'Optional customer email for prefilling',
            },
            returnUrl: {
              type: 'string',
              format: 'uri',
              description: 'URL to redirect after checkout',
            },
          },
        },
        response: {
          200: {
            type: 'object',
            properties: {
              sessionId: { type: 'string' },
              url: { type: 'string' },
            },
          },
        },
      },
    },
    async (request, reply) => {
      const logger = request.log;

      // Validate request body
      const parseResult = CreateCheckoutSessionSchema.safeParse(request.body);
      if (!parseResult.success) {
        throw new BadRequestError(parseResult.error.errors.map((e) => e.message).join(', '));
      }

      const { priceId, platform, email, returnUrl } = parseResult.data;

      logger.info({
        priceId,
        platform,
        email: email ? 'provided' : 'not provided',
      }, 'Creating checkout session');

      // Create checkout session
      const session = await stripeService.createCheckoutSession({
        priceId,
        platform,
        email,
        returnUrl,
      });

      logger.info({ sessionId: session.sessionId }, 'Checkout session created');

      return reply.send({
        sessionId: session.sessionId,
        url: session.url,
      });
    }
  );

  /**
   * GET /api/checkout-session/:sessionId
   * Get checkout session status (for polling after redirect)
   */
  fastify.get<{
    Params: { sessionId: string };
  }>(
    '/checkout-session/:sessionId',
    {
      schema: {
        description: 'Get checkout session status',
        tags: ['Checkout'],
        params: {
          type: 'object',
          required: ['sessionId'],
          properties: {
            sessionId: { type: 'string' },
          },
        },
        response: {
          200: {
            type: 'object',
            properties: {
              status: { type: 'string' },
              customerId: { type: 'string' },
              subscriptionId: { type: 'string' },
              token: { type: 'string' },
            },
          },
        },
      },
    },
    async (request, reply) => {
      const { sessionId } = request.params;
      const logger = request.log;

      logger.info({ sessionId }, 'Fetching checkout session status');

      // This would typically be implemented to check session status
      // For now, return a placeholder response
      // The actual subscription creation is handled via webhooks

      return reply.send({
        status: 'pending',
        customerId: null,
        subscriptionId: null,
        token: null,
      });
    }
  );
};
