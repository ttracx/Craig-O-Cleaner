import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { PrismaClient } from '@prisma/client';
import { HealthCheckResponse } from '../types/index.js';

interface HealthRouteOptions {
  prisma: PrismaClient;
}

// Package version (would normally be imported from package.json)
const VERSION = '1.0.0';

export const healthRoutes = async (
  fastify: FastifyInstance,
  options: HealthRouteOptions
): Promise<void> => {
  const { prisma } = options;
  const startTime = Date.now();

  /**
   * GET /health
   * Health check endpoint for load balancers and monitoring
   */
  fastify.get<{
    Reply: HealthCheckResponse;
  }>(
    '/health',
    {
      schema: {
        description: 'Health check endpoint',
        tags: ['Health'],
        response: {
          200: {
            type: 'object',
            properties: {
              status: { type: 'string', enum: ['ok', 'degraded', 'error'] },
              timestamp: { type: 'string' },
              uptime: { type: 'number' },
              version: { type: 'string' },
              database: {
                type: 'object',
                properties: {
                  status: { type: 'string', enum: ['connected', 'disconnected'] },
                  latency: { type: 'number' },
                },
              },
            },
          },
        },
      },
    },
    async (request, reply) => {
      const logger = request.log;

      // Check database connectivity
      let dbStatus: 'connected' | 'disconnected' = 'disconnected';
      let dbLatency: number | undefined;

      try {
        const dbStart = Date.now();
        await prisma.$queryRaw`SELECT 1`;
        dbLatency = Date.now() - dbStart;
        dbStatus = 'connected';
      } catch (err) {
        logger.error({ err }, 'Database health check failed');
        dbStatus = 'disconnected';
      }

      // Determine overall status
      let status: 'ok' | 'degraded' | 'error';
      if (dbStatus === 'connected') {
        // Check if DB latency is acceptable (< 1000ms)
        status = dbLatency && dbLatency < 1000 ? 'ok' : 'degraded';
      } else {
        status = 'error';
      }

      const response: HealthCheckResponse = {
        status,
        timestamp: new Date().toISOString(),
        uptime: Math.floor((Date.now() - startTime) / 1000),
        version: VERSION,
        database: {
          status: dbStatus,
          latency: dbLatency,
        },
      };

      // Return appropriate status code based on health
      const statusCode = status === 'error' ? 503 : 200;
      return reply.status(statusCode).send(response);
    }
  );

  /**
   * GET /ready
   * Readiness check - indicates if the service is ready to accept traffic
   */
  fastify.get(
    '/ready',
    {
      schema: {
        description: 'Readiness check endpoint',
        tags: ['Health'],
        response: {
          200: {
            type: 'object',
            properties: {
              ready: { type: 'boolean' },
            },
          },
          503: {
            type: 'object',
            properties: {
              ready: { type: 'boolean' },
              reason: { type: 'string' },
            },
          },
        },
      },
    },
    async (request, reply) => {
      try {
        // Check if database is accessible
        await prisma.$queryRaw`SELECT 1`;
        return reply.send({ ready: true });
      } catch (err) {
        return reply.status(503).send({
          ready: false,
          reason: 'Database not available',
        });
      }
    }
  );

  /**
   * GET /live
   * Liveness check - indicates if the service is alive (minimal check)
   */
  fastify.get(
    '/live',
    {
      schema: {
        description: 'Liveness check endpoint',
        tags: ['Health'],
        response: {
          200: {
            type: 'object',
            properties: {
              alive: { type: 'boolean' },
            },
          },
        },
      },
    },
    async (request, reply) => {
      // Simple liveness check - just returns OK
      return reply.send({ alive: true });
    }
  );

  /**
   * GET /metrics
   * Basic metrics endpoint (could be expanded for Prometheus)
   */
  fastify.get(
    '/metrics',
    {
      schema: {
        description: 'Basic metrics endpoint',
        tags: ['Health'],
        response: {
          200: {
            type: 'object',
            properties: {
              uptime_seconds: { type: 'number' },
              memory_usage_mb: { type: 'number' },
              cpu_usage_percent: { type: 'number' },
            },
          },
        },
      },
    },
    async (request, reply) => {
      const memUsage = process.memoryUsage();
      const cpuUsage = process.cpuUsage();

      return reply.send({
        uptime_seconds: Math.floor((Date.now() - startTime) / 1000),
        memory_usage_mb: Math.round(memUsage.heapUsed / 1024 / 1024 * 100) / 100,
        // CPU usage as a rough percentage (user + system time)
        cpu_usage_percent: Math.round((cpuUsage.user + cpuUsage.system) / 1000000 * 100) / 100,
      });
    }
  );
};
