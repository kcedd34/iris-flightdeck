import { expect, test, type Page } from "@playwright/test";
import { disarm, setTheme, signIn } from "./setup/helpers";
import { ADMIN, adminRequest } from "./setup/users";
import { Narration } from "./setup/narration";

// Feature 006, User Story 3: the demo driver.
//
// It puts the portal through docs/demo-script.md in order, so recording the demonstration is an
// execution rather than an improvisation — and so it can be recorded again after any change.
//
// It also writes a timed script of what happened while it ran (verification/demo-run.md by default,
// FD_DEMO_SCRIPT to put it elsewhere), so the author can narrate or subtitle over the recording
// knowing the instant of every beat. That file is written line by line as the run goes, never
// assembled at the end: a run that dies halfway must still leave the part that already played.
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
  "7 self-protection": 40,
  "8 security and secrets": 25,
  "9 tasks to logs": 30,
  "10 log stream": 45,
  "11 session trail": 25,
  "12 light theme": 20,
};

const SCRIPT = process.env.FD_DEMO_SCRIPT ?? "../verification/demo-run.md";

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

/** IRIS reports an account that never expires as this date; it is not an expiry. */
const NO_EXPIRY = "1840-12-31";

function expiredOn(date: string): boolean {
  if (!date) return false;
  const day = date.split(" ")[0];
  if (day === NO_EXPIRY) return false;
  return new Date(day) < new Date();
}

/** The administrators the server counts, by the same narrow rule the last-administrator check uses. */
async function administrators(): Promise<string[] | null> {
  const answer = await adminRequest("GET", "/security/users", { maxRows: "500" });
  const list = (answer.json as { result?: { Name: string }[] }).result;
  if (!Array.isArray(list)) return null;
  const counted: string[] = [];
  for (const { Name } of list) {
    const detail = (await adminRequest("GET", "/security/user", { name: Name })).json as { result?: { Enabled: boolean; ExpirationDate: string; Roles: string[] } };
    const user = detail.result;
    if (!user || !user.Enabled) continue;
    if (expiredOn(user.ExpirationDate)) continue;
    if (user.Roles.includes("%All") || user.Roles.includes("%Manager") || user.Roles.includes("%SecurityAdministrator") || user.Roles.includes("%Admin_Secure")) counted.push(Name);
  }
  return counted;
}

test.describe.configure({ timeout: 1_500_000 });

