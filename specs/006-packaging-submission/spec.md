# Feature Specification: Packaging and Submission

**Feature Branch**: `006-packaging-submission`

**Created**: 2026-09-18

**Status**: Draft

**Input**: User description: "Packaging and submission. Scope: README in English, demo video, verification on both Community images, and the submission checklist in docs/contest.md Section 7. Two of the five published judging criteria are Clarity of Instructions and Developer Experience. Treat this as product work, not documentation chores."

## Context

Five features built the portal. This one makes it legible to someone who has never seen it, and
submittable.

That is not a clerical wrap-up. Of the five published judging criteria — Complexity, Clarity of
Instructions, Developer Experience, Applicability, Usability — **two are decided entirely by what a
stranger reads and runs in their first ten minutes**. The constitution already says so: the README
and the one-command install are first-class deliverables with reserved schedule, planned and reviewed
like features. This feature is that reserved schedule.

The failure mode this feature exists to prevent is specific and common: a technically strong
submission whose README opens with a feature list, whose install has an undocumented port collision,
and whose video is a menu tour. A reader who bounces at minute two never reaches the complexity.

## Clarifications

### Session 2026-09-18

- Q: How far does this feature take the demo video? → A: **Script, rehearsed environment and a
  deterministic driver** — a scripted run that puts the portal through the exact demo sequence with
  its timings, so the author presses record once and follows it. **Condition: the driver uses the
  real waiting times and never accelerates them.** If a TLS connection test takes ten seconds, the
  video shows ten seconds. A video that hides the true behaviour falls apart at the evaluator's first
  install, and a demo that cannot survive being reproduced is worse than no demo.
- Q: Who performs the cold read that SC-005 measures? → A: **Both, in that order.** Agent passes with
  no project context iterate until the README answers every question; **one final human pass is the
  recorded result.** The division is deliberate: the agent is better at finding a fact that is
  *absent*, the human is the only one who catches the sentence that is technically correct and still
  fails to communicate. The human reader **knows IRIS but has never seen FlightDeck**, which is also
  the evaluator's profile.
- Q: The Ideas Portal link, which a placeholder cannot satisfy? → A: **The author publishes the idea
  and supplies the URL.** The README carries the line ready to receive it, and the conformance
  checklist records it as an **author action pending, due before submission**.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A stranger understands what this is and runs it (Priority: P1)

Someone who has never heard of FlightDeck opens the repository page. In the first screen of text they
learn what the portal *is* — how you interact with it — and see it moving. They copy one command, run
it, and reach a working portal with data on every screen. When the port they need is taken, the
README already told them what to do.

**Why this priority**: This is two of the five judging criteria, and it gates everything else. A
reader who does not get past the first screen never evaluates the six domains, the dry-run or the log
stream. Nothing else in this feature matters if this fails.

**Independent Test**: Hand the repository to a reader with no prior exposure, give them only the
README, and time them from first view to a signed-in portal with content. No question they ask may
require an answer that is not in the README.

**Acceptance Scenarios**:

1. **Given** a reader who has never seen the project, **When** they read the first two sentences,
   **Then** they can state how the portal is operated (keyboard-first, safe-by-default, built on the
   official SysAdmin API) without having read a feature list.
2. **Given** the repository page rendered as the hosting platform renders it, **When** the reader has
   scrolled no further than the first screen, **Then** they have seen the instrument cluster as a
   moving or still image, not only as prose.
3. **Given** a clean machine with the stated prerequisites, **When** the reader runs the first
   command block in the README verbatim, **Then** a working portal is reachable and every domain
   screen shows content on first access.
4. **Given** the required port is already in use on the reader's machine, **When** they follow the
   README's port-conflict instructions, **Then** the install succeeds on a different port without
   editing any file that is not named in those instructions.
5. **Given** a reader who wants it on an instance they already run, **When** they follow the second
   install path, **Then** the package installs through IPM without the container path being a
   prerequisite.

---

### User Story 2 - A judge can tell in one minute what is different here (Priority: P1)

A judge comparing submissions reads the README's differentiators and the compatibility statement.
They learn that the portal is driven from a command palette, that entities link to each other, that
every change is rehearsed before it happens, that every tab starts read-only, and that the log stream
is the one mandatory axis the official API does not cover. They also learn exactly which IRIS
versions this runs on and what is reduced on the older one.

