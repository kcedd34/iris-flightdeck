import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import type { TrailRecord } from "../src/api/types";
import { appendTrail, clearTrail, exportTrail, getTrail, resetTrailMemoryForTests, TRAIL_CAP, TRAIL_KEY, TRAIL_NOTICE } from "../src/mutation/trail";

function record(i: number): TrailRecord {
  return { id: `id-${i}`, time: "2026-09-17T00:00:00Z", operationId: "PUT /v2/web-app", kind: "edit", target: `/csp/app-${i}`, rows: [], result: "Applied", status: 200, message: null, concurrency: "checked" };
}

describe("session trail (spec FR-014, FR-015)", () => {
  beforeEach(() => {
    window.sessionStorage.clear();
    window.localStorage.clear();
    resetTrailMemoryForTests();
  });
  afterEach(() => vi.restoreAllMocks());

  it("survives a reload of the tab: it is read back from sessionStorage, never localStorage", () => {
    appendTrail(record(1));
    expect(window.localStorage.length).toBe(0);
    expect(window.sessionStorage.getItem(TRAIL_KEY)).toContain("/csp/app-1");
    resetTrailMemoryForTests(); // what a reload does to module memory
    expect(getTrail().document.entries.map((e) => e.target)).toEqual(["/csp/app-1"]);
    expect(getTrail().persistent).toBe(true);
  });

  it("caps entries and counts what was dropped", () => {
    for (let i = 0; i < TRAIL_CAP + 3; i++) appendTrail(record(i));
    const { document } = getTrail();
    expect(document.entries).toHaveLength(TRAIL_CAP);
    expect(document.dropped).toBe(3);
    expect(document.entries[0]!.target).toBe("/csp/app-3");
  });

  it("falls back to memory, stated, when storage throws", () => {
    vi.spyOn(Storage.prototype, "setItem").mockImplementation(() => {
      throw new Error("QuotaExceededError");
    });
    appendTrail(record(1));
    expect(getTrail().persistent).toBe(false);
    expect(getTrail().document.entries).toHaveLength(1);
  });

  it("clears storage and memory, and exports the document with the auditing notice", () => {
    appendTrail(record(1));
    const exported = JSON.parse(exportTrail(new Date("2026-09-17T12:00:00Z")).text);
    expect(exported.notice).toBe(TRAIL_NOTICE);
    expect(exported.entries[0].target).toBe("/csp/app-1");
    expect(exportTrail(new Date("2026-09-17T12:00:00Z")).fileName).toBe("flightdeck-trail-2026-09-17T12-00-00-000Z.json");
    clearTrail();
    expect(window.sessionStorage.getItem(TRAIL_KEY)).toBeNull();
    resetTrailMemoryForTests();
    expect(getTrail().document.entries).toHaveLength(0);
  });
});
