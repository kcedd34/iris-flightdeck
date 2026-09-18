# Feature Specification: Tasks and Operating System Management

**Feature Branch**: `004-tasks-system`

**Created**: 2026-09-18

**Status**: Draft

**Input**: User description: "Tasks and operating system management. Scope: UC07 (tasks) and UC08 (operating system) from docs/prd.md Section 7, with their Gherkin acceptance criteria verbatim as the definition of done; full official coverage of the 126 operations assigned to these domains in docs/api-coverage.md; reuse of the domain screen pattern and the shared mutation layer from features 002 and 003; canvas time series; asynchronous disk; capability fields govern controls; terminating a process is maximum grade and self-protected."

## Overview

Two domains complete the "etc" of the brief. **Tasks** (UC07) is what is scheduled, what failed and
why, and running one on demand. **Operating system** (UC08) is the instrument cluster and the live
state of the instance: processes, databases and their directories, namespaces, devices, licence,
locks, web sessions, ECP, external language servers, DocDB and file-system access purposes.

Together they are 126 of the 273 official operations — the largest block in the product. Partial
coverage is a defect, not a scope choice: every one of the 126 is either implemented or explicitly
declined with a reason that names what to use instead.

Nothing here invents interaction. Both domains are built from the screen pattern of feature 002 and
the single shared mutation layer of features 002 and 003: one dry-run, one trail, one confirmation
ladder, entity types and mutations declared as descriptors. The two things this feature adds to the
pattern are the instrument cluster (a canvas time series with a sliding window held in the client)
and the fire-and-poll asynchronous value, which the disk instrument and the asynchronous results
section share.

## Clarifications

### Session 2026-09-18

- Q: How does the portal deliver continuous telemetry, given the official API offers no streaming
  endpoint? → A: **Polling only, with the mode in use and the interval always visible.** The official
  API offers no streaming endpoint, so a FlightDeck-owned SSE layer would be polling in disguise on
  the server: it would add a long-lived connection behind the web gateway without changing anything
  an administrator can observe. The absence of SSE is a decision with a reason, not an omission, and
  it is stated on screen as the mode in use.
- Q: Which storage operations does FlightDeck perform, and which does it decline? → A: **The same
  rule as feature 003: decline only where there is no recovery and no safe test path.** Declined with
  a reason and the native path: truncate, database deletion and namespace deletion. Performed through
  the shared mutation layer: mount, dismount, expand-volume, modify-size, compact, defragment and
  integrity-check. The three long ones — compact, defragment and integrity-check — run through the
  asynchronous result pattern, never as a synchronous request, and their confirmation states the
  expected duration as well as the risk: an operation that takes minutes, presented as synchronous,
  reads as a frozen application.
- Q: UC07 Gherkin 2 requires a jump from a failed run to the logs of that period, but logs are
  feature 005 and that route keeps its empty state. → A: **Write and test the correlation contract
  now.** The control navigates to the logs route carrying the task and the time window in the URL,
  and the empty state of feature 005 shows the correlation it received. Feature 005 then consumes
  parameters that already exist instead of inventing the contract and coming back to change this
  feature.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See the instance breathing (Priority: P1)

An administrator opens the operating system domain and lands on the instrument cluster. CPU, memory
and disk read as large numbers with a short trailing time series under each, updating continuously.
The disk instrument's value comes from an asynchronous task; while a refresh is in flight the last
known number stays on screen. Below the cluster, the process list shows what is running, sorted by
consumption.

**Why this priority**: This is the signature screen of the whole product and the image that carries
the cockpit metaphor. It is also the one screen that must look alive rather than refreshed.

**Independent Test**: Open the domain on a running instance, watch for a minute, and confirm the
numbers change, the series slides, the disk number never disappears, and the window survives the tab
losing and regaining focus.

**Acceptance Scenarios** (UC08 Gherkin, verbatim):

