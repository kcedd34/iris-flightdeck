---

description: "Task list for feature 005: the unified log stream"
---

# Tasks: Unified Log Stream

**Input**: Design documents from `/specs/005-unified-logs/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/](./contracts/), and the probe results recorded in
`verification/README.md` ("Log sources, probed for feature 005").

**Tests**: test tasks are included because the spec's acceptance scenarios — the UC09 Gherkin,
verbatim — are the definition of done, as in features 001 to 004.

**Organization**: by user story. US1 is the normalised line (P1), US2 live follow (P1), US3 a source
that is absent saying why (P2), US4 correlation and export (P2).

**Two ordering rules this list inherits from the plan.**

1. **The reader and the source contract land before any source.** Four of the five depend on them,
   and the rule that cannot be retrofitted — never read a file whole — lives there. A source written
   before the contract is a source that gets rewritten.
2. **Every source delivers its unavailable path in the same task as its happy path.** On a stock
   Community instance the alerts source is *normally* absent, and on IRIS 2026.1 the journal source
   is. If that path is built later, the screen an evaluator opens first is the one tested last.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: US1, US2, US3, US4
- Paths are repository-relative and exact

---

## Phase 1: Setup (shared infrastructure)

- [X] T001 Add this feature's official schemas to `scripts/build/gen-schemas.py`: `AuditEvent`
  (already present, verify), `JournalFile`, `JournalFileList`, `JournalSettings`, `JournalRecord`
  and the audit record shape, using the names the operations actually reference (read them back from
  `docs/sysadmin-api-v2.json`, as feature 004 did); regenerate and run
  `scripts/build/check-generated.sh`.
- [X] T002 Add the logs domain's three sections to `frontend/src/shell/domains.ts`, replacing the
  single `stream` section: `stream` (the unified line), `journal` (files, settings, operations) and
  `audit-events` (the capture definitions). The domain keeps its position in the rail.
- [X] T003 [P] Add the Playwright project `logs` to `frontend/playwright.config.ts`, matching
  `logs.spec.ts`, in the shape the existing projects use.
- [X] T004 Extend `scripts/build/check-coverage.py` with `"6. Logs": "005"` in `SHIPPED`, so the
  domain's 14 official operations are counted from now on. Run it: it must name all 14 as unreached
  before the work starts, which is the check proving it counts them (spec FR-032, SC-009).

---

## Phase 2: Foundational (blocking prerequisites)

### The reader and the contract (before any source)

- [X] T005 Write `backend/cls/FlightDeck/Logs/Reader.cls`: backwards paged reading of one file.
  Seek to `size − (page × window)` with `%Stream.FileCharacter.MoveTo`, read one `window`, split
  lines and **discard the first line** (it belongs to the earlier page). `window` and the line limit
  are declared parameters. The whole file is never read, at any size (RN-FD-25, spec FR-012, FR-013).
- [X] T006 Give the reader a cursor carrying `file`, `size`, `modified`, `offset`, `window` and
  `lines`: `size` and `modified` are captured on the first page, so a file that grew does not shift
  pages already served (spec FR-015), and when either moves **backwards** the reader stops and
  reports that the file changed under it rather than mixing two files (spec FR-014).
- [X] T007 Write `backend/cls/FlightDeck/Logs/Event.cls`: the normalised event of `data-model.md` §1 —
  `id`, `timestamp`, `source`, `severity`, `namespace`, `process`, `user`, `message`, `raw`,
  `rawAvailable`, `rawReason`, `correlate`, `parsed`. A field the source does not provide is
  **absent**, never defaulted. `id` is stable across refreshes.
- [X] T008 Declare the severity scale in the same class: `info`, `warning`, `error`, `fatal` and
  `unknown`. `unknown` is **outside the ordering** — what a source that states no level gets — and is
  never inferred from the message text (spec FR-003a, FR-003b).
- [X] T009 Write `backend/cls/FlightDeck/Logs/Source.cls`: the contract of
  `contracts/log-sources.md` — `Page(window, cursor, limit)` answering
  `{events, cursor, available, reason, read, suppressed, unread}` — and the registry that names the
  five sources with their `severityMap`, `correlates`, `kind` and the official operations each calls.
  No source ever states a privilege (Constitution III).
- [X] T010 Write `backend/cls/FlightDeck/Logs/Stream.cls`: the merge. Read the selected sources,
  order by timestamp descending with ties broken on source then id so the order is stable between
  refreshes, apply the per-refresh limit, and answer **every** source's state — including the
  unavailable ones with their reason (spec FR-010, data-model §4).

### The five sources, each with its unavailable path

- [X] T011 [P] `backend/cls/FlightDeck/Logs/Sources/Messages.cls`: the instance's messages log,
  resolved from the instance (`$zutil(12)` plus `messages.log`), never a hard-coded path. Parse
  `MM/DD/YY-HH:MM:SS:mmm (pid) <level> [Category.Event] message`; map the platform's own level
  0 → info, 1 → warning, 2 → error, 3 → fatal (research R1). A line that does not match becomes an
  event with `parsed: false` carrying the line as its message (spec FR-006). Unavailable path: the
  file cannot be read — the source says so with the reason.
- [X] T012 [P] `backend/cls/FlightDeck/Logs/Sources/Alerts.cls`: `alerts.log` and
  `SystemMonitor.log` where the instance writes them, through the same reader. **A stock instance
  writes no alerts log** (research R3), so the unavailable answer is this source's normal state:
  "This instance writes no alerts log. Alerts are configured in System Monitor, and appear here once
  it writes one." Never an empty page, which would read as "no alerts have happened".
- [X] T013 [P] `backend/cls/FlightDeck/Logs/Sources/Interop.cls`: `Ens_Util.Log` read with SQL,
  newest first, one bounded page per namespace, across **every** interoperability-enabled namespace
  up to a declared cap. Map `Type`: 1 and 2 → error, 3 → warning, 4 and 5 → info (research R4). The
  page names the namespaces it read and those the cap or a refusal left out (spec FR-011a).
- [X] T014 [P] `backend/cls/FlightDeck/Logs/Sources/Audit.cls`: `POST /v2/security/audit/records`
  through `FlightDeck.Async.Runner` (feature 004). Carry each row's three-part key —
  `utcTimeStamp`, `systemID`, `auditIndex` — so the original record is one read away (research R6).
  Severity: `Status` reports a failure → error, otherwise `unknown`. Unavailable path: auditing
  disabled on the instance is reported with that reason **and where to enable it** (spec FR-011).
- [X] T015 [P] `backend/cls/FlightDeck/Logs/Sources/Journal.cls`: `GET /v2/journal/files` then
  `POST /v2/journal/file/records` through the same asynchronous helper. No user and no severity in a
  journal record: severity is `unknown` and `user` stays absent; `DatabaseName` is a database, not a
  namespace, so it goes in the message and the raw record and **not** in `namespace` (research R5).
  Unavailable path: on the v1 dialect every journal operation is withheld — the source states the
  reason feature 001 recorded, and the other four keep streaming.
- [X] T016 Add the entity types to `backend/cls/FlightDeck/Domain/EntityTypes.cls`: `logs/event`,
  `logs/journal-file`, `logs/journal-settings` (singleton) and `logs/audit-event` (keys `source`,
  `type`, `name`), as `data-model.md` §6 gives them.
- [X] T017 Declare the six mutation descriptors in `backend/cls/FlightDeck/Mutation/Descriptors.cls`:
  `PUT /v2/journal/settings` (reinforced), `POST /v2/journal/switch-file` and `/switch-dir`
  (reinforced, each stating the instance-wide effect), `POST /v2/journal/file/integrity-check`
  (asynchronous, `expectedDuration` declared, spec FR-030), `PUT /v2/security/audit/event` (simple)
  and `DELETE /v2/security/audit/event` (reinforced, consequence: those events stop being recorded).
- [X] T018 Write `backend/cls/FlightDeck/API/Logs.cls` and add the routes to
  `backend/cls/FlightDeck/API/Router.cls`: `GET /v1/logs/events`, `GET /v1/logs/event/raw` and
  `GET /v1/logs/export`, matching `contracts/flightdeck-api-005.openapi.json`. All three are reads
  and stay available under safe mode.
- [X] T019 Register `specs/005-unified-logs/contracts/flightdeck-api-005.openapi.json` in
  `scripts/build/gen-openapi-cls.py` and regenerate, so the served document and the router agree
  (`FlightDeck.Test.RouterGuards` asserts it).

### Backend tests for the foundation

- [X] T020 [P] `backend/test/FlightDeck/Test/LogReader.cls`: a generated fixture file with known
  lines. Assert the first page is the tail, the next page is older, the partial first line is
  discarded exactly once, the caps hold, and **no read returns more than the window** — the test that
  makes "never read the file whole" checkable rather than aspirational.
- [X] T021 [P] `backend/test/FlightDeck/Test/LogReaderRotation.cls`: a file that grows between pages
  does not shift the pages already served; a file that shrinks or is replaced makes the reader stop
  and report the change (spec FR-014, FR-015).
- [X] T022 [P] `backend/test/FlightDeck/Test/LogNormalise.cls`: one case per source, each against a
  record shaped like the probe. Assert every normalised field, that `raw` is present, that a field
  the source does not provide is **absent** rather than empty, and that an unparsable line survives
  as an event with `parsed: false`.
- [X] T023 [P] `backend/test/FlightDeck/Test/LogSeverity.cls`: each source's mapping, and the two that
  state no level answering `unknown`. Assert that no mapping reads the message text — the test that
  catches a future "clever" inference.
- [X] T024 [P] `backend/test/FlightDeck/Test/LogStream.cls`: the merge orders by timestamp descending,
  breaks ties deterministically, counts what it suppressed, and lists **every** source including the
  unavailable ones with their reason.

---

## Phase 3: User Story 1 — One line for every subsystem (Priority: P1)

**Goal**: five formats, one schema, and the original record always reachable.

**Independent test**: with at least two sources producing events, both appear in one list under the
same fields, ordered by time, and each opens to show its original record.

- [X] T025 [US1] Build the stream section in `frontend/src/domains/logs/Stream.tsx`: the list on the
  shared pattern, columns timestamp, source, severity, namespace, process, user and message, newest
  first, with the instance's time zone stated once.
- [X] T026 [US1] Render severity with the existing state tokens; `unknown` is visibly distinct and is
  not shown as info (spec FR-003a). Nothing blinks (docs/design.md §7).
- [X] T027 [US1] Build the event inspector in `frontend/src/domains/logs/EventInspector.tsx`:
  normalised fields, then the original record fetched on demand through `GET /v1/logs/event/raw`.
- [X] T028 [US1] Where the original cannot be recovered, state it where the record would be and keep
  the normalised fields on screen (spec FR-005). Where a line did not parse, say so beside the
  message it kept (spec FR-006).
- [X] T029 [US1] Add the filters — source, severity, period, free text — to the list, in the address
  as the other domains do.
- [X] T030 [US1] The minimum-severity control **states how it treats `unknown`** and offers its own
  switch: unknown is not ordered, so it cannot be above or below a threshold, and an event must not
  disappear from a filtered view without the filter saying that it does (spec FR-003c).
- [X] T031 [US1] An empty result proposes widening the period or lowering the minimum severity
  (spec FR-021, UC09 A3).
- [X] T032 [P] [US1] `frontend/e2e/logs.spec.ts` — UC09 Gherkin 1: events from sources with different
  formats appear under the same field schema, and each gives access to its original record.
- [X] T033 [P] [US1] `frontend/e2e/logs.spec.ts`: an event whose source states no level shows
  `unknown`, and the severity filter says how it treats it.
- [X] T034 [P] [US1] `frontend/e2e/logs.spec.ts`: an unparsable line is present as an event with its
  line as the message and the gap stated — nothing is dropped.

---

## Phase 4: User Story 2 — Follow it live, without drowning (Priority: P1)

**Goal**: new events at the top without reloading, and an honest account of what was suppressed.

**Independent test**: with a source producing events faster than the display rate, new events appear
at the top, the list stays responsive, and the number suppressed is stated.

- [X] T035 [US2] Add live follow to the stream: poll `GET /v1/logs/events?since=…` on an interval,
  prepend what is new, and keep the mode and interval visible — the same shape the instrument cluster
  uses (research R8). No second polling mechanism is written.
- [X] T036 [US2] Bound the client-side window and persist nothing: a reload starts clean
  (spec FR-020).
- [X] T037 [US2] State the suppression: when a refresh brought more than the limit, the most recent
  are kept and the screen says how many were not shown, per source and in total (spec FR-018).
- [X] T038 [US2] Pause live follow when the tab is hidden and resume on focus, preserving the window
  (spec FR-019).
- [X] T039 [P] [US2] `frontend/e2e/logs.spec.ts` — UC09 Gherkin 2: with live follow on, new events
  appear at the top without a reload.
- [X] T040 [P] [US2] `frontend/e2e/logs.spec.ts`: with more events than the limit, the count of
  suppressed events is stated and the newest are the ones kept.
- [X] T041 [P] [US2] `frontend/e2e/logs.spec.ts`: hiding the tab pauses the follow; returning resumes
  it with the window intact; reloading starts a new window.

---

## Phase 5: User Story 3 — A source that is not there says why (Priority: P2)

**Goal**: the absence of a source is information, not silence.

**Independent test**: with auditing disabled, the other sources still stream and the audit source
names the reason and the way to enable it.

- [X] T042 [US3] Render the source panel: every source, always, with its state — read count,
  suppressed count, and for the unavailable ones the reason (spec FR-010, data-model §4).
- [X] T043 [US3] For the audit source disabled on the instance, show the reason **and the path to
  enable it**, linking to the security domain's auditing section (spec FR-011, UC09 A5).
- [X] T044 [US3] For the interoperability source, name the namespaces read and those the cap or a
  refusal left out (spec FR-011a).
- [X] T045 [US3] For a source refused by permission, show the refusal as the platform worded it, and
  keep the others streaming (UC09 A1).
- [X] T046 [US3] When **no** source is available, say so listing each source and its reason, rather
  than showing an empty list that could be mistaken for silence (spec edge case).
- [X] T047 [P] [US3] `frontend/e2e/logs.spec.ts` — UC09 Gherkin 3: with auditing disabled, the other
  sources keep working and the audit source is flagged with the reason. The test turns auditing off
  through the shared mutation layer and restores it afterwards.
- [X] T048 [P] [US3] `frontend/e2e/logs.spec.ts`: the alerts source on a stock instance states that
  the instance writes no alerts log, and the stream still shows events from the others.

---

## Phase 6: User Story 4 — From an event to the thing it happened to (Priority: P2)

**Goal**: close the graph between logs and every other domain, in both directions, and let the result
leave the portal.

**Independent test**: from an event carrying a process identifier the process opens; from a failed
task run the stream opens filtered on that task and window; an export carries what the filter
selected.

- [X] T049 [US4] Offer the jumps from the event inspector: process → `system/process`, namespace →
  `system/namespace`, user → `permissions/user` (RN-FD-26, spec FR-024, data-model §7).
- [X] T050 [US4] Offer a jump only where the field exists, and where the target is no longer reported
  by the instance say so instead of offering a dead link (spec FR-027).
- [X] T051 [US4] Consume feature 004's correlation contract: `taskId`, `taskName`, `from` and `to` in
  the address open the stream already filtered on them (spec FR-025).
- [X] T052 [US4] State on screen what the stream was filtered on when it opened from such an address,
  so the filter is visible rather than implicit (spec FR-026).
- [X] T053 [US4] Replace the logs route's placeholder empty state (feature 004 wrote it to display the
  correlation) with the real screen, keeping the same parameters working.
- [X] T054 [US4] Implement `GET /v1/logs/export`: the filtered result with every event's `raw`, plus
  a header naming the filters that produced it and the sources unavailable at the time
  (spec FR-022, FR-023).
- [X] T055 [US4] Wire the export control in the stream, using the shared download path the trail
  export already uses.
- [X] T056 [P] [US4] `frontend/e2e/logs.spec.ts` — UC09 Gherkin 4: an event with a process identifier
  offers a direct jump to that process, and the process inspector opens.
- [X] T057 [P] [US4] `frontend/e2e/logs.spec.ts` — SC-007: opening from a failed task run filters the
  stream on that task and window and says so.
- [X] T058 [P] [US4] `frontend/e2e/logs.spec.ts` — SC-008: an export carries exactly the filtered
  events, each with its original record, and names the filters and the unavailable sources.

---

## Phase 7: Journal and audit events as configuration

- [X] T059 Build the journal section in `frontend/src/domains/logs/Journal.tsx`: the files, the
  settings singleton, and the four operations through the shared dry-run (spec FR-028, FR-029).
- [X] T060 Switching the journal file or directory states the instance-wide effect in its
  confirmation; the integrity check is fired and polled with its expected duration stated
  (spec FR-030).
- [X] T061 Build the audit events section in `frontend/src/domains/logs/AuditEvents.tsx`: the
  definitions, with `PUT` and `DELETE` through the shared mutation layer (spec FR-031).
- [X] T062 Link the two auditing halves to each other: the security domain's auditing section points
  here for what is captured, and this section points there for the state and the records. Both state
  the split and why it is a split (spec FR-031a).
- [X] T063 [P] `frontend/e2e/logs.spec.ts`: a journal write goes through the shared dry-run at its
  declared grade, and the integrity check states its duration before anything is sent.
- [X] T064 [P] `frontend/e2e/logs.spec.ts`: an audit event definition is created and deleted through
  the shared confirmation, and the deletion's consequence names what stops being recorded.

---

## Phase 8: Polish & cross-cutting concerns

- [X] T065 Extend the pattern catalog fixture with a log-shaped case the live sources cannot produce
  on demand: an event whose original record is gone, and one whose line did not parse — the two
  states the screen must render honestly (feature 002 research R13).
- [X] T066 [P] Extend `frontend/e2e/audit.spec.ts` so the credential sweep covers the stream and its
  export: no password, Basic token or `Authorization` header may appear in an event, in a raw record
  or in an exported file (spec FR-037).
- [X] T067 [P] Design review of the logs domain in both themes against `docs/design.md` §4, §6 and
  §7, recorded in `specs/005-unified-logs/checklists/design-review.md`. Severity uses the state
  tokens; nothing blinks; the suppression note is information, not an alarm.
- [X] T068 [P] Accessibility pass with axe on the three logs sections in both themes, at the project's
  standard tag set, including the live region for events arriving during follow.
- [X] T069 Run `scripts/build/check-coverage.py`: all 14 logs operations must be implemented or
  declined, with no tolerated list (spec FR-032, SC-009).
- [X] T070 Rebuild `frontend/dist` and run every static gate — tokens, dialect, mutation-boundary,
  secrets, descriptors, coverage, dist, generated — fixing what they name.
- [X] T071 Measure SC-003 on a large file: grow the messages log to about 100 MB inside the container
  (`quickstart.md` §6), page back through the stream, and confirm the serving process does not grow
  with the file. Record the measurement in the sign-off.
- [X] T072 Limited-mode matrix on IRIS 2026.1: the journal source and section state the reason
  recorded in feature 001 while the other four sources keep streaming; extend
  `frontend/e2e/limited.spec.ts` accordingly and update the counts.
- [X] T073 Full matrix on fresh installs — IRIS CE 2026.2, IRIS for Health 2026.2 and IRIS CE 2026.1 —
  one install at a time: the whole backend suite, every Playwright project, both enforcement scripts
  and all static gates. Write `verification/feature-005-signoff.md` recording the three versions, as
  features 002 to 004 did.
- [X] T074 Run `specs/005-unified-logs/quickstart.md` §1 to §13 end to end and fix any step that does
  not work as written.

---

## Dependencies & Execution Order

- **Phase 1 (setup)** blocks everything. T004 is deliberate: the coverage check must first **fail**
  naming all 14 operations, which is what proves it counts this domain.
- **Phase 2 (foundational)** blocks all four stories. Within it, T005–T010 (the reader, the event,
  the contract, the merge) block T011–T015 (the sources), which is the first ordering rule of this
  list.
- **US1** depends on the whole of Phase 2.
- **US2** depends on US1's screen and on T010's suppression count.
- **US3** depends on each source's unavailable path, which T011–T015 delivered with their happy path.
- **US4** depends on US1 and on feature 004's correlation contract, which is already written.
- **Phase 7** depends on T016–T017 only, so it can run beside US2 to US4.
- **Polish** depends on everything; T072–T074 are the matrix, sign-off and quickstart, and come last.

## Parallel opportunities

- Phase 1: T003 beside T001.
- Phase 2: T011–T015 are five independent sources once T005–T010 are in — the widest parallel block
  of the feature; T020–T024 follow each in turn.
- US1: T032–T034 together once T025–T031 are in.
- US2: T039–T041 together.
- US3: T047–T048 together.
- US4: T056–T058 together.
- Polish: T066–T068 together.

## Implementation strategy

**MVP**: Phase 1 + Phase 2 + US1 gives the unified line with every source normalised and every
original record reachable — the axis the brief calls the differentiator, and the one no other domain
provides.

**If the feature has to shrink**: cut depth in US4 (the export before the jumps) and in Phase 7
(journal configuration before audit events), never the sources themselves. A stream missing a source
is not a unified stream, and the one rule that must not be traded away at any size is the pair the
whole feature rests on: `raw` always present, and an absent source stating why.
