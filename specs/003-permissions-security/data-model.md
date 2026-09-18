# Phase 1 Data Model: Permissions, Security and Secrets

Everything here is descriptor data or a server-computed answer. No new storage exists: official
objects are read and written through official operations, and FlightDeck adds only metadata beside
them.

## 1. Entity types (descriptor data, `FlightDeck.Domain.EntityTypes`)

| Id | Section | List operation | Detail operation | Keys | Notes |
|---|---|---|---|---|---|
| `permissions/user` | users | `GET /v2/security/users` | `GET /v2/security/user` | `name` | mutations: create (POST), edit (PUT), delete, password |
| `permissions/role` | roles | `GET /v2/security/roles` | `GET /v2/security/role` | `name` | now writable (feature 002 shipped it read-only) |
| `permissions/resource` | resources | `GET /v2/security/resources` | `GET /v2/security/resource` | `name` | `AllowDelete` from the list governs the delete control (Constitution IX) |
| `permissions/service` | services | `GET /v2/security/services` | `GET /v2/security/service` | `name` | edit only; creation does not exist officially |
| `permissions/privileged-routine` | privileged-routines | `GET /v2/security/privileged-routines` | `GET /v2/security/privileged-routine` | `name` | |
| `security/tls-configuration` | tls | `GET /v2/security/ssl-configurations` | `GET /v2/security/ssl-configuration` | `name` | action: connection test |
| `security/x509-credential` | x509 | `GET /v2/security/x509-credentials` | `GET /v2/security/x509-credential` | `alias` | validity facts from the certificate read |
| `security/oauth2-server-definition` | oauth2 | `GET /v2/security/oauth2/client/server-definitions` | `GET /v2/security/oauth2/client/server-definition` | `serverId` | |
| `security/oauth2-client` | oauth2 | `GET /v2/security/oauth2/client/client-configurations` | `GET /v2/security/oauth2/client/client-configuration` | `applicationName` | needs `serverId` to list: parameterised |
| `security/oauth2-server-client` | oauth2 | `GET /v2/security/oauth2/server/clients` | `GET /v2/security/oauth2/server/client` | `clientId` | |
| `security/oauth2-resource-server` | oauth2 | `GET /v2/security/oauth2/resource-servers` | `GET /v2/security/oauth2/resource-server` | `name` | mappings as a panel |
| `security/wallet-collection` | wallet | `GET /v2/wallet/collections` | `GET /v2/wallet/collection` | `name` | secrets as a panel; delete states the secret count |
| `security/wallet-secret` | wallet | `GET /v2/wallet/secrets` (needs `collection`) | — | `collection`, `name` | write-only object: no detail operation exists, and none is wanted |
| `security/ldap-configuration` | ldap | `GET /v2/security/ldap/configurations` | `GET /v2/security/ldap/configuration` | `name` | known platform defect on the listing |
| `security/mft-connection` | mft | `GET /v2/security/mft/connections` | `GET /v2/security/mft/connection` | `name` | token deletion is an action |
| `security/superserver` | superservers | `GET /v2/security/superservers` | `GET /v2/security/superserver` | `port` | |
| `security/encryption-key-file` | encryption | `GET /v2/security/encryption/file/keys` (needs `file`) | — | `file`, `id` | read-only by policy |

### Singleton types (detail only, no list)

| Id | Section | Detail operation | Write |
|---|---|---|---|
| `security/audit-settings` | audit | `GET /v2/security/audit/enabled` | `PUT /v2/security/audit/enabled` |
| `security/encryption-settings` | encryption | `GET /v2/security/encryption/settings` | declared unavailable by policy |
| `security/web-authentication` | web-auth | `GET /v2/security/web-auth` | `PUT /v2/security/web-auth`; SMTP password as an action |
| `security/oauth2-server` | oauth2 | `GET /v2/security/oauth2/server` | `PUT`, `DELETE`, server password action |

## 2. Facts (server-computed, `FlightDeck.Domain.Facts`)

| Fact | Applies to | Source | Used by |
|---|---|---|---|
| `enabled` | user | `Enabled` | markers, the last-administrator predicate |
| `expired` | user | `ExpirationDate` against the instance's date; the API normalises "no limit" to an empty string, and an expired account is still reported `Enabled: true` (probe P1) | marker, predicate |
| `externalAuthentication` | user | `AutheEnabled` bits for delegated and LDAP | the origin note of spec US1-3 |
| `isSystem` | role, resource, service | official naming and flags the schema exposes | disables what the platform refuses |
| `daysRemaining` | X.509 credential | `ValidityNotAfter` from the per-alias certificate read, cached with a cap because the listing does not carry it (probe P3) | band marker, attention list |
| `validityBand` | X.509 credential | `daysRemaining` against the alert window | `valid`, `expiring`, `expired`, `unknown`, `not-read` (beyond the cap or refused) |
| `validityUnknown` | TLS configuration | the API reports no validity for the certificate file | states the gap instead of implying validity |
| `secretCount` | wallet collection | `GET /v2/wallet/secrets` | the reinforced delete message |

