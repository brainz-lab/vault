import { test, expect } from "@playwright/test";
import { urls } from "../../playwright.config";
import {
  assertPageHeading,
  assertEmptyState,
} from "../../helpers/assertions";
import { clickSidebarLink } from "../../helpers/navigation";
import { selectTestProject } from "../../helpers/project";

test.describe("Vault - Audit Log", { tag: "@feature" }, () => {
  test.beforeEach(async ({ page }) => {
    await page.goto(`${urls.vault}/dashboard`);
    await page.waitForLoadState("networkidle");
    await selectTestProject(page);
    await clickSidebarLink(page, "Audit Log");
  });

  test("displays page heading", async ({ page }) => {
    await assertPageHeading(
      page,
      "Audit Log",
      "Track all secret access and changes",
    );
  });

  test("shows Export CSV button", async ({ page }) => {
    await expect(
      page.getByRole("link", { name: /Export CSV/ }),
    ).toBeVisible();
  });

  test("shows Action filter dropdown", async ({ page }) => {
    const actionCombobox = page.getByRole("combobox").filter({ has: page.locator("option", { hasText: "All Actions" }) });
    await expect(actionCombobox).toBeVisible();
  });

  test("Action filter includes expected options", async ({ page }) => {
    const actionSelect = page.getByRole("combobox").filter({ has: page.locator("option", { hasText: "All Actions" }) });
    for (const action of ["All Actions", "Read Secret", "Create Secret", "Update Secret", "Archive Secret"]) {
      await expect(actionSelect.locator(`option:text("${action}")`)).toBeAttached();
    }
  });

  test("shows From date filter", async ({ page }) => {
    await expect(page.getByPlaceholder("From date")).toBeVisible();
  });

  test("shows To date filter", async ({ page }) => {
    await expect(page.getByLabel("To")).toBeVisible();
  });

  test("shows Filter button", async ({ page }) => {
    await expect(
      page.getByRole("button", { name: "Filter" }),
    ).toBeVisible();
  });

  test("shows Clear filter link", async ({ page }) => {
    await expect(
      page.getByRole("link", { name: "Clear" }),
    ).toBeVisible();
  });

  test("shows audit log table or empty state", async ({ page }) => {
    const table = page.getByRole("table").first();
    const emptyState = page.getByText(/no audit logs|no logs|no entries/i).first();
    await expect(table.or(emptyState)).toBeVisible();
  });

  test("empty state shows informational message", async ({ page }) => {
    const emptyState = page.getByRole("heading", { name: /no audit logs/i });
    const isEmpty = await emptyState.isVisible().catch(() => false);
    if (isEmpty) {
      await expect(
        page.getByText("Activity will appear here once secrets are accessed"),
      ).toBeVisible();
    }
  });
});
