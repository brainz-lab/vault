'use strict';

const { validateAuth } = require('../services/auth-validator');

/**
 * Validation route for testing piece auth credentials.
 *
 * @param {import('fastify').FastifyInstance} fastify
 */
async function validateRoutes(fastify) {
  /**
   * POST /validate
   *
   * Body:
   *   piece - short piece name (e.g. "slack")
   *   auth  - auth credentials to validate
   */
  fastify.post('/validate', {
    schema: {
      body: {
        type: 'object',
        required: ['piece', 'auth'],
        properties: {
          piece: { type: 'string', minLength: 1 },
          auth: {},
        },
      },
    },
  }, async (request, reply) => {
    const { piece, auth } = request.body;

    request.log.info({ piece }, 'Validating auth credentials');

    try {
      const result = await validateAuth(piece, auth);

      if (!result.valid) {
        reply.code(422);
      }

      return result;
    } catch (err) {
      request.log.error({ err, piece }, 'Unexpected validation error');
      reply.code(500);
      return {
        valid: false,
        error: `Internal validation error: ${err.message}`,
      };
    }
  });
}

module.exports = validateRoutes;
