# Research: Unified Log Stream (feature 005)

Phase 0. Every finding below was taken from the running IRIS CE 2026.2 install on port 52780
(`iris-flightdeck-iris-1`) on 2026-09-18. Findings that changed the design are marked **finding**.

---

## R1 — The messages log: format, and the severity the platform itself states (finding)

**Probe**: `/durable/iris/mgr/messages.log`, resolved from the instance (`$zutil(12)` gives the
manager directory; the file is `messages.log` inside it), never a hard-coded path.

```
06/26/26-16:32:16:927 (15309) 0 [Generic.Event] Allocated 504MB shared memory
09/18/26-04:45:26:546 (1672) 0 [Utility.Event] Enabling logons
```

The shape is `MM/DD/YY-HH:MM:SS:mmm (pid) <level> [Category.Event] message`.

**Decision**: parse those five parts. The third field is **the platform's own severity level**, so the
normalised severity is a mapping of a number the instance stated, not a judgement FlightDeck made:
0 → info, 1 → warning, 2 → error, 3 → fatal. A line that does not match the shape becomes an event
whose message is the line itself, with the parse gap stated (spec FR-006).

**Consequence**: `process` comes from the parenthesised pid and correlates to the processes domain;
`namespace` and `user` are absent in this source and stay absent rather than being guessed.

---

## R2 — Backwards paged reading is possible without reading the file whole (finding)

**Probe**: `%Stream.FileCharacter` linked to the 47 KB messages log, `MoveTo(size - 2000)` then
`Read(80)` returned the tail slice and nothing before it.

**Decision**: pages are read by seeking to `size - (page × window)` and reading one window, then
splitting into lines and discarding the first (partial) line, which belongs to the previous page.
The window and the line limit are declared parameters, and nothing ever reads the whole file
(RN-FD-25, spec FR-012, FR-013).

**Stability across a growing file** (spec FR-015): every page is taken against the size observed when
the *first* page was read, and that size travels in the cursor. A file that grew since does not shift
the pages already served; new content is reached by starting a new read, not by silently moving the
window.

**Rotation and truncation** (spec FR-014): the cursor also carries the file's size and modification
time. When either moved backwards the reader stops and says the file changed under it, instead of
mixing two files' content.

---

## R3 — The alerts log does not exist on a stock instance (finding)

**Probe**: the manager directory holds `messages.log`, `journal.log` and `SystemMonitor.log`. There
is no `alerts.log`: IRIS writes one only where the System Monitor's alert handling is configured.

**Decision**: the alerts source reads `alerts.log` where the instance writes one and, where it does
not, is listed as unavailable with exactly that reason and where alerts are configured — not as an
empty source, which would read as "no alerts have happened" (spec FR-010, UC09 A1). `SystemMonitor.log`
is read as part of the same source when present, because it is where the monitor states what it
raised; its lines carry their own timestamp and text.

**Alternative considered**: deriving alerts from the messages log by severity, which most viewers do.
Rejected: it would report an alert the instance never raised, and the whole point of the source is to
show what the platform itself escalated.

---

## R4 — The interoperability event log is SQL, per namespace (finding)

**Probe**: `USER` reports `IsEnsembleNamespace = 1`; `%SYS` does not. `Ens_Util.Log` exists in `USER`
with columns `ID, ConfigName, Job, MessageId, SessionId, SourceClass, SourceMethod, Stack,
StatusValue, Text, TimeLogged, TraceCat, Type`.

**Decision**: read it with SQL, ordered by `ID` descending, one bounded page per namespace, across
**every** interoperability-enabled namespace up to a declared cap (spec FR-011a). `Type` is the
platform's own level (`Ens.DataType.LogType`: 1 assert, 2 error, 3 warning, 4 info, 5 trace), so
severity is again a mapping of a stated value: 1 and 2 → error, 3 → warning, 4 → info, 5 → info with
the trace category kept in the message.

**Correlation**: `Job` is the process, `SessionId` is the interoperability session, `ConfigName` the
production item. `Job` correlates to the processes domain; the namespace is the namespace the row was
read from, which is a fact, not a guess.

**Cost**: one bounded query per namespace per refresh. The cap is declared and what it left out is
stated, the same rule the column privileges panel and the certificate validity reads already use.

---

## R5 — Journal records are asynchronous, and carry no user (finding)

**Probe**: `POST /v2/journal/file/records?file=…&maxRows=3` answers **202** with
`LOCATION: /api/admin/v1/async-result?id=…`, and the finished result is a plain array:

```json
{"Address": 131312, "TypeName": "SET", "ExtTypeName": "SET", "TimeStamp": "2026-09-18 04:45:24",
 "InTransaction": false, "ProcessID": 1677, "GlobalNode": "^SYS(\"LastLicenseKey\")",
 "DatabaseName": "/durable/iris/mgr/"}
```

**Decision**: the journal source is read through the asynchronous helper feature 004 built — the same
one that serves the disk instrument, the long storage operations and the audit records. Nothing new
is written for it.

**Normalisation**: `timestamp` from `TimeStamp`, `process` from `ProcessID`, `message` from the record
type and the global node, `raw` the whole row. There is **no severity and no user** in a journal
record: severity is `unknown` (the fifth value, spec FR-003a) and `user` stays absent. `DatabaseName`
is a database, not a namespace, so it is carried in the message and the raw record rather than being
put in the `namespace` field, which would be a quiet lie.

