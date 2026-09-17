# Phase 1 Data Model: FlightDeck Foundation and Shell

FlightDeck owns no database tables. Every entity below is either:
- a runtime shape (a browser tab's memory, or one request on the backend),
- a file the day-1 script writes, or
- one of the three small per-user browser preferences.

IRIS stays authoritative for identity, privileges and every administered object.

---

## 1. VerificationReport  *(file, written by the day-1 script; schema in `contracts/verification-report.schema.json`)*

| Field | Type | Rules |
|---|---|---|
| `schemaVersion` | `1` | Constant |
| `generatedAt` | ISO-8601 string | UTC |
| `target.baseUrl` | string | Never includes credentials |
| `target.product` | `iris` \| `irisforhealth` \| `unknown` | From `/info.result.product`; `unknown` if probe 1 fails |
| `target.serverVersion` | string \| null | Raw `/info.result.serverVersion` |
| `target.apiVersion` | number \| null | `/info.result.apiVersion` |
| `probes` | ProbeResult[8] | Exactly 8, ordered 1..8 |
| `summary.counts` | `{confirmed_present, confirmed_absent, inconclusive}` | Sum is 8 |
| `summary.exitCode` | `0` \| `1` | `1` iff `counts.inconclusive > 0` |

### ProbeResult

| Field | Type | Rules |
|---|---|---|
| `id` | 1..8 | Fixed order from PRD §14 |
| `key` | `admin_api` \| `auth_path` \| `resource_shapes` \| `async_db_metrics` \| `wallet` \| `mgmnt_api` \| `log_sources` \| `audit_enabled` | |
| `title` | string | English |
| `classification` | `confirmed_present` \| `confirmed_absent` \| `inconclusive` | Exactly one |
| `finding` | object | Probe-specific facts (see below). Empty object when not established |
| `raw` | string \| null | **Required non-null** unless `classification = confirmed_present`. Error text or response excerpt, max 8 KB, with any `Authorization` value redacted |
| `durationMs` | integer | |
| `candidates` | CandidateResult[] | **Only on probe 2**. Exactly 3, in order `in_process`, `jwt`, `loopback_proxy` |

`CandidateResult`: `{ key, classification, raw, notes }`. Probe 2's own classification is
`confirmed_present` if any candidate is present. If none is present it is `confirmed_absent` when
all three are absent, and `inconclusive` otherwise. `finding.selected` is the first present
candidate in order, or `null`.

Probe-specific `finding` fields:

| Probe | Keys |
|---|---|
| 1 | `apiVersion`, `serverVersion`, `product` |
| 2 | `selected` |
| 3 | `systemResources.sampleKeys[]`, `sharedMemory.sampleKeys[]`, `matchesSpec` (bool per schema) |
| 4 | `taskStarted` (bool), `pollCount`, `latencyMs`, `resultKeys[]` |
| 5 | `collectionsStatus` (HTTP status) |
| 6 | `serviceCount` |
| 7 | `messagesLog.path`, `messagesLog.sampleLine`, `alerts.path`, `interop.queryAvailable` (bool), `interop.namespacesWithProductions[]` |
| 8 | `enabled` (bool) |

---

## 2. Session  *(backend: derived per request from the IRIS CSP session; frontend: tab memory)*

| Field | Type | Source / rules |
|---|---|---|
| `username` | string | `/info.result.username`. Never a portal account |
| `instance.product` | `iris` \| `irisforhealth` \| other string | `/info` |
| `instance.version` | string | Parsed for display only (`2026.2`). **Never used for capability decisions** (FR-012) |
| `instance.serverVersion` | string | Raw `/info` |
| `instance.apiVersion` | number | `/info`. Must be `>= 2`, otherwise sign-in is refused with the version message |
| `instance.namespace` | string | The namespace FlightDeck runs in |
| `authPath` | `in_process` | Constant in this feature (research R4) |
| `privileges` | map `resource → {use: bool}` | `/info.result.privileges`, keys normalized to `%Admin_<Key>` |
| `capabilitySummary` | `{allowed, total}` | Count over CapabilityEntry |
| `state` *(frontend only)* | `signed_out` \| `active` \| `expired` | See transitions |
| `safeMode` *(frontend only)* | `armed` \| `disarmed` | **Memory only.** Initial value is always `armed` |
| `tabId` *(frontend only)* | UUID | Generated at module load, memory only |
| `computationEpoch` *(frontend only)* | integer | Incremented on every re-authentication |

**Never present anywhere**: password, `Authorization` value, JWT, refresh token, `CSPSESSIONID`
value (browser-held, httpOnly, IRIS-owned).

**Transitions (frontend)**

```text
signed_out --POST /session 200--> active (safeMode = armed)
active --any API 401--> expired            (screen, tab, selection, drafts kept in memory)
expired --POST /session 200 (same user)--> active (computationEpoch += 1; all queries invalidated;
                                                    safeMode unchanged within the same tab)
expired --POST /session 200 (different user)--> active (full reset: drafts discarded,
                                                         safeMode = armed)
active --DELETE /session--> signed_out (memory cleared, safeMode = armed)
page load / new tab / duplicated tab --> signed_out or active, and safeMode = armed ALWAYS
safeMode: armed --explicit user action--> disarmed; disarmed --explicit action or reload--> armed
```

---

## 3. CapabilityEntry  *(backend-derived; `GET /session/capabilities`)*

| Field | Type | Rules |
|---|---|---|
| `operationId` | string | `"<METHOD> <path>"`, e.g. `"GET /v2/security/roles"`. Unique |
| `method` | `GET` \| `PUT` \| `POST` \| `DELETE` | |
| `path` | string | As in the official spec |
| `domain` | Domain | From the path-family table below |
| `mutating` | bool | `method != GET`, except for POST operations whose summary starts with "List"/"View" (`/v2/security/audit/records`, `/v2/journal/file/records`, `/v2/database-dir/info`), which count as non-mutating |
| `summary` | string | Official summary with the privilege prefix removed |
| `requires` | string[] | e.g. `["%Admin_Manage:U", "%Admin_Operate:U"]` (OR semantics). Empty means none required |
| `allowed` | bool | `requires` is empty, or any element is held with `use = true` |
| `reason` | string \| null | Null iff `allowed`. Otherwise §9 message 2 with `U` rendered as `Use`: `"Requires Use on %Admin_Secure. Ask your instance administrator for access."`, or for OR lists `"Requires Use on %Admin_Manage or %Admin_Operate. Ask your instance administrator for access."` |

**Validation**: exactly 273 entries for the bundled spec. A drift test compares the entry set with
`docs/sysadmin-api-v2.json`.

### Domain (operation → rail destination)

Domain assignment is **generated at build time from `docs/api-coverage.md`**: each `## N. <Domain>`
heading and the operation rows beneath it. It is not a hand-maintained path table, so it cannot
diverge from the coverage document.

| Domain id | Rail label | api-coverage section | Operations |
|---|---|---|---|
| `shell` | (none) | 0. Sessão | 5 |
| `web-apps` | Web applications and APIs | 1. Web apps e APIs | 8 |
| `permissions` | Permissions | 2. Permissões | 31 |
| `security` | Security and secrets | 3. Segurança e segredos | 89 |
| `tasks` | Tasks | 4. Tarefas | 24 |
| `system` | System | 5. Sistema operacional | 102 |
| `logs` | Logs | 6. Logs | 14 |

A build check fails if any operation in `docs/sysadmin-api-v2.json` is unassigned, assigned twice,
or if the counts differ from the table.

---

## 4. Section  *(frontend constant; FR-033)*

| Field | Type | Rules |
|---|---|---|
| `domain` | Domain (not `shell`) | |
| `id` | kebab-case string | Unique within the domain. URL segment |
| `label` | string | Sentence case, never uppercase |
| `order` | integer | Fixed. Order from spec Assumptions |

A domain with exactly one section renders **no** tab strip (Logs). The URL is
`/flightdeck/<domain>/<section>`. `/flightdeck/<domain>` redirects to the first section.

---

## 5. PaletteEntry

### 5a. ActionEntry *(client-built)*

| Field | Type | Rules |
|---|---|---|
| `id` | string | Stable. `nav:<domain>/<section>`, `shell:theme-dark`, `shell:safe-mode-disarm`, `op:<operationId>` |
| `kind` | `action` | |
| `label` | string | e.g. "Go to Security and secrets / TLS", "Delete a role" |
| `domain` | Domain | |
| `context` | string | e.g. the section name, or the operation path in mono |
| `mutating` | bool | True only for `op:` entries with `CapabilityEntry.mutating` |
| `enabled` | bool | From `CapabilityEntry.allowed` for `op:` entries. Always true for navigation/shell entries |
| `disabledReason` | string \| null | `CapabilityEntry.reason` |
| `target` | route | Owning domain route for `op:` entries (this feature) |

### 5b. EntityEntry *(server-found; `GET /palette/entities`)*

| Field | Type | Rules |
|---|---|---|
| `kind` | `entity` | |
| `domain` | Domain | |
| `entityType` | string | e.g. `Role`, `Web application`, `Task` |
| `name` | string | As returned by IRIS |
| `context` | string | Disambiguation, e.g. namespace, or `"Role · 3 resources"` |
| `sourceOperationId` | string | The list operation it came from |
| `target` | `{route, inspect: {entityType, name}}` | Opens the domain route with the inspector identifying the entity |

### 5c. EntitySearchGroup

| Field | Type | Rules |
|---|---|---|
| `domain` | Domain | |
| `entityType` | string | |
| `state` | `ok` \| `forbidden` \| `timeout` \| `error` | |
| `reason` | string \| null | Required when not `ok` |
| `results` | EntityEntry[] | Top `limit` |
| `total` | integer \| null | Count before truncation when known |

---

## 6. RecentAction  *(browser `localStorage`, key `flightdeck:recent:<username>`)*

| Field | Type | Rules |
|---|---|---|
| `id` | PaletteEntry id | |
| `label`, `domain`, `kind` | copied from the entry | Display only |
| `usedAt` | ISO string | |

Max 8 entries, most recent first, deduplicated by `id`. It never contains query text typed by the
user, credentials or entity data beyond name and label.

## 7. ThemePreference  *(browser `localStorage`, key `flightdeck:theme:<username>`)*

`"dark"` \| `"light"`. If absent, `prefers-color-scheme` applies. Before sign-in, the OS preference
always applies.

---

## 8. Vital  *(backend `GET /vitals`; last known value kept in `%session.Data("vitals")` and client memory)*

| Field | Type | Rules |
|---|---|---|
| `id` | `cpu` \| `memory` \| `shm` \| `disk` | Always all four, in this order |
| `label` | `CPU` \| `Memory` \| `Shared memory` \| `Disk` | Wording from `docs/prototype.html`, which prevails over design §4 (design §10). Accessible names: "Host CPU in use", "Host memory in use", "IRIS shared memory heap in use", "Fullest database" |
| `source` | `native` \| `api` | `native` for cpu and memory (research R8), `api` for shm and disk |
| `scope` | string \| null | `"Docker host kernel"` when running in a container, otherwise null. Shown in the tooltip |
| `state` | `ok` \| `caution` \| `warning` \| `unavailable` | Thresholds: caution ≥ 75 %, warning ≥ 90 % |
| `value` | number \| null | Percent, 0–100, one decimal |
| `asOf` | ISO string \| null | When `value` was measured |
| `pending` | bool | An async refresh is in flight. The client keeps showing `value` |
| `reason` | string \| null | Required when `unavailable` (e.g. "Host metrics are not readable on this platform.") |
| `requires` | string \| null | Missing privilege when unavailable for permission reasons |

## 9. DemoObject  *(installer log line; not stored)*

| Field | Type | Rules |
|---|---|---|
| `kind` | `resource` \| `role` \| `web-app` \| `task` \| `wallet-collection` | |
| `name` | string | Prefix `FD_Demo` / `/csp/fd-demo` / `FD Demo` |
| `outcome` | `created` \| `exists` \| `skipped` | `skipped` needs a reason, e.g. wallet unavailable |

---

## 10. Fixture draft  *(fixtures build only; FR-017a)*

| Field | Type | Rules |
|---|---|---|
| `current` | `{description: string}` | Loaded from `GET /session` (username echo) |
| `draft` | `{description: string}` | Typed by the tester |
| `diff` | `{field, before, after}[]` | Computed |
| `diffEpoch` | integer | `computationEpoch` at compute time. Confirmation is disabled while `diffEpoch != computationEpoch` |
