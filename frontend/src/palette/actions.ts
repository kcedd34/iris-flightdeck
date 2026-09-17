import type { CapabilityEntry, DomainId } from "../api/types";
import { DOMAINS } from "../shell/domains";

export interface ActionEntry {
  id: string;
  kind: "action";
  label: string;
  domain: DomainId;
  context: string;
  mono: boolean;
  mutating: boolean;
  enabled: boolean;
  disabledReason: string | null;
  run:
    | { type: "navigate"; to: string }
    | { type: "theme"; theme: "dark" | "light" }
    | { type: "safe-mode"; to: "armed" | "disarmed" }
    | { type: "sign-out" }
    | { type: "operation"; to: string };
}

/**
 * Local action index (FR-023): navigation to every destination and section, shell actions, and every
 * mutating official operation with its capability-derived state. Operations only navigate to their
 * domain in this feature.
 */
export function buildActions(capabilities: CapabilityEntry[]): ActionEntry[] {
  const actions: ActionEntry[] = [
    nav("nav:home", "Go to Home", "shell", "Home", "/"),
    ...DOMAINS.flatMap((d) =>
      d.sections.map((s) =>
        nav(
          `nav:${d.id}/${s.id}`,
          d.sections.length > 1 ? `Go to ${d.label} / ${s.label}` : `Go to ${d.label}`,
          d.id,
          s.label,
          `/${d.id}/${s.id}`,
        ),
      ),
    ),
    shell("shell:theme-dark", "Switch to dark theme", { type: "theme", theme: "dark" }),
    shell("shell:theme-light", "Switch to light theme", { type: "theme", theme: "light" }),
    shell("shell:safe-mode-disarm", "Turn off safe mode in this tab", { type: "safe-mode", to: "disarmed" }),
    shell("shell:safe-mode-arm", "Turn on safe mode", { type: "safe-mode", to: "armed" }),
    shell("shell:sign-out", "Sign out", { type: "sign-out" }),
  ];
  for (const c of capabilities) {
    if (!c.mutating || c.domain === "shell") continue;
    const domain = DOMAINS.find((d) => d.id === c.domain);
    actions.push({
      id: `op:${c.operationId}`,
      kind: "action",
      label: sentence(c.summary),
      domain: c.domain,
      context: `${c.method} ${c.path}`,
      mono: true,
      mutating: true,
      enabled: c.available && c.allowed,
      disabledReason: c.reason,
      run: { type: "operation", to: domain ? `/${domain.id}/${domain.sections[0]!.id}` : "/" },
    });
  }
  return actions;
}

function nav(id: string, label: string, domain: DomainId, context: string, to: string): ActionEntry {
  return { id, kind: "action", label, domain, context, mono: false, mutating: false, enabled: true, disabledReason: null, run: { type: "navigate", to } };
}

function shell(id: string, label: string, run: ActionEntry["run"]): ActionEntry {
  return { id, kind: "action", label, domain: "shell", context: "FlightDeck", mono: false, mutating: false, enabled: true, disabledReason: null, run };
}

function sentence(summary: string): string {
  const clean = summary.replace(/\s+/g, " ").trim();
  const first = clean.split(/(?<=[a-z])\. /)[0] ?? clean;
  return first.charAt(0).toUpperCase() + first.slice(1);
}

/** Case-insensitive match ignoring separators, the same rule the server uses. */
export function normalize(text: string): string {
  return text.toLowerCase().replace(/[_\-\s/.]/g, "");
}

export function matchActions(actions: ActionEntry[], query: string): ActionEntry[] {
  const needle = normalize(query);
  if (!needle) return [];
  const scored = actions
    .map((a) => {
      const label = normalize(a.label);
      const context = normalize(a.context);
      const rank = label === needle ? 0 : label.startsWith(needle) ? 1 : label.includes(needle) ? 2 : context.includes(needle) ? 3 : -1;
      return { a, rank };
    })
    .filter((x) => x.rank >= 0);
  scored.sort((x, y) => x.rank - y.rank || x.a.label.localeCompare(y.a.label));
  return scored.map((x) => x.a);
}
