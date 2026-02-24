'use strict';

const { listPieces, loadPiece, serializePiece } = require('../services/piece-loader');

/**
 * Catalog routes for browsing installed pieces.
 *
 * @param {import('fastify').FastifyInstance} fastify
 */
async function catalogRoutes(fastify) {
  /**
   * GET /catalog
   * List all installed pieces with their metadata, actions, triggers, and auth.
   */
  fastify.get('/catalog', async (request, reply) => {
    try {
      const pieces = listPieces();
      return {
        count: pieces.length,
        pieces,
      };
    } catch (err) {
      request.log.error({ err }, 'Failed to list catalog');
      reply.code(500);
      return { error: 'Failed to load piece catalog', detail: err.message };
    }
  });

  /**
   * GET /catalog/:name
   * Get detailed info about a single piece by short name.
   */
  fastify.get('/catalog/:name', async (request, reply) => {
    const { name } = request.params;

    try {
      const piece = loadPiece(name);
      if (!piece) {
        reply.code(404);
        return {
          error: `Piece "${name}" not found`,
          hint: 'Use POST /install to install new pieces',
        };
      }

      const serialized = serializePiece(piece);
      serialized.name = name;
      serialized.packageName = `@activepieces/piece-${name}`;

      return serialized;
    } catch (err) {
      request.log.error({ err, name }, 'Failed to load piece');
      reply.code(500);
      return { error: `Failed to load piece "${name}"`, detail: err.message };
    }
  });
}

module.exports = catalogRoutes;
