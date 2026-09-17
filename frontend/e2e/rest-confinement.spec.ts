import { execFileSync } from "node:child_process";
import { expect, test } from "@playwright/test";
import { signIn } from "./setup/helpers";

// Feature 002 SC-009 and RN-FD-08: the REST executor is not an outbound proxy. Hostile targets are
// refused through the UI and through direct requests, and no connection leaves the container.

const CONTAINER = process.env.FD_CONTAINER ?? "iris-flightdeck-iris-1";
const HOSTILE = ["http://example.com/", "https://example.com/api", "//example.com/x", "/api/../../etc", "/%2e%2e/", "\\\\host\\share", "api/no-slash"];

/** Remote endpoints of established TCP connections inside the container that are not loopback. */
function outbound(): string[] | null {
  try {
    const table = execFileSync("docker", ["exec", CONTAINER, "cat", "/proc/net/tcp", "/proc/net/tcp6"], { encoding: "utf8" });
    return table
      .split("\n")
      .slice(1)
      .map((line) => line.trim().split(/\s+/))
      .filter((cols) => cols.length > 3 && cols[3] === "01")
      .map((cols) => cols[2]!)
      .filter((remote) => !/^(0100007F|00000000000000000000000001000000|0000000000000000FFFF00000100007F):/.test(remote));
  } catch {
    return null;
  }
}

test("SC-009. Hostile targets are refused through the UI and directly, and no connection leaves the container", async ({ page }) => {
  const before = outbound();
  await signIn(page);
  await page.goto(`web-apps/rest-apis?inspect=${encodeURIComponent("web-apps/rest-service:?webApplication=%2Fapi%2Fflightdeck")}`);
  for (const path of HOSTILE) {
    await page.getByTestId("rest-path").fill(path);
    await page.getByTestId("rest-execute").click();
    await expect(page.getByTestId("rest-error")).toContainText(/only to this instance/i);
  }
  for (const path of HOSTILE) {
    const status = await page.evaluate(async (target) => {
      const response = await fetch("/api/flightdeck/v1/rest/execute", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-FlightDeck-Tab": "e2e-confinement", "X-FlightDeck-Safe-Mode": "armed" },
        body: JSON.stringify({ method: "GET", path: target }),
      });
      return { status: response.status, code: ((await response.json()) as { error?: { code?: string } }).error?.code };
    }, path);
    expect(status.status, path).toBe(400);
    expect(status.code, path).toBe("TARGET_OUTSIDE_INSTANCE");
  }
  const hostHeader = await page.evaluate(async () => {
    const response = await fetch("/api/flightdeck/v1/rest/execute", {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-FlightDeck-Tab": "e2e-confinement", "X-FlightDeck-Safe-Mode": "armed" },
      body: JSON.stringify({ method: "GET", path: "/api/flightdeck/v1/session/capabilities", headers: { Host: "example.com" } }),
    });
    return { status: response.status, code: ((await response.json()) as { error?: { code?: string } }).error?.code };
  });
  expect(hostHeader).toEqual({ status: 400, code: "CREDENTIAL_HEADER" });
  const after = outbound();
  test.skip(before === null || after === null, "docker is not reachable from the test runner; connection table not checked");
  const opened = after!.filter((remote) => !before!.includes(remote));
  expect(opened).toEqual([]);
});