1. **Given** the instrument panel is open, **When** time passes, **Then** the instruments must update
   continuously **And** keep a sliding window of recent history.
2. **Given** the disk space metric arrives through an asynchronous task, **When** a refresh is in
   progress, **Then** the last known value must stay visible **And** never be replaced by a loading
   indicator.

Supporting scenarios:

3. **Given** the instance does not offer a metric (A5), **When** the cluster renders, **Then** that
   instrument is disabled with its reason **And** the others keep updating.
4. **Given** the browser tab loses focus (A2), **When** it regains focus, **Then** telemetry resumes
   **And** the accumulated window is preserved.
5. **Given** a database is above the occupancy threshold (A4), **When** the cluster renders, **Then**
   it is marked there **And** aggregated on the home panel.

---

### User Story 2 - Act on a process, only where the API says it is allowed (Priority: P1)

The administrator filters the process list, opens one, and sees namespace, user, routine, state,
consumption, active time and roles. Terminate, suspend and broadcast are enabled or disabled by the
capability fields the API returned with the process itself. Terminating asks for the process
identifier to be typed, and the process running the administrator's own session cannot be terminated
at all.

**Why this priority**: This is the feature's destructive surface. Getting the enablement from the
API rather than from a guess, and protecting the session's own process, is what makes the domain
safe to ship.

**Independent Test**: With one process whose `CanBeTerminated` is false and one where it is true,
confirm the first is disabled with its reason and never requested, the second demands the typed
identifier, and the current session's process is refused with an explanation.

**Acceptance Scenarios** (UC08 Gherkin, verbatim):

3. **Given** the API reports that a process cannot be terminated, **When** the list is shown, **Then**
   the terminate control must appear disabled with the reason.
4. **Given** the user requests the termination of a process that is allowed, **When** the confirmation
   is shown, **Then** typing the process identifier must be required.

Supporting scenarios:

5. **Given** the target process is the one running the current session (A3), **When** termination is
   proposed, **Then** it is blocked and explained, on the server as well as on the screen.
6. **Given** a process the API marks as not suspendable or not able to receive a broadcast, **When**
   the inspector renders, **Then** those controls are disabled with the reason and the operation is
   never attempted (A6).

---

### User Story 3 - See what is scheduled, what failed, and run it again (Priority: P2)

The administrator opens the tasks domain. Each task shows state, last run, result, duration, next run
and a compact band of recent history, so an intermittent failure is visible without opening anything.
Opening a failed run shows the complete error message. The administrator runs a task on demand and
follows it to completion; a task already running refuses a concurrent run and says when the current
one started.

**Why this priority**: Tasks are the second domain of this feature and are independently valuable:
they answer "what broke overnight" without leaving the portal.

**Independent Test**: With a task that has a history including a failure, confirm the band is visible
in the list, the full message is in the detail, an on-demand run is followed to completion, and a
second run while the first is in flight is refused with the start time.

**Acceptance Scenarios** (UC07 Gherkin, verbatim):

1. **Given** a task has a run history, **When** the list is shown, **Then** the recent history band
   must be visible without opening the detail.
2. **Given** the last run failed, **When** the user opens the run detail, **Then** the complete error
   message must be shown **And** there must be a direct jump to the logs of that period.
3. **Given** a task is running, **When** the user tries to run it on demand, **Then** the concurrent
   run must be prevented, with the start time reported.
4. **Given** the user suspends the task manager, **When** the confirmation is shown, **Then**
   reinforced confirmation must be required **And** the effect on the whole instance explained.

Supporting scenarios:

5. **Given** a system task (A3), **When** it is inspected, **Then** inspection and suspension are
   offered **And** deletion is disabled with its reason.
6. **Given** an on-demand run that does not finish within the follow window (A4), **When** the window
   elapses, **Then** progress is shown and polling continues **And** the interface stays usable.

---

### User Story 4 - Read the rest of the instance (Priority: P3)

