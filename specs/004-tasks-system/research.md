# Research: Tasks and Operating System Management (feature 004)

Phase 0. Every decision below was taken against the running IRIS CE 2026.2 install on port 52780
(`iris-flightdeck-iris-1`) on 2026-09-18, through the official API, unless it says otherwise.
Probes that changed the design are marked **finding**.

---

## R1 — Telemetry transport: polling only

**Decision**: the instrument cluster polls FlightDeck's own telemetry endpoint. No streaming
transport is built.

**Rationale**: the official SysAdmin API has no streaming endpoint; every metric is a GET. A
FlightDeck-owned SSE layer would poll the platform on the server and hold a long-lived connection
behind the web gateway, with nothing an administrator could observe that polling does not already
give. The mode in use and the interval are shown on screen, so the absence of streaming is stated,
not hidden (spec FR-020, FR-020a).

**Alternatives considered**: SSE with automatic fallback (RN-FD-20's literal reading) — rejected as
above, and recorded in the spec as a decision with its reason; WebSocket — same objection plus a
second protocol to degrade.

**Consequence for the plan**: one read endpoint, `GET /v1/telemetry`, answering the whole cluster in
one call so that N instruments do not become N requests per second.

---

## R2 — `SharedMemoryUsage` is declared after all, and the probe confirms it (correction)

**Correction to the brief.** docs/prd.md says `SystemResourcesStats` and `SharedMemoryUsage` declare
no shape in the specification. In `docs/sysadmin-api-v2.json` as shipped, **both are fully declared**
— `SharedMemoryUsage` as an array of objects, `SystemResourcesStats` likewise. The probe therefore
does something better than fill a gap: it confirms the declared shape against a live instance, field
for field. Nothing is typed blind, and nothing is invented (spec FR-038 to FR-040).

**Probe**: `GET /v2/monitor/system-usage/shared-memory` → 200, an array of rows:

```json
{"Description": "Classes Instantiated", "SMHAllocated": 4259840, "SMHAvailable": 247296,
 "SMHUsed": 4012544, "SMTUsed": 1920, "GSTUsed": 0, "AllUsed": 4014464}
```

**Decision**: type it as a list of `{Description, SMHAllocated, SMHAvailable, SMHUsed, SMTUsed,
GSTUsed, AllUsed}`; render the rows whose `AllUsed` is non-zero, largest first, and keep the rest
behind the section's own listing. Unknown fields are ignored; absent fields render as absent, never
as zero (spec FR-038 to FR-040).

**Note**: the existing `FlightDeck.Vitals.Service.SharedMemory()` already reads this endpoint for the
home panel. It is reused, not duplicated (spec FR-046).

---

## R3 — `SystemResourcesStats` is the seize table (declared, and confirmed)

**Probe**: `GET /v2/monitor/dashboard/system-resources` → 200, an array of
`{Name, Seize, Nseize, Aseize, Bseize, BusySet}` rows (`Pid`, `Routine`, and so on).

**Decision**: this is resource contention, not a headline metric. It belongs in the instruments
section as a table below the cluster, not as a fourth instrument. Typed from the observed fields
only.

**Alternatives considered**: deriving a "contention" instrument from `Seize`/`Nseize` — rejected:
the specification declares no meaning for these counters, and inventing a threshold would be
inventing a fact.

---

## R4 — The dashboard endpoints carry the threshold words the platform itself uses

**Probe**: `GET /v2/monitor/dashboard/main` → 200, with `Performance`, `ECP`, `Status` and
`SystemUsage` blocks. `SystemUsage` reports `DatabaseSpace: "Normal"`, `LockTable: "Normal"`,
`WriteDaemon: "Normal"`, plus `Processes`, `CSPSessions` and a `BusyProcesses` list.

**Decision**: where the platform states a condition in words, FlightDeck shows those words and does
not recompute them. The occupancy threshold of spec FR-034 uses the same rule the home panel already
applies to disk per database, so the two screens cannot disagree.

**Finding**: `BusyProcesses` is padded with empty entries (`{"Process": "", "Commands": 0}`). They
are dropped on read; an empty process identifier is not a process.

---

## R5 — Process capability fields arrive on the list, not only on the detail (finding)

**Probe**: `GET /v2/processes?maxRows=2` → each row carries `CanBeExamined`, `CanBeSuspended`,
`CanBeTerminated` and `CanReceiveBroadcast`. `GET /v2/process` takes **`id`**, not `pid`
(`?pid=` answers 400).

**Decision**: the list is the source of the control state, so a row's buttons are decided without
opening it (spec FR-028). `CanBeExamined` is a fourth capability the use case does not name: it
governs whether the inspector opens at all, and a row where it is false shows the reason instead of
an empty inspector.

**Consequence**: no capability is inferred anywhere, and no request is issued for a control the API
disabled (spec FR-029). The four fields become descriptor facts, and the enablement rule is a
predicate over facts — data, not code.

**Stated as a rule, not as a case**: wherever an official schema exposes a capability field over an
object, that field governs the corresponding control. Processes are where this feature first meets
it; locks meet it again (R11). Any other schema carrying such a field is treated the same way, with
no new decision (plan, "A standing rule this feature establishes").

---

## R6 — The asynchronous handle arrives in a header, and the header names v1 (finding)

**Probe**: `POST /v2/database-dir/info?dir=/durable/iris/mgr/` → **202** with an empty `result` and

```
LOCATION: /api/admin/v1/async-result?id=027625106990288105865181
```

Polling `GET /v2/async-result?id=<id>` and `GET /v1/async-result?id=<id>` both answer 200 with the
same body, so the path in the header is a platform quirk, not a dialect instruction.

**Decision**: the asynchronous helper reads the identifier from the `LOCATION` header (falling back
to the body if a future version puts it there) and always polls through the dialect layer, never
through the path the header suggests. Nothing outside `FlightDeck.Admin` sees that string.

**Shape of a finished result**:

```json
{"State": "Finished", "TaskName": "POST /v2/database-dir/info", "Console": [], "FailureReason": "",
 "Result": {"Size": 70, "AvailableSpace": 8.1, "DiskFree": "792.78GB", "MaxSize": 0, "Full": false,
            "Mounted": true, "Blocks": 8960, "BlockSize": 8192, ...},
 "TimeQueued": "...", "TimeStarted": "...", "TimeFinished": "..."}
```

`State` is one of `Queued`, `Running`, `Finished`, `Failed`, `Canceled`, `Paused`.

**Consequence**: one asynchronous value component serves the disk instrument, the asynchronous
results section and the three long storage operations (R9). `DiskFree` is a formatted string
("792.78GB"), so it is displayed as the platform wrote it and never parsed into a number.

---

## R7 — `GET /v2/task/history` ignores the task id (finding, changes the design)

**Probe**: `/v2/task/history?id=1` and `?id=2` return the same 42 rows, covering every task on the
instance. Each row carries its own `TaskId`, `Name`, `LastStart`, `Completed`, `Result`, `Status`,
`Namespace`, `Routine`, `Pid`, `ErrDate`, `ErrNumber`, `Username`.

**Decision**: the recent-history band (spec FR-002, RN-FD-17) is built from **one** history read for
the whole list, grouped by `TaskId` on the server, rather than one read per task. This is also what
makes the band affordable: a list of forty tasks costs one request, not forty.

**Consequence**: the task list is a composed read — `GET /v2/tasks` for definition and schedule,
`GET /v2/task/history` once for the bands and the last result. The task list itself carries
`LastFinished` and `NextScheduled` but **no result**, so the result and the duration come from the
history rows. This composition lives behind FlightDeck's domain read, not in the screen.

**Platform defect to record**: the `id` parameter of `/v2/task/history` is accepted and ignored. It
is documented in `verification/README.md` and worked around as above, never masked.

---

## R8 — Task shapes

**Probe**: `GET /v2/tasks` rows are `{Name, Type, Namespace, Description, Id, Suspended,
LastFinished, NextScheduled}`; `Type` is `System` for the platform's own tasks, which is the fact
behind the "system task" marker of spec FR-007. `GET /v2/task?id=1` returns the full definition
(schedule fields, `TaskClass`, `RunAsUser`, e-mail settings). `GET /v2/task/upcoming` returns
`{Id, Name, Namespace, Suspended, Datetime}`. `GET /v2/task/manager` returns `{"Status": "Running"}`.

**Decision**: `Type = "System"` is a marker with a predicate over facts, and it disables deletion
with the reason (spec FR-007). The manager's `Status` is a singleton entity type, as the journal and
audit configuration already are, with suspend and resume as reinforced-grade actions whose text
states the instance-wide effect (spec FR-008).

**On-demand run**: `POST /v2/task/run` takes `{"RunNow": true}`. Refusal of a concurrent run
(spec FR-006) is the platform's own answer; FlightDeck reports it with the start time it already has
from the history, and never retries.

---

## R9 — The three long storage operations run asynchronously, and say how long

**Decision** (from the spec's clarification): compact, defragment and integrity-check are fired and
then polled through the same asynchronous helper as R6. Their confirmation text states the expected
duration as well as the risk, and the domain stays usable while they run (spec FR-037b, FR-037c).

**Rationale**: an operation that takes minutes, presented as a synchronous request, reads as a frozen
application — the same failure the TLS connection test showed in feature 003, where a ten-second wait
needed an explicit "up to ten seconds" notice.

**Request shapes** (from the specification): `POST /v2/database-dir/integrity-check` takes a
`{"Databases": [{"Directory": ...}]}` body; the other directory operations take the `dir` query
parameter.

---

## R10 — What FlightDeck declines, and how the refusal reads

**Decision**: declined on every version, through the existing capability policy: truncating a
database directory, deleting a database, deleting a namespace.

**The refusal names the native path and the asymmetry.** Creating a database or a namespace is
performed, so a message that only said "not available" would read as a defect. The text states what
FlightDeck does not do, why, and where the platform does it — for example:

> FlightDeck creates databases but does not delete them: deleting a database removes data with no
> recovery from the portal, and there is no safe way to rehearse it. Use System Administration >
> Configuration > Local Databases in the platform's management portal.

**Rationale**: this is the rule feature 003 applied to the eight encryption writes, and the mechanism
(`FlightDeck.Capability.Policy`, merged into the map as `available:false` with `declined:true`) is
already built and already shows the reason on screen.

---

## R11 — Locks carry their own capability field (finding)

**Probe**: `GET /v2/locks` rows are `{Pid, ModeCount, Reference, Directory, System, Removable,
DeleteID, CanBeExamined}`.

**Decision**: `Removable` governs the delete control exactly as the process fields do. This is the
rule of R5 meeting its second instance, which is why it is written as a rule: RN-FD-34 is about
schemas that declare capability, not about processes. Removal is reinforced grade (spec FR-035) and uses `DeleteID`, not a
composed key.

---

## R12 — The remaining families all answer on a stock install

**Probe** (all 200): `/v2/namespaces` (3), `/v2/databases`, `/v2/database-dirs`, `/v2/devices`,
`/v2/license/key`, `/v2/locks` (11), `/v2/web-sessions` (0 rows), `/v2/ecp/settings`,
`/v2/ext-lang-servers` (8), `/v2/doc-dbs` (0 rows), `/v2/fs-access-purposes` (0 rows),
`/v2/wqm-categories` (3).

**Decision**: every section of US4 has real data to show on a stock install except web sessions,
DocDB and file-system access purposes, which are legitimately empty. Those three get an empty state
that says the instance has none, never a broken screen. No fixture is invented to make them look
populated; the pattern catalog already proves the rendering.

---

## R13 — The licence key is read by the platform, so the mask is in the trail

**Probe**: `GET /v2/license/key` returns `AuthorizationKey` in full, among `LicenseCapacity`,
`CustomerName`, `OrderNumber`, `Product`, `LicenseType`, `Server`, `Platform`.

**Decision**: the mask lives in the mutation layer, never on the read. FlightDeck shows what the
official read returns — hiding a value the platform hands to
any administrator would be theatre, and Constitution VI is about material the portal must never
return, which this is not. What the mutation layer masks is the key **typed on upload**: it is a
`secretField` of `PUT /v2/license/key`, so the dry-run, the trail and its export show only "changed"
(spec FR-036). The key MUST NOT reach a backend log or the body of an error on any path, including a
failed write and a platform refusal (spec FR-036a); `check-secrets` and the `secrets` project both
assert it.

---

## R14 — Reuse, and the two declared pattern additions

**Reused unchanged**: the screen pattern (`DomainSection`, `SingletonSection`, `LinksPanel`,
`ObjectForm`, `useDomainMutation`), the single dry-run and trail, the descriptor mechanism
(entity types, markers, links, grades, self-protection), the capability map and policy, the dialect
boundary, and the native providers for host CPU and memory, disk per database and namespace reads on
v1 (spec FR-042 to FR-046).

**Addition 1 — the instrument cluster** (`src/pattern/instruments`): a canvas time series with a
bounded client-side window, a threshold state and a disabled state with a reason. Canvas, not a
declarative SVG library, because at one second with several series SVG degrades visibly
(docs/design.md §5; spec FR-015).

**Addition 2 — the asynchronous value** (`src/pattern/async`): fire, poll, keep the last known value,
mark it stale with the time it was read, show the platform's message on failure. Never a spinner in
place of a number (spec FR-022 to FR-025).

Both are additions to the pattern and its contract
(`specs/002-webapps-explorer-mutations/contracts/ui-pattern.md`, extended by
`contracts/ui-pattern-delta.md` here), not local components of one screen. The pattern catalog
fixture exercises both, as it does every other pattern behaviour.

---

## R15 — Self-protection for the session's own process

**Decision**: terminating the process that runs the signed-in session is refused by the server, in
`FlightDeck.Mutation.SelfProtection`, as a declared rule over facts — the same mechanism that already
protects FlightDeck's own web applications and the last administrative access.

**How the session's process is known**: `$job` of the request process, carried as a fact on the
process entity. The rule compares it to the target identifier; equality blocks, with the explanation
(spec FR-031, RN-FD-12).

**Rationale for blocking rather than warning**: the administrator cannot see the consequence of
terminating their own session before it happens — the portal would simply stop answering, which reads
as a crash. This is the one case in the domain where certainty exists, so the block is affirmative.

---

## R16 — The logs correlation contract

**Decision**: a failed run offers a jump to `/logs/stream?taskId=<id>&taskName=<name>&from=<start>&to=<end>`, where
the window is the run's start and completion, widened by one minute on each side. The logs route's
empty state reads those parameters and states what it received.

**Rationale**: writing and testing the contract here means feature 005 consumes parameters that
already exist instead of inventing them and coming back to change this feature (spec FR-041 to
FR-041b).

**Alternatives considered**: a disabled control until logs exist — rejected: it leaves a PRD
acceptance criterion unmet and shows a dead button; no control at all — rejected for the same reason,
with the debt moved to the next feature.
