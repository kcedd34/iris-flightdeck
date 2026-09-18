# Data Model: Unified Log Stream (feature 005)

Phase 1. Shapes are the ones the running instance returned (see `research.md`), never invented.

---

## 1. The normalised event

One shape for all five sources (spec FR-001 to FR-006, RN-FD-23, RN-FD-24).

```json
{
  "id": "audit:5310:2026-09-18 12:57:21.793",
  "timestamp": "2026-09-18 12:57:21.793",
  "source": "audit",
  "severity": "unknown",
  "namespace": "%SYS",
  "process": "45246",
  "user": "_SYSTEM",
  "message": "AuditReport · List Query",
  "raw": { "…": "the record exactly as the source gave it" },
  "rawAvailable": true,
  "rawReason": null,
  "correlate": { "process": "45246", "namespace": "%SYS", "user": "_SYSTEM" },
  "parsed": true
}
```

- `severity` ∈ `info | warning | error | fatal | unknown`. `unknown` is outside the ordering: it is
  what a source that states no level gets, and it is never inferred from the text (spec FR-003a).
- `raw` is **mandatory**. Where the original cannot be recovered, `rawAvailable` is false and
  `rawReason` says why; the normalised fields are still shown (spec FR-005).
- `parsed` is false for a line that did not match its source's shape; the line itself is then the
  message, and nothing is dropped (spec FR-006).
- A field a source does not provide is **absent**, not empty and not guessed.
- `id` is stable across refreshes so a live update does not duplicate an event already on screen.

## 2. The five sources

Declared as data (spec FR-034). Each carries its availability, its reason, and its severity mapping.

| id | Reads | Severity mapping | Correlates |
|---|---|---|---|
| `audit` | `POST /v2/security/audit/records` (asynchronous), detail by `utcTimeStamp`+`systemID`+`auditIndex` | `Status` reports a failure → error; otherwise `unknown` | process, namespace, user |
| `journal` | `POST /v2/journal/file/records` (asynchronous), per file from `GET /v2/journal/files` | none stated → `unknown` | process |
| `messages` | the instance's `messages.log`, read backwards in pages | the platform's own level: 0 info, 1 warning, 2 error, 3 fatal | process |
| `alerts` | `alerts.log` and `SystemMonitor.log` where the instance writes them | as messages; a monitor line with no level → `unknown` | process when the line carries one |
| `interop` | `Ens_Util.Log` in every interoperability-enabled namespace, capped | `Type`: 1,2 → error; 3 → warning; 4,5 → info | process, namespace |

**Availability** is per source, and the stream renders with whatever answers (spec FR-010):

```json
{"id": "alerts", "available": false,
 "reason": "This instance writes no alerts log. Alerts are configured in System Monitor, and appear here once it writes one."}
```

`audit` disabled on the instance and `journal` withheld on the v1 dialect are the two reasons a
source is most often absent; both are the platform's own words plus where to change it (FR-011).

## 3. Reading a file backwards (RN-FD-25)

```
cursor = { file, size, modified, offset, window, lines }
```

- The first page seeks to `size − window`; each further page moves `window` earlier.
- The first line of a page is discarded as partial — it belongs to the page before it.
- `size` and `modified` are captured on the first page and carried: a file that grew does not shift
  the pages already served (spec FR-015).
- When `size` or `modified` moves **backwards**, the reader stops and states that the file changed
  under it (rotation or truncation), rather than mixing two files (spec FR-014).
- `window` and `lines` are declared caps. The whole file is never read (spec FR-013).

## 4. The merge

One request answers the stream: each selected source is read for the window asked, the events are
merged by timestamp descending, and ties break on `source` then `id` so the order is stable between
refreshes.

```json
{
  "events": [ … ],
  "sources": [ {"id": "audit", "available": true, "read": 20, "suppressed": 0}, … ],
  "window": {"from": "…", "to": "…"},
  "truncated": {"reason": "the per-refresh limit", "suppressed": 143},
  "timeZone": "the instance's zone, stated"
}
```

- `suppressed` per source and in total is what the screen states during live follow (spec FR-018).
- `sources` always lists **every** source, including the unavailable ones with their reason: the list
  of what was read is part of the answer, not a detail (spec FR-010, FR-023).

## 5. Filters and the address

| Filter | Values |
|---|---|
| `source` | any subset of the five |
| `severity` | a minimum of info, warning, error, fatal — and an explicit choice for `unknown` |
| `from`, `to` | the period, in the instance's zone |
| `q` | free text over the normalised message and, when asked, the raw record |
| `taskId`, `taskName` | from feature 004's correlation contract |

- The minimum-severity filter **states how it treats `unknown`** (spec FR-003c): it is not ordered,
  so it is included or excluded by its own switch, and the screen says which.
- Arriving with `taskId` + `from` + `to` opens the stream filtered on them and says so (FR-025,
  FR-026). This is the contract feature 004 wrote and tested; this feature consumes it unchanged.

## 6. Entity types and mutations

| Entity type | Keys | List | Detail | Section |
|---|---|---|---|---|
| `logs/event` | `id` | the merge (§4) | the event plus its raw record | stream |
| `logs/journal-file` | `name` | `GET /v2/journal/files` | `GET /v2/journal/file` | journal |
| `logs/journal-settings` | — (singleton) | — | `GET /v2/journal/settings` | journal |
| `logs/audit-event` | `source`, `type`, `name` | `GET /v2/security/audit/events` | `GET /v2/security/audit/event` | audit events |

| Operation | Kind | Grade | Notes |
|---|---|---|---|
| `PUT /v2/journal/settings` | upsert | reinforced | Changes how the instance journals |
| `POST /v2/journal/switch-file` | action | reinforced | States the instance-wide effect |
| `POST /v2/journal/switch-dir` | action | reinforced | Same, and names the directory |
| `POST /v2/journal/file/integrity-check` | action, **asynchronous** | reinforced | `expectedDuration` declared (spec FR-030) |
| `PUT /v2/security/audit/event` | upsert | simple | What the instance records |
| `DELETE /v2/security/audit/event` | delete | reinforced | Consequence: those events stop being recorded |

Nothing here adds a confirmation path: every one goes through the shared dry-run and trail
(spec FR-033).

## 7. Correlation out of an event (RN-FD-26)

| Field | Opens |
|---|---|
| `process` | `system/process` in the operating system domain |
| `namespace` | `system/namespace` |
| `user` | `permissions/user` |
| `taskId` (only when the address carried one) | `tasks/task` |

A jump is offered only where the field exists; a target the instance no longer reports says so rather
than offering a dead link (spec FR-027).

## 8. Export

The filtered result, with every event's `raw`, plus a header naming the filters that produced it and
the sources that were unavailable at the time (spec FR-022, FR-023). The export is the same data the
screen showed — not a second query with different filters.
