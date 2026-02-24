'use strict';

const { loadPiece } = require('./piece-loader');
const { withTimeout } = require('../utils/timeout');
const logger = require('../utils/logger');

/**
 * Auth types supported by Activepieces connectors.
 */
const AUTH_TYPES = {
  NONE: 'NONE',
  SECRET_TEXT: 'SECRET_TEXT',
  BASIC: 'BASIC',
  CUSTOM_AUTH: 'CUSTOM_AUTH',
  OAUTH2: 'OAUTH2',
};

/**
 * Validate auth credentials for a given piece.
 *
 * If the piece's auth definition includes a `validate` method, it will be
 * called with the provided credentials. Otherwise we do basic structural
 * validation based on the auth type.
 *
 * @param {string} pieceName - Short piece name
 * @param {any} auth - The auth credentials to validate
 * @returns {Promise<{ valid: boolean, error?: string }>}
 */
async function validateAuth(pieceName, auth) {
  const piece = loadPiece(pieceName);
  if (!piece) {
    return { valid: false, error: `Piece "${pieceName}" not found or failed to load` };
  }

  const pieceAuth = piece.auth;

  // If the piece has no auth requirement, any input is fine
  if (!pieceAuth || pieceAuth.type === AUTH_TYPES.NONE) {
    return { valid: true };
  }

  // Structural validation based on auth type
  const structureError = validateStructure(pieceAuth, auth);
  if (structureError) {
    return { valid: false, error: structureError };
  }

  // If the piece provides a custom validate function, run it
  if (typeof pieceAuth.validate === 'function') {
    try {
      const { result } = await withTimeout(async () => {
        return await pieceAuth.validate({
          auth,
        });
      }, 15_000);

      // validate() may return { valid: boolean, error?: string }
      // or it may throw on failure
      if (result && typeof result === 'object') {
        if (result.valid === false) {
          return { valid: false, error: result.error || 'Validation failed' };
        }
        return { valid: true };
      }

      // If it returned without error, treat as valid
      return { valid: true };
    } catch (err) {
      logger.warn(
        { piece: pieceName, err: err.message },
        'Auth validation threw an error'
      );
      return { valid: false, error: `Validation error: ${err.message}` };
    }
  }

  // No validate function: if structure is OK, assume valid
  return { valid: true };
}

/**
 * Check that the provided auth object has the expected structure for the
 * declared auth type.
 *
 * @returns {string|null} Error message or null if valid
 */
function validateStructure(pieceAuth, auth) {
  if (auth === null || auth === undefined) {
    if (pieceAuth.required !== false) {
      return 'Auth credentials are required for this piece';
    }
    return null;
  }

  switch (pieceAuth.type) {
    case AUTH_TYPES.SECRET_TEXT: {
      if (typeof auth !== 'string' && typeof auth !== 'object') {
        return 'SECRET_TEXT auth must be a string or object with a value field';
      }
      if (typeof auth === 'object' && !auth.value && auth.value !== '') {
        return 'SECRET_TEXT auth object must have a "value" field';
      }
      break;
    }

    case AUTH_TYPES.BASIC: {
      if (typeof auth !== 'object') {
        return 'BASIC auth must be an object with username and password fields';
      }
      if (!auth.username) {
        return 'BASIC auth requires a "username" field';
      }
      if (!auth.password && auth.password !== '') {
        return 'BASIC auth requires a "password" field';
      }
      break;
    }

    case AUTH_TYPES.OAUTH2: {
      if (typeof auth !== 'object') {
        return 'OAUTH2 auth must be an object';
      }
      if (!auth.access_token) {
        return 'OAUTH2 auth requires an "access_token" field';
      }
      break;
    }

    case AUTH_TYPES.CUSTOM_AUTH: {
      if (typeof auth !== 'object') {
        return 'CUSTOM_AUTH must be an object';
      }
      // Validate that required custom props are present
      if (pieceAuth.props) {
        for (const [key, prop] of Object.entries(pieceAuth.props)) {
          if (prop && prop.required && (auth[key] === undefined || auth[key] === null)) {
            return `CUSTOM_AUTH is missing required field: "${key}"`;
          }
        }
      }
      break;
    }

    case AUTH_TYPES.NONE:
      break;

    default:
      // Unknown auth type - no structural validation
      break;
  }

  return null;
}

module.exports = { validateAuth, AUTH_TYPES };
