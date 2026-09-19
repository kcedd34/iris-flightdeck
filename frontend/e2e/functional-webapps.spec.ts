import { expect, test } from "@playwright/test";
import { adminRequest } from "./setup/users";
import { list, mutate } from "./setup/flightdeck";
import { verifiedEffect, verifiedRead } from "./setup/effect";
import { requireV2Dialect } from "./setup/dialect";

// Feature 008: the percent-class-access operations, which had never been executed.

// The entity is keyed by (name, allowType, class), where **name is the web application** and class is
// the class the grant covers — not the other way round, which is what the instance's "Invalid
// Application name" complaint was saying.
const APP = "/csp/fd-demo-reports";
const CLASSES = "%FDFunctional.Sample";
const ALLOW = "AllowClass";
const KEYS = { name: APP, allowType: ALLOW, class: CLASSES };

test.beforeEach(requireV2Dialect);

test.describe("percent class access", () => {
  test.afterAll(async () => {
    await adminRequest("DELETE", "/web-app/pct-access", KEYS);
  });

  test("PUT /v2/web-app/pct-access grants access the instance then lists", async ({ request }) => {
    await adminRequest("DELETE", "/web-app/pct-access", KEYS);
    await mutate(request, {
      operationId: "PUT /v2/web-app/pct-access",
      keys: KEYS,
      proposed: { AllowAccess: true },
    });
    await verifiedEffect(
      { operationId: "PUT /v2/web-app/pct-access", subject: `${APP} -> ${CLASSES}`, proves: "the instance lists the grant it did not have before" },
      async () => {
        const after = await adminRequest("GET", "/web-app/pct-accesses", { name: APP, maxRows: "200" });
        const rows = ((after.json as { result?: { Class?: string }[] })?.result ?? []);
        expect(rows.some((row) => (row.Class ?? "") === CLASSES), "the grant was not listed after FlightDeck created it").toBe(true);
      },
    );
  });

  test("DELETE /v2/web-app/pct-access removes it, and the instance stops listing it", async ({ request }) => {
    await adminRequest("PUT", "/web-app/pct-access", KEYS, { AllowAccess: true });
    await mutate(request, {
      operationId: "DELETE /v2/web-app/pct-access",
      keys: KEYS,
    });
    await verifiedEffect(
      { operationId: "DELETE /v2/web-app/pct-access", subject: `${APP} -> ${CLASSES}`, proves: "the instance no longer lists the grant" },
      async () => {
        const after = await adminRequest("GET", "/web-app/pct-accesses", { name: APP, maxRows: "200" });
        const rows = ((after.json as { result?: { Class?: string }[] })?.result ?? []);
        expect(rows.some((row) => (row.Class ?? "") === CLASSES), "the grant is still listed after it was deleted").toBe(false);
      },
    );
  });

  test("GET /v2/web-app/pct-accesses is what the section reads", async ({ request }) => {
    await adminRequest("PUT", "/web-app/pct-access", KEYS, { AllowAccess: true });
    await verifiedRead("GET /v2/web-app/pct-accesses", "FlightDeck lists the grants the instance holds for that application", async () => {
      const rows = await list(request, "web-apps", "pct-access", { name: APP });
      expect(rows.items.some((item) => item.displayName.includes("FDFunctional")), "FlightDeck did not list the grant").toBe(true);
    });
  });
});
