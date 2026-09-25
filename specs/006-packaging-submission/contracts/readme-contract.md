# Contract: what the README must contain, and in what order

This is the required elements turned into statements a gate can check. `scripts/build/check-readme.py`
implements it and runs inside `scripts/build/check-generated.sh`, beside the other gates.

The gate exists because the README is the one artifact in this repository that carries checkable
facts and is never compiled. Everything else that makes a claim — the capability map, the
descriptors, the coverage of the six domains — already fails a build when it drifts.

## What the gate checks, and what it deliberately does not

A gate over prose can enforce **presence, order and arithmetic**. It cannot enforce that a sentence is
clear, or that two sentences lead with the interaction model. Those are the cold read's job (SC-005),
and the contract says so rather than pretending otherwise.

So: the gate is the floor, the cold read is the ceiling, and neither substitutes for the other.

## The twelve elements, in order

Each element is identified by an **anchor** — a heading or a marker the gate finds. The gate asserts
that every anchor is present, and that they appear in this relative order.

This list was ten elements at feature 006. The idea link (then element 9) was dropped when it turned
out not to be a requirement of this contest, leaving nine. Three were added on 2026-09-25 for a reader
with a few minutes and no context: the fast path, the three-sentence paragraph under it, and the tour
that stands in for a video. The instrument cluster moved above "what it is", so it stays above the
fold under the new opening.

| # | Element | Anchor | Checked |
|---|---|---|---|
| 1 | Fast path | The list right after the `# ` title | At most **five** lines, each with a link; links to the live demo, the install, `docs/api-coverage.md`, `verification/functional-coverage.md` and `verification/README.md`; states the operation total the coverage document assigns, the verified / exempt / open counts `verification/functional-coverage.md` records, and the version `module.xml` declares |
| 2 | What it does that a management portal usually does not | The paragraph after the fast path | Exactly **three** sentences; mentions logs, security and the server |
| 3 | The instrument cluster, above the fold | An image reference to `docs/img/instruments.*` | The third block after the title, with only elements 1 and 2 above it; before the installation heading |
| 4 | What it is, two sentences, leading with the interaction model; then the no-video statement | The paragraph after the cluster | At most **two** sentences; above the installation heading, a statement that there is no video, linking to the tour |
| 5 | Installation, one command first, package second, port conflict documented | `## Install` … with the container path first | The container block appears before `zpm "install iris-flightdeck"`; the current version from `module.xml` is stated in bold; a port-conflict subsection exists **inside** the installation section, not in troubleshooting |
| 6 | The six contest domains, one line each | `## The six domains` | Present; exactly **six** list items |
| 7 | What makes it different | `## What makes it different` | Present; contains all five claims: command palette, entity graph, dry-run, safe mode, log stream |
| 8 | A tour, in place of a video | `## A tour, in place of a video` | Present; a numbered walk-through of at least six steps |
| 9 | Compatibility | `## Compatibility` | Present; names SysAdmin API **v2** as required; names both supported versions; the counts satisfy `allowed + unavailable + declined = total` for each, and each count is attributed to a named version |
| 10 | REST executor confinement | A statement that it is confined to the instance and **not an outbound proxy** | Present; the exact phrase "not an outbound proxy" appears |
| 11 | Declined operations, as decisions | `## What FlightDeck declines to do` | Present; every operation in `FlightDeck.Capability.Policy` is accounted for by its group; the journal statement is present and **separate** from the declined list |
| 12 | MIT licence | `## License` and the `LICENSE` file | Heading present; the word MIT present; `LICENSE` exists in the repository root |

The fold used to be checked as "within the first 1200 characters". The fast path's link targets add
characters that render as nothing, so the rule is now structural: nothing but elements 1 and 2 may
stand between the title and the cluster.

## Element 4 in detail

The hardest to check and the most important. The gate enforces what it can:

- it is the first paragraph after the instrument cluster;
- it is **at most two sentences**, counted on sentence-ending punctuation outside of code and links;
- only the fast path, the three-sentence paragraph and the cluster come between the title and it.

It cannot enforce "leads with the interaction model". That is asserted by the cold read: a reader who
has finished the first paragraph must be able to say how the portal is operated. The contract records
the intent so a later edit that turns it into a feature summary is a visible regression rather than a
style preference.

## Element 9 in detail

The compatibility numbers are the README's most perishable content, and they are the ones a judge can
check fastest. The gate asserts:

- the total matches the operation count the capability spec declares;
- the declined count matches the number of operations in `FlightDeck.Capability.Policy`;
- for every version block, `allowed + unavailable + declined = total`;
- each block names the version the numbers were read from.

It does **not** assert the per-version `allowed` and `unavailable` against a live instance: that would
require both versions running on every build (research R1). The arithmetic and the attribution catch
the realistic failure, which is a number carried forward after the map changed.

## Element 11 in detail

The gate reads `FlightDeck.Capability.Policy` structurally — the same way `check-coverage.py` reads
descriptors — and asserts that every declined operation belongs to a group the README names, and that
the README's group counts add up to the policy's total.

It separately asserts that the **journal statement is present and outside the declined list**, because
the journal is not declined: it is the one place where this project refuses to substitute a native
provider for a missing official operation, on the grounds that filtering records by the databases a
user may read is an authorization decision that belongs to IRIS. Flattening it into the declined list
would lose the only statement in the README that explains where native providers stop.

## Failure output

The gate names the element, what it expected and what it found, in the style of the existing gates:

```text
check-readme: element 6 (the six domains) — expected 6 list items under "## The six domains", found 5
check-readme: element 9 (compatibility) — IRIS CE 2026.1: 200 + 62 + 11 = 273, declared total 274
check-readme: ok (12 elements, in order)
```

An element that is present but out of order is reported as an order failure naming both neighbours,
because the order is the requirement that a well-meaning edit is most likely to break.
