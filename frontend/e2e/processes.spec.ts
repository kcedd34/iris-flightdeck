import { expect, test } from "@playwright/test";
import { disarm, signIn } from "./setup/helpers";

// Feature 004, User Story 2: processes. UC08 Gherkin 3 and 4, verbatim, plus the two refusals the
// server owns — a control the API disabled is never requested, and the session's own process is
// never terminated.

test("PRD UC08-3. A process the API reports as not terminable shows the control disabled with the reason, and no request is issued", async ({ page }) => {
  await signIn(page);
  await page.goto("system/processes");
  const list = page.getByTestId("domain-list");
  await expect(list).toBeVisible();
  // The capability fields arrive on the list, so the row's controls are decided without opening it.
  const rows = page.getByTestId("domain-list").getByRole("button");
  const count = await rows.count();
  expect(count).toBeGreaterThan(0);

  // Find a process the instance will not let anyone terminate (the daemons always qualify).
  let found = false;
  for (let i = 0; i < count && !found; i++) {
    await rows.nth(i).click();
    const inspector = page.getByTestId("entity-inspector");
    await expect(inspector).toBeVisible();
    const terminate = inspector.getByTestId("action-POST-v2-process-terminate-terminate");
    if ((await terminate.getAttribute("aria-disabled")) === "true") {
      found = true;
      await expect(inspector).toContainText("cannot be terminated");
      // Clicking a disabled control issues nothing: the API already answered, and the screen obeys.
      const requests: string[] = [];
      page.on("request", (request) => {
        if (request.url().includes("/mutations/")) requests.push(request.url());
      });
      await terminate.click({ force: true });
      await page.waitForTimeout(500);
      expect(requests, "a disabled control must not reach the mutation layer").toEqual([]);
    }
  }
  expect(found, "the instance reports at least one process that cannot be terminated").toBe(true);
});

test("PRD UC08-4 and RN-FD-12. Terminating asks for the identifier, and the session's own process is refused", async ({ page }) => {
  await signIn(page);
  await page.goto("system/processes");
  const candidates = await page.evaluate(async () => {
    const response = await fetch("/api/flightdeck/v1/domains/system/process?maxRows=500", { headers: { "X-FlightDeck-Tab": "e2e" } });
    const list = (await response.json()) as { items: { keys: { id: string }; facts: { canBeTerminated?: boolean; isThisRequest?: boolean } }[] };
    return list.items.filter((row) => row.facts.canBeTerminated && !row.facts.isThisRequest).map((row) => row.keys.id);
  });
  test.skip(candidates.length === 0, "this instance reports no process that may be terminated other than the one serving this request");

  // Which process serves the next request is IRIS's choice, so a candidate can become this request's
  // own between the listing and the preview — and is then blocked, correctly. Try the candidates in
  // turn rather than treating that race as a failure.
  let confirmed = false;
  for (const id of candidates.slice(0, 5)) {
    await page.goto(`system/processes?inspect=${encodeURIComponent(`system/process:?id=${id}`)}`);
    const inspector = page.getByTestId("entity-inspector");
    await expect(inspector).toBeVisible();
    await disarm(page);
    const terminate = inspector.getByTestId("action-POST-v2-process-terminate-terminate");
    if ((await terminate.getAttribute("aria-disabled")) === "true") continue;
    await terminate.click();
    const dryRun = page.getByTestId("dry-run");
    await expect(dryRun).toBeVisible();
    // The preview is a request: wait for it to settle before reading which screen this is, or a
    // confirmation still loading looks like a refusal.
    await expect
      .poll(async () => (await dryRun.getByTestId("dry-run-confirm-input").count()) > 0 || (await dryRun.getByTestId("dry-run-message").count()) > 0, { timeout: 15_000 })
      .toBe(true);
    if ((await dryRun.getByTestId("dry-run-confirm-input").count()) === 0) {
      // Refused between the listing and the preview: this process became the one serving the request,
      // or the instance stopped allowing it. Either way the refusal is explained, which is the rule
      // working — the run simply has to try another candidate.
      await expect(dryRun.getByTestId("dry-run-message")).not.toBeEmpty();
      await dryRun.getByRole("button", { name: "Cancel" }).click();
      continue;
    }
    // Maximum grade: the identifier must be typed, and the consequence is stated (spec FR-030).
    await expect(dryRun.getByTestId("dry-run-confirm-input")).toBeVisible();
    await expect(dryRun).toContainText("Work in flight is lost");
    await expect(dryRun.getByTestId("dry-run-apply")).toBeDisabled();
    await dryRun.getByRole("button", { name: "Cancel" }).click();
    confirmed = true;
    break;
  }
  expect(confirmed, "one of the terminable processes asked for its identifier to be typed").toBe(true);
});

test("SC-006. The server refuses terminating a process that serves this administrator's session, even when the request bypasses the screen", async ({ page }) => {
  await signIn(page);
  await page.goto("system/processes");
  await disarm(page);
  // Which process belongs to this session is on the detail, not the list: the platform reports the
  // CSP session there. The block compares that, not the process serving this request, because IRIS
  // serves consecutive requests from different processes (feature 004 sign-off).
  const answer = await page.evaluate(async () => {
    const list = await (await fetch("/api/flightdeck/v1/domains/system/process?maxRows=500", { headers: { "X-FlightDeck-Tab": "e2e" } })).json();
    for (const item of list.items as { keys: { id: string }; facts: { isThisRequest?: boolean } }[]) {
      if (!item.facts.isThisRequest) continue;
      const response = await fetch("/api/flightdeck/v1/mutations/preview", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-FlightDeck-Tab": "e2e" },
        body: JSON.stringify({ operationId: "POST /v2/process/terminate", keys: item.keys, params: { id: item.keys.id } }),
      });
      return { found: true as const, status: response.status, body: await response.json() };
    }
    return { found: false as const };
  });
  test.skip(!answer.found, "no process on this instance reports the signed-in session, so there is nothing to protect here");
  if (answer.found) {
    expect(answer.body.blocked?.message ?? "").toContain("your own session");
  }
});
