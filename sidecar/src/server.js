'use strict';

const Fastify = require('fastify');
const logger = require('./utils/logger');

const PORT = parseInt(process.env.PORT, 10) || 3100;
const HOST = process.env.HOST || '0.0.0.0';
const SIDECAR_SECRET_KEY = process.env.SIDECAR_SECRET_KEY || '';

/**
 * Build and configure the Fastify server instance.
 */
async function buildServer() {
  const fastify = Fastify({
    logger: {
      level: process.env.LOG_LEVEL || 'info',
      transport:
        process.env.NODE_ENV !== 'production'
          ? { target: 'pino-pretty', options: { colorize: true } }
          : undefined,
    },
    bodyLimit: 10 * 1024 * 1024, // 10 MB
    requestTimeout: 130_000, // slightly above max action timeout
    disableRequestLogging: false,
  });

  // --------------------------------------------------------------------------
  // Authentication middleware
  // --------------------------------------------------------------------------
  fastify.addHook('onRequest', async (request, reply) => {
    // Skip auth for health check
    if (request.url === '/health') {
      return;
    }

    // If no secret key is configured, skip auth (development mode)
    if (!SIDECAR_SECRET_KEY) {
      return;
    }

    const authHeader = request.headers.authorization;
    if (!authHeader) {
      reply.code(401);
      throw new Error('Missing Authorization header');
    }

    const token = authHeader.startsWith('Bearer ')
      ? authHeader.slice(7)
      : authHeader;

    if (token !== SIDECAR_SECRET_KEY) {
      reply.code(403);
      throw new Error('Invalid authorization token');
    }
  });

  // --------------------------------------------------------------------------
  // Global error handler
  // --------------------------------------------------------------------------
  fastify.setErrorHandler((error, request, reply) => {
    const statusCode = error.statusCode || reply.statusCode || 500;

    request.log.error({
      err: error,
      statusCode,
      url: request.url,
      method: request.method,
    }, 'Request error');

    // Fastify validation errors
    if (error.validation) {
      reply.code(400).send({
        error: 'Validation error',
        detail: error.message,
        validation: error.validation,
      });
      return;
    }

    reply.code(statusCode).send({
      error: error.message || 'Internal server error',
    });
  });

  // --------------------------------------------------------------------------
  // Register routes
  // --------------------------------------------------------------------------
  await fastify.register(require('./routes/health'));
  await fastify.register(require('./routes/catalog'));
  await fastify.register(require('./routes/execute'));
  await fastify.register(require('./routes/install'));
  await fastify.register(require('./routes/validate'));

  // --------------------------------------------------------------------------
  // 404 handler
  // --------------------------------------------------------------------------
  fastify.setNotFoundHandler((request, reply) => {
    reply.code(404).send({
      error: 'Not found',
      method: request.method,
      url: request.url,
    });
  });

  return fastify;
}

/**
 * Start the server and set up graceful shutdown handlers.
 */
async function start() {
  let fastify;

  try {
    fastify = await buildServer();

    await fastify.listen({ port: PORT, host: HOST });

    logger.info(
      { port: PORT, host: HOST, auth: SIDECAR_SECRET_KEY ? 'enabled' : 'disabled' },
      'Vault connector sidecar started'
    );
  } catch (err) {
    logger.fatal({ err }, 'Failed to start server');
    process.exit(1);
  }

  // Graceful shutdown
  const shutdown = async (signal) => {
    logger.info({ signal }, 'Received shutdown signal, closing server...');
    try {
      await fastify.close();
      logger.info('Server closed gracefully');
      process.exit(0);
    } catch (err) {
      logger.error({ err }, 'Error during shutdown');
      process.exit(1);
    }
  };

  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));

  // Prevent crashes from unhandled rejections
  process.on('unhandledRejection', (reason) => {
    logger.error({ err: reason }, 'Unhandled promise rejection');
  });

  process.on('uncaughtException', (err) => {
    logger.fatal({ err }, 'Uncaught exception - shutting down');
    shutdown('uncaughtException');
  });
}

// Allow importing buildServer for testing
module.exports = { buildServer };

// Auto-start when run directly
if (require.main === module) {
  start();
}
