# Data Model: Tasks and Operating System Management (feature 004)

Phase 1. Shapes are the ones the running instance returned (see `research.md`), never invented.
Everything here is declared as data — descriptors, facts, markers, links, grades — unless it says
otherwise.

---

## 1. Entity types

Declared in `FlightDeck.Domain.EntityTypes`. `keys` are the parameters the official operation takes.

### 1.1 Tasks domain (`tasks`)

| Entity type | Keys | List | Detail | Notes |
|---|---|---|---|---|
| `tasks/task` | `id` | `GET /v2/tasks` | `GET /v2/task` | Composed list: history is joined in (§3) |
| `tasks/task-manager` | — (singleton) | — | `GET /v2/task/manager` | `{Status}`; suspend and resume are actions |
| `tasks/wqm-category` | `name` | `GET /v2/wqm-categories` | `GET /v2/wqm-category` | Full CRUD |
| `tasks/async-result` | `id` | `GET /v2/async-results` | `GET /v2/async-result` | Cancel, pause, resume |

**Facts on `tasks/task`** (from the observed rows): `isSystem` (`Type = "System"`), `suspended`,
`hasHistory`, `lastResult` (`Success`, `Error`, or absent), `lastStart`, `lastDuration`,
`nextScheduled`, `running` (a history row with no `Completed`).

**Markers**: `system` (predicate `{facts.isSystem}`), `suspended`, `failing` (last result is an
error), `intermittent` (the band holds both results in the window).

### 1.2 Operating system domain (`system`)

| Entity type | Keys | List | Detail |
|---|---|---|---|
| `system/process` | `id` | `GET /v2/processes` | `GET /v2/process` |
| `system/database` | `name` | `GET /v2/databases` | `GET /v2/database` |
| `system/database-dir` | `dir` | `GET /v2/database-dirs` | `GET /v2/database-dir` |
| `system/namespace` | `name` | `GET /v2/namespaces` | `GET /v2/namespace` |
| `system/device` | `name` | `GET /v2/devices` | `GET /v2/device` |
| `system/device-subtype` | `name` | `GET /v2/device/subtypes` | `GET /v2/device/subtype` |
| `system/device-settings` | — (singleton) | — | `GET /v2/device/settings` |
| `system/license-key` | — (singleton) | — | `GET /v2/license/key` (inline shape, no named schema) |
| `system/license-server` | `name` | `GET /v2/license/servers` | `GET /v2/license/server` |
| `system/lock` | `deleteId` | `GET /v2/locks` | — (the row is the detail) |
| `system/web-session` | `id` | `GET /v2/web-sessions` | — (the row is the detail; the platform offers no per-session read, only `DELETE`) |
| `system/ecp-data-server` | `name` | `GET /v2/ecp/data-servers` | `GET /v2/ecp/data-server` |
| `system/ecp-app-server` | `name` | `GET /v2/ecp/application-servers` | — |
| `system/ecp-ssl-connection` | `name` | `GET /v2/ecp/application-server-ssl-connections` | — |
| `system/ecp-settings` | — (singleton) | — | `GET /v2/ecp/settings` |
| `system/ext-lang-server` | `name` | `GET /v2/ext-lang-servers` | `GET /v2/ext-lang-server` |
| `system/doc-db` | `name` | `GET /v2/doc-dbs` | `GET /v2/doc-db` |
| `system/fs-access-purpose` | `name` | `GET /v2/fs-access-purposes` | `GET /v2/fs-access-purpose` |

**Facts on `system/process`** (observed): `canBeExamined`, `canBeSuspended`, `canBeTerminated`,
`canReceiveBroadcast`, `isOwnSession`, `state`, `namespace`, `username`, `cpuTime`, `memoryUsed`,
`elapsedTime`.

**Facts on `system/lock`**: `removable`, `canBeExamined`, `isSystem`.

**Facts on `system/database-dir`**: `mounted` (from `Status`), `readOnly`, `encrypted`, `mirrored`,
`sizeMB`, `maxSize`, `occupancyBand` (same thresholds the home panel uses).

