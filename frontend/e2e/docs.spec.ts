import { expect, test } from "@playwright/test";
import { disarm, setTheme, signIn } from "./setup/helpers";
import { administrators } from "./setup/administrators";
import { ADMIN, adminRequest } from "./setup/users";

// Feature 006, User Story 1: the documentation images, produced from the running portal.
//
// These are not tests of the portal — they are the README's images, captured by a test so they
// cannot outlive the screens they show. A hand-taken screenshot of a screen that has since changed
// is a silent lie in the most visible place in the repository, and images are not reviewed the way
// text is. If a route or a test id here no longer exists, this fails instead.
//
// It does not run in the default sweep: a capture failure must be legible on its own rather than
// buried among the other projects' results. Set FD_CAPTURE=1 to produce the images.

const OUT = "../docs/img";

// The dry-run image needs someone to lose something, or the impact panel has nothing to report and
// the picture argues nothing. The capture creates that subject and removes it again, so the image is
// reproducible on any install rather than depending on whatever a previous test run left behind.
const HOLDER = "fd_demo_reporter";
const ROLE = "FD_Demo_Operator";

test.skip(!process.env.FD_CAPTURE, "documentation capture: set FD_CAPTURE=1 to rewrite docs/img");

test.beforeAll(async () => {
  await adminRequest("DELETE", "/security/user", { name: HOLDER });
  await adminRequest("POST", "/security/user", { name: HOLDER }, {
    Password: "Fd-Demo-2026",
    User: { Enabled: true, ChangePassword: false, FullName: "FlightDeck demo reporter", Roles: [ROLE] },
  });
});

test.afterAll(async () => {
  await adminRequest("DELETE", "/security/user", { name: HOLDER });
});

test("capture: the instrument cluster, with live readings", async ({ page }) => {
  await signIn(page);
  await setTheme(page, "dark");
  await page.goto("system/instruments");
  const cluster = page.getByTestId("instrument-cluster");
  await expect(cluster).toBeVisible();
  for (const id of ["cpu", "memory", "disk", "processes"]) {
    await expect(page.getByTestId(`instrument-${id}`), id).toBeVisible();
  }
  // The series must have something in it: an empty canvas is what the screen looks like in its first
  // second, and that is the one state this image must not show.
  const first = await page.getByTestId("instrument-value-cpu").textContent();
  await expect
    .poll(async () => page.getByTestId("instrument-value-cpu").textContent(), { timeout: 30_000, intervals: [500] })
    .not.toBe(first);
  // Let the sliding window actually fill. The series is the argument this image makes — a time
  // series drawn on canvas — and a canvas with three points draws nothing worth photographing.
  // Series.tsx strokes only from the second point on, so a short dwell here is an empty picture.
  await page.waitForTimeout(40_000);
  await expect
    .poll(async () => page.getByTestId("instrument-series").first().evaluate((node) => (node as HTMLCanvasElement).width), { timeout: 10_000 })
    .toBeGreaterThan(0);
  // The viewport, not the element: the argument this image makes is the whole shell — glareshield,
  // rail and the cluster together — which is what a reader sees when they open the portal.
  await page.screenshot({ path: `${OUT}/instruments.png` });
});

test("capture: the command palette, the interaction the portal is named for", async ({ page }) => {
  await signIn(page);
  await setTheme(page, "dark");
  await page.goto("system/instruments");
  await expect(page.getByTestId("instrument-cluster")).toBeVisible();
  await page.keyboard.press("Control+k");
  await page.getByTestId("palette-input").fill("FD_Demo");
  const palette = page.getByTestId("command-palette");
  await expect(palette.locator("[cmdk-item]", { hasText: "FD_Demo_Operator" })).toBeVisible();
  // Grouped by domain is the point of the picture: one query, results from several domains at once.
  await expect(palette.locator("[cmdk-group]").nth(1)).toBeVisible();
  await page.screenshot({ path: `${OUT}/palette.png` });
});

