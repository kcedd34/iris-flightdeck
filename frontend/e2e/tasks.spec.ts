import { expect, test } from "@playwright/test";
import { capability, disarm, signIn } from "./setup/helpers";

/** The task whose band carries a failed run, or null when this instance recorded none. */
async function taskWithFailedRun(page: import("@playwright/test").Page): Promise<string | null> {
  const rows = await page.evaluate(async () => {
    const response = await fetch("/api/flightdeck/v1/domains/tasks/task?maxRows=500", { headers: { "X-FlightDeck-Tab": "e2e" } });
    return (await response.json()) as { items: { displayName: string; facts: { lastResult?: string } }[] };
  });
  return rows.items.find((item) => item.facts.lastResult === "Error")?.displayName ?? null;
}

// Feature 004, User Story 3: tasks. UC07 Gherkin 1 to 4, verbatim as the definition of done.

test("PRD UC07-1. The recent-history band is visible in the list, without opening any detail", async ({ page }) => {
  await signIn(page);
  await page.goto("tasks/tasks");
  const list = page.getByTestId("domain-list");
  await expect(list).toBeVisible();
  const history = await capability(page, "GET /v2/task/history");
  test.skip(!history?.available, `this install does not offer the run history: ${history?.reason ?? "no entry in the capability map"}`);
  // The band is in the row itself: a failure is visible without opening anything. A task that has
  // never run says so rather than showing an empty rectangle.
  const bands = await list.getByTestId("history-band").count();
  const empties = await list.getByText("no runs recorded").count();
  expect(bands + empties, "every row states its run history").toBeGreaterThan(0);
  const failed = await taskWithFailedRun(page);
  test.skip(failed === null, "this install has recorded no failed task run, so no row can show one");
  await expect(list.getByRole("button", { name: new RegExp(failed!) })).toContainText("Last run failed");
});

test("PRD UC07-2. A failed run shows the complete message and jumps to the logs of that period", async ({ page }) => {
  await signIn(page);
  await page.goto("tasks/tasks");
  const failed = await taskWithFailedRun(page);
  test.skip(failed === null, "this install has recorded no failed task run: there is no message to show and no period to jump to");
  await page.getByRole("button", { name: new RegExp(failed!) }).click();
  const runs = page.getByTestId("task-runs");
  await expect(runs).toBeVisible();
  // The platform's own message, complete, as first-class content.
  await expect(page.getByTestId("task-run-message-0")).not.toBeEmpty();
  await page.getByTestId("task-run-logs-0").click();
  // The correlation contract is written and tested here; feature 005 consumes these parameters.
  await expect(page).toHaveURL(/taskId=\d+/);
  await expect(page).toHaveURL(/from=/);
  await expect(page).toHaveURL(/to=/);
  const correlation = page.getByTestId("logs-correlated");
  await expect(correlation).toBeVisible();
  // The wording is the stream's own (feature 005 implements this side of the contract). This
  // assertion was written in feature 004 against an invented string and a test id that never
  // existed, and it went unnoticed because the test skips on an install with no failed run — which
  // was every install until one was made to fail on purpose.
  await expect(correlation).toContainText("Filtered on task");
  await expect(correlation).toContainText("between");
});

test("PRD UC07-3. Running a task on demand goes through the shared dry-run, and the platform decides about a concurrent run", async ({ page }) => {
  await signIn(page);
  await page.goto("tasks/tasks");
  await disarm(page);
  const run = await capability(page, "POST /v2/task/run");
  test.skip(!run?.available, `this install does not offer an on-demand run: ${run?.reason ?? "no entry in the capability map"}`);
  await page.getByRole("button", { name: /FD Demo daily no-op/ }).click();
  await page.getByTestId("action-POST-v2-task-run-run-now").click();
  const dryRun = page.getByTestId("dry-run");
  await expect(dryRun).toBeVisible();
  await expect(dryRun).toContainText("an on-demand run of task");
  // An action with no listing to compare shows exactly what will be sent, including the body.
  await expect(dryRun.getByTestId("dry-run-request")).toContainText("/v2/task/run");
  await expect(dryRun.getByTestId("dry-run-request")).toContainText("RunNow");
  await dryRun.getByTestId("dry-run-apply").click();
  await expect(dryRun.getByTestId("dry-run-applied")).toBeVisible();
});

test("A system task can be suspended but not deleted, and the reason is stated (spec FR-007)", async ({ page }) => {
  await signIn(page);
  await page.goto("tasks/tasks");
  await disarm(page);
  await page.getByRole("button", { name: /Switch Journal/ }).click();
  const inspector = page.getByTestId("entity-inspector");
  await expect(inspector.getByTestId("action-POST-v2-task-suspend-suspend")).not.toHaveAttribute("aria-disabled", "true");
  await inspector.getByTestId("action-DELETE-v2-task-delete").click();
  const dryRun = page.getByTestId("dry-run");
  await expect(dryRun).toContainText("system task");
  await expect(dryRun.getByTestId("dry-run-apply")).toBeDisabled();
});

test("PRD UC07-4. Suspending the task manager asks for reinforced confirmation and states the instance-wide effect", async ({ page }) => {
  await signIn(page);
  await page.goto("tasks/manager");
  await disarm(page);
  const section = page.getByTestId("singleton-inspector");
  await expect(section).toBeVisible();
  await section.getByTestId("action-POST-v2-task-manager-suspend-suspend").click();
  const dryRun = page.getByTestId("dry-run");
  await expect(dryRun).toBeVisible();
  await expect(dryRun).toContainText("No scheduled task runs anywhere on this instance");
  // Reinforced: the typed name is required before Apply is offered.
  await expect(dryRun.getByTestId("dry-run-confirm-input")).toBeVisible();
  await dryRun.getByRole("button", { name: "Cancel" }).click();
});

test("The Work Queue categories and the async results list on the shared pattern (spec FR-009, FR-010)", async ({ page }) => {
  await signIn(page);
  await page.goto("tasks/work-queue-categories");
  await expect(page.getByTestId("domain-list")).toContainText("Default");
  await page.goto("tasks/async-results");
  const list = page.getByTestId("domain-list");
  await expect(list).toBeVisible();
  // The disk instrument fires these where the platform answers asynchronously, so a busy instance
  // holds many and a v1 instance (native disk read) holds none. Both are states, not failures.
  // Wait for the read to settle before counting: an empty list and a list still loading look alike.
  await expect
    .poll(async () => (await list.getByTestId("list-row").count()) > 0 || /holding no asynchronous result/.test((await list.textContent()) ?? ""), { timeout: 15_000 })
    .toBe(true);
  const rows = await list.getByTestId("list-row").count();
  if (rows === 0) {
    await expect(list).toContainText("holding no asynchronous result");
  } else {
    await expect(list.getByTestId("list-row").first()).toContainText(/Finished|Running|Queued|Failed|Canceled|Paused/);
  }
});
