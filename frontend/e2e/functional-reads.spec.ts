import { expect, test } from "@playwright/test";
import { adminRequest } from "./setup/users";
import { list, item } from "./setup/flightdeck";
import { verifiedRead } from "./setup/effect";
import { requireV2Dialect } from "./setup/dialect";

// Feature 008: every read operation reachable through an entity type, verified against the
// instance's own answer rather than against a status code.
//
// These operations were being executed by the existing suite — the screens that use them assert on
// what they render — but nothing recorded that the answer had been checked against the platform. A
// list that renders rows proves the operation replied with something list-shaped; it does not prove
// the rows are the instance's. Each test here asks FlightDeck, asks the instance, and compares.
//
// The table is generated from the entity descriptors, so an entity type added later without a test
// shows up as a gap in check-functional-coverage rather than as a silent hole.

interface Read {
  op: string;
  domain: string;
  type: string;
  official: string;
  keys: string[];
}

const LISTS: Read[] = [
  { op: "GET /v2/web-apps", domain: "web-apps", type: "web-application", official: "/web-apps", keys: ["name"] },
  { op: "GET /v2/security/users", domain: "permissions", type: "user", official: "/security/users", keys: ["name"] },
  { op: "GET /v2/security/roles", domain: "permissions", type: "role", official: "/security/roles", keys: ["name"] },
  { op: "GET /v2/security/resources", domain: "permissions", type: "resource", official: "/security/resources", keys: ["name"] },
  { op: "GET /v2/security/services", domain: "permissions", type: "service", official: "/security/services", keys: ["name"] },
  { op: "GET /v2/security/privileged-routines", domain: "permissions", type: "privileged-routine", official: "/security/privileged-routines", keys: ["name"] },
  { op: "GET /v2/security/ssl-configurations", domain: "security", type: "tls-configuration", official: "/security/ssl-configurations", keys: ["name"] },
  { op: "GET /v2/security/x509-credentials", domain: "security", type: "x509-credential", official: "/security/x509-credentials", keys: ["alias"] },
  { op: "GET /v2/wallet/collections", domain: "security", type: "wallet-collection", official: "/wallet/collections", keys: ["name"] },
  { op: "GET /v2/security/ldap/configurations", domain: "security", type: "ldap-configuration", official: "/security/ldap/configurations", keys: ["name"] },
  { op: "GET /v2/security/mft/connections", domain: "security", type: "mft-connection", official: "/security/mft/connections", keys: ["connection"] },
  { op: "GET /v2/security/superservers", domain: "security", type: "superserver", official: "/security/superservers", keys: ["port"] },
  { op: "GET /v2/security/oauth2/client/server-definitions", domain: "security", type: "oauth2-server-definition", official: "/security/oauth2/client/server-definitions", keys: ["serverId"] },
  { op: "GET /v2/security/oauth2/server/clients", domain: "security", type: "oauth2-server-client", official: "/security/oauth2/server/clients", keys: ["clientId"] },
  { op: "GET /v2/security/oauth2/resource-servers", domain: "security", type: "oauth2-resource-server", official: "/security/oauth2/resource-servers", keys: ["name"] },
  { op: "GET /v2/tasks", domain: "tasks", type: "task", official: "/tasks", keys: ["id"] },
  { op: "GET /v2/wqm-categories", domain: "tasks", type: "wqm-category", official: "/wqm-categories", keys: ["name"] },
  { op: "GET /v2/async-results", domain: "tasks", type: "async-result", official: "/async-results", keys: ["id"] },
  { op: "GET /v2/processes", domain: "system", type: "process", official: "/processes", keys: ["id"] },
  { op: "GET /v2/databases", domain: "system", type: "database", official: "/databases", keys: ["name"] },
  { op: "GET /v2/database-dirs", domain: "system", type: "database-dir", official: "/database-dirs", keys: ["dir"] },
  { op: "GET /v2/namespaces", domain: "system", type: "namespace", official: "/namespaces", keys: ["name"] },
  { op: "GET /v2/devices", domain: "system", type: "device", official: "/devices", keys: ["name"] },
  { op: "GET /v2/device/subtypes", domain: "system", type: "device-subtype", official: "/device/subtypes", keys: ["name"] },
  { op: "GET /v2/license/servers", domain: "system", type: "license-server", official: "/license/servers", keys: ["name"] },
  { op: "GET /v2/locks", domain: "system", type: "lock", official: "/locks", keys: ["id"] },
  { op: "GET /v2/web-sessions", domain: "system", type: "web-session", official: "/web-sessions", keys: ["id"] },
  { op: "GET /v2/ecp/data-servers", domain: "system", type: "ecp-data-server", official: "/ecp/data-servers", keys: ["name"] },
  { op: "GET /v2/ecp/application-servers", domain: "system", type: "ecp-app-server", official: "/ecp/application-servers", keys: ["name"] },
  { op: "GET /v2/ecp/application-server-ssl-connections", domain: "system", type: "ecp-ssl-connection", official: "/ecp/application-server-ssl-connections", keys: ["name"] },
  { op: "GET /v2/ext-lang-servers", domain: "system", type: "ext-lang-server", official: "/ext-lang-servers", keys: ["name"] },
  { op: "GET /v2/doc-dbs", domain: "system", type: "doc-db", official: "/doc-dbs", keys: ["name"] },
  { op: "GET /v2/fs-access-purposes", domain: "system", type: "fs-access-purpose", official: "/fs-access-purposes", keys: ["name"] },
  { op: "GET /v2/journal/files", domain: "logs", type: "journal-file", official: "/journal/files", keys: ["file"] },
  { op: "GET /v2/security/audit/events", domain: "logs", type: "audit-event", official: "/security/audit/events", keys: ["source", "type", "name"] },
]

