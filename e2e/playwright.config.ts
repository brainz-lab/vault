import { defineConfig, devices } from "@playwright/test";

const isCI = !!process.env.CI;

const ENV = {
  staging: {
    platform: "https://platform.staging.fluyenta.com",
    vault: "https://vault.staging.fluyenta.com",
  },
  local: {
    platform: "http://localhost:3000",
    vault: "http://localhost:4006",
  },
};

const env = (process.env.TEST_ENV as "staging" | "local") || "staging";

export const urls = ENV[env];

export default defineConfig({
  testDir: "./tests",
  fullyParallel: false,
  forbidOnly: isCI,
  retries: isCI ? 2 : 0,
  workers: 1,
  reporter: isCI
    ? [["github"], ["html", { open: "never" }]]
    : [["html", { open: "on-failure" }]],
  timeout: 60_000,
  expect: { timeout: 10_000 },

  use: {
    baseURL: urls.platform,
    trace: "on-first-retry",
    screenshot: "only-on-failure",
    video: "on-first-retry",
    actionTimeout: 15_000,
    navigationTimeout: 30_000,
  },

  projects: [
    {
      name: "setup",
      testDir: ".",
      testMatch: /global\.setup\.ts/,
    },
    {
      name: "chromium",
      use: {
        ...devices["Desktop Chrome"],
        storageState: "playwright/.auth/user.json",
      },
      dependencies: ["setup"],
    },
  ],
});
