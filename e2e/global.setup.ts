import { test as setup, expect } from "@playwright/test";
import { urls } from "./playwright.config";

const AUTH_FILE = "playwright/.auth/user.json";

setup("authenticate via Platform SSO", async ({ page }) => {
  // Navigate to Platform login
  await page.goto(`${urls.platform}/login`);

  // Fill credentials
  await page.getByLabel("Email").fill(process.env.TEST_EMAIL || "jolmos@runmyprocess.com");
  await page.getByLabel("Password").fill(process.env.TEST_PASSWORD || "");

  // Submit login form and wait for navigation
  await Promise.all([
    page.waitForURL("**/dashboard**", { timeout: 30_000 }),
    page.getByRole("button", { name: /sign in/i }).click(),
  ]);
  await page.waitForLoadState("networkidle");

  // Save auth state
  await page.context().storageState({ path: AUTH_FILE });
});