---

## 2. Mutations

Declared in `FlightDeck.Mutation.Descriptors`. Grade is data; no screen decides a grade.

### 2.1 Tasks

| Operation | Kind | Grade | Notes |
|---|---|---|---|
| `PUT /v2/task`, `POST /v2/task` | upsert | simple | Create and edit |
| `DELETE /v2/task` | delete | reinforced | Blocked by `selfProtection` when `facts.isSystem` |
| `POST /v2/task/suspend`, `/resume` | action | simple | |
| `POST /v2/task/run` | action | simple | Body `{"RunNow": true}`; refusal of a concurrent run is the platform's answer, reported with the start time |
| `POST /v2/task/manager/suspend` | action | **reinforced** | Text states the effect on the whole instance |
| `POST /v2/task/manager/resume`, `/run` | action | simple | |
| `PUT`, `DELETE /v2/wqm-category` | upsert, delete | simple, reinforced | |
| `POST /v2/async-result/cancel`, `/pause`, `/resume` | action | simple | |

### 2.2 Operating system

| Operation | Kind | Grade | Notes |
|---|---|---|---|
| `POST /v2/process/terminate` | action | **maximum** | Typed process identifier; `selfProtection` blocks the session's own process |
| `POST /v2/process/suspend`, `/resume` | action | reinforced | Enabled only where `facts.canBeSuspended` |
| `POST /v2/process/broadcast` | action | simple | Enabled only where `facts.canReceiveBroadcast` |
| `DELETE /v2/lock` | delete | reinforced | Enabled only where `facts.removable` |
| `PUT /v2/database`, `PUT /v2/database-dir`, `POST /v2/database-dir` | upsert | reinforced | Creation is performed |
| `POST /v2/database-dir/mount`, `/dismount` | action | reinforced | |
| `POST /v2/database-dir/expand-volume`, `/modify-size` | action | reinforced | |
| `POST /v2/database-dir/compact`, `/defragment`, `/integrity-check` | action, **asynchronous** | reinforced | Confirmation states the expected duration (§4) |
| `PUT /v2/namespace`, `/global-mapping`, `/package-mapping`, `/routine-mapping` | upsert | simple | Mappings are simple; the namespace itself is reinforced |
| `POST /v2/namespace/copy-mappings`, `/enable-interop` | action | reinforced | |
| `DELETE /v2/namespace/*-mapping` | delete | reinforced | |
| `PUT`/`DELETE /v2/device`, `/device/subtype`, `PUT /v2/device/settings` | upsert, delete | simple, reinforced | |
| `PUT /v2/license/key` | upsert | reinforced | `secretFields: ["AuthorizationKey"]` (research R13) |
| `POST /v2/license/key/validate` | action | simple | Read-only check; shows the platform's answer |
| `PUT`/`DELETE /v2/license/server` | upsert, delete | simple, reinforced | |
| `PUT`/`DELETE /v2/ecp/data-server`, `POST /v2/ecp/data-server/action`, `PUT /v2/ecp/settings` | upsert, delete, action | reinforced | |
| `POST /v2/ecp/application-server-ssl-connection/authorize`, `/reject`, `DELETE` | action, delete | reinforced | |
| `PUT`/`DELETE /v2/ext-lang-server`, `POST /start`, `/stop` | upsert, delete, action | simple, reinforced | |
| `PUT`/`DELETE /v2/doc-db` | upsert, delete | simple, reinforced | |
| `PUT`/`DELETE /v2/fs-access-purpose`, `/path` | upsert, delete | simple, reinforced | |

### 2.3 Declined on every version (`FlightDeck.Capability.Policy`)

| Operation | Reason and native path |
|---|---|
| `POST /v2/database-dir/truncate` | Returns space to the file system with no recovery from the portal, and no safe rehearsal. System Administration > Configuration > Local Databases. |
| `DELETE /v2/database` | FlightDeck creates databases but does not delete them: deletion removes data with no recovery. Same native path. |
| `DELETE /v2/namespace` | FlightDeck creates namespaces but does not delete them: deletion detaches mappings and data with no recovery. System Administration > Configuration > Namespaces. |

