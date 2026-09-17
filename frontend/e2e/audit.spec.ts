import { execFileSync } from "node:child_process";
import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Page } from "@playwright/test";
import { disarm, setTheme, signIn } from "./setup/helpers";
import { adminRequest, ensureUser } from "./setup/users";

// Feature 002 polish: the credential audit extended to edits, test requests, the trail export and
// copied curl (T083, SC-010), and axe on the new surfaces in both themes (T084).

const AUDIT = { user: "fd_e2e_audit", password: "Audit-Pass-7Q2x-2026" };
const APP = "/csp/fd-e2e-audit";
const CONTAINER = process.env.FD_CONTAINER ?? "iris-flightdeck-iris-1";
const WCAG = ["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"];

test.beforeAll(async () => {
  await ensureUser(AUDIT.user, AUDIT.password, ["%All"]);
  await adminRequest("DELETE", "/web-app", { name: APP });
  const created = await adminRequest("PUT", "/web-app", { name: APP }, { NameSpace: "USER", Description: "FlightDeck audit application", Enabled: true, AutheEnabled: 32 });
  expect(created.status).toBe(201);
});

test.afterAll(async () => {
  await adminRequest("DELETE", "/web-app", { name: APP });
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
  // Export the trail.
  await dryRun.getByRole("button", { name: "Open session trail" }).click();
  const [download] = await Promise.all([page.waitForEvent("download"), page.getByTestId("trail-export").click()]);
  const chunks: Buffer[] = [];
  for await (const chunk of await download.createReadStream()) chunks.push(chunk as Buffer);
  const exported = Buffer.concat(chunks).toString("utf8");

  const basic = Buffer.from(`${AUDIT.user}:${AUDIT.password}`).toString("base64");
  const needles = [AUDIT.password, basic, "Authorization"];
  const storage = await page.evaluate(() => JSON.stringify({ session: { ...window.sessionStorage }, local: { ...window.localStorage } }));
  const cookies = JSON.stringify(await context.cookies());
  for (const [where, text] of Object.entries({ exported, curl, storage, cookies })) {
    for (const needle of needles) expect(text.includes(needle), `${needle.slice(0, 6)}… in ${where}`).toBe(false);
  }
  expect(curl).toContain("-u '<user>:<password>'");
  expect(exported).toContain("Audited edit");

  let logs: string | null;
  try {
    logs = execFileSync("docker", ["exec", CONTAINER, "sh", "-c", `grep -rlF -e '${AUDIT.password}' -e '${basic}' /durable/iris/mgr --include='*.log' || true`], { encoding: "utf8" });
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
    for (const section of ["web-applications", "percent-class-access", "rest-apis"]) {
      await page.goto(`web-apps/${section}`);
      await expect(page.getByTestId("list-row").first()).toBeVisible();
      await axe(page, section);
    }
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