test("capture: a dry-run with its impact analysis", async ({ page }) => {
  await signIn(page);
  await setTheme(page, "dark");
  await page.goto(`permissions/roles?inspect=${encodeURIComponent(`permissions/role:${ROLE}`)}`);
  await expect(page.getByTestId("entity-inspector").getByRole("heading", { name: ROLE })).toBeVisible();
  await disarm(page);
  await page.getByTestId("action-DELETE-v2-security-role-delete").click();
  const dryRun = page.getByTestId("dry-run");
  await expect(dryRun).toBeVisible();
  const impact = dryRun.getByTestId("dry-run-impact");
  await expect(impact).toBeVisible();
  // The impact must actually name what it costs, or the image shows an empty box.
  await expect(impact).toContainText(HOLDER);
  // Nothing is applied: the point of the picture is the rehearsal, and the capture must leave the
  // instance exactly as it found it.
  await page.screenshot({ path: `${OUT}/dry-run.png` });
  await dryRun.getByRole("button", { name: "Cancel" }).click();
  await expect(dryRun).toHaveCount(0);
});

// The two added for the README's tour, at the resolution the tour is read at. The first three stay at
// the project's 1440x900 until they are recaptured.
test.describe("at 1920x1080", () => {
  test.use({ viewport: { width: 1920, height: 1080 } });

  test("capture: the unified log stream, with an event open", async ({ page }) => {
    await signIn(page);
    await setTheme(page, "dark");
    await page.goto("logs/stream");
    await expect(page.getByTestId("logs-sources")).toBeVisible();
    const list = page.getByTestId("log-list").getByRole("listitem");
    await expect(list.first()).toBeVisible();
    // Several sources must have reported, or the picture is one log with a new name. The stream is
    // settled when the row count stops moving between two reads.
    await expect
      .poll(async () => {
        const before = await list.count();
        await page.waitForTimeout(1_500);
        return before > 0 && before === (await list.count());
      }, { timeout: 30_000, intervals: [0] })
      .toBe(true);
    await list.first().click();
    // The original record behind the normalised line is the argument this image makes.
    await expect(page.getByTestId("log-event")).toBeVisible();
    await page.screenshot({ path: `${OUT}/log-stream.png` });
  });

  test("capture: the last-administrator refusal", async ({ page }) => {
    // The refusal fires only when it is true, so the capture makes it true: every other counted
    // administrator is disabled through the official API for the length of this test and re-enabled
    // in the finally, exactly as the demo's shot 7 does. Nothing is staged in the portal.
    const keep = ADMIN.user;
    const suspended: string[] = [];
    try {
      for (const name of (await administrators()) ?? []) {
        if (name === keep) continue;
        await adminRequest("PUT", "/security/user", { name }, { Enabled: false });
        suspended.push(name);
      }
      await signIn(page);
      await setTheme(page, "dark");
      await page.goto(`permissions/users?inspect=${encodeURIComponent(`permissions/user:${keep}`)}`);
      await expect(page.getByTestId("entity-inspector").getByRole("heading", { name: keep })).toBeVisible();
      await disarm(page);
      await page.getByTestId("action-PUT-v2-security-user-edit").click();
      const form = page.getByTestId("object-form");
      await form.locator("#f-Enabled").uncheck();
      await form.getByTestId("form-submit").click();
      const dryRun = page.getByTestId("dry-run");
      await expect(dryRun.getByTestId("dry-run-message")).toContainText("no administrator");
      await expect(dryRun.getByTestId("dry-run-apply")).toBeDisabled();
      await page.waitForLoadState("networkidle");
      await page.screenshot({ path: `${OUT}/self-protection.png` });
      await dryRun.getByRole("button", { name: "Cancel" }).click();
      await expect(dryRun).toHaveCount(0);
    } finally {
      for (const name of suspended) await adminRequest("PUT", "/security/user", { name }, { Enabled: true });
    }
  });
});