The remaining sections of the operating system domain — databases and their directories, namespaces,
devices, licence, locks, web sessions, ECP, external language servers, DocDB and file-system access
purposes — are readable and, where FlightDeck performs the write, editable through the same pattern:
list, inspector, links, dry-run.

**Why this priority**: This is the bulk of the 126 operations and the difference between "covers the
etc" and "covers part of it", but no single section of it is a signature moment.

**Independent Test**: Every section lists on a running instance, every inspector opens, and every
operation of the 126 is either exercised or shown disabled with a reason that names the native path.

**Acceptance Scenarios**:

1. **Given** the operating system domain, **When** the section tabs render, **Then** every section
   named in UC08 is present, in the order the use case gives.
2. **Given** an operation this instance does not offer, **When** its control renders, **Then** it is
   disabled with the version reason from the capability map.
3. **Given** an operation FlightDeck declines on every version, **When** its control renders, **Then**
   it is disabled with the policy reason and the native path, and never looks like missing work.

---

### Edge Cases

- A metric the edition does not expose: the instrument is disabled with its reason; the cluster keeps
  its geometry and the other instruments keep updating.
- The asynchronous disk task fails or is cancelled: the last known value stays, marked stale with the
  time it was read and the platform's message; no spinner replaces the number.
- Telemetry runs for hours: the sliding window is bounded and held in the session only; nothing is
  persisted, and a reload starts a new window (RN-FD-21).
- A process disappears between listing and action: the platform's own answer is shown; the list
  refreshes; nothing is retried silently.
- A task is deleted while its detail is open: the dry-run detects the changed state and recomputes,
  as the shared layer already does.
- The task manager is suspended: tasks still list, and the screen states that the manager is
  suspended rather than showing every task as merely idle.
- A run history is empty: the band shows "no runs recorded" rather than an empty rectangle.
- The instance reports a shape for `SystemResourcesStats` or `SharedMemoryUsage` that the probe did
  not see: unknown fields are ignored and the known ones render; no field is invented.
- A section is offered but returns a platform defect (for example a 500): the section shows the
  platform's message and the rest of the domain keeps working, and the defect is recorded in
  `verification/README.md`.

## Requirements *(mandatory)*

### Functional Requirements

#### Tasks domain (UC07, 24 operations)

- **FR-001**: The tasks domain MUST present three sections: tasks, Work Queue Manager categories and
  asynchronous results.
- **FR-002**: The task list MUST show, per task, its state, last run, result, duration, next run and
  a compact band of recent history, so an intermittent failure is visible without opening the detail
  (RN-FD-17).
- **FR-003**: The list MUST be filterable by state, namespace and result.
- **FR-004**: A task inspector MUST show the definition and the complete run history, and a run's
  detail MUST carry the complete error message of a failed run.
- **FR-005**: Creating, editing, suspending, resuming and deleting a task MUST go through the shared
  dry-run and be recorded in the session trail (RN-FD-27).
- **FR-006**: An on-demand run MUST be followed until it completes, and MUST be refused while a run
  of the same task is in flight, stating when the current run started (RN-FD-18).
- **FR-006a**: When a run does not complete within the follow window, the screen MUST show that it is
  still running and continue polling without blocking the interface.
- **FR-007**: A system task MUST be inspectable and suspendable, with deletion disabled and the
  reason stated.
- **FR-008**: Suspending or resuming the task manager MUST be a reinforced-grade confirmation whose
  text states the effect on the whole instance.
- **FR-009**: Work Queue Manager categories MUST be listable, inspectable, creatable, editable and
  deletable through the same pattern.
- **FR-010**: Asynchronous results MUST be listed with their state, and MUST offer cancel, pause and
  resume where the platform offers them, through the shared mutation layer.
- **FR-011**: The asynchronous result mechanism MUST be one implementation, shared by this section
  and by the disk instrument of UC08.

#### Instrument cluster (UC08, RN-FD-19 to RN-FD-21)

