# Feature Specification: Unified Log Stream

**Feature Branch**: `005-unified-logs`

**Created**: 2026-09-18

**Status**: Draft

**Input**: User description: "Unified log stream. UC09 from docs/prd.md §7, Gherkin verbatim as the definition of done. The only mandatory contest axis with no official API coverage: audit and journal come from the official API, while messages.log, alerts and the interoperability event log are native providers. Five sources under one normalised schema, with `raw` mandatory everywhere; backwards paged file reading with a line limit; live follow with rate limiting; jump from an event to the related entity; consume the correlation contract of feature 004; export the filtered result; a source unavailable by permission or version is stated with its reason while the others keep working."

## Overview

Five sources, one line. Audit records and journal records arrive through the official API; the
instance's messages log, its alerts and the interoperability event log have no official endpoint and
are read by FlightDeck itself. They appear under one schema — timestamp, source, severity, namespace,
process, user, message, raw — filtered, followed live, and exported.

**This is the only mandatory axis of the brief with no official API coverage**, which is exactly why
it is the feature that distinguishes the submission: it is the one where the work cannot be delegated
to the platform. It is, in practice, a normalisation problem, and normalisation is where information
gets quietly lost. Two rules keep it honest: every event carries its original record (`raw`), and
where the original cannot be recovered the gap is stated rather than filled in.

Nothing here invents interaction. The screen is the domain pattern of feature 002; every mutation
goes through the single shared dry-run and trail of features 002 and 003; the asynchronous helper of
feature 004 reads what the platform answers asynchronously; availability comes from the capability
map, never from a version test.

## Clarifications

### Session 2026-09-18

- Q: Where do the audit **event definitions** live, given feature 003 already owns the auditing
  settings in the security domain? → A: **An "Audit events" section of the logs domain.** This is not
  an inconsistency with feature 003: the auditing family divides by the nature of the object, not by
  the verb. The audit state and the audit records are *data*, and data stays in security; the
  definitions of what gets captured are *configuration of an investigation*, and they belong where
  the investigating happens. Someone reading the stream who notices an event is missing changes what
  is captured without leaving the screen. `PUT` and `DELETE` still go through the shared mutation
  layer, wherever they are delivered.
- Q: What severity does an event get when its source states none? → A: **A fifth value, `unknown`,
  outside the severity ordering.** Mapping it to `info` would assert "informational" about something
  nobody classified, and deriving it from the text would be wrong silently — a line reading "no
  errors found" would become an error. Two conditions come with it: the minimum-severity filter
  states explicitly how it treats `unknown` rather than excluding it in silence, and the deviation
  from the four-value scale in docs/prd.md is recorded here with its reason.
- Q: Which namespaces does the interoperability event log cover? → A: **Every interoperability-enabled
  namespace, with a declared cap, and what the cap left out stated on screen** — the same rule the
  column privileges panel and the certificate validity reads already use. Reading only the session's
  namespace would leave the source empty on a Community instance used for evaluation, which is
  exactly where it will be looked at.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - One line for every subsystem (Priority: P1)

An administrator investigating an incident opens the log stream. Events from audit, the journal, the
messages log, alerts and interoperability appear together, most recent first, under one set of
fields. Each event can be opened to see the original record exactly as its source wrote it.

**Why this priority**: This is the feature. Without the single normalised line there is no unified
stream, only five viewers.

**Independent Test**: With at least two sources producing events, confirm both appear in one list
under the same fields, ordered by time, and that each opens to show its original record.

**Acceptance Scenarios** (UC09 Gherkin, verbatim):

1. **Given** events come from sources with different formats, **When** the unified stream is shown,
   **Then** they must all appear under the same field schema **And** each event must give access to
   its original record.

Supporting scenarios:

2. **Given** an event whose original record cannot be recovered (A4), **When** it is opened, **Then**
   the normalised fields are shown **And** the missing original is stated explicitly.
3. **Given** a filter that matches nothing (A3), **When** the result is empty, **Then** the screen
   proposes widening the period or lowering the minimum severity.

---

### User Story 2 - Follow it live, without drowning (Priority: P1)

The administrator turns on live follow. New events appear at the top without reloading. When the
instance produces more than the screen can show, the most recent are kept and the screen states how
many were suppressed.

