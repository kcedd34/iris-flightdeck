# Contract: what the README must contain, and in what order

This is the ten required elements turned into statements a gate can check. `scripts/build/check-readme.py`
implements it and runs inside `scripts/build/check-generated.sh`, beside the other gates.

The gate exists because the README is the one artifact in this repository that carries checkable
facts and is never compiled. Everything else that makes a claim — the capability map, the
descriptors, the coverage of the six domains — already fails a build when it drifts.

## What the gate checks, and what it deliberately does not

A gate over prose can enforce **presence, order and arithmetic**. It cannot enforce that a sentence is
clear, or that two sentences lead with the interaction model. Those are the cold read's job (SC-005),
and the contract says so rather than pretending otherwise.

So: the gate is the floor, the cold read is the ceiling, and neither substitutes for the other.

## The ten elements, in order

Each element is identified by an **anchor** — a heading or a marker the gate finds. The gate asserts
that every anchor is present, and that they appear in this relative order.

| # | Element | Anchor | Checked |
|---|---|---|---|
| 1 | What it is, two sentences, leading with the interaction model | The first paragraph after the `# ` title | Present; at most **two** sentences; appears before any list; contains no bulleted feature |
| 2 | The instrument cluster, above the fold | An image reference to `docs/img/instruments.*` | Present; appears **before** the installation heading; within the first 1200 characters of the file |
| 3 | Installation, one command first, package second, port conflict documented | `## Install` … with the container path first | The container block appears before the package block; a port-conflict subsection exists **inside** the installation section, not in troubleshooting |
| 4 | The six contest domains, one line each | `## The six domains` | Present; exactly **six** list items; each names a domain and what the portal does there |
| 5 | What makes it different | `## What makes it different` | Present; contains all five claims: command palette, entity graph, dry-run, safe mode, log stream |
| 6 | Compatibility | `## Compatibility` | Present; names SysAdmin API **v2** as required; names both supported versions with their release channel; the counts satisfy `allowed + unavailable + declined = total` for each, and each count is attributed to a named version |
| 7 | REST executor confinement | A statement that it is confined to the instance and **not an outbound proxy** | Present; the exact phrase "not an outbound proxy" appears |
| 8 | Declined operations, as decisions | `## What FlightDeck declines to do` | Present; every operation in `FlightDeck.Capability.Policy` is accounted for by its group; the journal statement is present and **separate** from the declined list |
| 9 | The idea link | A line naming the InterSystems Ideas Portal | Present. The URL itself is an author action: the gate accepts the final wording with the link **or** with the declared placeholder marker, and prints a warning while the placeholder is there, so it is never forgotten silently |
| 10 | MIT licence | `## License` and the `LICENSE` file | Heading present; the word MIT present; `LICENSE` exists in the repository root |

## Element 1 in detail

The hardest to check and the most important. The gate enforces what it can:

- it is the first paragraph after the title;
- it is **at most two sentences**, counted on sentence-ending punctuation outside of code and links;
- no list, image or heading comes between the title and it.

It cannot enforce "leads with the interaction model". That is asserted by the cold read: a reader who
has finished the first paragraph must be able to say how the portal is operated. The contract records
the intent so a later edit that turns it into a feature summary is a visible regression rather than a
style preference.

## Element 6 in detail

The compatibility numbers are the README's most perishable content, and they are the ones a judge can
check fastest. The gate asserts:

- the total matches the operation count the capability spec declares;
- the declined count matches the number of operations in `FlightDeck.Capability.Policy`;
- for every version block, `allowed + unavailable + declined = total`;
- each block names the version the numbers were read from.

It does **not** assert the per-version `allowed` and `unavailable` against a live instance: that would
require both versions running on every build (research R1). The arithmetic and the attribution catch
the realistic failure, which is a number carried forward after the map changed.

## Element 8 in detail

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
check-readme: element 4 (the six domains) — expected 6 list items under "## The six domains", found 5
check-readme: element 6 (compatibility) — IRIS CE 2026.1: 200 + 62 + 11 = 273, declared total 274
check-readme: ok (10 elements, in order; idea link pending — author action)
```

An element that is present but out of order is reported as an order failure naming both neighbours,
because the order is the requirement that a well-meaning edit is most likely to break.
