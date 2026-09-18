import { execFileSync } from "node:child_process";
import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Page } from "@playwright/test";
import { capability, disarm, setTheme, signIn } from "./setup/helpers";
import { adminRequest, ensureUser } from "./setup/users";

// Feature 002 polish: the credential audit extended to edits, test requests, the trail export and
// copied curl (T083, SC-010), and axe on the new surfaces in both themes (T084).

const AUDIT = { user: "fd_e2e_audit", password: "Audit-Pass-7Q2x-2026" };
// Feature 003 secrets written during the audited session, none of which may appear anywhere after.
const WALLET_SECRET = "audit-wallet-secret-2026";
const NEW_PASSWORD = "Audit-New-Pass-5R3y-2026";
/** Feature 004: the licence key is masked by the mutation layer and must reach no log or error body. */
const LICENSE_KEY = "Audit-License-Key-8Q2w-2026";
const COLLECTION = "FD_E2E_AuditVault";
const SUBJECT = "fd_e2e_audit_subject";
const APP = "/csp/fd-e2e-audit";
const CONTAINER = process.env.FD_CONTAINER ?? "iris-flightdeck-iris-1";
const WCAG = ["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"];

test.beforeAll(async () => {
  await ensureUser(AUDIT.user, AUDIT.password, ["%All"]);
  await ensureUser(SUBJECT, "Audit-Subject-2026", []);
  await adminRequest("PUT", "/wallet/collection", { name: COLLECTION }, { UseResource: "FD_Demo_Reports:READ", EditResource: "FD_Demo_Reports:WRITE" });
  await adminRequest("DELETE", "/web-app", { name: APP });
  const created = await adminRequest("PUT", "/web-app", { name: APP }, { NameSpace: "USER", Description: "FlightDeck audit application", Enabled: true, AutheEnabled: 32 });
  expect(created.status).toBe(201);
});

test.afterAll(async () => {
  await adminRequest("DELETE", "/web-app", { name: APP });
  await adminRequest("DELETE", "/wallet/secret", { name: `${COLLECTION}.audit_token` });
  await adminRequest("DELETE", "/wallet/collection", { name: COLLECTION });
  await adminRequest("DELETE", "/security/user", { name: SUBJECT });
});

async function axe(page: Page, where: string) {
  await page.waitForTimeout(400);
  const results = await new AxeBuilder({ page }).withTags(WCAG).analyze();
  expect(results.violations.map((v) => `${where}: ${v.id} ${v.nodes.map((n) => n.target.join(" ")).join(", ")}`)).toEqual([]);
}

