import { expect, type Page } from "@playwright/test";
import { ADMIN } from "./users";

export async function signIn(page: Page, credentials = ADMIN): Promise<void> {
  await page.goto("./");
  await page.locator('input[name="username"]').fill(credentials.user);
  await page.locator('input[name="password"]').fill(credentials.password);
  await page.getByRole("button", { name: "Sign in" }).click();
  await expect(page.getByTestId("glareshield")).toBeVisible();
}

export async function disarm(page: Page): Promise<void> {
  await page.getByTestId("safe-mode-indicator").click();
  await page.getByRole("button", { name: "Turn off safe mode", exact: true }).click();
  await expect(page.getByTestId("safe-mode-indicator")).toContainText("Live — changes enabled");
}

export async function setTheme(page: Page, theme: "dark" | "light"): Promise<void> {
  const current = await page.evaluate(() => document.documentElement.getAttribute("data-theme"));
  if (current !== theme) await page.getByRole("button", { name: `Switch to ${theme} theme` }).click();
  await expect(page.locator("html")).toHaveAttribute("data-theme", theme);
}

/**
 * One entry of the session capability map. Tests decide what an install offers by asking the map,
 * never by asking the version: a test that presumes an operation exists turns a declared
 * unavailability into a red run, which reads as a broken application.
 */
export async function capability(page: Page, operationId: string): Promise<{ operationId: string; available: boolean; declined?: boolean; reason: string | null } | undefined> {
  return page.evaluate(async (id) => {
    const map = await fetch("/api/flightdeck/v1/session/capabilities", { headers: { "X-FlightDeck-Tab": "e2e" } });
    return ((await map.json()) as { entries: { operationId: string; available: boolean; declined?: boolean; reason: string | null }[] }).entries.find((e) => e.operationId === id);
  }, operationId);
}
