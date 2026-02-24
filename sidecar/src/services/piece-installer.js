'use strict';

const { execSync } = require('node:child_process');
const path = require('node:path');
const logger = require('../utils/logger');
const { clearCache } = require('./piece-loader');

const ROOT_DIR = path.resolve(__dirname, '..', '..');

/**
 * Install an npm package (expected to be an @activepieces/piece-* package).
 *
 * @param {string} packageName - Full npm package name, e.g. "@activepieces/piece-slack"
 * @returns {{ success: boolean, name?: string, version?: string, error?: string }}
 */
function installPiece(packageName) {
  if (!packageName || typeof packageName !== 'string') {
    return { success: false, error: 'Package name is required' };
  }

  // Basic safety: only allow @activepieces scoped packages
  if (!packageName.startsWith('@activepieces/piece-')) {
    return {
      success: false,
      error: 'Only @activepieces/piece-* packages are allowed',
    };
  }

  const shortName = packageName.replace('@activepieces/piece-', '');

  logger.info({ packageName }, 'Installing piece package');

  try {
    execSync(`npm install ${packageName} --save --production`, {
      cwd: ROOT_DIR,
      stdio: 'pipe',
      timeout: 120_000,
      env: { ...process.env, NODE_ENV: 'production' },
    });
  } catch (err) {
    logger.error({ packageName, err: err.message }, 'npm install failed');
    return {
      success: false,
      error: `npm install failed: ${err.stderr ? err.stderr.toString().split('\n')[0] : err.message}`,
    };
  }

  // Clear any cached version so the new one loads fresh
  clearCache(shortName);

  // Clear Node require cache for the package so the fresh install is picked up
  clearRequireCache(packageName);

  // Verify it can be loaded
  let version = 'unknown';
  try {
    const pkgJsonPath = require.resolve(`${packageName}/package.json`);
    const pkgJson = require(pkgJsonPath);
    version = pkgJson.version || 'unknown';
  } catch {
    // If we can't read the version, still treat as success
  }

  // Verify the piece actually loads
  try {
    require(packageName);
  } catch (err) {
    logger.warn({ packageName, err: err.message }, 'Package installed but failed to load');
    return {
      success: false,
      name: shortName,
      version,
      error: `Package installed but failed to load: ${err.message}`,
    };
  }

  logger.info({ packageName, version }, 'Piece installed successfully');

  return {
    success: true,
    name: shortName,
    version,
  };
}

/**
 * Check if a piece package is installed and can be required.
 *
 * @param {string} name - Short piece name (e.g. "slack") or full package name
 * @returns {boolean}
 */
function isInstalled(name) {
  const packageName = name.startsWith('@activepieces/')
    ? name
    : `@activepieces/piece-${name}`;

  try {
    require.resolve(packageName);
    return true;
  } catch {
    return false;
  }
}

/**
 * Remove all entries from Node's require cache that match the given package name.
 * This ensures a freshly installed version is picked up on next require().
 */
function clearRequireCache(packageName) {
  const prefix = path.join('node_modules', packageName.replace('/', path.sep));
  for (const key of Object.keys(require.cache)) {
    if (key.includes(prefix)) {
      delete require.cache[key];
    }
  }
}

module.exports = { installPiece, isInstalled };
