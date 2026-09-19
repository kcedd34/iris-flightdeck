import { expect, test } from "@playwright/test";
import { adminRequest } from "./setup/users";
import { mutate } from "./setup/flightdeck";
import { verifiedEffect } from "./setup/effect";
import { requireV2Dialect } from "./setup/dialect";

// Feature 008, step 4: destructive operations, on targets the tests create for themselves.
//
// The rule every test here follows: **create the thing, destroy it through FlightDeck, then prove it
// is gone by asking the instance.** Nothing points at an object the instance needs, and every block
// has an afterAll that removes its subject however the test ended. Residue from an earlier run of
// this suite already left a task manager suspended and auditing disabled once; from a destructive
// test the residue is the deletion itself, which is worse and does not undo.
//
// Operations with no target that can be created safely are not here. They are exempted by name in
// scripts/build/functional-exemptions.json, each with its own reason.

/** Creates the subject through the official API, so the create is not what is under test. */
async function given(path: string, keys: Record<string, string>, body: Record<string, unknown>) {
  const response = await adminRequest("PUT", path, keys, body);
  expect(response.status, `could not set up ${path} ${JSON.stringify(keys)}: ${JSON.stringify(response.json).slice(0, 200)}`).toBeLessThan(300);
}

/** Asks the instance directly whether the subject is still there. */
async function gone(path: string, keys: Record<string, string>) {
  const response = await adminRequest("GET", path, keys);
  expect(response.status, `the instance still holds ${path} ${JSON.stringify(keys)}`).not.toBe(200);
}

/** IRIS refuses a schedule whose start is already past, so this is always ahead of the clock. */
function tomorrow(): string {
  const date = new Date(Date.now() + 24 * 60 * 60 * 1000);
  return date.toISOString().slice(0, 10);
}

test.beforeEach(requireV2Dialect);

test.describe("privileged routines", () => {
  const NAME = "FDDestructiveRoutine";
  test.afterAll(async () => void (await adminRequest("DELETE", "/security/privileged-routine", { name: NAME })));

  test("DELETE /v2/security/privileged-routine removes one, and the instance stops holding it", async ({ request }) => {
    await given("/security/privileged-routine", { name: NAME }, { Description: "created to be deleted" });
    await mutate(request, { operationId: "DELETE /v2/security/privileged-routine", keys: { name: NAME } });
    await verifiedEffect(
      { operationId: "DELETE /v2/security/privileged-routine", subject: NAME, proves: "the instance no longer holds the routine" },
      async () => gone("/security/privileged-routine", { name: NAME }),
    );
  });
});

test.describe("TLS configurations", () => {
  const NAME = "FDDestructiveTLS";
  test.afterAll(async () => void (await adminRequest("DELETE", "/security/ssl-configuration", { name: NAME })));

  test("DELETE /v2/security/ssl-configuration removes one, and the instance stops holding it", async ({ request }) => {
    await given("/security/ssl-configuration", { name: NAME }, { Description: "created to be deleted", Enabled: true, Type: "0", VerifyPeer: 0 });
    await mutate(request, { operationId: "DELETE /v2/security/ssl-configuration", keys: { name: NAME } });
    await verifiedEffect(
      { operationId: "DELETE /v2/security/ssl-configuration", subject: NAME, proves: "the instance no longer holds the configuration" },
      async () => gone("/security/ssl-configuration", { name: NAME }),
    );
  });
});

test.describe("devices", () => {
  const NAME = "FDDestructiveDevice";
  test.afterAll(async () => void (await adminRequest("DELETE", "/device", { name: NAME })));

  test("DELETE /v2/device removes one, and the instance stops holding it", async ({ request }) => {
    await given("/device", { name: NAME }, { Description: "created to be deleted", PhysicalDevice: "/dev/null", Type: "OTH", SubType: "C-ANSI" });
    await mutate(request, { operationId: "DELETE /v2/device", keys: { name: NAME } });
    await verifiedEffect(
      { operationId: "DELETE /v2/device", subject: NAME, proves: "the instance no longer holds the device" },
      async () => gone("/device", { name: NAME }),
    );
  });
});

test.describe("work queue categories", () => {
  const NAME = "FDDestructiveCategory";
  test.afterAll(async () => void (await adminRequest("DELETE", "/wqm-category", { name: NAME })));

  test("DELETE /v2/wqm-category removes one, and the instance stops holding it", async ({ request }) => {
    await given("/wqm-category", { name: NAME }, { DefaultWorkers: 1, MaxActiveWorkers: 1, MaxTotalWorkers: 2 });
    await mutate(request, { operationId: "DELETE /v2/wqm-category", keys: { name: NAME } });
    await verifiedEffect(
      { operationId: "DELETE /v2/wqm-category", subject: NAME, proves: "the instance no longer holds the category" },
      async () => gone("/wqm-category", { name: NAME }),
    );
  });
});

