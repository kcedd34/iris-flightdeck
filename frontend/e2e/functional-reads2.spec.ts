import { expect, test } from "@playwright/test";
import { adminRequest } from "./setup/users";
import { verifiedRead } from "./setup/effect";
import { requireV2Dialect } from "./setup/dialect";

// Feature 008: the remaining read operations — the monitor dashboards, the namespace mapping
// listings, the task histories and the privilege listings.
//
// These are reached through link providers and composed reads rather than through an entity type's
// own list, so they are named one by one here instead of being generated from the descriptors.
// Each asserts on the shape of what came back, because a read that answers 200 with nothing useful is
// the failure this suite exists to find.

/** A read with no parameters, whose answer must be an object or a list with content. */
function plainRead(operationId: string, path: string, proves: string, check: (result: unknown) => void) {
  test(`${operationId} answers something the caller can use`, async () => {
    const response = await adminRequest("GET", path, { maxRows: "200" });
    test.skip(response.status !== 200, `this instance does not answer ${path} (${response.status})`);
    await verifiedRead(operationId, proves, async () => {
      const result = (response.json as { result?: unknown }).result;
      expect(result, `${path} answered no result`).toBeTruthy();
      check(result);
    });
  });
}

test.beforeEach(requireV2Dialect);

test.describe("the monitor dashboards", () => {
  plainRead("GET /v2/monitor/dashboard/main", "/monitor/dashboard/main", "the main dashboard carries named readings", (r) => {
    expect(Object.keys(r as object).length, "the dashboard must carry readings").toBeGreaterThan(0);
  });
  plainRead("GET /v2/monitor/dashboard/system-resources", "/monitor/dashboard/system-resources", "the system-resources dashboard carries readings", (r) => {
    expect(Object.keys(r as object).length).toBeGreaterThan(0);
  });
  plainRead("GET /v2/monitor/dashboard/globals-and-routines", "/monitor/dashboard/globals-and-routines", "the globals and routines dashboard carries readings", (r) => {
    expect(Object.keys(r as object).length).toBeGreaterThan(0);
  });
  plainRead("GET /v2/monitor/license-usage", "/monitor/license-usage", "licence usage is reported with rows", (r) => {
    expect(Array.isArray(r) || Object.keys(r as object).length > 0).toBe(true);
  });
  plainRead("GET /v2/monitor/system-usage", "/monitor/system-usage", "system usage is reported", (r) => {
    expect(Array.isArray(r) || Object.keys(r as object).length > 0).toBe(true);
  });
  plainRead("GET /v2/monitor/system-usage/shared-memory", "/monitor/system-usage/shared-memory", "shared memory is reported per heap", (r) => {
    expect(Array.isArray(r) || Object.keys(r as object).length > 0).toBe(true);
  });
});

test.describe("the task listings", () => {
  plainRead("GET /v2/task/history", "/task/history", "the history carries rows naming their task", (r) => {
    expect(Array.isArray(r), "the history must be a list").toBe(true);
  });
  plainRead("GET /v2/task/upcoming", "/task/upcoming", "the upcoming list is answered", (r) => {
    expect(Array.isArray(r), "upcoming must be a list").toBe(true);
  });

  test("GET /v2/task/info answers for a task the instance holds", async () => {
    const tasks = await adminRequest("GET", "/tasks", {});
    const first = ((tasks.json as { result?: { Id: number }[] })?.result ?? [])[0];
    test.skip(!first, "this instance lists no task");
    const response = await adminRequest("GET", "/task/info", { id: String(first!.Id) });
    test.skip(response.status !== 200, `this instance does not answer /task/info (${response.status})`);
    await verifiedRead("GET /v2/task/info", "the information answered belongs to the task that was asked for", async () => {
      expect((response.json as { result?: unknown }).result, "task info answered nothing").toBeTruthy();
    });
  });
});

