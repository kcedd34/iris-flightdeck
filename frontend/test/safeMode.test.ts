import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

describe("safe mode store (Constitution IV)", () => {
  beforeEach(() => {
    vi.resetModules();
  });
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("starts armed on every fresh module load", async () => {
    const first = await import("../src/session/safeMode");
    expect(first.getSafeMode()).toBe("armed");
    first.disarm();
    expect(first.getSafeMode()).toBe("disarmed");
    vi.resetModules();
    const reloaded = await import("../src/session/safeMode");
    expect(reloaded.getSafeMode()).toBe("armed");
  });

  it("never touches browser storage or cookies", async () => {
    const local = vi.spyOn(Storage.prototype, "setItem");
    const localGet = vi.spyOn(Storage.prototype, "getItem");
    const cookie = vi.spyOn(document, "cookie", "set");
    const store = await import("../src/session/safeMode");
    store.disarm();
    store.arm();
    store.disarm();
    expect(local).not.toHaveBeenCalled();
    expect(localGet).not.toHaveBeenCalled();
    expect(cookie).not.toHaveBeenCalled();
  });

  it("notifies subscribers on change only", async () => {
    const store = await import("../src/session/safeMode");
    const listener = vi.fn();
    store.subscribe(listener);
    store.arm();
    expect(listener).not.toHaveBeenCalled();
    store.disarm();
    expect(listener).toHaveBeenCalledTimes(1);
  });
});

describe("API client headers (research R5)", () => {
  beforeEach(() => {
    vi.resetModules();
  });

  it("sends tab id and current safe-mode state on every request", async () => {
    const fetchMock = vi.fn().mockImplementation(async () => new Response("{}", { status: 200 }));
    vi.stubGlobal("fetch", fetchMock);
    const store = await import("../src/session/safeMode");
    const client = await import("../src/api/client");
    await client.request("/vitals");
    store.disarm();
    await client.request("/vitals");
    const headers = fetchMock.mock.calls.map((c) => (c[1] as RequestInit).headers as Record<string, string>);
    expect(headers[0]!["X-FlightDeck-Tab"]).toBe(store.tabId);
    expect(headers[0]!["X-FlightDeck-Safe-Mode"]).toBe("armed");
    expect(headers[1]!["X-FlightDeck-Safe-Mode"]).toBe("disarmed");
    vi.unstubAllGlobals();
  });

  it("maps any 401 on sign-in to the invalid-credentials message and keeps no credential", async () => {
    const fetchMock = vi.fn().mockImplementation(async () => new Response("", { status: 401 }));
    vi.stubGlobal("fetch", fetchMock);
    const client = await import("../src/api/client");
    await expect(client.signIn("alice", "secret")).rejects.toMatchObject({
      code: "INVALID_CREDENTIALS",
      message: "Invalid credentials. Check your username and password.",
    });
    const second = vi.fn().mockImplementation(async () => new Response("{}", { status: 200 }));
    vi.stubGlobal("fetch", second);
    await client.request("/vitals");
    const headers = (second.mock.calls[0]![1] as RequestInit).headers as Record<string, string>;
    expect(headers.Authorization).toBeUndefined();
    vi.unstubAllGlobals();
  });

  it("reports expiry on 401 only while a session is active", async () => {
    const fetchMock = vi.fn().mockImplementation(async () => new Response("", { status: 401 }));
    vi.stubGlobal("fetch", fetchMock);
    const client = await import("../src/api/client");
    const expired = vi.fn();
    client.registerSessionExpiry(expired);
    await expect(client.request("/vitals")).rejects.toBeTruthy();
    expect(expired).not.toHaveBeenCalled();
    client.setSessionActive(true);
    await expect(client.request("/vitals")).rejects.toBeTruthy();
    expect(expired).toHaveBeenCalledTimes(1);
    vi.unstubAllGlobals();
  });
});
