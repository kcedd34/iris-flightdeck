// Test users, created through the official SysAdmin API on the running install (idempotent).
export const IRIS = `http://localhost:${process.env.FLIGHTDECK_PORT ?? "52780"}`;
export const ADMIN = { user: process.env.FD_ADMIN_USER ?? "_SYSTEM", password: process.env.FD_ADMIN_PASSWORD ?? "SYS" };
export const OPERATOR = { user: "fd_e2e_operator", password: "E2e-Pass-2026" };
export const NO_PRIVILEGE = { user: "fd_e2e_none", password: "E2e-Pass-2026" };

function basic(u: { user: string; password: string }): string {
  return "Basic " + Buffer.from(`${u.user}:${u.password}`).toString("base64");
}

/** The SysAdmin API version the install exposes: v2 on IRIS 2026.2+, v1 on IRIS 2026.1 (limited mode). */
async function adminBase(): Promise<string> {
  const info = await fetch(`${IRIS}/api/admin/info`, { headers: { Authorization: basic(ADMIN) } });
  const version = ((await info.json()) as { result: { apiVersion: number } }).result.apiVersion;
  return `${IRIS}/api/admin/v${version >= 2 ? 2 : 1}`;
}

export async function ensureUser(name: string, password: string, roles: string[]): Promise<void> {
  // Same method, path and body on both versions (verification/v1-api-2026.1.md, same shape).
  const url = `${await adminBase()}/security/user?name=${encodeURIComponent(name)}`;
  const existing = await fetch(url, { headers: { Authorization: basic(ADMIN) } });
  if (existing.status === 200) return;
  const created = await fetch(url, {
    method: "POST",
    headers: { Authorization: basic(ADMIN), "Content-Type": "application/json" },
    body: JSON.stringify({ Password: password, User: { Enabled: true, ChangePassword: false, FullName: "FlightDeck e2e", Roles: roles } }),
  });
  if (created.status >= 300) throw new Error(`Creating ${name} failed: HTTP ${created.status} ${await created.text()}`);
}