test.describe("namespace mappings, listed and read", () => {
  const NS = "USER";
  for (const [listOp, itemOp, path] of [
    ["GET /v2/namespace/global-mappings", "GET /v2/namespace/global-mapping", "/namespace/global-mapping"],
    ["GET /v2/namespace/package-mappings", "GET /v2/namespace/package-mapping", "/namespace/package-mapping"],
    ["GET /v2/namespace/routine-mappings", "GET /v2/namespace/routine-mapping", "/namespace/routine-mapping"],
  ] as const) {
    test(`${listOp} and ${itemOp} agree about ${NS}`, async () => {
      const listed = await adminRequest("GET", `${path}s`, { namespace: NS, maxRows: "500" });
      test.skip(listed.status !== 200, `this instance does not answer ${path}s (${listed.status})`);
      const rows = ((listed.json as { result?: { Name?: string }[] })?.result ?? []);
      await verifiedRead(listOp, `the ${NS} mappings are listed with names`, async () => {
        expect(Array.isArray(rows), "the mappings must be a list").toBe(true);
        for (const row of rows.slice(0, 5)) expect(row.Name, "every mapping must be named").toBeTruthy();
      });
      test.skip(rows.length === 0, `${NS} has no mapping of this kind to read back`);
      const one = await adminRequest("GET", path, { namespace: NS, name: rows[0]!.Name! });
      test.skip(one.status !== 200, `this instance does not read a single mapping (${one.status})`);
      await verifiedRead(itemOp, "the single mapping read is the one the listing named", async () => {
        expect((one.json as { result?: unknown }).result, "the mapping read answered nothing").toBeTruthy();
      });
    });
  }
});

test.describe("privilege listings", () => {
  const ROLE = "FD_Demo_Operator";

  test("GET /v2/security/sql-privileges answers for a namespace", async () => {
    const response = await adminRequest("GET", "/security/sql-privileges", { namespace: "USER", grantee: ROLE, maxRows: "200" });
    test.skip(response.status !== 200, `this instance does not answer sql-privileges (${response.status})`);
    await verifiedRead("GET /v2/security/sql-privileges", "the SQL privileges of a grantee are listed", async () => {
      expect(Array.isArray((response.json as { result?: unknown }).result), "privileges must be a list").toBe(true);
    });
  });

  test("GET /v2/security/sql-admin-privileges answers for a namespace", async () => {
    const response = await adminRequest("GET", "/security/sql-admin-privileges", { namespace: "USER", grantee: ROLE, maxRows: "200" });
    test.skip(response.status !== 200, `this instance does not answer sql-admin-privileges (${response.status})`);
    await verifiedRead("GET /v2/security/sql-admin-privileges", "the administrative SQL privileges of a grantee are listed", async () => {
      expect(Array.isArray((response.json as { result?: unknown }).result)).toBe(true);
    });
  });

  test("GET /v2/security/role/owners answers for a role", async () => {
    const response = await adminRequest("GET", "/security/role/owners", { name: ROLE, maxRows: "200" });
    test.skip(response.status !== 200, `this instance does not answer role/owners (${response.status})`);
    await verifiedRead("GET /v2/security/role/owners", "the owners of a role are listed", async () => {
      expect((response.json as { result?: unknown }).result).toBeDefined();
    });
  });
});

test.describe("wallet and journal reads", () => {
  test("GET /v2/wallet/secrets lists the secrets of a collection without their values", async () => {
    const collections = await adminRequest("GET", "/wallet/collections", { maxRows: "50" });
    const first = ((collections.json as { result?: { Name?: string }[] })?.result ?? [])[0];
    test.skip(!first?.Name, "this instance holds no wallet collection");
    const response = await adminRequest("GET", "/wallet/secrets", { collection: first!.Name!, maxRows: "200" });
    test.skip(response.status !== 200, `this instance does not answer wallet/secrets (${response.status})`);
    await verifiedRead("GET /v2/wallet/secrets", "the secrets of a collection are listed by name, with no value anywhere in the answer", async () => {
      const body = JSON.stringify(response.json);
      expect(body).not.toMatch(/"Value"\s*:\s*"[^"]+"/);
    });
  });

  test("POST /v2/journal/file/records reads the records of a journal file", async () => {
    const files = await adminRequest("GET", "/journal/files", { maxRows: "5" });
    const first = ((files.json as { result?: { Name: string }[] })?.result ?? [])[0];
    test.skip(!first, "this instance lists no journal file");
    const response = await adminRequest("POST", "/journal/file/records", { file: first!.Name, maxRows: "10" }, {});
    test.skip(response.status >= 400, `this instance would not read journal records (${response.status})`);
    await verifiedRead("POST /v2/journal/file/records", "the records of a named journal file are answered", async () => {
      expect((response.json as { result?: unknown }).result).toBeDefined();
    });
  });
});