**Why this priority**: Applicability and Complexity are judged from this section. It is also where a
submission either claims things it cannot show or states them so they can be checked in minutes.

**Independent Test**: Read only the differentiator and compatibility sections, then verify each claim
against the running portal without further guidance.

**Acceptance Scenarios**:

1. **Given** the differentiator section, **When** a judge reads it, **Then** each of the five claims
   — command palette, entity graph, dry-run with impact analysis, safe mode, unified log stream —
   names where in the portal it can be seen.
2. **Given** the compatibility section, **When** a judge reads it, **Then** they learn that the
   SysAdmin API v2 is required, which release channel each supported version belongs to, and the
   number of official operations offered, withheld by version, and declined by policy on each.
3. **Given** a judge who wonders whether the REST test executor could reach outside the instance,
   **When** they read the section on it, **Then** they learn it is confined to the instance and is
   not an outbound proxy, and where that confinement is enforced.
4. **Given** the declined operations, **When** a judge reads them, **Then** each is stated as a
   decision with its reason and the native path that performs it, and none reads as an unimplemented
   gap.

---

### User Story 3 - The demo opens on the strongest thing, not on a menu (Priority: P2)

A viewer watches the demo and, within the first seconds, sees the instrument cluster moving and a
dry-run showing exactly what a change will do before it happens. The rest follows from there. No part
of the demo is a tour of navigation.

**Why this priority**: The contest checklist requires the video to open on the instrument cluster and
the dry-run, not on a menu. It is the second-highest-leverage artifact after the README, and it can
be produced only once the portal is final — which it now is.

**Independent Test**: Watch the first thirty seconds with no context and state what the portal does
and why it is unusual.

**Acceptance Scenarios**:

1. **Given** the demo, **When** the first seconds play, **Then** the instrument cluster is on screen
   with live readings, before any navigation is shown.
2. **Given** the demo, **When** a change is demonstrated, **Then** the dry-run is shown before the
   change is applied, including what the change would affect.
3. **Given** the demo, **When** it ends, **Then** all six contest domains have been shown doing real
   work, and the log stream has been shown with more than one source in one list.

---

### User Story 4 - Installation is proven on both Community images, from clean (Priority: P2)

Before submission, the documented install path is executed from nothing on both InterSystems
Community images, and the result is recorded: what was run, what came up, and every screen carrying
content.

**Why this priority**: The contest requires the application to run on IRIS Community Edition or IRIS
for Health Community Edition; this project has always claimed both. A claim of "runs on both" that
was last checked three features ago is a claim, not a fact.

**Independent Test**: From a machine with no images pulled and no volumes, run the README's own
commands for each image and record the outcome.

**Acceptance Scenarios**:

1. **Given** a machine with no prior FlightDeck images or volumes, **When** the README's first
   command block is run against each Community image in turn, **Then** each reaches a signed-in
   portal, and the run is recorded with its date, image tag and outcome.
2. **Given** each install, **When** every domain screen is opened for the first time, **Then** each
   shows content rather than an empty state caused by the install.
3. **Given** the older supported version, **When** the portal is opened, **Then** it runs in limited
   mode, says so persistently, and the recorded outcome names how many operations are withheld.

---

### User Story 5 - The submission checklist is closed with evidence (Priority: P3)

Every line of the contest conformance checklist is answered with a pointer to where it was verified,
so that submitting is a matter of following the list rather than remembering.

**Why this priority**: It is the lowest-risk item — it records work the other stories do — but it is
the one that turns a finished project into a submitted one, and an unanswered line is discovered at
the deadline.

**Independent Test**: Read the checklist alone and confirm that every box is either ticked with a
pointer to its evidence or explicitly deferred with the reason and the date it must be done.

**Acceptance Scenarios**:

1. **Given** the conformance checklist, **When** it is read before submission, **Then** every scope,
   judging and formal line is either closed with a pointer to its evidence, or marked as an action
   that only the author can perform, with what is needed.
2. **Given** the formal requirements, **When** they are checked, **Then** the licence file is present
   and named in the README, the README is in English with installation steps, and the idea link is
   present.

---

### Edge Cases

- **The reader's port is taken by something they cannot stop.** The documented alternative must work
  without editing files the instructions do not name.
- **The reader has IRIS for Health, not IRIS CE.** The first command block must state the one change
  that switches images, in the same place, not in a later section.
