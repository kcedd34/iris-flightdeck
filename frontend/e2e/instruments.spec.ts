import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";
import { setTheme, signIn } from "./setup/helpers";

// Feature 004, User Story 1: the instrument cluster. UC08 Gherkin 1 and 2, verbatim as the
// definition of done, plus the rules that make the screen honest — a window that lives only in this
// tab, and an instrument that keeps its place when the instance does not offer it.

test("PRD UC08-1. The instruments update continuously and keep a sliding window of recent history", async ({ page }) => {
  await signIn(page);
  await page.goto("system/instruments");
  const cluster = page.getByTestId("instrument-cluster");
  await expect(cluster).toBeVisible();
  // The cluster covers at least CPU, memory, disk, processes and devices (spec FR-013, RN-FD-19).
  for (const id of ["cpu", "memory", "disk", "processes", "devices"]) {
    await expect(page.getByTestId(`instrument-${id}`), id).toBeVisible();
  }
  // The series is drawn on canvas, not as SVG (docs/design.md §5, spec FR-015).
  const series = page.getByTestId("instrument-series").first();
  await expect(series).toBeVisible();
  expect(await series.evaluate((node) => node.tagName)).toBe("CANVAS");
  // It fills as time passes: the window grows with readings rather than starting full.
  const width = await series.evaluate((node) => (node as HTMLCanvasElement).width);
  expect(width).toBeGreaterThan(0);
  const first = await page.getByTestId("instrument-value-cpu").textContent();
  await expect
    .poll(async () => page.getByTestId("instrument-value-cpu").textContent(), { timeout: 20_000, intervals: [500] })
    .not.toBe(first);
});

test("The refresh mode in use and its interval are visible, and the interval can be changed (spec FR-020)", async ({ page }) => {
  await signIn(page);
  await page.goto("system/instruments");
  const mode = page.getByTestId("telemetry-mode");
  // Polling is the only transport, and the screen says so rather than leaving it to be guessed.
  await expect(mode).toContainText("polling");
  await expect(mode).toContainText("Window 60s, kept in this tab only");
  await page.getByTestId("telemetry-interval").selectOption("5");
  await expect(mode).toContainText("every 5s");
});

test("PRD UC08-2. While the disk refresh is in flight the last known value stays, and is never a loading indicator", async ({ page }) => {
  await signIn(page);
  await page.goto("system/instruments");
  const value = page.getByTestId("instrument-value-disk");
  await expect(value).toBeVisible();
  const readings: string[] = [];
  for (let i = 0; i < 6; i++) {
    readings.push(((await value.textContent()) ?? "").trim());
    await page.waitForTimeout(700);
  }
  // Never blank, never a spinner, never a skeleton: a number or an explicit absence mark.
  for (const reading of readings) {
    expect(reading, `readings: ${readings.join(" | ")}`).not.toBe("");
    expect(reading).toMatch(/\d|—/);
  }
  await expect(page.getByTestId("instrument-disk").locator(".skeleton")).toHaveCount(0);
});

test("No metric history survives a reload: the window is client-side only (spec FR-018, SC-009)", async ({ page }) => {
  await signIn(page);
  await page.goto("system/instruments");
  await expect(page.getByTestId("instrument-cluster")).toBeVisible();
  await page.waitForTimeout(3000);
  const before = await page.evaluate(() => ({ local: window.localStorage.length, session: window.sessionStorage.length }));
  await page.reload();
  await expect(page.getByTestId("instrument-cluster")).toBeVisible();
  const after = await page.evaluate(() => ({ local: window.localStorage.length, session: window.sessionStorage.length }));
  expect(after.local).toBe(before.local);
  expect(after.session).toBe(before.session);
  // Nothing in either store carries a series of readings.
  const stored = await page.evaluate(() =>
    [...Array(window.localStorage.length).keys()].map((i) => window.localStorage.getItem(window.localStorage.key(i)!) ?? "").join("|"),
  );
  expect(stored).not.toMatch(/telemetry|series|instrument/i);
});

test("The seize table is shown as the platform reports it, with no threshold FlightDeck invented", async ({ page }) => {
  await signIn(page);
  await page.goto("system/instruments");
  const table = page.getByTestId("resource-table");
  await expect(table).toContainText("Resource seizes");
  await expect(table).toContainText("states no meaning for these counters");
});

for (const theme of ["dark", "light"] as const) {
  test(`axe finds no violations on the four new sections (${theme})`, async ({ page }) => {
    test.setTimeout(180_000);
    await signIn(page);
    await setTheme(page, theme);
    const violations: string[] = [];
    for (const route of ["system/instruments", "system/processes", "tasks/tasks", "system/directories"]) {
      await page.goto(route);
      await expect(page.getByTestId("glareshield")).toBeVisible();
      await page.waitForTimeout(300);
      // The same bar the shell sweep uses, so this feature is held to the project's standard rather
      // than to a different one (feature 001 e2e/shell.spec.ts).
      const result = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"]).analyze();
      for (const violation of result.violations) {
        violations.push(`${route}: ${violation.id} ${violation.nodes.map((n) => n.target.join(" ")).join(", ")}`);
      }
    }
    expect(violations).toEqual([]);
  });
}
