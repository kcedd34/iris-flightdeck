import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Page } from "@playwright/test";
import { disarm, setTheme, signIn } from "./setup/helpers";
import { DOCKER_SKIP_REASON, dockerAvailable, setFixtures } from "./setup/iris";

// Feature 002, User Story 4: the pattern catalog exercises the shipped pattern where web
// applications do not (scenarios 1, 2 and 4; scenario 3 is the build gate, T081).

// The catalog exists only while the test install has the fixtures flag, which has no HTTP surface on
// purpose and is set through the container. Without Docker every test here skips with the reason.
const DOCKER = dockerAvailable();

test.skip(!DOCKER, DOCKER_SKIP_REASON);

test.beforeAll(() => {
  if (DOCKER) setFixtures(true);
});

test.afterAll(() => {
  if (DOCKER) setFixtures(false);
});

async function openItem(page: Page, name: string) {
  await page.goto("__fixtures__/pattern");
  await page.getByTestId("catalog-reset").click();
  await page.getByTestId("list-row").filter({ hasText: name }).click();
  await expect(page.getByTestId("entity-inspector").getByRole("heading", { name })).toBeVisible();
}

async function edit(page: Page, change: (form: ReturnType<Page["getByTestId"]>) => Promise<void>) {
  await page.getByTestId("action-PUT-fixture-catalog-item-edit").click();
  const form = page.getByTestId("object-form");
  await change(form);
  await form.getByTestId("form-submit").click();
}

test.beforeEach(async ({ page }) => {
  await signIn(page);
});

test("1. Simple, reinforced and maximum operations share one dry-run view with the grade's interaction", async ({ page }) => {
  await openItem(page, "plain-item");
  await disarm(page);
  const dryRun = page.getByTestId("dry-run");

  // Simple: confirm.
  await edit(page, (form) => form.locator("#f-Description").fill("Simple edit"));
  await expect(dryRun.getByTestId("dry-run-confirm-input")).toHaveCount(0);
  await expect(dryRun.getByTestId("dry-run-apply")).toBeEnabled();
  await dryRun.getByTestId("dry-run-apply").click();
  await expect(dryRun.getByTestId("dry-run-applied")).toBeVisible();
  await dryRun.getByRole("button", { name: "Close" }).click();

  // Reinforced: type the target name.
  await edit(page, (form) => form.locator("#f-Enabled").uncheck());
  await expect(dryRun.getByTestId("dry-run-apply")).toBeDisabled();
  await dryRun.getByTestId("dry-run-confirm-input").fill("plain-ite");
  await expect(dryRun.getByTestId("dry-run-apply")).toBeDisabled();
  await dryRun.getByTestId("dry-run-confirm-input").fill("plain-item");
  await expect(dryRun.getByTestId("dry-run-acknowledge")).toHaveCount(0);
  await expect(dryRun.getByTestId("dry-run-apply")).toBeEnabled();
  await dryRun.getByRole("button", { name: "Cancel" }).click();

  // Maximum: type the identifier and acknowledge the consequence; impact is shown.
  await openItem(page, "critical-item");
  await disarm(page);
  await page.getByTestId("action-DELETE-fixture-catalog-item-delete").click();
  await expect(dryRun.getByTestId("dry-run-impact")).toContainText("1 synthetic user loses access");
  await dryRun.getByTestId("dry-run-confirm-input").fill("critical-item");
  await expect(dryRun.getByTestId("dry-run-apply")).toBeDisabled();
  await expect(dryRun).toContainText("Everything that depends on it stops working.");
  await dryRun.getByTestId("dry-run-acknowledge").check();
  await dryRun.getByTestId("dry-run-apply").click();
  await expect(dryRun.getByTestId("dry-run-applied")).toBeVisible();
});

test("2. A secret field shows only changed or unchanged in the dry-run, the trail and the export", async ({ page }) => {
  await openItem(page, "plain-item");
  await disarm(page);
  await edit(page, async (form) => {
    await form.locator("#f-Description").fill("With a new secret");
    await form.locator("#f-Secret").fill("typed-secret-value");
  });
  const dryRun = page.getByTestId("dry-run");
  const secret = dryRun.getByTestId("dry-run-row-Secret");
  await expect(secret).toContainText("changed");
  await expect(secret).not.toContainText("typed-secret-value");
  await expect(dryRun).not.toContainText("catalog-secret-plain");
  await dryRun.getByTestId("dry-run-apply").click();
  await expect(dryRun.getByTestId("dry-run-applied")).toBeVisible();
  await dryRun.getByRole("button", { name: "Open session trail" }).click();
  const trail = page.getByTestId("trail-panel");
  await trail.getByTestId("trail-entry").first().getByRole("button").first().click();
  await expect(trail.getByTestId("trail-entry").first()).toContainText("changed");
  const [download] = await Promise.all([page.waitForEvent("download"), trail.getByTestId("trail-export").click()]);
  const exported = await download.createReadStream().then(async (stream) => {
    const chunks: Buffer[] = [];
    for await (const chunk of stream) chunks.push(chunk as Buffer);
    return Buffer.concat(chunks).toString("utf8");
  });
  expect(exported).toContain('"secret": true');
  expect(exported).not.toContain("typed-secret-value");
  expect(exported).not.toContain("catalog-secret");
  const stored = await page.evaluate(() => JSON.stringify(window.sessionStorage));
  expect(stored).not.toContain("typed-secret-value");
  // The list and the inspector never carry the secret either.
  const list = await page.evaluate(async () => (await fetch("/api/flightdeck/v1/domains/fixtures/catalog-item", { headers: { "X-FlightDeck-Tab": "e2e" } })).text());
  expect(list).not.toContain("catalog-secret");
});

