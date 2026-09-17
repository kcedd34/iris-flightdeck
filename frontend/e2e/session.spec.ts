import { expect, test } from "@playwright/test";
import { disarm, signIn } from "./setup/helpers";
import { NO_PRIVILEGE, OPERATOR } from "./setup/users";

// docs/prd.md UC01 scenarios (translated), alternate flows A1, A2, A5, and FR-012a.
// Scenario 4 is in fixtures.spec.ts (FR-017a).

test("1. Given the user authenticates successfully, when the initial dashboard is opened, then the session is in safe mode and the read-only indicator is persistently visible", async ({ page }) => {
  await signIn(page);
  await expect(page.getByTestId("safe-mode-indicator")).toHaveText("Safe mode");
  await expect(page.getByTestId("capability-summary")).toBeVisible();
  for (const route of ["web-apps/web-applications", "security/tls", "logs/stream"]) {
    await page.goto(route);
    await expect(page.getByTestId("safe-mode-indicator")).toHaveText("Safe mode");
  }
});

test("2. Given the user lacks the privilege an API operation requires, when the screen renders, then the action is disabled and the required resource and permission are shown", async ({ page }) => {
  await signIn(page, OPERATOR);
  await expect(page.getByTestId("capability-summary")).toContainText("58 of 273");
  await page.keyboard.press("Control+k");
  await page.getByTestId("palette-input").fill("delete a role");
  const row = page.locator('[cmdk-item][data-disabled="true"][aria-disabled="true"]', { hasText: "Delete a role" });
  await expect(row).toBeVisible();
  await expect(row).toContainText("Requires Use on %Admin_Secure. Ask your instance administrator for access.");
});

test("3. Given the instance's sign-in path, when the user authenticates, then access works in-process and no credential is persisted in any layer", async ({ page, context }) => {
  const authorizationAfterSignIn: string[] = [];
  let signedIn = false;
  page.on("request", (r) => {
    if (signedIn && r.url().includes("/api/flightdeck/") && r.headers()["authorization"]) authorizationAfterSignIn.push(r.url());
  });
  await signIn(page);
  signedIn = true;
  await page.goto("permissions/roles");
  await expect(page.getByTestId("glareshield")).toBeVisible();
  await page.keyboard.press("Control+k");
  await page.getByTestId("palette-input").fill("FD_Demo");
  await expect(page.getByTestId("command-palette").getByText("FD_Demo_Operator")).toBeVisible();
  await page.keyboard.press("Escape");
  expect(authorizationAfterSignIn).toEqual([]);
  const storage = await page.evaluate(() => ({
    local: Object.keys(window.localStorage),
    session: Object.keys(window.sessionStorage),
    values: Object.values(window.localStorage).join(" "),
  }));
  expect(storage.session).toEqual([]);
  for (const key of storage.local) expect(key).toMatch(/^flightdeck:(theme|recent):/);
  expect(storage.values).not.toContain('"SYS"');
  // Only IRIS-owned cookies: the CSP session, browser id and web server affinity. None is a credential.
  for (const cookie of await context.cookies()) expect(cookie.name).toMatch(/^(CSPSESSIONID|CSPBrowserId|CSPWSERVERID)/);
});

test("5. Given a tab was disarmed, when a reload, a new tab or a tab opened from it starts, then it starts in safe mode without exception (20 trials)", async ({ page, context }) => {
  test.setTimeout(240_000);
  await signIn(page);
  for (let trial = 1; trial <= 20; trial++) {
    await disarm(page);
    const kind = trial % 3;
    if (kind === 0) {
      await page.reload();
      await expect(page.getByTestId("safe-mode-indicator"), `trial ${trial}: reload`).toHaveText("Safe mode");
    } else if (kind === 1) {
      const fresh = await context.newPage();
      await fresh.goto("./");
      await expect(fresh.getByTestId("safe-mode-indicator"), `trial ${trial}: new tab`).toHaveText("Safe mode");
      await fresh.close();
      await page.getByTestId("safe-mode-indicator").click();
    } else {
      const [popup] = await Promise.all([context.waitForEvent("page"), page.evaluate(() => void window.open(window.location.href))]);
      await popup.waitForLoadState();
      await expect(popup.getByTestId("safe-mode-indicator"), `trial ${trial}: opened from disarmed tab`).toHaveText("Safe mode");
      await popup.close();
      await page.getByTestId("safe-mode-indicator").click();
    }
    await expect(page.getByTestId("safe-mode-indicator")).toHaveText("Safe mode");
  }
});

test("6. Given an invalid credential, when sign-in fails, then the message is generic and identical for an unknown user and a wrong password", async ({ page }) => {
  const dialogs: string[] = [];
  page.on("dialog", (d) => {
    dialogs.push(d.type());
    void d.dismiss();
  });
  await page.goto("./");
  const messages: string[] = [];
  for (const [user, password] of [
    ["no_such_user_fd", "whatever"],
    [OPERATOR.user, "wrong-password"],
  ] as const) {
    await page.locator('input[name="username"]').fill(user);
    await page.locator('input[name="password"]').fill(password);
    await page.getByRole("button", { name: "Sign in" }).click();
    const alert = page.getByRole("alert");
    await expect(alert).toBeVisible();
    messages.push((await alert.innerText()).trim());
  }
  expect(messages[0]).toBe("Invalid credentials. Check your username and password.");
  expect(messages[1]).toBe(messages[0]);
  expect(dialogs).toEqual([]);
});

test("7. Given a user without any administrative privilege, when they sign in, then the required privileges are listed and no session opens", async ({ page }) => {
  await page.goto("./");
  await page.locator('input[name="username"]').fill(NO_PRIVILEGE.user);
  await page.locator('input[name="password"]').fill(NO_PRIVILEGE.password);
  await page.getByRole("button", { name: "Sign in" }).click();
  await expect(page.getByRole("alert")).toContainText("Requires Use on %Admin_");
  await expect(page.getByRole("alert")).toContainText("Ask your instance administrator for access.");
  await expect(page.getByTestId("glareshield")).toHaveCount(0);
});

test("8. Given an instance without any SysAdmin API, when the user signs in, then sign-in is refused with the version message and the detected version (FR-012a)", async ({ page }) => {
  await page.route("**/api/flightdeck/v1/session", async (route) => {
    if (route.request().method() === "POST") {
      await route.fulfill({
        status: 403,
        contentType: "application/json",
        body: JSON.stringify({
          error: {
            code: "UNSUPPORTED_VERSION",
            message: "Not available on this IRIS version or edition. Requires IRIS 2026.1.",
            raw: null,
            detectedVersion: "IRIS for UNIX (Ubuntu Server LTS for x86-64 Containers) 2025.1 (Build 223U) Tue Mar 11 2025 18:01:57 EDT",
          },
        }),
      });
    } else {
      await route.fulfill({ status: 401, body: "" });
    }
  });
  await page.goto("./");
  await page.locator('input[name="username"]').fill("_SYSTEM");
  await page.locator('input[name="password"]').fill("SYS");
  await page.getByRole("button", { name: "Sign in" }).click();
  await expect(page.getByRole("alert")).toContainText("Not available on this IRIS version or edition. Requires IRIS 2026.1.");
  await expect(page.getByRole("alert")).toContainText("Detected: IRIS for UNIX (Ubuntu Server LTS for x86-64 Containers) 2025.1 (Build 223U)");
  await expect(page.getByTestId("glareshield")).toHaveCount(0);
});
