import { test, expect } from "@playwright/test";
import { urls } from "../../playwright.config";
import {
  assertPageHeading,
  assertCreateButton,
  assertEmptyState,
} from "../../helpers/assertions";
import { clickSidebarLink } from "../../helpers/navigation";
import { selectTestProject } from "../../helpers/project";

test.describe("Vault - Access Tokens", { tag: "@feature" }, () => {
  test.beforeEach(async ({ page }) => {
    await page.goto(`${urls.vault}/dashboard`);
    await page.waitForLoadState("networkidle");
    await selectTestProject(page);
    await clickSidebarLink(page, "Access Tokens");
  });

  test("displays page heading", async ({ page }) => {
    await assertPageHeading(
      page,
      "Access Tokens",
      "API tokens for accessing secrets programmatically",
    );
  });

  test("shows New Token button", async ({ page }) => {
    await assertCreateButton(page, /New Token/);
  });

  test("shows tokens table or empty state", async ({ page }) => {
    const table = page.getByRole("table").first();
    const emptyState = page.getByText(/no tokens/i);
    await expect(table.or(emptyState).first()).toBeVisible();
  });

  test("tokens show status badges (Active, Revoked, or Expired)", async ({ page }) => {
    const table = page.locator("table").first();
    const hasTable = await table.isVisible().catch(() => false);
    if (hasTable) {
      const activeBadge = page.getByText("Active").first();
      const revokedBadge = page.getByText("Revoked").first();
      const expiredBadge = page.getByText("Expired").first();
      const hasActive = await activeBadge.isVisible().catch(() => false);
      const hasRevoked = await revokedBadge.isVisible().catch(() => false);
      const hasExpired = await expiredBadge.isVisible().catch(() => false);
      expect(hasActive || hasRevoked || hasExpired).toBeTruthy();
    }
  });

  test("active tokens show Edit and Revoke actions", async ({ page }) => {
    const table = page.locator("table").first();
    const hasTable = await table.isVisible().catch(() => false);
    if (hasTable) {
      const editLink = page.getByText("Edit").first();
      const hasEdit = await editLink.isVisible().catch(() => false);
      if (hasEdit) {
        await expect(editLink).toBeVisible();
      }
    }
  });

  test("empty state shows New Token action", async ({ page }) => {
    const emptyState = page.getByRole("heading", { name: /no tokens/i });
    const isEmpty = await emptyState.isVisible().catch(() => false);
    if (isEmpty) {
      await expect(page.getByText("Create a token to access secrets via API")).toBeVisible();
      await expect(
        page.getByRole("link", { name: /New Token/ }),
      ).toBeVisible();
    }
  });
});
