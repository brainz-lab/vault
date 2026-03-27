import { test, expect } from "@playwright/test";
import { urls } from "../../playwright.config";
import {
  assertPageHeading,
  assertEmptyState,
} from "../../helpers/assertions";
import { clickSidebarLink } from "../../helpers/navigation";
import { selectTestProject } from "../../helpers/project";

test.describe("Vault - Secrets", { tag: "@feature" }, () => {
  test.beforeEach(async ({ page }) => {
    await page.goto(`${urls.vault}/dashboard`);
    await page.waitForLoadState("networkidle");
    await selectTestProject(page);
    await clickSidebarLink(page, "Secrets");
  });

  test("displays page heading", async ({ page }) => {
    await assertPageHeading(
      page,
      "Secrets",
      /manage encrypted secrets/i,
    );
  });

  test("shows New Secret button", async ({ page }) => {
    await expect(
      page.getByRole("link", { name: /New Secret/ }).first(),
    ).toBeVisible();
  });

  test("shows search input", async ({ page }) => {
    await expect(
      page.getByPlaceholder("Search secrets..."),
    ).toBeVisible();
  });

  test("shows type filter dropdown", async ({ page }) => {
    const typeDropdown = page.locator("select").filter({ hasText: "All Types" });
    await expect(typeDropdown).toBeVisible();
  });

  test("type filter includes expected options", async ({ page }) => {
    const typeSelect = page.locator("select").filter({ hasText: "All Types" });
    for (const typeName of ["Credentials", "TOTP", "HOTP", "String", "JSON", "File", "Certificate"]) {
      await expect(typeSelect.locator(`option:text("${typeName}")`)).toBeAttached();
    }
  });

  test("shows Search button", async ({ page }) => {
    await expect(
      page.getByRole("button", { name: "Search" }),
    ).toBeVisible();
  });

  test("shows environment selector button", async ({ page }) => {
    // The environment selector button shows the current environment name (e.g., "Development")
    const envButton = page.getByRole("button").filter({ hasText: /development/i });
    const hasEnvButton = await envButton.isVisible().catch(() => false);
    if (!hasEnvButton) {
      // Fallback: check for any environment name in a button
      await expect(page.getByRole("button").filter({ hasText: /production|staging|development/i })).toBeVisible();
    }
  });

  test("shows secrets table or empty state", async ({ page }) => {
    const table = page.locator("table").first();
    const hasTable = await table.isVisible().catch(() => false);
    if (hasTable) {
      await expect(page.getByText("Key").first()).toBeVisible();
      await expect(page.getByText("Type").first()).toBeVisible();
      await expect(page.getByText("Version").first()).toBeVisible();
    } else {
      await assertEmptyState(page, /no secrets/i);
    }
  });

  test("empty state shows New Secret action", async ({ page }) => {
    const emptyState = page.getByRole("heading", { name: /no secrets/i });
    const isEmpty = await emptyState.isVisible().catch(() => false);
    if (isEmpty) {
      await expect(
        page.getByRole("link", { name: /New Secret/ }),
      ).toBeVisible();
    }
  });
});
