import { vi, beforeAll, afterAll, beforeEach, afterEach } from 'vitest';
import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';
import Stripe from 'stripe';

// ============================================================================
// Environment Setup
// ============================================================================

// Set test environment variables before any imports
process.env.NODE_ENV = 'test';
process.env.PORT = '0'; // Use random port for tests
process.env.HOST = '127.0.0.1';
process.env.DATABASE_URL = 'postgresql://test:test@localhost:5432/test?schema=public';
process.env.STRIPE_SECRET_KEY = 'sk_test_mock_key_for_testing';
process.env.STRIPE_WEBHOOK_SECRET = 'whsec_test_mock_secret';
process.env.STRIPE_PRICE_MONTHLY = 'price_craigoclean_monthly';
process.env.STRIPE_PRICE_YEARLY = 'price_craigoclean_yearly';
process.env.JWT_SECRET = 'test-jwt-secret-key-minimum-32-characters-long';
process.env.JWT_EXPIRES_IN = '1h';
process.env.CORS_ORIGINS = 'http://localhost:3000,craigoclean://';
process.env.RATE_LIMIT_MAX = '1000';
process.env.RATE_LIMIT_TIME_WINDOW = '60000';
process.env.LOG_LEVEL = 'silent';
process.env.SUCCESS_URL = 'craigoclean://billing/success';
process.env.CANCEL_URL = 'craigoclean://billing/cancel';

// ============================================================================
// Mock Data
// ============================================================================

export const mockUser = {
  id: 'test-user-id',
  email: 'test@example.com',
  stripeCustomerId: 'cus_test123',
  platform: 'linux',
  createdAt: new Date(),
  updatedAt: new Date(),
};

export const mockEntitlement = {
  id: 'test-entitlement-id',
  userId: mockUser.id,
  stripeSubscriptionId: 'sub_test123',
  status: 'ACTIVE' as const,
  tier: 'MONTHLY' as const,
  currentPeriodStart: new Date(),
  currentPeriodEnd: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
  cancelAtPeriodEnd: false,
  trialEnd: null,
  createdAt: new Date(),
  updatedAt: new Date(),
};

export const mockStripeCustomer: Stripe.Customer = {
  id: 'cus_test123',
  object: 'customer',
  email: 'test@example.com',
  name: 'Test User',
  metadata: { platform: 'linux' },
  created: Math.floor(Date.now() / 1000),
  livemode: false,
  balance: 0,
  currency: null,
  default_source: null,
  delinquent: false,
  description: null,
  discount: null,
  invoice_prefix: 'TEST',
  invoice_settings: {
    custom_fields: null,
    default_payment_method: null,
    footer: null,
    rendering_options: null,
  },
  next_invoice_sequence: 1,
  preferred_locales: [],
  shipping: null,
  tax_exempt: 'none',
  deleted: undefined,
};

export const mockStripeSubscription: Stripe.Subscription = {
  id: 'sub_test123',
  object: 'subscription',
  customer: 'cus_test123',
  status: 'active',
  items: {
    object: 'list',
    data: [
      {
        id: 'si_test123',
        object: 'subscription_item',
        subscription: 'sub_test123',
        price: {
          id: 'price_craigoclean_monthly',
          object: 'price',
          active: true,
          billing_scheme: 'per_unit',
          created: Math.floor(Date.now() / 1000),
          currency: 'usd',
          livemode: false,
          lookup_key: null,
          metadata: {},
          nickname: 'Monthly',
          product: 'prod_test123',
          recurring: {
            interval: 'month',
            interval_count: 1,
            usage_type: 'licensed',
            aggregate_usage: null,
            trial_period_days: 7,
          },
          tax_behavior: 'unspecified',
          tiers_mode: null,
          transform_quantity: null,
          type: 'recurring',
          unit_amount: 99,
          unit_amount_decimal: '99',
        },
        quantity: 1,
        created: Math.floor(Date.now() / 1000),
        metadata: {},
        billing_thresholds: null,
        discounts: [],
        tax_rates: [],
      },
    ],
    has_more: false,
    url: '/v1/subscription_items?subscription=sub_test123',
  },
  current_period_start: Math.floor(Date.now() / 1000),
  current_period_end: Math.floor(Date.now() / 1000) + 30 * 24 * 60 * 60,
  cancel_at_period_end: false,
  trial_end: Math.floor(Date.now() / 1000) + 7 * 24 * 60 * 60,
  metadata: { platform: 'linux', tier: 'monthly' },
  created: Math.floor(Date.now() / 1000),
  livemode: false,
  application: null,
  application_fee_percent: null,
  automatic_tax: { enabled: false, liability: null },
  billing_cycle_anchor: Math.floor(Date.now() / 1000),
  billing_cycle_anchor_config: null,
  billing_thresholds: null,
  cancel_at: null,
  canceled_at: null,
  cancellation_details: { comment: null, feedback: null, reason: null },
  collection_method: 'charge_automatically',
  currency: 'usd',
  days_until_due: null,
  default_payment_method: null,
  default_source: null,
  description: null,
  discount: null,
  discounts: [],
  ended_at: null,
  invoice_settings: { account_tax_ids: null, issuer: { type: 'self' } },
  latest_invoice: 'in_test123',
  next_pending_invoice_item_invoice: null,
  on_behalf_of: null,
  pause_collection: null,
  payment_settings: {
    payment_method_options: null,
    payment_method_types: null,
    save_default_payment_method: null,
  },
  pending_invoice_item_interval: null,
  pending_setup_intent: null,
  pending_update: null,
  schedule: null,
  start_date: Math.floor(Date.now() / 1000),
  test_clock: null,
  transfer_data: null,
  trial_settings: { end_behavior: { missing_payment_method: 'create_invoice' } },
  trial_start: Math.floor(Date.now() / 1000),
};

