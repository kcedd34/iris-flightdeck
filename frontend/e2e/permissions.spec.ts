import { expect, test, type Page } from "@playwright/test";
import { signIn } from "./setup/helpers";
import { CHAIN, adminRequest } from "./setup/users";

// Feature 003, User Story 1: the chain between a user and a resource, read-only (PRD UC05-1 and the
// spec's scenarios 1 to 7).

async function openUser(page: Page, name: string, query = "") {
  await page.goto(`permissions/users?inspect=${encodeURIComponent(`permissions/user:${name}`)}${query}`);
  await expect(page.getByTestId("entity-inspector").getByRole("heading", { name })).toBeVisible();
}

function group(page: Page, provider: string) {
  return page.getByTestId(`links-group-${provider}`);
}

test.beforeEach(async ({ page }) => {
  await signIn(page);
});

test("PRD UC05-1. A privilege held through an inherited role appears with the chain of roles that grants it", async ({ page }) => {
  await openUser(page, CHAIN.user);
  const privileges = group(page, "effective-privileges");
  const inherited = privileges.getByRole("button").filter({ hasText: "FD_Demo_Billing:U" });
  await expect(inherited).toBeVisible();
  await expect(inherited).toContainText("FD_Demo_L1");
  await expect(inherited).toContainText("FD_Demo_L3");
});

test("2. Direct and inherited grants are both listed, each with its origin, and no privilege appears without one", async ({ page }) => {
  await openUser(page, CHAIN.user);
  const privileges = group(page, "effective-privileges");
  await expect(privileges.getByRole("button").filter({ hasText: "FD_Demo_Reports:RW" })).toContainText("via FD_Demo_Operator");
  const rows = privileges.getByRole("button");
  const count = await rows.count();
  expect(count).toBeGreaterThan(1);
  for (let i = 0; i < count; i++) await expect(rows.nth(i)).toContainText("via ");
  // The roles themselves distinguish direct from inherited.
  const roles = group(page, "user-roles");
  const role = (name: string) => roles.getByRole("button").filter({ has: page.locator(".mono", { hasText: new RegExp(`^${name}$`) }) });
  await expect(role("FD_Demo_L1")).toContainText("direct");
  await expect(role("FD_Demo_L3")).toContainText("through FD_Demo_L1, FD_Demo_L2");
});

test("3. An account authenticated elsewhere is marked, and the portal states it does not manage those roles here", async ({ page }) => {
  const name = "fd_e2e_ldap";
  await adminRequest("DELETE", "/security/user", { name });
  const created = await adminRequest("POST", "/security/user", { name }, {
    Password: "E2e-Pass-2026",
    User: { Enabled: true, ChangePassword: false, FullName: "FlightDeck e2e LDAP", AutheEnabled: 1024 },
  });
  test.skip(created.status >= 300, `the platform refused an LDAP-authenticated account: HTTP ${created.status}`);
  try {
    await openUser(page, name);
    await expect(page.getByTestId("entity-inspector").getByTestId("marker-external-authentication")).toBeVisible();
    await expect(group(page, "user-roles")).toContainText("FlightDeck does not manage those here");
  } finally {
    await adminRequest("DELETE", "/security/user", { name });
  }
});

test("5. Links open the connected entity in one click, in both directions", async ({ page }) => {
  await page.goto(`permissions/resources?inspect=${encodeURIComponent("permissions/resource:FD_Demo_Reports")}`);
  const inspector = page.getByTestId("entity-inspector");
  await expect(inspector.getByRole("heading", { name: "FD_Demo_Reports" })).toBeVisible();
  // resource -> the objects it protects, and the roles that grant it
  await expect(group(page, "resource-objects")).toContainText("/csp/fd-demo-reports");
  await group(page, "resource-roles").getByRole("button", { name: /FD_Demo_Operator/ }).click();
  await expect(inspector.getByRole("heading", { name: "FD_Demo_Operator" })).toBeVisible();
  // role -> the users who hold it, through the inverse traversal
  await expect(group(page, "role-holders")).toContainText(CHAIN.user);
  await group(page, "role-holders").getByRole("button", { name: new RegExp(CHAIN.user) }).click();
  await expect(inspector.getByRole("heading", { name: CHAIN.user })).toBeVisible();
});

test("6. SQL privileges are a panel of the chain: it asks for a namespace and answers with the platform's own provenance", async ({ page }) => {
  await openUser(page, CHAIN.user);
  const sql = group(page, "sql-privileges");
  await expect(sql).toHaveAttribute("data-state", "needs-parameter");
  await expect(sql).toContainText("answers per namespace and grantee");
  await sql.getByTestId("links-group-sql-privileges-parameter-namespace").selectOption("USER");
  await expect(sql).toHaveAttribute("data-state", "ok");
  const first = sql.getByRole("button").first();
  await expect(first).toBeVisible();
});

test("7. The palette reaches SQL privileges by name and opens the panel ready to answer", async ({ page }) => {
  await page.keyboard.press("Control+k");
  await page.getByTestId("palette-input").fill("SQL privileges");
  await page.getByTestId("command-palette").locator("[cmdk-item]").filter({ hasText: "SQL privileges of a user" }).first().click();
  await expect(page).toHaveURL(/permissions\/users\?panel=sql-privileges/);
  await page.getByTestId("list-row").filter({ hasText: CHAIN.user }).click();
  const sql = group(page, "sql-privileges");
  await expect(sql).toHaveAttribute("data-requested", "true");
  await expect(sql).toHaveAttribute("data-state", "ok");
});

test("Every permissions section lists its entities on the shared pattern", async ({ page }) => {
  for (const [section, sample] of [
    ["users", "Admin"],
    ["roles", "%All"],
    ["resources", "%Admin_Secure"],
    ["services", "%Service_Login"],
    ["privileged-routines", ""],
  ] as const) {
    await page.goto(`permissions/${section}`);
    await expect(page.getByTestId("domain-list")).toBeVisible();
    if (sample) await expect(page.getByTestId("list-row").filter({ hasText: sample }).first()).toBeVisible();
  }
});