---

## R6 — Audit records carry their own key for the full record (finding)

**Probe**: `POST /v2/security/audit/records` (asynchronous, as feature 004 found) returns rows with
`AuditIndex, UTCTimeStamp, SystemID, EventSource, EventType, Event, Username, Namespace, Pid, Roles,
Description, EventData, Authentication, JobId, JobNumber, SessionID, ClientIPAddress, Status`.
`GET /v2/security/audit/record` requires exactly `utcTimeStamp`, `systemID` and `auditIndex` — all
three present in every row.

**Decision**: the list is the stream's source; the detail read is what "access to the original record"
means for this source (UC09 Gherkin 1), and the three-part key travels with each event so the detail
can be fetched on demand rather than eagerly.

**Normalisation**: `timestamp` from `UTCTimeStamp`, `namespace`, `user` from `Username`, `process`
from `Pid`, `message` from `Event` and `Description`. Audit records state no severity level, so
severity is `unknown` unless the record's `Status` reports a failure, which maps to `error`.

**Correlation**: `Pid` → processes, `Namespace` → namespaces, `Username` → users, and `SessionID`
relates an audit record to the web session that produced it.

---

## R7 — The fifth severity value, and why the scale in the brief is widened

**Decision** (from the spec's clarification): `unknown`, outside the ordering of info, warning, error
and fatal.

**Rationale**: two of the five sources state no level at all (journal records, most audit records).
Mapping them to `info` would assert a classification nobody made, and deriving one from the text is
wrong silently — "no errors found" would become an error. The deviation from docs/prd.md §7 is
recorded in the spec (FR-003b), and the minimum-severity filter states how it treats `unknown`
(FR-003c) rather than dropping it quietly.

---

## R8 — Live follow: polling, and what "rate limited" means here

**Decision**: live follow polls, as the instrument cluster does (feature 004 R1: the official API
offers no streaming endpoint, and a FlightDeck-owned one would poll on the server behind a long-lived
connection with nothing observable gained). The mode and interval are visible.

**Rate limiting** (spec FR-018) is about what the screen keeps, not about what the server sends: each
refresh takes the newest events up to a per-refresh limit, prepends them, and when a source reported
more than the limit the screen states how many were not shown. The window is bounded and nothing is
persisted (spec FR-020).

**Alternative considered**: dropping the oldest silently. Rejected for the reason this whole feature
exists: a log viewer that quietly loses events is worse than one that says it did.

---

## R9 — Audit event definitions live in the logs domain

**Decision** (from the spec's clarification): an "Audit events" section of the logs domain, with
`PUT` and `DELETE` through the shared mutation layer.

**Rationale, recorded so it does not read as an inconsistency with feature 003**: the auditing family
divides by the nature of the object, not by the verb. The audit *state* (enabled or not) and the
audit *records* are data, and data stays in the security domain; the *definitions of what is
captured* are configuration of an investigation, and they belong where the investigating happens.
The two sections link to each other (spec FR-031a).

---

## R10 — Journal configuration against journal records

**Decision**: the journal appears twice, deliberately. Its **records** are a source of the stream
(R5). Its **files, settings and operations** — switch file, switch directory, integrity check — are a
section of configuration, with every write through the shared mutation layer (spec FR-028, FR-029).

**Grades**: settings are reinforced; switching the file or the directory is reinforced with the
instance-wide effect stated; the integrity check runs through the asynchronous helper with its
expected duration declared, as the storage operations of feature 004 do (spec FR-030).

**On IRIS 2026.1** every journal operation is withheld on the v1 dialect with the reason feature 001
recorded ("FlightDeck does not read the journal natively: filtering records by the databases you can
read is an authorization decision that belongs to IRIS"). Both the source and the section state that
reason there, and the other four sources keep streaming.

---

## R11 — What the stream reuses

**Reused unchanged**: the screen pattern (list, inspector, filters, section tabs), the single shared
dry-run and trail, the descriptor mechanism, the capability map and policy, the dialect boundary, the
asynchronous helper (`FlightDeck.Async.Runner`), and the correlation contract feature 004 wrote —
`taskId`, `taskName`, `from`, `to` in the address, which the logs route's empty state already
displays and which this feature turns into a filter (spec FR-025).

**Added**: one reader for files (backwards, paged, bounded), one normaliser per source, and one merge
that orders events from several sources into one line. The merge is the only genuinely new mechanism,
and it belongs to the logs domain rather than to the pattern: no other domain merges sources.

**Not added**: no new confirmation UI, no second polling loop (live follow uses the same shape as the
cluster), no chart library, no streaming transport.

---

## R12 — Correlation targets, and the honest limit of each

| Source | process | namespace | user | task |
|---|---|---|---|---|
| Audit records | `Pid` | `Namespace` | `Username` | — |
| Journal records | `ProcessID` | — (the row names a database, not a namespace) | — | — |
| Messages log | pid from the line | — | — | — |
| Alerts | pid when the line carries one | — | — | — |
| Interoperability | `Job` | the namespace it was read from | — | — |

**Decision**: a jump is offered only where the field exists, and a target the instance no longer
reports says so rather than offering a dead link (spec FR-027). No source carries a task identifier,
so the task correlation is the one feature 004 sends **into** this screen, not one the stream derives.
