import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import Stripe from 'stripe';
import { PrismaClient } from '@prisma/client';
import { StripeService } from '../services/stripe.service.js';
import { EntitlementService } from '../services/entitlement.service.js';
import { WebhookResponse, BadRequestError } from '../types/index.js';

interface WebhookRouteOptions {
  prisma: PrismaClient;
  stripeService: StripeService;
  entitlementService: EntitlementService;
}

// Events we care about
const HANDLED_EVENTS = [
  'customer.subscription.created',
  'customer.subscription.updated',
  'customer.subscription.deleted',
  'invoice.payment_failed',
  'invoice.payment_succeeded',
  'checkout.session.completed',
] as const;

type HandledEventType = typeof HANDLED_EVENTS[number];

export const webhookRoutes = async (
  fastify: FastifyInstance,
  options: WebhookRouteOptions
): Promise<void> => {
  const { prisma, stripeService, entitlementService } = options;

  /**
   * POST /webhooks/stripe
   * Handle Stripe webhook events
   */
  fastify.post<{
    Reply: WebhookResponse;
  }>(
    '/stripe',
    {
      // Important: We need the raw body for signature verification
      config: {
        rawBody: true,
      },
      schema: {
        description: 'Handle Stripe webhook events',
        tags: ['Webhooks'],
        response: {
          200: {
            type: 'object',
            properties: {
              received: { type: 'boolean' },
            },
          },
        },
      },
    },
    async (request, reply) => {
      const logger = request.log;

      // Get raw body and signature
      const rawBody = request.rawBody;
      const signature = request.headers['stripe-signature'];

      if (!rawBody) {
        throw new BadRequestError('Missing request body');
      }

      if (!signature || typeof signature !== 'string') {
        throw new BadRequestError('Missing Stripe signature header');
      }

      // Verify webhook signature and parse event
      let event: Stripe.Event;
      try {
        event = stripeService.verifyWebhookSignature(
          Buffer.isBuffer(rawBody) ? rawBody : Buffer.from(rawBody),
          signature
        );
      } catch (err) {
        logger.error({ err }, 'Webhook signature verification failed');
        throw new BadRequestError('Invalid webhook signature');
      }

      logger.info({ eventId: event.id, eventType: event.type }, 'Received webhook event');

      // Check for duplicate event (idempotency)
      const existingEvent = await prisma.webhookEvent.findUnique({
        where: { stripeEventId: event.id },
      });

      if (existingEvent?.processed) {
        logger.info({ eventId: event.id }, 'Event already processed, skipping');
        return reply.send({ received: true });
      }

      // Store event for processing
      await prisma.webhookEvent.upsert({
        where: { stripeEventId: event.id },
        update: {},
        create: {
          stripeEventId: event.id,
          eventType: event.type,
          payload: JSON.stringify(event.data.object),
        },
      });

      // Process the event
      try {
        await processWebhookEvent(event, entitlementService, logger);

        // Mark event as processed
        await prisma.webhookEvent.update({
          where: { stripeEventId: event.id },
          data: {
            processed: true,
            processedAt: new Date(),
          },
        });

        logger.info({ eventId: event.id, eventType: event.type }, 'Webhook event processed successfully');
      } catch (err) {
        // Store error but still return 200 to prevent retries for known issues
        logger.error({ err, eventId: event.id }, 'Error processing webhook event');

        await prisma.webhookEvent.update({
          where: { stripeEventId: event.id },
          data: {
            error: err instanceof Error ? err.message : 'Unknown error',
          },
        });

        // Still return 200 to acknowledge receipt
        // Stripe will retry on 4xx/5xx responses
      }

      return reply.send({ received: true });
    }
  );
};

/**
 * Process a webhook event based on its type
 */
async function processWebhookEvent(
  event: Stripe.Event,
  entitlementService: EntitlementService,
  logger: FastifyRequest['log']
): Promise<void> {
  switch (event.type) {
    case 'customer.subscription.created':
    case 'customer.subscription.updated': {
      const subscription = event.data.object as Stripe.Subscription;
      logger.info({
        subscriptionId: subscription.id,
        status: subscription.status,
        customerId: subscription.customer,
      }, 'Processing subscription update');

      await entitlementService.syncFromStripeSubscription(subscription);
      break;
    }

    case 'customer.subscription.deleted': {
      const subscription = event.data.object as Stripe.Subscription;
      logger.info({
        subscriptionId: subscription.id,
        customerId: subscription.customer,
      }, 'Processing subscription deletion');

      await entitlementService.handleSubscriptionDeleted(subscription);
      break;
    }

    case 'invoice.payment_failed': {
      const invoice = event.data.object as Stripe.Invoice;
      logger.info({
        invoiceId: invoice.id,
        subscriptionId: invoice.subscription,
        customerId: invoice.customer,
      }, 'Processing payment failure');

      await entitlementService.handlePaymentFailed(invoice);
      break;
    }

    case 'invoice.payment_succeeded': {
      const invoice = event.data.object as Stripe.Invoice;
      logger.info({
        invoiceId: invoice.id,
        subscriptionId: invoice.subscription,
        customerId: invoice.customer,
      }, 'Processing successful payment');

      await entitlementService.handlePaymentSucceeded(invoice);
      break;
    }

    case 'checkout.session.completed': {
      const session = event.data.object as Stripe.Checkout.Session;
      logger.info({
        sessionId: session.id,
        customerId: session.customer,
        subscriptionId: session.subscription,
      }, 'Processing checkout completion');

      // Subscription will be handled by customer.subscription.created event
      // This is just for logging/analytics
      break;
    }

    default:
      logger.info({ eventType: event.type }, 'Ignoring unhandled event type');
  }
}
