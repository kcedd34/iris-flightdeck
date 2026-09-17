import { expect, test, type Page } from "@playwright/test";
import { disarm, signIn } from "./setup/helpers";

// Feature 002, User Story 3: PRD UC04 scenarios 1 to 4 (translated) and spec scenarios 5 to 9.

function service(page: Page, name: string) {
  return page.getByTestId("list-row").filter({ has: page.locator(".nm", { hasText: new RegExp(`^${name.replace(/[/.%]/g, "\\$&")}$`) }) });
}

const TAB = "X-FlightDeck-Tab: e2e-explorer";

async function openService(page: Page, name: string) {
  await page.goto(`web-apps/rest-apis?inspect=${encodeURIComponent(`web-apps/rest-service:?${new URLSearchParams({ webApplication: name }).toString()}`)}`);
  await expect(page.getByTestId("entity-inspector").getByRole("heading", { name })).toBeVisible();
}

test("PRD UC04-1. Services with and without a specification both appear, and those without are flagged", async ({ page }) => {
  await signIn(page);
  await page.goto("web-apps/rest-apis");
  await expect(service(page, "/api/mgmnt")).toBeVisible();
  await expect(service(page, "/api/mgmnt").getByTestId("marker-no-specification")).toHaveCount(0);
  await expect(service(page, "/api/monitor").getByTestId("marker-no-specification")).toHaveText("No specification");
});

test("PRD UC04-4. FlightDeck's own API appears with its specification", async ({ page }) => {
  await signIn(page);
  await page.goto("web-apps/rest-apis");
  await expect(service(page, "/api/flightdeck").getByTestId("marker-published")).toBeVisible();
  await service(page, "/api/flightdeck").click();
  const spec = page.getByTestId("rest-specification");
  await expect(spec).toContainText("FlightDeck API");
  await expect(spec).toContainText("OpenAPI 3.0");
  await expect(spec.locator(".spath-h", { hasText: /^\/rest\/services$/ })).toBeVisible();
});

test("PRD UC04-2. A test request shows status, time, headers and formatted body, and copies as curl without a credential", async ({ page, context }) => {
  await context.grantPermissions(["clipboard-read", "clipboard-write"]);
  await signIn(page);
  await openService(page, "/api/flightdeck");
  await page.getByTestId("rest-path").fill("/api/flightdeck/v1/session/capabilities");
  // FlightDeck's own API requires this header; the explorer adds nothing on the user's behalf.
  await page.getByTestId("rest-headers").fill(TAB);
  await page.getByTestId("rest-execute").click();
  const response = page.getByTestId("rest-response");
  await expect(response.getByTestId("rest-status")).toHaveText("200");
  await expect(response.getByTestId("rest-time")).toContainText("ms");
  await expect(response.getByTestId("rest-headers-out")).toContainText(/content-type/i);
  await expect(response.getByTestId("rest-body-out")).toContainText('"entries"');
  await response.getByTestId("rest-copy-curl").click();
  const curl = await page.evaluate(() => navigator.clipboard.readText());
  expect(curl).toContain("-u '<user>:<password>'");
  expect(curl).toContain("/api/flightdeck/v1/session/capabilities");
  expect(curl).not.toMatch(/SYS|Authorization|Cookie|CSPSESSIONID/i);
});

test("PRD UC04-3. With safe mode armed, POST, PUT, PATCH and DELETE are blocked and disarming is offered", async ({ page }) => {
  await signIn(page);
  await openService(page, "/api/flightdeck");
  for (const method of ["POST", "PUT", "PATCH", "DELETE"]) {
    await page.getByTestId("rest-method").selectOption(method);
    await page.getByTestId("rest-path").fill("/api/flightdeck/v1/nothing-here");
    await page.getByTestId("rest-execute").click();
    const dryRun = page.getByTestId("dry-run");
    await expect(dryRun.getByTestId("dry-run-disarm")).toBeVisible();
    await expect(dryRun.getByTestId("dry-run-apply")).toHaveCount(0);
    await dryRun.getByRole("button", { name: "Cancel" }).click();
    await expect(dryRun).toHaveCount(0);
  }
  await expect(page.getByTestId("rest-response")).toHaveCount(0);
});

