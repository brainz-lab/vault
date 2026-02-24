'use strict';

const DEFAULT_TIMEOUT_MS = 30_000;
const MAX_TIMEOUT_MS = 120_000;

/**
 * Wrap a promise with an AbortController-based timeout.
 *
 * @param {Function} fn - Async function to execute. Receives { signal } as first arg.
 * @param {number} [timeoutMs] - Timeout in milliseconds.
 * @returns {Promise<{ result: any, duration_ms: number }>}
 */
async function withTimeout(fn, timeoutMs) {
  const ms = Math.min(
    Math.max(timeoutMs || DEFAULT_TIMEOUT_MS, 1),
    MAX_TIMEOUT_MS
  );

  const controller = new AbortController();
  const { signal } = controller;

  const timer = setTimeout(() => {
    controller.abort();
  }, ms);

  const start = Date.now();

  try {
    const result = await Promise.race([
      fn({ signal }),
      new Promise((_, reject) => {
        signal.addEventListener('abort', () => {
          reject(new Error(`Execution timed out after ${ms}ms`));
        });
      }),
    ]);

    const duration_ms = Date.now() - start;
    return { result, duration_ms };
  } finally {
    clearTimeout(timer);
  }
}

module.exports = { withTimeout, DEFAULT_TIMEOUT_MS, MAX_TIMEOUT_MS };