export const mockCheckoutSession: Stripe.Checkout.Session = {
  id: 'cs_test123',
  object: 'checkout.session',
  url: 'https://checkout.stripe.com/test',
  customer: 'cus_test123',
  subscription: 'sub_test123',
  mode: 'subscription',
  status: 'complete',
  payment_status: 'paid',
  metadata: { platform: 'linux' },
  created: Math.floor(Date.now() / 1000),
  livemode: false,
  after_expiration: null,
  allow_promotion_codes: true,
  amount_subtotal: 99,
  amount_total: 99,
  automatic_tax: { enabled: false, liability: null, status: null },
  billing_address_collection: 'auto',
  cancel_url: 'craigoclean://billing/cancel',
  success_url: 'craigoclean://billing/success',
  client_reference_id: null,
  client_secret: null,
  consent: null,
  consent_collection: null,
  currency: 'usd',
  currency_conversion: null,
  custom_fields: [],
  custom_text: { after_submit: null, shipping_address: null, submit: null, terms_of_service_acceptance: null },
  customer_creation: 'always',
  customer_details: { email: 'test@example.com', name: null, phone: null, tax_exempt: 'none', tax_ids: [], address: null },
  customer_email: 'test@example.com',
  expires_at: Math.floor(Date.now() / 1000) + 86400,
  invoice: 'in_test123',
  invoice_creation: null,
  line_items: undefined,
  locale: 'auto',
  payment_intent: null,
  payment_link: null,
  payment_method_collection: 'always',
  payment_method_configuration_details: null,
  payment_method_options: null,
  payment_method_types: ['card'],
  phone_number_collection: { enabled: false },
  recovered_from: null,
  redirect_on_completion: 'always',
  return_url: null,
  saved_payment_method_options: null,
  setup_intent: null,
  shipping_address_collection: null,
  shipping_cost: null,
  shipping_details: null,
  shipping_options: [],
  submit_type: null,
  tax_id_collection: null,
  total_details: { amount_discount: 0, amount_shipping: 0, amount_tax: 0 },
  ui_mode: 'hosted',
};

// ============================================================================
// Stripe Mock
// ============================================================================

export const createStripeMock = () => {
  return {
    customers: {
      create: vi.fn().mockResolvedValue(mockStripeCustomer),
      retrieve: vi.fn().mockResolvedValue(mockStripeCustomer),
      list: vi.fn().mockResolvedValue({ data: [mockStripeCustomer] }),
    },
    subscriptions: {
      list: vi.fn().mockResolvedValue({ data: [mockStripeSubscription] }),
      retrieve: vi.fn().mockResolvedValue(mockStripeSubscription),
      update: vi.fn().mockResolvedValue(mockStripeSubscription),
    },
    checkout: {
      sessions: {
        create: vi.fn().mockResolvedValue(mockCheckoutSession),
        retrieve: vi.fn().mockResolvedValue(mockCheckoutSession),
      },
    },
    billingPortal: {
      sessions: {
        create: vi.fn().mockResolvedValue({ url: 'https://billing.stripe.com/test' }),
      },
    },
    webhooks: {
      constructEvent: vi.fn().mockImplementation((payload, sig, secret) => {
        const data = JSON.parse(payload.toString());
        return {
          id: 'evt_test123',
          type: data.type || 'customer.subscription.created',
          data: { object: data.object || mockStripeSubscription },
        };
      }),
    },
  };
};

