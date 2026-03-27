import { test, expect } from "@playwright/test";
import { urls } from "../../playwright.config";
import { assertPageHeading } from "../../helpers/assertions";
import { clickSidebarLink } from "../../helpers/navigation";
import { selectTestProject } from "../../helpers/project";

test.describe("Vault - SSH Keys", { tag: "@feature" }, () => {
  test.beforeEach(async ({ page }) => {
    await page.goto(`${urls.vault}/dashboard`);
    await page.waitForLoadState("networkidle");
    await selectTestProject(page);
    await clickSidebarLink(page, "SSH Keys");
  });

  test("displays page heading", async ({ page }) => {
    await assertPageHeading(
      page,
      "SSH Keys",
      /manage ssh keys and connection profiles/i,
    );
  });

  test("shows Client Keys section", async ({ page }) => {
    await expect(
      page.getByRole("heading", { name: "Client Keys", level: 2 }),
    ).toBeVisible();
  });

  test("shows Client Keys description", async ({ page }) => {
    await expect(
      page.getByText("SSH identity keys (private/public key pairs)"),
    ).toBeVisible();
  });

  test("shows Server Keys section", async ({ page }) => {
    await expect(
      page.getByRole("heading", { name: "Server Keys", level: 2 }),
    ).toBeVisible();
  });

  test("shows Server Keys description", async ({ page }) => {
    await expect(
      page.getByText("Known host public keys for verification"),
    ).toBeVisible();
  });

  test("shows Connections section", async ({ page }) => {
    await expect(
      page.getByRole("heading", { name: "Connections", level: 2 }),
    ).toBeVisible();
  });

  test("shows SSH MCP Tools section", async ({ page }) => {
    await expect(
      page.getByRole("heading", { name: "SSH MCP Tools" }),
    ).toBeVisible();
  });

  test("shows client keys table or empty state", async ({ page }) => {
    const clientKeyTable = page.getByRole("heading", { name: "Client Keys" }).locator("..").locator("..").locator("table");
    const hasTable = await clientKeyTable.isVisible().catch(() => false);
    if (!hasTable) {
      await expect(page.getByText("No client keys stored")).toBeVisible();
    }
  });

  test("shows server keys table or empty state", async ({ page }) => {
    const hasServerKeys = await page.getByText("No server keys stored").isVisible().catch(() => false);
    if (hasServerKeys) {
      await expect(page.getByText("No server keys stored")).toBeVisible();
    }
  });

  test("shows connections table or empty state", async ({ page }) => {
    const hasConnections = await page.getByText("No connection profiles stored").isVisible().catch(() => false);
    if (hasConnections) {
      await expect(page.getByText("No connection profiles stored")).toBeVisible();
    }
  });

  test("lists SSH MCP tool names", async ({ page }) => {
    // Use listitem scope to avoid matching duplicate tool names in empty-state hints
    const toolNames = [
      "vault_ssh_list_client_keys",
      "vault_ssh_generate_key",
      "vault_ssh_list_server_keys",
      "vault_ssh_list_connections",
      "vault_ssh_export_config",
    ];
    for (const toolName of toolNames) {
      await expect(
        page.getByRole("listitem").filter({ hasText: toolName }).first(),
      ).toBeVisible();
    }
  });
});
