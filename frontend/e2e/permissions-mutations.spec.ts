import { expect, test, type Page } from "@playwright/test";
import { disarm, signIn } from "./setup/helpers";
import { ADMIN, adminRequest } from "./setup/users";

// Feature 003, User Story 2: changes to permissions, with impact before the confirmation, the
// own-session rule and secrets that never appear (spec scenarios 1, 3 and 6).

const ROLE = "FD_E2E_ImpactRole";
const RESOURCE = "FD_E2E_ImpactResource";
const USER = "fd_e2e_impact";

test.beforeAll(async () => {
  await adminRequest("PUT", "/security/resource", { name: RESOURCE }, { Description: "FlightDeck e2e resource", PublicPermission: "U" });
  await adminRequest("PUT", "/security/role", { name: ROLE }, { Description: "FlightDeck e2e role", Resources: [{ Name: RESOURCE, Permissions: "RW" }] });
  await adminRequest("DELETE", "/security/user", { name: USER });
  await adminRequest("POST", "/security/user", { name: USER }, { Password: "E2e-Pass-2026", User: { Enabled: true, ChangePassword: false, FullName: "FlightDeck e2e impact", Roles: [ROLE] } });
});

test.afterAll(async () => {
  await adminRequest("DELETE", "/security/user", { name: USER });
  await adminRequest("DELETE", "/security/role", { name: ROLE });
  await adminRequest("DELETE", "/security/resource", { name: RESOURCE });
});

async function openRole(page: Page, name: string) {
  await page.goto(`permissions/roles?inspect=${encodeURIComponent(`permissions/role:${name}`)}`);
  await expect(page.getByTestId("entity-inspector").getByRole("heading", { name })).toBeVisible();
}

test.beforeEach(async ({ page }) => {
  await signIn(page);
});

test("PRD UC05-2. Removing a role lists the users who lose access and the objects that become unreachable, before anything is applied", async ({ page }) => {
  await openRole(page, ROLE);
  await disarm(page);
  await page.getByTestId("action-DELETE-v2-security-role-delete").click();
  const dryRun = page.getByTestId("dry-run");
  const impact = dryRun.getByTestId("dry-run-impact");
  await expect(impact).toContainText(USER);
  await expect(impact).toContainText(RESOURCE);
  await expect(dryRun.getByTestId("dry-run-apply")).toBeDisabled();
  await dryRun.getByRole("button", { name: "Cancel" }).click();
  // Nothing was applied.
  const role = await adminRequest("GET", "/security/role", { name: ROLE });
  expect(role.status).toBe(200);
});

test("PRD UC05-4. A change to the signed-in user's own account asks for the reinforced confirmation and states the immediate effect", async ({ page }) => {
  await page.goto(`permissions/users?inspect=${encodeURIComponent(`permissions/user:${ADMIN.user}`)}`);
  await disarm(page);
  await page.getByTestId("action-PUT-v2-security-user-edit").click();
  const form = page.getByTestId("object-form");
  await form.locator("#f-Comment").fill("Reviewed in an e2e run");
  await form.locator("#f-Enabled").uncheck();
  await form.getByTestId("form-submit").click();
  const dryRun = page.getByTestId("dry-run");
  await expect(dryRun.getByTestId("dry-run-confirm-input")).toBeVisible();
  await expect(dryRun).toContainText("your own account");
  await expect(dryRun).toContainText("immediately");
  await dryRun.getByRole("button", { name: "Cancel" }).click();
  const user = await adminRequest("GET", "/security/user", { name: ADMIN.user });
  expect((user.json as { result: { Enabled: boolean } }).result.Enabled).toBe(true);
});

test("6. A password is a secret in every layer: the confirmation shows what will be sent without the value, and the trail keeps none", async ({ page }) => {
  await page.goto(`permissions/users?inspect=${encodeURIComponent(`permissions/user:${USER}`)}`);
  await disarm(page);
  await page.getByTestId("action-POST-v2-security-user-password-set-password").click();
  const form = page.getByTestId("object-form");
  await form.locator("#f-NewPassword").fill("E2e-New-Pass-2026");
  await form.getByTestId("form-submit").click();
  const dryRun = page.getByTestId("dry-run");
  await expect(dryRun.getByTestId("dry-run-request")).toBeVisible();
  await expect(dryRun).not.toContainText("E2e-New-Pass-2026");
  await dryRun.getByTestId("dry-run-confirm-input").fill(`the password of ${USER}`);
  await dryRun.getByTestId("dry-run-apply").click();
  await expect(dryRun.getByTestId("dry-run-applied")).toBeVisible();
  await dryRun.getByRole("button", { name: "Open session trail" }).click();
  const trail = page.getByTestId("trail-panel");
  await expect(trail.getByTestId("trail-entry").first()).toContainText("the password of");
  const [download] = await Promise.all([page.waitForEvent("download"), trail.getByTestId("trail-export").click()]);
  const chunks: Buffer[] = [];
  for await (const chunk of await download.createReadStream()) chunks.push(chunk as Buffer);
  expect(Buffer.concat(chunks).toString("utf8")).not.toContain("E2e-New-Pass-2026");
  const stored = await page.evaluate(() => JSON.stringify(window.sessionStorage));
  expect(stored).not.toContain("E2e-New-Pass-2026");
});

test("A granted role can be added and removed through the shared confirmation, and the chain updates", async ({ page }) => {
  await page.goto(`permissions/users?inspect=${encodeURIComponent(`permissions/user:${USER}`)}`);
  await disarm(page);
  await page.getByTestId("action-PUT-v2-security-user-edit").click();
  const form = page.getByTestId("object-form");
  await form.locator("#f-Roles").fill(`${ROLE}, FD_Demo_Operator`);
  await form.getByTestId("form-submit").click();
  const dryRun = page.getByTestId("dry-run");
  await expect(dryRun.getByTestId("dry-run-row-Roles")).toHaveAttribute("data-changed", "true");
  await dryRun.getByTestId("dry-run-confirm-input").fill(USER);
  await dryRun.getByTestId("dry-run-apply").click();
  await expect(dryRun.getByTestId("dry-run-applied")).toBeVisible();
  await dryRun.getByRole("button", { name: "Close" }).click();
  await expect(page.getByTestId("links-group-user-roles")).toContainText("FD_Demo_Operator");
});