**Why this priority**: An incident is watched while it happens. A stream that either freezes or
floods is useless at the moment it matters most.

**Independent Test**: With a source producing events faster than the display rate, confirm new events
appear at the top, the list stays responsive, and the number suppressed is stated.

**Acceptance Scenarios** (UC09 Gherkin, verbatim):

2. **Given** the user turns on live follow, **When** new events occur, **Then** they must appear at
   the top without reloading the screen.

Supporting scenarios:

4. **Given** the live volume is above the limit (A2), **When** events are suppressed, **Then** the
   most recent are kept **And** how many were suppressed is stated.

---

### User Story 3 - A source that is not there says why (Priority: P2)

Auditing is disabled on the instance, or this session may not read the journal, or the version does
not offer an operation. The stream keeps working with the sources that answer, and each absent source
is named with its reason — and, where the instance can enable it, where to do so.

**Why this priority**: A silent absence reads as "nothing happened", which is the most dangerous
thing a log viewer can say.

**Independent Test**: With auditing disabled, confirm the other sources still stream and the audit
source is listed as unavailable with the platform's reason.

**Acceptance Scenarios** (UC09 Gherkin, verbatim):

3. **Given** auditing is disabled on the instance, **When** the stream is shown, **Then** the other
   sources must keep working **And** the audit source must be flagged with the reason.

Supporting scenarios:

5. **Given** a source refused by permission (A1), **When** the stream is shown, **Then** it is named
   with the refusal **And** the others keep streaming.

---

### User Story 4 - From an event to the thing it happened to (Priority: P2)

An event names a process, a namespace, a user or a task. The administrator opens it and jumps
straight to that entity's inspector in the domain that owns it. Arriving from a failed task run in
the tasks domain works the other way round: the address carries the task and the time window, and the
stream opens filtered on them.

**Why this priority**: This closes the graph between logs and every other domain, and it is what
turns "I found the error" into "I found what it happened to".

**Independent Test**: From an event carrying a process identifier, confirm the jump opens that
process; and from a failed task run, confirm the stream opens filtered on that task and window.

**Acceptance Scenarios** (UC09 Gherkin, verbatim):

4. **Given** an event has a process identifier, **When** the user opens that event, **Then** there
   must be a direct jump to the corresponding process.

Supporting scenarios:

