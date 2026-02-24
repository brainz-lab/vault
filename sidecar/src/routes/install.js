'use strict';

const { installPiece, isInstalled } = require('../services/piece-installer');

/**
 * Installation route for adding new piece packages at runtime.
 *
 * @param {import('fastify').FastifyInstance} fastify
 */
async function installRoutes(fastify) {
  /**
   * POST /install
   *
   * Body:
   *   package - full npm package name (e.g. "@activepieces/piece-slack")
   */
  fastify.post('/install', {
    schema: {
      body: {
        type: 'object',
        required: ['package'],
        properties: {
          package: { type: 'string', minLength: 1 },
        },
      },
    },
  }, async (request, reply) => {
    const { package: packageName } = request.body;

    request.log.info({ packageName }, 'Installing piece package');

    // Validate package name format
    if (!packageName.startsWith('@activepieces/piece-')) {
      reply.code(400);
      return {
        success: false,
        error: 'Only @activepieces/piece-* packages are allowed',
      };
    }

    // Check if already installed
    const shortName = packageName.replace('@activepieces/piece-', '');
    if (isInstalled(shortName)) {
      request.log.info({ packageName }, 'Package already installed, reinstalling for update');
    }

    try {
      const result = installPiece(packageName);

      if (!result.success) {
        reply.code(422);
      }

      return result;
    } catch (err) {
      request.log.error({ err, packageName }, 'Unexpected install error');
      reply.code(500);
      return {
        success: false,
        error: `Internal install error: ${err.message}`,
      };
    }
  });
}

module.exports = installRoutes;
