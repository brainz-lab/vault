'use strict';

const { executePieceAction } = require('../services/piece-executor');

/**
 * Execution route for running piece actions.
 *
 * @param {import('fastify').FastifyInstance} fastify
 */
async function executeRoutes(fastify) {
  /**
   * POST /execute
   *
   * Body:
   *   piece   - short piece name (e.g. "slack")
   *   action  - action name within the piece
   *   input   - object with input props
   *   auth    - auth credentials for the connector
   *   timeout - optional timeout in ms (default 30000, max 120000)
   */
  fastify.post('/execute', {
    schema: {
      body: {
        type: 'object',
        required: ['piece', 'action'],
        properties: {
          piece: { type: 'string', minLength: 1 },
          action: { type: 'string', minLength: 1 },
          input: { type: 'object', default: {} },
          auth: {},
          timeout: { type: 'integer', minimum: 1000, maximum: 120000, default: 30000 },
        },
      },
    },
  }, async (request, reply) => {
    const { piece, action, input, auth, timeout } = request.body;

    request.log.info({ piece, action }, 'Executing piece action');

    try {
      const result = await executePieceAction(piece, action, input, auth, timeout);

      if (!result.success) {
        reply.code(422);
      }

      return result;
    } catch (err) {
      request.log.error({ err, piece, action }, 'Unexpected execution error');
      reply.code(500);
      return {
        success: false,
        output: null,
        duration_ms: 0,
        error: `Internal execution error: ${err.message}`,
      };
    }
  });
}

module.exports = executeRoutes;
