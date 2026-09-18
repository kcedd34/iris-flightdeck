import { expect, test } from "@playwright/test";
import { signIn } from "./setup/helpers";

// docs/prd.md UC02 scenarios (translated), alternate flows A1 and A4, SC-004 and SC-010.

test("1. Given the user is on any screen, when they press Ctrl+K, then the palette opens with focus in the search field (under 100 ms)", async ({ page }) => {
  await signIn(page);
  for (const route of ["./", "security/tls", "permissions/roles?inspect=Role%3AFD_Demo_Operator"]) {
    await page.goto(route);
    await expect(page.getByTestId("glareshield")).toBeVisible();
    await page.keyboard.press("Control+k");
    await expect(page.getByTestId("palette-input")).toBeFocused();
    const ms = await page.evaluate(() => performance.measure("palette", "palette-open", "palette-input-focused").duration);
    expect(ms).toBeLessThan(100);
    await page.keyboard.press("Escape");
    await expect(page.getByTestId("command-palette")).toHaveCount(0);
  }
});

test("2. Given the term matches entities of different domains, when results show, then they are grouped by domain with disambiguating context", async ({ page }) => {
  await signIn(page);
  await page.keyboard.press("Control+k");
  await page.getByTestId("palette-input").fill("FD_Demo");
  const palette = page.getByTestId("command-palette");
  const expected: [string, string, string][] = [
    ["Web applications and APIs", "/csp/fd-demo", "Web application"],
    ["Permissions", "FD_Demo_Operator", "Role"],
    ["Permissions", "FD_Demo_Billing", "Resource"],
    ["Security and secrets", "FD_Demo_Vault", "Wallet collection"],
    ["Tasks", "FD Demo failing task", "Task"],
  ];
  for (const [heading, name, context] of expected) {
    const group = palette.locator("[cmdk-group]").filter({ has: page.locator("[cmdk-group-heading]", { hasText: heading }) });
    // The first line of a row is the entity name; match it exactly (/csp/fd-demo vs /csp/fd-demo-reports).
    const row = group.locator("[cmdk-item]").filter({ has: page.getByText(name, { exact: true }) });
    await expect(row).toBeVisible();
    await expect(row).toContainText(context);
  }
  // Feature 003 added the demo role chain (FD_Demo_L1 to L3) to the same prefix.
  await expect(palette).toContainText("13 results");
});

test("3. Given entity search is unavailable, when the user types, then local actions are still offered and the unavailability is signaled", async ({ page }) => {
  await signIn(page);
  await page.route("**/api/flightdeck/v1/palette/entities**", (route) => route.fulfill({ status: 500, body: "boom" }));
  await page.keyboard.press("Control+k");
  await page.getByTestId("palette-input").fill("tasks");
  await expect(page.getByTestId("palette-unavailable")).toHaveText("Entity search is unavailable right now. Portal actions are still available.");
  await page.locator("[cmdk-item]", { hasText: "Go to Tasks / Tasks" }).click();
  await expect(page).toHaveURL(/\/flightdeck\/tasks\/tasks$/);
});

test("4. Given safe mode is armed, when the user selects a mutating action, then the system offers to disarm before executing", async ({ page }) => {
  await signIn(page);
  await page.keyboard.press("Control+k");
  await page.getByTestId("palette-input").fill("delete a role");
  await expect(page.locator("[cmdk-item]", { hasText: "Delete a role" })).toBeVisible();
  await page.keyboard.press("Enter");
  await expect(page.getByText("Safe mode is on. Turn it off to make changes in this tab.")).toBeVisible();
  await expect(page).toHaveURL(/\/flightdeck\/$/);
  await page.getByRole("button", { name: "Turn off safe mode and continue" }).click();
  await expect(page).toHaveURL(/\/flightdeck\/permissions\/users$/);
  await expect(page.getByTestId("safe-mode-indicator")).toContainText("Live — changes enabled");
});

test("A1. No match suggests searchable domains and the shortcut reference", async ({ page }) => {
  await signIn(page);
  await page.keyboard.press("Control+k");
  await page.getByTestId("palette-input").fill("zzqxnothing");
  const empty = page.getByTestId("command-palette").getByRole("status").filter({ hasText: "No matches" });
  await expect(empty).toContainText("Searchable domains: Web applications and APIs");
  await expect(empty).toContainText("Keyboard shortcuts: Ctrl+K opens this palette");
});

test("A4. More results than fit show a total and offer refinement by domain", async ({ page }) => {
  await signIn(page);
  await page.keyboard.press("Control+k");
  await page.getByTestId("palette-input").fill("go to");
  const more = page.locator("[cmdk-item]", { hasText: /more — refine to Security and secrets/ });
  await expect(more).toBeVisible();
  await expect(page.getByTestId("command-palette")).toContainText(/\d+ results/);
  await more.click();
  await expect(page.getByRole("button", { name: /Remove filter Security and secrets/ })).toBeVisible();
});

test("Selecting an entity opens its domain with the entity in the inspector, and the choice becomes a recent action", async ({ page }) => {
  await signIn(page);
  await page.keyboard.press("Control+k");
  await page.getByTestId("palette-input").fill("FD_Demo_Vault");
  await page.locator("[cmdk-item]", { hasText: "FD_Demo_Vault" }).click();
  await expect(page).toHaveURL(/\/flightdeck\/security\/wallet\?inspect=/);
  await expect(page.getByTestId("inspector")).toContainText("FD_Demo_Vault");
  await page.keyboard.press("Control+k");
  await expect(page.locator("[cmdk-group]", { hasText: "Recent" })).toContainText("FD_Demo_Vault");
});
