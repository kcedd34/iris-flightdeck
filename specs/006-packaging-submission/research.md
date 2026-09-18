# Phase 0 research: Packaging and Submission

Eight questions. Each was answered against the running portal, the repository or the platform — none
from memory. Probed on the fresh IRIS CE 2026.2 install (port 52780) unless stated otherwise.

---

## R1. Where do the README's numbers come from, and which can a gate check?

**Decision**: every number in the README is read from the portal's own session response, and the ones
derived from repository data are asserted by the new gate.

The portal reports its capability summary at sign-in:

```json
{"allowed": 262, "unavailable": 0, "declined": 11, "total": 273}
```

read from `GET /api/flightdeck/v1/session`, together with the instance it is talking to:

```json
{"product":"iris","version":"2026.2","apiVersion":2,"edition":"Community","dialect":"v2"}
```

On IRIS CE 2026.1 the same endpoint answers `{"allowed":200,"unavailable":62,"declined":11,"total":273}`.

**Three kinds of number, and only two are gateable.**

| Number | Source | Gate |
|---|---|---|
| Declined operations (11) | `FlightDeck.Capability.Policy` XData, read structurally | Yes — the gate parses the class and compares |
| Total operations (273) | The generated capability spec | Yes |
| Allowed / withheld per version (262/0, 200/62) | A running instance of that version | No — the gate asserts the prose is *consistent* (allowed + unavailable + declined = total) and that the version it is attributed to is named |

**Rationale**: a gate that tried to check per-version counts would need both instances running on
every build, which would make the gate the slowest thing in the repository and the first one someone
disables. Asserting the arithmetic and the attribution catches the realistic failure — a number
copied forward after the map changed — without that cost.

