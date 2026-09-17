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
