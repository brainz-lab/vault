import { test, expect } from "@playwright/test";
import { urls } from "../../playwright.config";
import { assertPageHeading } from "../../helpers/assertions";
import { clickSidebarLink } from "../../helpers/navigation";
import { selectTestProject } from "../../helpers/project";

test.describe("Vault - MCP Setup", { tag: "@feature" }, () => {
  test.beforeEach(async ({ page }) => {
    await page.goto(`${urls.vault}/dashboard`);
    await page.waitForLoadState("networkidle");
    await selectTestProject(page);
    await clickSidebarLink(page, "MCP Setup");
  });

  test("displays page heading", async ({ page }) => {
    await assertPageHeading(
      page,
      "MCP Setup",
      "Connect Vault to Claude Desktop or Cursor",
    );
  });

  test("shows API Key section", async ({ page }) => {
    await expect(
      page.getByRole("heading", { name: "API Key" }),
    ).toBeVisible();
  });

  test("shows API key value in code block", async ({ page }) => {
    await expect(page.locator("code").first()).toBeVisible();
  });

  test("shows Copy button for API key", async ({ page }) => {
    await expect(
      page.getByRole("button", { name: "Copy" }),
    ).toBeVisible();
  });

  test("shows Regenerate button", async ({ page }) => {
    await expect(
      page.getByRole("button", { name: "Regenerate" }),
    ).toBeVisible();
  });

  test("shows Claude Desktop Configuration section", async ({ page }) => {
    await expect(
      page.getByRole("heading", { name: "Claude Desktop Configuration" }),
    ).toBeVisible();
  });

  test("shows Claude Desktop config file path", async ({ page }) => {
    await expect(
      page.getByText("~/.config/claude-desktop/config.json"),
    ).toBeVisible();
  });

  test("shows Cursor Configuration section", async ({ page }) => {
    await expect(
      page.getByRole("heading", { name: "Cursor Configuration" }),
    ).toBeVisible();
  });

  test("shows Cursor config file path", async ({ page }) => {
    await expect(
      page.getByText("~/.cursor/mcp.json"),
    ).toBeVisible();
  });

  test("shows Available MCP Tools section", async ({ page }) => {
    await expect(
      page.getByRole("heading", { name: "Available MCP Tools" }),
    ).toBeVisible();
  });

  test("lists vault_list_secrets tool", async ({ page }) => {
    await expect(page.getByText("vault_list_secrets")).toBeVisible();
  });

  test("lists vault_get_secret tool", async ({ page }) => {
    await expect(page.getByText("vault_get_secret")).toBeVisible();
  });

  test("lists vault_set_secret tool", async ({ page }) => {
    await expect(page.getByText("vault_set_secret")).toBeVisible();
  });

  test("lists vault_delete_secret tool", async ({ page }) => {
    await expect(page.getByText("vault_delete_secret")).toBeVisible();
  });

  test("lists vault_list_environments tool", async ({ page }) => {
    await expect(page.getByText("vault_list_environments")).toBeVisible();
  });

  test("lists vault_export tool", async ({ page }) => {
    await expect(page.getByText("vault_export")).toBeVisible();
  });

  test("lists vault_import tool", async ({ page }) => {
    await expect(page.getByText("vault_import")).toBeVisible();
  });
});
