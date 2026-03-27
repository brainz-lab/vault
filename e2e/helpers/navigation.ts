import { type Page, expect } from "@playwright/test";
import { urls } from "../playwright.config";

type Service = keyof typeof urls;

/**
 * Navigate to a Layer 0 service via Platform's "My App" project page.
 * This is the reliable SSO handoff path: Platform > My App > Open <Service>.
 */
export async function openServiceViaProject(
  page: Page,
  service: Service,
): Promise<void> {
  // Go to Platform projects
  await page.goto(`${urls.platform}/dashboard`);
  await page.waitForLoadState("networkidle");

  // Click "My App" project link if not already there
  const projectLink = page.getByRole("link", { name: /my app/i });
  if (await projectLink.isVisible()) {
    await projectLink.click();
    await page.waitForLoadState("networkidle");
  }

  // Find and click the "Open <Service>" button
  const serviceName = service.charAt(0).toUpperCase() + service.slice(1);
  const openButton = page.getByRole("link", {
    name: new RegExp(`open ${serviceName}`, "i"),
  });
  await openButton.click();

  // Wait for the service page to load (may open in same or new tab)
  await page.waitForURL(`**/${service}**`, { timeout: 30_000 });
  await page.waitForLoadState("networkidle");
}

/**
 * Navigate directly to a service URL (works when auth cookies are shared).
 */
export async function navigateToService(
  page: Page,
  service: Service,
  path = "/dashboard",
): Promise<void> {
  await page.goto(`${urls[service]}${path}`);
  await page.waitForLoadState("networkidle");
}

/**
 * Assert sidebar navigation is visible with expected links.
 */
export async function assertSidebarLinks(
  page: Page,
  expectedLinks: string[],
): Promise<void> {
  const nav = page.getByRole("navigation");
  for (const linkName of expectedLinks) {
    await expect(nav.getByRole("link", { name: linkName })).toBeVisible();
  }
}

/**
 * Click a sidebar navigation link and wait for page load.
 */
export async function clickSidebarLink(
  page: Page,
  linkName: string,
): Promise<void> {
  await page.getByRole("navigation").getByRole("link", { name: linkName }).click();
  await page.waitForLoadState("networkidle");
}
