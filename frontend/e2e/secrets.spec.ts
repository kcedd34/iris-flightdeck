import { expect, test, type Page } from "@playwright/test";
import { capability, disarm, signIn } from "./setup/helpers";
import { adminRequest } from "./setup/users";

// Feature 003, User Story 3: secrets are write-only in every layer (Constitution VI, spec FR-015,
// FR-017), and the two audit writes carry the grades the boundary decision demands (FR-021a).

const COLLECTION = "FD_E2E_Secrets";
const VALUE = "e2e-secret-value-2026";

test.beforeAll(async () => {
  await adminRequest("PUT", "/wallet/collection", { name: COLLECTION }, { UseResource: "FD_Demo_Reports:READ", EditResource: "FD_Demo_Reports:WRITE" });
});

test.afterAll(async () => {
  await adminRequest("DELETE", "/wallet/secret", { name: `${COLLECTION}.e2e_token` });
  await adminRequest("DELETE", "/wallet/collection", { name: COLLECTION });
});

async function openCollection(page: Page) {
  await page.goto(`security/wallet?inspect=${encodeURIComponent(`security/wallet-collection:${COLLECTION}`)}`);
  await expect(page.getByTestId("entity-inspector").getByRole("heading", { name: COLLECTION })).toBeVisible();
}

test.beforeEach(async ({ page }) => {
  await signIn(page);
  const write = await capability(page, "PUT /v2/wallet/secret");
  test.skip(!write?.available, `this install does not offer a wallet secret write: ${write?.reason ?? "the capability map has no entry for it"}`);
});

test("PRD UC06-1. A secret is created through the shared confirmation, and its value appears nowhere afterwards", async ({ page }) => {
  await openCollection(page);
  await disarm(page);
  await page.getByTestId("action-PUT-v2-wallet-secret-new-secret").click();
  const form = page.getByTestId("object-form");
  await form.locator("#f-secretName").fill("e2e_token");
  await form.locator("#f-type").selectOption("%Wallet.KeyValue");
  await form.locator("#f-secret").fill(VALUE);
  await form.getByTestId("form-submit").click();
  const dryRun = page.getByTestId("dry-run");
  // The collection's own listing is the prior state, so the affected row is shown before and after.
  await expect(dryRun.getByTestId(`dry-run-row-${COLLECTION}.e2e_token`)).toHaveAttribute("data-changed", "true");
  await expect(dryRun).not.toContainText(VALUE);
  await dryRun.getByTestId("dry-run-apply").click();
  await expect(dryRun.getByTestId("dry-run-applied")).toBeVisible();
  await dryRun.getByRole("button", { name: "Open session trail" }).click();
  const trail = page.getByTestId("trail-panel");
  await expect(trail.getByTestId("trail-entry").first()).toContainText(`${COLLECTION}.e2e_token`);
  const [download] = await Promise.all([page.waitForEvent("download"), trail.getByTestId("trail-export").click()]);
  const chunks: Buffer[] = [];
  for await (const chunk of await download.createReadStream()) chunks.push(chunk as Buffer);
  expect(Buffer.concat(chunks).toString("utf8")).not.toContain(VALUE);
  const storage = await page.evaluate(() => JSON.stringify(window.sessionStorage));
  expect(storage).not.toContain(VALUE);
  // Nor in the portal's own reads: the listing knows names and types only.
  const links = await page.evaluate(async (name) => (await fetch(`/api/flightdeck/v1/domains/security/wallet-collection/links?name=${name}`, { headers: { "X-FlightDeck-Tab": "e2e" } })).text(), COLLECTION);
  expect(links).toContain("e2e_token");
  expect(links).not.toContain(VALUE);
});

test("PRD UC06, A5. Deleting a collection that holds secrets states how many, and asks for the typed name", async ({ page }) => {
  await adminRequest("PUT", "/wallet/secret", { name: `${COLLECTION}.e2e_token` }, { Type: "%Wallet.KeyValue", WalletSecretConfig: { Secret: VALUE } });
  await openCollection(page);
  await disarm(page);
  await page.getByTestId("action-DELETE-v2-wallet-collection-delete").click();
  const dryRun = page.getByTestId("dry-run");
  await expect(dryRun.getByTestId("dry-run-impact")).toContainText("secret");
  await expect(dryRun.getByTestId("dry-run-confirm-input")).toBeVisible();
  await expect(dryRun.getByTestId("dry-run-apply")).toBeDisabled();
  await dryRun.getByRole("button", { name: "Cancel" }).click();
  const still = await adminRequest("GET", "/wallet/collection", { name: COLLECTION });
  expect(still.status).toBe(200);
});

test("Spec FR-021a. Purging audit records asks for the maximum confirmation and states the consequence; copying names the destination", async ({ page }) => {
  await page.goto("security/auditing");
  await disarm(page);
  await page.getByTestId("action-POST-v2-security-audit-record-purge-purge-records").click();
  let form = page.getByTestId("object-form");
  await form.getByTestId("form-submit").click();
  const dryRun = page.getByTestId("dry-run");
  await expect(dryRun.getByTestId("dry-run-acknowledge")).toBeVisible();
  await expect(dryRun).toContainText("erases the instance's own audit trail");
  await expect(dryRun.getByTestId("dry-run-apply")).toBeDisabled();
  await dryRun.getByRole("button", { name: "Cancel" }).click();
  // Cancelling the confirmation keeps the form with its input; leaving the form returns to the section.
  await page.getByTestId("object-form").getByRole("button", { name: "Cancel" }).click();

  await page.getByTestId("action-POST-v2-security-audit-record-copy-copy-records").click();
  form = page.getByTestId("object-form");
  await form.locator("#f-auditCopyNamespace").fill("USER");
  await form.getByTestId("form-submit").click();
  await expect(dryRun.getByTestId("dry-run-confirm-input")).toBeVisible();
  await expect(dryRun).toContainText("USER");
  await dryRun.getByRole("button", { name: "Cancel" }).click();
});

test("Reading audit records is not part of this domain: the boundary with the logs feature is mutation against reading", async ({ page }) => {
  await page.goto("security/auditing");
  const section = page.getByTestId("singleton-inspector");
  await expect(section).toBeVisible();
  // Writes are here (copy, purge, the setting); no control reads records, and no list of them exists.
  await expect(section.getByTestId("action-POST-v2-security-audit-record-purge-purge-records")).toBeVisible();
  await expect(page.getByTestId("domain-list")).toHaveCount(0);
  await expect(section.getByRole("button", { name: /view|list|read/i })).toHaveCount(0);
  // The operation itself exists in the capability map: the logs feature will own it.
  const capabilities = (await page.evaluate(async () => (await fetch("/api/flightdeck/v1/session/capabilities", { headers: { "X-FlightDeck-Tab": "e2e" } })).json())) as { entries: { operationId: string }[] };
  expect(capabilities.entries.some((e) => e.operationId === "POST /v2/security/audit/records")).toBe(true);
});