- **FR-012**: The operating system domain MUST open on the instrument cluster.
- **FR-013**: The cluster MUST cover at least CPU, memory, disk per database, processes and devices;
  the absence of any of these is a requirement failure (RN-FD-19).
- **FR-014**: Each instrument MUST render a large primary number and a short trailing time series,
  with the exact geometry docs/design.md §5 specifies: the number in tabular numerals, the series
  drawn as a 1.5px stroke with no axis, grid, legend, fill or gradient.
- **FR-015**: The time series MUST be drawn on canvas. A declarative SVG chart library MUST NOT be
  used: at a one-second refresh with several series it degrades visibly (docs/design.md §5).
- **FR-016**: The series MUST slide continuously, with no entry transition per point.
- **FR-017**: Crossing a threshold MUST change the number's colour and add a state icon. It MUST NOT
  blink or animate.
- **FR-018**: The sliding window MUST live in the client session only. The portal MUST NOT persist
  any metric history (RN-FD-21).
- **FR-019**: Telemetry MUST pause when the tab loses focus and resume when it regains focus,
  preserving the accumulated window.
- **FR-020**: Telemetry MUST be delivered by polling. The refresh mode in use and its interval MUST
  be visible, and the interval MUST be configurable (RN-FD-20).
- **FR-020a**: The portal MUST NOT implement a streaming transport of its own. The official API
  offers no streaming endpoint, and a FlightDeck-owned one would poll the platform on the server
  while holding a long-lived connection behind the web gateway, with no observable difference for the
  administrator. The screen states the mode in use, which is polling, and the interval.
- **FR-021**: A metric this instance or edition does not expose MUST render as a disabled instrument
  with its reason, leaving the rest of the cluster live (RN-FD-32).

#### Asynchronous values (RN-FD-32)

- **FR-022**: Disk free space MUST be obtained by firing the platform's asynchronous task and polling
  its result.
- **FR-023**: While a refresh is in flight, the last known value MUST remain on screen. The number
  MUST NOT be cleared and MUST NOT be replaced by a loading indicator.
- **FR-024**: A value older than its refresh interval MUST be marked as stale, with the time it was
  read, rather than hidden.
- **FR-025**: When the asynchronous task fails or is cancelled, the platform's own message MUST be
  shown beside the last known value.

#### Processes (UC08, RN-FD-34, RN-FD-22, RN-FD-12)

- **FR-026**: The process list MUST be filterable and sortable by consumption, and MUST state how
  many processes are active.
- **FR-027**: A process inspector MUST show namespace, user, routine, state, consumption, active time
  and login and escalated roles.
- **FR-028**: Wherever an official schema exposes a capability field over an object, that field
  governs the corresponding control, and the interface MUST NOT infer permission from type, user or
  state (RN-FD-34). The process fields `CanBeTerminated`, `CanBeSuspended`, `CanReceiveBroadcast` and
  `CanBeExamined`, and the lock field `Removable`, are instances of this rule, not exceptions to it:
  a capability field found in any other schema of these domains is treated the same way, without a
  new decision.
- **FR-029**: A control the API disables MUST show the reason and MUST NOT issue the request.
- **FR-030**: Terminating a process MUST always be maximum-grade confirmation, requiring the process
  identifier to be typed. There MUST be no exception for any profile (RN-FD-22).
- **FR-031**: Terminating the process that runs the signed-in session MUST be blocked, on the server
  as well as in the interface, with an explanation (RN-FD-12).

#### The rest of the operating system domain (UC08)

- **FR-032**: The domain MUST present the sections UC08 names: instruments, processes, databases and
  directories, namespaces, devices, licence, locks, web sessions, ECP, external language servers,
  DocDB and file-system access purposes.
- **FR-033**: Every one of the 102 operating system operations MUST be either implemented or declined
  with a reason; the same applies to the 24 task operations. No operation may be silently absent.