**Alternatives considered**: hard-coding the counts in the gate (rejected: two places to update, and
the gate would then be asserting itself); omitting the counts from the README (rejected: they are the
compatibility statement's entire substance).

---

## R2. What fits above the fold, and what does that allow?

**Decision**: the first screen gets the title, two sentences, and the image. Nothing else.

Measured against today's README: the title, the two-sentence description and the image occupy the
first ~330 characters; the feature bullets that follow push installation well below the fold. On a
1080p viewport the hosting platform renders roughly the first 25–30 lines of the rendered body above
the fold, and the repository page spends part of that on its own header.

**Consequence for the required order**: the user's item 2 (the image) and item 3 (installation) both
want to be early, and only one can be above the fold. The image wins, because it is the thing prose
cannot do — but installation must be the *very next* thing, which means **the feature bullets that
sit there today have to move down**. The six domains (item 4) and the differentiators (item 5) come
after installation, which is exactly the order the user specified.

This is the single biggest structural change to the README: today it is description-then-install, and
it becomes description-image-install-then-description.

---

## R3. How is the instrument cluster captured so it cannot go stale?

**Decision**: a Playwright project photographs the running portal and writes into `docs/img/`.

The e2e suite already signs in, sets the theme and waits for the instrument cluster to carry live
readings — `instruments.spec.ts` asserts exactly that. A capture project reuses those helpers, so the
photograph is of the shipped screen in a shipped theme, with real values.

**Why this and not a manual screenshot**: the failure this prevents is specific. If the cluster's
test id or the route changes, a hand-captured PNG keeps showing the old screen and nobody notices,
because images are not reviewed the way text is. A capture that runs as a test **fails** instead.

**Two images, not one**: the cluster (the above-the-fold asset) and the dry-run with its impact
analysis. The second is the other thing this project does that a screenshot argues better than a
paragraph, and the demo needs the same two shots — so the same project produces both.

**Constraint carried from Principle VI**: no capture may photograph a secret. The images are produced
from the demonstration objects, which hold none, and the existing credential sweep covers what the
capture writes.

---

## R4. What does "the portal's real speed" mean, concretely?

**Decision**: the driver performs the same operations the e2e suite performs, through the interface,
and waits for the portal's own completion signals. Four things are forbidden.

| Forbidden | Why it would be a lie |
|---|---|
| Shortening or stubbing a network wait | The evaluator's first install would take longer than the video, and every other claim becomes suspect |
| Skipping a confirmation step | The confirmation *is* the product; a demo without it demonstrates a different application |
| Pre-warming a screen off camera so it appears instantly | The first paint after sign-in is a real cost and the README makes a claim about it |
| Speeding up the recording in post | Same as the first, moved to a different tool |

**What is allowed**: choosing *which* operation to show. Picking an operation that completes in three
seconds over one that takes three minutes is editing, not deception, as long as what is shown is
shown whole. The demo script states the expected elapsed time of each shot, so a recording that runs
faster than the portal is visibly wrong rather than merely suspected.

**The asynchronous operations are the honest test case.** The disk instrument polls an asynchronous
task and keeps its last value visible; the storage operations declare their expected duration in the
confirmation. Both are in the demo precisely because they are where a portal usually lies with a
spinner.

---

## R5. What is the cold-read protocol?

**Decision**: two stages, different instruments, one recorded result.

**Agent passes** (iterative, cheap, repeatable): a session with no project context receives the
repository and the README only. It performs the install and records every question it cannot answer
from the README. Each question becomes a README change. Repeat until a pass raises none.

**Human pass** (once, recorded): a reader who knows IRIS and has never seen FlightDeck, timed from
first opening the repository page to a signed-in portal with content on every domain screen. Every
question is recorded whether or not it blocked them.

**Why both** (the user's own reasoning, recorded here because it decides the protocol): the agent is
better at finding a fact that is *absent*; the human is the only one who catches a sentence that is
technically correct and still fails to communicate. Grading the second with the first would measure
the wrong thing.

**What is recorded**: elapsed time, the point at which content appeared on every domain screen, every
question raised, and for each question the README change it produced or why none was needed.

---

## R6. What exactly is declined, and what is the third category?

**Decision**: the README states **three** categories, not two, because "declined" does not cover all
of it.

**Eleven operations are declined by policy**, read structurally from `FlightDeck.Capability.Policy`:

| Group | Count | Operations | Native path |
|---|---|---|---|
| Encryption writes | 8 | key file create; key-file admin add and remove; key add and remove; key activate and deactivate; encryption settings | System Administration > Encryption |
| Destructive storage writes | 3 | database directory truncate; database delete; namespace delete | System Administration > Configuration > Local Databases / Namespaces |

Each carries its own reason. They share a shape: *the portal cannot rehearse them and cannot undo
them*. Truncation returns space to the file system with no recovery from the portal; a deleted
encryption key cannot decrypt what it encrypted. FlightDeck grows databases and creates namespaces; it
does not delete them.

**The third category is the journal, and it is not a decline — it is a refusal to substitute.** On
the v1 dialect the journal operations are withheld by the platform, and FlightDeck does **not** read
the journal natively to fill the gap:

> FlightDeck does not read the journal natively: filtering records by the databases you can read is
> an authorization decision that belongs to IRIS.

This is the more interesting of the two statements and the README must not flatten it into the
declined list. Everywhere else in this project a missing official operation is a candidate for a
native provider — that is how three of the five log sources exist. The journal is where that stops,
because implementing it natively would mean FlightDeck deciding which records a user may see, and
that decision belongs to the platform. It is a Principle II statement wearing a Principle I costume.

---

## R7. Does the IPM path work as the README describes it?

**Finding**: the module declares what the README claims, and the claim is checkable.

`module.xml` declares `<UnitTest Name="/backend/test" Package="FlightDeck.Test" Phase="test" />`, so
the README's `zpm "iris-flightdeck test"` has a target behind it, and `<Default Name="Demo" Value="0" />`
confirms demonstration objects are off by default on the IPM path, as the README says.

**To verify in this feature**: the IPM load on an instance that is not the container build, because
that is the path the README documents and the only one no gate covers. This is a quickstart step, not
an assumption.

---

## R8. Which statements in today's README are already false?

Four findings, and one near-miss worth recording so it is not "corrected" later.

| Statement | Status |
|---|---|
| "disables the **64** operations it cannot offer" | **False.** The instance withholds **62**; a further 11 are declined by policy on every version. The sentence also merges two different reasons for the same disabled control |
| "Specifications, plan and research live in `specs/001-foundation-shell/`" | **Stale.** Six features now |
| "This release completes the six domains…" as a release note in the opening | **Displaced**, not false: it belongs after installation under the six domains, not above the fold |
| Feature bullets before installation | **Wrong order** for the required sequence (R2) |
| "Sign-in says *Requires IRIS 2026.1*" in troubleshooting | **Correct — do not change.** `MSGNOAPI` really does say 2026.1, because an instance with no SysAdmin API at all needs 2026.1 to have one. `MSGVERSION`, the *other* message, says 2026.2. Two messages, two thresholds; the README quotes the right one |

The last row is why R8 exists as a research question rather than an editing pass. Two of the four
edits that looked obvious on a read-through would have been wrong.
