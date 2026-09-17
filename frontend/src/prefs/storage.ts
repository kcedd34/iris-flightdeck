// The only module allowed to touch browser storage (Constitution IV, eslint rule).
// Stores exactly two per-user conveniences: theme choice and recent palette actions.
// Never credentials, never safe-mode state, never typed queries.

export type Theme = "dark" | "light";

export interface RecentAction {
  id: string;
  label: string;
  domain: string;
  kind: "action" | "entity";
  usedAt: string;
}

const MAX_RECENT = 8;

function read(key: string): string | null {
  try {
    return window.localStorage.getItem(key);
  } catch {
    return null;
  }
}

function write(key: string, value: string): void {
  try {
    window.localStorage.setItem(key, value);
  } catch {
    // Storage unavailable (private mode, quota): preferences are optional.
  }
}

export function getTheme(username: string): Theme | null {
  const value = read(`flightdeck:theme:${username}`);
  return value === "dark" || value === "light" ? value : null;
}

export function setTheme(username: string, theme: Theme): void {
  write(`flightdeck:theme:${username}`, theme);
}

export function getRecent(username: string): RecentAction[] {
  const raw = read(`flightdeck:recent:${username}`);
  if (!raw) return [];
  try {
    const parsed: unknown = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];
    return parsed
      .filter((r): r is RecentAction => typeof r?.id === "string" && typeof r?.label === "string")
      .slice(0, MAX_RECENT)
      .map(({ id, label, domain, kind, usedAt }) => ({ id, label, domain, kind, usedAt }));
  } catch {
    return [];
  }
}

export function pushRecent(username: string, entry: Omit<RecentAction, "usedAt">): void {
  const next: RecentAction[] = [
    { id: entry.id, label: entry.label, domain: entry.domain, kind: entry.kind, usedAt: new Date().toISOString() },
    ...getRecent(username).filter((r) => r.id !== entry.id),
  ].slice(0, MAX_RECENT);
  write(`flightdeck:recent:${username}`, JSON.stringify(next));
}
