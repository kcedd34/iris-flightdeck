import { expect, test } from "@playwright/test";
import { disarm, signIn } from "./setup/helpers";
import { ADMIN, adminRequest } from "./setup/users";

// Feature 003, User Story 2, spec FR-010 to FR-010c and SC-005: the last-administrator check.
// The predicate fails by permitting, so the case that proves it exists is the positive one: the
// instance is narrowed to a single counted administrator, the change that would remove it is
// proposed through the interface, and the server refuses it. Everything is restored afterwards.

const KEEP = ADMIN.user;
let suspended: string[] = [];

/** IRIS reports an account that never expires as this date; it is not an expiry (backend: Facts.Expired). */
const NO_EXPIRY = "1840-12-31";

function expired(date: string): boolean {
  if (!date) return false;
  const day = date.split(" ")[0];
  if (day === NO_EXPIRY) return false;
  return new Date(day) < new Date();
}

/** The counted administrators, or null when this install will not list users through the official API. */
async function administrators(): Promise<string[] | null> {
  const answer = await adminRequest("GET", "/security/users", { maxRows: "500" });
  const list = (answer.json as { result?: { Name: string }[] }).result;
  if (!Array.isArray(list)) return null;
  const counted: string[] = [];
  for (const { Name } of list) {
    const detail = (await adminRequest("GET", "/security/user", { name: Name })).json as { result?: { Enabled: boolean; ExpirationDate: string; Roles: string[] } };
    const user = detail.result;
    if (!user || !user.Enabled) continue;
    if (expired(user.ExpirationDate)) continue;
    // The same narrow rule the server uses: %All by name, or a role that grants %Admin_Secure.
    if (user.Roles.includes("%All") || user.Roles.includes("%Manager") || user.Roles.includes("%SecurityAdministrator") || user.Roles.includes("%Admin_Secure")) counted.push(Name);
  }
  return counted;
}

test.afterEach(async () => {
  for (const name of suspended) await adminRequest("PUT", "/security/user", { name }, { Enabled: true });
  suspended = [];
});

test("PRD UC05-3. With one administrator left, the change that would remove it is refused, explained, and nothing is written", async ({ page }) => {
  test.setTimeout(180_000);
  const before = await administrators();
  test.skip(before === null, "this install does not list users through the official API, so the administrators cannot be counted");
  expect(before!.length).toBeGreaterThan(1);
  for (const name of before!) {
    if (name === KEEP) continue;
    const disabled = await adminRequest("PUT", "/security/user", { name }, { Enabled: false });
    expect(disabled.status, `disabling ${name}`).toBeLessThan(300);
    suspended.push(name);
  }
  expect(await administrators()).toEqual([KEEP]);

  await signIn(page);
  await page.goto(`permissions/users?inspect=${encodeURIComponent(`permissions/user:${KEEP}`)}`);
  await disarm(page);
  await page.getByTestId("action-PUT-v2-security-user-edit").click();
  const form = page.getByTestId("object-form");
  await form.locator("#f-Enabled").uncheck();
  await form.getByTestId("form-submit").click();

  const dryRun = page.getByTestId("dry-run");
  await expect(dryRun.getByTestId("dry-run-message")).toContainText("no administrator");
  await expect(dryRun.getByTestId("dry-run-message")).toContainText("%Admin_Secure");
  await expect(dryRun.getByTestId("dry-run-message")).toContainText("%All");
  await expect(dryRun.getByTestId("dry-run-message")).toContainText("delegated");
  await expect(dryRun.getByTestId("dry-run-apply")).toBeDisabled();

  // The same change straight to the server, with no interface involved.
  // The account is the one this run kept, not a literal: on an install whose administrator is not
  // _SYSTEM the literal named a user the loop above had already disabled, so the server answered
  // "nothing would change" (422) and the self-protection rule was never reached. Found by running
  // this suite against a real deployment whose admin account is the demo user.
  const direct = await page.evaluate(async (keep) => {
    const headers = { "X-FlightDeck-Tab": "e2e-last-admin", "X-FlightDeck-Safe-Mode": "disarmed", "Content-Type": "application/json" };
    const body = { operationId: "PUT /v2/security/user", keys: { name: keep }, proposed: { Enabled: false } };
    const preview = (await (await fetch("/api/flightdeck/v1/mutations/preview", { method: "POST", headers, body: JSON.stringify(body) })).json()) as { fingerprint: string; confirmText: string };
    const apply = await fetch("/api/flightdeck/v1/mutations/apply", {
      method: "POST",
      headers,
      body: JSON.stringify({ ...body, fingerprint: preview.fingerprint, confirmation: preview.confirmText }),
    });
    return { status: apply.status, body: (await apply.json()) as { error?: { code?: string }; trail?: { result?: string; checkMode?: string; checkResult?: string } } };
  }, KEEP);
  expect(direct.status).toBe(403);
  expect(direct.body.error?.code).toBe("SELF_PROTECTION");
  expect(direct.body.trail?.result).toBe("Blocked");
  expect(direct.body.trail?.checkMode).toBe("complete");
  expect(direct.body.trail?.checkResult).toBe("would-remove-last");

  // Nothing was written: the last administrator is still enabled.
  const user = (await adminRequest("GET", "/security/user", { name: KEEP })).json as { result: { Enabled: boolean } };
  expect(user.result.Enabled).toBe(true);
});

test("SC-005b. On an instance whose administrators hold %All, an ordinary permission change is not refused", async ({ page }) => {
  await signIn(page);
  await page.goto(`permissions/roles?inspect=${encodeURIComponent("permissions/role:FD_Demo_Operator")}`);
  await disarm(page);
  await page.getByTestId("action-PUT-v2-security-role-edit").click();
  const form = page.getByTestId("object-form");
  await form.locator("#f-Description").fill("FlightDeck demo: operates reports (reviewed)");
  await form.getByTestId("form-submit").click();
  const dryRun = page.getByTestId("dry-run");
  await expect(dryRun.getByTestId("dry-run-apply")).toBeEnabled();
  await expect(dryRun.getByTestId("dry-run-message")).toHaveCount(0);
  await dryRun.getByRole("button", { name: "Cancel" }).click();
});