- **FR-034**: A database above the occupancy threshold MUST be marked in its section and aggregated on
  the home panel.
- **FR-035**: Locks MUST be listable and removable, with removal at reinforced grade.
- **FR-036**: The licence section MUST show the key and the licence servers, and MUST offer key
  validation. The licence key is masked by the **mutation layer**, not on the read: the official read
  returns it to any administrator, so hiding it on screen would be theatre. The key typed on upload
  MUST be a secret field of the write, so the dry-run, the trail and its export show only that it
  changed.
- **FR-036a**: The licence key MUST NOT reach a backend log or the body of an error, on any path,
  including a failed write and a platform refusal.
- **FR-037**: FlightDeck MUST perform, through the shared mutation layer and at the grade the risk
  deserves, these storage operations: mount, dismount, expand-volume, modify-size, compact,
  defragment and integrity-check. Creating a database or a namespace is also performed.
- **FR-037a**: FlightDeck MUST decline, on every version, with the reason and the native path:
  truncating a database directory, deleting a database and deleting a namespace. These are the
  operations with no recovery from the portal and no safe test path within the schedule; declining is
  the same rule feature 003 applied to the encryption writes. A declined operation counts as covered
  and MUST NOT look like missing work.
- **FR-037d**: Because creating a database or a namespace IS performed, each refusal message MUST say
  so, state why the deletion is declined, and name the native path in the platform's management
  portal. The asymmetry between creating and deleting MUST read as a decision, not as a defect.
- **FR-037b**: Compact, defragment and integrity-check MUST run through the asynchronous result
  pattern — fired, then polled — and MUST NOT be issued as a synchronous request. Their confirmation
  MUST state the expected duration as well as the risk: an operation that takes minutes, presented as
  synchronous, reads as a frozen application.
- **FR-037c**: While one of those long operations is running, the screen MUST show it is in progress
  with what is known about it, and the rest of the domain MUST stay usable.

#### Undeclared shapes

- **FR-038**: `SystemResourcesStats` and `SharedMemoryUsage` MUST be typed from a recorded probe of a
  running instance, not from the specification, which declares no shape for them.
- **FR-039**: The probe and the resulting shape MUST be recorded in `verification/`, with the version
  it was observed on.
- **FR-040**: No field may be invented. A field the probe did not observe MUST NOT be rendered, and an
  unexpected field MUST be ignored rather than breaking the screen.

#### Logs correlation (UC07 Gherkin 2, RN-FD-26)

- **FR-041**: A failed run MUST offer a direct jump to the logs of its period. The control navigates
  to the logs route carrying the task and the time window in the address.
- **FR-041a**: The correlation contract — which parameters travel and what they mean — MUST be
  written and tested in this feature, not in the one that consumes it.
- **FR-041b**: Until logs are built, the logs route's empty state MUST display the correlation it
  received, so the jump is verifiable end to end now. Feature 005 then reads parameters that already
  exist rather than inventing the contract and changing this feature.

#### Reuse of the delivered pattern

- **FR-042**: Both domains MUST be composed from the existing screen pattern: list, inspector, links,
  action bar, object form and the section tabs, since each domain holds several entity types.
- **FR-043**: Every mutation MUST go through the single shared dry-run, confirmation ladder and trail.
  No per-domain confirmation dialog, diff renderer or trail write may be added.
- **FR-044**: New entity types and mutations MUST be declared as descriptors — facts, markers, link
  providers, grades and self-protection rules as data.
- **FR-045**: Anything the pattern cannot express MUST be a change to the pattern and its contract,
  not a local component; the instrument cluster and the asynchronous value are the two declared
  additions.
- **FR-046**: The native providers already delivered for host CPU and memory, disk per database and
  namespace reads MUST be reused, not duplicated.

#### Cross-cutting invariants

- **FR-047**: No code outside the dialect layer may consult the instance version or dialect;
  availability MUST come from the capability map only.
