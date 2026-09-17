import { expect, test } from "@playwright/test";
import { disarm, signIn } from "./setup/helpers";
import { NO_PRIVILEGE, OPERATOR, adminRequest } from "./setup/users";

// FR-012a limited mode: the reduced IRIS 2026.1 matrix. Run against a 2026.1 install with
//   FLIGHTDECK_PORT=<port> npx playwright test --project limited
// Dialect selection, the unavailable state coming from the capability map, and the limited-mode
// indicator. The 28 translations are verified by effect in the backend suite
// (FlightDeck.Test.V1Translations). On a 2026.2 install every test here is skipped.

const VERSION_MESSAGE = "Not available on this IRIS version or edition. Requires IRIS 2026.2.";

test.beforeEach(async ({ page }) => {
  const response = page.waitForResponse((r) => r.url().includes("/api/flightdeck/v1/session") && r.request().method() === "POST");
  await signIn(page);
  // Decided by the capability map, never by the instance's version: limited mode means the map
  // holds operations the instance does not offer.
  const session = (await (await response).json()) as { capabilitySummary: { unavailable: number } };
  test.skip(session.capabilitySummary.unavailable === 0, "the instance offers every operation: nothing is limited");
});

type Entry = { operationId: string; available: boolean; reason: string | null };

test("sign-in succeeds in limited mode: the capability map marks what the instance does not offer, with reasons", async ({ page }) => {
  const result = await page.evaluate(async () => {
    const headers = { "X-FlightDeck-Tab": "e2e-limited" };
    const session = await fetch("/api/flightdeck/v1/session", { headers });
    const map = await fetch("/api/flightdeck/v1/session/capabilities", { headers });
    return {
      status: session.status,
      summary: ((await session.json()) as { capabilitySummary: { unavailable: number; total: number } }).capabilitySummary,
      entries: ((await map.json()) as { entries: Entry[] }).entries,
    };
  });
  expect(result.status).toBe(200);
  expect(result.summary).toMatchObject({ unavailable: 64, total: 273 });
  expect(result.entries.filter((e) => !e.available)).toHaveLength(64);
  const byId = new Map(result.entries.map((e) => [e.operationId, e]));
  expect(byId.get("GET /v2/databases")).toMatchObject({ available: false, reason: VERSION_MESSAGE });
  expect(byId.get("GET /v2/namespaces")).toMatchObject({ available: true });
  expect(byId.get("POST /v2/task/suspend")).toMatchObject({ available: true });
});

test("the glareshield shows a persistent limited-mode indicator, with icon and text and an accessible explanation", async ({ page }) => {
  const indicator = page.getByTestId("glareshield").getByTestId("limited-mode-indicator");
  await expect(indicator).toBeVisible();
  await expect(indicator).toContainText("Limited");
  await expect(indicator).not.toContainText("v1");
  await expect(indicator).toHaveAccessibleDescription(/64 of 273 operations are not offered by this IRIS version/);
  for (const route of ["security/tls", "system", "logs"]) {
    await page.goto(route);
    await expect(page.getByTestId("limited-mode-indicator")).toBeVisible();
  }
  expect((await page.getByTestId("glareshield").boundingBox())?.height).toBe(44);
});

test("an operation the instance does not offer is disabled in the palette with the version message; offered ones stay enabled", async ({ page }) => {
  await page.keyboard.press("Control+k");
  await page.getByTestId("palette-input").fill("compact a local database");
  const unavailable = page.locator("[cmdk-item]", { hasText: "Compact a local database" });
  await expect(unavailable).toHaveAttribute("aria-disabled", "true");
  await expect(unavailable).toContainText(VERSION_MESSAGE);

  // Namespace writes are withheld on purpose, and say why (constitution 2.1.0).
  await page.getByTestId("palette-input").fill("create/edit a namespace");
  const withheld = page.locator("[cmdk-item]", { hasText: "Create/Edit a namespace" });
  await expect(withheld).toHaveAttribute("aria-disabled", "true");
  await expect(withheld).toContainText(VERSION_MESSAGE);
  await expect(withheld).toContainText("a native write would copy platform side effects FlightDeck does not control");

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
  // One note per reason within a domain: System (databases, ECP, ...) and Logs (journal files, with
  // the recorded authorization reason). Namespaces are searched natively and are not listed.
  const group = (heading: string) => palette.locator("[cmdk-group]").filter({ has: page.locator("[cmdk-group-heading]", { hasText: heading }) });
  const system = group("System").getByTestId("palette-unavailable-types");
  await expect(system).toHaveCount(1);
  await expect(system).toContainText("Database");
  await expect(system).not.toContainText("Namespace");
  await expect(system).toContainText(VERSION_MESSAGE);
  const logs = group("Logs").getByTestId("palette-unavailable-types");
  await expect(logs).toContainText("Journal file");
  await expect(logs).toContainText("filtering records by the databases you can read is an authorization decision that belongs to IRIS");
  await expect(palette.getByTestId("palette-unavailable-types")).toHaveCount(2);
  await expect(page.getByTestId("palette-unavailable")).toHaveCount(0);
});

