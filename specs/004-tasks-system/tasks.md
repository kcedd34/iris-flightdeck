---

description: "Task list for feature 004: tasks and operating system management"
---

# Tasks: Tasks and Operating System Management

**Input**: Design documents from `/specs/004-tasks-system/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/](./contracts/), and the probe results recorded in
`verification/README.md` ("Tasks and system, probed for feature 004").

**Tests**: test tasks are included because the spec's acceptance scenarios — the UC07 and UC08
Gherkin, verbatim — are the definition of done, as in features 001 to 003.

**Organization**: by user story. US1 is the instrument cluster (P1), US2 processes (P1), US3 tasks
(P2), US4 the eleven remaining sections of the operating system domain (P3).

**Ordering note that overrides the usual reading of priorities.** The foundational phase carries the
full breadth: all 22 entity types, their facts and the ~60 descriptors, plus the three policy-declined
writes. It lands **before** the signature work, so US4's surface exists while US1 and US2 are still
being polished. US4 is not optional — it holds most of the 102 operations and the whole "covers the
etc" argument of the brief. If the feature has to shrink, depth comes out of US1 and US2 first, which
already stand on a finished pattern; the P3 surface is the last thing to cut.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: US1, US2, US3, US4
- Paths are repository-relative and exact

---

## Phase 1: Setup (shared infrastructure)

- [X] T001 Add this feature's official schemas to `scripts/build/gen-schemas.py`: `Task`, `TaskList`,
  `TaskHistory`, `TaskUpcoming`, `TaskManager`, `WQMCategory`, `WQMCategoryList`, `AsyncTask`,
  `AsyncTaskList`, `Process`, `ProcessList`, `Database`, `DatabaseList`, `DatabaseDirectory`,
  `DatabaseDirectoryList`, `Namespace`, `NamespaceList`, `GlobalMapping`, `PackageMapping`,
  `RoutineMapping`, `Device`, `DeviceList`, `DeviceSubtype`, `DeviceSettings`, `LicenseKey`,
  `LicenseServer`, `LicenseServerList`, `Lock`, `LockList`, `WebSession`, `WebSessionList`,
  `ECPDataServer`, `ECPApplicationServer`, `ECPSettings`, `ExtLangServer`, `ExtLangServerList`,
  `DocDB`, `DocDBList`, `FSAccessPurpose`, `FSAccessPurposePath`, then regenerate and run
  `scripts/build/check-generated.sh`.
- [X] T002 Record the two undeclared shapes as generated types from the probe, not from the
  specification: `SharedMemoryUsage` as a list of
  `{Description, SMHAllocated, SMHAvailable, SMHUsed, SMTUsed, GSTUsed, AllUsed}` and
  `SystemResourcesStats` as a list of `{Name, Seize, Nseize, Aseize, Bseize, BusySet}`, in
  `scripts/build/gen-schemas.py` with a comment naming `verification/README.md` as the source
  (spec FR-038, FR-039; research R2, R3).
- [X] T003 [P] Add the two domains to `frontend/src/shell/domains.ts` with their section tabs in the
  order UC08 gives: `system` → instruments, processes, databases, directories, namespaces, devices,
  licence, locks, web sessions, ECP, external language servers, DocDB, file access; `tasks` → tasks,
  WQM categories, async results (spec FR-001, FR-032).
- [X] T004 [P] Add the Playwright projects `instruments`, `processes`, `tasks` and `system` to
  `frontend/playwright.config.ts`, each with its spec file, in the shape the existing projects use.
- [X] T005 Write `scripts/build/check-coverage.py`: parse the operation tables of
  `docs/api-coverage.md` sections 4 and 5, assert the count is 24 + 102 = 126, and fail naming any
  operation that is neither reachable through a descriptor or a domain read nor declared in
  `FlightDeck.Capability.Policy`. Wire it into `scripts/build/check-generated.sh` (spec FR-033,
  SC-001). Probe it by removing one descriptor and confirming it names that operation.

---

## Phase 2: Foundational (blocking prerequisites)

**Breadth first**: every entity type and descriptor of both domains lands here, so US4's surface is in
place before the signature work begins.

### Entity types and facts

- [X] T006 Declare the four task-domain entity types in
  `backend/cls/FlightDeck/Domain/EntityTypes.cls`: `tasks/task` (key `id`), `tasks/task-manager`
  (singleton), `tasks/wqm-category` (key `name`), `tasks/async-result` (key `id`), each with its list
  and detail operation exactly as `data-model.md` §1.1 gives them.
- [X] T007 Declare the eighteen system-domain entity types in the same file, with the keys
  `data-model.md` §1.2 gives — note `system/process` keys on **`id`**, not `pid` (`?pid=` answers 400,
  research R5), and `system/lock` keys on `deleteId`.
- [X] T008 Add `Process()`, `Lock()`, `DatabaseDir()` and `Task()` to
  `backend/cls/FlightDeck/Domain/Facts.cls`. `Process()` carries `canBeExamined`, `canBeSuspended`,
  `canBeTerminated`, `canReceiveBroadcast` (straight from the row, never derived) and `isOwnSession`;
  `Lock()` carries `removable`, `canBeExamined`, `isSystem`; `DatabaseDir()` carries `mounted`,
  `readOnly`, `encrypted`, `mirrored`, `sizeMB`, `maxSize`, `occupancyBand` using the thresholds the
  home panel already applies; `Task()` carries `isSystem` (`Type = "System"`), `suspended`,
  `hasHistory`, `lastResult`, `lastStart`, `lastDuration`, `nextScheduled`, `running`.
- [X] T009 [P] Declare the markers in `EntityTypes.cls`: on tasks, `system`, `suspended`, `failing`
  and `intermittent`; on database directories, the occupancy band; on processes, the state. Each is a
  predicate over facts, never a computation in a screen.
- [X] T010 [P] Add the link providers to `backend/cls/FlightDeck/Domain/LinkProviders.cls`: task →
  its runs, database ↔ its directory, namespace ↔ its global, package and routine mappings, process →
  its namespace and user.

### Descriptors and policy

- [X] T011 Declare the task-domain mutation descriptors in
  `backend/cls/FlightDeck/Mutation/Descriptors.cls` exactly as `data-model.md` §2.1 lists them,
  including `POST /v2/task/run` with body `{"RunNow": true}`, and
  `POST /v2/task/manager/suspend` at **reinforced** grade whose text states the effect on the whole
  instance (spec FR-008).
- [X] T012 Declare the process, lock and storage descriptors as `data-model.md` §2.2 lists them,
  with `POST /v2/process/terminate` at **maximum** grade requiring the typed identifier
  (spec FR-030).
- [X] T013 Declare the remaining system descriptors (namespaces and their three mapping families,
  devices and subtypes, device settings, licence key and servers, ECP, external language servers,
  DocDB, file-system access purposes and their paths) as `data-model.md` §2.2 lists them. This is the
  bulk of US4 and lands before the signature work by design.
- [X] T014 Mark `AuthorizationKey` as a `secretField` of `PUT /v2/license/key` in the descriptor, so
  the dry-run, the trail and its export show only that it changed. The read is **not** masked: the
  official read returns the key to any administrator (spec FR-036; research R13).
- [X] T015 Add the three declined writes to `backend/cls/FlightDeck/Capability/Policy.cls`:
  `POST /v2/database-dir/truncate`, `DELETE /v2/database`, `DELETE /v2/namespace`. Each `reason`
  states that FlightDeck **creates** databases and namespaces, why the deletion is declined (no
  recovery from the portal, no safe rehearsal) and the `nativePath` in the platform's management
  portal, so the asymmetry reads as a decision, not a defect (spec FR-037a, FR-037d; research R10).
- [X] T016 Add the self-protection rules to `backend/cls/FlightDeck/Mutation/SelfProtection.cls`:
  terminating the process whose identifier equals the session's own (`isOwnSession`) is an
  affirmative block with its explanation; deleting a task whose `isSystem` fact is true is blocked
  with the reason (spec FR-031, FR-007; research R15).
- [X] T017 Extend the descriptor contract with `expectedDuration` (an optional short human phrase)
  and validate it in `backend/cls/FlightDeck/Domain/Descriptor.cls` and
  `scripts/build/check-descriptors.py`; declare it on compact, defragment and integrity-check
  (contracts/ui-pattern-delta.md §3.1).

### The two pattern additions (backend side)

- [X] T018 Write `backend/cls/FlightDeck/Async/Runner.cls`: fire an operation, read the handle from
  the **`LOCATION` header** (falling back to the body), poll through the dialect layer, and expose
  `{state, handle, lastValueAt, stale, message, value}`. The header names `/api/admin/v1/async-result`
  even on a v2 instance; that string must not leave `FlightDeck.Admin` (research R6, spec FR-047).
- [X] T019 Add the handle-from-header read to `backend/cls/FlightDeck/Admin/Client.cls` so the
  quirk lives in the dialect layer, and cover it in `backend/test/FlightDeck/Test/Dialect.cls`.
- [X] T020 Write `backend/cls/FlightDeck/Tasks/History.cls`: read `GET /v2/task/history` **once** and
  group by `TaskId`, returning per task the last result, the last duration and a bounded band. The
  platform ignores the `id` parameter and returns the whole instance history (research R7); a list of
  forty tasks must cost one request, not forty.
- [X] T021 Write `backend/cls/FlightDeck/Telemetry/Service.cls`: one reading of the whole cluster,
  reusing `FlightDeck.Vitals.Service` and the native host metrics rather than duplicating them
  (spec FR-046), with `available`/`reason` per instrument taken from the capability map and the seize
  table from `GET /v2/monitor/dashboard/system-resources` as a table, not an instrument
  (research R3).
- [X] T022 Add the routes `GET /v1/telemetry` and `GET /v1/async/:handle` to
  `backend/cls/FlightDeck/API/Router.cls` and to the served OpenAPI document, matching
  `contracts/flightdeck-api-004.openapi.json`; both are reads and stay available under safe mode.
- [X] T023 Compose the task list read in the domain layer: `GET /v2/tasks` plus one history read
  (T020) plus `GET /v2/task/manager` for the manager status, so a suspended manager is stated rather
  than read as every task being idle (data-model.md §3).

### Backend tests for the foundation

- [X] T024 [P] `backend/test/FlightDeck/Test/AsyncRunner.cls`: the state machine of
  `data-model.md` §4.2, including that a `Failed` or `Canceled` state keeps the last value and
  carries the platform's message, and that the handle is read from the header.
- [X] T025 [P] `backend/test/FlightDeck/Test/TaskHistory.cls`: grouping by `TaskId` from a fixture
  that mixes tasks, the bounded band, and the assertion that exactly one history read happens for a
  list of many tasks.
- [X] T026 [P] `backend/test/FlightDeck/Test/CapabilityPolicy.cls`: extend with the three declined
  storage writes, asserting each reason names the native path **and** states that creation is
  performed.
- [X] T027 [P] `backend/test/FlightDeck/Test/Coverage.cls`: assert that every one of the 126
  operations of both domains is either reachable or declined, mirroring `check-coverage.py` so the
  count is proven on the instance as well as in the build.

---

## Phase 3: User Story 1 — See the instance breathing (Priority: P1)

**Goal**: the instrument cluster, alive, with the asynchronous disk value that never blanks.

**Independent test**: open the domain on a running instance, watch for a minute, confirm the numbers
change, the series slides, the disk number never disappears, and the window survives the tab losing
and regaining focus.

- [X] T028 [US1] Write `frontend/src/pattern/async/useAsyncValue.ts` implementing
  `contracts/ui-pattern-delta.md` §2: the last known value stays in every state but a `Finished`
  carrying a new one; a value older than the interval is marked stale with the time it was read; a
  failure shows the platform's message beside the value; **no state renders a spinner where the
  number is**.
- [X] T029 [US1] Write `frontend/src/pattern/instruments/Series.tsx` — the canvas time series:
  1.5px stroke in `state-actual`, no axis, grid, legend, fill or gradient; sliding, with no per-point
  entry transition; **canvas, never a declarative SVG chart library** (docs/design.md §5,
  spec FR-015).
- [X] T030 [US1] Write `frontend/src/pattern/instruments/Instrument.tsx`: the 40px number, weight
  500, tabular numerals in `text-primary`; threshold changes colour and adds the state icon, and
  **never blinks or animates** (spec FR-017).
- [X] T031 [US1] Write `frontend/src/pattern/instruments/Cluster.tsx`: identical geometry across
  instruments, the bounded sliding window held here and nowhere else, the polling loop, pause on
  `document.hidden` and resume on focus preserving the window, and the visible mode and interval
  (spec FR-016, FR-018, FR-019, FR-020).
- [X] T032 [US1] Honour `prefers-reduced-motion` in the series: redraw in place without the sliding
  animation, numbers still updating (contracts/ui-pattern-delta.md §1 rule 8).
- [X] T033 [US1] Build the instruments section in `frontend/src/domains/system/Instruments.tsx`:
  the cluster fed by `GET /v1/telemetry`, the disk instrument bound to the asynchronous value, the
  seize table below the cluster, and disk-per-database occupancy marked with the home panel's
  thresholds (spec FR-013, FR-034).
- [X] T034 [US1] Render an unavailable instrument disabled **in place**, with the reason from the
  capability map, while the others keep updating (spec FR-021, RN-FD-32).
- [X] T035 [P] [US1] `frontend/e2e/instruments.spec.ts` — UC08 Gherkin 1: the instruments update
  continuously and keep a sliding window; assert the number changes across ticks and the window
  survives blur and focus.
- [X] T036 [P] [US1] `frontend/e2e/instruments.spec.ts` — UC08 Gherkin 2 and SC-004: hold the
  asynchronous answer and assert the number is never blank, never replaced by a loading indicator,
  and is marked stale with the time it was read.
- [X] T037 [P] [US1] `frontend/e2e/instruments.spec.ts`: after a reload the window starts empty —
  nothing is persisted (spec FR-018, SC-009).
- [X] T038 [P] [US1] Vitest unit for the sliding window in
  `frontend/src/pattern/instruments/window.test.ts`: bounded length, oldest dropped first, no
  unbounded growth over ten simulated minutes (SC-003).

---

## Phase 4: User Story 2 — Act on a process, only where the API says it is allowed (Priority: P1)

**Goal**: the process section, with controls the API decides and a termination that cannot take the
administrator's own session down.

**Independent test**: with one process whose `CanBeTerminated` is false and one where it is true,
confirm the first is disabled with its reason and never requested, the second demands the typed
identifier, and the current session's process is refused with an explanation.

- [X] T039 [US2] Extend `frontend/src/pattern/ActionBar.tsx` with a per-object disabled reason, so a
  control the API disabled **for this object** renders disabled with that reason and **never issues
  the request** (contracts/ui-pattern-delta.md §3.2, spec FR-029).
- [X] T040 [US2] Build the processes section in `frontend/src/domains/system/Processes.tsx`: filter,
  sort by consumption, the active count, and the four capability facts read from the **list**, so a
  row's controls are decided without opening it (research R5, spec FR-026, FR-028).
- [X] T041 [US2] Build the process inspector: namespace, user, routine, state, consumption, active
  time, login and escalated roles; a row whose `canBeExamined` is false shows the reason instead of
  an empty inspector (spec FR-027, research R5).
- [X] T042 [US2] Wire terminate, suspend and broadcast through the existing shared dry-run, at the
  grades T012 declared, with no new dialog anywhere (spec FR-043).
- [X] T043 [P] [US2] `backend/test/FlightDeck/Test/ProcessCapabilities.cls`: the enablement predicate
  reads the fact and nothing else, proven for all four fields **and** for the lock's `Removable`, so
  the rule is tested as a rule and a third instance needs no new test shape (plan, "A standing rule
  this feature establishes").
- [X] T044 [P] [US2] `backend/test/FlightDeck/Test/SelfProtection.cls`: extend with the session's own
  process — the block is affirmative, explained, and holds when the request bypasses the interface.
- [X] T045 [P] [US2] `frontend/e2e/processes.spec.ts` — UC08 Gherkin 3 and SC-005: a process the API
  marks as not terminable shows the disabled control with its reason, and **no request is issued**
  when it is clicked (assert on the network, not only on the DOM).
- [X] T046 [P] [US2] `frontend/e2e/processes.spec.ts` — UC08 Gherkin 4: terminating a permitted
  process requires typing its identifier.
- [X] T047 [US2] `frontend/e2e/processes.spec.ts` — A3 and SC-006: terminating the session's own
  process is refused, with the explanation, and the refusal also holds for a direct API call.
- [X] T048 [US2] Extend `scripts/dev/check-mutation-enforcement.sh` with the own-session refusal and
  with a terminate attempt from an armed tab, and probe both so the new checks can actually fail.

---

## Phase 5: User Story 3 — See what is scheduled, what failed, and run it again (Priority: P2)

**Goal**: the tasks domain, with the compact history band, on-demand runs and the instance-wide
manager.

**Independent test**: with a task whose history includes a failure, confirm the band is visible in the
list, the full message is in the detail, an on-demand run is followed to completion, and a second run
while the first is in flight is refused with the start time.

- [X] T049 [US3] Build the tasks section in `frontend/src/domains/tasks/Tasks.tsx`: state, last run,
  result, duration, next run and the compact recent-history band per row, from the composed read of
  T023 (spec FR-002, RN-FD-17).
- [X] T050 [US3] Add the filters by state, namespace and result (spec FR-003).
- [X] T051 [US3] Build the task inspector: the definition and the complete run history, with a failed
  run's complete message as first-class content (spec FR-004).
- [X] T052 [US3] Wire create, edit, suspend, resume and delete through the shared dry-run; deletion
  of a system task is disabled with its reason (spec FR-005, FR-007).
- [X] T053 [US3] Wire the on-demand run: follow it to completion, and when it does not finish inside
  the follow window show that it is still running and keep polling without blocking the interface
  (spec FR-006, FR-006a). Reuse `useAsyncValue` rather than writing a second polling loop.
- [X] T054 [US3] Report a refused concurrent run with the start time of the run in flight, taken from
  the history the list already has; never retry silently (spec FR-006).
- [X] T055 [US3] Build the task-manager singleton section with suspend and resume at reinforced
  grade, the text stating the effect on the whole instance, and the list stating that the manager is
  suspended rather than showing every task as idle (spec FR-008).
- [X] T056 [US3] Build the WQM categories section — list, inspector and full CRUD through the shared
  layer (spec FR-009).
- [X] T057 [US3] Build the asynchronous results section: state per result, with cancel, pause and
  resume where the platform offers them, on the **same** mechanism the disk instrument uses
  (spec FR-010, FR-011).
- [X] T058 [US3] Implement the logs correlation control on a failed run: navigate to
  `/logs/stream?taskId=<id>&taskName=<name>&from=<start−1m>&to=<end+1m>` (data-model.md §5,
  spec FR-041).
- [X] T059 [US3] Make the logs route's empty state read those parameters and state what it received,
  so the jump is verifiable end to end now and feature 005 consumes a contract that already exists
  (spec FR-041b).
- [X] T060 [P] [US3] `frontend/e2e/tasks.spec.ts` — UC07 Gherkin 1: the recent-history band is
  visible in the list without opening any detail.
- [X] T061 [P] [US3] `frontend/e2e/tasks.spec.ts` — UC07 Gherkin 2 and SC-012: the failed run shows
  the complete message, and the jump reaches the logs route with the task and window in the address,
  which the empty state then displays.
- [X] T062 [P] [US3] `frontend/e2e/tasks.spec.ts` — UC07 Gherkin 3 and SC-008: a second on-demand run
  is refused with the start time of the run in flight.
- [X] T063 [P] [US3] `frontend/e2e/tasks.spec.ts` — UC07 Gherkin 4: suspending the manager asks for
  reinforced confirmation whose text names the instance-wide effect.
- [X] T064 [US3] Add a demo task with a deliberately failing run to
  `backend/cls/FlightDeck/Install/Demo.cls` if the stock instance offers none with a failure, so the
  band, the message and the correlation have something real to show; skip with the platform's message
  if the creation is refused, as the wallet secret already does.

---

## Phase 6: User Story 4 — Read the rest of the instance (Priority: P3)

**Goal**: the eleven remaining sections, which carry most of the 102 operations and the "covers the
etc" argument. The descriptors already exist (Phase 2); this phase builds the screens and proves the
coverage.

**Independent test**: every section lists on a running instance, every inspector opens, and every one
of the 126 operations is either exercised or shown disabled with a reason.

- [X] T065 [P] [US4] Databases and directories sections in
  `frontend/src/domains/system/Databases.tsx`: list, inspector, the database ↔ directory link, the
  occupancy band, and mount, dismount, expand-volume and modify-size through the shared dry-run.
- [X] T066 [US4] Wire compact, defragment and integrity-check through `Async/Runner` — fired, then
  polled, **never** issued synchronously — with `expectedDuration` shown in the confirmation beside
  the consequence and repeated in the applying state (spec FR-037b, FR-037c).
- [X] T067 [US4] Render the three declined writes disabled with the policy reason and the native
  path, next to the creation controls that are enabled, so the asymmetry reads as a decision
  (spec FR-037a, FR-037d).
- [X] T068 [P] [US4] Namespaces section: the namespace, its three mapping families, copy-mappings and
  enable-interop, with creation performed and deletion declined.
- [X] T069 [P] [US4] Devices section: devices, subtypes and the device settings singleton.
- [X] T070 [P] [US4] Licence section: the key, the servers and key validation, with the key masked in
  the mutation layer and never in the read (spec FR-036).
- [X] T071 [P] [US4] Locks section: list and removal at reinforced grade, enabled only where
  `Removable` is true — the same rule as the process controls (spec FR-035, research R11).
- [X] T072 [P] [US4] Web sessions section, with an empty state that says the instance has none rather
  than a broken screen (research R12).
- [X] T073 [P] [US4] ECP section: data servers, application servers, the SSL connections with
  authorize and reject, and the settings singleton.
- [X] T074 [P] [US4] External language servers section, including start and stop and the activity
  read.
- [X] T075 [P] [US4] DocDB section, with the empty state of T072's shape.
- [X] T076 [P] [US4] File-system access purposes section, including paths, with the same empty state.
- [X] T077 [US4] `frontend/e2e/system.spec.ts`: every section lists and every inspector opens; the
  three empty sections state that the instance has none; the declined writes show their reason and
  the native path (spec FR-033, quickstart §12).
- [X] T078 [US4] `frontend/e2e/system.spec.ts`: one long storage operation (integrity-check) states
  its expected duration in the confirmation, is fired rather than awaited, and leaves the domain
  usable while it runs (SC-011).

---

## Phase 7: Polish & cross-cutting concerns

- [X] T079 Extend the pattern catalog fixture in `backend/cls/FlightDeck/Fixture/PatternCatalog.cls`
  and `frontend/src/fixtures/PatternCatalog.tsx` to exercise **both** additions: an instrument that
  crosses a threshold, one that is unavailable with a reason, and an asynchronous value moving
  through `Running`, `Finished`, `Failed` and stale — behaviour the shipped domains cannot force on a
  live instance.
- [X] T080 [P] `frontend/e2e/pattern.spec.ts`: assert the catalog's instrument and asynchronous
  cases, including that no state renders a spinner where a number is.
- [X] T081 [P] Extend `frontend/e2e/audit.spec.ts` to a session that terminates a process and uploads
  a licence key, then sweep the trail export, the copied curl, browser storage, cookies and the IRIS
  logs — the licence key must appear in none of them, and in no error body (spec FR-036a).
- [X] T082 [P] Design review of both domains in both themes against `docs/design.md` §4, §5 and §7,
  with the cluster checked against §5 point by point: geometry identical, number 40px weight 500
  tabular, 1.5px stroke, no axis or grid or legend, no blinking on threshold. Record it in
  `specs/004-tasks-system/checklists/design-review.md`.
- [X] T083 [P] Accessibility pass with axe on the instruments, processes, tasks and system sections,
  in both themes, including the canvas's accessible name and a text alternative for each series.
- [X] T084 Run `scripts/build/check-coverage.py` against the finished domains and fix any operation
  it names; the count must be exactly 126 (SC-001).
- [X] T085 Rebuild `frontend/dist`, run every static gate — `check:tokens`, `check:dialect`,
  `check:mutation-boundary`, `check:secrets`, `check-descriptors`, `check-coverage`, `check-dist`,
  `check-generated` — and fix what they name. `check:dialect` must stay green with the `LOCATION`
  quirk confined to the dialect layer.
- [X] T086 Limited-mode matrix on IRIS 2026.1: extend `frontend/e2e/limited.spec.ts` with one
  telemetry read and one system write decided by the capability map, update the unavailable and
  declined counts, and re-run the `limited` project on port 52791.
- [X] T087 Full matrix on fresh installs — IRIS CE 2026.2, IRIS for Health 2026.2 and IRIS CE 2026.1 —
  one install at a time: the whole backend suite, every Playwright project, both enforcement scripts
  and all static gates. Write `verification/feature-004-signoff.md` recording the three versions, as
  features 002 and 003 did.
- [X] T088 Run `specs/004-tasks-system/quickstart.md` §1 to §13 end to end and fix any step that does
  not work as written.

---

## Dependencies & Execution Order

- **Phase 1 (setup)** blocks everything; T005's coverage check is what keeps the 126 honest.
- **Phase 2 (foundational)** blocks all four stories. It deliberately carries US4's breadth: the
  descriptors of every section land here, before the signature screens.
- **US1** depends on T018–T022 (async runner, telemetry service, routes).
- **US2** depends on T008 (process facts), T012 (descriptors) and T016 (self-protection); T039 is a
  pattern change and must land before T040.
- **US3** depends on T020 and T023 (the grouped history and the composed list) and reuses T028.
- **US4** depends on T013 (its descriptors) and, for T066, on T018 and T017.
- **Polish** depends on all stories. T086–T088 are the matrix and sign-off and come last.

## Parallel opportunities

- Phase 1: T003 and T004 together.
- Phase 2: T009 and T010 together; T024–T027 together once their subjects exist.
- US1: T035–T038 together once T033 is in.
- US2: T043–T046 together once T040 and T042 are in.
- US3: T060–T063 together once T049–T058 are in.
- US4: T065, T068–T076 are eleven independent sections and are the widest parallel block in the
  feature.
- Polish: T080–T083 together.

## Implementation strategy

**MVP**: Phase 1 + Phase 2 + US1 gives the signature screen on a live instance, which is the image the
product is judged by. But note the ordering rule: because Phase 2 already carries every descriptor,
reaching the MVP does **not** leave US4 unbuilt — it leaves US4's screens unbuilt over descriptors
that already exist and are already counted by the coverage check.

**If the feature has to shrink**: take depth out of US1 and US2 — fewer instrument refinements, a
simpler process filter — before reducing the US4 surface. US4 is most of the 102 operations and the
whole "covers the etc" argument; the coverage check (T005, T084) is what makes any such reduction
visible instead of silent.
