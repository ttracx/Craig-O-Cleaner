import jwt from 'jsonwebtoken';
import { PrismaClient } from '@prisma/client';
import { config } from '../config/index.js';
import { JWTPayload, UnauthorizedError, AppError } from '../types/index.js';

export class TokenService {
  private prisma: PrismaClient;
  private jwtSecret: string;
  private jwtExpiresIn: string;

  constructor(prisma: PrismaClient) {
    this.prisma = prisma;
    this.jwtSecret = config.jwt.secret;
    this.jwtExpiresIn = config.jwt.expiresIn;
  }

  /**
   * Generate a new JWT token for a user
   */
  generateToken(userId: string, email: string): string {
    const payload: JWTPayload = {
      userId,
      email,
    };

    return jwt.sign(payload, this.jwtSecret, {
      expiresIn: this.jwtExpiresIn,
    });
  }

  /**
   * Verify and decode a JWT token
   */
  verifyToken(token: string): JWTPayload {
    try {
      const decoded = jwt.verify(token, this.jwtSecret) as JWTPayload;
      return decoded;
    } catch (err) {
      if (err instanceof jwt.TokenExpiredError) {
        throw new UnauthorizedError('Token has expired');
      }
      if (err instanceof jwt.JsonWebTokenError) {
        throw new UnauthorizedError('Invalid token');
      }
      throw new UnauthorizedError('Token verification failed');
    }
  }

  /**
   * Create and store an entitlement token in the database
   */
  async createEntitlementToken(userId: string): Promise<{
    token: string;
    expiresAt: Date;
  }> {
    // Get user email
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
    });

    if (!user) {
      throw new AppError('User not found', 404);
    }

    // Generate JWT token
    const token = this.generateToken(userId, user.email);

    // Calculate expiry date
    const expiresAt = this.calculateExpiryDate();

    // Store token in database
    await this.prisma.entitlementToken.create({
      data: {
        userId,
        token,
        expiresAt,
      },
    });

    return { token, expiresAt };
  }

  /**
   * Validate an entitlement token from the database
   */
  async validateEntitlementToken(token: string): Promise<{
    valid: boolean;
    userId?: string;
    email?: string;
  }> {
    // First verify JWT signature
    let decoded: JWTPayload;
    try {
      decoded = this.verifyToken(token);
    } catch {
      return { valid: false };
    }

    // Check if token exists in database and is not revoked
    const storedToken = await this.prisma.entitlementToken.findUnique({
      where: { token },
      include: { user: true },
    });

    if (!storedToken) {
      return { valid: false };
    }

    // Check if token is revoked
    if (storedToken.revokedAt) {
      return { valid: false };
    }

    // Check if token has expired
    if (storedToken.expiresAt < new Date()) {
      return { valid: false };
    }

    return {
      valid: true,
      userId: decoded.userId,
      email: decoded.email,
    };
  }

  /**
   * Revoke a specific token
   */
  async revokeToken(token: string): Promise<void> {
    await this.prisma.entitlementToken.update({
      where: { token },
      data: { revokedAt: new Date() },
    });
  }

  /**
   * Revoke all tokens for a user
   */
  async revokeAllUserTokens(userId: string): Promise<void> {
    await this.prisma.entitlementToken.updateMany({
      where: {
        userId,
        revokedAt: null,
      },
      data: { revokedAt: new Date() },
    });
  }

  /**
   * Clean up expired tokens
   */
  async cleanupExpiredTokens(): Promise<number> {
    const result = await this.prisma.entitlementToken.deleteMany({
      where: {
        expiresAt: { lt: new Date() },
      },
    });

    return result.count;
  }

  /**
   * Get all active tokens for a user
   */
  async getUserTokens(userId: string): Promise<
    Array<{
      id: string;
      expiresAt: Date;
      createdAt: Date;
    }>
  > {
    const tokens = await this.prisma.entitlementToken.findMany({
      where: {
        userId,
        revokedAt: null,
        expiresAt: { gt: new Date() },
      },
      select: {
        id: true,
        expiresAt: true,
        createdAt: true,
      },
      orderBy: { createdAt: 'desc' },
    });

    return tokens;
  }

  /**
   * Calculate token expiry date based on config
   */
  private calculateExpiryDate(): Date {
    const expiresIn = this.jwtExpiresIn;
    const now = new Date();

    // Parse the expiresIn string (e.g., '30d', '1h', '60m')
    const match = expiresIn.match(/^(\d+)([dhms])$/);
    if (!match) {
      // Default to 30 days
      return new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);
    }

    const [, value, unit] = match;
    const numValue = parseInt(value!, 10);

    switch (unit) {
      case 'd':
        return new Date(now.getTime() + numValue * 24 * 60 * 60 * 1000);
      case 'h':
        return new Date(now.getTime() + numValue * 60 * 60 * 1000);
      case 'm':
        return new Date(now.getTime() + numValue * 60 * 1000);
      case 's':
        return new Date(now.getTime() + numValue * 1000);
      default:
        return new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);
    }
  }

  /**
   * Extract token from Authorization header
   */
  static extractBearerToken(authHeader: string | undefined): string | null {
    if (!authHeader) return null;

    const parts = authHeader.split(' ');
    if (parts.length !== 2 || parts[0]?.toLowerCase() !== 'bearer') {
      return null;
    }

    return parts[1] || null;
  }
}

export const createTokenService = (prisma: PrismaClient): TokenService => {
  return new TokenService(prisma);
};