6. **Given** the address carries a task and a time window (feature 004's correlation contract),
   **When** the stream opens, **Then** it is already filtered on them **And** says so.
7. **Given** a filtered result, **When** the user exports it, **Then** the export carries exactly
   what the filter selected, including each event's original record.

---

### Edge Cases

- A log file is rotated or truncated while being read: the reader reports what it could read and says
  the file changed, rather than mixing two files silently.
- A log file is very large: it is read backwards in bounded pages and never loaded whole.
- A line does not parse: it becomes an event whose message is the line itself, with the parse gap
  stated; it is never dropped.
- Two sources report the same moment: ordering is stable, and equal timestamps keep a deterministic
  order rather than shuffling between refreshes.
- The instance's time zone differs from the reader's: timestamps are shown in the instance's zone,
  and the zone is stated.
- Live follow runs for a long time: the client-side window is bounded, nothing is persisted, and a
  reload starts clean.
- A source answers asynchronously (audit records do): the last known page stays on screen while the
  next one is fetched.
- No source is available at all: the screen says so, listing each source and its reason, and offers
  no empty list that could be mistaken for silence.

## Requirements *(mandatory)*

### Functional Requirements

#### The normalised schema (RN-FD-23, RN-FD-24)

- **FR-001**: Every event MUST carry the same fields: timestamp, source, severity, namespace,
  process, user, message and raw. A field a source does not provide is absent, never invented.
- **FR-002**: Severity MUST be normalised to one scale: info, warning, error, fatal.
- **FR-003**: Each source's mapping onto that scale MUST be recorded, so a reader can tell what an
  "error" meant in its original terms.
- **FR-003a**: An event whose source states no severity MUST show `unknown`, a fifth value outside
  the severity ordering. FlightDeck MUST NOT map it to `info` (that asserts a classification nobody
  made) and MUST NOT derive it from the message text (that is wrong silently: "no errors found" is
  not an error).
- **FR-003b**: This is a deliberate deviation from the four-value scale in docs/prd.md §7, recorded
  with its reason: the scale has no value for "the source did not say", and the alternatives both
  invent a fact.
- **FR-003c**: The minimum-severity filter MUST state how it treats `unknown` — it is not ordered
  against info, warning, error and fatal, so it cannot be above or below a threshold. An event with
  unknown severity MUST NOT disappear from a filtered view without the filter saying that it does.
- **FR-004**: `raw` MUST be present on every event of every source: normalisation never destroys
  information.
- **FR-005**: Where the original record cannot be recovered, the event MUST state that explicitly and
  still show the normalised fields (A4). It MUST NOT be silently omitted.
- **FR-006**: An unparsable line MUST become an event carrying the line as its message, with the gap
  stated. Nothing is dropped for being unreadable.

#### The five sources

- **FR-007**: The stream MUST cover five sources: audit records, journal records, the instance's
  messages log, its alerts, and the interoperability event log.
- **FR-008**: Audit records and journal records MUST be read through the official API.
- **FR-009**: The messages log, the alerts log and the interoperability event log MUST be read by
  FlightDeck's own providers, because the official API offers no operation for them.
- **FR-010**: Each source MUST declare its own availability and reason, and the stream MUST keep
  working with the sources that answer (A1, RN-FD-32).
- **FR-011**: Where auditing is disabled on the instance, the audit source MUST be listed with that
  reason and with the path to enable it (A5).
- **FR-011a**: The interoperability source MUST read every namespace where interoperability is
  enabled, up to a declared cap, and MUST state on screen which namespaces it covered and which the
  cap left out. A namespace the session may not read is named as unread, not skipped in silence.

#### Reading files (RN-FD-25)

- **FR-012**: Log files MUST be read backwards from the end, in pages, with a line limit per page.
- **FR-013**: A whole log file MUST NEVER be read into memory, at any size.
- **FR-014**: The reader MUST state when a file changed under it (rotation or truncation) rather than
  mixing content from two files.
- **FR-015**: Paging MUST be stable: asking for the next page returns older events, never repeats or
  skips because the file grew meanwhile.

#### Filtering, live follow and export

- **FR-016**: The stream MUST be filterable by source, severity, period and free text.
- **FR-017**: Live follow MUST add new events at the top without reloading the screen.
- **FR-018**: Live follow MUST be rate limited: when events arrive faster than the limit, the most
  recent are kept and the number suppressed is stated (A2).
- **FR-019**: Live follow MUST pause when the tab is hidden and resume on focus, as the instrument
  cluster does.
- **FR-020**: The client-side window MUST be bounded, and no event history may be persisted by the
  portal.
- **FR-021**: An empty result MUST propose widening the period or lowering the minimum severity (A3).
- **FR-022**: The filtered result MUST be exportable, and the export MUST carry exactly what the
  filter selected, including each event's `raw`.
- **FR-023**: The export MUST state, in the file itself, which filters produced it and which sources
  were unavailable at the time.

#### Correlation (RN-FD-26)

- **FR-024**: An event carrying a process, namespace, user or task MUST offer a jump to that entity's
  inspector in the domain that owns it.
- **FR-025**: The stream MUST consume the correlation contract written in feature 004: a task
  identifier and a time window arriving in the address open the stream already filtered on them.
- **FR-026**: When the stream opens from such an address, it MUST state what it was filtered on, so
  the filter is visible rather than implicit.
- **FR-027**: A jump MUST be offered only where the target can be identified; an event that names a
  process the instance no longer reports says so rather than offering a dead link.

#### Journal and audit configuration

- **FR-028**: Journal files, journal settings and the journal operations that change the instance
  (switch file, switch directory, integrity check) MUST be presented as configuration, separate from
  the record stream they produce.
- **FR-029**: Every journal write — settings, switch file, switch directory — MUST go through the
  shared mutation layer at the grade its risk deserves. Switching the journal file or directory
  MUST state the instance-wide effect.
- **FR-030**: The journal integrity check MUST run through the asynchronous helper, never as a
  synchronous request, and its confirmation MUST state the expected duration.
- **FR-031**: The audit event definitions (`GET /v2/security/audit/event`, `GET .../events`,
  `PUT .../event`, `DELETE .../event`) MUST be delivered as an **"Audit events" section of the logs
  domain**, and their writes MUST go through the shared mutation layer. This settles feature 003's
  FR-021f.
- **FR-031a**: The split from the security domain's auditing section MUST be stated where a reader
  would otherwise read it as an inconsistency: the family divides by the nature of the object, not by
  the verb. State and records are data and stay in security; the definitions of what is captured are
  configuration of an investigation and live where the investigating happens. The two sections MUST
  link to each other.
- **FR-032**: All 14 official operations assigned to the logs domain MUST be implemented or declined
  with a reason; the coverage check MUST count them.

#### Reuse and invariants

- **FR-033**: The screen MUST be composed from the existing pattern — list, inspector, filters,
  section tabs — with no new confirmation dialog, diff renderer or trail write.
- **FR-034**: Sources, their severity mappings and their correlation fields MUST be declared as data,
  in the same descriptor style the other domains use.
- **FR-035**: Availability MUST come from the capability map only; no code outside the dialect layer
  may consult the instance version or dialect.
- **FR-036**: Where a rule disables a control because the object itself refuses it, it MUST be
  declared as `refusedWhen` with its reason, never as a permission test.
- **FR-037**: Secret material MUST be masked by the existing mutation layer, and no log event may be
  used to expose one: an event whose text contains a credential the portal knows MUST be masked the
  same way.
- **FR-038**: Every build gate MUST stay green, including the now strict coverage check.

### Key Entities

- **Log event**: one normalised record — timestamp, source, severity (info, warning, error, fatal or
  unknown), namespace, process, user, message, raw — plus the correlation targets it offers.
- **Source**: one origin of events, with its availability, its reason when unavailable, and the
  severity mapping it uses.
- **Page**: a bounded slice of one source, read backwards, with the cursor that asks for the next.
- **Journal file**: a file the instance writes, with its own records and the operations that manage
  it.
- **Audit event definition**: the configuration that decides what auditing records.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Events from at least two different sources appear in one list under identical fields,
  ordered by time.
- **SC-002**: Every event in the stream carries its original record, or states why it could not be
  recovered; a check proves there is no third case.
- **SC-003**: A log file of at least 100 MB is browsed without the portal reading it whole, verified
  by measuring what the reader consumes.
- **SC-004**: With a source producing more events than the display limit, the screen keeps the most
  recent and states how many were suppressed.
- **SC-005**: With auditing disabled, the other sources still stream, and the audit source names the
  reason and the way to enable it.
- **SC-006**: From an event carrying a process, the administrator reaches that process's inspector in
  one action.
- **SC-007**: An address carrying a task and a time window opens the stream filtered on them, stated
  on screen.
- **SC-008**: An exported result contains exactly the events the filter selected, each with its
  original record, and names the filters and the unavailable sources.
- **SC-009**: All 14 official logs operations are implemented or declined with a reason, proven by
  the coverage check.
- **SC-010**: The full matrix passes on IRIS CE 2026.2, IRIS for Health 2026.2 and IRIS CE 2026.1,
  with every project green or skipped with a stated reason.
- **SC-011**: An event whose source states no severity is visible as `unknown`, and a filtered view
  that would hide it says so; no event acquires a severity nobody assigned.
- **SC-012**: The interoperability source names the namespaces it read and any the cap or a refusal
  left out; on an instance with no interoperability-enabled namespace it says that, rather than
  showing an empty list.

## Assumptions

- The screen pattern, the shared mutation layer, the asynchronous helper and the capability map are
  reused unchanged; anything they cannot express is a change to the pattern and its contract.
- Live follow polls, as the instrument cluster does: the official API offers no streaming endpoint,
  and feature 004 recorded why a FlightDeck-owned one would add nothing an administrator can observe.
  The mode and interval are visible.
- Timestamps are shown in the instance's time zone, which is stated on screen, because an event's
  time is a fact about the instance and not about the reader.
- The journal's own records remain read through the official API on every version that offers it; on
  a version that does not, the source is unavailable with the reason already recorded for the journal
  in feature 001.
- The messages log and the alerts log are files the instance writes in its manager directory; their
  location is read from the instance rather than assumed.
- No log content is persisted by the portal, and no metric or event history survives a reload.
