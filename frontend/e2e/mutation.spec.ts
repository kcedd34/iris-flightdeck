import { expect, test, type Page } from "@playwright/test";
import { disarm, signIn } from "./setup/helpers";
import { ADMIN, adminRequest } from "./setup/users";

// Feature 002, User Story 2: PRD UC03 scenarios 3 and 4, UC10 scenarios 1 to 4 (translated), spec
// scenarios 7 to 10, SC-005 (concurrent change) and the trail lifetime (spec FR-014).

const APP = "/csp/fd-e2e-mutation";

async function resetApp() {
  await adminRequest("DELETE", "/web-app", { name: APP });
  const created = await adminRequest("PUT", "/web-app", { name: APP }, { NameSpace: "USER", Description: "FlightDeck e2e application", Enabled: true, AutheEnabled: 32, Timeout: 900 });
  expect(created.status).toBe(201);
}

async function official(name: string): Promise<Record<string, unknown>> {
  return ((await adminRequest("GET", "/web-app", { name })).json as { result: Record<string, unknown> }).result;
}

async function openApp(page: Page, name = APP) {
  await page.goto(`web-apps/web-applications?inspect=${encodeURIComponent(`web-apps/web-application:${name}`)}`);
  await expect(page.getByTestId("entity-inspector").getByRole("heading", { name })).toBeVisible();
}

async function editDescription(page: Page, text: string) {
  await page.getByTestId("action-PUT-v2-web-app-edit").click();
  const form = page.getByTestId("object-form");
  await form.locator("#f-Description").fill(text);
  await form.getByTestId("form-submit").click();
}

test.beforeEach(async () => {
  await resetApp();
});

test.afterAll(async () => {
  await adminRequest("DELETE", "/web-app", { name: APP });
});

test("PRD UC03-3 and UC10-1. Editing with safe mode disarmed shows the differences field by field before applying, and records the action in the trail", async ({ page }) => {
  await signIn(page);
  await openApp(page);
  await disarm(page);
  await editDescription(page, "Edited through the dry-run");
  const dryRun = page.getByTestId("dry-run");
  await expect(dryRun.getByRole("columnheader", { name: "CURRENT" })).toBeVisible();
  await expect(dryRun.getByRole("columnheader", { name: "COMMANDED" })).toBeVisible();
  const row = dryRun.getByTestId("dry-run-row-Description");
  await expect(row).toHaveAttribute("data-changed", "true");
  await expect(row).toContainText("FlightDeck e2e application");
  await expect(row).toContainText("Edited through the dry-run");
  await expect(dryRun.getByTestId("dry-run-row-Timeout")).toHaveAttribute("data-changed", "false");
  expect((await official(APP)).Description).toBe("FlightDeck e2e application");
  await dryRun.getByTestId("dry-run-apply").click();
  await expect(dryRun.getByTestId("dry-run-applied")).toHaveText("Applied");
  expect((await official(APP)).Description).toBe("Edited through the dry-run");
  await dryRun.getByRole("button", { name: "Open session trail" }).click();
  const trail = page.getByTestId("trail-panel");
  await expect(trail).toContainText("This trail is local to this browser tab and does not replace IRIS auditing.");
  const entry = trail.getByTestId("trail-entry").first();
  await expect(entry).toHaveAttribute("data-result", "Applied");
  await expect(entry).toContainText(APP);
});

test("PRD UC03-4. Disabling the application that serves the portal is blocked and explained, in the UI and by the server", async ({ page }) => {
  await signIn(page);
  await openApp(page, "/api/flightdeck");
  await disarm(page);
  const disable = page.getByTestId("action-PUT-v2-web-app-disable");
  await expect(disable).toHaveAttribute("aria-disabled", "true");
  await expect(page.getByText("This web application serves FlightDeck. Disabling it would lock you out.").first()).toBeVisible();
  // Trying anyway through the form: the dry-run shows the block and offers no Apply.
  await page.getByTestId("action-PUT-v2-web-app-edit").click();
  await page.getByTestId("object-form").locator("#f-Enabled").uncheck();
  await page.getByTestId("object-form").getByTestId("form-submit").click();
  const dryRun = page.getByTestId("dry-run");
  await expect(dryRun.getByTestId("dry-run-message")).toHaveText("This web application serves FlightDeck. Disabling it would lock you out.");
  await expect(dryRun.getByTestId("dry-run-apply")).toBeDisabled();
  await dryRun.getByRole("button", { name: "Cancel" }).click();
  // And straight to the server, without the UI.
  const direct = await page.evaluate(async () => {
    const headers = { "X-FlightDeck-Tab": "e2e-direct", "X-FlightDeck-Safe-Mode": "disarmed", "Content-Type": "application/json" };
    const body = { operationId: "PUT /v2/web-app", keys: { name: "/api/flightdeck" }, proposed: { Enabled: false } };
    const preview = await (await fetch("/api/flightdeck/v1/mutations/preview", { method: "POST", headers, body: JSON.stringify(body) })).json();
    const apply = await fetch("/api/flightdeck/v1/mutations/apply", { method: "POST", headers, body: JSON.stringify({ ...body, fingerprint: preview.fingerprint, confirmation: "/api/flightdeck" }) });
    return { status: apply.status, body: await apply.json() };
  });
  expect(direct.status).toBe(403);
  expect(direct.body.error.message).toBe("This web application serves FlightDeck. Disabling it would lock you out.");
  expect((await official("/api/flightdeck")).Enabled).toBe(true);
});