test("home counts exclude operations the instance does not offer, and the Disk vital reads natively", async ({ page }) => {
  await expect(page.getByTestId("capability-summary")).toContainText("64 not offered by this IRIS version");
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

test("namespaces are read natively on IRIS 2026.1 and found by the palette under System", async ({ page }) => {
  await page.keyboard.press("Control+k");
  await page.getByTestId("palette-input").fill("USER");
  const system = page.getByTestId("command-palette").locator("[cmdk-group]").filter({ has: page.locator("[cmdk-group-heading]", { hasText: "System" }) });
  const row = system.locator("[cmdk-item]", { hasText: "USER" }).filter({ hasText: "Namespace" });
  await expect(row.first()).toBeVisible();
});

test("for a user without the declared privilege, the namespace group is refused by the capability map (the provider's own 403 is in the backend suite)", async ({ page }) => {
  await page.getByRole("button", { name: "Sign out" }).click();
  await signIn(page, OPERATOR);
  await page.keyboard.press("Control+k");
  await page.getByTestId("palette-input").fill("USER");
  const system = page.getByTestId("command-palette").locator("[cmdk-group]").filter({ has: page.locator("[cmdk-group-heading]", { hasText: "System" }) });
  await expect(system.getByRole("note").filter({ hasText: "Namespace" })).toContainText("Requires Use on %Admin_Manage");
});

// Feature 002 (SC-013): web applications on the limited instance. Whether reads and the write are
// offered comes from the capability map only; the test follows the map, not the version.
async function capability(page: import("@playwright/test").Page, operationId: string): Promise<Entry> {
  return page.evaluate(async (id) => {
    const map = await fetch("/api/flightdeck/v1/session/capabilities", { headers: { "X-FlightDeck-Tab": "e2e-limited" } });
    return ((await map.json()) as { entries: { operationId: string; available: boolean; reason: string | null }[] }).entries.find((e) => e.operationId === id)!;
  }, operationId);
}

test("web applications are listed and inspected with exposure markers, as the capability map offers them", async ({ page }) => {
  const list = await capability(page, "GET /v2/web-apps");
  await page.goto("web-apps/web-applications");
  if (!list.available) {
    await expect(page.getByTestId("domain-list")).toContainText(list.reason!);
    return;
  }
  const row = page.getByTestId("list-row").filter({ has: page.locator(".nm", { hasText: /^\/csp\/fd-demo$/ }) });
  await expect(row.getByTestId("marker-no-auth")).toBeVisible();
  await row.click();
  await expect(page.getByTestId("entity-inspector").getByRole("heading", { name: "/csp/fd-demo" })).toBeVisible();
  await expect(page.getByTestId("links-panel")).toBeVisible();
  await page.goto("web-apps/rest-apis");
  await expect(page.getByTestId("list-row").filter({ hasText: "/api/flightdeck" })).toBeVisible();
});

test("one web application write goes through the shared dry-run when the capability map offers it", async ({ page }) => {
  const APP = "/csp/fd-e2e-limited";
  const put = await capability(page, "PUT /v2/web-app");
  await adminRequest("DELETE", "/web-app", { name: APP });
  const created = await adminRequest("PUT", "/web-app", { name: APP }, { NameSpace: "USER", Description: "Limited mode application", Enabled: true, AutheEnabled: 32 });
  test.skip(created.status >= 300, `the official API refused the fixture application: HTTP ${created.status}`);
  try {
    await page.goto(`web-apps/web-applications?inspect=${encodeURIComponent(`web-apps/web-application:${APP}`)}`);
    const edit = page.getByTestId("action-PUT-v2-web-app-edit");
    if (!put.available) {
      await expect(edit).toHaveAttribute("aria-disabled", "true");
      await expect(page.getByText(put.reason!).first()).toBeVisible();
      return;
    }
    await disarm(page);
    await edit.click();
    await page.getByTestId("object-form").locator("#f-Description").fill("Edited in limited mode");
    await page.getByTestId("object-form").getByTestId("form-submit").click();
    const dryRun = page.getByTestId("dry-run");
    await expect(dryRun.getByTestId("dry-run-row-Description")).toHaveAttribute("data-changed", "true");
    await dryRun.getByTestId("dry-run-apply").click();
    await expect(dryRun.getByTestId("dry-run-applied")).toBeVisible();
    const after = (await adminRequest("GET", "/web-app", { name: APP })).json as { result: { Description: string } };
    expect(after.result.Description).toBe("Edited in limited mode");
  } finally {
    await adminRequest("DELETE", "/web-app", { name: APP });
  }
});
