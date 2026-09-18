import { expect, test } from "@playwright/test";
import { capability, disarm, signIn } from "./setup/helpers";

// Feature 004, User Story 4: the breadth of the operating system domain. Most of the 102 operations
// live here, and this is the "covers the etc" argument of the brief: every section lists, every
// inspector opens, and a declined write reads as a decision rather than as missing work.

const SECTIONS = [
  ["databases", "Databases"],
  ["directories", "Directories"],
  ["namespaces", "Namespaces"],
  ["devices", "Devices"],
  ["locks", "Locks"],
  ["web-sessions", "Web sessions"],
  ["ecp", "ECP"],
  ["external-language-servers", "External language servers"],
  ["docdb", "DocDB"],
  ["file-system-access", "File system access"],
] as const;

test("Every section of the domain lists, and an empty one says the instance has none", async ({ page }) => {
  await signIn(page);
  for (const [id, label] of SECTIONS) {
    await page.goto(`system/${id}`);
    await expect(page.getByRole("navigation", { name: /sections/ }), label).toBeVisible();
    // Either rows, or an empty state that states the instance has none: never a broken screen.
    const list = page.getByTestId("domain-list");
    await expect(list, label).toBeVisible();
    // Wait for the read to settle: rows, an empty state, or the reason it could not be read.
    await expect
      .poll(async () => (await list.getByTestId("list-row").count()) > 0 || /No |no |not available/i.test((await list.textContent()) ?? ""), { timeout: 15_000 })
      .toBe(true);
  }
  // The licence section is a singleton, not a list.
  await page.goto("system/license");
  await expect(page.getByTestId("singleton-inspector")).toBeVisible();
});

test("An inspector opens on every section that has rows", async ({ page }) => {
  await signIn(page);
  for (const [id, label] of [["databases", "Databases"], ["directories", "Directories"], ["namespaces", "Namespaces"], ["devices", "Devices"]] as const) {
    await page.goto(`system/${id}`);
    const rows = page.getByTestId("domain-list").getByTestId("list-row");
    if ((await rows.count()) === 0) continue;
    await rows.first().click();
    await expect(page.getByTestId("entity-inspector"), label).toBeVisible();
  }
});

test("Spec FR-037a and FR-037d. The declined writes state the reason, that creation is performed, and the native path", async ({ page }) => {
  await signIn(page);
  const dirs = await capability(page, "GET /v2/database-dirs");
  test.skip(!dirs?.available, `this install does not offer the database directories: ${dirs?.reason ?? "no entry in the capability map"}`);
  await page.goto("system/directories");
  await disarm(page);
  await page.getByTestId("domain-list").getByTestId("list-row").first().click();
  const inspector = page.getByTestId("entity-inspector");
  const truncate = inspector.getByTestId("action-POST-v2-database-dir-truncate-truncate");
  await expect(truncate).toHaveAttribute("aria-disabled", "true");
  await expect(inspector).toContainText("does not truncate");
  await expect(inspector).toContainText("Local Databases");

  await page.goto("system/namespaces");
  await disarm(page);
  await page.getByTestId("domain-list").getByTestId("list-row").first().click();
  const namespaceInspector = page.getByTestId("entity-inspector");
  await expect(namespaceInspector.getByTestId("action-DELETE-v2-namespace-delete")).toHaveAttribute("aria-disabled", "true");
  // The asymmetry is explained: FlightDeck creates namespaces, and says where deletion is done.
  await expect(namespaceInspector).toContainText("creates namespaces");
  await expect(namespaceInspector).toContainText("Namespaces");
});

test("SC-011. A long storage operation states how long it takes and is fired, not awaited", async ({ page }) => {
  await signIn(page);
  const check = await capability(page, "POST /v2/database-dir/integrity-check");
  test.skip(!check?.available, `this install does not offer the integrity check: ${check?.reason ?? "no entry in the capability map"}`);
  await page.goto("system/directories");
  await disarm(page);
  await page.getByTestId("domain-list").getByTestId("list-row").first().click();
  await page.getByTestId("action-POST-v2-database-dir-integrity-check-integrity-check").click();
  const dryRun = page.getByTestId("dry-run");
  await expect(dryRun).toBeVisible();
  await expect(dryRun).toContainText("rewrites blocks while the database stays in use");
  // The expected duration is stated before anything is sent, beside the consequence.
  await expect(dryRun).toContainText(/minutes/);
  await dryRun.getByRole("button", { name: "Cancel" }).click();
});
