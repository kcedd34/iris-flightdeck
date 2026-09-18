import { expect, test, type Page } from "@playwright/test";
import { disarm, setTheme, signIn } from "./setup/helpers";
import { adminRequest } from "./setup/users";

// Feature 006, User Story 3: the demo driver.
//
// It puts the portal through docs/demo-script.md in order, so recording the demonstration is an
// execution rather than an improvisation — and so it can be recorded again after any change.
//
// The rule it exists to protect: nothing is accelerated, stubbed, skipped or simulated. This file
// installs no route interception and fakes no response; every wait you see is the instance's own.
//
// Two different things are measured, and it matters that they are not confused. The **work** time is
// how long the portal took — it is reported, never padded, and it is what a viewer compares the
// recording against. The **minimum** is presentation pacing: how long the shot stays on screen so
// the viewer can read it. Holding a screen open is not hiding latency; shortening a wait would be,
// and nothing here does that. What the driver enforces is that each shot actually drove the portal:
// a shot that issued no request to the instance is a shot showing a static page, and it fails.
//
// It does not run in the default sweep: set FD_DEMO=1, and add --headed to record.

const SHOTS: Record<string, number> = {
  "1 instruments": 45,
  "2 palette": 20,
  "3 dry-run": 40,
  "4 safe mode": 25,
  "5 web apps and REST": 35,
  "6 permissions": 30,
  "7 security and secrets": 25,
  "8 tasks to logs": 30,
  "9 log stream": 45,
};

test.skip(!process.env.FD_DEMO, "demo driver: set FD_DEMO=1 (add --headed to record)");

/** Ask the instance to run the demonstration task that fails on purpose, and wait for the failure. */
async function runFailingTask(): Promise<void> {
  const list = await adminRequest("GET", "/tasks", {});
  const tasks = ((list.json as { result?: { Name: string; Id: number }[] })?.result ?? []);
  const failing = tasks.find((task) => task.Name === "FD Demo failing task");
  if (!failing) return;
  // RunNow is required by the operation's own schema; without it the instance answers 400.
  await adminRequest("POST", "/task/run", { id: String(failing.Id) }, { RunNow: true });
  // The instance's task manager decides when to run it, so this waits a short while and no longer.
  // If the run has not been recorded by then the shot shows the history bands instead and says so:
  // the demo never pretends to a failure the instance has not had.
  for (let attempt = 0; attempt < 20; attempt++) {
    const history = await adminRequest("GET", "/task/history", { id: String(failing.Id) });
    const rows = ((history.json as { result?: { TaskId: number; Result: string }[] })?.result ?? []);
    if (rows.some((row) => row.TaskId === failing.Id && row.Result === "Error")) return;
    await new Promise((resolve) => setTimeout(resolve, 1_000));
  }
}

/** The demonstration task that fails on purpose, if this install has recorded a failed run. */
async function failedTask(page: Page): Promise<string | null> {
  const rows = await page.evaluate(async () => {
    const response = await fetch("/api/flightdeck/v1/domains/tasks/task?maxRows=500", { headers: { "X-FlightDeck-Tab": "demo" } });
    return (await response.json()) as { items: { displayName: string; facts: { lastResult?: string } }[] };
  });
  return rows.items.find((item) => item.facts.lastResult === "Error")?.displayName ?? null;
}
test.describe.configure({ timeout: 900_000 });

/** Requests this run made to FlightDeck's own API, counted so every shot can prove it drove the portal. */
let calls = 0;

/**
 * One shot: run it, then hold the screen until the shot has occupied its declared minimum.
 *
 * The hold is presentation pacing — time for a viewer to read what is on screen — and it is the
 * opposite of hiding latency: the work happens first, at whatever speed the instance works, and only
 * the remainder is waited out. A shot that overruns its minimum is fine and is reported; a shot that
 * cannot reach it has done less than the script claims, and that fails.
 */
async function shot(page: Page, name: string, body: () => Promise<void>) {
  const minimum = SHOTS[name]!;
  const before = calls;
  const started = Date.now();
  await body();
  const worked = (Date.now() - started) / 1000;
  const requests = calls - before;
  const remaining = minimum - worked;
  if (remaining > 0) await page.waitForTimeout(remaining * 1000);
  const total = (Date.now() - started) / 1000;
  console.log(`shot ${name}: work ${worked.toFixed(1)}s, ${requests} API requests, on screen ${total.toFixed(1)}s`);
  // The real check. Padding the screen time would make a timing assertion vacuous — the hold always
  // reaches the minimum — so what is asserted instead is that the portal was actually driven.
  expect(requests, `shot "${name}" issued no request to the instance: it showed a static page`).toBeGreaterThan(0);
}

