import { expect, test } from "@playwright/test";
import { signIn } from "./setup/helpers";

// UC01 scenario 4 (FR-017, FR-017a), proven with the fixtures-only form.
test("4. Given the session expired with an unsaved edit open, when the user re-authenticates, then the same screen is restored, the typed input is preserved, and any computed difference is recomputed before confirmation", async ({ page, context }) => {
  await signIn(page);
  await page.goto("__fixtures__/reauth");
  const input = page.getByTestId("fixture-input");
  await input.fill("draft text");
  await expect(page.getByTestId("fixture-apply")).toBeEnabled();

  await context.clearCookies();
  await page.getByRole("button", { name: "Check server" }).click();
  const overlay = page.getByRole("dialog", { name: "Your session expired" });
  await expect(overlay).toBeVisible();
  await expect(input).toHaveValue("draft text");

  await overlay.locator('input[name="password"]').fill("SYS");
  await overlay.getByRole("button", { name: "Continue" }).click();
  await expect(overlay).toBeHidden();
  await expect(page.getByTestId("fixture-recomputed")).toHaveText("Differences recomputed");
  await expect(input).toHaveValue("draft text");
  await expect(page.getByTestId("fixture-apply")).toBeEnabled();
  expect(new URL(page.url()).pathname).toBe("/flightdeck/__fixtures__/reauth");
});
