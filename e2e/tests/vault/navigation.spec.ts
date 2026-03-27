import { test, expect } from "@playwright/test";
import { urls } from "../../playwright.config";
import { assertSidebarLinks, clickSidebarLink } from "../../helpers/navigation";
import { TEST_PROJECT_NAME } from "../../helpers/config";
import { selectTestProject } from "../../helpers/project";

const VAULT_SIDEBAR_LINKS = [
  "Overview",
  "Secrets",
  "Environments",
  "Access Tokens",
  "Audit Log",
  "Connectors",
  "Provider Keys",
  "Project Settings",
  "MCP Setup",
  "SSH Keys",
  "AI Assistant",
];

test.describe("Vault - Navigation", { tag: "@smoke" }, () => {
  test.beforeEach(async ({ page }) => {
    await page.goto(`${urls.vault}/dashboard`);
    await page.waitForLoadState("networkidle");
    await selectTestProject(page);
  });

  test("sidebar displays all navigation links", async ({ page }) => {
    await assertSidebarLinks(page, VAULT_SIDEBAR_LINKS);
  });

  test("sidebar shows Vault branding", async ({ page }) => {
    await expect(page.getByRole("link", { name: "Fluyenta Vault" })).toBeVisible();
  });

  test("sidebar shows project name", async ({ page }) => {
    await expect(
      page.getByRole("link", { name: new RegExp(TEST_PROJECT_NAME, "i") }),
    ).toBeVisible();
  });

  test("'All Products' link is visible", async ({ page }) => {
    const link = page.getByRole("link", { name: "All Products" });
    await expect(link).toBeVisible();
    await expect(link).toHaveAttribute(
      "href",
      expect.stringContaining("platform"),
    );
  });

  for (const linkName of VAULT_SIDEBAR_LINKS) {
    test(`navigates to ${linkName} page`, async ({ page }) => {
      await clickSidebarLink(page, linkName);
      await expect(page.getByRole("heading", { level: 1 })).toBeVisible();
    });
  }
});
