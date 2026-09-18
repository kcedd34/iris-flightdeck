# Implementation Plan: Unified Log Stream

**Branch**: `005-unified-logs` | **Date**: 2026-09-18 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/005-unified-logs/spec.md`

## Summary

Five sources, one line. Audit and journal records come from the official API — both asynchronously,
through the helper feature 004 built. The messages log and the alerts log are read from disk,
backwards, in bounded pages. The interoperability event log is read with SQL, per namespace. They are
merged into one normalised event, filtered, followed live, correlated to the entities they name, and
exported.

This is the only mandatory axis of the brief with no official API coverage, so it is also the one
where the work is visible. It is a normalisation problem, and the two rules that keep normalisation
honest are structural here: every event carries its original record, and where the original cannot be
recovered the gap is stated rather than filled.

The design rests on probes of a live instance, not on the documentation. Six of them shaped it: the
messages log states its own severity level, which makes the normalised severity a mapping rather than
a judgement; `%Stream.FileCharacter.MoveTo` makes bounded backwards reading possible; a stock instance
writes **no** alerts log, so that source's normal state is "absent, with the reason"; the
interoperability log is SQL, per namespace, with its own level column; journal records answer 202 and
carry no user or severity; and an audit record's own three-part key travels in every row, so the
original record is one read away. See [research.md](./research.md).

## Technical Context

**Language/Version**: ObjectScript (IRIS 2026.1 and 2026.2) on the backend; TypeScript 5 with React 18
and Vite 5 on the frontend.

**Primary Dependencies**: the official SysAdmin API v2 through `FlightDeck.Admin.Client`;
`%Stream.FileCharacter` for the file sources; `%SQL.Statement` for the interoperability source;
`FlightDeck.Async.Runner` (feature 004) for the two asynchronous official reads. No new runtime
dependency, on either side.

**Storage**: none. No event is persisted by the portal; the live window lives in the browser session.

**Testing**: `%UnitTest` on the backend, including a file fixture with known content for the reader;
Vitest for the pure client pieces; Playwright for the screen, in a new `logs` project.

**Target Platform**: IRIS CE and IRIS for Health, 2026.2 and 2026.1, served by IRIS itself.

**Project Type**: web application inside an IRIS instance.

**Performance Goals**: a page of the stream answers within the same budget as any other domain read;
a 100 MB log file is paged without the serving process growing with it (SC-003).

**Constraints**: no whole-file read at any size; no version or dialect test outside `FlightDeck.Admin`;
mutations refused server-side under safe mode; `frontend/dist` versioned and rebuilt.

**Scale/Scope**: 14 official operations, 5 sources, 4 entity types, 6 mutation descriptors, 1 domain
with 3 sections, 1 new backend subsystem (the reader, the normalisers and the merge).

## Constitution Check

*GATE: passed before Phase 0; re-checked after Phase 1 design.*

| Principle | How this feature satisfies it | Gate |
|---|---|---|
| I. Official API first | Audit and journal are read through the official operations. The three native providers exist **because the API offers nothing** for those sources — which is the exception the constitution names, and the reason this axis is the differentiator. Each native provider is documented as such. | Review + `check-coverage` |
| II. Delegated identity | No credential is stored or logged. The stream shows what the session may read: a source refused for this user says so. | `audit` project |
| III. Capabilities from the spec | Each source's availability comes from the capability map for its operations; the file and SQL sources declare their own availability from what the instance answered, never from a version. | `check:dialect` |
| IV. Safe mode per tab | Reads stream while armed; every journal and audit-event write is refused server-side under safe mode. | `check-safe-mode-enforcement.sh` |
| V. Diff before every mutation | Journal settings, switch file, switch directory, integrity check and the audit event writes all go through the one shared dry-run and trail. | `check:mutation-boundary` |
| VI. Secrets are write-only | No source may surface a secret: an event whose text carries one the portal knows is masked by the existing layer, and the `secrets` sweep covers the stream. | `check:secrets`, `secrets` project |
| VII. Self-protection | Nothing here disables the portal; the destructive journal operations are graded and state their instance-wide effect. | Review |
| VIII. Graceful degradation | The defining behaviour of this feature: a source that cannot be read is named with its reason and the others keep streaming; an unrecoverable original is stated, not hidden. | `logs` project |
| IX. The API decides | Where an object refuses an operation the rule is `refusedWhen` with its reason, as the pattern's README now states. | `check-descriptors` |
| X. design.md is binding | The stream uses the shipped list and inspector; severity is shown with the state tokens and no new colour; nothing blinks. | `check:tokens`, `contrast` |
| XI. English everywhere | UI text, comments and commits in English. | Review |

**No violation to justify.** The three native providers are not a reimplementation of an official
endpoint: there is no official endpoint for messages, alerts or the interoperability log, and
Principle I names exactly this case (RN-FD-30).

## Project Structure

### Documentation (this feature)

```text
specs/005-unified-logs/
├── plan.md              # This file
├── spec.md              # Final, three clarifications answered
├── research.md          # Phase 0: R1–R12, six findings that shaped the design
├── data-model.md        # Phase 1: the event, the five sources, the cursor, the merge
├── quickstart.md        # Phase 1: §0–§13 end-to-end validation
├── contracts/
│   ├── flightdeck-api-005.openapi.json   # /logs/events, /logs/event/raw, /logs/export
│   └── log-sources.md                    # what a source must provide, and never do
└── checklists/requirements.md
```

### Source code

```text
backend/cls/FlightDeck/
├── Logs/Reader.cls          # NEW: backwards paged file reading, bounded, rotation-aware
├── Logs/Event.cls           # NEW: the normalised event and its severity scale
├── Logs/Source.cls          # NEW: the source contract and registry
├── Logs/Sources/Audit.cls   # NEW: official, asynchronous
├── Logs/Sources/Journal.cls # NEW: official, asynchronous
├── Logs/Sources/Messages.cls, Alerts.cls   # NEW: file sources, sharing the reader
├── Logs/Sources/Interop.cls # NEW: SQL, per namespace, capped
├── Logs/Stream.cls          # NEW: the merge, the cursor and the suppression count
├── Domain/EntityTypes.cls   # + logs/event, logs/journal-file, logs/journal-settings, logs/audit-event
├── Mutation/Descriptors.cls # + 6 descriptors (journal writes, audit event writes)
└── API/Logs.cls             # NEW: GET /v1/logs/events, /v1/logs/event/raw, /v1/logs/export

