// Test users, created through the official SysAdmin API on the running install (idempotent).
export const IRIS = `http://localhost:${process.env.FLIGHTDECK_PORT ?? "52780"}`;
export const ADMIN = { user: process.env.FD_ADMIN_USER ?? "_SYSTEM", password: process.env.FD_ADMIN_PASSWORD ?? "SYS" };
export const OPERATOR = { user: "fd_e2e_operator", password: "E2e-Pass-2026" };
export const NO_PRIVILEGE = { user: "fd_e2e_none", password: "E2e-Pass-2026" };
/// Feature 003 accounts. The installer creates no user (it would be a stored credential); the test
/// harness owns these, as it already owns the operator and no-privilege accounts.
export const CHAIN = { user: "fd_e2e_chain", password: "E2e-Pass-2026" };
export const WALLET_ONLY = { user: "fd_e2e_wallet", password: "E2e-Pass-2026" };
export const EXPIRED = { user: "fd_e2e_expired", password: "E2e-Pass-2026" };

function basic(u: { user: string; password: string }): string {
  return "Basic " + Buffer.from(`${u.user}:${u.password}`).toString("base64");
}

/** The SysAdmin API version the install exposes: v2 on IRIS 2026.2+, v1 on IRIS 2026.1 (limited mode). */
async function adminVersion(): Promise<number> {
  const info = await fetch(`${IRIS}/api/admin/info`, { headers: { Authorization: basic(ADMIN) } });
  return ((await info.json()) as { result: { apiVersion: number } }).result.apiVersion;
}

async function adminBase(): Promise<string> {
  return `${IRIS}/api/admin/v${(await adminVersion()) >= 2 ? 2 : 1}`;
}

/**
 * The v1 route for a v2 path the fixtures use. On IRIS 2026.1 a collection is the singular path with
 * a trailing slash, and a wallet collection has no "collection" segment at all. FlightDeck's own
 * client does this in FlightDeck.Admin; the fixtures call the official API directly, so they need
 * the same map or they create nothing and the tests fail as if the feature were broken.
 */
const V1_PATHS: Record<string, string> = {
  "/security/users": "/security/user/",
  "/security/roles": "/security/role/",
  "/security/resources": "/security/resource/",
  "/security/ssl-configurations": "/security/ssl-configuration/",
  "/wallet/collections": "/wallet/",
  "/wallet/collection": "/wallet",
  "/wallet/secrets": "/wallet/secret/",
};

export interface UserOptions {
  /** Last date the account can be used; "" means no limit, as the official API reports it. */
  expirationDate?: string;
  enabled?: boolean;
}

/** Creates a role with the given resource grants, idempotently (feature 003 test fixtures). */
export async function ensureRole(name: string, description: string, resources: { Name: string; Permissions: string }[]): Promise<void> {
  const url = `${await adminBase()}/security/role?name=${encodeURIComponent(name)}`;
  const existing = await fetch(url, { headers: { Authorization: basic(ADMIN) } });
  if (existing.status === 200) return;
  const created = await fetch(url, {
    method: "PUT",
    headers: { Authorization: basic(ADMIN), "Content-Type": "application/json" },
    body: JSON.stringify({ Description: description, Resources: resources }),
  });
  if (created.status >= 300) throw new Error(`Creating role ${name} failed: HTTP ${created.status} ${await created.text()}`);
}

export async function ensureUser(name: string, password: string, roles: string[], options: UserOptions = {}): Promise<void> {
  // Same method, path and body on both versions (verification/v1-api-2026.1.md, same shape).
  const url = `${await adminBase()}/security/user?name=${encodeURIComponent(name)}`;
  const existing = await fetch(url, { headers: { Authorization: basic(ADMIN) } });
  if (existing.status === 200) return;
  const created = await fetch(url, {
    method: "POST",
    headers: { Authorization: basic(ADMIN), "Content-Type": "application/json" },
    body: JSON.stringify({
      Password: password,
      User: {
        Enabled: options.enabled ?? true,
        ChangePassword: false,
        FullName: "FlightDeck e2e",
        Roles: roles,
        ...(options.expirationDate === undefined ? {} : { ExpirationDate: options.expirationDate, AccountNeverExpires: false }),
      },
    }),
  });
  if (created.status >= 300) throw new Error(`Creating ${name} failed: HTTP ${created.status} ${await created.text()}`);
}

/** Official SysAdmin API call as the admin test account (test infrastructure, feature 002 fixtures). */
export async function adminRequest(method: "GET" | "PUT" | "POST" | "DELETE", path: string, query: Record<string, string>, body?: unknown): Promise<{ status: number; json: unknown }> {
  const v1 = (await adminVersion()) < 2;
  const url = new URL(`${await adminBase()}${v1 ? (V1_PATHS[path] ?? path) : path}`);
  for (const [k, v] of Object.entries(query)) url.searchParams.set(k, v);
  const response = await fetch(url, {
    method,
    headers: { Authorization: basic(ADMIN), ...(body === undefined ? {} : { "Content-Type": "application/json" }) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  let json: unknown;
  try {
    json = JSON.parse(text);
  } catch {
    json = text;
  }
  return { status: response.status, json };
}
