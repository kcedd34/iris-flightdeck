# Design review: Unified Log Stream (T067)

**Reviewed**: 2026-09-18 · **Against**: `docs/design.md` §4 (layout), §6 (density and typography) and
§7 (anti-patterns) · **Themes**: dark and light, both checked.

## §4 — layout

| Rule | State |
|---|---|
| The domain uses the shipped list-and-inspector pattern; nothing here sets its own proportions | `Stream.tsx` composes `ListInspector`; `EventInspector` uses `.pinspector`, the same shell as every other inspector |
| Section tabs for a domain with more than one entity type | Three: stream, journal, audit events. The shell test no longer special-cases logs, because it now has them |
| The work header states what is on screen, including a filter that arrived from elsewhere | A correlated open renders `.logs-correlated` naming the task and the window, with a Clear that returns to the plain stream |
| Filters sit above the list, in the shared filter bar | `.dlist-filters`, the same class the other domains use |

## §6 — density and typography

| Rule | State |
|---|---|
| The stream is a dense table-like list: one row per event, four columns of fixed meaning | `.logs-row` is a 190px / 96px / 72px / 1fr grid at 12px, 4px vertical padding — the densest list in the portal, which is what a log wants |
| Timestamps are tabular so columns of digits align | `.logs-at` sets `font-variant-numeric: tabular-nums` |
| The message is the free column and truncates rather than reflowing the row | `.logs-msg` ellipsises; the whole line is in the inspector and in the original record |
| Monospace only where the content is machine text | The message heading and the raw record are `mono`; labels and notes are not |
| Secondary information is 11px `text-secondary`, never a second colour | `.logs-note`, `.logs-state`, `.logs-source-*` all take exactly that pair |

## §7 — anti-patterns

| Anti-pattern | State |
|---|---|
| A number with no unit or scope | The suppression note names both the count and its reason; the share note says *of each selected source*; the time note names the instance's zone |
| A spinner in place of data | The stream keeps the page it has while the next one is read; the inspector's record says "Reading…" only where no record has ever been shown for that event |
| An alarm that performs | No keyframes, no blink, no sound anywhere in `logs.css`. Severity is a colour and a word, painted from the state tokens (`--state-warning`, `--state-caution`, `--state-actual`) — no new colour was added |
| A control whose disabled state is unexplained | A source that cannot be read is listed with its reason and where to enable it; the journal section on the v1 dialect states the reason feature 001 recorded |
| Invented precision | Severity is mapped from the level the source itself states, never derived from the message text (`LogSeverity` asserts this). A source that states no level gets `unknown` |
| A gap filled to look complete | An unrecoverable original says so where the record would be; a line that did not parse is shown whole and marked. Both are exercised in the pattern catalog (T065) |

## The suppression note is information, not an alarm

`logs-suppressed` renders inside `.logs-state` — the same 11px `text-secondary` line that carries the
follow mode and the time zone — not as a banner, not in a state colour, and not with a role that
interrupts. It reports a fact about the page the reader is looking at. The one line that *does* take
a state colour is `.logs-allout` (`--state-caution`), used where **every** selected source is out,
because then the screen has nothing to show and silence would read as "no events".

## `unknown` severity

It is outside the ordering and must look neither like an alarm nor like "fine". It takes
`--text-secondary` rather than the muted token: the word is information about the event, and the
muted token is for placeholders and disabled controls (§3). This was a defect first — it started on
`--text-muted` and failed the axe contrast check in the light theme — and the fix is recorded in the
stylesheet beside the rule, so it is not undone by someone tidying tokens.

## Live region

The list carries `aria-live="polite"` **only while following**, and the follow itself pauses when the
tab is hidden. A stream that announced every arriving line while unfollowed would be §7's performing
alarm in an accessibility costume.

## Both themes

Checked on the stream, journal and audit-events sections in dark and light: `npm run contrast` and
the axe pass in `logs.spec.ts` (both themes) are clean, including the inspector's raw record, the
source panel with an unavailable source, and the correlated-open line.

## Notes

- On a stock Community instance the alerts source is normally absent and says so. That is the screen
  an evaluator sees first, and it is a designed state rather than an error path: it names what an
  alerts log is and where it comes from, so the absence teaches something.
- The journal and audit-events sections reuse the domain pattern wholesale; nothing in this feature
  extends the pattern. The two additions of feature 004 (instruments, asynchronous values) were the
  last ones needed.
