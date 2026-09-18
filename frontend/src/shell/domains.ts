import type { DomainId, RailDomainId } from "../api/types";

export type { RailDomainId };

export interface Section {
  id: string;
  label: string;
}

export interface Domain {
  id: RailDomainId;
  label: string;
  /** SVG path data from docs/prototype.html, 18x18 viewBox, stroke currentColor. */
  icon: string;
  /** Fixed order, most used first (docs/design.md §4.1, spec Assumptions). */
  sections: Section[];
}

export const DOMAINS: Domain[] = [
  {
    id: "web-apps",
    label: "Web applications and APIs",
    icon: '<rect x="2" y="3" width="14" height="12"/><path d="M2 7h14"/>',
    sections: [
      { id: "web-applications", label: "Web applications" },
      { id: "rest-apis", label: "REST APIs" },
      { id: "percent-class-access", label: "Percent class access" },
    ],
  },
  {
    id: "permissions",
    label: "Permissions",
    icon: '<circle cx="9" cy="6" r="3"/><path d="M3 15c0-3.3 2.7-5 6-5s6 1.7 6 5"/>',
    sections: [
      { id: "users", label: "Users" },
      { id: "roles", label: "Roles" },
      { id: "resources", label: "Resources" },
      { id: "services", label: "Services" },
      { id: "privileged-routines", label: "Privileged routines" },
    ],
  },
  {
    id: "security",
    label: "Security and secrets",
    icon: '<path d="M9 2l6 2.5v5C15 13 12.5 15.3 9 16.5 5.5 15.3 3 13 3 9.5v-5z"/>',
    sections: [
      { id: "tls", label: "TLS" },
      { id: "x509", label: "X.509" },
      { id: "oauth2", label: "OAuth 2.0" },
      { id: "wallet", label: "Wallet" },
      { id: "encryption", label: "Encryption" },
      { id: "ldap", label: "LDAP" },
      { id: "mft", label: "MFT" },
      { id: "auditing", label: "Auditing" },
      { id: "web-authentication", label: "Web authentication" },
      { id: "superservers", label: "Superservers" },
    ],
  },
  {
    id: "tasks",
    label: "Tasks",
    icon: '<circle cx="9" cy="9" r="6.5"/><path d="M9 5v4l2.5 1.6"/>',
    sections: [
      { id: "tasks", label: "Tasks" },
      { id: "work-queue-categories", label: "Work queue categories" },
      { id: "async-results", label: "Async results" },
    ],
  },
  {
    id: "system",
    label: "System",
    icon: '<rect x="3" y="3" width="12" height="12"/><rect x="6.5" y="6.5" width="5" height="5"/>',
    sections: [
      { id: "instruments", label: "Instruments" },
      { id: "processes", label: "Processes" },
      { id: "databases", label: "Databases" },
      { id: "namespaces", label: "Namespaces" },
      { id: "devices", label: "Devices" },
      { id: "license", label: "License" },
      { id: "locks", label: "Locks" },
      { id: "web-sessions", label: "Web sessions" },
      { id: "ecp", label: "ECP" },
      { id: "external-language-servers", label: "External language servers" },
      { id: "docdb", label: "DocDB" },
      { id: "file-system-access", label: "File system access" },
    ],
  },
  {
    id: "logs",
    label: "Logs",
    icon: '<path d="M3 4h12M3 8h12M3 12h7"/>',
    sections: [{ id: "stream", label: "Log stream" }],
  },
];

export function findDomain(id: string | undefined): Domain | undefined {
  return DOMAINS.find((d) => d.id === id);
}

export function findSection(domain: Domain, id: string | undefined): Section | undefined {
  return domain.sections.find((s) => s.id === id);
}

export function domainLabel(id: DomainId): string {
  return id === "shell" ? "FlightDeck" : (findDomain(id)?.label ?? id);
}
