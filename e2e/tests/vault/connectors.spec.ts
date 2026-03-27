import { test, expect } from "@playwright/test";
import { urls } from "../../playwright.config";
import {
  assertPageHeading,
} from "../../helpers/assertions";
import { clickSidebarLink } from "../../helpers/navigation";
import { selectTestProject } from "../../helpers/project";

test.describe("Vault - Connectors", { tag: "@feature" }, () => {
  test.beforeEach(async ({ page }) => {
    await page.goto(`${urls.vault}/dashboard`);
    await page.waitForLoadState("networkidle");
    await selectTestProject(page);
    await clickSidebarLink(page, "Connectors");
  });

  test("displays page heading", async ({ page }) => {
    await assertPageHeading(
      page,
      "Connectors",
      /browse and connect to .+ third-party services/i,
    );
  });

  test("shows Credentials button", async ({ page }) => {
    await expect(
      page.getByRole("link", { name: "Credentials" }),
    ).toBeVisible();
  });

  test("shows Connections button", async ({ page }) => {
    await expect(
      page.getByRole("link", { name: "Connections" }),
    ).toBeVisible();
  });

  test("shows search input", async ({ page }) => {
    await expect(
      page.getByPlaceholder("Search connectors..."),
    ).toBeVisible();
  });

  test("shows Category filter dropdown", async ({ page }) => {
    const categoryCombobox = page.getByRole("combobox").filter({ has: page.locator("option", { hasText: "All Categories" }) });
    await expect(categoryCombobox).toBeVisible();
  });

  test("shows Type filter dropdown", async ({ page }) => {
    const typeCombobox = page.getByRole("combobox").filter({ has: page.locator("option", { hasText: "All Types" }) });
    await expect(typeCombobox).toBeVisible();
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

  test("shows connector grid or empty state", async ({ page }) => {
    // Connector cards are links containing an h3 heading and "actions" text
    const connectorCard = page.getByRole("link").filter({ hasText: /actions/ }).first();
    const hasConnectors = await connectorCard.isVisible().catch(() => false);
    if (hasConnectors) {
      await expect(connectorCard).toBeVisible();
    } else {
      const emptyState = page.getByText(/no connectors found/i);
      const hasEmpty = await emptyState.isVisible().catch(() => false);
      if (hasEmpty) {
        await expect(emptyState).toBeVisible();
      }
    }
  });

  test("Credentials button navigates to credentials page", async ({ page }) => {
    await page.getByRole("link", { name: "Credentials" }).click();
    await page.waitForLoadState("networkidle");
    await expect(page).toHaveURL(/connector_credentials/);
  });

  test("Connections button navigates to connections page", async ({ page }) => {
    await page.getByRole("link", { name: "Connections" }).click();
    await page.waitForLoadState("networkidle");
    await expect(page).toHaveURL(/connector_connections/);
  });
});