frontend/src/
├── domains/logs/Stream.tsx      # the unified list, filters, live follow, suppression note
├── domains/logs/EventInspector.tsx  # normalised fields, the original record, the jumps
├── domains/logs/Journal.tsx     # files, settings and the four journal operations
├── domains/logs/AuditEvents.tsx # the definitions, with their writes
└── domains/registry.tsx         # + the three logs sections

frontend/e2e/logs.spec.ts        # UC09 Gherkin 1–4, plus export, correlation and suppression
```

## Phases

### Phase 0 — Research (done)

[research.md](./research.md). No `NEEDS CLARIFICATION` remains; the three spec-level decisions were
answered before planning and are recorded in the spec.

### Phase 1 — Design and contracts (done)

[data-model.md](./data-model.md), [contracts/](./contracts/) and [quickstart.md](./quickstart.md).
Constitution re-checked above after design: unchanged, no violation.

### Phase 2 — Tasks (`/speckit.tasks`, not this command)

Two ordering notes the task list should inherit:

> **The reader and the source contract come first.** Four of the five sources depend on them, and the
> one rule that cannot be retrofitted — never read a file whole — lives there. A source built before
> the contract is a source that will be rewritten.

> **Availability is not an afterthought.** Every source lands with its unavailable path in the same
> task as its happy path, because on a stock Community instance the alerts source and, on 2026.1, the
> journal source are *normally* unavailable. If that path is built later, the screen an evaluator
> opens first is the one that was tested last.

## Complexity Tracking

No constitutional deviation is requested. One deviation from the brief is declared in the spec and
repeated here so it is not discovered later: **the severity scale carries a fifth value**, `unknown`,
outside the ordering (spec FR-003a to FR-003c). docs/prd.md §7 lists four. Two of the five sources
state no level at all, and both alternatives — mapping to `info`, or deriving from the text — assert
something no one said. The deviation is the smaller error, and it is visible in the filter rather
than hidden in a mapping.

Three risks are tracked:

| Risk | Why it matters | Mitigation |
|---|---|---|
| The file reader is the one piece where a mistake is expensive at scale | A whole-file read on a 10 GB journal directory would take the instance down, and it is the kind of bug that only appears in production | Bounded window and line cap in the reader itself, not in its callers; a backend test with a generated large file; SC-003 measures it |
| Five sources, five formats, one screen | Normalisation quietly losing a field is the classic failure of this kind of viewer | `raw` mandatory and checked; a test per source asserting every normalised field against a known record; the unparsable line kept as an event |
| Live follow at high volume | A viewer that freezes during an incident is worse than no viewer | Bounded window, per-refresh limit, suppression stated, pause on hidden tab — all four asserted in the `logs` project |
