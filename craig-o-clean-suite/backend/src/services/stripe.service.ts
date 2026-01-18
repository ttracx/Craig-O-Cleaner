import Stripe from 'stripe';
import { config } from '../config/index.js';
import { PrismaClient, SubscriptionStatus, SubscriptionTier } from '@prisma/client';
import { STRIPE_STATUS_MAP, AppError, BadRequestError, NotFoundError } from '../types/index.js';

const stripe = new Stripe(config.stripe.secretKey, {
  apiVersion: '2024-04-10',
  typescript: true,
});

export class StripeService {
  private prisma: PrismaClient;

  constructor(prisma: PrismaClient) {
    this.prisma = prisma;
  }

  /**
   * Get the Stripe price ID based on tier
   */
  private getPriceId(tier: 'monthly' | 'yearly'): string {
    return tier === 'monthly'
      ? config.stripe.prices.monthly
      : config.stripe.prices.yearly;
  }

  /**
   * Get or create a Stripe customer
   */
  async getOrCreateCustomer(email: string, platform?: string): Promise<Stripe.Customer> {
    // Check if user exists with this email
    const existingUser = await this.prisma.user.findUnique({
      where: { email },
    });

    if (existingUser?.stripeCustomerId) {
      const customer = await stripe.customers.retrieve(existingUser.stripeCustomerId);
      if (!customer.deleted) {
        return customer as Stripe.Customer;
      }
    }

    // Create new Stripe customer
    const customer = await stripe.customers.create({
      email,
      metadata: {
        platform: platform || 'unknown',
      },
    });

    // Update or create user in database
    await this.prisma.user.upsert({
      where: { email },
      update: {
        stripeCustomerId: customer.id,
        platform,
      },
      create: {
        email,
        stripeCustomerId: customer.id,
        platform,
      },
    });

    return customer;
  }

  /**
   * Create a checkout session for subscription
   */
  async createCheckoutSession(params: {
    email?: string;
    priceId: 'monthly' | 'yearly';
    platform: string;
    returnUrl?: string;
  }): Promise<{ sessionId: string; url: string }> {
    const stripePriceId = this.getPriceId(params.priceId);

    const sessionParams: Stripe.Checkout.SessionCreateParams = {
      mode: 'subscription',
      payment_method_types: ['card'],
      line_items: [
        {
          price: stripePriceId,
          quantity: 1,
        },
      ],
      subscription_data: {
        trial_period_days: 7,
        metadata: {
          platform: params.platform,
          tier: params.priceId,
        },
      },
      success_url: `${params.returnUrl || config.urls.success}?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: params.returnUrl?.replace('success', 'cancel') || config.urls.cancel,
      metadata: {
        platform: params.platform,
      },
      allow_promotion_codes: true,
      billing_address_collection: 'auto',
      customer_creation: 'always',
    };

    // If email provided, prefill customer email or use existing customer
    if (params.email) {
      const customer = await this.getOrCreateCustomer(params.email, params.platform);
      sessionParams.customer = customer.id;
      delete sessionParams.customer_creation;
    }

    const session = await stripe.checkout.sessions.create(sessionParams);

    if (!session.url) {
      throw new AppError('Failed to create checkout session URL', 500);
    }

    return {
      sessionId: session.id,
      url: session.url,
    };
  }

  /**
   * Create a customer portal session
   */
  async createPortalSession(customerId: string, returnUrl?: string): Promise<string> {
    const session = await stripe.billingPortal.sessions.create({
      customer: customerId,
      return_url: returnUrl || config.urls.success,
    });

    return session.url;
  }

  /**
   * Retrieve subscription by ID
   */
  async getSubscription(subscriptionId: string): Promise<Stripe.Subscription> {
    return stripe.subscriptions.retrieve(subscriptionId);
  }

  /**
   * Look up customer by email
   */
  async findCustomerByEmail(email: string): Promise<Stripe.Customer | null> {
    const customers = await stripe.customers.list({
      email,
      limit: 1,
    });

    return customers.data[0] || null;
  }

  /**
   * Get active subscription for a customer
   */
  async getActiveSubscription(customerId: string): Promise<Stripe.Subscription | null> {
    const subscriptions = await stripe.subscriptions.list({
      customer: customerId,
      status: 'all',
      limit: 10,
    });

    // Find the most recent active or trialing subscription
    const activeStatuses = ['active', 'trialing', 'past_due'];
    const activeSub = subscriptions.data.find((sub) =>
      activeStatuses.includes(sub.status)
    );

    return activeSub || null;
  }

  /**
   * Verify webhook signature and parse event
   */
  verifyWebhookSignature(payload: Buffer, signature: string): Stripe.Event {
    try {
      return stripe.webhooks.constructEvent(
        payload,
        signature,
        config.stripe.webhookSecret
      );
    } catch (err) {
      throw new BadRequestError(`Webhook signature verification failed: ${(err as Error).message}`);
    }
  }

  /**
   * Map Stripe subscription status to our enum
   */
  mapSubscriptionStatus(stripeStatus: string): SubscriptionStatus {
    return STRIPE_STATUS_MAP[stripeStatus] || 'INCOMPLETE';
  }

  /**
   * Determine subscription tier from price
   */
  async determineSubscriptionTier(subscription: Stripe.Subscription): Promise<SubscriptionTier> {
    const priceId = subscription.items.data[0]?.price?.id;

    if (priceId === config.stripe.prices.monthly) {
      return 'MONTHLY';
    } else if (priceId === config.stripe.prices.yearly) {
      return 'YEARLY';
    }

    // Try to determine from price metadata or interval
    const interval = subscription.items.data[0]?.price?.recurring?.interval;
    if (interval === 'month') return 'MONTHLY';
    if (interval === 'year') return 'YEARLY';

    return 'MONTHLY'; // Default
  }

  /**
   * Cancel subscription at period end
   */
  async cancelSubscription(subscriptionId: string): Promise<Stripe.Subscription> {
    return stripe.subscriptions.update(subscriptionId, {
      cancel_at_period_end: true,
    });
  }

  /**
   * Reactivate a canceled subscription
   */
  async reactivateSubscription(subscriptionId: string): Promise<Stripe.Subscription> {
    return stripe.subscriptions.update(subscriptionId, {
      cancel_at_period_end: false,
    });
  }
}

export const createStripeService = (prisma: PrismaClient): StripeService => {
  return new StripeService(prisma);
};
