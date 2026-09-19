import { expect, type APIRequestContext } from "@playwright/test";
import { ADMIN, IRIS } from "./users";

/**
 * Driving FlightDeck's own API from a test, without a browser (feature 008).
 *
 * The functional-coverage tests have to make **FlightDeck** perform the operation — not call the
 * SysAdmin API themselves, which would test IRIS — and then verify the result by reading the object
 * back independently. These helpers are the first half; `verifiedEffect` in `effect.ts` is the
 * second.
 *
 * FlightDeck's API accepts HTTP Basic, so this needs no browser session. Every request carries the
 * tab header the API requires, and mutations carry the disarmed header, because safe mode is enforced
 * server-side and a test that bypassed it would be testing a path users do not have.
 */

const TAB = "e2e-functional";

function auth() {
  return "Basic " + Buffer.from(`${ADMIN.user}:${ADMIN.password}`).toString("base64");
}

function headers(mutating = false): Record<string, string> {
  return {
    Authorization: auth(),
    "X-FlightDeck-Tab": TAB,
    "Content-Type": "application/json",
    ...(mutating ? { "X-FlightDeck-Safe-Mode": "disarmed" } : {}),
  };
}

export interface MutationRequest {
  operationId: string;
  keys?: Record<string, string>;
  params?: Record<string, string>;
  proposed?: Record<string, unknown>;
}

/** The dry-run FlightDeck computes before anything is sent. */
export async function preview(request: APIRequestContext, body: MutationRequest) {
  const response = await request.post(`${IRIS}/api/flightdeck/v1/mutations/preview`, {
    headers: headers(true),
    data: body,
  });
  return { status: response.status(), body: (await response.json()) as Record<string, any> };
}

/**
 * Performs a mutation the way the interface does: preview for the fingerprint and the confirmation
 * text, then apply. Fails loudly if FlightDeck refused, because a refusal is not a pass.
 */
export async function mutate(request: APIRequestContext, body: MutationRequest) {
  const dryRun = await preview(request, body);
  expect(dryRun.status, `preview of ${body.operationId}: ${JSON.stringify(dryRun.body).slice(0, 300)}`).toBe(200);
  expect(dryRun.body.blocked ?? null, `${body.operationId} was blocked: ${JSON.stringify(dryRun.body.blocked)}`).toBeNull();
  const response = await request.post(`${IRIS}/api/flightdeck/v1/mutations/apply`, {
    headers: headers(true),
    data: { ...body, fingerprint: dryRun.body.fingerprint, confirmation: dryRun.body.confirmText },
  });
  const text = await response.text();
  expect(
    response.status(),
    `apply of ${body.operationId} answered ${response.status()}: ${text.slice(0, 400)}`,
  ).toBeLessThan(300);
  return { status: response.status(), body: text ? (JSON.parse(text) as Record<string, any>) : {} };
}

/** A list read through FlightDeck's own domain layer, which is what the screens use. */
export async function list(request: APIRequestContext, domain: string, entityType: string, query: Record<string, string> = {}) {
  const search = new URLSearchParams({ maxRows: "500", ...query }).toString();
  const response = await request.get(`${IRIS}/api/flightdeck/v1/domains/${domain}/${entityType}?${search}`, {
    headers: headers(),
  });
  expect(response.status(), `list ${domain}/${entityType}`).toBe(200);
  return (await response.json()) as { items: { displayName: string; keys: Record<string, string>; facts: Record<string, unknown> }[]; total: number };
}

/** One entity's detail through FlightDeck. */
export async function item(request: APIRequestContext, domain: string, entityType: string, keys: Record<string, string>) {
  const search = new URLSearchParams(keys).toString();
  const response = await request.get(`${IRIS}/api/flightdeck/v1/domains/${domain}/${entityType}/item?${search}`, {
    headers: headers(),
  });
  return { status: response.status(), body: response.status() === 200 ? ((await response.json()) as Record<string, any>) : {} };
}

/** A link group of one entity, which is how several read-only operations are reached. */
export async function links(request: APIRequestContext, domain: string, entityType: string, keys: Record<string, string>, extra: Record<string, string> = {}) {
  const search = new URLSearchParams({ ...keys, ...extra }).toString();
  const response = await request.get(`${IRIS}/api/flightdeck/v1/domains/${domain}/${entityType}/links?${search}`, {
    headers: headers(),
  });
  return { status: response.status(), body: response.status() === 200 ? ((await response.json()) as Record<string, any>) : {} };
}