test("SC-010. No credential in the trail export, copied curl, browser storage, cookies or IRIS logs", async ({ page, context }) => {
  test.setTimeout(180_000);
  await context.grantPermissions(["clipboard-read", "clipboard-write"]);
  await signIn(page, AUDIT);
  // Edit an application.
  await page.goto(`web-apps/web-applications?inspect=${encodeURIComponent(`web-apps/web-application:${APP}`)}`);
  await disarm(page);
  await page.getByTestId("action-PUT-v2-web-app-edit").click();
  await page.getByTestId("object-form").locator("#f-Description").fill("Audited edit");
  await page.getByTestId("object-form").getByTestId("form-submit").click();
  const dryRun = page.getByTestId("dry-run");
  await dryRun.getByTestId("dry-run-apply").click();
  await expect(dryRun.getByTestId("dry-run-applied")).toBeVisible();
  await dryRun.getByRole("button", { name: "Close" }).click();
  // Run a test request, a mutating one through the dry-run, and copy curl.
  await page.goto(`web-apps/rest-apis?inspect=${encodeURIComponent("web-apps/rest-service:?webApplication=%2Fapi%2Fflightdeck")}`);
  await disarm(page);
  await page.getByTestId("rest-path").fill("/api/flightdeck/v1/session");
  await page.getByTestId("rest-headers").fill("X-FlightDeck-Tab: audit");
  await page.getByTestId("rest-execute").click();
  await expect(page.getByTestId("rest-status")).toHaveText("200");
  await page.getByTestId("rest-copy-curl").click();
  const curl = await page.evaluate(() => navigator.clipboard.readText());
  await page.getByTestId("rest-method").selectOption("POST");
  await page.getByTestId("rest-body").fill('{"probe":true}');
  await page.getByTestId("rest-execute").click();
  await dryRun.getByTestId("dry-run-apply").click();
  await expect(dryRun.getByTestId("dry-run-applied")).toBeVisible();
  // Feature 003: a wallet secret and a user password, both written through the shared layer. Where
  // the install does not offer the wallet secret write, the password alone carries this session's
  // secret, and the sweep below is the same.
  const walletWrite = (await capability(page, "PUT /v2/wallet/secret"))?.available ?? false;
  let form = page.getByTestId("object-form");
  if (walletWrite) {
    await page.goto(`security/wallet?inspect=${encodeURIComponent(`security/wallet-collection:${COLLECTION}`)}`);
    await disarm(page);
    await page.getByTestId("action-PUT-v2-wallet-secret-new-secret").click();
    await form.locator("#f-secretName").fill("audit_token");
    await form.locator("#f-type").selectOption("%Wallet.KeyValue");
    await form.locator("#f-secret").fill(WALLET_SECRET);
    await form.getByTestId("form-submit").click();
    await dryRun.getByTestId("dry-run-apply").click();
    await expect(dryRun.getByTestId("dry-run-applied")).toBeVisible();
    await dryRun.getByRole("button", { name: "Close" }).click();
  }

  await page.goto(`permissions/users?inspect=${encodeURIComponent(`permissions/user:${SUBJECT}`)}`);
  await disarm(page);
  await page.getByTestId("action-POST-v2-security-user-password-set-password").click();
  form = page.getByTestId("object-form");
  await form.locator("#f-NewPassword").fill(NEW_PASSWORD);
  await form.getByTestId("form-submit").click();
  await dryRun.getByTestId("dry-run-confirm-input").fill(`the password of ${SUBJECT}`);
  await dryRun.getByTestId("dry-run-apply").click();
  await expect(dryRun.getByTestId("dry-run-applied")).toBeVisible();

  // Feature 004: a licence key typed into a write. The platform returns the key on a read, so what is
  // masked is what the mutation layer carries — the dry-run, the trail and its export — and it must
  // reach no backend log and no error body either (spec FR-036, FR-036a).
  const licenseRefused = await page.evaluate(async (key) => {
    const response = await fetch("/api/flightdeck/v1/mutations/preview", {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-FlightDeck-Tab": "e2e", "X-FlightDeck-Safe-Mode": "disarmed" },
      body: JSON.stringify({ operationId: "PUT /v2/license/key", keys: {}, proposed: { AuthorizationKey: key } }),
    });
    return { status: response.status, body: await response.text() };
  }, LICENSE_KEY);
  // Whatever the platform answers, the key is not in what comes back.
  expect(licenseRefused.body).not.toContain(LICENSE_KEY);

  // Feature 005: the log stream reads what the instance wrote, and the instance writes a great deal.
  // Nothing in an event, in a raw record or in an exported file may carry a credential this session
  // used (spec FR-037).
  const streamText = await page.evaluate(async () => {
    const response = await fetch("/api/flightdeck/v1/logs/events?limit=200", { headers: { "X-FlightDeck-Tab": "e2e" } });
    return response.text();
  });
  const streamExport = await page.evaluate(async () => {
    const response = await fetch("/api/flightdeck/v1/logs/export?limit=200", { headers: { "X-FlightDeck-Tab": "e2e" } });
    return response.text();
  });

  // Export the trail.
  await dryRun.getByRole("button", { name: "Open session trail" }).click();
  const [download] = await Promise.all([page.waitForEvent("download"), page.getByTestId("trail-export").click()]);
  const chunks: Buffer[] = [];
  for await (const chunk of await download.createReadStream()) chunks.push(chunk as Buffer);
  const exported = Buffer.concat(chunks).toString("utf8");

  const basic = Buffer.from(`${AUDIT.user}:${AUDIT.password}`).toString("base64");
  const needles = [AUDIT.password, basic, "Authorization", WALLET_SECRET, NEW_PASSWORD, LICENSE_KEY];
  const storage = await page.evaluate(() => JSON.stringify({ session: { ...window.sessionStorage }, local: { ...window.localStorage } }));
  const cookies = JSON.stringify(await context.cookies());
  for (const [where, text] of Object.entries({ exported, curl, storage, cookies, streamText, streamExport })) {
    for (const needle of needles) expect(text.includes(needle), `${needle.slice(0, 6)}… in ${where}`).toBe(false);
  }
  expect(curl).toContain("-u '<user>:<password>'");
  expect(exported).toContain("Audited edit");

  let logs: string | null;
  try {
    logs = execFileSync("docker", ["exec", CONTAINER, "sh", "-c", `grep -rlF -e '${AUDIT.password}' -e '${basic}' -e '${WALLET_SECRET}' -e '${NEW_PASSWORD}' /durable/iris/mgr --include='*.log' || true`], { encoding: "utf8" });
  } catch {
    logs = null;
  }
  test.skip(logs === null, "docker is not reachable from the test runner; IRIS logs not searched");
  expect(logs!.trim()).toBe("");
});

