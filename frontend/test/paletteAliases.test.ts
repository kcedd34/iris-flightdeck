import { describe, expect, it } from "vitest";
import { buildActions, matchActions, normalize } from "../src/palette/actions";
import { SECTION_ALIASES, UNMAPPED } from "../src/palette/aliases";
import { DOMAINS } from "../src/shell/domains";

/**
 * An administrator arriving from the Management Portal types the portal's words. Before feature 008's
 * UX pass, 15 of the 17 captions on the portal's own menu found nothing here
 * (verification/ux-review.md, A2). This test fails if any of them stops resolving.
 *
 * The expected route is asserted, not just "some result": an alias that leads to the wrong screen is
 * worse than one that leads nowhere, because the user believes the answer.
 */

const actions = buildActions([]);

function routesFor(query: string): string[] {
  return matchActions(actions, query)
    .filter((a) => a.run.type === "navigate")
    .map((a) => (a.run as { type: "navigate"; to: string }).to);
}

/** The Management Portal's menu captions, read from IRIS for Health Community 2026.2. */
const PORTAL: [string, string][] = [
  ["Manage Web Applications", "/web-apps/web-applications"],
  ["Manage Users", "/permissions/users"],
  ["Manage Roles", "/permissions/roles"],
  ["Manage Resources", "/permissions/resources"],
  ["Manage Services", "/permissions/services"],
  ["Manage Locks", "/system/locks"],
  ["Configure Namespaces", "/system/namespaces"],
  ["Configure Databases", "/system/databases"],
  ["Configure Memory", "/system/instruments"],
  ["View Processes", "/system/processes"],
  ["View Messages Log", "/logs/stream"],
  ["View Background Tasks", "/tasks/tasks"],
  ["View System Dashboard", "/system/instruments"],
  ["SSL/TLS Configurations", "/security/tls"],
  ["Task Schedule", "/tasks/tasks"],
  ["Task Manager", "/tasks/manager"],
  ["System Administration", "/permissions/users"],
  ["System Operation", "/system/processes"],
];

/** Words an administrator uses that are neither our section names nor the portal's captions. */
const VERNACULAR: [string, string][] = [
  ["messages.log", "/logs/stream"],
  ["console.log", "/logs/stream"],
  ["alerts.log", "/logs/stream"],
  ["Scheduled tasks", "/tasks/tasks"],
  ["Cron", "/tasks/tasks"],
  ["CSP sessions", "/system/web-sessions"],
  ["Global mappings", "/system/namespaces"],
  ["Routine mappings", "/system/namespaces"],
  ["Licence", "/system/license"],
  ["Certificates", "/security/x509"],
  ["Active Directory", "/security/ldap"],
  ["Work Queue Manager", "/tasks/work-queue-categories"],
  ["Two factor", "/security/web-authentication"],
  ["Memory", "/system/instruments"],
  ["Jobs", "/system/processes"],
  ["Local databases", "/system/databases"],
  ["Python gateway", "/system/external-language-servers"],
  ["Managed file transfer", "/security/mft"],
];

describe("the palette answers the words an IRIS administrator already has", () => {
  it.each(PORTAL)("the portal's %s reaches %s", (term, route) => {
    expect(routesFor(term), `"${term}" found nothing in the palette`).toContain(route);
  });

  it.each(VERNACULAR)("%s reaches %s", (term, route) => {
    expect(routesFor(term), `"${term}" found nothing in the palette`).toContain(route);
  });

  it("says nothing rather than something wrong for what FlightDeck does not do", () => {
    for (const [term, reason] of Object.entries(UNMAPPED)) {
      expect(routesFor(term), `"${term}" acquired a destination; ${reason}`).toHaveLength(0);
    }
  });

  it("keeps a section's own name ahead of any synonym for it", () => {
    // "Locks" is the section's name and an alias of nothing else: a name always outranks an alias.
    const first = matchActions(actions, "Locks")[0];
    expect(first?.label).toBe("Go to System / Locks");
  });

  it("carries no alias the destination's own name already answers", () => {
    // A redundant alias is a line that looks like coverage and adds none. The palette already matches
    // the label, so an alias earns its place only by being a word the label does not contain.
    const redundant: string[] = [];
    for (const entry of actions) {
      for (const alias of entry.aliases) {
        if (normalize(entry.label).includes(normalize(alias))) redundant.push(`${entry.label} <- "${alias}"`);
      }
    }
    expect(redundant, "these aliases are already found by the destination's own name").toEqual([]);
  });

  it("aliases only sections that exist", () => {
    const known = new Set(DOMAINS.flatMap((d) => d.sections.map((s) => `${d.id}/${s.id}`)));
    for (const key of Object.keys(SECTION_ALIASES)) {
      expect(known, `${key} is aliased but is not a section`).toContain(key);
    }
  });
});
