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
  // The number depends on what this install offers; the shape and the total are the claim.
  await expect(page.getByTestId("capability-summary")).toContainText(/\d+ of 273 operations available to you/);
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
    values: Object.values(window.localStorage).join(" ") + " " + Object.values(window.sessionStorage).join(" "),
  }));
  // Feature 002: the session trail is the only session storage entry allowed, and it holds no credential.
  for (const key of storage.session) expect(key).toBe("flightdeck.trail.v1");
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
  // Feature 003 corrected this message: the instance refused to report the account's privileges,
  // which is about the account, not the version. It still names the privileges FlightDeck uses.
  await expect(page.getByRole("alert")).toContainText("refused to report this account's privileges");
  await expect(page.getByRole("alert")).toContainText("%Admin_Secure");
  await expect(page.getByRole("alert")).not.toContainText("Requires IRIS");
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

// Feature 007: the published demo prints its credentials under the sign-in form. A normal install
// must not — this is the case that protects everyone who runs FlightDeck on their own machine.
test("the sign-in form shows no demo credentials on an install that did not ask for them", async ({ page }) => {
  await page.goto("./");
  await expect(page.getByTestId("credentials-form").or(page.locator("form.credentials"))).toBeVisible();
  await expect(page.getByTestId("demo-credentials")).toHaveCount(0);
  await expect(page.locator('meta[name="fd-demo-notice"]')).toHaveCount(0);
});

// The assets as FlightDeck's own server delivers them, not as the Vite dev server does.
//
// Every project in this suite points at Vite, so FlightDeck.UI.Static served no test at all — and it
// was double-encoding every non-ASCII byte it sent. On a real install (Docker or IPM) each "—", "…",
// "×" and "→" in the interface arrived as mojibake, and nothing here could see it. Found by opening
// the deployed demo and reading the screen.
test("the installed static server delivers assets byte-for-byte, not re-encoded", async ({ request }) => {
  const origin = `http://localhost:${process.env.FLIGHTDECK_PORT ?? "52780"}`;
  const index = await request.get(`${origin}/flightdeck/`);
  expect(index.status()).toBe(200);
  const bundle = /assets\/(index-[^"']+\.js)/.exec(await index.text())?.[1];
  expect(bundle, "the page must reference a bundle").toBeTruthy();

  const asset = await request.get(`${origin}/flightdeck/assets/${bundle}`);
  expect(asset.status()).toBe(200);
  const bytes = await asset.body();
  const text = bytes.toString("utf8");
  // The interface ships these characters; if the server re-encodes, they arrive as their UTF-8 bytes
  // reinterpreted as Latin-1, which is what "Ã¢â‚¬" and friends are.
  expect(text).toContain("\u2014");
  expect(text, "asset was encoded twice on the way out").not.toContain("\u00c3\u00a2\u00c2\u0080\u00c2\u0094");
  expect(bytes.includes(Buffer.from([0xc3, 0xa2, 0xc2, 0x80, 0xc2, 0x94])), "double-encoded em dash").toBe(false);
});
