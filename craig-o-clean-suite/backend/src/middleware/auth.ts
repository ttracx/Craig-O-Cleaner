import { FastifyRequest, FastifyReply, FastifyInstance } from 'fastify';
import { TokenService } from '../services/token.service.js';
import { UnauthorizedError, AuthenticatedRequest } from '../types/index.js';

declare module 'fastify' {
  interface FastifyRequest {
    user?: {
      userId: string;
      email: string;
    };
  }
}

export const createAuthMiddleware = (tokenService: TokenService) => {
  return async (request: FastifyRequest, reply: FastifyReply): Promise<void> => {
    const authHeader = request.headers.authorization;

    if (!authHeader) {
      throw new UnauthorizedError('Authorization header is required');
    }

    const token = TokenService.extractBearerToken(authHeader);

    if (!token) {
      throw new UnauthorizedError('Invalid authorization header format. Use: Bearer <token>');
    }

    // Validate the token
    const validation = await tokenService.validateEntitlementToken(token);

    if (!validation.valid || !validation.userId || !validation.email) {
      throw new UnauthorizedError('Invalid or expired token');
    }

    // Attach user info to request
    request.user = {
      userId: validation.userId,
      email: validation.email,
    };
  };
};

/**
 * Optional auth middleware - does not throw if no token provided
 */
export const createOptionalAuthMiddleware = (tokenService: TokenService) => {
  return async (request: FastifyRequest, reply: FastifyReply): Promise<void> => {
    const authHeader = request.headers.authorization;

    if (!authHeader) {
      return;
    }

    const token = TokenService.extractBearerToken(authHeader);

    if (!token) {
      return;
    }

    try {
      const validation = await tokenService.validateEntitlementToken(token);

      if (validation.valid && validation.userId && validation.email) {
        request.user = {
          userId: validation.userId,
          email: validation.email,
        };
      }
    } catch {
      // Silently ignore auth errors for optional auth
    }
  };
};

/**
 * Plugin to register auth decorators
 */
export const authPlugin = async (fastify: FastifyInstance, options: { tokenService: TokenService }) => {
  const { tokenService } = options;

  // Decorate request with user
  fastify.decorateRequest('user', null);

  // Register hooks
  fastify.decorate('authenticate', createAuthMiddleware(tokenService));
  fastify.decorate('optionalAuth', createOptionalAuthMiddleware(tokenService));
};

declare module 'fastify' {
  interface FastifyInstance {
    authenticate: ReturnType<typeof createAuthMiddleware>;
    optionalAuth: ReturnType<typeof createOptionalAuthMiddleware>;
  }
}
