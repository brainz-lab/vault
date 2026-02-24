'use strict';

const { execSync } = require('node:child_process');
const path = require('node:path');
const fs = require('node:fs');

const PIECES_FILE = path.resolve(__dirname, '..', 'pieces.json');
const ROOT_DIR = path.resolve(__dirname, '..');

function main() {
  console.log('[install-pieces] Starting piece installation...');

  let pieces;
  try {
    const raw = fs.readFileSync(PIECES_FILE, 'utf-8');
    pieces = JSON.parse(raw);
  } catch (err) {
    console.error(`[install-pieces] Failed to read ${PIECES_FILE}: ${err.message}`);
    process.exit(1);
  }

  if (!Array.isArray(pieces) || pieces.length === 0) {
    console.warn('[install-pieces] No pieces found in pieces.json');
    return;
  }

  console.log(`[install-pieces] Found ${pieces.length} pieces to install`);

  const results = { success: [], failed: [] };

  for (const piece of pieces) {
    const pkg = piece.package;
    const name = piece.name;

    console.log(`[install-pieces] Installing ${pkg} (${name})...`);

    try {
      execSync(`npm install ${pkg} --save --production`, {
        cwd: ROOT_DIR,
        stdio: 'pipe',
        timeout: 120_000,
      });
      results.success.push(name);
      console.log(`[install-pieces]   OK: ${name}`);
    } catch (err) {
      results.failed.push({ name, error: err.message });
      console.error(`[install-pieces]   FAIL: ${name} - ${err.message}`);
    }
  }

  console.log('\n[install-pieces] Installation complete.');
  console.log(`[install-pieces]   Success: ${results.success.length}/${pieces.length}`);
  console.log(`[install-pieces]   Failed:  ${results.failed.length}/${pieces.length}`);

  if (results.failed.length > 0) {
    console.log('[install-pieces] Failed packages:');
    for (const f of results.failed) {
      console.log(`[install-pieces]   - ${f.name}: ${f.error.split('\n')[0]}`);
    }
  }
}

main();