test.describe("namespace mappings", () => {
  const NS = "USER";
  const G = "FDDestructiveGlobal";
  const P = "FDDestructivePackage";
  const R = "FDDestructiveRtn";

  test.afterAll(async () => {
    await adminRequest("DELETE", "/namespace/global-mapping", { namespace: NS, name: G });
    await adminRequest("DELETE", "/namespace/package-mapping", { namespace: NS, name: P });
    await adminRequest("DELETE", "/namespace/routine-mapping", { namespace: NS, name: R });
  });

  for (const [op, path, name] of [
    ["DELETE /v2/namespace/global-mapping", "/namespace/global-mapping", G],
    ["DELETE /v2/namespace/package-mapping", "/namespace/package-mapping", P],
    ["DELETE /v2/namespace/routine-mapping", "/namespace/routine-mapping", R],
  ] as const) {
    test(`${op} removes the mapping, and the instance stops listing it`, async ({ request }) => {
      await given(path, { namespace: NS, name }, { Database: "USER" });
      await mutate(request, { operationId: op, keys: { namespace: NS, name } });
      await verifiedEffect(
        { operationId: op, subject: `${NS}:${name}`, proves: "the instance no longer holds the mapping" },
        async () => gone(path, { namespace: NS, name }),
      );
    });
  }
});

test.describe("tasks", () => {
  const NAME = "FD Destructive Task";
  let created: string | null = null;

  async function idOf(name: string): Promise<string | null> {
    const response = await adminRequest("GET", "/tasks", {});
    const rows = ((response.json as { result?: { Name: string; Id: number }[] })?.result ?? []);
    const found = rows.find((row) => row.Name === name);
    return found ? String(found.Id) : null;
  }

  test.afterAll(async () => {
    const id = created ?? (await idOf(NAME));
    if (id) await adminRequest("DELETE", "/task", { id });
  });

  test("DELETE /v2/task removes a task this test created, and the instance stops listing it", async ({ request }) => {
    const existing = await idOf(NAME);
    if (existing) await adminRequest("DELETE", "/task", { id: existing });
    const create = await adminRequest("POST", "/task", {}, {
      Name: NAME, Description: "created to be deleted", NameSpace: "USER", TaskClass: "FlightDeck.Demo.NoopTask",
      RunAsUser: "_SYSTEM", EmailOnCompletion: [], EmailOnError: [], EmailOnExpiration: [], EmailOutput: false,
      Expires: false, ExpiresDays: "", ExpiresHours: "", ExpiresMinutes: "", OpenOutputFile: false,
      OutputDirectory: "", OutputFilename: "", OutputFileIsBinary: false, Priority: "Normal",
      TimePeriod: "Daily", TimePeriodEvery: 1, TimePeriodDay: "", DailyFrequency: "Once",
      DailyFrequencyTime: "", DailyIncrement: "", DailyStartTime: "03:00:00", DailyEndTime: "00:00:00",
      StartDate: tomorrow(), EndDate: "", RunAfterGUID: "", MirrorStatus: "Primary",
      SuspendOnError: false, SuspendTerminated: false, IsBatch: false, RescheduleOnStart: false, Settings: {},
    });
    expect(create.status, `could not create the task to delete: ${JSON.stringify(create.json).slice(0, 200)}`).toBeLessThan(300);
    created = await idOf(NAME);
    expect(created, "the task to delete was not created").not.toBeNull();

    await mutate(request, { operationId: "DELETE /v2/task", keys: { id: created! } });
    await verifiedEffect(
      { operationId: "DELETE /v2/task", subject: `task ${created}`, proves: "the instance no longer lists the task" },
      async () => {
        expect(await idOf(NAME), "the task is still listed after it was deleted").toBeNull();
        created = null;
      },
    );
  });
});

test.describe("licence servers", () => {
  const NAME = "FDDestructiveLicSrv";
  test.afterAll(async () => void (await adminRequest("DELETE", "/license/server", { name: NAME })));

  test("DELETE /v2/license/server removes one, and the instance stops holding it", async ({ request }) => {
    const setup = await adminRequest("PUT", "/license/server", { name: NAME }, { Address: "127.0.0.1", Port: 4002 });
    test.skip(setup.status >= 300, `this instance would not accept a licence server to delete (${setup.status})`);
    await mutate(request, { operationId: "DELETE /v2/license/server", keys: { name: NAME } });
    await verifiedEffect(
      { operationId: "DELETE /v2/license/server", subject: NAME, proves: "the instance no longer holds the licence server" },
      async () => gone("/license/server", { name: NAME }),
    );
  });
});

test.describe("external language servers", () => {
  const NAME = "FDDestructiveLangSrv";
  test.afterAll(async () => void (await adminRequest("DELETE", "/ext-lang-server", { name: NAME })));

  test("DELETE /v2/ext-lang-server removes one, and the instance stops holding it", async ({ request }) => {
    const setup = await adminRequest("PUT", "/ext-lang-server", { name: NAME }, { Type: "Python", Port: 51999, Server: "127.0.0.1" });
    test.skip(setup.status >= 300, `this instance would not accept a language server to delete (${setup.status})`);
    await mutate(request, { operationId: "DELETE /v2/ext-lang-server", keys: { name: NAME } });
    await verifiedEffect(
      { operationId: "DELETE /v2/ext-lang-server", subject: NAME, proves: "the instance no longer holds the language server" },
      async () => gone("/ext-lang-server", { name: NAME }),
    );
  });
});
