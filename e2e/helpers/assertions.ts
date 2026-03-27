import { type Page, type Locator, expect } from "@playwright/test";

/**
 * Assert a metrics card displays the expected label and value.
 */
export async function assertMetricCard(
  page: Page,
  label: string,
  expectedValue?: string | RegExp,
): Promise<void> {
  const card = page.locator(`text=${label}`).locator("..");
  await expect(card).toBeVisible();
  if (expectedValue) {
    await expect(card).toContainText(expectedValue);
  }
}

/**
 * Assert an empty state is shown with expected heading text.
 */
export async function assertEmptyState(
  page: Page,
  headingText: string | RegExp,
): Promise<void> {
  await expect(
    page.getByRole("heading", { name: headingText }),
  ).toBeVisible();
}

/**
 * Assert page heading and optional subtitle.
 */
export async function assertPageHeading(
  page: Page,
  heading: string | RegExp,
  subtitle?: string | RegExp,
): Promise<void> {
  await expect(
    page.getByRole("heading", { level: 1, name: heading }),
  ).toBeVisible();
  if (subtitle) {
    await expect(page.getByText(subtitle)).toBeVisible();
  }
}

/**
 * Assert a "New/Create" action button is visible.
 */
export async function assertCreateButton(
  page: Page,
  name: string | RegExp,
): Promise<Locator> {
  const btn = page.getByRole("link", { name });
  await expect(btn).toBeVisible();
  return btn;
}

/**
 * Assert tab navigation with expected tab names.
 */
export async function assertTabs(
  page: Page,
  tabNames: string[],
): Promise<void> {
  for (const tab of tabNames) {
    await expect(page.getByRole("link", { name: tab })).toBeVisible();
  }
}

/**
 * Assert time range selector buttons.
 */
export async function assertTimeRangeSelector(
  page: Page,
  ranges: string[] = ["1h", "6h", "24h", "7d", "30d"],
): Promise<void> {
  for (const range of ranges) {
    await expect(page.getByRole("link", { name: range })).toBeVisible();
  }
}