## 3. Link providers (graph, RN-FD-13)

| Provider | From | Shows |
|---|---|---|
| `user-roles` | user | direct roles, escalation roles, and each role's inherited chain |
| `effective-privileges` | user, role | one row per resource and permission, each with every granting chain |
| `role-owners` | role | direct owners, users and roles alike (already shipped in feature 002) |
| `role-holders` | role | the users behind a role, by walking role owners inversely with a cycle guard and cap (probe finding B) |
| `role-resources` | role | resources granted, with permissions |
| `resource-roles` | resource | roles granting it (already shipped) |
| `resource-objects` | resource | web applications, wallet collections, privileged routines, databases and services it protects |
| `wallet-users` | wallet collection | resource → roles → users who can use its secrets |
| `sql-privileges` | user, role | parameterised by namespace; provenance is the API's own `GrantedVia` and `GrantedBy`, not a local traversal (probe P4) |
| `tls-consumers` | TLS configuration | MFT connections, OAuth clients and superservers that name it |

Every provider reports `ok`, `none` or `undetermined` with a reason, so a refused read never renders
as an empty answer.

## 4. Effective privilege (computed, never stored)

```json
{
  "resource": "%DB_IRISSYS",
  "permission": "RW",
  "chains": [
    { "via": ["%Manager", "%DB_IRISSYS_Manager"], "kind": "role" },
    { "via": ["FD_Ops"], "kind": "escalation" }
  ],
  "truncated": false
}
```

`chains` is never empty: a privilege without a chain is not emitted. `truncated` is true when a cap
or a refused read stopped the traversal, and the panel states what was not expanded.

## 5. Mutation descriptors

### 5.1 New kind: `action`

```json
{
  "kind": "action",
  "operationId": "POST /v2/security/sql-privilege/revoke",
  "params": ["namespace", "grantee", "type", "object", "action"],
  "options": ["withGrant", "cascade", "asGrantor"],
  "readOperation": "GET /v2/security/sql-privileges",
  "target": "{action} on {object} for {grantee}",
  "grade": [{ "when": { "op": "true" }, "grade": "reinforced" }],
  "impact": "sql-privilege-impact"
}
```

The preview shows the affected set before and after, in the existing diff component; when no listing
exists, it shows the request block with the parameters that will be sent.

### 5.2 Grades in this feature

| Operation | Grade | Reason |
|---|---|---|
| user edit, role edit, resource edit | simple, reinforced when the change removes a role or permission | a removal is what impact analysis exists for |
| user delete, role delete, resource delete | reinforced; maximum when the target is a system entity | |
| any change affecting the signed-in user | reinforced, with the immediate-effect warning | spec FR-011 |
| SQL grant | simple | additive |
| SQL revoke | reinforced | removal |
| wallet collection delete | reinforced, stating the secret count | spec FR-017 |
| audit record purge | maximum, consequence stated | erases the instance's audit trail |
| audit record copy | reinforced; maximum when `DeleteAfterCopy` is true | |
| audit disable | reinforced | stops the instance recording security events |
| TLS or X.509 delete | reinforced; the consumers found by `tls-consumers` are the impact | |

### 5.3 Self-protection rules

| Rule | Applies to |
|---|---|
| last administrative access (spec FR-010 to FR-010-2): counts `%Admin_Secure:USE` holders and `%All` members, requires a non-empty baseline, compares `ExpirationDate` | role delete, role edit removing `%Admin_Secure` or `%All`, user delete, user disable, user role removal, resource delete or permission change on `%Admin_Secure` |
| declared unavailable by policy | every encryption write (R12) |

## 6. Trail record additions

`TrailRecord` gains two optional fields, written by the server and rendered by the existing trail
entry:

| Field | Values | Meaning |
|---|---|---|
| `checkMode` | `complete`, `partial` | which mode the last-administrator evaluation ran in |
| `checkResult` | `held`, `would-remove-last`, `not-determined` | the predicate's answer for this change |

They appear only for operations that run the predicate, and the export carries them unchanged.

## 7. Attention item (home panel, RN-FD-15)

```json
{
  "kind": "expiring-credential",
  "target": { "domain": "security", "entityType": "x509-credential", "keys": { "alias": "fd_demo" } },
  "label": "fd_demo expires in 12 days",
  "band": "expiring",
  "daysRemaining": 12
}
```

The endpoint returns the items the session may read, plus a `degraded` flag with the reason when a
source was refused, following the shape feature 001 already uses for the palette's degraded groups.
