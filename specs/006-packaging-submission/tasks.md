---

description: "Task list for feature 006: packaging and submission"
---

# Tasks: Packaging and Submission

**Input**: Design documents from `/specs/006-packaging-submission/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/readme-contract.md](./contracts/readme-contract.md).

**Tests**: test tasks are included. The README's checkable claims get a build gate, and the images
and the demo get Playwright projects, because this project's rule is that a claim which can be
checked mechanically is checked mechanically.

**Organization**: by user story. US1 is the stranger who installs (P1), US2 the judge who checks
claims (P1), US3 the demo (P2), US4 clean-environment verification (P2), US5 the checklist (P3).

**Two ordering rules this list inherits from the plan.**

1. **Research before prose.** The numbers, the declined list and the false statements in today's
   README are findings, not drafting decisions. Phase 2 closes them before a word is rewritten.
2. **The gate lands with the README, not after it.** `check-readme.py` is written against the
   contract and **must fail on today's README** before the rewrite makes it pass. A contract written
   after the artifact it describes is a description.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: US1, US2, US3, US4, US5
- Paths are repository-relative and exact

---

## Phase 1: Setup

- [X] T001 Create the feature directory with spec, plan, research, data model, contract and
  quickstart under `specs/006-packaging-submission/`.
- [X] T002 Add the Playwright projects `docs` and `demo` to `frontend/playwright.config.ts`, matching
  `docs.spec.ts` and `demo.spec.ts`, in the shape the existing projects use. Neither runs in the
  default suite sweep that gates a merge: they produce artifacts, and a capture failure must be
  legible on its own rather than buried in 148 results.

---

## Phase 2: Foundational (blocking prerequisites)

### The findings that the prose depends on

- [X] T003 Read the portal's own counts from a running instance of each supported version and record
  them in `research.md` R1, with the instance block that produced them.
- [X] T004 Read the declined operations structurally from `FlightDeck.Capability.Policy` and group
  them by the reason they share; record in `research.md` R6, including the **journal as a third
  category** that is not a decline.
- [X] T005 Audit today's README for statements that are already false, and record each in
  `research.md` R8 with its status — including the near-miss that must **not** be changed.

### The contract and its gate

- [X] T006 Write `scripts/build/check-readme.py` implementing
  [`contracts/readme-contract.md`](./contracts/readme-contract.md): the ten anchors, their relative
  order, element 1's two-sentence rule, element 6's arithmetic and attribution, element 8's
  reconciliation against `FlightDeck.Capability.Policy`, and element 10's `LICENSE` existence. Output
  in the style of the existing gates.
- [X] T007 Run the gate against **today's** README and confirm it fails, naming the order violation
  (feature bullets before installation) and the missing elements. This is the task that proves the
  gate counts; a gate first seen passing has not been tested.
- [X] T008 Wire `check-readme.py` into `scripts/build/check-generated.sh` beside the other gates.

---

## Phase 3: US1 — A stranger understands what this is and runs it (P1)

**Goal**: the first screen explains the portal and shows it; the next thing is an install that works,
including when the port is taken.

**Independent test**: give a reader only the README and time them to a signed-in portal with content.

- [X] T009 [US1] Write `frontend/e2e/docs.spec.ts`: sign in with the shared helpers, set the theme,
  wait for the instrument cluster to carry **live readings** (not a loading state), and write
  `docs/img/instruments.png`. The capture fails if the route or the cluster's test id no longer
  exists (spec FR-013, FR-014; research R3).
- [X] T010 [US1] Extend the same project to capture `docs/img/dry-run.png`: a real dry-run with its
  impact analysis, from the demonstration objects, with nothing secret on screen.
- [X] T011 [US1] Run the `audit` project over what the capture wrote, so no image can carry a
  credential (Constitution VI).
- [X] T012 [US1] Rewrite the README's opening: title, **two sentences** leading with the interaction
  model, then the instrument-cluster image — and nothing else above the fold. The feature bullets that
  sit there today move down (research R2, spec FR-001, FR-002).
- [X] T013 [US1] Restructure installation as element 3: the one-command container path first,
  complete on its own; the IPM path second; and the **port-conflict case inside the installation
  section**, not in troubleshooting (spec FR-003, FR-004).
- [X] T014 [US1] Fold the IRIS for Health variant into the installation section as the one variable it
  is, in the same place as the main path, so a reader on that image never leaves the section.

---

## Phase 4: US2 — A judge can check every claim in a minute (P1)

**Goal**: the differentiators, the compatibility statement, the executor confinement and the declined
operations, each stated so it can be verified against the running portal.

**Independent test**: read only these sections and verify each claim, with no further guidance.

- [X] T015 [P] [US2] Write element 4: the six contest domains, one line each, naming what the portal
  does there (spec FR-005).
- [X] T016 [P] [US2] Write element 5: the five differentiators — command palette, entity graph,
  dry-run with impact analysis, safe mode, and the unified log stream as the one mandatory axis with
  no official API coverage — each naming **where in the portal it can be seen** (spec FR-006).
- [X] T017 [US2] Write element 6: compatibility. SysAdmin API v2 required; `latest-cd` is 2026.2 and
  `latest` is 2026.1; the operation counts per version, each attributed to the version it was read
  from, each satisfying `allowed + unavailable + declined = total` (spec FR-007; research R1). Fix
  the "64 operations" statement, which is wrong and merges two different reasons (research R8).
- [X] T018 [P] [US2] Write element 7: the REST test executor is confined to the instance and is **not
  an outbound proxy**, naming where the confinement is enforced (spec FR-008).
- [X] T019 [US2] Write element 8: what FlightDeck declines, as decisions. The eight encryption writes
  and the three destructive storage writes, grouped by the reason they share, each with its native
  path — and the **journal stated separately**, because it is not a decline but a refusal to
  substitute a native provider for an authorization decision that belongs to IRIS (spec FR-009;
  research R6).
- [X] T020 [P] [US2] Write element 9 in its final wording, ready to receive the Ideas Portal URL, and
  element 10: MIT, with `LICENSE` present and linked (spec FR-010, FR-011).
- [X] T021 [US2] Correct the stale pointers the audit found: the specs directory now holds six
  features, not one (research R8).
- [X] T022 [US2] Run `check-readme.py` and make it pass, with the idea link reported as the pending
  author action it is.

---

## Phase 5: US3 — The demo opens on the strongest thing (P2)

**Goal**: a demonstration that starts on the instrument cluster and the dry-run, shows all six
domains, and runs at the portal's real speed.

**Independent test**: watch the first thirty seconds with no context and state what the portal does.

- [X] T023 [US3] Write `docs/demo-script.md`: shot by shot, what is shown, in what order, what each
  shot proves, and **the expected elapsed time of each shot**, so a recording that runs faster than
  the portal is visibly wrong (spec FR-018; research R4).
- [X] T024 [US3] Write `frontend/e2e/demo.spec.ts`, the driver: the portal driven through the script
  in order, through the interface, waiting on the portal's own completion signals.
- [X] T025 [US3] Open on the instrument cluster with live readings, before any navigation (spec
  FR-015).
- [X] T026 [US3] Show a change rehearsed through the dry-run, with what it would affect, before it is
  applied (spec FR-016).
- [X] T027 [US3] Cover all six domains doing real work, and the log stream with more than one source
  in one list (spec FR-017).
- [X] T028 [US3] Make the driver **report the elapsed time of each shot** and fail if any shot is
  faster than the script declares — the mechanical form of "no wait is shortened, stubbed, skipped or
  simulated" (spec FR-019a). Include at least one asynchronous operation, which is where a portal
  usually lies with a spinner.
- [X] T029 [US3] Record in the script what the author must do: record and publish. This is one of the
  three author actions and it is named, not assumed.

---

## Phase 6: US4 — Installation proven on both Community images, from clean (P2)

**Goal**: the documented path executed from nothing on both images, recorded.

**Independent test**: from no images and no volumes, run the README's own commands and record.

- [X] T030 [US4] Run the README's own commands from clean on IRIS Community Edition; record per
  `data-model.md` §1 in `verification/install-runs.md`, reading version and capability summary **from
  the portal**, not from the tag.
- [X] T031 [US4] The same on IRIS for Health Community Edition.
- [X] T032 [US4] Confirm every domain screen shows content on first access, on each install, and
  record which screen was checked last.
- [X] T033 [US4] Verify the port-conflict path by occupying the port and following the README's
  instructions verbatim (quickstart §5).
- [X] T034 [US4] Verify the IPM path on an instance that is not the container build: the two web
  applications, the runtime role and the capture routine, demonstration objects **off** by default,
  then on with `-DDemo=1` (quickstart §6; research R7).
- [X] T035 [US4] Verify the compatibility claims against a running instance of **each** supported
  version, number for number (quickstart §7).
- [X] T036 [US4] Fix in the README any step that did not work as written, and re-run it. A deviation
  is a README defect, not a note (spec FR-022).

---

## Phase 7: US5 — The checklist closed with evidence (P3)

- [X] T037 [US5] Close every line of `docs/contest.md` §7 in place, each with a pointer to its
  evidence, per `data-model.md` §3. No tick without a pointer.
- [X] T038 [US5] Record the three author actions — the Ideas Portal URL, the recording, the human cold
  read — each with what it needs and its deadline before submission.
- [X] T039 [US5] Re-check the scope lines against reality: the six axes implemented with real reads
  and mutations, the 273 operations assigned and implemented or explicitly degraded with a reason, and
  the log stream's five sources under one schema.

---

## Phase 8: Polish & cross-cutting concerns

- [X] T040 [P] Cold read, agent passes: a session with **no project context**, given the repository
  and the README only, performs the install and records every question it cannot answer. Each becomes
  a README change. Repeat until a pass raises none (spec FR-023; research R5).
- [X] T041 Record the agent passes in `verification/cold-read.md` per `data-model.md` §2, including
  the questions that were worked around rather than blocked — those are the dangerous ones.
- [ ] T042 Hand over the human pass: a reader who knows IRIS and has never seen FlightDeck, timed.
  This is the recorded result for SC-005 and is the third author action (spec FR-024a).
- [X] T043 Run every static gate including the new one, and the full Playwright suite, so this
  feature's changes to shared configuration break nothing.
- [X] T044 Write `verification/feature-006-signoff.md` in the shape features 002 to 005 used:
  gates, what the work found, the clean installs, and what remains with the author.
- [X] T045 Run `specs/006-packaging-submission/quickstart.md` §1 to §9 end to end and fix any step
  that does not work as written.

---

## Dependencies & Execution Order

- **Phase 1** blocks the two new projects.
- **Phase 2** blocks all prose. T007 is deliberate: the gate must **fail** on today's README, which is
  what proves it checks anything.
- **US1 (Phase 3)** blocks nothing but is the MVP: opening, image, installation. If only this ships,
  two of the five judging criteria are already addressed.
- **US2 (Phase 4)** depends on Phase 2's findings, not on US1.
- **US3 (Phase 5)** depends on the portal being final, which it is; it is independent of the README.
- **US4 (Phase 6)** depends on the README being written, because it tests the README's own commands.
- **US5 (Phase 7)** depends on US1–US4, because it records their evidence.
- **Polish** depends on everything. T040–T042 are the cold read and come last, because reading a
  README that is still changing measures nothing.

## Implementation Strategy

**MVP is US1.** The opening, the image and an installation that works. It is the smallest thing that
moves the two judging criteria this feature exists for.

**The three author actions never block.** The idea URL, the recording and the human read are prepared
so that each closes in minutes when the author gets to it, and every other line closes without them.
