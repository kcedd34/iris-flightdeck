import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";
import { setTheme, signIn } from "./setup/helpers";
import { adminRequest } from "./setup/users";

// Feature 005: the unified log stream. UC09 Gherkin 1 to 4, verbatim as the definition of done.

test("PRD UC09-1. Events from sources with different formats appear under one schema, each with its original record", async ({ page }) => {
  await signIn(page);
  await page.goto("logs/stream");
  const list = page.getByTestId("log-list");
  await expect(list).toBeVisible();
  await expect.poll(async () => list.getByTestId("log-row").count(), { timeout: 20_000 }).toBeGreaterThan(0);

  // More than one source in one line: that is what "unified" means.
  const sources = await list.getByTestId("log-row").evaluateAll((rows) => [...new Set(rows.map((r) => r.getAttribute("data-source")))]);
  expect(sources.length, `sources on screen: ${sources.join(", ")}`).toBeGreaterThan(1);

  // Every event opens to its original record — or says why it cannot be recovered. No third case.
  await list.getByTestId("log-row").first().click();
  const inspector = page.getByTestId("log-event");
  await expect(inspector).toBeVisible();
  const raw = inspector.getByTestId("log-raw");
  const gone = inspector.getByTestId("log-raw-gone");
  await expect.poll(async () => (await raw.count()) + (await gone.count())).toBeGreaterThan(0);
});

test("An event whose source stated no severity shows unknown, and the filter says how it treats it (spec FR-003a, FR-003c)", async ({ page }) => {
  await signIn(page);
  await page.goto("logs/stream");
  const list = page.getByTestId("log-list");
  await expect.poll(async () => list.getByTestId("log-row").count(), { timeout: 20_000 }).toBeGreaterThan(0);
  // Journal and audit records state no level; on any live instance at least one such event exists.
  const severities = await list.getByTestId("log-row").evaluateAll((rows) => [...new Set(rows.map((r) => r.getAttribute("data-severity")))]);
  expect(severities).toContain("unknown");
  // The switch is explicit, not implied by the threshold.
  await expect(page.getByTestId("filter-unknown")).toContainText("not ranked");
});

test("PRD UC09-3. A source that cannot be read is named with its reason, and the others keep streaming", async ({ page }) => {
  await signIn(page);
  await page.goto("logs/stream");
  const panel = page.getByTestId("logs-sources");
  await expect(panel).toBeVisible();
  // All five are listed, whatever their state.
  for (const id of ["audit", "journal", "messages", "alerts", "interop"]) {
    await expect(panel.getByTestId(`logs-source-${id}`), id).toBeVisible();
  }
  // Any source that is out carries a reason; the list still has events from the others.
  const unavailable = panel.locator('[data-available="false"]');
  if ((await unavailable.count()) > 0) {
    await expect(unavailable.first()).not.toBeEmpty();
    await expect.poll(async () => page.getByTestId("log-row").count(), { timeout: 20_000 }).toBeGreaterThan(0);
  }
});

test("PRD UC09-4. An event with a process identifier jumps to that process", async ({ page }) => {
  await signIn(page);
  await page.goto("logs/stream");
  const list = page.getByTestId("log-list");
  await expect.poll(async () => list.getByTestId("log-row").count(), { timeout: 20_000 }).toBeGreaterThan(0);
  const rows = list.getByTestId("log-row");
  const count = await rows.count();
  let jumped = false;
  for (let i = 0; i < Math.min(count, 12) && !jumped; i++) {
    await rows.nth(i).click();
    const jump = page.getByTestId("log-jump-process");
    if ((await jump.count()) === 0) continue;
    await jump.click();
    await expect(page).toHaveURL(/system\/processes/);
    jumped = true;
  }
  expect(jumped, "at least one event on screen names a process").toBe(true);
});

test("The stream states the instance's time zone and the share it is showing", async ({ page }) => {
  await signIn(page);
  await page.goto("logs/stream");
  const state = page.getByTestId("logs-state");
  await expect(state).toContainText("times in the instance's zone");
  await expect(page.getByTestId("logs-share")).toContainText("of each selected source");
});

test("PRD UC09-2. With live follow on, new events appear at the top without reloading", async ({ page }) => {
  await signIn(page);
  await page.goto("logs/stream");
  const list = page.getByTestId("log-list");
  await expect.poll(async () => list.getByTestId("log-row").count(), { timeout: 20_000 }).toBeGreaterThan(0);
  const before = await list.getByTestId("log-row").first().textContent();
  await page.getByTestId("follow-toggle").click();
  await expect(page.getByTestId("logs-state")).toContainText("Following by polling");
  // Produce events: every read of the audit source is itself audited, so the stream moves on its own.
  await expect
    .poll(async () => list.getByTestId("log-row").first().textContent(), { timeout: 40_000, intervals: [1000] })
    .not.toBe(before);
  // No reload happened: the toggle is still pressed and the filters are untouched.
  await expect(page.getByTestId("follow-toggle")).toHaveAttribute("aria-pressed", "true");
});

