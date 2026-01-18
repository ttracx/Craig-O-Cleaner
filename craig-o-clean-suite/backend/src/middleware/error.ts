import { FastifyError, FastifyReply, FastifyRequest } from 'fastify';
import { ZodError } from 'zod';
import { AppError, ErrorResponse } from '../types/index.js';
import { config } from '../config/index.js';

/**
 * Format Zod validation errors
 */
const formatZodError = (error: ZodError): string => {
  const messages = error.errors.map((e) => {
    const path = e.path.join('.');
    return path ? `${path}: ${e.message}` : e.message;
  });
  return messages.join('; ');
};

/**
 * Global error handler for Fastify
 */
export const errorHandler = (
  error: FastifyError | Error,
  request: FastifyRequest,
  reply: FastifyReply
): void => {
  const logger = request.log;

  // Handle Zod validation errors
  if (error instanceof ZodError) {
    const message = formatZodError(error);
    logger.warn({ err: error }, 'Validation error');

    const response: ErrorResponse = {
      statusCode: 400,
      error: 'Validation Error',
      message,
      code: 'VALIDATION_ERROR',
    };

    reply.status(400).send(response);
    return;
  }

  // Handle our custom AppError
  if (error instanceof AppError) {
    logger.warn({ err: error }, error.message);

    const response: ErrorResponse = {
      statusCode: error.statusCode,
      error: error.name,
      message: error.message,
      code: error.code,
    };

    reply.status(error.statusCode).send(response);
    return;
  }

  // Handle Fastify validation errors
  if ('validation' in error && error.validation) {
    logger.warn({ err: error }, 'Request validation error');

    const response: ErrorResponse = {
      statusCode: 400,
      error: 'Validation Error',
      message: error.message,
      code: 'VALIDATION_ERROR',
    };

    reply.status(400).send(response);
    return;
  }

  // Handle Stripe errors
  if (error.name === 'StripeError' || error.constructor.name.includes('Stripe')) {
    logger.error({ err: error }, 'Stripe error');

    const stripeError = error as { statusCode?: number; code?: string; message: string };
    const statusCode = stripeError.statusCode || 500;

    const response: ErrorResponse = {
      statusCode,
      error: 'Payment Error',
      message: config.server.isDev ? stripeError.message : 'A payment processing error occurred',
      code: stripeError.code || 'STRIPE_ERROR',
    };

    reply.status(statusCode).send(response);
    return;
  }

  // Handle 404 errors
  if ('statusCode' in error && error.statusCode === 404) {
    const response: ErrorResponse = {
      statusCode: 404,
      error: 'Not Found',
      message: 'The requested resource was not found',
      code: 'NOT_FOUND',
    };

    reply.status(404).send(response);
    return;
  }

  // Handle rate limit errors
  if ('statusCode' in error && error.statusCode === 429) {
    const response: ErrorResponse = {
      statusCode: 429,
      error: 'Too Many Requests',
      message: 'Rate limit exceeded. Please try again later.',
      code: 'RATE_LIMIT_EXCEEDED',
    };

    reply.status(429).send(response);
    return;
  }

  // Log unexpected errors
  logger.error({ err: error }, 'Unexpected error');

  // Generic error response
  const response: ErrorResponse = {
    statusCode: 500,
    error: 'Internal Server Error',
    message: config.server.isDev ? error.message : 'An unexpected error occurred',
    code: 'INTERNAL_ERROR',
  };

  reply.status(500).send(response);
};

/**
 * Not found handler
 */
export const notFoundHandler = (request: FastifyRequest, reply: FastifyReply): void => {
  const response: ErrorResponse = {
    statusCode: 404,
    error: 'Not Found',
    message: `Route ${request.method} ${request.url} not found`,
    code: 'ROUTE_NOT_FOUND',
  };

  reply.status(404).send(response);
};

/**
 * Request logging hook
 */
export const requestLoggingHook = (request: FastifyRequest, reply: FastifyReply, done: () => void): void => {
  request.log.info({
    method: request.method,
    url: request.url,
    params: request.params,
    query: request.query,
    headers: {
      'user-agent': request.headers['user-agent'],
      'content-type': request.headers['content-type'],
    },
  });
  done();
};

/**
 * Response logging hook
 */
export const responseLoggingHook = (request: FastifyRequest, reply: FastifyReply, done: () => void): void => {
  request.log.info({
    statusCode: reply.statusCode,
    responseTime: reply.elapsedTime,
  });
  done();
};
