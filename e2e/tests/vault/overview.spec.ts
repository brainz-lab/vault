import { test, expect } from "@playwright/test";
import { urls } from "../../playwright.config";
import { assertMetricCard } from "../../helpers/assertions";
import { TEST_PROJECT_NAME } from "../../helpers/config";
import { selectTestProject } from "../../helpers/project";

test.describe("Vault - Overview", { tag: "@smoke" }, () => {
  test.beforeEach(async ({ page }) => {
    await page.goto(`${urls.vault}/dashboard`);
    await page.waitForLoadState("networkidle");
    await selectTestProject(page);
  });

  test("displays project name as page heading", async ({ page }) => {
    await expect(
      page.getByRole("heading", { level: 1, name: new RegExp(TEST_PROJECT_NAME, "i") }),
    ).toBeVisible();
  });

  test("shows Project Overview subtitle", async ({ page }) => {
    await expect(page.getByText("Project Overview")).toBeVisible();
  });

  test("displays metric cards (Total Secrets, Environments, Active Tokens, Audit Events)", async ({ page }) => {
    const main = page.getByRole("main");
    await expect(main.getByText("Total Secrets")).toBeVisible();
    await expect(main.getByText("Environments").first()).toBeVisible();
    await expect(main.getByText("Active Tokens")).toBeVisible();
    await expect(main.getByText("Audit Events")).toBeVisible();
  });

  test("shows MCP Setup button", async ({ page }) => {
    await expect(
      page.getByRole("main").getByRole("link", { name: "MCP Setup" }),
    ).toBeVisible();
  });

  test("shows Settings button", async ({ page }) => {
    await expect(
      page.getByRole("main").getByRole("link", { name: /settings/i }),
    ).toBeVisible();
  });

  test("shows Recent Secrets section", async ({ page }) => {
    await expect(
      page.getByRole("heading", { name: "Recent Secrets" }),
    ).toBeVisible();
  });

  test("shows Recent Activity section", async ({ page }) => {
    await expect(
      page.getByRole("heading", { name: "Recent Activity" }),
    ).toBeVisible();
  });

  test("shows View All link for secrets", async ({ page }) => {
    const viewAllLinks = page.getByRole("link", { name: /View All/ });
    await expect(viewAllLinks.first()).toBeVisible();
  });

  test("shows Environments section", async ({ page }) => {
    await expect(
      page.getByRole("heading", { name: "Environments" }),
    ).toBeVisible();
  });

  test("shows empty state or recent secrets list", async ({ page }) => {
    const hasSecrets = await page.getByText(/ago$/).first().isVisible().catch(() => false);
    if (!hasSecrets) {
      await expect(page.getByText("No secrets yet")).toBeVisible();
    }
  });
});
