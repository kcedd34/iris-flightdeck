# Feature 006 sign-off (T044, T045), 2026-09-18

Packaging and submission: the README in the required ten-element order, the documentation images, the
demo script and its driver, clean-environment verification on both Community images, and the contest
conformance checklist closed. Run from the working tree; nothing is committed.

Two of the five judging criteria — Clarity of Instructions and Developer Experience — are decided by
what a stranger reads and runs in their first ten minutes. This feature was the reserved schedule the
constitution requires for that, and it was treated as product work: the README's checkable claims got
a build gate, its images got a producing test, and its prose got read cold by someone who had never
seen the project.

## Static gates

| Gate | Result |
|---|---|
| `scripts/build/check-generated.sh` | up to date; `check-descriptors` ok (50 entity types, 142 mutations); `check-secrets` ok; `check-coverage` ok (268 operations across 6 shipped domains, 11 declined); **`check-readme` ok (10 elements, in order)** |
| `scripts/build/check-dist.sh` | up to date |
| `npm run lint` | clean |
| `npm run check:tokens` / `check:dialect` / `check:mutation-boundary` / `check:secrets` / `contrast` | all ok |
| `npm run test` (Vitest) | 18/18 |
| Backend `%UnitTest` | 189/189 |
| Full Playwright suite (IRIS CE 2026.2) | **130 passed, 22 skipped, 0 failed** |

## The new gate: `check-readme.py`

The README was the only artifact in this repository that carried checkable facts and was never
compiled. The capability map, the descriptors and the domain coverage all fail a build when they
drift; the front door did not.

It checks presence, order and arithmetic for the ten required elements: the two-sentence opening
before any list; the instrument-cluster image above the fold and before installation; the container
path before the package path with the port-conflict case inside the installation section; exactly six
domains; the five differentiator claims; `allowed + unavailable + declined = total` per named
version, with the total and the declined count reconciled against `docs/api-coverage.md` and
`FlightDeck.Capability.Policy`; the exact phrase "not an outbound proxy"; every declined operation
accounted for by a named group, with the journal stated **outside** that list; the Ideas Portal line;
and `LICENSE` present.

**It was written before the rewrite and made to fail first** (T007): eight problems on the old
README. The order check was then proved separately by moving Compatibility below the declines section
— it failed naming both neighbours. What it deliberately does not check is whether a sentence is
clear; that is the cold read's job, and the contract says so rather than pretending otherwise.

## What this feature found in the product

Packaging is supposed to be documentation work. It was not.

**The canvas time series had never drawn.** The instrument cluster is the signature element of
`docs/design.md` §5 and the first thing the README shows. Capturing it revealed a canvas with **zero
painted pixels**. `createWindow().series()` handed out its internal array, which it then mutates in
place as readings arrive; React's redraw effect is keyed on that array's identity, so it ran exactly
once, on mount, when the window held a single point — and `Series.tsx` returns early below two
points. The line was never stroked, on any install, since feature 004.

Every existing assertion passed throughout: `instruments.spec.ts` checked that the element was a
`CANVAS` with a width greater than zero, which it was. The fix is one line — the window returns a
copy — and the regression test counts non-transparent pixels, which is the only thing that cannot be
faked. The same assertion is now in the demo driver's first shot.

**A test asserted a string that no code produced, and a test id that did not exist.**
`tasks.spec.ts` checked the logs correlation against `logs-correlation` (the real id is
`logs-correlated`) and the text "Correlation received: task" (the stream says "Filtered on task…").
Both were written in feature 004 and never executed, because the test skips on an install with no
failed task run — which was every install, until the demo driver made the demonstration task fail on
purpose. The assertion now matches what the screen says.

**React was dropping a link row**, found earlier in this session and recorded here because it is the
same class of bug: `LinksPanel` keyed rows by name, and the same entity legitimately appears twice in
one group through two different grants.

**A test race**: `count()` does not wait, and asking it of a section that has just begun rendering
returned 0 on a cold instance.

## The documentation images are produced by a test

`frontend/e2e/docs.spec.ts` writes `docs/img/instruments.png`, `dry-run.png` and `palette.png` from
the running portal. A hand-taken screenshot of a screen that has since changed is a silent lie in the
most visible place in the repository, and images are not reviewed the way text is; a capture that
runs as a test fails instead.

Two details worth recording:

