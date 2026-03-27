import { test, expect } from "@playwright/test";
import { urls } from "../../playwright.config";
import { assertPageHeading } from "../../helpers/assertions";
import { clickSidebarLink } from "../../helpers/navigation";
import { selectTestProject } from "../../helpers/project";

test.describe("Vault - Provider Keys", { tag: "@feature" }, () => {
  test.beforeEach(async ({ page }) => {
    await page.goto(`${urls.vault}/dashboard`);
    await page.waitForLoadState("networkidle");
    await selectTestProject(page);
    await clickSidebarLink(page, "Provider Keys");
  });

  test("displays page heading", async ({ page }) => {
    await assertPageHeading(
      page,
      "Provider Keys",
      /api keys for ai providers/i,
    );
  });

  test("shows Add Global Key button", async ({ page }) => {
    await expect(
      page.getByRole("link", { name: /Add Global Key/ }),
    ).toBeVisible();
  });

  test("shows Add Project Key button", async ({ page }) => {
    await expect(
      page.getByRole("link", { name: /Add Project Key/ }),
    ).toBeVisible();
  });

  test("shows Global Keys section", async ({ page }) => {
    await expect(page.getByRole("heading", { name: "Global Keys", level: 2 })).toBeVisible();
  });

  test("shows Project Keys section", async ({ page }) => {
    await expect(page.getByRole("heading", { name: /Project Keys/, level: 2 })).toBeVisible();
  });

  test("shows global keys table or empty state", async ({ page }) => {
    const globalTable = page.locator("table").first();
    const hasTable = await globalTable.isVisible().catch(() => false);
    if (hasTable) {
      await expect(page.getByText("Name").first()).toBeVisible();
      await expect(page.getByText("Provider").first()).toBeVisible();
    } else {
      await expect(
        page.getByText("No global provider keys configured"),
      ).toBeVisible();
    }
  });

  test("shows How Provider Keys Work section", async ({ page }) => {
    await expect(
      page.getByText("How Provider Keys Work"),
    ).toBeVisible();
  });

  test("explains resolution order in info section", async ({ page }) => {
    await expect(
      page.getByText(/resolution order/i),
    ).toBeVisible();
  });
});
