'use strict';

const { cachedCount, listInstalledPackages } = require('../services/piece-loader');

/**
 * Health check route.
 *
 * @param {import('fastify').FastifyInstance} fastify
 */
async function healthRoutes(fastify) {
  fastify.get('/health', {
    schema: {
      response: {
        200: {
          type: 'object',
          properties: {
            status: { type: 'string' },
            uptime: { type: 'number' },
            pieces_loaded: { type: 'integer' },
            pieces_installed: { type: 'integer' },
            timestamp: { type: 'string' },
          },
        },
      },
    },
  }, async (request, reply) => {
    const installed = listInstalledPackages();
    return {
      status: 'ok',
      uptime: process.uptime(),
      pieces_loaded: cachedCount(),
      pieces_installed: installed.length,
      timestamp: new Date().toISOString(),
    };
  });
}

module.exports = healthRoutes;
