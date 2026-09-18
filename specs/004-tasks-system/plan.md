# Implementation Plan: Tasks and Operating System Management

**Branch**: `004-tasks-system` | **Date**: 2026-09-18 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/004-tasks-system/spec.md`

## Summary

Two domains, 126 official operations, built on the pattern and the shared mutation layer that
features 002 and 003 already delivered. The work divides into four blocks: the instrument cluster
(canvas, sliding window, polling), processes (capability fields decide the controls, termination is
maximum grade and self-protected), tasks (the composed list with its history band, on-demand runs,
the instance-wide manager), and the eleven remaining sections of the operating system domain, which
carry most of the operations and the whole "covers the etc" argument.

Only two things are new in the pattern: the instrument cluster and the asynchronous value. Everything
else is composition of what exists. Three operations are declined on every version — truncate, delete
database, delete namespace — with a message that names what FlightDeck does do, why it declines, and
the native path, so the asymmetry against creation reads as a decision.

The design rests on probes of a live instance, not on the specification alone. Four of them changed
it: capability fields arrive on the **list** (so the controls are decided without opening a row) and are
not confined to processes — the rule below covers every schema that carries one; the asynchronous
handle arrives in a **`LOCATION` header** that names `/v1` even on v2;
`GET /v2/task/history` **ignores its `id`** and returns the whole instance history (so the band is one
grouped read, not one read per task); and `SystemResourcesStats` is the seize table, which is a
table, not a fourth instrument. See [research.md](./research.md).

## Technical Context

**Language/Version**: ObjectScript (IRIS 2026.1 and 2026.2) on the backend; TypeScript 5 with React
18 and Vite 5 on the frontend.

**Primary Dependencies**: the official SysAdmin API v2 (`/api/admin/v2`) through
`FlightDeck.Admin.Client`, with the v1 dialect for 2026.1; no new runtime dependency. The instrument
cluster is drawn with the platform's own 2D canvas — **no chart library is added**.

**Storage**: none. Metric history lives in the browser session and is never persisted (RN-FD-21).

**Testing**: `%UnitTest` on the backend; Vitest for pure frontend units; Playwright for the screens,
with new projects `tasks`, `system`, `instruments` and `processes`.

**Target Platform**: IRIS CE and IRIS for Health CE, 2026.2 and 2026.1, served by IRIS itself.

**Project Type**: web application inside an IRIS instance (backend classes + versioned `frontend/dist`).

**Performance Goals**: the cluster answers one reading per interval in a single request; a one-second
interval with five instruments stays responsive for ten minutes with a bounded window (SC-002,
SC-003).

**Constraints**: no code outside `FlightDeck.Admin` consults the version or dialect; mutations are
refused server-side under safe mode; secrets are masked by the existing layer; `frontend/dist` is
versioned and must be rebuilt.

**Scale/Scope**: 126 official operations (24 tasks, 102 system), 22 entity types, ~60 mutation
descriptors, 13 sections across two domains, 2 new pattern modules.

## Constitution Check

*GATE: passed before Phase 0; re-checked after Phase 1 design.*

| Principle | How this feature satisfies it | Gate |
|---|---|---|
| I. Official API first | Every one of the 126 operations is called through the official endpoint. The native providers reused (host CPU and memory, disk per database, namespace reads on v1) exist only where the API has no route on that version. No ObjectScript reimplementation is added. | Review + `check-generated` |
| II. Delegated identity | No credential is stored, cached or logged; the telemetry endpoint runs in the session that asked. | `audit` project |
| III. Capabilities from the spec | Instrument availability, section availability and control availability all read the capability map. The three declined writes go through `FlightDeck.Capability.Policy`, not a hand-coded test. | `check:dialect` |
| IV. Safe mode per tab | Every mutation of both domains is refused server-side while armed, telemetry is a read and stays available. | `check-safe-mode-enforcement.sh` |
| V. Diff before every mutation | One shared dry-run and trail; no new dialog. Terminating a process is maximum grade with the typed identifier. | `check:mutation-boundary` |
| VI. Secrets are write-only | The licence key typed on upload is a `secretField`; what the platform returns on a read is shown as the platform returns it (research R13). | `check:secrets`, `secrets` project |
| VII. Self-protection | Terminating the session's own process is blocked on the server, as a declared rule over facts. | `check-mutation-enforcement.sh` |
| VIII. Graceful degradation | The asynchronous value never clears a number; an unavailable instrument keeps its place with its reason; three legitimately empty sections get an empty state, not a broken screen. | `instruments` project |
| IX. The API decides | **Rule, not a list of cases**: wherever an official schema exposes a capability field over an object, that field governs the corresponding control. `CanBeTerminated`, `CanBeSuspended`, `CanReceiveBroadcast`, `CanBeExamined` and the locks' `Removable` are instances of it. Nothing is inferred and no request is issued for a disabled control. | `processes` project |
| X. design.md is binding | The cluster follows §5 exactly, including canvas over SVG, identical geometry and no blinking on threshold. | `check:tokens`, `contrast`, design review |
| XI. English everywhere | UI text, comments and commits in English. | Review |

**No violation to justify.** The two pattern additions are extensions of the shared pattern and its
contract, not local components, which is what the constitution asks for when the pattern falls short.

## Project Structure

### Documentation (this feature)

```text
specs/004-tasks-system/
├── plan.md              # This file
├── spec.md              # Final, three clarifications answered
├── research.md          # Phase 0: R1–R16, four findings that changed the design
├── data-model.md        # Phase 1: entity types, mutations, telemetry, async, correlation
├── quickstart.md        # Phase 1: §0–§13 end-to-end validation
├── contracts/
│   ├── flightdeck-api-004.openapi.json   # /telemetry, /async/{handle}, composed task list
│   └── ui-pattern-delta.md               # the two pattern additions and their rules
└── checklists/requirements.md
```

### Source code

```text
backend/cls/FlightDeck/
├── Domain/EntityTypes.cls          # + 22 entity types (tasks 4, system 18)
├── Domain/Facts.cls                # + Process(), Lock(), DatabaseDir(), Task()
├── Domain/LinkProviders.cls        # + task runs, database↔directory, namespace↔mappings
├── Mutation/Descriptors.cls        # + ~60 descriptors, grades and self-protection as data
├── Mutation/SelfProtection.cls     # + the session's own process rule
├── Capability/Policy.cls           # + the three declined storage writes, with native paths
├── Async/Runner.cls                # NEW: fire, read the LOCATION handle, poll, expose state
├── Tasks/History.cls               # NEW: one history read, grouped by TaskId
├── Telemetry/Service.cls           # NEW: one reading of the cluster, reusing Vitals and Native
└── API/Router.cls                  # + GET /v1/telemetry, GET /v1/async/:handle

