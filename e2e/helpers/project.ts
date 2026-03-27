import { type Page } from "@playwright/test";
import { TEST_PROJECT_NAME } from "./config";

/**
 * Select the test project in a project-scoped service dashboard.
 *
 * Many BrainzLab services scope data by project. After navigating to
 * a service dashboard the user may land on a project list or already
 * be inside a project. This helper clicks the test project link if
 * visible, making specs resilient to both states.
 */
export async function selectTestProject(page: Page): Promise<void> {
  const projectLink = page.getByRole("link", {
    name: new RegExp(TEST_PROJECT_NAME, "i"),
  });
  if (await projectLink.isVisible().catch(() => false)) {
    await projectLink.click();
    await page.waitForLoadState("networkidle");
  }
}
