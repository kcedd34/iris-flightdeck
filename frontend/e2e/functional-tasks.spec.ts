import { expect, test } from "@playwright/test";
import { adminRequest } from "./setup/users";
import { list, mutate } from "./setup/flightdeck";
import { verifiedEffect, verifiedRead } from "./setup/effect";
import { requireV2Dialect } from "./setup/dialect";

// Feature 008: task-domain operations that had never been executed.
// Each one is performed through FlightDeck and then read back through the official API.

const TASK = "FD Functional Task";
const CATEGORY = "FDFunctionalCategory";

async function taskId(name: string): Promise<number | null> {
  const response = await adminRequest("GET", "/tasks", {});
  const rows = ((response.json as { result?: { Name: string; Id: number }[] })?.result ?? []) as { Name: string; Id: number }[];
  return rows.find((row) => row.Name === name)?.Id ?? null;
}

/** IRIS refuses a schedule whose start is already past, so this is always ahead of the clock. */
function tomorrow(): string {
  const date = new Date(Date.now() + 24 * 60 * 60 * 1000);
  return date.toISOString().slice(0, 10);
}

test.beforeEach(requireV2Dialect);

test.describe("tasks", () => {
  test.afterAll(async () => {
    const id = await taskId(TASK);
    if (id !== null) await adminRequest("DELETE", "/task", { id: String(id) });
  });

  test("POST /v2/task creates a task that the instance then lists", async ({ request }) => {
    const existing = await taskId(TASK);
    if (existing !== null) await adminRequest("DELETE", "/task", { id: String(existing) });
    await mutate(request, {
      operationId: "POST /v2/task",
      // The full field set, taken from a task the instance already holds. The create rejects a
      // partial body one field at a time, and the enumerations are words ("Daily", "Normal"), not the
      // numbers a reader would guess — so the shape is copied rather than invented.
      proposed: {
        Name: TASK,
        Description: "FlightDeck functional coverage",
        NameSpace: "USER",
        TaskClass: "FlightDeck.Demo.NoopTask",
        RunAsUser: "_SYSTEM",
        EmailOnCompletion: [],
        EmailOnError: [],
        EmailOnExpiration: [],
        EmailOutput: false,
        Expires: false,
        ExpiresDays: "",
        ExpiresHours: "",
        ExpiresMinutes: "",
        OpenOutputFile: false,
        OutputDirectory: "",
        OutputFilename: "",
        OutputFileIsBinary: false,
        Priority: "Normal",
        TimePeriod: "Daily",
        TimePeriodEvery: 1,
        TimePeriodDay: "",
        DailyFrequency: "Once",
        DailyFrequencyTime: "",
        DailyIncrement: "",
        DailyStartTime: "03:00:00",
        DailyEndTime: "00:00:00",
        StartDate: tomorrow(),
        EndDate: "",
        RunAfterGUID: "",
        MirrorStatus: "Primary",
        SuspendOnError: false,
        SuspendTerminated: false,
        IsBatch: false,
        RescheduleOnStart: false,
        Settings: {},
      },
    });
    await verifiedEffect(
      { operationId: "POST /v2/task", subject: TASK, proves: "the instance lists a task it did not have before, under that name" },
      async () => {
        const id = await taskId(TASK);
        expect(id, "the task must exist after FlightDeck created it").not.toBeNull();
      },
    );
  });

  test("PUT /v2/task edits it, and the instance reports the new description", async ({ request }) => {
    const id = await taskId(TASK);
    test.skip(id === null, "the create test must run first");
    const wanted = `edited by FlightDeck ${Date.now()}`;
    await mutate(request, {
      operationId: "PUT /v2/task",
      keys: { id: String(id) },
      proposed: { Description: wanted },
    });
    await verifiedEffect(
      { operationId: "PUT /v2/task", subject: `task ${id}`, proves: "the instance reports the edited description" },
      async () => {
        const after = await adminRequest("GET", "/task", { id: String(id) });
        expect((after.json as { result?: { Description?: string } }).result?.Description).toBe(wanted);
      },
    );
  });
});

test.describe("work queue categories", () => {
  test("PUT /v2/wqm-category creates one and GET /v2/wqm-category reads it back", async ({ request }) => {
    // Removed first: the category can survive an earlier run, and re-sending the same values would be
    // refused as "nothing to apply" — which would prove the mutation layer works and this one did not.
    await adminRequest("DELETE", "/wqm-category", { name: CATEGORY });
    await mutate(request, {
      operationId: "PUT /v2/wqm-category",
      keys: { name: CATEGORY },
      proposed: { DefaultWorkers: 2, MaxActiveWorkers: 2, MaxTotalWorkers: 4 },
    });
    await verifiedEffect(
      { operationId: "PUT /v2/wqm-category", subject: CATEGORY, proves: "the instance holds the category with the worker count that was sent" },
      async () => {
        const after = await adminRequest("GET", "/wqm-category", { name: CATEGORY });
        expect(after.status).toBe(200);
        expect(Number((after.json as { result?: { DefaultWorkers?: number } }).result?.DefaultWorkers)).toBe(2);
      },
    );
    await verifiedRead("GET /v2/wqm-category", "FlightDeck lists the category the instance holds", async () => {
      const rows = await list(request, "tasks", "wqm-category");
      expect(rows.items.some((item) => item.displayName === CATEGORY), "FlightDeck did not list the category").toBe(true);
    });
  });
});

test.describe("the task manager", () => {
  test.afterAll(async () => {
    await adminRequest("POST", "/task/manager/resume", {}, {});
  });

  // Suspending and resuming the manager is instance-wide, so each test puts it back immediately and
  // the pair is verified by the manager's own reported state rather than by the response.
  test("POST /v2/task/manager/suspend and /resume move the manager's reported state", async ({ request }) => {
    await mutate(request, { operationId: "POST /v2/task/manager/suspend", params: { suspend: "1" } });
    await verifiedEffect(
      { operationId: "POST /v2/task/manager/suspend", subject: "the task manager", proves: "the instance reports the manager suspended" },
      async () => {
        const after = await adminRequest("GET", "/task/manager", {});
        const body = (after.json as { result?: { Status?: string } }).result ?? {};
        expect(String(body.Status)).toMatch(/suspend/i);
      },
    );
    await mutate(request, { operationId: "POST /v2/task/manager/resume" });
    await verifiedEffect(
      { operationId: "POST /v2/task/manager/resume", subject: "the task manager", proves: "the instance reports the manager running again" },
      async () => {
        const after = await adminRequest("GET", "/task/manager", {});
        const body = (after.json as { result?: { Status?: string } }).result ?? {};
        expect(String(body.Status)).toMatch(/running/i);
      },
    );
  });
});