test("the demo, shot by shot, at the portal's own speed", async ({ page, context }) => {
  context.on("request", (request) => {
    if (request.url().includes("/api/flightdeck/")) calls++;
  });
  // Shot 8 needs a failed run to show. On a fresh install the demonstration task that fails on
  // purpose is scheduled but has not run yet, so the demo asks the instance to run it now and waits
  // for the failure to be recorded — a real wait, on real work, which is the shot.
  await runFailingTask();
  await signIn(page);
  await setTheme(page, "dark");

  // 1. The cluster, filling. The series takes time to draw, and that is the shot: an empty canvas is
  //    what this screen looks like in its first second and is the one state the demo must not show.
  await shot(page, "1 instruments", async () => {
    await page.goto("system/instruments");
    await expect(page.getByTestId("instrument-cluster")).toBeVisible();
    const series = page.getByTestId("instrument-series").first();
    await expect
      .poll(
        async () =>
          series.evaluate((node) => {
            const canvas = node as HTMLCanvasElement;
            const image = canvas.getContext("2d")!.getImageData(0, 0, canvas.width, canvas.height).data;
            let painted = 0;
            for (let i = 3; i < image.length; i += 4) if (image[i] !== 0) painted++;
            return painted;
          }),
        { timeout: 30_000, intervals: [1_000] },
      )
      .toBeGreaterThan(0);
  });

  // 2. Driven by name, not by menu.
  await shot(page, "2 palette", async () => {
    await page.keyboard.press("Control+k");
    await page.getByTestId("palette-input").fill("FD_Demo");
    const palette = page.getByTestId("command-palette");
    await expect(palette.locator("[cmdk-item]", { hasText: "FD_Demo_Operator" })).toBeVisible();
    await expect(palette.locator("[cmdk-group]").first()).toBeVisible();
    await page.keyboard.press("Escape");
  });

  // 3. The rehearsal, and Cancel. Nothing is applied: the point of the shot is what it costs, shown
  //    before it happens.
  await shot(page, "3 dry-run", async () => {
    await page.goto(`permissions/roles?inspect=${encodeURIComponent("permissions/role:FD_Demo_Operator")}`);
    await expect(page.getByTestId("entity-inspector").getByRole("heading", { name: "FD_Demo_Operator" })).toBeVisible();
    await disarm(page);
    await page.getByTestId("action-DELETE-v2-security-role-delete").click();
    const dryRun = page.getByTestId("dry-run");
    await expect(dryRun).toBeVisible();
    await expect(dryRun.getByTestId("dry-run-impact")).toBeVisible();
    await expect(dryRun.getByTestId("dry-run-apply")).toBeDisabled();
    await dryRun.getByRole("button", { name: "Cancel" }).click();
    await expect(dryRun).toHaveCount(0);
  });

  // 4. Safe mode is per tab: a second tab starts read-only however this one was left.
  await shot(page, "4 safe mode", async () => {
    const second = await context.newPage();
    await second.goto("./");
    await expect(second.getByTestId("safe-mode-indicator")).toHaveText("Safe mode");
    await second.close();
    await expect(page.getByTestId("safe-mode-indicator")).toBeVisible();
  });

  // 5. Exposure markers, then a real request dispatched in-process against this instance.
  await shot(page, "5 web apps and REST", async () => {
    await page.goto("web-apps/web-applications");
    await expect(page.getByTestId("list-row").first()).toBeVisible();
    await page.goto("web-apps/rest-apis");
    await expect(page.getByTestId("list-row").first()).toBeVisible();
    // The executor lives in a service's inspector, not on the list: open FlightDeck's own API, whose
    // specification the instance publishes, and run a request against it.
    await page.goto(
      `web-apps/rest-apis?inspect=${encodeURIComponent(`web-apps/rest-service:?${new URLSearchParams({ webApplication: "/api/flightdeck" }).toString()}`)}`,
    );
    await expect(page.getByTestId("entity-inspector").getByRole("heading", { name: "/api/flightdeck" })).toBeVisible();
    await page.getByTestId("rest-path").fill("/api/flightdeck/v1/session/capabilities");
    await page.getByTestId("rest-headers").fill("X-FlightDeck-Tab: demo");
    await page.getByTestId("rest-execute").click();
    await expect(page.getByTestId("rest-response").getByTestId("rest-status")).toHaveText("200");
  });

  // 6. A privilege is never shown without the chain of roles that grants it.
  await shot(page, "6 permissions", async () => {
    await page.goto(`permissions/roles?inspect=${encodeURIComponent("permissions/role:FD_Demo_Operator")}`);
    const inspector = page.getByTestId("entity-inspector");
    await expect(inspector).toContainText("FD_Demo_Reports");
    await page.goto("permissions/users");
    await expect(page.getByTestId("list-row").first()).toBeVisible();
  });

  // 7. Write-only secrets, and the declined encryption writes with their reason.
  await shot(page, "7 security and secrets", async () => {
    await page.goto("security/wallet");
    await expect(page.getByTestId("domain-list")).toBeVisible();
    await page.goto("security/encryption");
    await expect(page.locator("main")).toBeVisible();
  });

  // 8. The correlation contract: the stream opens filtered on the run's task and window, and says so.
  await shot(page, "8 tasks to logs", async () => {
    await page.goto("tasks/tasks");
    await expect(page.getByTestId("list-row").first()).toBeVisible();
    const failed = await failedTask(page);
    // The demonstration task that fails on purpose gives this shot its subject. If the install has
    // recorded no failed run yet, the shot shows the list and its history bands rather than
    // inventing a failure — the script says what it shows, and it must stay true on any install.
    if (failed) {
      await page.getByRole("button", { name: new RegExp(failed) }).click();
      await expect(page.getByTestId("task-runs")).toBeVisible();
      await page.getByTestId("task-run-logs-0").click();
      await expect(page.getByTestId("logs-correlated")).toContainText("Filtered on task");
    } else {
      console.log('shot 8: no failed run recorded on this install; showing the list and its history bands');
      await expect(page.getByTestId("history-band").first()).toBeVisible();
    }
  });

  // 9. Five sources, one line, and the original record behind it.
  await shot(page, "9 log stream", async () => {
    await page.goto("logs/stream");
    await expect(page.getByTestId("logs-sources")).toBeVisible();
    await expect(page.getByTestId("log-list").getByRole("listitem").first()).toBeVisible();
    await page.getByTestId("log-list").getByRole("listitem").first().click();
    await expect(page.getByTestId("log-event")).toBeVisible();
    await page.getByTestId("follow-toggle").click();
    await expect(page.getByTestId("logs-state")).toContainText("Following");
  });
});