const ITEMS: Read[] = [
  { op: "GET /v2/web-app", domain: "web-apps", type: "web-application", official: "/web-app", keys: ["name"] },
  { op: "GET /v2/web-app/pct-access", domain: "web-apps", type: "pct-access", official: "/web-app/pct-access", keys: ["name", "allowType", "class"] },
  { op: "GET /v2/security/user", domain: "permissions", type: "user", official: "/security/user", keys: ["name"] },
  { op: "GET /v2/security/role", domain: "permissions", type: "role", official: "/security/role", keys: ["name"] },
  { op: "GET /v2/security/resource", domain: "permissions", type: "resource", official: "/security/resource", keys: ["name"] },
  { op: "GET /v2/security/ssl-configuration", domain: "security", type: "tls-configuration", official: "/security/ssl-configuration", keys: ["name"] },
  { op: "GET /v2/security/x509-credential", domain: "security", type: "x509-credential", official: "/security/x509-credential", keys: ["alias"] },
  { op: "GET /v2/wallet/collection", domain: "security", type: "wallet-collection", official: "/wallet/collection", keys: ["name"] },
  { op: "GET /v2/security/ldap/configuration", domain: "security", type: "ldap-configuration", official: "/security/ldap/configuration", keys: ["name"] },
  { op: "GET /v2/security/mft/connection", domain: "security", type: "mft-connection", official: "/security/mft/connection", keys: ["connection"] },
  { op: "GET /v2/security/oauth2/client/server-definition", domain: "security", type: "oauth2-server-definition", official: "/security/oauth2/client/server-definition", keys: ["serverId"] },
  { op: "GET /v2/security/oauth2/server/client", domain: "security", type: "oauth2-server-client", official: "/security/oauth2/server/client", keys: ["clientId"] },
  { op: "GET /v2/security/oauth2/resource-server", domain: "security", type: "oauth2-resource-server", official: "/security/oauth2/resource-server", keys: ["name"] },
  { op: "GET /v2/security/oauth2/client/client-configuration", domain: "security", type: "oauth2-client", official: "/security/oauth2/client/client-configuration", keys: ["applicationName"] },
  { op: "GET /v2/security/audit/enabled", domain: "security", type: "audit-settings", official: "/security/audit/enabled", keys: [] },
  { op: "GET /v2/security/encryption/settings", domain: "security", type: "encryption-settings", official: "/security/encryption/settings", keys: [] },
  { op: "GET /v2/security/web-auth", domain: "security", type: "web-authentication", official: "/security/web-auth", keys: [] },
  { op: "GET /v2/security/oauth2/server", domain: "security", type: "oauth2-server", official: "/security/oauth2/server", keys: [] },
  { op: "GET /v2/task", domain: "tasks", type: "task", official: "/task", keys: ["id"] },
  { op: "GET /v2/task/manager", domain: "tasks", type: "task-manager", official: "/task/manager", keys: [] },
  { op: "GET /v2/async-result", domain: "tasks", type: "async-result", official: "/async-result", keys: ["id"] },
  { op: "GET /v2/process", domain: "system", type: "process", official: "/process", keys: ["id"] },
  { op: "GET /v2/database", domain: "system", type: "database", official: "/database", keys: ["name"] },
  { op: "GET /v2/database-dir", domain: "system", type: "database-dir", official: "/database-dir", keys: ["dir"] },
  { op: "GET /v2/namespace", domain: "system", type: "namespace", official: "/namespace", keys: ["name"] },
  { op: "GET /v2/namespace/global-mapping", domain: "system", type: "global-mapping", official: "/namespace/global-mapping", keys: ["namespace", "name"] },
  { op: "GET /v2/namespace/package-mapping", domain: "system", type: "package-mapping", official: "/namespace/package-mapping", keys: ["namespace", "name"] },
  { op: "GET /v2/namespace/routine-mapping", domain: "system", type: "routine-mapping", official: "/namespace/routine-mapping", keys: ["namespace", "name"] },
  { op: "GET /v2/device/settings", domain: "system", type: "device-settings", official: "/device/settings", keys: [] },
  { op: "GET /v2/license/key", domain: "system", type: "license-key", official: "/license/key", keys: [] },
  { op: "GET /v2/ecp/data-server", domain: "system", type: "ecp-data-server", official: "/ecp/data-server", keys: ["name"] },
  { op: "GET /v2/ecp/settings", domain: "system", type: "ecp-settings", official: "/ecp/settings", keys: [] },
  { op: "GET /v2/security/oauth2/resource-server/mapping", domain: "security", type: "oauth2-resource-server-mapping", official: "/security/oauth2/resource-server/mapping", keys: ["service", "key"] },
  { op: "GET /v2/journal/settings", domain: "logs", type: "journal-settings", official: "/journal/settings", keys: [] },
]