test("PRD UC10-2. A destructive operation requires typing the target name", async ({ page }) => {
  await signIn(page);
  await openApp(page);
  await disarm(page);
  await page.getByTestId("action-DELETE-v2-web-app-delete").click();
  const dryRun = page.getByTestId("dry-run");
  await expect(dryRun).toContainText(`Type ${APP} to confirm`);
  const apply = dryRun.getByTestId("dry-run-apply");
  await expect(apply).toBeDisabled();
  await dryRun.getByTestId("dry-run-confirm-input").fill(APP.slice(0, -1));
  await expect(apply).toBeDisabled();
  await dryRun.getByTestId("dry-run-confirm-input").fill(APP);
  await expect(apply).toBeEnabled();
  await apply.click();
  await expect(dryRun.getByTestId("dry-run-applied")).toBeVisible();
  expect((await adminRequest("GET", "/web-app", { name: APP })).status).toBe(404);
});

test("PRD UC10-3. When the state changed on the server since it was read, the differences are reloaded and recomputed before applying (SC-005)", async ({ page }) => {
  await signIn(page);
  await openApp(page);
  await disarm(page);
  await editDescription(page, "Mine");
  const dryRun = page.getByTestId("dry-run");
  await expect(dryRun.getByTestId("dry-run-row-Timeout")).toContainText("900");
  await adminRequest("PUT", "/web-app", { name: APP }, { Timeout: 901 });
  await dryRun.getByTestId("dry-run-apply").click();
  await expect(dryRun.getByTestId("dry-run-message")).toHaveText("This object changed on the server while you were editing. Review the updated differences before applying.");
  await expect(dryRun.getByTestId("dry-run-row-Timeout")).toContainText("901");
  expect((await official(APP)).Description).toBe("FlightDeck e2e application");
  await dryRun.getByTestId("dry-run-apply").click();
  await expect(dryRun.getByTestId("dry-run-applied")).toBeVisible();
  const after = await official(APP);
  expect(after.Description).toBe("Mine");
  expect(after.Timeout).toBe(901);
});

test("PRD UC10-4. The trail exports as JSON with time, target, differences and result of each action", async ({ page }) => {
  await signIn(page);
  await openApp(page);
  await disarm(page);
  await editDescription(page, "For the export");
  await page.getByTestId("dry-run").getByTestId("dry-run-apply").click();
  await page.getByTestId("dry-run").getByRole("button", { name: "Open session trail" }).click();
  const [download] = await Promise.all([page.waitForEvent("download"), page.getByTestId("trail-export").click()]);
  expect(download.suggestedFilename()).toMatch(/^flightdeck-trail-.*\.json$/);
  const text = await (await download.createReadStream()).toArray().then((chunks) => Buffer.concat(chunks).toString("utf8"));
  const exported = JSON.parse(text);
  expect(exported.notice).toBe("This trail is local to this browser tab and does not replace IRIS auditing.");
  const entry = exported.entries.at(-1);
  expect(entry.time).toMatch(/^\d{4}-\d{2}-\d{2}T/);
  expect(entry.target).toBe(APP);
  expect(entry.result).toBe("Applied");
  expect(entry.rows.find((r: { field: string }) => r.field === "Description")).toMatchObject({ changed: true, current: "FlightDeck e2e application", commanded: "For the export" });
  expect(text).not.toContain(ADMIN.password);
});