frontend/src/
├── pattern/instruments/            # NEW: Cluster, Instrument, canvas series, window, focus
├── pattern/async/                  # NEW: useAsyncValue, states, staleness
├── domains/tasks/                  # sections: tasks, WQM categories, async results
├── domains/system/                 # sections: instruments, processes, databases and dirs,
│                                   #   namespaces, devices, licence, locks, web sessions, ECP,
│                                   #   external language servers, DocDB, FS access purposes
└── mutation/DryRun.tsx             # + expectedDuration beside the consequence

frontend/e2e/
├── instruments.spec.ts             # cluster, window, focus, async disk
├── processes.spec.ts               # capability fields, maximum grade, self-protection
├── tasks.spec.ts                   # band, failure, concurrent run, manager, correlation jump
└── system.spec.ts                  # the eleven remaining sections and the declined writes
```

## Phases

### Phase 0 — Research (done)

[research.md](./research.md) resolves every unknown, including the two shapes the specification does
not declare, and records the four findings that changed the design. No `NEEDS CLARIFICATION` remains.

### Phase 1 — Design and contracts (done)

[data-model.md](./data-model.md), [contracts/](./contracts/) and [quickstart.md](./quickstart.md).
Constitution re-checked above after design: unchanged, no violation.

### Phase 2 — Tasks (`/speckit.tasks`, not this command)

Ordering follows the user stories, with one deliberate departure from the default reading of
priorities, stated here so the task list inherits it:

> **US4 is not optional.** It holds databases and directories, namespaces, devices, licence, locks,
> web sessions, ECP, external language servers, DocDB and file-system access purposes — most of the
> 102 operations of the domain and the whole "covers the etc" argument of the brief. If the feature
> has to shrink, depth comes out of US1 and US2 first, which already stand on a finished pattern;
> the P3 surface is the last thing to cut, not the first.

Practical consequence for sequencing: the foundational block (entity types, facts, descriptors for
all 22 types, the capability policy entries) lands **before** the signature work, so US4's breadth is
already in place while US1 and US2 are polished. The instrument cluster and the asynchronous value
come next, because processes and the disk instrument both depend on them.

## A standing rule this feature establishes

**Capability fields govern controls, wherever they appear.** When an official schema carries a field
that states what may be done to that object, that field decides the control's enabled state, and the
interface never infers permission from type, user or state (RN-FD-34). This is a rule about schemas,
not a list of endpoints: `CanBeTerminated`, `CanBeSuspended`, `CanReceiveBroadcast` and
`CanBeExamined` on a process, and `Removable` on a lock, are the instances this feature happens to
meet. A capability field found in any other schema — in these domains or a later feature — is treated
the same way, with no new decision and no new code path: it becomes a fact on the entity and a
predicate on the control.

Two consequences for the task list:

- The descriptor mechanism carries the rule, so adding a domain that has capability fields costs a
  declaration, not a component.
- The check that proves it is generic: no request may be issued for a control whose capability fact
  is false, asserted on processes and on locks, and written so a third instance needs no new test
  shape.

## Complexity Tracking

No constitutional deviation is requested. Two risks are tracked instead:

| Risk | Why it matters | Mitigation |
|---|---|---|
| The cluster at one second could drift into jank as sections are added | The signature screen is judged on feeling alive | One request per interval for the whole cluster; canvas with a bounded window; the `instruments` project asserts responsiveness over ten minutes (SC-003) |
| 126 operations could quietly become 110 | Partial coverage is a defect, not a scope choice | A build check counts the operations of both domains against `docs/api-coverage.md` and fails when one is neither implemented nor declined (SC-001) |