- The cluster capture **waits 40 seconds** for the sliding window to fill. A canvas with three points
  draws almost nothing, and an empty canvas is precisely the state the image must not show.
- The dry-run capture **creates its own subject** — a user holding the demonstration role — and
  removes it afterwards. The first version depended on an end-to-end test's leftover user, so the
  image was not reproducible on a clean install, where nothing holds the role and the impact panel
  would have had nothing to report.

## The demo driver, and the claim it does not make

`docs/demo-script.md` is nine shots, 4 minutes 55 seconds on screen, opening on the instrument
cluster and the dry-run as the contest checklist requires. `frontend/e2e/demo.spec.ts` drives the
portal through them in order, so the recording is an execution and can be redone after any change.

The rule is that nothing is accelerated, stubbed, skipped or simulated: the driver installs no route
interception and fakes no response.

**One assertion was written and then removed for being vacuous.** The first version claimed to "fail
a shot that finished faster than its minimum" — but each shot holds the screen until it reaches its
minimum, so the check could never fail. That is exactly the kind of sentence this feature exists to
catch, and it was in this feature's own artifact. What the driver enforces instead is that each shot
**issued requests to the instance** — a shot that made none is a shot showing a static page — and it
reports the real work time of every shot, which is what a viewer compares the recording against. The
script now distinguishes *work* from *time on screen* and says which one it is enforcing.

## Clean-environment verification

Run with the README's own commands. Full detail in
[`install-runs.md`](./install-runs.md); in summary:

| Run | Result |
|---|---|
| IRIS Community 2026.2 | ready in 12 s; `iris / 2026.2 / Community / v2`; 262 + 0 + 11 = 273; content on all six domains |
| IRIS for Health Community 2026.2 | ready in 18 s; `irisforhealth / 2026.2 / Community / v2`; **the same counts as IRIS 2026.2**, which the README claims and a reader would otherwise spend 5 GB to check |
| Port conflict | the documented alternative works; **the README quoted an older Docker's error message** and now quotes the current one |
| IPM on an instance that is not the container build | two web applications, the runtime role, the `%SYS` routine, `install complete (demo=0)`, **0 demo resources and no `/csp/fd-demo`** — the one install path no gate covers |

## The cold read

Two agent passes with no project context, reading only the README, recorded in
[`cold-read.md`](./cold-read.md).

Pass 1 returned six blocking questions and twenty-odd others. The most consequential were not the
missing facts but the **correct guesses**: the reader would have guessed right about what the
SysAdmin API is, which namespace FlightDeck installs into, and whether `Ctrl`+`K` wins against the
browser — and a reader who guesses right is not evidence that the text was clear, because the next
one guesses wrong.

Pass 2 was much shorter, which is the point of running it twice, and it found two things worth
singling out:

- **A fix from pass 1 created a blocking problem.** "Clone this repository — the URL is on the page
  you came from" is nothing at all to a reader holding only the file.
- **A fix from pass 1 created a trap.** The `.env` example added for Windows readers carried both the
  port and the image, so a reader arriving there for a port conflict who pasted the block would
  silently switch to IRIS for Health, via a command missing the `--build` that switch needs.

Both are now fixed. The agent passes are the instrument; **the recorded result for SC-005 is the
human pass**, which remains with the author.

## What remains with the author

Four actions, each a few minutes, none blocking anything else, all recorded in `docs/contest.md` §7
with what they need and their deadline:

1. **The Ideas Portal URL.** The README carries the line in final wording with a
   `<!-- idea-link-pending -->` marker; the gate warns on it at every build and still passes, so it
   cannot be forgotten silently.
2. **The recording.** `docs/demo-script.md` and the driver are ready; start the driver headed and
   record the window.
3. **The human cold read.** A reader who knows IRIS and has never seen FlightDeck, timed.
4. **The clone URL.** This repository has no remote configured, so nothing in it knows its published
   address. The README currently names two places to copy it from, which works for a reader arriving
   from the repository page; with the real URL it becomes a copyable command.

## Result

Feature 006 is complete apart from the four author actions: **41 of 45 tasks**, with T042 (the human
pass) held for the author and the rest closed.

The README now satisfies its contract and is gated on every build. Every number in it was read from a
running instance, every install command was executed from clean on both Community images, and every
claim it makes is paired with the gate, sweep or record that enforces it.
