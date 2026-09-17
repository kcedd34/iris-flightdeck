import { expect, test, type Page } from "@playwright/test";
import { signIn } from "./setup/helpers";
import { OPERATOR } from "./setup/users";

// Feature 002, User Story 1: PRD UC03 scenarios 1 and 2 (translated), spec scenarios 1a and 3 to 6.

function row(page: Page, name: string) {
  return page.getByTestId("list-row").filter({ has: page.locator(".nm", { hasText: new RegExp(`^${name.replace(/[/.]/g, "\\$&")}$`) }) });
}

async function openWebApps(page: Page) {
  await page.goto("web-apps/web-applications");
  await expect(page.getByTestId("list-row").first()).toBeVisible();
}

test("PRD UC03-1. Given a web application accessible without authentication, when the list is displayed, then it receives a visual attention highlight", async ({ page }) => {
  await signIn(page);
  await openWebApps(page);
  await expect(row(page, "/api/monitor").getByTestId("marker-open-api")).toBeVisible();
  await expect(row(page, "/csp/fd-demo").getByTestId("marker-no-auth")).toContainText("No authentication");
});

test("1a. The list itself grades exposure: an open API above a static SPA, and FlightDeck's authenticated API unmarked", async ({ page }) => {
  await signIn(page);
  await openWebApps(page);
  const monitor = row(page, "/api/monitor");
  await expect(monitor.getByTestId("marker-open-api")).toHaveText("Open API · no authentication");
  await expect(monitor.locator(".marker-warning")).toBeVisible();
  const spa = row(page, "/flightdeck");
  await expect(spa.getByTestId("marker-static-only")).toHaveText("No authentication · static files only");
  await expect(spa.locator(".marker-caution")).toBeVisible();
  await expect(spa.getByTestId("marker-open-api")).toHaveCount(0);
  const api = row(page, "/api/flightdeck");
  for (const id of ["open-api", "no-auth", "static-only"]) await expect(api.getByTestId(`marker-${id}`)).toHaveCount(0);
  await expect(page.getByTestId("entity-inspector")).toHaveCount(0);
});

test("PRD UC03-2. Given an application protected by a resource, when the detail is displayed, then the roles that grant that resource are one click away", async ({ page }) => {
  await signIn(page);
  await openWebApps(page);
  await row(page, "/csp/fd-demo-reports").click();
  const roles = page.getByTestId("links-group-resource-roles");
  await expect(roles).toContainText("roles grant this resource");
  await roles.getByRole("button", { name: /FD_Demo_Operator/ }).click();
  const inspector = page.getByTestId("entity-inspector");
  await expect(inspector.getByRole("heading", { name: "FD_Demo_Operator" })).toBeVisible();
  await expect(inspector).toContainText("FD_Demo_Reports:RW");
});

test("3. Filters for namespace, state, REST and no authentication are applied and kept in the address", async ({ page }) => {
  await signIn(page);
  await openWebApps(page);
  await page.getByTestId("filter-auth").selectOption("none");
  await expect(page).toHaveURL(/auth=none/);
  const rows = page.getByTestId("list-row");
  const count = await rows.count();
  expect(count).toBeGreaterThan(0);
  for (let i = 0; i < count; i++) await expect(rows.nth(i).locator(".marker-warning, .marker-caution").first()).toBeVisible();
  await page.getByTestId("filter-rest").selectOption("yes");
  await expect(page).toHaveURL(/rest=yes/);
  await expect(row(page, "/api/monitor")).toBeVisible();
  await expect(row(page, "/csp/fd-demo")).toHaveCount(0);
  await page.reload();
  await expect(page.getByTestId("filter-rest")).toHaveValue("yes");
  await page.getByTestId("filter-rest").selectOption("");
  await page.getByTestId("filter-auth").selectOption("");
  await page.getByTestId("filter-ns").selectOption("USER");
  await expect(row(page, "/api/admin")).toHaveCount(0);
  await expect(row(page, "/csp/fd-demo")).toBeVisible();
});

test("4. An application the API marks as a system application is signaled in the list and the inspector", async ({ page }) => {
  await signIn(page);
  await openWebApps(page);
  const sys = row(page, "/csp/sys");
  await expect(sys.getByTestId("marker-system")).toBeVisible();
  await sys.click();
  await expect(page.getByTestId("entity-inspector").getByTestId("marker-system")).toBeVisible();
});

test("5. A user without the declared privilege sees the refusal with the required permission and resource", async ({ page }) => {
  await signIn(page, OPERATOR);
  await page.goto("web-apps/web-applications");
  await expect(page.getByRole("alert")).toContainText("Requires Use on %Admin_Secure. Ask your instance administrator for access.");
});

test("6. A linked role opens read-only in the inspector with Back; the permissions route keeps its empty state", async ({ page }) => {
  await signIn(page);
  await openWebApps(page);
  await row(page, "/csp/fd-demo-reports").click();
  await page.getByTestId("links-group-resource-roles").getByRole("button", { name: /FD_Demo_Auditor/ }).click();
  const inspector = page.getByTestId("entity-inspector");
  await expect(inspector.getByRole("heading", { name: "FD_Demo_Auditor" })).toBeVisible();
  await expect(inspector).toContainText("Role");
  await expect(inspector.locator(".actions")).toHaveCount(0);
  await inspector.getByRole("button", { name: "Back" }).click();
  await expect(inspector.getByRole("heading", { name: "/csp/fd-demo-reports" })).toBeVisible();
  await page.goto("permissions/roles");
  await expect(page.getByRole("status").filter({ hasText: "Not available in this build yet" })).toBeVisible();
});

test("Palette: selecting a web application opens its inspector on the domain pattern", async ({ page }) => {
  await signIn(page);
  await page.keyboard.press("Control+k");
  await page.getByTestId("palette-input").fill("fd-demo-reports");
  await page.locator("[cmdk-item]", { hasText: "/csp/fd-demo-reports" }).click();
  await expect(page).toHaveURL(/\/web-apps\/web-applications\?inspect=web-apps%2Fweb-application/);
  await expect(page.getByTestId("entity-inspector").getByRole("heading", { name: "/csp/fd-demo-reports" })).toBeVisible();
});

test("Percent class access lists configurations with keys and opens one in the inspector", async ({ page }) => {
  await signIn(page);
  await page.goto("web-apps/percent-class-access");
  const first = page.getByTestId("list-row").first();
  await expect(first).toBeVisible();
  await first.click();
  await expect(page.getByTestId("entity-inspector")).toContainText("Allow access");
});
