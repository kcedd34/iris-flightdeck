# Implementation Plan: Packaging and Submission

**Branch**: `006-packaging-submission` | **Date**: 2026-09-18 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/006-packaging-submission/spec.md`

## Summary

The portal is finished. This feature makes it legible in ten minutes to someone who has never seen
it, and submittable.

Three deliverables and one discipline. The deliverables are the **README** in the required
ten-element order, a **demo driver** that runs the portal through the demonstration at its real
speed, and a **clean-environment verification** on both Community images. The discipline is that
nothing in the README is written from memory: every number, every claim and every command is read
from a running instance, and the ones that can be checked mechanically get a gate, like every other
claim in this project.

That last point is the plan's spine. A README is the easiest artifact in a repository to let drift,
and this one carries counts that change whenever the capability map does. So the ten required
elements become a **contract with a build gate** (`check-readme.py`), the instrument-cluster image
becomes a **capture the test suite produces** rather than a screenshot someone took once, and the
operation counts are **read from the portal** at the moment the README is finalised and asserted by
the gate afterwards.

## Technical Context

**Language/Version**: Markdown for the deliverable; Python 3 for the new build gate, matching the
existing `scripts/build/*.py`; TypeScript with Playwright for the asset capture and the demo driver,
matching `frontend/e2e/`.

**Primary Dependencies**: none new. The capture and the driver use the Playwright already installed;
the gate uses the standard library, like `check-coverage.py`.

**Storage**: none.

**Testing**: the new `check-readme.py` gate, wired into `scripts/build/check-generated.sh` beside the
other gates; a Playwright project that produces the documentation images and fails if a screen it
photographs no longer exists.

**Target Platform**: IRIS CE and IRIS for Health Community images, 2026.2 and 2026.1.

**Project Type**: documentation, packaging and two small tools inside the existing repository.

**Performance Goals**: SC-001 — a cold reader reaches a signed-in portal with content in under ten
minutes, of which the install is the bulk. Nothing here may make the install slower.

**Constraints**: English throughout; no claim that is not checked against a running instance; the
demo driver never accelerates, skips or simulates a wait (FR-019a); the three author actions — the
idea URL, the recording, the final human read — must not block anything else.

**Scale/Scope**: one README rewritten to a ten-element order, one new build gate, one image-capture
project, one demo script and driver, two clean installs recorded, one conformance checklist closed.

## Constitution Check

*GATE: passed before Phase 0; re-checked after Phase 1 design.*

| Principle | How this feature satisfies it | Gate |
|---|---|---|
| I. Official API first | Nothing is implemented here. The README states which operations are declined and why, and the declined list is read from `FlightDeck.Capability.Policy`, not retyped. | `check-readme` |
| II. Delegated identity | The README documents the default Community account as local-evaluation-only, and states that no credential is stored on any path. The capture and the driver sign in the same way the e2e suite does and store nothing. | `check:secrets`, review |
| III. Capabilities from the spec | The README's operation counts are read from the running portal's own capability summary on each supported version — never counted by hand, never hard-coded in prose the gate cannot check. | `check-readme` |
| IV. Safe mode per tab | The demo shows safe mode being turned off deliberately, per tab, because that is the product. The driver never bypasses it. | `logs`/`demo` projects |
| V. Diff before every mutation | The demo's second shot is the dry-run, before anything is applied — the contest checklist requires exactly this. | Review |
| VI. Secrets are write-only | No capture may photograph a secret. The image capture runs the existing credential sweep over what it produces. | `check:secrets`, `audit` project |
| VII. Self-protection | Untouched. | — |
| VIII. Graceful degradation | The README states what limited mode is, in operations, so a reduced instance reads as a property of that instance. The verification record proves it on 2026.1. | Review |
| IX. The API decides | Untouched. | — |
| X. design.md is binding | The captured images are the shipped screens in a shipped theme; nothing is staged, mocked or restyled for the photograph. | Review |
| XI. English everywhere | The README, the demo script, the new gate and every comment are English. `docs/contest.md` stays in its original language as a working document; its evidence pointers are English. | Review |

**No violation to justify.** One thing is worth stating rather than discovering: `docs/contest.md` is
in Portuguese. Principle XI covers UI text, code comments and commit messages, not the author's own
working notes. It is not a deliverable and is not published.

## Project Structure

### Documentation (this feature)

```text
specs/006-packaging-submission/
├── plan.md              # This file
├── spec.md              # Final, three clarifications answered
├── research.md          # Phase 0: R1–R8
├── data-model.md        # Phase 1: the three records this feature produces
├── quickstart.md        # Phase 1: §1–§9 end-to-end validation
├── contracts/
│   └── readme-contract.md    # The ten elements, in order, as checkable statements
└── checklists/requirements.md
```

### Source code and artifacts

```text
README.md                        # rewritten to the ten-element order
docs/img/instruments.png         # NEW: the above-the-fold asset, captured
docs/img/dry-run.png             # NEW: the impact analysis, captured
docs/demo-script.md              # NEW: the shot-by-shot plan, with what each shot proves
scripts/build/check-readme.py    # NEW: the README contract as a gate
frontend/e2e/docs.spec.ts        # NEW: captures the documentation images from the running portal
frontend/e2e/demo.spec.ts        # NEW: the demo driver, at the portal's real speed
verification/install-runs.md     # + the two clean-environment runs for this submission
verification/cold-read.md        # NEW: the agent passes, the questions, and the human pass
docs/contest.md §7               # every line closed with evidence or a named author action
```

## Phases

### Phase 0 — Research

[research.md](./research.md). Eight questions, each answered against the running portal or the
repository rather than from memory:

- **R1** Where do the README's numbers come from, and which of them can a gate check?
- **R2** What actually fits above the fold on the hosting platform, and what does that allow?
- **R3** How is the instrument cluster captured so the image is reproducible and cannot go stale?
- **R4** What does "at the portal's real speed" mean for a driver, concretely, and what would violate it?
- **R5** What is the cold-read protocol, so an agent pass and a human pass produce comparable results?
- **R6** What exactly is declined, and what is the third category the word "declined" does not cover?
- **R7** Does the IPM path work as the README describes it, on an instance that is not the container?
- **R8** Which statements in today's README are already false?

### Phase 1 — Design and contracts

[contracts/readme-contract.md](./contracts/readme-contract.md) turns the ten requirements into
statements a gate can check: which must appear, in which order, and which carry a value that must
match the portal. [data-model.md](./data-model.md) fixes the shape of the three records this feature
produces — verification run, cold-read pass, checklist line — so they are comparable between runs
rather than prose. [quickstart.md](./quickstart.md) validates the whole thing end to end.

### Phase 2 — Tasks (`/speckit.tasks`, not this command)

Two ordering notes the task list should inherit:

> **Research before prose.** The README's numbers, the declined list and the false statements in
> today's text are findings, not drafting decisions. Writing first and checking afterwards produces a
> README that is edited twice and believed once.

> **The gate lands with the README, not after it.** A contract written after the artifact it
> describes is a description, not a contract. `check-readme.py` is written against the contract and
> must fail on today's README before the rewrite makes it pass.

## Complexity Tracking

No constitutional deviation is requested.

Four risks are tracked:

| Risk | Why it matters | Mitigation |
|---|---|---|
| The README goes stale the first time the capability map changes | It carries counts, version claims and a declined list; a wrong number in the front door is worse than no number, because it is the one thing a judge can check in seconds | `check-readme.py` reads the declined operations structurally and asserts the prose against them; the counts are labelled with the version they were read from |
| A captured image outlives the screen it photographs | An image of a screen that no longer exists is a silent lie in the most visible place | The images are produced by a Playwright project against the running portal; if the screen or its test id is gone, the capture fails rather than leaving the old file |
| The demo driver drifts into a highlight reel | A demo that hides latency is discovered at the evaluator's first install, and then everything else in the submission is doubted | FR-019a is a hard rule: no accelerated, skipped or simulated wait. The driver performs the same operations the e2e suite performs, and the script states the expected elapsed time of each shot so a recording that is too fast is visibly wrong |
| The cold read grades itself | The author cannot read their own README cold, and an agent that helped write it is no better | The agent passes run with no project context and only the README; the recorded result is the human pass, by a reader who knows IRIS and not FlightDeck (FR-024a) |

**Three author actions are open by design** and are tracked in the conformance checklist, not hidden
in a task: the Ideas Portal URL, the recording of the video, and the final human cold read. The
README carries the idea line in final wording so that closing it is a URL paste, and every other line
of the checklist is closed without them.
