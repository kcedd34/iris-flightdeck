// The only module allowed to call fetch. Adds the tab and safe-mode headers to every request
// (research R5), maps the error envelope, and reports session expiry.
import { getSafeMode, tabId } from "../session/safeMode";

export const API_BASE = "/api/flightdeck/v1";

export const MESSAGES = {
  invalidCredentials: "Invalid credentials. Check your username and password.",
  safeModeOn: "Safe mode is on. Turn it off to make changes in this tab.",
  version: "Not available on this IRIS version or edition. Requires IRIS 2026.2.",
  entitySearch: "Entity search is unavailable right now. Portal actions are still available.",
  changedOnServer:
    "This object changed on the server while you were editing. Review the updated differences before applying.",
} as const;

export class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
    readonly raw: string | null = null,
    readonly requires: string[] = [],
    readonly detectedVersion: string | null = null,
  ) {
    super(message);
    this.name = "ApiError";
  }
}

type ExpiryListener = () => void;
let onExpired: ExpiryListener | null = null;
let sessionActive = false;

/** SessionProvider registers here; the client calls it on a 401 while a session is active. */
export function registerSessionExpiry(listener: ExpiryListener | null): void {
  onExpired = listener;
}

export function setSessionActive(active: boolean): void {
  sessionActive = active;
}

interface RequestOptions {
  method?: "GET" | "POST" | "PUT" | "DELETE" | "PATCH";
  query?: Record<string, string | number | undefined>;
  body?: unknown;
  signal?: AbortSignal;
  authorization?: string;
}

async function toApiError(response: Response): Promise<ApiError> {
  let text = "";
  try {
    text = await response.text();
    const parsed = JSON.parse(text) as { error?: Partial<ApiError> & { message?: string; code?: string } };
    if (parsed.error?.code) {
      const e = parsed.error;
      return new ApiError(
        response.status,
        e.code ?? "UPSTREAM_ERROR",
        e.message ?? "Request failed.",
        (e.raw as string | null) ?? null,
        (e.requires as string[] | undefined) ?? [],
        (e.detectedVersion as string | null) ?? null,
      );
    }
  } catch {
    // not JSON: fall through with the raw text
  }
  return new ApiError(response.status, response.status === 401 ? "UNAUTHORIZED" : "UPSTREAM_ERROR",
    `Request failed with HTTP ${response.status}.`, text || null);
}

export async function request<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const url = new URL(API_BASE + path, window.location.origin);
  for (const [k, v] of Object.entries(options.query ?? {})) {
    if (v !== undefined && v !== "") url.searchParams.set(k, String(v));
  }
  const headers: Record<string, string> = {
    Accept: "application/json",
    "X-FlightDeck-Tab": tabId,
    "X-FlightDeck-Safe-Mode": getSafeMode(),
  };
  if (options.body !== undefined) headers["Content-Type"] = "application/json";
  if (options.authorization) headers.Authorization = options.authorization;
  const response = await fetch(url, {
    method: options.method ?? "GET",
    headers,
    body: options.body === undefined ? undefined : JSON.stringify(options.body),
    credentials: "same-origin",
    signal: options.signal,
  });
  if (!response.ok) {
    const error = await toApiError(response);
    const isSignIn = path === "/session" && (options.method ?? "GET") === "POST";
    if (response.status === 401 && !isSignIn && sessionActive) onExpired?.();
    throw error;
  }
  if (response.status === 204) return undefined as T;
  return (await response.json()) as T;
}

/**
 * Sign in. The Basic header is built in this function's scope, sent once, and never stored,
 * logged or returned (Constitution II, research R4). Any 401 here means invalid credentials,
 * whatever the body (analysis U1): IRIS rejects them before FlightDeck code runs.
 */
export async function signIn<T>(username: string, password: string): Promise<T> {
  const bytes = new TextEncoder().encode(`${username}:${password}`);
  const authorization = "Basic " + btoa(String.fromCharCode(...bytes));
  try {
    return await request<T>("/session", { method: "POST", authorization });
  } catch (error) {
    if (error instanceof ApiError && error.status === 401) {
      throw new ApiError(401, "INVALID_CREDENTIALS", MESSAGES.invalidCredentials);
    }
    throw error;
  }
}
