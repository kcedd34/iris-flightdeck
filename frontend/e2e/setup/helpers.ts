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
