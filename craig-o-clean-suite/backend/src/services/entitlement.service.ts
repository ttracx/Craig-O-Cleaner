import { PrismaClient, SubscriptionStatus, SubscriptionTier, Entitlement } from '@prisma/client';
import Stripe from 'stripe';
import { StripeService } from './stripe.service.js';
import { TokenService } from './token.service.js';
import { EntitlementResponse, NotFoundError, AppError } from '../types/index.js';

export class EntitlementService {
  private prisma: PrismaClient;
  private stripeService: StripeService;
  private tokenService: TokenService;

  // Offline grace period in hours
  private readonly OFFLINE_GRACE_PERIOD_HOURS = 72;

  constructor(
    prisma: PrismaClient,
    stripeService: StripeService,
    tokenService: TokenService
  ) {
    this.prisma = prisma;
    this.stripeService = stripeService;
    this.tokenService = tokenService;
  }

  /**
   * Create or update entitlement from Stripe subscription
   */
  async syncFromStripeSubscription(subscription: Stripe.Subscription): Promise<Entitlement> {
    const customerId = typeof subscription.customer === 'string'
      ? subscription.customer
      : subscription.customer.id;

    // Find user by Stripe customer ID
    let user = await this.prisma.user.findUnique({
      where: { stripeCustomerId: customerId },
    });

    // If no user found, try to get customer email and create user
    if (!user) {
      const customer = await this.stripeService.findCustomerByEmail(customerId);
      if (customer && customer.email) {
        user = await this.prisma.user.upsert({
          where: { email: customer.email },
          update: { stripeCustomerId: customerId },
          create: {
            email: customer.email,
            stripeCustomerId: customerId,
            platform: subscription.metadata?.platform || undefined,
          },
        });
      }
    }

    if (!user) {
      throw new NotFoundError('User not found for subscription');
    }

    const status = this.stripeService.mapSubscriptionStatus(subscription.status);
    const tier = await this.stripeService.determineSubscriptionTier(subscription);

    // Create or update entitlement
    const entitlement = await this.prisma.entitlement.upsert({
      where: { stripeSubscriptionId: subscription.id },
      update: {
        status,
        tier,
        currentPeriodStart: new Date(subscription.current_period_start * 1000),
        currentPeriodEnd: new Date(subscription.current_period_end * 1000),
        cancelAtPeriodEnd: subscription.cancel_at_period_end,
        trialEnd: subscription.trial_end
          ? new Date(subscription.trial_end * 1000)
          : null,
      },
      create: {
        userId: user.id,
        stripeSubscriptionId: subscription.id,
        status,
        tier,
        currentPeriodStart: new Date(subscription.current_period_start * 1000),
        currentPeriodEnd: new Date(subscription.current_period_end * 1000),
        cancelAtPeriodEnd: subscription.cancel_at_period_end,
        trialEnd: subscription.trial_end
          ? new Date(subscription.trial_end * 1000)
          : null,
      },
    });

    return entitlement;
  }

  /**
   * Handle subscription cancellation
   */
  async handleSubscriptionDeleted(subscription: Stripe.Subscription): Promise<Entitlement | null> {
    const entitlement = await this.prisma.entitlement.findUnique({
      where: { stripeSubscriptionId: subscription.id },
    });

    if (!entitlement) {
      return null;
    }

    return this.prisma.entitlement.update({
      where: { id: entitlement.id },
      data: {
        status: 'CANCELED',
        cancelAtPeriodEnd: true,
      },
    });
  }

  /**
   * Handle payment failure
   */
  async handlePaymentFailed(invoice: Stripe.Invoice): Promise<void> {
    if (!invoice.subscription) return;

    const subscriptionId = typeof invoice.subscription === 'string'
      ? invoice.subscription
      : invoice.subscription.id;

    const entitlement = await this.prisma.entitlement.findUnique({
      where: { stripeSubscriptionId: subscriptionId },
    });

    if (entitlement) {
      await this.prisma.entitlement.update({
        where: { id: entitlement.id },
        data: { status: 'PAST_DUE' },
      });
    }
  }

  /**
   * Handle successful payment
   */
  async handlePaymentSucceeded(invoice: Stripe.Invoice): Promise<void> {
    if (!invoice.subscription) return;

    const subscriptionId = typeof invoice.subscription === 'string'
      ? invoice.subscription
      : invoice.subscription.id;

    // Fetch fresh subscription data
    const subscription = await this.stripeService.getSubscription(subscriptionId);
    await this.syncFromStripeSubscription(subscription);
  }

