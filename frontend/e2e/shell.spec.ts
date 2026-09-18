import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";
import { setTheme, signIn } from "./setup/helpers";

// User Story 5 (FR-029 to FR-039), design gates SC-006 to SC-008.

const DOMAINS: [string, string][] = [
  ["web-apps", "Web applications and APIs"],
  ["permissions", "Permissions"],
  ["security", "Security and secrets"],
  ["tasks", "Tasks"],
  ["system", "System"],
  ["logs", "Logs"],
];

test("glareshield is 44px, the rail is 56px with exactly six destinations in order", async ({ page }) => {
  await signIn(page);
  const glare = await page.getByTestId("glareshield").boundingBox();
  const rail = await page.getByTestId("rail").boundingBox();
  expect(glare?.height).toBe(44);
  expect(rail?.width).toBe(56);
  const labels = await page.getByTestId("rail").getByRole("link").evaluateAll((els) => els.map((e) => e.getAttribute("aria-label")));
  expect(labels).toEqual(DOMAINS.map(([, label]) => label));
  // The indicator follows the capability map, not the version: present exactly when this install
  // does not offer every operation (FR-012a). Its content is the limited project's subject.
  const session = (await (await page.request.get("/api/flightdeck/v1/session", { headers: { "X-FlightDeck-Tab": "e2e" } })).json()) as {
    capabilitySummary: { unavailable: number };
  };
  await expect(page.getByTestId("limited-mode-indicator")).toHaveCount(session.capabilitySummary.unavailable === 0 ? 0 : 1);
});

test("section tabs appear only for domains with more than one entity type, and the active tab lives in the URL", async ({ page }) => {
  await signIn(page);
  for (const [id, label] of DOMAINS) {
    await page.getByTestId("rail").getByRole("link", { name: label }).click();
    await expect(page).toHaveURL(new RegExp(`/flightdeck/${id}/[a-z0-9-]+$`));
    // Every shipped domain now carries more than one section: logs gained its three in feature 005.
    const tabs = page.getByTestId("section-tabs").getByRole("link");
    // count() does not wait, so it must not be the first thing asked of a section that has just
    // begun rendering: on a cold instance the first domain answered 0 here and the run failed.
    await expect(tabs.first()).toBeVisible();
    expect(await tabs.count()).toBeGreaterThan(1);
    await tabs.nth(1).click();
    const active = page.getByTestId("section-tabs").locator('[aria-current="page"]');
    await expect(active).toHaveCount(1);
    const href = await active.getAttribute("href");
    await expect(page).toHaveURL(new RegExp(`${href}$`));
    await page.reload();
    await expect(page.getByTestId("section-tabs").locator('[aria-current="page"]')).toHaveAttribute("href", href!);
    // Every domain of the rail is now built: web applications (002), permissions and security (003),
    // tasks and system (004), logs (005). No section carries the feature 001 placeholder any more.
    await expect(page.getByRole("status").filter({ hasText: "Not available in this build yet" })).toHaveCount(0);
  }
});

test("an entity opens in the inspector beside the list without a path change; below 1280px it is an overlay", async ({ page }) => {
  await signIn(page);
  await page.goto("permissions/roles");
  await expect(page.getByTestId("glareshield")).toBeVisible();
  const path = new URL(page.url()).pathname;
  await page.keyboard.press("Control+k");
  await page.getByTestId("palette-input").fill("FD_Demo_Auditor");
  await page.locator("[cmdk-item]", { hasText: "FD_Demo_Auditor" }).click();
  await expect(page.getByTestId("inspector")).toContainText("FD_Demo_Auditor");
  expect(new URL(page.url()).pathname).toBe(path);
  const box = await page.getByTestId("inspector").boundingBox();
  expect(box?.width).toBe(420);
  await expect(page.getByTestId("inspector").locator("xpath=self::aside")).toHaveCount(1);

  await page.setViewportSize({ width: 1024, height: 768 });
  await expect(page.getByTestId("inspector")).toHaveAttribute("role", "dialog");
});

