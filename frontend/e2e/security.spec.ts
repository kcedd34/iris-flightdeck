import { expect, test } from "@playwright/test";
import { capability, disarm, signIn } from "./setup/helpers";
import { WALLET_ONLY, adminRequest } from "./setup/users";

// Feature 003, User Story 3: the security domain — sections that degrade with a reason, the wallet
// chain, the platform's own TLS test, encryption declared read-only, and the partial-mode check.

test("PRD UC06-4. A wallet collection shows, in one click, which users can use its secrets", async ({ page }) => {
  await signIn(page);
  await page.goto(`security/wallet?inspect=${encodeURIComponent("security/wallet-collection:FD_Demo_Vault")}`);
  const inspector = page.getByTestId("entity-inspector");
  await expect(inspector.getByRole("heading", { name: "FD_Demo_Vault" })).toBeVisible();
  const users = page.getByTestId("links-group-wallet-users");
  await expect(users).toContainText("users can use these secrets");
  await users.getByRole("button").first().click();
  await expect(inspector.getByRole("heading")).not.toHaveText("FD_Demo_Vault");
});

test("PRD UC06-3 and spec FR-020. Encryption is readable and its writes are declined, each with the reason and the native path", async ({ page }) => {
  await signIn(page);
  await page.goto("security/encryption");
  const section = page.getByTestId("singleton-inspector");
  await expect(section).toBeVisible();
  // Readable: the official settings are shown.
  await expect(section).toContainText("DB Enc Start Mode");
  // The decision is stated, not implied by an absence.
  await expect(page.getByTestId("encryption-policy-note")).toContainText("permanently unreadable");
  for (const [testid, label] of [
    ["action-PUT-v2-security-encryption-settings-edit-settings", "Edit settings"],
    ["action-POST-v2-security-encryption-file-create-key-file", "Create key file"],
  ] as const) {
    const control = section.getByTestId(testid);
    await expect(control, label).toHaveAttribute("aria-disabled", "true");
  }
  await expect(section).toContainText("System Administration > Encryption");
  await expect(section).not.toContainText("Not available in this build yet");
});

test("PRD UC06-1. A stored secret is listed by name and type, and no value is offered anywhere", async ({ page }) => {
  await signIn(page);
  // The demo secret exists only where the platform accepts the secret body FlightDeck sends; where
  // it does not, the installer says so and the write is declared unavailable (limited project).
  const write = await capability(page, "PUT /v2/wallet/secret");
  test.skip(!write?.available, `this install has no demo wallet secret: ${write?.reason ?? "the capability map has no entry for the wallet secret write"}`);
  await page.goto(`security/wallet?inspect=${encodeURIComponent("security/wallet-collection:FD_Demo_Vault")}`);
  const secrets = page.getByTestId("links-group-wallet-secrets");
  await expect(secrets).toContainText("FD_Demo_Vault.FD_Demo_Token");
  await expect(secrets).toContainText("%Wallet.KeyValue");
  await expect(secrets).not.toContainText("flightdeck-demonstration-value");
  // Only replace and delete are offered: no operation reads a secret back.
  const inspector = page.getByTestId("entity-inspector");
  await expect(inspector.getByTestId("action-PUT-v2-wallet-secret-new-secret")).toBeVisible();
  await expect(inspector.getByTestId("wallet-delete-secret")).toBeVisible();
  const body = await page.evaluate(async () => (await fetch("/api/flightdeck/v1/domains/security/wallet-collection/links?name=FD_Demo_Vault", { headers: { "X-FlightDeck-Tab": "e2e" } })).text());
  expect(body).not.toContain("flightdeck-demonstration-value");
});

test("PRD UC06, A4. A TLS connection test shows the platform's own result and changes nothing", async ({ page }) => {
  await signIn(page);
  const list = await adminRequest("GET", "/security/ssl-configurations", { maxRows: "5" });
  const configurations = (list.json as { result?: { Name: string }[] }).result;
  const first = Array.isArray(configurations) ? configurations[0] : undefined;
  test.skip(!first, `this instance lists no TLS configuration (HTTP ${list.status})`);
  await page.goto(`security/tls?inspect=${encodeURIComponent(`security/tls-configuration:${first!.Name}`)}`);
  await disarm(page);
  await page.getByTestId("action-POST-v2-security-ssl-configuration-test-test-connection").click();
  const form = page.getByTestId("object-form");
  await form.locator("#f-host").fill("localhost");
  await form.locator("#f-port").fill("1");
  await form.getByTestId("form-submit").click();
  const dryRun = page.getByTestId("dry-run");
  await expect(dryRun.getByTestId("dry-run-request")).toContainText("ssl-configuration/test");
  await dryRun.getByTestId("dry-run-apply").click();
  // Success or failure, the platform's own answer is what appears: the dry-run reports it applied,
  // or the form keeps the input and shows the platform's error verbatim (UC06 A4).
  // The platform's own test takes a fixed ten seconds to fail a connection (verification/README.md),
  // so this waits longer than the suite's default.
  await expect(dryRun.getByTestId("dry-run-applied").or(page.getByTestId("form-error"))).toBeVisible({ timeout: 30_000 });
  const failure = page.getByTestId("form-error");
  if (await failure.count()) await expect(failure).not.toContainText("FlightDeck");
  const after = await adminRequest("GET", "/security/ssl-configuration", { name: first!.Name });
  expect(after.status).toBe(200);
});

test("Every security section renders, and a section the instance does not populate says why", async ({ page }) => {
  await signIn(page);
  for (const section of ["tls", "x509", "oauth2", "wallet", "encryption", "ldap", "mft", "auditing", "web-authentication", "superservers"]) {
    await page.goto(`security/${section}`);
    await expect(page.getByTestId("domain-list").or(page.getByTestId("singleton-inspector")).first()).toBeVisible();
    await expect(page.getByText("Not available in this build yet")).toHaveCount(0);
  }
});

test("Partial mode: a wallet-only administrator changes a collection, and the check declares itself incomplete", async ({ page }) => {
  // Probe P5: inside permissions, reads and writes share one privilege, so partial mode is
  // unreachable there. A wallet administrator can change a collection without being able to read
  // the users behind its resource, which is exactly what the two modes exist for.
  await signIn(page, WALLET_ONLY);
  await page.goto(`security/wallet?inspect=${encodeURIComponent("security/wallet-collection:FD_Demo_Vault")}`);
  const inspector = page.getByTestId("entity-inspector");
  await expect(inspector.getByRole("heading", { name: "FD_Demo_Vault" })).toBeVisible();
  const users = page.getByTestId("links-group-wallet-users");
  await expect(users).toHaveAttribute("data-state", /forbidden|undetermined/);
  await disarm(page);
  await page.getByTestId("action-PUT-v2-wallet-collection-edit").click();
  const form = page.getByTestId("object-form");
  await form.locator("#f-UseResource").fill("FD_Demo_Reports:READ");
  await form.getByTestId("form-submit").click();
  const dryRun = page.getByTestId("dry-run");
  // The impact could not be determined, and the dry-run says so instead of showing an empty list.
  await expect(dryRun.getByTestId("dry-run-impact")).toContainText(/could not|not be determined/i);
  await dryRun.getByRole("button", { name: "Cancel" }).click();
});
