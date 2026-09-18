# Cold read of the README (feature 006, FR-023, FR-024, SC-005)

Two stages, different instruments, one recorded result.

**Agent passes** run with no project context, given the repository and the README and forbidden to
open any other file. They are cheap and repeatable, and they are good at finding a fact that is
*absent*. **The human pass** is the recorded result for SC-005: a reader who knows IRIS and has never
seen FlightDeck — the evaluator's profile — because that reader is the only one who catches a
sentence that is technically correct and still fails to communicate.

A question is recorded even when the reader worked around it. The ones answered by guessing correctly
are the dangerous ones: the next reader guesses wrong.

---

## Pass `agent-1` — 2026-09-18

**Reader**: a session with no project context, knowing IRIS, reading only `README.md`.
**Blocked**: no, but six questions would have required asking a human.

### Blocking questions, and what each produced

| Question | Change |
|---|---|
| **Which image does the default `docker compose up -d` pull?** Never named. The README itself says the `latest` tag is the limited release, so the reader's first fear was that the quickstart lands in limited mode | The install section now names `intersystemsdc/iris-community:2026.2-zpm`, says it is pinned in `docker-compose.yml`, and states in as many words that the default gives the **full** portal |
| **Apple Silicon?** "macOS" with no qualifier, and IRIS images have a history of being x86-64 only. Under emulation the "about 15 seconds" promise is meaningless | Checked the manifests: both Community images publish `amd64` **and** `arm64`. Requirements now say so, and that Apple Silicon runs natively with no emulation |
| **`git clone <repository-url>` is a literal placeholder** — the README does not know its own address | Replaced with an instruction that works from wherever the reader arrived: clone this repository, the URL is on the page you came from |
| **`FLIGHTDECK_PORT=… docker compose up -d` is POSIX syntax** and fails in PowerShell and `cmd`, both covered by "Windows (including WSL2)" | The port-conflict section now documents the `.env` file Compose reads automatically, with both variables in it |
| **Why does the IRIS for Health path need `--build` when the default does not?** Either there is a local Dockerfile — in which case the disk figures and the 15-second promise are wrong — or the flag is spurious | There is a local build. The README now says the first `up` builds a small image on top of the base, corrects the timing to "about 15 seconds after the first build, which itself takes a few minutes", and explains that `--build` is needed on the Health path because the local image already exists on a different base |
| **What does `scripts/verify/run-both-images.sh` do to my machine?** Does it take my port, tear down my install, need Python? It is the project's own evidence and it was the least safe thing to run | It now says the reports are committed so you need not run it, and that it needs Python 3, starts and removes its own throwaway containers, and does not touch your install or its data |

### Questions the reader would have guessed past

The most valuable part of the pass, because each is a place where a correct guess hid a gap.

| Guess | Change |
|---|---|
| **"the official SysAdmin API"** — bolded like a proper noun, cited throughout, never once defined or linked. Every trust claim in the document rests on it | The opening paragraph now says what it is: IRIS's REST management API under `/api/admin` |
| **Does FlightDeck replace the Management Portal or sit beside it?** "a keyboard-first management portal" reads as a replacement; "Native path: *System Administration > Encryption*" implies the real one is still there | Stated after sign-in: it installs into `USER`, does not replace the Management Portal, runs beside it, and points back to it for what it declines |
| **<kbd>Ctrl</kbd>+<kbd>K</kbd> is the browser's own address-bar shortcut** | The tour now says FlightDeck takes the shortcut while the portal has focus |
| **Is `delete a role` a literal command label or a natural-language phrase?** A reader who typed `delete role` and got nothing would conclude the tour was broken | The tour now says to type `delete` and choose "Delete a role", and says the palette matches fragments of names. "Delete a role" is the operation's own label, checked against the running portal |
| **Which namespace?** Never stated, including in the IPM section. An IRIS-literate judge's first move is to cross-check in the Management Portal | `USER`, stated |
| **`-DDemo=1` creates an unauthenticated web application on your instance.** The README warned that the *credentials* are for local evaluation and attached no warning to this | A marked warning on the IPM path: `/csp/fd-demo` is deliberately unauthenticated, which is what you want on a scratch instance and not on a shared one |
| **What does `zpm "load"` do below 2026.1** — clean refusal or half-install? | Stated: it installs, and sign-in refuses with the detected version rather than half-working |