test("A blocked operation is refused with its reason and recorded as Blocked", async ({ page }) => {
  await openItem(page, "protected-item");
  await disarm(page);
  await page.getByTestId("action-DELETE-fixture-catalog-item-delete").click();
  const dryRun = page.getByTestId("dry-run");
  await expect(dryRun.getByTestId("dry-run-message")).toHaveText("This catalog item is protected. The pattern refuses to change it.");
  await expect(dryRun.getByTestId("dry-run-apply")).toBeDisabled();
  await dryRun.getByRole("button", { name: "Cancel" }).click();
  await page.getByTestId("catalog-open-trail").click();
  const entry = page.getByTestId("trail-panel").getByTestId("trail-entry").first();
  await expect(entry).toHaveAttribute("data-result", "Blocked");
  await expect(entry).toContainText("protected-item");
});

test("A change made on the server while the dry-run is open is detected and recomputed", async ({ page }) => {
  await openItem(page, "plain-item");
  await disarm(page);
  await edit(page, (form) => form.locator("#f-Description").fill("Mine"));
  const dryRun = page.getByTestId("dry-run");
  await expect(dryRun.getByTestId("dry-run-row-Revision")).toContainText("1");
  // Another administrator changes the object.
  await page.evaluate(async () => {
    await fetch("/api/flightdeck/v1/domains/fixtures/catalog-item?drift=plain-item", { headers: { "X-FlightDeck-Tab": "e2e-other" } });
  });
  await dryRun.getByTestId("dry-run-apply").click();
  await expect(dryRun.getByTestId("dry-run-message")).toHaveText("This object changed on the server while you were editing. Review the updated differences before applying.");
  await expect(dryRun.getByTestId("dry-run-row-Revision")).toContainText("2");
  await dryRun.getByTestId("dry-run-apply").click();
  await expect(dryRun.getByTestId("dry-run-applied")).toBeVisible();
});

test("4. With reduced motion the dry-run appears in its final state instantly", async ({ page }) => {
  await page.emulateMedia({ reducedMotion: "reduce" });
  await openItem(page, "plain-item");
  await disarm(page);
  await edit(page, (form) => form.locator("#f-Description").fill("Instant"));
  const row = page.getByTestId("dry-run").getByTestId("dry-run-row-Description");
  await expect(row).toBeVisible();
  const motion = await row.evaluate((el) => {
    const cmd = el.querySelector(".cmd")!;
    const style = getComputedStyle(cmd);
    return { opacity: style.opacity, transition: style.transitionDuration, flash: getComputedStyle(el, "::after").animationName };
  });
  expect(motion).toEqual({ opacity: "1", transition: "0s", flash: "none" });
});

test("5. An action-kind mutation shows the affected set before and after, with the grade its descriptor declares", async ({ page }) => {
  await openItem(page, "plain-item");
  await disarm(page);
  const dryRun = page.getByTestId("dry-run");
  // Adding: simple, and the row moves from absent to present.
  await page.getByTestId("action-POST-fixture-catalog-tag-grant-add-a-tag").click();
  await expect(dryRun.getByTestId("dry-run-row-tag reviewed-again")).toContainText("not granted");
  await expect(dryRun.getByTestId("dry-run-confirm-input")).toHaveCount(0);
  await dryRun.getByTestId("dry-run-apply").click();
  await expect(dryRun.getByTestId("dry-run-applied")).toBeVisible();
  await dryRun.getByRole("button", { name: "Close" }).click();
  // Removing: reinforced, and the row is present today.
  await page.getByTestId("action-POST-fixture-catalog-tag-revoke-remove-a-tag").click();
  await expect(dryRun.getByTestId("dry-run-row-tag reviewed")).toContainText("granted");
  await expect(dryRun.getByTestId("dry-run-confirm-input")).toBeVisible();
  await dryRun.getByRole("button", { name: "Cancel" }).click();
});

test("6. A parameterised panel answers nothing until it has its parameter, and says which it used", async ({ page }) => {
  await openItem(page, "plain-item");
  const tags = page.getByTestId("links-group-catalog-tags");
  await expect(tags).toHaveAttribute("data-state", "needs-parameter");
  await expect(tags).toContainText("Choose a scope");
  await tags.getByTestId("links-group-catalog-tags-parameter-scope").selectOption("all");
  await expect(tags).toHaveAttribute("data-state", "ok");
  await expect(tags).toContainText("reviewed");
});

for (const theme of ["dark", "light"] as const) {
  test(`axe finds no violations on the catalog and its maximum-grade dry-run (${theme})`, async ({ page }) => {
    await setTheme(page, theme);
    await openItem(page, "critical-item");
    await disarm(page);
    const check = async (where: string) => {
      await page.waitForTimeout(400);
      const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"]).analyze();
      expect(results.violations.map((v) => `${where}: ${v.id} ${v.nodes.map((n) => n.target.join(" ")).join(", ")}`)).toEqual([]);
    };
    await check("catalog");
    await page.getByTestId("action-DELETE-fixture-catalog-item-delete").click();
    await expect(page.getByTestId("dry-run").getByTestId("dry-run-acknowledge")).toBeVisible();
    await check("maximum dry-run");
  });
}
