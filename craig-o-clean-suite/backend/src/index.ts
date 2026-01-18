import { buildApp } from './app.js';
import { config } from './config/index.js';

const start = async (): Promise<void> => {
  const app = await buildApp();

  try {
    // Start the server
    await app.listen({
      port: config.server.port,
      host: config.server.host,
    });

    const address = app.server.address();
    const port = typeof address === 'string' ? address : address?.port;

    app.log.info(`Server started on ${config.server.host}:${port}`);
    app.log.info(`Environment: ${config.server.env}`);
    app.log.info(`Log level: ${config.logging.level}`);

    // Graceful shutdown handlers
    const shutdown = async (signal: string): Promise<void> => {
      app.log.info(`Received ${signal}, shutting down gracefully...`);

      try {
        await app.close();
        app.log.info('Server closed successfully');
        process.exit(0);
      } catch (err) {
        app.log.error(err, 'Error during shutdown');
        process.exit(1);
      }
    };

    process.on('SIGTERM', () => shutdown('SIGTERM'));
    process.on('SIGINT', () => shutdown('SIGINT'));

    // Handle uncaught exceptions
    process.on('uncaughtException', (err) => {
      app.log.fatal(err, 'Uncaught exception');
      process.exit(1);
    });

    process.on('unhandledRejection', (reason, promise) => {
      app.log.error({ reason, promise }, 'Unhandled rejection');
    });
  } catch (err) {
    app.log.fatal(err, 'Failed to start server');
    process.exit(1);
  }
};

// Start the application
start();
