'use strict';

const fs = require('node:fs');
const path = require('node:path');
const logger = require('../utils/logger');

/** In-memory cache of loaded piece modules keyed by piece name */
const pieceCache = new Map();

/**
 * Resolve the actual piece export from a loaded module.
 * Activepieces packages export in varying shapes:
 *   - module.default (ESM interop)
 *   - module.<PieceName>  (named export matching the piece)
 *   - The module itself is the piece object
 *
 * A valid piece object has at minimum: displayName, actions.
 */
function resolvePieceExport(mod, name) {
  // Direct default export (most common with ESM interop)
  if (mod && mod.default && mod.default.displayName) {
    return mod.default;
  }

  // Check if the module itself is a piece
  if (mod && mod.displayName && mod.actions) {
    return mod;
  }

  // Search all named exports for something that looks like a piece
  if (mod && typeof mod === 'object') {
    for (const key of Object.keys(mod)) {
      const val = mod[key];
      if (val && typeof val === 'object' && val.displayName && val.actions) {
        return val;
      }
    }
  }

  // Some pieces export a function that returns the piece
  if (typeof mod === 'function') {
    try {
      const result = mod();
      if (result && result.displayName) {
        return result;
      }
    } catch {
      // ignore
    }
  }

  return null;
}

/**
 * Load a piece by its short name (e.g. "slack") or full package name.
 * Returns the normalized piece object or null if not found.
 */
function loadPiece(name) {
  if (pieceCache.has(name)) {
    return pieceCache.get(name);
  }

  const packageName = name.startsWith('@activepieces/')
    ? name
    : `@activepieces/piece-${name}`;

  let mod;
  try {
    mod = require(packageName);
  } catch (err) {
    logger.warn({ packageName, err: err.message }, 'Failed to require piece package');
    return null;
  }

  const piece = resolvePieceExport(mod, name);
  if (!piece) {
    logger.warn({ packageName }, 'Loaded module but could not resolve piece export');
    return null;
  }

  pieceCache.set(name, piece);

  // Also cache by short name if loaded via full package name
  const shortName = packageName.replace('@activepieces/piece-', '');
  if (shortName !== name) {
    pieceCache.set(shortName, piece);
  }

  logger.info({ name: shortName, displayName: piece.displayName }, 'Piece loaded');
  return piece;
}

/**
 * Scan node_modules for all installed @activepieces/piece-* packages.
 * Returns an array of { name, packageName } entries.
 */
function listInstalledPackages() {
  const results = [];
  const scopeDir = path.resolve(process.cwd(), 'node_modules', '@activepieces');

  if (!fs.existsSync(scopeDir)) {
    return results;
  }

  let entries;
  try {
    entries = fs.readdirSync(scopeDir, { withFileTypes: true });
  } catch {
    return results;
  }

  for (const entry of entries) {
    if (!entry.isDirectory()) continue;
    if (!entry.name.startsWith('piece-')) continue;

    // Skip internal / framework packages
    if (entry.name === 'piece-framework' || entry.name === 'pieces-common') continue;

    const shortName = entry.name.replace('piece-', '');
    results.push({
      name: shortName,
      packageName: `@activepieces/${entry.name}`,
    });
  }

  return results;
}

/**
 * Load all installed pieces and return an array of piece objects enriched
 * with the short `name` and `packageName`.
 */
function listPieces() {
  const packages = listInstalledPackages();
  const pieces = [];

  for (const { name, packageName } of packages) {
    const piece = loadPiece(name);
    if (piece) {
      pieces.push({ ...serializePiece(piece), name, packageName });
    }
  }

  return pieces;
}

/**
 * Serialize a piece object to a JSON-safe representation.
 */
function serializePiece(piece) {
  const actions = [];
  if (piece.actions && typeof piece.actions === 'object') {
    for (const [key, action] of Object.entries(piece.actions)) {
      actions.push({
        name: action.name || key,
        displayName: action.displayName || key,
        description: action.description || '',
        props: serializeProps(action.props),
      });
    }
  }

  const triggers = [];
  if (piece.triggers && typeof piece.triggers === 'object') {
    for (const [key, trigger] of Object.entries(piece.triggers)) {
      triggers.push({
        name: trigger.name || key,
        displayName: trigger.displayName || key,
        description: trigger.description || '',
        props: serializeProps(trigger.props),
      });
    }
  }

  const auth = serializeAuth(piece.auth);

  return {
    displayName: piece.displayName || '',
    description: piece.description || '',
    logoUrl: piece.logoUrl || '',
    minimumSupportedRelease: piece.minimumSupportedRelease || '',
    maximumSupportedRelease: piece.maximumSupportedRelease || '',
    version: piece.version || '',
    authors: piece.authors || [],
    auth,
    actions,
    triggers,
  };
}

/**
 * Serialize prop definitions to plain objects.
 */
function serializeProps(props) {
  if (!props || typeof props !== 'object') return {};

  const out = {};
  for (const [key, prop] of Object.entries(props)) {
    if (!prop) continue;
    out[key] = {
      displayName: prop.displayName || key,
      description: prop.description || '',
      type: prop.type || 'UNKNOWN',
      required: !!prop.required,
    };
    if (prop.defaultValue !== undefined) {
      out[key].defaultValue = prop.defaultValue;
    }
    if (prop.options) {
      out[key].options = prop.options;
    }
  }
  return out;
}

/**
 * Serialize auth schema.
 */
function serializeAuth(auth) {
  if (!auth) return { type: 'NONE', props: {} };

  return {
    type: auth.type || 'NONE',
    displayName: auth.displayName || '',
    description: auth.description || '',
    required: auth.required !== false,
    props: serializeProps(auth.props),
  };
}

/**
 * Clear a piece from the cache (useful after installing a new version).
 */
function clearCache(name) {
  pieceCache.delete(name);
  const fullName = `@activepieces/piece-${name}`;
  pieceCache.delete(fullName);

  // Also clear from Node's require cache
  try {
    const resolvedPath = require.resolve(fullName);
    delete require.cache[resolvedPath];
  } catch {
    // not in cache
  }
}

/**
 * Return count of cached pieces.
 */
function cachedCount() {
  // Each piece may be cached under two keys (short + full name), so deduplicate
  const unique = new Set();
  for (const [key, val] of pieceCache.entries()) {
    unique.add(val.displayName || key);
  }
  return unique.size;
}

module.exports = {
  loadPiece,
  listPieces,
  listInstalledPackages,
  serializePiece,
  clearCache,
  cachedCount,
};