- **The reader installs on an instance whose SysAdmin API is absent or older than v2.** Sign-in is
  refused with a version message today; the README must set that expectation before they install, not
  after.
- **The reader is on the older supported version.** The README must say what limited mode means in
  operations, so the reduction is understood as a property of the instance and not a defect.
- **A screenshot or clip goes stale.** An image showing a screen that no longer exists is worse than
  no image; the asset must be reproducible from the running portal rather than hand-captured once.
- **The demo cannot be recorded or published by the project itself.** Producing and publishing a
  video is an authoring act; the deliverable must be defined so that what can be prepared is
  prepared, and what only the author can do is named.
- **The idea link does not exist yet.** The Open Exchange requirement is published and cannot be
  satisfied by a placeholder.

## Requirements *(mandatory)*

### Functional Requirements

**The README, in the order the reader meets it**

- **FR-001**: The README MUST open with what the portal is in two sentences, leading with the
  interaction model — how it is operated and what it is built on — and MUST NOT open with a feature
  list.
- **FR-002**: The README MUST show the instrument cluster as an image or short clip within the first
  screen of the rendered page, above any installation instructions.
- **FR-003**: The README MUST present installation with the one-command path first and the package
  path second, in that order, each complete on its own.
- **FR-004**: The README MUST document the port-conflict case in the installation section, with the
  exact change required, not in a troubleshooting appendix reached later.
- **FR-005**: The README MUST describe each of the six contest domains in one line stating what the
  portal does there, so the six axes are visible without reading six sections.
- **FR-006**: The README MUST state what makes the portal different in five named claims: the command
  palette, the entity graph, the dry-run with impact analysis, safe mode, and the unified log stream
  as the one mandatory axis with no official API coverage.
- **FR-007**: The README MUST state compatibility: that the official SysAdmin API v2 is required,
  which supported version belongs to which release channel, and the count of operations offered,
  withheld by version and declined by policy on each supported version.
- **FR-008**: The README MUST state that the REST test executor is confined to the instance and is
  not an outbound proxy.
- **FR-009**: The README MUST list the operations FlightDeck declines — the encryption writes, the
  destructive storage writes, and the journal records it will not read natively — each **as a
  decision with its reason and the native path that performs it**, never as a missing feature.
- **FR-010**: The README MUST link to the idea on the InterSystems Ideas Portal.
- **FR-011**: The README MUST state the MIT licence, and the licence file MUST be present in the
  repository.
- **FR-012**: The README MUST be in English throughout, as every other deliverable of this project.

**The above-the-fold asset**

- **FR-013**: The instrument-cluster asset MUST be produced from the running portal by a repeatable
  procedure, so it can be regenerated when the screen changes rather than re-captured by hand.
- **FR-014**: The asset MUST show live readings, not an empty or loading state, and MUST show the
  portal in the theme the README's other images use.

**The demo**

- **FR-015**: The demo MUST open on the instrument cluster with live readings, before any navigation
  is shown.
- **FR-016**: The demo MUST show a change rehearsed through the dry-run, including what the change
  would affect, before it is applied.
- **FR-017**: The demo MUST show all six contest domains doing real work, and the log stream with
  more than one source in one list.
- **FR-018**: The project MUST carry a demo script that states, shot by shot, what is shown, in what
  order and why, so the recording is an execution rather than an improvisation.
- **FR-019**: The project MUST provide a **demo driver**: a repeatable scripted run that puts the
  portal through the demo sequence in order, so the recording is an execution. Recording and
  publishing the file remain the author's act.
- **FR-019a**: The driver MUST use the **real waiting times of the portal and the instance** and MUST
  NOT shorten, skip or simulate them. Where an operation takes ten seconds, the demo takes ten
  seconds and the screen shows what the portal shows while waiting.

**Clean-environment verification**

- **FR-020**: The documented install path MUST be executed from a clean state on both InterSystems
  Community images before submission, using the README's own commands and no others.
- **FR-021**: Each verification run MUST be recorded with its date, the image identifier, the
  commands run, the outcome, and confirmation that every domain screen showed content on first
  access.
- **FR-022**: Any step that did not work as written MUST be fixed in the README, and the corrected
  step re-run, rather than recorded as a known deviation.

**The cold read**

- **FR-023**: A reader with no prior exposure to the project MUST perform a timed walkthrough using
  only the README, and every question they cannot answer from it MUST become a correction to the
  README.