for (const theme of ["dark", "light"] as const) {
  test(`axe finds no violations on the web-apps sections, the dry-run, the trail and the explorer (${theme})`, async ({ page }) => {
    test.setTimeout(180_000);
    await signIn(page);
    await setTheme(page, theme);
    for (const section of ["web-apps/web-applications", "web-apps/percent-class-access", "web-apps/rest-apis"]) {
      await page.goto(section);
      await expect(page.getByTestId("list-row").first()).toBeVisible();
      await axe(page, section);
    }
    // Feature 003 sections: every list, every singleton, and the home panel's attention list.
    for (const section of [
      "permissions/users",
      "permissions/roles",
      "permissions/resources",
      "permissions/services",
      "permissions/privileged-routines",
      "security/tls",
      "security/x509",
      "security/oauth2",
      "security/wallet",
      "security/encryption",
      "security/ldap",
      "security/mft",
      "security/auditing",
      "security/web-authentication",
      "security/superservers",
      "./",
    ]) {
      await page.goto(section);
      await expect(page.getByTestId("domain-list").or(page.getByTestId("singleton-inspector")).or(page.getByTestId("home-attention")).first()).toBeVisible();
      await axe(page, section);
    }
    // An inspector with the chain, and one with a parameterised panel.
    await page.goto(`permissions/users?inspect=${encodeURIComponent("permissions/user:_SYSTEM")}`);
    await expect(page.getByTestId("links-group-effective-privileges")).toBeVisible();
    await axe(page, "permissions inspector");
    await page.goto(`web-apps/rest-apis?inspect=${encodeURIComponent("web-apps/rest-service:?webApplication=%2Fapi%2Fflightdeck")}`);
    await page.getByTestId("rest-operation").first().getByRole("button").click();
    await page.getByTestId("rest-path").fill("/api/flightdeck/v1/nothing-here");
    await page.getByTestId("rest-execute").click();
    await expect(page.getByTestId("rest-response")).toBeVisible();
    await axe(page, "rest inspector");
    await page.goto(`web-apps/web-applications?inspect=${encodeURIComponent(`web-apps/web-application:${APP}`)}`);
    await expect(page.getByTestId("links-panel")).toBeVisible();
    await axe(page, "web application inspector");
    await disarm(page);
    await page.getByTestId("action-DELETE-v2-web-app-delete").click();
    await expect(page.getByTestId("dry-run").getByTestId("dry-run-confirm-input")).toBeVisible();
    await axe(page, "dry-run");
    await page.getByTestId("dry-run").getByRole("button", { name: "Cancel" }).click();
    await page.keyboard.press("Control+k");
    await page.getByTestId("palette-input").fill("Session trail");
    await page.keyboard.press("Enter");
    await expect(page.getByTestId("trail-panel")).toBeVisible();
    await axe(page, "trail");
  });
}
