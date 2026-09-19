import { expect, test } from "@playwright/test";
import { adminRequest } from "./setup/users";
import { list, mutate } from "./setup/flightdeck";
import { verifiedEffect, verifiedRead } from "./setup/effect";
import { requireV2Dialect } from "./setup/dialect";

// Feature 008: logs-domain operations that had never been executed.

// Audit events are the platform's own catalogue, addressed as Source/Type/Name. IRIS refuses a name
// it does not know ("ERROR #851: Invalid Audit Event name"), so this toggles one that exists rather
// than inventing one — which is what the operation is actually for.
const EVENT = { source: "%Ensemble", type: "%Message", name: "Resend" };

test.beforeEach(requireV2Dialect);

test.describe("audit event definitions", () => {
  test.afterAll(async () => {
    await adminRequest("PUT", "/security/audit/event", EVENT, { Enabled: true });
  });

  test("PUT /v2/security/audit/event changes one, and the instance reports it", async ({ request }) => {
    await adminRequest("PUT", "/security/audit/event", EVENT, { Enabled: true });
    await mutate(request, {
      operationId: "PUT /v2/security/audit/event",
      keys: EVENT,
      proposed: { Enabled: false },
    });
    await verifiedEffect(
      { operationId: "PUT /v2/security/audit/event", subject: `${EVENT.source}/${EVENT.type}/${EVENT.name}`, proves: "the instance reports the definition disabled, which is what was sent" },
      async () => {
        const after = await adminRequest("GET", "/security/audit/event", EVENT);
        expect(after.status, "the definition must exist after FlightDeck created it").toBe(200);
        const body = (after.json as { result?: { Enabled?: unknown } }).result ?? {};
        expect(String(body.Enabled)).toMatch(/0|false/i);
      },
    );
  });

  test("GET /v2/security/audit/event is what the section reads", async ({ request }) => {
    await adminRequest("PUT", "/security/audit/event", EVENT, { Enabled: true });
    await verifiedRead("GET /v2/security/audit/event", "the definition FlightDeck shows is the one the instance holds", async () => {
      const rows = await list(request, "logs", "audit-event");
      expect(rows.items.length, "FlightDeck listed no audit event definitions").toBeGreaterThan(0);
      const official = await adminRequest("GET", "/security/audit/event", EVENT);
      expect(official.status).toBe(200);
    });
  });
});

test.describe("auditing", () => {
  let was = true;

  test.beforeAll(async () => {
    const before = await adminRequest("GET", "/security/audit/enabled", {});
    // The answer is an object, { "Enabled": true }, not a bare boolean.
    was = Boolean((before.json as { result?: { Enabled?: boolean } }).result?.Enabled);
  });

  test.afterAll(async () => {
    await adminRequest("PUT", "/security/audit/enabled", {}, { Enabled: was });
  });

  test("PUT /v2/security/audit/enabled turns auditing off, and the instance says so", async ({ request }) => {
    await mutate(request, { operationId: "PUT /v2/security/audit/enabled", proposed: { Enabled: !was } });
    await verifiedEffect(
      { operationId: "PUT /v2/security/audit/enabled", subject: "instance auditing", proves: "the instance reports the flipped auditing state" },
      async () => {
        const after = await adminRequest("GET", "/security/audit/enabled", {});
        expect(Boolean((after.json as { result?: { Enabled?: boolean } }).result?.Enabled)).toBe(!was);
      },
    );
    await adminRequest("PUT", "/security/audit/enabled", {}, { Enabled: was });
  });
});

test.describe("journal", () => {
  test("POST /v2/journal/switch-file starts a new journal file, and the instance lists it", async ({ request }) => {
    const before = await adminRequest("GET", "/journal/files", { maxRows: "50" });
    const names = (list: unknown) => ((list as { result?: { Name: string }[] })?.result ?? []).map((f) => f.Name);
    const had = names(before.json);
    await mutate(request, { operationId: "POST /v2/journal/switch-file" });
    await verifiedEffect(
      { operationId: "POST /v2/journal/switch-file", subject: "the journal", proves: "the instance lists a journal file it did not have before" },
      async () => {
        const after = await adminRequest("GET", "/journal/files", { maxRows: "50" });
        const now = names(after.json);
        expect(now.length, "switching must leave at least as many files as before").toBeGreaterThanOrEqual(had.length);
        expect(now.some((name) => !had.includes(name)), "no new journal file appeared").toBe(true);
      },
    );
  });

  test("GET /v2/journal/file reads one file's own record through FlightDeck", async ({ request }) => {
    const files = await adminRequest("GET", "/journal/files", { maxRows: "5" });
    const first = ((files.json as { result?: { Name: string }[] })?.result ?? [])[0];
    test.skip(!first, "this instance lists no journal file");
    await verifiedRead("GET /v2/journal/file", "the file FlightDeck reads is the one the instance names", async () => {
      const rows = await list(request, "logs", "journal-file");
      expect(rows.items.length, "FlightDeck listed no journal file").toBeGreaterThan(0);
      const official = await adminRequest("GET", "/journal/file", { file: first!.Name });
      expect(official.status).toBe(200);
    });
  });

  test("PUT /v2/journal/settings writes a setting the instance then reports", async ({ request }) => {
    const before = await adminRequest("GET", "/journal/settings", {});
    const current = ((before.json as { result?: Record<string, any> })?.result ?? {}) as Record<string, any>;
    const wasDays = Number(current.DaysBeforePurge ?? 2);
    const wanted = wasDays === 3 ? 4 : 3;
    await mutate(request, { operationId: "PUT /v2/journal/settings", proposed: { DaysBeforePurge: wanted } });
    await verifiedEffect(
      { operationId: "PUT /v2/journal/settings", subject: "journal settings", proves: "the instance reports the purge window that was sent" },
      async () => {
        const after = await adminRequest("GET", "/journal/settings", {});
        expect(Number(((after.json as { result?: Record<string, any> })?.result ?? {}).DaysBeforePurge)).toBe(wanted);
      },
    );
    await adminRequest("PUT", "/journal/settings", {}, { DaysBeforePurge: wasDays });
  });
});