  /**
   * Get entitlement for a user
   */
  async getEntitlementForUser(userId: string): Promise<EntitlementResponse> {
    const entitlement = await this.prisma.entitlement.findFirst({
      where: {
        userId,
        status: { in: ['ACTIVE', 'TRIALING', 'PAST_DUE'] },
      },
      orderBy: { currentPeriodEnd: 'desc' },
    });

    if (!entitlement) {
      return {
        valid: false,
        subscription: null,
        features: {
          fullAccess: false,
          offlineGracePeriodHours: 0,
        },
      };
    }

    const isValid = this.isEntitlementValid(entitlement);

    return {
      valid: isValid,
      subscription: {
        id: entitlement.stripeSubscriptionId,
        status: entitlement.status,
        tier: entitlement.tier,
        currentPeriodEnd: entitlement.currentPeriodEnd.toISOString(),
        cancelAtPeriodEnd: entitlement.cancelAtPeriodEnd,
        trialEnd: entitlement.trialEnd?.toISOString() || null,
      },
      features: {
        fullAccess: isValid,
        offlineGracePeriodHours: isValid ? this.OFFLINE_GRACE_PERIOD_HOURS : 0,
      },
    };
  }

  /**
   * Check if entitlement is currently valid
   */
  private isEntitlementValid(entitlement: Entitlement): boolean {
    const validStatuses: SubscriptionStatus[] = ['ACTIVE', 'TRIALING', 'PAST_DUE'];

    if (!validStatuses.includes(entitlement.status)) {
      return false;
    }

    // Check if current period has ended
    if (entitlement.currentPeriodEnd < new Date()) {
      // Allow some grace period for webhook processing
      const graceMinutes = 60; // 1 hour grace
      const graceEnd = new Date(entitlement.currentPeriodEnd.getTime() + graceMinutes * 60 * 1000);
      if (graceEnd < new Date()) {
        return false;
      }
    }

    return true;
  }

  /**
   * Restore subscription by email
   */
  async restoreSubscription(email: string, platform?: string): Promise<{
    token: string;
    expiresAt: Date;
    entitlement: Entitlement;
  }> {
    // Find user by email
    let user = await this.prisma.user.findUnique({
      where: { email },
      include: {
        entitlements: {
          where: {
            status: { in: ['ACTIVE', 'TRIALING', 'PAST_DUE'] },
          },
          orderBy: { currentPeriodEnd: 'desc' },
          take: 1,
        },
      },
    });

    // If no local user, check Stripe
    if (!user) {
      const customer = await this.stripeService.findCustomerByEmail(email);
      if (!customer) {
        throw new NotFoundError('No subscription found for this email');
      }

      // Get active subscription from Stripe
      const subscription = await this.stripeService.getActiveSubscription(customer.id);
      if (!subscription) {
        throw new NotFoundError('No active subscription found for this email');
      }

      // Sync the subscription
      const entitlement = await this.syncFromStripeSubscription(subscription);

      // Reload user with entitlements
      user = await this.prisma.user.findUnique({
        where: { email },
        include: {
          entitlements: {
            where: { id: entitlement.id },
          },
        },
      });

      if (!user) {
        throw new AppError('Failed to sync subscription', 500);
      }
    }

    const entitlement = user.entitlements[0];
    if (!entitlement) {
      // Try to sync from Stripe
      if (user.stripeCustomerId) {
        const subscription = await this.stripeService.getActiveSubscription(user.stripeCustomerId);
        if (subscription) {
          const syncedEntitlement = await this.syncFromStripeSubscription(subscription);
          const { token, expiresAt } = await this.tokenService.createEntitlementToken(user.id);
          return { token, expiresAt, entitlement: syncedEntitlement };
        }
      }
      throw new NotFoundError('No active subscription found for this email');
    }

    // Update platform if provided
    if (platform && user.platform !== platform) {
      await this.prisma.user.update({
        where: { id: user.id },
        data: { platform },
      });
    }

    // Create new token
    const { token, expiresAt } = await this.tokenService.createEntitlementToken(user.id);

    return { token, expiresAt, entitlement };
  }

  /**
   * Get entitlement by subscription ID
   */
  async getEntitlementBySubscriptionId(subscriptionId: string): Promise<Entitlement | null> {
    return this.prisma.entitlement.findUnique({
      where: { stripeSubscriptionId: subscriptionId },
    });
  }

  /**
   * Get all entitlements for a user
   */
  async getAllEntitlementsForUser(userId: string): Promise<Entitlement[]> {
    return this.prisma.entitlement.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
  }

  /**
   * Check and expire past-due subscriptions
   */
  async expirePastDueSubscriptions(daysThreshold: number = 7): Promise<number> {
    const threshold = new Date();
    threshold.setDate(threshold.getDate() - daysThreshold);

    const result = await this.prisma.entitlement.updateMany({
      where: {
        status: 'PAST_DUE',
        updatedAt: { lt: threshold },
      },
      data: {
        status: 'CANCELED',
      },
    });

    return result.count;
  }
}

export const createEntitlementService = (
  prisma: PrismaClient,
  stripeService: StripeService,
  tokenService: TokenService
): EntitlementService => {
  return new EntitlementService(prisma, stripeService, tokenService);
};
