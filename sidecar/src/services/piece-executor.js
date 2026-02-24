'use strict';

const { loadPiece } = require('./piece-loader');
const { withTimeout } = require('../utils/timeout');
const logger = require('../utils/logger');

/**
 * Build the execution context expected by Activepieces action.run().
 *
 * The context object mimics the Activepieces engine context that actions
 * receive at runtime. We provide the minimum surface needed for most
 * actions to function outside the full Activepieces engine.
 */
function buildContext(auth, input, signal) {
  return {
    auth,
    propsValue: input || {},
    store: createInMemoryStore(),
    connections: {
      get: async () => null,
    },
    server: {
      apiUrl: process.env.AP_API_URL || '',
      publicUrl: process.env.AP_PUBLIC_URL || '',
      token: '',
    },
    files: {
      write: async ({ fileName, data }) => {
        logger.debug({ fileName }, 'File write requested (in-memory noop)');
        return `memory://${fileName}`;
      },
    },
    run: {
      id: `sidecar-${Date.now()}`,
      stop: () => {},
      pause: () => {},
    },
    generateResumeUrl: () => '',
    // Some actions check for abort signal
    signal,
  };
}

/**
 * Simple in-memory key-value store that satisfies the StoreScope interface
 * expected by some Activepieces actions.
 */
function createInMemoryStore() {
  const data = new Map();
  return {
    put: async (key, value) => {
      data.set(key, value);
    },
    get: async (key) => {
      return data.get(key) ?? null;
    },
    delete: async (key) => {
      data.delete(key);
    },
  };
}

/**
 * Execute a piece action.
 *
 * @param {string} pieceName - Short name of the piece (e.g. "slack")
 * @param {string} actionName - Name of the action within the piece
 * @param {object} input - Input props for the action
 * @param {any} auth - Auth credentials
 * @param {number} [timeoutMs=30000] - Execution timeout in ms
 * @returns {Promise<{ success: boolean, output?: any, duration_ms: number, error?: string }>}
 */
async function executePieceAction(pieceName, actionName, input, auth, timeoutMs) {
  const piece = loadPiece(pieceName);
  if (!piece) {
    return {
      success: false,
      output: null,
      duration_ms: 0,
      error: `Piece "${pieceName}" not found or failed to load`,
    };
  }

  const action = piece.actions && piece.actions[actionName];
  if (!action) {
    const available = piece.actions ? Object.keys(piece.actions) : [];
    return {
      success: false,
      output: null,
      duration_ms: 0,
      error: `Action "${actionName}" not found in piece "${pieceName}". Available: ${available.join(', ')}`,
    };
  }

  if (typeof action.run !== 'function') {
    return {
      success: false,
      output: null,
      duration_ms: 0,
      error: `Action "${actionName}" does not have a run() method`,
    };
  }

  try {
    const { result, duration_ms } = await withTimeout(async ({ signal }) => {
      const context = buildContext(auth, input, signal);
      return await action.run(context);
    }, timeoutMs);

    return {
      success: true,
      output: result ?? null,
      duration_ms,
    };
  } catch (err) {
    logger.error(
      { piece: pieceName, action: actionName, err: err.message },
      'Action execution failed'
    );

    return {
      success: false,
      output: null,
      duration_ms: 0,
      error: err.message,
    };
  }
}

module.exports = { executePieceAction };
