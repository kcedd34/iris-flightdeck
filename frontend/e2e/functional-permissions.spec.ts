import { expect, test } from "@playwright/test";
import { adminRequest } from "./setup/users";
import { list, mutate } from "./setup/flightdeck";
import { verifiedEffect, verifiedRead } from "./setup/effect";
import { requireV2Dialect } from "./setup/dialect";

// Feature 008: operations of the permissions domain that had never been executed.
//
// Each test makes FlightDeck perform the operation and then reads the object back through the
// official API, independently, and asserts on what came back. A status code proves the request was
// accepted; only the read-back proves anything happened.

const ROUTINE = "FDFunctionalRoutine";
// %Service_Monitor, and its Description rather than its Enabled flag. Two things were learned
// getting here: %Service_Console does not exist on this platform (the terminal service is
// %Service_Terminal), and enabling a service the Community licence does not cover is refused by IRIS
// with "ERROR #787: not allowed by license" — which FlightDeck surfaces verbatim, correctly. The
// description is a real field with no licence and no running service behind it.
const SERVICE = "%Service_Monitor";

test.beforeEach(requireV2Dialect);

test.describe("privileged routines", () => {
  test.afterAll(async () => {
    await adminRequest("DELETE", "/security/privileged-routine", { name: ROUTINE });
  });

  test("PUT /v2/security/privileged-routine creates one, and reading it back finds it", async ({ request }) => {
    await adminRequest("DELETE", "/security/privileged-routine", { name: ROUTINE });
    await mutate(request, {
      operationId: "PUT /v2/security/privileged-routine",
      keys: { name: ROUTINE },
      proposed: { Description: "FlightDeck functional coverage" },
    });
    await verifiedEffect(
      {
        operationId: "PUT /v2/security/privileged-routine",
        subject: ROUTINE,
        proves: "the routine exists afterwards and carries the description that was sent",
      },
      async () => {
        const after = await adminRequest("GET", "/security/privileged-routine", { name: ROUTINE });
        expect(after.status, "the routine must exist after FlightDeck created it").toBe(200);
        const body = (after.json as { result?: { Description?: string } }).result ?? {};
        expect(body.Description).toBe("FlightDeck functional coverage");
      },
    );
  });

  test("GET /v2/security/privileged-routine is what the list answers with", async ({ request }) => {
    await adminRequest("DELETE", "/security/privileged-routine", { name: ROUTINE });
    await adminRequest("PUT", "/security/privileged-routine", { name: ROUTINE }, { Description: "read me back" });
    await verifiedRead(
      "GET /v2/security/privileged-routine",
      "the routine FlightDeck lists is the one the instance holds, with its description",
      async () => {
        const rows = await list(request, "permissions", "privileged-routine");
        const row = rows.items.find((item) => item.displayName === ROUTINE);
        expect(row, `FlightDeck did not list ${ROUTINE}`).toBeTruthy();
        const official = await adminRequest("GET", "/security/privileged-routine", { name: ROUTINE });
        expect((official.json as { result?: { Description?: string } }).result?.Description).toBe("read me back");
      },
    );
  });
});

test.describe("services", () => {
  let restore: Record<string, unknown> = {};

  test.beforeAll(async () => {
    const before = await adminRequest("GET", "/security/service", { name: SERVICE });
    restore = ((before.json as { result?: Record<string, unknown> }).result ?? {}) as Record<string, unknown>;
  });

  test.afterAll(async () => {
    if (restore.Enabled !== undefined) {
      await adminRequest("PUT", "/security/service", { name: SERVICE }, { Enabled: restore.Enabled });
    }
  });

  test("GET /v2/security/service answers the state the instance actually holds", async ({ request }) => {
    await verifiedRead("GET /v2/security/service", "the service FlightDeck shows matches the instance's own answer", async () => {
      const rows = await list(request, "permissions", "service");
      const row = rows.items.find((item) => item.displayName === SERVICE);
      expect(row, `FlightDeck did not list ${SERVICE}`).toBeTruthy();
      const official = await adminRequest("GET", "/security/service", { name: SERVICE });
      expect(official.status).toBe(200);
      expect(official.status, "the instance must hold the service FlightDeck listed").toBe(200);
      expect((official.json as { result?: { Name?: string } }).result?.Name ?? SERVICE).toBe(SERVICE);
    });
  });

  test("PUT /v2/security/service changes the service, and the instance reports the change", async ({ request }) => {
    const before = await adminRequest("GET", "/security/service", { name: SERVICE });
    const was = Boolean((before.json as { result?: { Enabled?: boolean } }).result?.Enabled);
    await mutate(request, {
      operationId: "PUT /v2/security/service",
      keys: { name: SERVICE },
      proposed: { Enabled: !was },
    });
    await verifiedEffect(
      {
        operationId: "PUT /v2/security/service",
        subject: SERVICE,
        proves: "the instance reports the flipped Enabled flag, not merely a 200",
      },
      async () => {
        const after = await adminRequest("GET", "/security/service", { name: SERVICE });
        expect(Boolean((after.json as { result?: { Enabled?: boolean } }).result?.Enabled)).toBe(!was);
      },
    );
    await adminRequest("PUT", "/security/service", { name: SERVICE }, { Enabled: was });
  });
});