### Claims with no stated way to check them

The reader listed nine, including the coverage table, "no credential is stored anywhere", the
server-side safe-mode guarantee, the executor opening no connection, and the 100 MB paging cost —
each asserted and none pointed anywhere.

**Change**: a new section, *Checking what this README claims*, pairing each claim with the gate,
sweep, script or record that enforces it, plus a reproducible `curl` for the capability counts beside
the compatibility table itself.

### Sentences that were technically correct and did not communicate

| Quoted | Change |
|---|---|
| "every change is **rehearsed** field by field" — a metaphor carrying the central feature, unexplained for another 110 lines | Replaced with what it means: the exact fields that would change and the users who would lose access, shown first, applied only on confirmation |
| "no credential is stored anywhere, **on any path**" — read as URL path, then install path, then code path | Replaced: "your password is never stored by any part of it" |
| "**the axis** with no official API coverage" / "**the brief** asks for…" — two undefined terms in consecutive clauses; the only sign the README is answering a contest specification | Rewritten without either: "Of the five places IRIS reports what happened, the SysAdmin API covers two… This is the part of the portal that could not be assembled from the API alone" |
| "a **fifth value** outside the ordering" — presumes four severities the README never lists | The scale is now named — `info`, `warning`, `error`, `fatal` — before the fifth is introduced |
| "There is **no third case**" — made the reader scroll back to count the two | The two cases are now stated as two, in one sentence, with "those two are the only cases" after them |
| "FlightDeck grows databases and creates namespaces; it does not delete **them**" — two candidate antecedents, both true, so it reads fine and then stalls | "creates databases and namespaces but deletes neither" |
| Column headers "Withheld by this version" / "Declined by policy" — withheld by whom, from whom | "Not offered by that IRIS" / "Declined by FlightDeck", with a sentence under the table saying which is which |

### The tension the reader could not resolve

Compatibility says capability comes from the API's declarations "rather than from a version number";
Troubleshooting then quotes user-facing strings that name version numbers. The reader could not tell
whether there was a version check after all.

**Change**: a paragraph saying the version is in the *message*, not in the *decision* — "Requires
IRIS 2026.2" is more useful to a reader than "this instance does not declare this operation".

### Order

Three fixed by cross-links rather than by moving sections, because the required element order is
fixed: the tour now links to the demonstration objects it promises, to what a rehearsal looks like,
and to Troubleshooting from the stop/start paragraph.

The limited-mode warning arriving 120 lines after the command it worries about is answered at the
source instead — the install section now states outright that the default is the full portal.

**Not fixed, and recorded as a judgement**: the reader wanted a table of contents. The ten README
elements have a required order, and a table of contents would sit between the image and the
installation, pushing the one-command path below the fold. The cross-links do the same work without
costing that.

### The two-sentence test

The reader's own words after the title and first paragraph were accurate on the interaction model —
palette, per-tab read-only, permission passthrough, no stored credentials — and wrong on two things:
they assumed the primary use was *against an existing instance*, and read "portal" as a *replacement*
for the Management Portal. They also said the opening undersold the scope.

**Change**: the first sentence now says it "ships as a container you can run in one command", and the
Management Portal relationship is stated explicitly.

---

## Pass `agent-2` — 2026-09-18

**Reader**: a second session, no project context, README only.
**Blocked**: once — and on a sentence the *first* pass's fix introduced.