test("7. Armed: the form is read-only with the disarm offer, and a direct mutation request is refused by the server", async ({ page }) => {
  await signIn(page);
  await openApp(page);
  await page.getByTestId("action-PUT-v2-web-app-edit").click();
  const form = page.getByTestId("object-form");
  await expect(form).toContainText("Safe mode is on. Turn it off to make changes in this tab.");
  await expect(form.locator("#f-Description")).toHaveAttribute("readonly", "");
  await expect(form.getByTestId("form-submit")).toBeDisabled();
  const direct = await page.evaluate(async (name) => {
    const r = await fetch("/api/flightdeck/v1/mutations/apply", {
      method: "POST",
      headers: { "X-FlightDeck-Tab": "e2e-armed", "Content-Type": "application/json" },
      body: JSON.stringify({ operationId: "PUT /v2/web-app", keys: { name }, proposed: { Description: "x" }, fingerprint: "any" }),
    });
    return { status: r.status, body: await r.json() };
  }, APP);
  expect(direct.status).toBe(403);
  expect(direct.body.error.message).toBe("Safe mode is on. Turn it off to make changes in this tab.");
});

test("8. A rejection shows the IRIS message verbatim, keeps the form input and records the failure", async ({ page }) => {
  await signIn(page);
  await openApp(page);
  await disarm(page);
  await page.getByTestId("action-PUT-v2-web-app-edit").click();
  const form = page.getByTestId("object-form");
  await form.locator("#f-Timeout").fill("abc");
  await form.getByTestId("form-submit").click();
  await page.getByTestId("dry-run").getByTestId("dry-run-apply").click();
  await expect(form.getByTestId("form-error")).toContainText("ERROR #7207");
  await expect(form.locator("#f-Timeout")).toHaveValue("abc");
  const trail = await page.evaluate(() => JSON.parse(window.sessionStorage.getItem("flightdeck.trail.v1") ?? "{}"));
  expect(trail.entries.at(-1)).toMatchObject({ result: "Failed", status: 500, target: APP });
});

test("9. A proposal equal to the current state sends nothing and says so", async ({ page }) => {
  await signIn(page);
  await openApp(page);
  await disarm(page);
  await page.getByTestId("action-PUT-v2-web-app-edit").click();
  await page.getByTestId("object-form").getByTestId("form-submit").click();
  const dryRun = page.getByTestId("dry-run");
  await expect(dryRun.getByTestId("dry-run-message")).toHaveText("Nothing to apply. The proposed state matches the current one.");
  await expect(dryRun.getByTestId("dry-run-apply")).toBeDisabled();
});

test("Trail lifetime: it survives a reload of the tab and is cleared at sign-out", async ({ page }) => {
  await signIn(page);
  await openApp(page);
  await disarm(page);
  await editDescription(page, "Survives reload");
  await page.getByTestId("dry-run").getByTestId("dry-run-apply").click();
  await expect(page.getByTestId("dry-run").getByTestId("dry-run-applied")).toBeVisible();
  await page.reload();
  await expect(page.getByTestId("glareshield")).toBeVisible();
  await page.keyboard.press("Control+k");
  await page.getByTestId("palette-input").fill("Session trail");
  await page.locator("[cmdk-item]", { hasText: "Session trail" }).first().click();
  await expect(page.getByTestId("trail-panel").getByTestId("trail-entry")).toHaveCount(1);
  await page.getByTestId("trail-panel").getByRole("button", { name: "Close" }).click();
  await page.getByRole("button", { name: "Sign out" }).click();
  await expect(page.getByRole("button", { name: "Sign in" })).toBeVisible();
  expect(await page.evaluate(() => window.sessionStorage.getItem("flightdeck.trail.v1"))).toBeNull();
});

test("Trail lifetime: detected expiry clears the trail; after re-authentication the open dry-run is recomputed", async ({ page, context }) => {
  await signIn(page);
  await openApp(page);
  await disarm(page);
  await editDescription(page, "Before expiry");
  await page.getByTestId("dry-run").getByTestId("dry-run-apply").click();
  await expect(page.getByTestId("dry-run").getByTestId("dry-run-applied")).toBeVisible();
  await page.getByTestId("dry-run").getByRole("button", { name: "Close" }).click();
  await editDescription(page, "After expiry");
  await expect(page.getByTestId("dry-run").getByTestId("dry-run-row-Description")).toContainText("Before expiry");
  await context.clearCookies();
  await page.getByTestId("dry-run").getByTestId("dry-run-apply").click();
  await expect(page.getByRole("dialog", { name: "Your session expired" })).toBeVisible();
  expect(await page.evaluate(() => window.sessionStorage.getItem("flightdeck.trail.v1"))).toBeNull();
  await adminRequest("PUT", "/web-app", { name: APP }, { Timeout: 905 });
  await page.getByRole("dialog", { name: "Your session expired" }).locator('input[name="password"]').fill(ADMIN.password);
  await page.getByRole("button", { name: "Continue" }).click();
  const dryRun = page.getByTestId("dry-run");
  await expect(dryRun.getByTestId("dry-run-row-Timeout")).toContainText("905");
  expect((await official(APP)).Description).toBe("Before expiry");
});
