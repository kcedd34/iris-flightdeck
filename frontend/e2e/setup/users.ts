// Test users, created through the official SysAdmin API on the running install (idempotent).
export const IRIS = `http://localhost:${process.env.FLIGHTDECK_PORT ?? "52780"}`;
export const ADMIN = { user: process.env.FD_ADMIN_USER ?? "_SYSTEM", password: process.env.FD_ADMIN_PASSWORD ?? "SYS" };
export const OPERATOR = { user: "fd_e2e_operator", password: "E2e-Pass-2026" };
export const NO_PRIVILEGE = { user: "fd_e2e_none", password: "E2e-Pass-2026" };

function basic(u: { user: string; password: string }): string {
  return "Basic " + Buffer.from(`${u.user}:${u.password}`).toString("base64");
}

export async function ensureUser(name: string, password: string, roles: string[]): Promise<void> {
  const url = `${IRIS}/api/admin/v2/security/user?name=${encodeURIComponent(name)}`;
  const existing = await fetch(url, { headers: { Authorization: basic(ADMIN) } });
  if (existing.status === 200) return;
  const created = await fetch(url, {
    method: "POST",
    headers: { Authorization: basic(ADMIN), "Content-Type": "application/json" },
    body: JSON.stringify({ Password: password, User: { Enabled: true, ChangePassword: false, FullName: "FlightDeck e2e", Roles: roles } }),
  });
  if (created.status >= 300) throw new Error(`Creating ${name} failed: HTTP ${created.status} ${await created.text()}`);
}