test("the demo, shot by shot, at the portal's own speed", async ({ page, context }) => {
  const script = new Narration(SCRIPT);

  /** Requests this run made to FlightDeck's own API, counted so every shot can prove it drove the portal. */
  let calls = 0;
  let polled = 0;
  let logApi = false;
  // Endpoints the portal asks for repeatedly by design: the cluster at one-second resolution and the
  // stream while following. Logging each one would bury the timeline, so they are counted instead.
  const POLLED = /\/(telemetry|instruments|vitals|logs\/events|async-result)/;

  // On the context, not the page: shot 4 opens a second tab, and a listener bound to the first one
  // sees none of its requests — which made that shot look like a static page and failed its own
  // guard. The guard was right; the listener was wrong.
  context.on("response", (response) => {
    const url = response.url();
    if (!url.includes("/api/flightdeck/")) return;
    calls++;
    const path = new URL(url).pathname;
    if (POLLED.test(path)) {
      polled++;
      return;
    }
    if (logApi) script.line("api", `\`${response.request().method()} ${path}\` → **${response.status()}**`);
  });

  /**
   * One shot: run it, then hold the screen until the shot has occupied its declared minimum.
   *
   * The hold is presentation pacing — time for a viewer to read what is on screen — and it is the
   * opposite of hiding latency: the work happens first, at whatever speed the instance works, and
   * only the remainder is waited out. A shot that overruns its minimum is fine and is reported; a
   * shot that cannot reach it has done less than the script claims, and that fails.
   */
  async function shot(name: string, body: () => Promise<void>, local?: string) {
    const minimum = SHOTS[name]!;
    const [number, ...rest] = name.split(" ");
    script.shotStart(Number(number), rest.join(" "));
    const before = calls;
    const started = Date.now();
    logApi = true;
    await body();
    logApi = false;
    const worked = (Date.now() - started) / 1000;
    const requests = calls - before;
    const remaining = minimum - worked;
    if (remaining > 0) {
      script.line("note", `Holding the screen for ${remaining.toFixed(1)}s so the viewer can read it. Nothing is waiting on the instance.`);
      await page.waitForTimeout(remaining * 1000);
    }
    const onScreen = (Date.now() - started) / 1000;
    script.shotEnd({ worked, onScreen, minimum, requests, held: calls - before - requests });
    console.log(`shot ${name}: work ${worked.toFixed(1)}s, ${requests} API requests, on screen ${onScreen.toFixed(1)}s`);
    // The real check. Padding the screen time would make a timing assertion vacuous — the hold always
    // reaches the minimum — so what is asserted instead is that the portal was actually driven.
    //
    // One shot legitimately talks to nobody: the session trail is kept in the browser tab and is
    // never persisted on the instance, and that is the thing the shot exists to show. It is not
    // exempted from the check, it is held to the opposite one — a shot that claims to be local and
    // then calls the instance has a false claim in it, and that fails too.
    if (local) {
      expect(requests, `shot "${name}" claims to be local (${local}) but called the instance ${requests} times`).toBe(0);
    } else {
      expect(requests, `shot "${name}" issued no request to the instance: it showed a static page`).toBeGreaterThan(0);
    }
  }

  // Pre-roll, before anything is on screen. Shot 9 needs a failed run to show: on a fresh install the
  // demonstration task that fails on purpose is scheduled but has not run yet, so the demo asks the
  // instance to run it now and waits for the failure to be recorded — a real wait, on real work.
  const prerollStarted = Date.now();
  await runFailingTask();
  script.recordPreroll((Date.now() - prerollStarted) / 1000);

  // The clock starts at the first visible frame of the application, so the timestamps line up with a
  // screen recording that was started before the command.
  await page.goto("./");
  await expect(page.locator('input[name="username"]')).toBeVisible();
  script.start();

  logApi = true;
  script.line("screen", "The sign-in form, which says FlightDeck stores no credentials.");
  await signIn(page);
  script.line("action", `Typed \`${ADMIN.user}\` and its password and pressed Sign in; the glareshield appeared with the instance's identity and its live vitals.`);
  await setTheme(page, "dark");
  script.line("action", "Switched to the dark theme, which is where the demonstration is recorded.");
  logApi = false;

  // 1. The cluster, filling. The series takes time to draw, and that is the shot: an empty canvas is
  //    what this screen looks like in its first second and is the one state the demo must not show.
  await shot("1 instruments", async () => {
    await page.goto("system/instruments");
    await expect(page.getByTestId("instrument-cluster")).toBeVisible();
    script.line("screen", "The instrument cluster: CPU, memory, shared memory, disk, processes and devices, each with its live reading.");
    script.line("action", "Opened the cluster; the canvases are empty for their first second, which is why this shot waits.");
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
    script.line("screen", "The series are drawing themselves at one-second resolution, from readings the portal takes for itself.");
    script.line("note", `Polled readings so far this shot: ${polled}. The window lives in this browser tab and is never persisted.`);
  });

  // 2. Driven by name, not by menu.
  await shot("2 palette", async () => {
    await page.keyboard.press("Control+k");
    script.line("action", "Pressed Ctrl+K; the command palette opened with the caret in it.");
    await page.getByTestId("palette-input").fill("FD_Demo");
    const palette = page.getByTestId("command-palette");
    await expect(palette.locator("[cmdk-item]", { hasText: "FD_Demo_Operator" })).toBeVisible();
    await expect(palette.locator("[cmdk-group]").first()).toBeVisible();
    script.line("screen", "Typing `FD_Demo` finds the demonstration roles, resources, tasks and wallet collection, grouped by domain.");
    script.line("note", "The palette searches the instance's own objects, not a list the portal keeps.");
    await page.keyboard.press("Escape");
    script.line("action", "Pressed Escape; the palette closed and returned focus to the screen behind it.");
  });

  // 3. The rehearsal, and Cancel. Nothing is applied: the point of the shot is what it costs, shown
  //    before it happens.
  await shot("3 dry-run", async () => {
    await page.goto(`permissions/roles?inspect=${encodeURIComponent("permissions/role:FD_Demo_Operator")}`);
    await expect(page.getByTestId("entity-inspector").getByRole("heading", { name: "FD_Demo_Operator" })).toBeVisible();
    script.line("screen", "The role FD_Demo_Operator is open, with the resources it grants and the accounts that hold it.");
    await disarm(page);
    script.line("action", "Turned off safe mode for this tab; the indicator went from Safe mode to Live — changes enabled.");
    await page.getByTestId("action-DELETE-v2-security-role-delete").click();
    const dryRun = page.getByTestId("dry-run");
    await expect(dryRun).toBeVisible();
    await expect(dryRun.getByTestId("dry-run-impact")).toBeVisible();
    await expect(dryRun.getByTestId("dry-run-apply")).toBeDisabled();
    script.line("screen", "The rehearsal: the fields that would change, the impact block naming who loses what, and Apply still disabled until the role's name is typed.");
    script.line("action", "Clicked Delete; the portal asked the instance what the change would cost and showed it. Nothing has been sent.");
    await dryRun.getByRole("button", { name: "Cancel" }).click();
    await expect(dryRun).toHaveCount(0);
    script.line("action", "Cancelled. The role is untouched — this is the shot: the cost is shown before the change, not after it.");
  });

  // 4. Safe mode is per tab: a second tab starts read-only however this one was left.
  await shot("4 safe mode", async () => {
    const second = await context.newPage();
    await second.goto("./");
    await expect(second.getByTestId("safe-mode-indicator")).toHaveText("Safe mode");
    script.line("screen", "A second tab, opened while the first one is live, starts read-only.");
    script.line("action", "Opened a new tab; its indicator reads Safe mode, because safe mode is per tab and is never remembered.");
    await second.close();
    await expect(page.getByTestId("safe-mode-indicator")).toBeVisible();
    script.line("action", "Closed it. The first tab is still live: one tab's state never reaches another.");
  });

  // 5. Exposure markers, then a real request dispatched in-process against this instance.
  await shot("5 web apps and REST", async () => {
    await page.goto("web-apps/web-applications");
    await expect(page.getByTestId("list-row").first()).toBeVisible();
    script.line("screen", "Every web application on the instance, each with a graded exposure marker: unauthenticated access, open API, disabled.");
    await page.goto("web-apps/rest-apis");
    await expect(page.getByTestId("list-row").first()).toBeVisible();
    script.line("screen", "The REST services the instance serves, discovered with their OpenAPI specifications.");
    // The executor lives in a service's inspector, not on the list: open FlightDeck's own API, whose
    // specification the instance publishes, and run a request against it.
    await page.goto(
      `web-apps/rest-apis?inspect=${encodeURIComponent(`web-apps/rest-service:?${new URLSearchParams({ webApplication: "/api/flightdeck" }).toString()}`)}`,
    );
    await expect(page.getByTestId("entity-inspector").getByRole("heading", { name: "/api/flightdeck" })).toBeVisible();
    await page.getByTestId("rest-path").fill("/api/flightdeck/v1/session/capabilities");
    await page.getByTestId("rest-headers").fill("X-FlightDeck-Tab: demo");
    script.line("action", "Typed a path and a header into the test executor, against this instance's own API.");
    await page.getByTestId("rest-execute").click();
    await expect(page.getByTestId("rest-response").getByTestId("rest-status")).toHaveText("200");
    script.line("screen", "The response came back 200, with its headers and body. The request was dispatched in-process: the executor opens no outbound connection.");
  });

  // 6. A privilege is never shown without the chain of roles that grants it.
  await shot("6 permissions", async () => {
    await page.goto(`permissions/roles?inspect=${encodeURIComponent("permissions/role:FD_Demo_Operator")}`);
    const inspector = page.getByTestId("entity-inspector");
    await expect(inspector).toContainText("FD_Demo_Reports");
    script.line("screen", "The role's effective privileges, each shown with the chain of roles that grants it — never a privilege without its provenance.");
    await page.goto("permissions/users");
    await expect(page.getByTestId("list-row").first()).toBeVisible();
    script.line("screen", "Every account on the instance, with the ones that are disabled or expired marked as such.");
  });

  // 7. Self-protection: the two refusals the portal makes about itself, and the one the platform
  //    makes for it. All three are real refusals on this instance; none is staged.
  await shot("7 self-protection", async () => {
    const counted = await administrators();
    const keep = ADMIN.user;
    const suspended: string[] = [];
    try {
      if (counted && counted.length > 1) {
        // The last-administrator predicate fails by permitting, so the only way to see it work is to
        // make the condition true: the instance really is narrowed to one counted administrator, and
        // really is restored afterwards. Said here so the narration does not claim otherwise.
        script.line("setup", `This instance counts ${counted.length} administrators. To reach the refusal, the others are disabled through the official API for the length of this shot, and re-enabled at the end of it.`);
        for (const name of counted) {
          if (name === keep) continue;
          await adminRequest("PUT", "/security/user", { name }, { Enabled: false });
          suspended.push(name);
        }
      }
      await page.goto(`permissions/users?inspect=${encodeURIComponent(`permissions/user:${keep}`)}`);
      await expect(page.getByTestId("entity-inspector").getByRole("heading", { name: keep })).toBeVisible();
      await disarm(page);
      await page.getByTestId("action-PUT-v2-security-user-edit").click();
      const form = page.getByTestId("object-form");
      await form.locator("#f-Enabled").uncheck();
      script.line("action", `Opened ${keep} and cleared Enabled — the account that is now the only administrator this instance has.`);
      await form.getByTestId("form-submit").click();
      const dryRun = page.getByTestId("dry-run");
      await expect(dryRun.getByTestId("dry-run-message")).toContainText("no administrator");
      await expect(dryRun.getByTestId("dry-run-apply")).toBeDisabled();
      script.line("screen", "The portal refuses: the change would leave the instance with no administrator, and it says what it counted and what it could not see.");
      script.line("note", "Apply is disabled. The server refuses the same change sent straight to it, so this is not an interface that merely hides the button.");
      await dryRun.getByRole("button", { name: "Cancel" }).click();
      await expect(dryRun).toHaveCount(0);
    } finally {
      for (const name of suspended) await adminRequest("PUT", "/security/user", { name }, { Enabled: true });
      if (suspended.length) script.line("setup", `The ${suspended.length} administrator${suspended.length === 1 ? "" : "s"} disabled for this shot ${suspended.length === 1 ? "has" : "have"} been re-enabled.`);
    }

    // The process serving this session, and a process the platform itself will not let anyone end.
    const processes = await page.evaluate(async () => {
      const response = await fetch("/api/flightdeck/v1/domains/system/process?maxRows=500", { headers: { "X-FlightDeck-Tab": "demo" } });
      const list = (await response.json()) as { items: { displayName: string; keys: { id: string }; facts: { isOwnSession?: boolean; canBeTerminated?: boolean } }[] };
      // isOwnSession is true when the process matches this session **or** merely happens to be the
      // one serving this request, and IRIS serves consecutive requests from different processes — so
      // a process picked on the second kind of match is gone by the time the screen opens it. Rather
      // than trust the flag, ask the server which of them it actually refuses, and put that one on
      // screen: a match by session holds still, a match by request does not.
      let own: string | null = null;
      for (const item of list.items.filter((candidate) => candidate.facts.isOwnSession)) {
        const preview = await fetch("/api/flightdeck/v1/mutations/preview", {
          method: "POST",
          headers: { "Content-Type": "application/json", "X-FlightDeck-Tab": "demo" },
          body: JSON.stringify({ operationId: "POST /v2/process/terminate", keys: item.keys, params: { id: item.keys.id } }),
        });
        const body = (await preview.json()) as { blocked?: { message?: string } };
        if ((body.blocked?.message ?? "").includes("your own session")) {
          own = item.keys.id;
          break;
        }
      }
      return {
        own,
        refused: list.items.find((item) => item.facts.canBeTerminated === false)?.keys.id ?? null,
      };
    });

    if (processes.own) {
      await page.goto(`system/processes?inspect=${encodeURIComponent(`system/process:?id=${processes.own}`)}`);
      await expect(page.getByTestId("entity-inspector")).toBeVisible();
      const terminate = page.locator(".actions button", { hasText: "Terminate" }).first();
      if ((await terminate.getAttribute("aria-disabled")) === "true") {
        script.line("screen", `Process ${processes.own} is the one serving this session, and Terminate is already disabled with the reason on it.`);
      } else {
        await terminate.click();
        const dryRun = page.getByTestId("dry-run");
        await expect(dryRun).toBeVisible();
        const message = await dryRun.getByTestId("dry-run-message").innerText().catch(() => "");
        if (message.includes("your own session")) {
          script.line("screen", `Process ${processes.own} is the one running this FlightDeck session. The portal refuses to end it: doing so would end the session mid-request.`);
          script.line("action", "Clicked Terminate; the refusal came back with the reason and a way out — end it from another session if you mean to.");
        } else {
          // Not a defect, and worth understanding before narrating over it: this instance reports no
          // CSP session on the process, so the rule matches on the process id — and IRIS serves
          // consecutive requests from different processes, so the one that was the session's when
          // the list was read has already been replaced by the time the screen opens it. The refusal
          // is real and fires on the request that meets it; it is simply not a thing a click can be
          // relied on to reach.
          script.line("note", `Process ${processes.own} was the session's when the list was read, and is no longer: this instance reports no CSP session on it, so the rule matches on the process id and IRIS moves the session between processes between requests. The refusal is real — it fired on the request that selected this process — but it is not something a click can be relied on to land on.`);
          script.line("screen", "The confirmation that did open, for a process the portal is willing to end, showing what ending it would cost.");
        }
        await dryRun.getByRole("button", { name: "Cancel" }).click();
      }
    } else {
      script.line("note", "No process on this instance reported itself as this session, so that refusal is not on screen in this run.");
    }

    if (processes.refused) {
      await page.goto(`system/processes?inspect=${encodeURIComponent(`system/process:?id=${processes.refused}`)}`);
      await expect(page.getByTestId("entity-inspector")).toBeVisible();
      const terminate = page.locator(".actions button", { hasText: "Terminate" }).first();
      await expect(terminate).toHaveAttribute("aria-disabled", "true");
      script.line("screen", `Process ${processes.refused} is a platform daemon. Terminate is disabled, and the reason beside it is the instance's own answer, not the portal's guess.`);
      script.line("note", "The schema carries what may be done to each object, and the control follows it. The interface never infers permission.");
    }
  });

  // 8. Write-only secrets, and the declined encryption writes with their reason.
  await shot("8 security and secrets", async () => {
    await page.goto("security/wallet");
    await expect(page.getByTestId("domain-list")).toBeVisible();
    script.line("screen", "The wallet: secrets are listed by name and never by value. They are set or replaced, never read back.");
    await page.goto("security/encryption");
    await expect(page.locator("main")).toBeVisible();
    script.line("screen", "Encryption is read here and not written: the eight write operations are declined by decision, each stating the reason and the native path that performs it.");
  });

  // 9. The correlation contract: the stream opens filtered on the run's task and window, and says so.
  await shot("9 tasks to logs", async () => {
    await page.goto("tasks/tasks");
    await expect(page.getByTestId("list-row").first()).toBeVisible();
    script.line("screen", "The task list, each row carrying a band of its recent runs so an intermittent failure is visible without opening anything.");
    const failed = await failedTask(page);
    // The demonstration task that fails on purpose gives this shot its subject. If the install has
    // recorded no failed run yet, the shot shows the list and its history bands rather than
    // inventing a failure — the script says what it shows, and it must stay true on any install.
    if (failed) {
      await page.getByRole("button", { name: new RegExp(failed) }).click();
      await expect(page.getByTestId("task-runs")).toBeVisible();
      script.line("action", `Opened ${failed}, whose last run failed, and its run history with the error the platform recorded.`);
      await page.getByTestId("task-run-logs-0").click();
      await expect(page.getByTestId("logs-correlated")).toContainText("Filtered on task");
      script.line("screen", "The log stream, already filtered on that task and the window of that run, and saying so above the results.");
      script.line("note", "That jump is the contract: from a failure to the logs of the period, without composing a query.");
    } else {
      console.log('shot 9: no failed run recorded on this install; showing the list and its history bands');
      script.line("note", "This install has recorded no failed run, so the shot shows the list and its history bands rather than inventing a failure.");
      await expect(page.getByTestId("history-band").first()).toBeVisible();
    }
  });

  // 10. Five sources, one line, and the original record behind it.
  await shot("10 log stream", async () => {
    await page.goto("logs/stream");
    await expect(page.getByTestId("logs-sources")).toBeVisible();
    await expect(page.getByTestId("log-list").getByRole("listitem").first()).toBeVisible();
    script.line("screen", "Five sources merged into one stream under a single schema: audit, journal, system messages, alerts and interoperability, each saying how much it read.");
    await page.getByTestId("log-list").getByRole("listitem").first().click();
    await expect(page.getByTestId("log-event")).toBeVisible();
    script.line("action", "Opened one line; the original record the source produced is kept behind the normalised fields, unedited.");
    await page.getByTestId("follow-toggle").click();
    await expect(page.getByTestId("logs-state")).toContainText("Following");
    script.line("action", "Turned on Follow; the stream is live. This is the axis the official API does not cover at all.");
  });

  // 11. The trail, and the export. Shot 7 refused two changes, and the refusals are in it.
  await shot("11 session trail", async () => {
    await page.keyboard.press("Control+k");
    await page.getByTestId("palette-input").fill("Session trail");
    await page.keyboard.press("Enter");
    const trail = page.getByTestId("trail-panel");
    await expect(trail).toBeVisible();
    script.line("action", "Opened the session trail from the palette, by name.");
    const entries = await trail.getByTestId("trail-entry").count();
    script.line("screen", `Everything this session proposed, ${entries} entr${entries === 1 ? "y" : "ies"} of it: what was applied, what was cancelled, and what the portal blocked, each with its reason.`);
    const download = page.waitForEvent("download");
    await trail.getByTestId("trail-export").click();
    const file = await download;
    script.line("action", `Exported it: \`${file.suggestedFilename()}\` came down. Secret fields appear in it as changed or unchanged and never as values.`);
    script.line("note", "The trail lives in this tab and is never persisted on the instance — which is why this shot makes no request at all, and is checked for making none.");
    expect(entries, "the trail has nothing in it, so this shot shows an empty panel").toBeGreaterThan(0);
    // The panel is modal: left open, its overlay covers the glareshield and the next shot's click on
    // the theme toggle never becomes actionable.
    await page.keyboard.press("Escape");
    await expect(trail).toHaveCount(0);
    script.line("action", "Closed the trail.");
  }, "the session trail is kept in the browser tab and never reaches the instance");

  // 12. The same portal in the light theme, which is a first-class theme and not an afterthought.
  await shot("12 light theme", async () => {
    await setTheme(page, "light");
    script.line("action", "Switched to the light theme from the glareshield; the choice is remembered per IRIS user.");
    await page.goto("system/instruments");
    await expect(page.getByTestId("instrument-cluster")).toBeVisible();
    script.line("screen", "The instrument cluster in light, with the same semantic palette: the state colours mean the same thing in both themes.");
    await page.goto("logs/stream");
    await expect(page.getByTestId("log-list").getByRole("listitem").first()).toBeVisible();
    script.line("screen", "And the log stream, where the severity colours carry meaning and are never the only signal.");
  });

  script.finish();
});