// ============================================================================
// Prisma Mock
// ============================================================================

export const createPrismaMock = () => {
  return {
    user: {
      findUnique: vi.fn().mockResolvedValue(mockUser),
      findFirst: vi.fn().mockResolvedValue(mockUser),
      create: vi.fn().mockResolvedValue(mockUser),
      update: vi.fn().mockResolvedValue(mockUser),
      upsert: vi.fn().mockResolvedValue(mockUser),
      delete: vi.fn().mockResolvedValue(mockUser),
    },
    entitlement: {
      findUnique: vi.fn().mockResolvedValue(mockEntitlement),
      findFirst: vi.fn().mockResolvedValue(mockEntitlement),
      findMany: vi.fn().mockResolvedValue([mockEntitlement]),
      create: vi.fn().mockResolvedValue(mockEntitlement),
      update: vi.fn().mockResolvedValue(mockEntitlement),
      upsert: vi.fn().mockResolvedValue(mockEntitlement),
      updateMany: vi.fn().mockResolvedValue({ count: 1 }),
    },
    entitlementToken: {
      findUnique: vi.fn().mockResolvedValue(null),
      create: vi.fn().mockImplementation(({ data }) => ({
        id: 'token-id',
        ...data,
        createdAt: new Date(),
        revokedAt: null,
      })),
      update: vi.fn().mockResolvedValue({}),
      updateMany: vi.fn().mockResolvedValue({ count: 1 }),
      deleteMany: vi.fn().mockResolvedValue({ count: 0 }),
      findMany: vi.fn().mockResolvedValue([]),
    },
    webhookEvent: {
      findUnique: vi.fn().mockResolvedValue(null),
      create: vi.fn().mockResolvedValue({}),
      update: vi.fn().mockResolvedValue({}),
      upsert: vi.fn().mockResolvedValue({}),
    },
    $connect: vi.fn().mockResolvedValue(undefined),
    $disconnect: vi.fn().mockResolvedValue(undefined),
    $queryRaw: vi.fn().mockResolvedValue([{ '?column?': 1 }]),
  };
};

// ============================================================================
// Test App Builder
// ============================================================================

let app: FastifyInstance | null = null;

export const getTestApp = async (): Promise<FastifyInstance> => {
  if (app) return app;

  // Dynamic import to ensure mocks are set up first
  const { buildApp } = await import('../src/app.js');
  app = await buildApp();
  await app.ready();
  return app;
};

export const closeTestApp = async (): Promise<void> => {
  if (app) {
    await app.close();
    app = null;
  }
};

// ============================================================================
// Test Utilities
// ============================================================================

export const generateTestToken = (): string => {
  // Generate a simple test JWT token
  const header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
  const payload = Buffer.from(
    JSON.stringify({
      userId: mockUser.id,
      email: mockUser.email,
      iat: Math.floor(Date.now() / 1000),
      exp: Math.floor(Date.now() / 1000) + 3600,
    })
  ).toString('base64url');
  // This won't be a valid signature but works for mocked tests
  const signature = 'test_signature';
  return `${header}.${payload}.${signature}`;
};

export const createWebhookPayload = (
  eventType: string,
  object: Record<string, unknown>
): { payload: string; signature: string } => {
  const payload = JSON.stringify({
    id: 'evt_test123',
    type: eventType,
    object,
    created: Math.floor(Date.now() / 1000),
    livemode: false,
  });

  // Mock signature - in real tests you'd compute this properly
  const signature = `t=${Math.floor(Date.now() / 1000)},v1=test_signature`;

  return { payload, signature };
};

// ============================================================================
// Global Test Hooks
// ============================================================================

beforeAll(async () => {
  // Setup before all tests
});

afterAll(async () => {
  await closeTestApp();
});

beforeEach(() => {
  // Reset all mocks before each test
  vi.clearAllMocks();
});

afterEach(() => {
  // Cleanup after each test
});