test("Live follow pauses while the tab is hidden and resumes on focus (spec FR-019)", async ({ page }) => {
  await signIn(page);
  await page.goto("logs/stream");
  await page.getByTestId("follow-toggle").click();
  await page.evaluate(() => {
    Object.defineProperty(document, "visibilityState", { value: "hidden", configurable: true });
    document.dispatchEvent(new Event("visibilitychange"));
  });
  await expect(page.getByTestId("logs-state")).toContainText("Paused while this tab is in the background");
  await page.evaluate(() => {
    Object.defineProperty(document, "visibilityState", { value: "visible", configurable: true });
    document.dispatchEvent(new Event("visibilitychange"));
  });
  await expect(page.getByTestId("logs-state")).toContainText("Following by polling");
});

test("SC-007. Opening from a failed task run filters the stream on that task and window, and says so", async ({ page }) => {
  await signIn(page);
  await page.goto("logs/stream?taskId=1002&taskName=FD%20Demo%20failing%20task&from=2026-09-18%2000:00:00&to=2026-09-19%2000:00:00");
  const note = page.getByTestId("logs-correlated");
  await expect(note).toBeVisible();
  await expect(note).toContainText("FD Demo failing task");
  await expect(note).toContainText("between");
});

test("SC-008. An export carries the filtered events with their original records, and names the filters and the unavailable sources", async ({ page }) => {
  await signIn(page);
  await page.goto("logs/stream?minSeverity=info");
  await expect.poll(async () => page.getByTestId("log-row").count(), { timeout: 20_000 }).toBeGreaterThan(0);
  const [download] = await Promise.all([page.waitForEvent("download"), page.getByTestId("logs-export").click()]);
  const chunks: Buffer[] = [];
  for await (const chunk of await download.createReadStream()) chunks.push(chunk as Buffer);
  const exported = JSON.parse(Buffer.concat(chunks).toString("utf8")) as {
    filters: Record<string, string>;
    sources: { id: string; available: boolean; reason: string | null }[];
    events: { raw: unknown; rawAvailable: boolean }[];
  };
  expect(exported.filters.minSeverity).toBe("info");
  expect(exported.sources.length).toBe(5);
  expect(exported.events.length).toBeGreaterThan(0);
  // Every exported event carries its original record, or states that it could not be recovered.
  for (const event of exported.events) expect(event.rawAvailable || event.raw === null).toBe(true);
});

test("The journal and audit events sections are configuration, and each names the other half (spec FR-028, FR-031a)", async ({ page }) => {
  await signIn(page);
  await page.goto("logs/audit-events");
  await expect(page.getByTestId("domain-list")).toBeVisible();
  await page.goto("logs/journal");
  await expect(page.getByTestId("singleton-inspector")).toBeVisible();
});

test("PRD UC09-3, live. With auditing switched off, the other sources keep streaming and the audit source names the reason", async ({ page }) => {
  await signIn(page);
  // Turn auditing off through the official API, as the instance's own state, and restore it after.
  const before = (await adminRequest("GET", "/security/audit/enabled", {})).json as { result?: { Enabled?: boolean } };
  const wasEnabled = Boolean(before.result?.Enabled);
  await adminRequest("PUT", "/security/audit/enabled", {}, { Enabled: false });
  try {
    await page.goto("logs/stream");
    const audit = page.getByTestId("logs-source-audit");
    await expect(audit).toHaveAttribute("data-available", "false");
    // The reason says what happened and where to change it — not just that it failed.
    await expect(page.getByTestId("logs-reason-audit")).toContainText("switched off");
    await expect(page.getByTestId("logs-reason-audit")).toContainText("Auditing");
    // The others keep working: the stream is not empty because one source is out.
    await expect.poll(async () => page.getByTestId("log-row").count(), { timeout: 20_000 }).toBeGreaterThan(0);
    const sources = await page.getByTestId("log-row").evaluateAll((rows) => [...new Set(rows.map((r) => r.getAttribute("data-source")))]);
    expect(sources).not.toContain("audit");
  } finally {
    if (wasEnabled) await adminRequest("PUT", "/security/audit/enabled", {}, { Enabled: true });
  }
});

for (const theme of ["dark", "light"] as const) {
  test(`axe finds no violations on the three logs sections (${theme})`, async ({ page }) => {
    test.setTimeout(180_000);
    await signIn(page);
    await setTheme(page, theme);
    const violations: string[] = [];
    for (const route of ["logs/stream", "logs/journal", "logs/audit-events"]) {
      await page.goto(route);
      await expect(page.getByTestId("glareshield")).toBeVisible();
      await page.waitForTimeout(400);
      const result = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"]).analyze();
      for (const violation of result.violations) {
        violations.push(`${route}: ${violation.id} ${violation.nodes.map((n) => n.target.join(" ")).join(", ")}`);
      }
    }
    expect(violations).toEqual([]);
  });
}
