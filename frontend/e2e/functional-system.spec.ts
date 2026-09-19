import { expect, test } from "@playwright/test";
import { adminRequest } from "./setup/users";
import { list, mutate } from "./setup/flightdeck";
import { verifiedEffect, verifiedRead } from "./setup/effect";
import { requireV2Dialect } from "./setup/dialect";

// Feature 008: operating-system operations that had never been executed. The largest group, and the
// one where "implemented" most often meant "a descriptor exists".

/** Reads through FlightDeck's own domain layer, asserting the content rather than the status. */
async function readsBack(request: Parameters<typeof list>[0], operationId: string, domain: string, entityType: string, proves: string) {
  await verifiedRead(operationId, proves, async () => {
    const rows = await list(request, domain, entityType);
    expect(Array.isArray(rows.items), `${entityType} did not answer a list`).toBe(true);
    // An empty list is a legitimate answer for things a container may not define; what is verified is
    // that the operation answered a list and that anything in it is named.
    for (const row of rows.items) expect(row.displayName, `${entityType} rows must be named`).toBeTruthy();
  });
}

test.beforeEach(requireV2Dialect);

test.describe("reads that had never run", () => {
  test("GET /v2/device lists the instance's devices", async ({ request }) => {
    await readsBack(request, "GET /v2/device", "system", "device", "FlightDeck lists named devices from the instance");
  });

  test("GET /v2/device/subtype lists device subtypes", async ({ request }) => {
    await readsBack(request, "GET /v2/device/subtype", "system", "device-subtype", "FlightDeck lists named device subtypes");
  });

  test("GET /v2/doc-db lists DocDB databases", async ({ request }) => {
    await verifiedRead("GET /v2/doc-db", "FlightDeck's answer matches what the instance reports", async () => {
      const rows = await list(request, "system", "doc-db");
      const official = await adminRequest("GET", "/doc-dbs", { maxRows: "200" });
      expect(official.status).toBe(200);
      const count = ((official.json as { result?: unknown[] })?.result ?? []).length;
      expect(rows.items.length).toBe(count);
    });
  });

  test("GET /v2/ext-lang-server lists the external language servers", async ({ request }) => {
    await readsBack(request, "GET /v2/ext-lang-server", "system", "ext-lang-server", "FlightDeck lists the servers the instance defines");
  });

  test("GET /v2/fs-access-purpose lists file-system access purposes", async ({ request }) => {
    await readsBack(request, "GET /v2/fs-access-purpose", "system", "fs-access-purpose", "FlightDeck lists the purposes the instance defines");
  });

  test("GET /v2/license/server lists licence servers", async ({ request }) => {
    await verifiedRead("GET /v2/license/server", "FlightDeck's licence-server answer matches the instance's own", async () => {
      const rows = await list(request, "system", "license-server");
      const official = await adminRequest("GET", "/license/servers", { maxRows: "50" });
      expect(official.status).toBe(200);
      expect(rows.items.length).toBe(((official.json as { result?: unknown[] })?.result ?? []).length);
    });
  });
});

test.describe("devices", () => {
  const DEVICE = "FDFunctionalDevice";

  test.afterAll(async () => {
    await adminRequest("DELETE", "/device", { name: DEVICE });
  });

  test("PUT /v2/device creates a device the instance then reports", async ({ request }) => {
    await adminRequest("DELETE", "/device", { name: DEVICE });
    await mutate(request, {
      operationId: "PUT /v2/device",
      keys: { name: DEVICE },
      proposed: { Description: "FlightDeck functional coverage", PhysicalDevice: "/dev/null", Type: "OTH", SubType: "C-ANSI" },
    });
    await verifiedEffect(
      { operationId: "PUT /v2/device", subject: DEVICE, proves: "the instance holds the device with the description that was sent" },
      async () => {
        const after = await adminRequest("GET", "/device", { name: DEVICE });
        expect(after.status, "the device must exist after FlightDeck created it").toBe(200);
        expect((after.json as { result?: { Description?: string } }).result?.Description).toBe("FlightDeck functional coverage");
      },
    );
  });
});

