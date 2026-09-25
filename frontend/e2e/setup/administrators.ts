import { adminRequest } from "./users";

/** IRIS reports an account that never expires as this date; it is not an expiry. */
const NO_EXPIRY = "1840-12-31";

function expiredOn(date: string): boolean {
  if (!date) return false;
  const day = date.split(" ")[0];
  if (day === NO_EXPIRY) return false;
  return new Date(day) < new Date();
}

/** The administrators the server counts, by the same narrow rule the last-administrator check uses. */
export async function administrators(): Promise<string[] | null> {
  const answer = await adminRequest("GET", "/security/users", { maxRows: "500" });
  const list = (answer.json as { result?: { Name: string }[] }).result;
  if (!Array.isArray(list)) return null;
  const counted: string[] = [];
  for (const { Name } of list) {
    const detail = (await adminRequest("GET", "/security/user", { name: Name })).json as { result?: { Enabled: boolean; ExpirationDate: string; Roles: string[] } };
    const user = detail.result;
    if (!user || !user.Enabled) continue;
    if (expiredOn(user.ExpirationDate)) continue;
    if (user.Roles.includes("%All") || user.Roles.includes("%Manager") || user.Roles.includes("%SecurityAdministrator") || user.Roles.includes("%Admin_Secure")) counted.push(Name);
  }
  return counted;
}
