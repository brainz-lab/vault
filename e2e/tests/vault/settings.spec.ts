import { test, expect } from "@playwright/test";
import { urls } from "../../playwright.config";
import { assertPageHeading } from "../../helpers/assertions";
import { clickSidebarLink } from "../../helpers/navigation";
import { selectTestProject } from "../../helpers/project";

test.describe("Vault - Project Settings", { tag: "@feature" }, () => {
  test.beforeEach(async ({ page }) => {
    await page.goto(`${urls.vault}/dashboard`);
    await page.waitForLoadState("networkidle");
    await selectTestProject(page);
    await clickSidebarLink(page, "Project Settings");
  });

  test("displays page heading", async ({ page }) => {
    await assertPageHeading(page, "Project Settings");
  });

  test("shows back link to project", async ({ page }) => {
    await expect(
      page.getByRole("link", { name: /back to/i }),
    ).toBeVisible();
  });

  test("shows Project Name field", async ({ page }) => {
    const nameField = page.getByLabel("Project Name");
    await expect(nameField).toBeVisible();
  });

  test("Project Name field has current project name", async ({ page }) => {
    const nameField = page.getByLabel("Project Name");
    await expect(nameField).not.toBeEmpty();
  });

  test("shows Platform Project ID field", async ({ page }) => {
    const idField = page.getByLabel(/Platform Project ID/);
    await expect(idField).toBeVisible();
  });

  test("shows Save Changes button", async ({ page }) => {
    await expect(
      page.getByRole("button", { name: "Save Changes" }),
    ).toBeVisible();
  });

  test("shows Cancel link", async ({ page }) => {
    await expect(
      page.getByRole("link", { name: "Cancel" }),
    ).toBeVisible();
  });

  test("Danger Zone: shows section heading", async ({ page }) => {
    await expect(
      page.getByRole("heading", { name: "Danger Zone" }),
    ).toBeVisible();
  });

  test("Danger Zone: shows warning about permanent deletion", async ({ page }) => {
    await expect(
      page.getByText(/permanently remove all secrets/i),
    ).toBeVisible();
  });

  test("Danger Zone: shows Delete Project button", async ({ page }) => {
    await expect(
      page.getByRole("button", { name: "Delete Project" }),
    ).toBeVisible();
  });
});
