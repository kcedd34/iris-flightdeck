import { expect, test } from "@playwright/test";
import { signIn } from "./setup/helpers";
import { NO_PRIVILEGE } from "./setup/users";

// FR-012a limited mode: the reduced IRIS 2026.1 matrix. Run against a 2026.1 install with
//   FLIGHTDECK_PORT=<port> npx playwright test --project limited
// Dialect selection, the unavailable state coming from the capability map, and the limited-mode
// indicator. The 28 translations are verified by effect in the backend suite
// (FlightDeck.Test.V1Translations). On a 2026.2 install every test here is skipped.

const VERSION_MESSAGE = "Not available on this IRIS version or edition. Requires IRIS 2026.2.";

test.beforeEach(async ({ page }) => {
  const response = page.waitForResponse((r) => r.url().includes("/api/flightdeck/v1/session") && r.request().method() === "POST");
  await signIn(page);
  const session = (await (await response).json()) as { instance: { dialect: string } };
  test.skip(session.instance.dialect !== "v1", "limited mode needs an IRIS 2026.1 install");
});

test("sign-in on IRIS 2026.1 selects the v1 dialect and enters limited mode instead of refusing", async ({ page }) => {
  const again = await page.evaluate(async () => {
    const r = await fetch("/api/flightdeck/v1/session", { headers: { "X-FlightDeck-Tab": "e2e-limited" } });
    return { status: r.status, body: (await r.json()) as { instance: { dialect: string; limited: boolean; apiVersion: number }; capabilitySummary: { unavailable: number; total: number } } };
  });
  expect(again.status).toBe(200);
  expect(again.body.instance).toMatchObject({ dialect: "v1", limited: true, apiVersion: 1 });
  expect(again.body.capabilitySummary).toMatchObject({ unavailable: 72, total: 273 });
});

test("the glareshield shows a persistent limited-mode indicator, with icon and text and an accessible explanation", async ({ page }) => {
  const indicator = page.getByTestId("glareshield").getByTestId("limited-mode-indicator");
  await expect(indicator).toBeVisible();
  await expect(indicator).toContainText("Limited · API v1");
  await expect(indicator).toHaveAccessibleDescription(/72 of 273 operations are not offered by this IRIS version/);
  for (const route of ["security/tls", "system", "logs"]) {
    await page.goto(route);
    await expect(page.getByTestId("limited-mode-indicator")).toBeVisible();
  }
  expect((await page.getByTestId("glareshield").boundingBox())?.height).toBe(44);
});

test("an operation the instance does not offer is disabled in the palette with the version message; offered ones stay enabled", async ({ page }) => {
  await page.keyboard.press("Control+k");
  await page.getByTestId("palette-input").fill("create/edit a namespace");
  const unavailable = page.locator("[cmdk-item]", { hasText: "Create/Edit a namespace" });
  await expect(unavailable).toHaveAttribute("aria-disabled", "true");
  await expect(unavailable).toContainText(VERSION_MESSAGE);

  await page.getByTestId("palette-input").fill("suspend a task");
  const translated = page.locator("[cmdk-item]", { hasText: "Suspend a task" });
  await expect(translated).not.toHaveAttribute("aria-disabled", "true");
  await expect(translated).not.toContainText(VERSION_MESSAGE);
});

test("entity types the instance does not offer are named once with the version message, and offered types still return results", async ({ page }) => {
  await page.keyboard.press("Control+k");
  await page.getByTestId("palette-input").fill("FD_Demo");
  const palette = page.getByTestId("command-palette");
  await expect(palette.locator("[cmdk-item]", { hasText: "FD_Demo_Operator" })).toBeVisible();
  // One note per domain: System (namespaces, databases, ECP, ...) and Logs (journal files).
  const group = (heading: string) => palette.locator("[cmdk-group]").filter({ has: page.locator("[cmdk-group-heading]", { hasText: heading }) });
  const system = group("System").getByTestId("palette-unavailable-types");
  await expect(system).toHaveCount(1);
  await expect(system).toContainText("Namespace");
  await expect(system).toContainText("Database");
  await expect(system).toContainText(VERSION_MESSAGE);
  await expect(group("Logs").getByTestId("palette-unavailable-types")).toContainText("Journal file");
  await expect(palette.getByTestId("palette-unavailable-types")).toHaveCount(2);
  await expect(page.getByTestId("palette-unavailable")).toHaveCount(0);
});

test("home counts exclude operations the instance does not offer, and the Disk vital reads natively", async ({ page }) => {
  await expect(page.getByTestId("capability-summary")).toContainText("72 not offered by this IRIS version");
  await expect(page.getByTestId("vital-disk")).toContainText(/\d+%/);
});

test("a user without any administrative privilege is refused for privileges, not for the version, even though %SYS is unreadable", async ({ page }) => {
  await page.getByRole("button", { name: "Sign out" }).click();
  await page.locator('input[name="username"]').fill(NO_PRIVILEGE.user);
  await page.locator('input[name="password"]').fill(NO_PRIVILEGE.password);
  await page.getByRole("button", { name: "Sign in" }).click();
  await expect(page.getByRole("alert")).toContainText("Requires Use on %Admin_");
  await expect(page.getByRole("alert")).not.toContainText("Requires IRIS");
  await expect(page.getByTestId("glareshield")).toHaveCount(0);
});