The pass was much shorter than the first, which is the point of running it. Six categories came back
"none" or "clear". What it found:

### The one blocking finding, which pass 1's fix created

> "Clone this repository — the URL is on the page you came from"

Pass 1 complained that `git clone <repository-url>` was a placeholder. The fix pointed at "the page
you came from" — which is nothing at all to a reader holding only the file, and the next line was
`cd iris-flightdeck`, assuming a clone that could not happen.

**Change**: the step now names two concrete places to get the URL — the **Code** button on the
repository's GitHub page, or its Open Exchange listing — and shows `git clone <that URL>` as its own
line. **The real URL remains an author action**, recorded with the other three in `docs/contest.md`
§7: this repository has no remote configured, so nothing in it knows its own published address.

### The safety finding

The warning that `/csp/fd-demo` is deliberately unauthenticated lived only in the IPM section. The
reader learned at line 254 that **the Docker install creates it too** — 200 lines after running the
command. "If my Docker daemon publishes ports beyond loopback, I would have wanted to know that
before the command, not 200 lines after it."

**Change**: stated in the install section, immediately after sign-in — what the demonstration objects
are, that one of them is deliberately unauthenticated and why, and that the IPM path creates nothing
of the sort unless asked.

### The trap in a fix

The `.env` example, added for Windows readers after pass 1, carried **two** lines: the port and the
image. A reader arriving there for a port conflict who pasted the block would silently switch to IRIS
for Health — a different image, 5 GB — via a command that does not pass the `--build` the README says
that switch needs.

**Change**: the port-conflict `.env` example now carries the port and nothing else.

### Contradictions and collisions

| Finding | Change |
|---|---|
| "FlightDeck requires the official **SysAdmin API v2**" is contradicted two paragraphs later by "2026.1 … exposes API v1 only. FlightDeck translates what v1 offers" | "needs the official SysAdmin API — v2 for the full portal, v1 for a reduced one" |
| The reproduction `curl` uses `/api/flightdeck/**v1**/session` in a section about needing **v2**. Two different version numbers sharing a section | A parenthesis: that `v1` is FlightDeck's own API version, and the tab header can be any string, because it is how safe mode is scoped to one tab |
| "The **fourth** column … the **fifth** is …" forced the reader to count columns that already have names | Names them instead |
| "**One command**" as a heading over a block of three | "One command, after cloning", with the install line commented as the install |
| `zpm "load …"` given with no note that IPM must already be present | "This path needs IPM (ZPM) already installed on the instance — the `-zpm` Community images carry it" |
| "Backend unit tests (inside the container)" with no way in | `docker compose exec iris iris session iris -U USER`, then the command |
| The ninety-second tour forward-referenced two later sections | Made self-contained; only the Troubleshooting link stays, which the reader said "is doing real work" |

### What the pass said was clear

The six domains; what FlightDeck declines ("the journal passage is the clearest reasoning in the
document", and the reader checked that 262+0+11 and 200+62+11 both reach 273); the REST executor;
sign-in and safe mode ("answered every security question I had formed while reading the intro, in the
order I had formed them"); Day-1 verification; the new claims-to-enforcement table ("it changed how
much of the rest I took on trust"); and the paragraph on why disabled controls name a version, which
"pre-empted the exact objection I was forming".

### The two-sentence test, pass 2

The reader's summary after the first paragraph was accurate on every operational point. What it still
did not convey: that there is a second install path at all, and that the container is not neutral —
it creates demonstration objects. The second is now stated in the install section; the first is left
deliberately, because the first paragraph is capped at two sentences and the interaction model earns
them.

---

## Pass `human` — pending

**Reader**: knows IRIS, has never seen FlightDeck. **This is the recorded result for SC-005** and is
one of the three author actions in `docs/contest.md` §7. To be run after the agent passes reach zero
questions, timed from first opening the repository page to a signed-in portal with content on every
domain screen, recording every question raised whether or not it blocked.
