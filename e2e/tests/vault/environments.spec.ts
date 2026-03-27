import { test, expect } from "@playwright/test";
import { urls } from "../../playwright.config";
import {
  assertPageHeading,
  assertCreateButton,
  assertEmptyState,
} from "../../helpers/assertions";
import { clickSidebarLink } from "../../helpers/navigation";
import { selectTestProject } from "../../helpers/project";

test.describe("Vault - Environments", { tag: "@feature" }, () => {
  test.beforeEach(async ({ page }) => {
    await page.goto(`${urls.vault}/dashboard`);
    await page.waitForLoadState("networkidle");
    await selectTestProject(page);
    await clickSidebarLink(page, "Environments");
  });

  test("displays page heading", async ({ page }) => {
    await assertPageHeading(
      page,
      "Environments",
      /manage secret environments/i,
    );
  });

  test("shows New Environment button", async ({ page }) => {
    await assertCreateButton(page, /New Environment/);
  });

  test("shows environments table or empty state", async ({ page }) => {
    const table = page.getByRole("table").first();
    const emptyState = page.getByText(/no environments/i).first();
    await expect(table.or(emptyState)).toBeVisible();
  });

  test("environments show status badges (Locked or Open)", async ({ page }) => {
    const table = page.locator("table").first();
    const hasTable = await table.isVisible().catch(() => false);
    if (hasTable) {
      // Each environment should have either a Locked or Open badge
      const lockedBadge = page.getByText("Locked").first();
      const openBadge = page.getByText("Open").first();
      const hasLocked = await lockedBadge.isVisible().catch(() => false);
      const hasOpen = await openBadge.isVisible().catch(() => false);
      expect(hasLocked || hasOpen).toBeTruthy();
    }
  });

  test("shows View secrets links for each environment", async ({ page }) => {
    const table = page.locator("table").first();
    const hasTable = await table.isVisible().catch(() => false);
    if (hasTable) {
      await expect(page.getByText("View secrets").first()).toBeVisible();
    }
  });

  test("shows Edit link for environments", async ({ page }) => {
    const table = page.locator("table").first();
    const hasTable = await table.isVisible().catch(() => false);
    if (hasTable) {
      await expect(page.getByText("Edit").first()).toBeVisible();
    }
  });

  test("shows Environment Inheritance info section", async ({ page }) => {
    const table = page.locator("table").first();
    const hasTable = await table.isVisible().catch(() => false);
    if (hasTable) {
      await expect(
        page.getByText("Environment Inheritance"),
      ).toBeVisible();
    }
  });

  test("empty state shows New Environment action", async ({ page }) => {
    const emptyState = page.getByRole("heading", { name: /no environments/i });
    const isEmpty = await emptyState.isVisible().catch(() => false);
    if (isEmpty) {
      await expect(
        page.getByRole("link", { name: /New Environment/ }),
      ).toBeVisible();
    }
  });
});