test("5. Only method, path, parameters, headers and body are editable; another host is refused", async ({ page }) => {
  await signIn(page);
  await openService(page, "/api/flightdeck");
  const builder = page.getByTestId("rest-request-builder");
  await expect(builder.locator("input, select, textarea")).toHaveCount(4);
  await page.getByTestId("rest-path").fill("http://example.com/");
  await page.getByTestId("rest-execute").click();
  await expect(page.getByTestId("rest-error")).toContainText(/only to this instance/i);
});

test("6. A service without a specification shows its metadata and routes, and offers a free request by path", async ({ page }) => {
  await signIn(page);
  await openService(page, "/api/monitor");
  const inspector = page.getByTestId("entity-inspector");
  await expect(inspector).toContainText("%SYS");
  await expect(inspector).toContainText("%Api.Monitor");
  await expect(page.getByTestId("rest-routes")).toContainText("/metrics");
  await expect(page.getByTestId("rest-roles-note")).toContainText("Test requests run with your login roles");
  await expect(page.getByTestId("rest-path")).toHaveValue("/api/monitor/");
});

test("7. An error status is shown in full, without interpretation", async ({ page }) => {
  await signIn(page);
  await openService(page, "/api/flightdeck");
  await page.getByTestId("rest-path").fill("/api/flightdeck/v1/nothing-here");
  await page.getByTestId("rest-headers").fill(TAB);
  await page.getByTestId("rest-execute").click();
  const response = page.getByTestId("rest-response");
  await expect(response.getByTestId("rest-status")).toHaveText("404");
  await expect(page.getByTestId("rest-error")).toHaveCount(0);
});

test("8. A namespace with no REST service explains why and points to FlightDeck's namespace", async ({ page }) => {
  await signIn(page);
  await page.goto("web-apps/rest-apis?ns=FD_NO_SUCH_NAMESPACE");
  const empty = page.getByTestId("domain-list");
  await expect(empty).toContainText("No REST service in FD_NO_SUCH_NAMESPACE");
  await expect(empty).toContainText("/api/flightdeck");
});

test("9. Disarmed, a DELETE opens the shared confirmation in request mode, requires typing the path, and is recorded in the trail", async ({ page }) => {
  await signIn(page);
  await openService(page, "/api/flightdeck");
  await disarm(page);
  await page.getByTestId("rest-method").selectOption("DELETE");
  await page.getByTestId("rest-path").fill("/api/flightdeck/v1/nothing-here");
  await page.getByTestId("rest-headers").fill(TAB);
  await page.getByTestId("rest-execute").click();
  const dryRun = page.getByTestId("dry-run");
  await expect(dryRun.getByTestId("dry-run-request")).toContainText("DELETE /api/flightdeck/v1/nothing-here");
  await expect(dryRun).toContainText(/no current state to compare/i);
  await expect(dryRun.getByTestId("dry-run-apply")).toBeDisabled();
  await dryRun.getByTestId("dry-run-confirm-input").fill("/api/flightdeck/v1/nothing-here");
  await dryRun.getByTestId("dry-run-apply").click();
  await expect(dryRun.getByTestId("dry-run-applied")).toBeVisible();
  await dryRun.getByRole("button", { name: "Open session trail" }).click();
  const entry = page.getByTestId("trail-panel").getByTestId("trail-entry").first();
  await expect(entry).toContainText("DELETE /api/flightdeck/v1/nothing-here");
  // FlightDeck's own router answers 403 SAFE_MODE_ON: the test request carries no safe-mode header,
  // and the explorer shows and records that status as returned, without interpretation.
  const status = await page.getByTestId("rest-status").textContent();
  await expect(entry).toContainText(`${status} ·`);
  await expect(entry).toHaveAttribute("data-result", Number(status) < 400 ? "Applied" : "Failed");
});

test("The palette finds a REST service and opens it in the REST APIs section", async ({ page }) => {
  await signIn(page);
  await page.keyboard.press("Control+k");
  await page.getByTestId("palette-input").fill("api/flightdeck");
  const palette = page.getByTestId("command-palette");
  const row = palette.locator("[cmdk-item]").filter({ has: page.getByText("/api/flightdeck", { exact: true }) }).filter({ hasText: "REST service" });
  await row.click();
  await expect(page).toHaveURL(/\/web-apps\/rest-apis\?inspect=/);
  await expect(page.getByTestId("rest-specification")).toContainText("FlightDeck API");
});