- **FR-048**: Mutations MUST be refused server-side under safe mode; the interface alone is not the
  guard.
- **FR-049**: Secret material in this domain MUST be masked by the existing mutation layer and never
  displayed, returned or logged.
- **FR-050**: Every build gate MUST stay green, including the token, dialect, mutation-boundary,
  secret, descriptor, generated-artefact and dist checks.
- **FR-051**: Platform defects encountered MUST be documented in `verification/README.md` and worked
  around, never silently masked.

### Key Entities

- **Task**: a scheduled unit of work, with a definition, a state, a next run and a history of runs;
  may be a system task, which restricts deletion.
- **Task run**: one execution, with start, duration, result and, when it failed, a complete message.
- **Task manager**: the instance-wide scheduler, which can be suspended and resumed.
- **Work Queue Manager category**: a named category of queued work.
- **Asynchronous result**: a fired platform task whose value arrives later; has a state, a value when
  it completes, and controls to cancel, pause or resume.
- **Instrument**: one metric rendered as a number plus a sliding series; has a threshold, a state and
  a reason when it is unavailable.
- **Process**: a running process, with identity, consumption, roles and the capability fields that
  decide which controls are enabled.
- **Database and database directory**: stored data and the directory that holds it, with size, free
  space and growth limit.
- **Namespace**: a namespace and its global, package and routine mappings.
- **Device, device subtype, licence key, licence server, lock, web session, ECP server, external
  language server, DocDB, file-system access purpose**: the remaining configured objects of the
  domain, each with a list, a detail and the writes the platform offers.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All 126 operations are accounted for: each is exercised by a test or shown disabled
  with a reason, and a check proves the count.
- **SC-002**: An administrator opening the operating system domain sees live numbers within two
  seconds of the screen appearing, on a cold session.
- **SC-003**: With telemetry running for ten minutes at a one-second interval, the interface stays
  responsive and memory does not grow without bound; the window is bounded.
- **SC-004**: During a disk refresh, the number on screen is never blank and never replaced by a
  loading indicator, verified by an automated test that holds the asynchronous answer.
- **SC-005**: A process the API marks as not terminable is never the subject of a request, verified
  by inspecting the requests the screen issues.
- **SC-006**: Terminating any process requires typing its identifier, and terminating the session's
  own process is refused by the server even when the request is issued directly.
- **SC-007**: An intermittent task failure is visible in the list without opening any detail.
- **SC-008**: A second on-demand run of a running task is refused with the start time of the run in
  flight.
- **SC-009**: No metric history survives a reload: after reloading, the window starts empty.
- **SC-010**: The full matrix passes on IRIS CE 2026.2, IRIS for Health 2026.2 and IRIS CE 2026.1,
  with every project either green or skipped with a stated reason.
- **SC-011**: A long storage operation never blocks the interface: after confirming a compact,
  defragment or integrity-check, the screen stays usable and reports progress, and the confirmation
  that preceded it stated how long the operation is expected to take.
- **SC-012**: A jump from a failed run reaches the logs route carrying the task and the time window,
  and what arrives is displayed, verified by an automated test that reads the address and the screen.

## Assumptions

- The screen pattern and the shared mutation layer delivered by features 002 and 003 are stable and
  are reused unchanged, except for the two declared pattern additions (instrument cluster and
  asynchronous value).
- The instrument thresholds follow the values the home panel already uses, so the two screens cannot
  disagree about what counts as a warning.
- Telemetry defaults to a one-second refresh on the instrument cluster and stops when the tab is
  hidden; the interval is a session preference, not a stored setting. Polling is the only transport
  (FR-020a), so "the mode in use" always reads as polling with its interval.
- Where the v1 dialect does not offer an operation (namespace writes are already withheld there), the
  section renders disabled with the reason, exactly as in feature 003.
- The demo installer already creates the demo tasks used by the task scenarios; no new fixture is
  required for them.
- Logs remain feature 005; this feature adds no log reading of any kind.