for (const theme of ["dark", "light"] as const) {
  test(`axe finds no violations on home and every domain route (${theme})`, async ({ page }) => {
    test.setTimeout(180_000);
    await signIn(page);
    await setTheme(page, theme);
    for (const route of ["./", ...DOMAINS.map(([id]) => `${id}`)]) {
      await page.goto(route);
      await expect(page.getByTestId("glareshield")).toBeVisible();
      await page.waitForTimeout(300);
      const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"]).analyze();
      expect(results.violations.map((v) => `${route}: ${v.id} ${v.nodes.map((n) => n.target.join(" ")).join(", ")}`)).toEqual([]);
    }
  });
}

test("keyboard only: tab order runs glareshield, rail, work header, list; every focused element shows the focus ring", async ({ page }) => {
  await signIn(page);
  await page.goto("security/tls");
  await expect(page.getByTestId("section-tabs")).toBeVisible();
  const regions: string[] = [];
  for (let i = 0; i < 40; i++) {
    await page.keyboard.press("Tab");
    const info = await page.evaluate(() => {
      const el = document.activeElement as HTMLElement | null;
      if (!el || el === document.body) return null;
      const style = getComputedStyle(el);
      const region = el.closest('[data-testid="glareshield"]') ? "glareshield" : el.closest('[data-testid="rail"]') ? "rail" : el.closest(".workhead") ? "header" : el.closest(".list") ? "list" : "other";
      return { region, outline: style.outlineStyle !== "none" && parseFloat(style.outlineWidth) >= 2 };
    });
    if (!info) continue;
    expect(info.outline, `focus ring on ${info.region} element ${i}`).toBe(true);
    if (regions[regions.length - 1] !== info.region) regions.push(info.region);
  }
  const order = regions.filter((r) => r !== "other");
  expect(order.slice(0, 4)).toEqual(["glareshield", "rail", "header", "list"]);
});

test("prefers-reduced-motion removes every transition", async ({ page }) => {
  await page.emulateMedia({ reducedMotion: "reduce" });
  await signIn(page);
  const durations = await page.evaluate(() =>
    Array.from(document.querySelectorAll<HTMLElement>(".mode, .livebar, .rail-item, .tab, .btn, .home-domain")).map((el) => getComputedStyle(el).transitionDuration),
  );
  expect(durations.length).toBeGreaterThan(0);
  for (const d of durations) expect(d.split(",").every((x) => parseFloat(x) === 0)).toBe(true);
});

test("home renders its first useful content in under 2 seconds", async ({ page }) => {
  await signIn(page);
  const start = Date.now();
  await page.goto("./");
  await expect(page.getByTestId("instance-identity")).toBeVisible();
  expect(Date.now() - start).toBeLessThan(2000);
});

test("vitals: four labeled readings, unavailable shows a dash with its reason, pending keeps the last value", async ({ page }) => {
  await signIn(page);
  const vitals = page.getByTestId("vitals");
  for (const label of ["CPU", "Memory", "Shared memory", "Disk"]) await expect(vitals).toContainText(label);
  await expect(page.getByTestId("vital-cpu")).toContainText(/\d+%/);
  await expect(page.getByTestId("vital-memory")).toContainText(/\d+%/);

  let call = 0;
  await page.route("**/api/flightdeck/v1/vitals", async (route) => {
    call++;
    const base = { source: "api", scope: null, asOf: "2026-09-17T00:00:00Z", reason: null, requires: null };
    const vitals = [
      { ...base, id: "cpu", label: "CPU", source: "native", state: "unavailable", value: null, pending: false, reason: "Host metrics are not readable on this platform." },
      { ...base, id: "memory", label: "Memory", source: "native", state: "ok", value: 42, pending: false },
      { ...base, id: "shm", label: "Shared memory", state: "ok", value: 40, pending: false },
      call === 1
        ? { ...base, id: "disk", label: "Disk", state: "caution", value: 77, pending: false }
        : { ...base, id: "disk", label: "Disk", state: "caution", value: 77, pending: true },
    ];
    await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ vitals }) });
  });
  await page.reload();
  await expect(page.getByTestId("vital-cpu")).toContainText("—");
  await page.getByTestId("vital-cpu").focus();
  await expect(page.getByRole("tooltip")).toContainText("Host metrics are not readable on this platform.");
  await expect(page.getByTestId("vital-disk")).toContainText("77%");
  await page.waitForTimeout(10_500);
  expect(call).toBeGreaterThan(1);
  await expect(page.getByTestId("vital-disk")).toContainText("77%");
});