- **FR-024**: The cold read MUST run in two stages: **agent passes** with no project context,
  repeated until no question remains that the README does not answer, followed by **one human pass**
  which is the recorded result.
- **FR-024a**: The human reader MUST **know IRIS and not know FlightDeck** — the evaluator's profile —
  and their pass MUST be timed and recorded with every question they raised.

**The submission checklist**

- **FR-025**: Every line of the contest conformance checklist MUST be closed with a pointer to the
  evidence that closes it, or marked as an action only the author can perform, with what it needs.
- **FR-026**: The README MUST carry the Ideas Portal line in its final wording, ready to receive the
  URL, and the conformance checklist MUST record the link as an **author action pending, due before
  submission**, naming what is needed to close it.

### Key Entities

- **README**: the repository's front door. The single artifact judged by two of the five criteria.
- **Above-the-fold asset**: an image or short clip of the instrument cluster, reproducible from the
  running portal.
- **Demo script**: the shot-by-shot plan of the demonstration, with what each shot proves.
- **Verification record**: one entry per clean install, naming date, image, commands, outcome and
  screen-content confirmation.
- **Cold-read record**: the timed walkthrough, the questions raised, and the README change each one
  produced.
- **Conformance checklist**: the contest's own list, each line closed with evidence or with a named
  author action.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A reader who has never seen the project reaches a signed-in portal with content on
  every domain screen in **under 10 minutes** from first opening the repository page, using only the
  README.
- **SC-002**: The interaction model and the instrument cluster are both visible **without scrolling
  past the first screen** of the rendered repository page.
- **SC-003**: All **ten** README requirements are present, in the stated order, and each is verified
  against the running portal rather than against an earlier draft.
- **SC-004**: The documented install path completes from clean on **both** Community images, and both
  runs are recorded with date, image and outcome.
- **SC-005**: A cold reader who knows IRIS and has never seen FlightDeck completes the walkthrough
  with **zero questions that the README does not answer**; the walkthrough is timed, and the time is
  recorded. Every question raised in an agent pass has become a README change before the human pass.
- **SC-006**: The demo shows the instrument cluster in its **first 15 seconds** and a dry-run before
  any change is applied, and covers all six domains. Its driver runs at the portal's real speed: the
  elapsed time of any operation it demonstrates matches the elapsed time of that operation performed
  by hand.
- **SC-007**: Every line of the contest conformance checklist is closed with evidence or named as an
  author action; **no line is left unanswered**.
- **SC-008**: Every claim the README makes about counts, versions and declined operations matches
  what the running portal reports, checked on both supported versions.
- **SC-009**: The above-the-fold asset can be regenerated from a running portal by following a
  documented procedure, and the regenerated asset matches what the README shows.

## Assumptions

- **The portal is finished.** Features 001 to 005 are complete and their matrices are green on IRIS
  CE 2026.2, IRIS for Health 2026.2 and IRIS CE 2026.1. This feature changes packaging, not
  behaviour. Any portal defect it uncovers is fixed as a defect, not absorbed into the README.
- **Nothing in the README may be aspirational.** Every statement is checked against a running
  instance. A sentence that cannot be checked is removed rather than softened.
- **The existing README is the starting point, not the deliverable.** It already carries most of the
  material; this feature reorders it to the required sequence, adds what is missing, and removes what
  no longer holds.
- **The above-the-fold asset defaults to a still image** captured from the running portal by the
  project's own browser automation, with a short clip used instead only if the demo recording
  produces one. A still is deterministic, regenerable and cheap to keep honest; a clip is not, unless
  it falls out of the video work.
- **Operation counts come from the portal, not from a document.** The README's numbers are read from
  a running instance of each supported version at the time the README is finalised.
- **"Both Community images" means IRIS Community Edition and IRIS for Health Community Edition.** The
  older supported version is verified as well, because limited mode is a claim the README makes.
- **The contest checklist stays in its original language.** It is a working document that predates
  the English-everywhere rule's scope, which covers UI text, code comments and commits. Its evidence
  pointers may be in English.
- **Publishing to external services is the author's act.** Submitting the application, publishing the
  video and publishing the idea reach outside this repository; this feature prepares them, and what
  remains is named in the checklist with its deadline.
- **The three author actions are the only open ends.** The Ideas Portal URL, the video recording and
  the final human cold read depend on the author; everything else in this feature is completed and
  verified without them, so none of them blocks the rest.
