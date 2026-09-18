# Data model: the records this feature produces

This feature writes no runtime data. It produces three **records**, and their shape matters because
each is written more than once and compared between runs. Prose that is not shaped is prose that
cannot be compared.

## 1. Verification run

One entry per clean install, appended to `verification/install-runs.md`.

| Field | Meaning |
|---|---|
| `date` | When the run was performed |
| `image` | The exact image identifier, including tag |
| `product` | `iris` or `irishealth`, as the portal reports it |
| `version` | As the portal reports it, not as the tag claims |
| `commands` | The commands run, verbatim, from the README |
| `readyAfter` | Seconds from `up` to the portal's own ready line |
| `screensWithContent` | Confirmation that every domain screen showed content on first access, and which screen was checked last |
| `capabilitySummary` | `allowed`, `unavailable`, `declined`, `total` as that instance reported them |
| `outcome` | `ok`, or what failed and what was changed in the README as a result |

**Rule**: `version` and `capabilitySummary` are read from the running portal, never from the tag or
from a previous run. An image tag is a claim about a version; the portal is the fact.

## 2. Cold-read pass

One entry per pass, in `verification/cold-read.md`.

| Field | Meaning |
|---|---|
| `pass` | `agent-1`, `agent-2`, … or `human` |
| `reader` | The reader's profile — for the human pass, "knows IRIS, has never seen FlightDeck" |
| `date` | When |
| `elapsed` | First view of the repository page to a signed-in portal with content on every domain screen |
| `questions` | Every question the reader could not answer from the README |
| `resolution` | For each question: the README change it produced, or why none was needed |
| `blocked` | Whether the reader ever stopped, and at which step |

**Rule**: a question is recorded even when the reader worked around it. The ones they answered by
guessing correctly are the dangerous ones, because the next reader guesses wrong.

**Rule**: the `human` pass is the recorded result for SC-005. Agent passes are the instrument that
gets the README there; they do not close the criterion on their own.

## 3. Checklist line

Every line of `docs/contest.md` §7, closed in place.

| State | Meaning | What it must carry |
|---|---|---|
| Closed | Done and verifiable | A pointer to where: a file, a run, a test project |
| Author action | Only the author can do it | What is needed, and the deadline |
| Not applicable | The line does not apply | Why |

**Rule**: there is no fourth state. A line with a tick and no pointer is not closed — it is a claim,
and the checklist exists precisely so that the last day is not spent re-verifying claims.

**The three author actions**, fixed here so they are not rediscovered:

| Action | Needs | Deadline |
|---|---|---|
| The Ideas Portal link | The URL, after the author publishes the idea | Before submission |
| The demo recording | The author records and publishes, following `docs/demo-script.md` | Before submission |
| The human cold read | A reader who knows IRIS and not FlightDeck | Before submission |

## 4. Documentation image

Not a record but a produced artifact, listed because it has a contract.

| Field | Meaning |
|---|---|
| `path` | `docs/img/<name>.png` |
| `producedBy` | The test that captures it |
| `screen` | The route and the element captured |
| `preconditions` | Signed in, theme, and the state the screen must be in (live readings, not loading) |

**Rule**: an image with no producing test may not be referenced by the README. A screenshot nobody
can regenerate is a claim about a screen that may no longer exist.
