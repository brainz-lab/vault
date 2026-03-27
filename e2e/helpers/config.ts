/**
 * Shared test configuration constants.
 *
 * TEST_PROJECT_NAME controls which project specs interact with.
 * - Local dev:  defaults to "My App"
 * - Staging CI: set TEST_PROJECT_NAME="E2E Test Project" in env
 */
export const TEST_PROJECT_NAME =
  process.env.TEST_PROJECT_NAME || "My App";