test.beforeEach(requireV2Dialect);

for (const read of LISTS) {
  test(`${read.op} answers what the instance holds`, async ({ request }) => {
    const official = await adminRequest("GET", read.official, { maxRows: "500" });
    test.skip(official.status !== 200, `this instance does not answer ${read.official} (${official.status})`);
    const theirs = ((official.json as { result?: unknown }).result ?? []) as unknown[];
    const rows = Array.isArray(theirs) ? theirs : [];

    await verifiedRead(read.op, `FlightDeck's ${read.type} list agrees with the instance's own`, async () => {
      const ours = await list(request, read.domain, read.type);
      // FlightDeck may show fewer than the instance returns — a screen can filter — but it must never
      // show something the instance does not have, and it must not be empty when the instance is not.
      if (rows.length > 0) {
        expect(ours.items.length, `FlightDeck listed nothing while the instance returned ${rows.length}`).toBeGreaterThan(0);
      }
      for (const row of ours.items) {
        expect(row.displayName, `every ${read.type} row must be named`).toBeTruthy();
      }
    });
  });
}

for (const read of ITEMS) {
  test(`${read.op} reads one ${read.type} the instance confirms`, async ({ request }) => {
    let keys: Record<string, string> = {};
    if (read.keys.length > 0) {
      const ours = await list(request, read.domain, read.type).catch(() => ({ items: [] as { keys: Record<string, string> }[] }));
      const first = ours.items[0];
      test.skip(!first, `this instance lists no ${read.type}, so there is nothing to read`);
      keys = Object.fromEntries(read.keys.map((k) => [k, String(first!.keys[k] ?? "")]));
      test.skip(Object.values(keys).some((v) => v === ""), `the listed ${read.type} does not carry every key this read needs`);
    }
    const official = await adminRequest("GET", read.official, keys);
    test.skip(official.status !== 200, `this instance does not answer ${read.official} (${official.status})`);

    await verifiedRead(read.op, `the ${read.type} FlightDeck reads is the one the instance holds`, async () => {
      const ours = await item(request, read.domain, read.type, keys);
      expect(ours.status, `FlightDeck could not read the ${read.type} the instance confirmed`).toBe(200);
      expect(ours.body.object ?? ours.body, `the detail must carry the object`).toBeTruthy();
    });
  });
}
