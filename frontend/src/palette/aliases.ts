/**
 * The words an IRIS administrator already has, mapped to the sections that answer them.
 *
 * The palette used to match only its own section names, so an experienced administrator typing what
 * the Management Portal calls things — "Manage Users", "View Processes", "Configure Databases" — got
 * nothing. The portal's menu is a verb plus a noun; ours is the noun alone, and that difference is
 * not worth making the user pay for.
 *
 * These are search keys only. They are never displayed: the result still reads "Go to Permissions /
 * Users". Adding one is a line, and the rule for adding one is that it must lead somewhere that
 * genuinely answers the question. A term FlightDeck does not cover gets no entry here and no
 * invented destination — the palette says it found nothing, which is the true answer.
 *
 * The native portal's own captions are marked (portal), so the list can be checked against a real
 * instance rather than against memory. They were read from the Management Portal menu of IRIS for
 * Health Community 2026.2 (verification/ux-review.md, "Comparison with the native portal").
 */
export const SECTION_ALIASES: Record<string, string[]> = {
  "web-apps/web-applications": [
    "Manage Web Applications", // (portal)
    "CSP applications",
  ],
  "web-apps/rest-apis": ["REST services", "OpenAPI", "Swagger", "API management"],
  "web-apps/percent-class-access": ["%class access", "Allowed classes"],

  "permissions/users": [
    "Manage Users", // (portal)
    "System Administration", // (portal) — the area whose pages these six sections answer
    "Accounts",
    "Logins",
  ],
  "permissions/roles": ["Manage Roles" /* (portal) */, "Security roles"],
  "permissions/resources": ["Manage Resources" /* (portal) */, "Security resources"],
  "permissions/services": ["Manage Services" /* (portal) */, "Security services"],
  "permissions/privileged-routines": ["Privileged routine applications", "Routine applications"],

  "security/tls": [
    "SSL/TLS Configurations", // (portal)
    "SSL",
    "TLS configurations",
    "System Administration", // (portal)
    "Certificates",
  ],
  "security/x509": ["X509 credentials", "Certificates", "Public key"],
  "security/oauth2": ["OpenID Connect", "Authorization server"],
  "security/wallet": ["Credentials store", "Key value secrets"],
  "security/encryption": ["Encryption key file", "Database encryption", "At-rest encryption"],
  "security/ldap": ["Directory", "Active Directory", "LDAP configurations"],
  "security/mft": ["Managed file transfer", "Box", "Dropbox", "Kiteworks"],
  "security/auditing": ["Audit settings", "Enable auditing"],
  "security/web-authentication": ["Authentication options", "Two factor", "Delegated authentication", "JWT"],
  "security/superservers": ["Listening ports"],

  "tasks/tasks": [
    "View Background Tasks", // (portal)
    "Task Schedule", // (portal, System Operation > Task Manager > Task Schedule)
    "Background tasks",
    "Scheduled tasks",
    "Cron",
    "System Operation", // (portal) — the area whose pages tasks, processes and logs answer
  ],
  "tasks/manager": ["Scheduler", "Suspend the scheduler"],
  "tasks/work-queue-categories": ["Work Queue Manager", "WQM", "Worker categories"],
  "tasks/async-results": ["Asynchronous results", "Long running operations"],

  "system/instruments": [
    "View System Dashboard", // (portal)
    "Configure Memory", // (portal) — FlightDeck reads memory here; it does not configure buffers
    "System Dashboard",
    "Memory",
    "Shared memory",
    "CPU",
    "Disk",
    "Telemetry",
    "Monitor",
  ],
  "system/processes": [
    "View Processes", // (portal)
    "System Operation", // (portal)
    "Jobs",
    "Terminate a job",
  ],
  "system/databases": ["Configure Databases" /* (portal) */, "Local databases", "System Administration" /* (portal) */],
  "system/directories": ["Database directories", "Database files", "IRIS.DAT"],
  "system/namespaces": [
    "Configure Namespaces", // (portal)
    "Global mappings",
    "Routine mappings",
    "Package mappings",
    "System Administration", // (portal)
  ],
  "system/devices": ["Device subtypes", "Printers"],
  "system/license": ["Licence" /* British spelling, as the README uses */, "License key", "License servers"],
  "system/locks": ["Manage Locks" /* (portal) */, "Lock table", "System Operation" /* (portal) */],
  "system/web-sessions": ["CSP sessions"],
  "system/ecp": ["Enterprise Cache Protocol", "Application servers", "Data servers"],
  "system/external-language-servers": ["Python gateway", "Java gateway", "Gateways"],
  "system/docdb": ["Document database", "DocDB applications"],
  "system/file-system-access": ["File access purposes", "Allowed directories"],

  "logs/stream": [
    "View Messages Log", // (portal)
    "Messages Log", // (portal)
    "messages.log",
    "console.log",
    "cconsole.log",
    "alerts.log",
    "Alerts",
    "Event log",
    "System Operation", // (portal)
  ],
  "logs/journal": ["Journals", "Journal files", "Journaling"],
  "logs/audit-events": ["Audit database", "Audit log"],
};

/**
 * Terms the native portal has that FlightDeck deliberately does not answer. Listed so the gap is a
 * recorded decision rather than a forgotten alias, and so the test can assert that they still find
 * nothing instead of quietly acquiring a misleading destination.
 */
export const UNMAPPED: Record<string, string> = {
  "System Explorer":
    "The portal's System Explorer is SQL, classes, routines and globals. FlightDeck administers the " +
    "instance and does not browse its data or code; pointing this somewhere would be a wrong answer " +
    "rather than a missing one.",
};