Each message names what FlightDeck does do, so the asymmetry between creating and deleting reads as
a decision, not a gap (spec FR-037a, research R10).

---

## 3. Composed reads (FlightDeck's own layer)

- **Task list with history band.** `GET /v1/domains/tasks/task` reads `GET /v2/tasks` and, once,
  `GET /v2/task/history`, groups the history rows by `TaskId`, and returns per task: the last result,
  the last duration, and a bounded band of recent results (most recent first). One history read per
  list, never one per task (research R7).
- **Process list.** Passes the four capability fields straight through as facts; no derivation.
- **Instrument cluster.** `GET /v1/telemetry` (§4) composes the native host metrics, the platform's
  monitor reads and the asynchronous disk value.

---

## 4. Telemetry and the asynchronous value

### 4.1 `GET /v1/telemetry`

One call answers the whole cluster, so N instruments are not N requests per second (research R1).

```json
{
  "mode": "polling",
  "intervalSeconds": 1,
  "asOf": "2026-09-18 01:51:15",
  "instruments": [
    {"id": "cpu", "label": "CPU", "unit": "%", "value": 34, "band": "normal",
     "scope": "host", "available": true, "reason": null},
    {"id": "memory", "label": "Memory", "unit": "%", "value": 61, "band": "normal", "available": true},
    {"id": "disk", "label": "Disk", "unit": "%", "value": 72, "band": "caution",
     "async": {"state": "Running", "lastValueAt": "2026-09-18 01:51:15", "stale": false,
               "detail": "IRISAPP 72%", "message": null}},
    {"id": "processes", "label": "Processes", "unit": "", "value": 142, "available": true},
    {"id": "devices", "label": "Devices", "unit": "", "value": 7, "available": true}
  ],
  "resources": [{"name": "Routine", "seize": 12571, "nseize": 5, "aseize": 3}]
}
```

- `available: false` carries `reason` from the capability map, never a version test (spec FR-021).
- `band` is `normal`, `caution` or `warning`, on the thresholds the home panel already uses.
- The sliding window is **not** in this payload: the client keeps it, bounded, and nothing is
  persisted (spec FR-018, RN-FD-21).

### 4.2 The asynchronous value

State machine, from the observed `AsyncTask` (research R6):

```
idle ──fire──▶ Queued ──▶ Running ──▶ Finished        (value replaces the last known value)
                 │            │
                 │            ├──▶ Failed    (last known value stays, platform message beside it)
                 │            └──▶ Canceled  (same)
                 └──▶ Paused ──resume──▶ Running
```

Rules that the component enforces, not the screen:

1. The last known value stays on screen in every state but `Finished` with a new value.
2. A value older than the refresh interval is marked stale with the time it was read.
3. `FailureReason` (or the platform's error text) is shown beside the value, never instead of it.
4. No state ever renders a spinner where the number is (spec FR-023, RN-FD-32).

`DiskFree` is a formatted string from the platform ("792.78GB") and is displayed verbatim.

---

## 5. The logs correlation contract

A failed run's control navigates to:

```
/logs/stream?taskId=<Id>&taskName=<Name>&from=<LastStart − 1 min>&to=<Completed + 1 min>
```

- `from` and `to` are the platform's own timestamps, widened by one minute on each side.
- Until feature 005 builds the screen, the logs route's empty state reads these parameters and
  states what it received, so the jump is verifiable end to end now (spec FR-041b).
- The contract is owned by this feature; feature 005 consumes it.

---

## 6. Self-protection rules (data)

| Rule | Predicate | Effect |
|---|---|---|
| Own session's process | `{facts.isOwnSession}` on `POST /v2/process/terminate` | Affirmative block, explained |
| System task deletion | `{facts.isSystem}` on `DELETE /v2/task` | Block with the reason |
| Declined storage writes | policy, not a predicate | `available:false`, `declined:true`, reason and native path |

`isOwnSession` is a fact: the request process's `$job` compared with the target identifier
(research R15). No screen computes it.
