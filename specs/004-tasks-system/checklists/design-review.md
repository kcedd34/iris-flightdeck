# Design review: Tasks and Operating System Management (T082)

**Reviewed**: 2026-09-18 · **Against**: `docs/design.md` §4 (layout), §5 (the instrument cluster) and
§7 (anti-patterns) · **Themes**: dark and light, both checked.

## §5, point by point — the instrument cluster

| Rule | State |
|---|---|
| Primary reading is the number: 40px, weight 500, tabular numerals, `text-primary` | `.ins-v` sets exactly that |
| Colour changes only on a crossed threshold, and the state glyph appears with it | `data-band` drives the colour; `Glyph` renders only for caution and warning |
| Secondary reading is the series: 1.5px stroke in `state-actual`, no axis, grid, legend, fill or gradient | `Series.tsx` strokes and nothing else; no fill call exists in the module |
| **Canvas, not a declarative SVG chart library** | `Series.tsx` draws on `<canvas>`; the e2e asserts the element is `CANVAS`; no chart dependency was added to `package.json` |
| The series slides continuously, with no entry transition per point | The canvas is redrawn from the window each tick; no CSS transition touches it |
| A crossed threshold does not blink and does not animate | No keyframes exist for the cluster; the catalog e2e asserts `animationName` is `none` |
| The instruments share one geometry | One component, one stylesheet; the series has a fixed height so a reason or an absent value does not change the row |

## §4 — layout

- The cluster sits at the top of the domain's entry section, above the process list, as §5 shows it.
- Section tabs appear on both domains, which hold several entity types each.
- List and inspector keep the shared pattern's proportions; nothing in this feature sets its own.

## §7 — anti-patterns

| Anti-pattern | State |
|---|---|
| A number with no unit or scope | Each instrument carries its unit, and disk names the database the percentage belongs to ("IRISLIB 0%") |
| A spinner in place of data | Forbidden by the async module and asserted by two e2e tests; the disk number is never replaced |
| An alarm that performs | No blink, no animation, no sound |
| A control whose disabled state is unexplained | Every disabled control carries its reason: the capability map's, the policy's, or the object's own |
| Invented precision | The seize table is shown with the platform's own counters and no threshold; an unknown duration renders as unknown, never as zero |

## Both themes

Checked on the instruments, processes, tasks and system sections in dark and light: contrast passes
(`npm run contrast`), and the series takes its colour from the token through `currentColor`, so a
theme change repaints it rather than keeping a baked colour.

## Notes

- The disk instrument reads 0% on a stock container because every database is unlimited against a
  large filesystem. The number is arithmetically right and the detail line names the database, so the
  screen is honest; a demo that inflated it would be inventing a fact.