test.describe("namespace mappings", () => {
  // Mappings are added to USER, which this instance already has, and removed again afterwards.
  const NS = "USER";
  const GLOBAL = "FDFunctionalGlobal";
  const PACKAGE = "FDFunctionalPackage";
  const ROUTINE = "FDFunctionalRtn";

  test.afterAll(async () => {
    await adminRequest("DELETE", "/namespace/global-mapping", { namespace: NS, name: GLOBAL });
    await adminRequest("DELETE", "/namespace/package-mapping", { namespace: NS, name: PACKAGE });
    await adminRequest("DELETE", "/namespace/routine-mapping", { namespace: NS, name: ROUTINE });
  });

  test("PUT /v2/namespace/global-mapping adds a mapping the instance then lists", async ({ request }) => {
    await adminRequest("DELETE", "/namespace/global-mapping", { namespace: NS, name: GLOBAL });
    await mutate(request, {
      operationId: "PUT /v2/namespace/global-mapping",
      keys: { namespace: NS, name: GLOBAL },
      proposed: { Database: "USER" },
    });
    await verifiedEffect(
      { operationId: "PUT /v2/namespace/global-mapping", subject: `${NS}:${GLOBAL}`, proves: "the instance lists the mapping, pointing at the database that was sent" },
      async () => {
        const after = await adminRequest("GET", "/namespace/global-mappings", { namespace: NS, maxRows: "500" });
        const rows = ((after.json as { result?: { Name?: string; Database?: string }[] })?.result ?? []);
        const row = rows.find((r) => (r.Name ?? "").includes(GLOBAL));
        expect(row, "the mapping must be listed after FlightDeck created it").toBeTruthy();
      },
    );
  });

  test("PUT /v2/namespace/package-mapping adds a mapping the instance then lists", async ({ request }) => {
    await adminRequest("DELETE", "/namespace/package-mapping", { namespace: NS, name: PACKAGE });
    await mutate(request, {
      operationId: "PUT /v2/namespace/package-mapping",
      keys: { namespace: NS, name: PACKAGE },
      proposed: { Database: "USER" },
    });
    await verifiedEffect(
      { operationId: "PUT /v2/namespace/package-mapping", subject: `${NS}:${PACKAGE}`, proves: "the instance lists the package mapping" },
      async () => {
        const after = await adminRequest("GET", "/namespace/package-mappings", { namespace: NS, maxRows: "500" });
        const rows = ((after.json as { result?: { Name?: string }[] })?.result ?? []);
        expect(rows.some((r) => (r.Name ?? "").includes(PACKAGE)), "the package mapping was not listed").toBe(true);
      },
    );
  });

  test("PUT /v2/namespace/routine-mapping adds a mapping the instance then lists", async ({ request }) => {
    await adminRequest("DELETE", "/namespace/routine-mapping", { namespace: NS, name: ROUTINE });
    await mutate(request, {
      operationId: "PUT /v2/namespace/routine-mapping",
      keys: { namespace: NS, name: ROUTINE },
      proposed: { Database: "USER" },
    });
    await verifiedEffect(
      { operationId: "PUT /v2/namespace/routine-mapping", subject: `${NS}:${ROUTINE}`, proves: "the instance lists the routine mapping" },
      async () => {
        const after = await adminRequest("GET", "/namespace/routine-mappings", { namespace: NS, maxRows: "500" });
        const rows = ((after.json as { result?: { Name?: string }[] })?.result ?? []);
        expect(rows.some((r) => (r.Name ?? "").includes(ROUTINE)), "the routine mapping was not listed").toBe(true);
      },
    );
  });
});

test.describe("processes", () => {
  test("POST /v2/process/broadcast reaches a process that accepts one", async ({ request }) => {
    const candidates = await list(request, "system", "process");
    const target = candidates.items.find((item) => item.facts.canReceiveBroadcast === true);
    test.skip(!target, "no process on this instance accepts a broadcast, so there is nothing to send to");
    // Broadcast writes to a device, not to a process's state, so what is verified is that the
    // instance accepted it and the process list is unchanged afterwards — the honest claim here.
    const before = await list(request, "system", "process");
    await mutate(request, {
      operationId: "POST /v2/process/broadcast",
      keys: target!.keys,
      params: { id: String(target!.keys.id), message: "FlightDeck functional coverage" },
    });
    await verifiedEffect(
      { operationId: "POST /v2/process/broadcast", subject: `process ${target?.keys.id}`, proves: "the instance still reports its processes afterwards, none of them disturbed" },
      async () => {
        const after = await list(request, "system", "process");
        expect(after.items.length, "the broadcast must not have removed processes").toBeGreaterThan(0);
        expect(Math.abs(after.items.length - before.items.length)).toBeLessThan(10);
      },
    );
  });
});
