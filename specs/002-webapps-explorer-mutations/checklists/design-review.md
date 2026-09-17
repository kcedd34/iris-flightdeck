# Design Review: web applications, REST explorer, dry-run and trail (T084)

**Feature**: [spec.md](../spec.md) · **Reviewed**: 2026-09-17 · **Build**: Vite dev server over the
IRIS 2026.2 CE dev install, then `frontend/dist` rebuilt after the fixes below

Same precedence as feature 001's review: `docs/prototype.html` prevails over design §4's text for the
components it implements. The dry-run's `CURRENT` and `COMMANDED` column labels are the prototype's
and design §6's own words, not decorative all-caps.

**Screens reviewed visually**, each in **dark** and **light** at 1440 px:
- web applications list with exposure markers and the inspector with links;
- web application edit form (safe mode off);
- dry-run, reinforced grade, with impact;
- percent class access list;
- REST APIs list, specification viewer, request builder and response;
- session trail (empty state).

The pattern catalog, its maximum-grade dry-run and the trail with entries were covered by axe and
e2e only, not by a visual pass.

**Automated gates**: `check:tokens`, `contrast` (ok), axe WCAG 2.1 AA with 0 violations on all of the
above in both themes (`e2e/audit.spec.ts`, `e2e/pattern.spec.ts`), reduced-motion e2e for the
dry-run reveal (`e2e/pattern.spec.ts` scenario 4).

| # | Anti-pattern (design §7) | Dark | Light | Evidence |
|---|---|---|---|---|
| 1 | Decorative color, gradient, illustration, brand color | pass | pass | Color only in markers (caution, warning), the dry-run's actual/commanded values and the Live state |
| 2 | Semantic color outside its meaning | pass | pass | `state-warning` only on the open-API marker and errors; `state-caution` on unauthenticated markers and "No specification"; `state-actual`/`state-commanded` only on changed dry-run values |
| 3 | Content chopped into identical rounded cards | pass | pass | Lists are flush rows with hairlines; the specification viewer groups by path with hairlines, no cards |
| 4 | Shadow on a structural surface | pass | pass | Only the dry-run and trail (floating layers) carry `--shadow` |
| 5 | One radius for everything | pass | pass | 0 on lists, inspector, diff; 2 px on controls and the response body; 6 px on the dry-run and trail |
| 6 | All-caps labels, eyebrows, middle-dot chains, arrows on buttons | pass | pass | Middle dot only inside marker texts that join two facts ("Open API · no authentication") and the trail's status prefix, as in the prototype's palette context; no arrows |
| 7 | Fade-and-rise, hover elevation, transitions over 200 ms | pass | pass | The dry-run reveal (160 ms slide, 240 ms decaying flash) is design §6's single declared exception, confined to `mutation/dryrun.css` by `check:tokens`; instant under reduced motion |
| 8 | Centered spinner | pass | pass | Inspector skeleton rows; dry-run says "Reading the current state from the instance." |
| 9 | Proportional numerals in numeric columns | pass | pass | List counts, REST status, time and body size use `.num` |
| 10 | Mono in UI labels; proportional in log content | pass | pass | Mono for paths, names, dispatch classes, methods, headers and values; labels in Plex Sans |
| 11 | CDN fonts | pass | pass | Unchanged from feature 001 |
| 12 | Empty state without cause and next action | pass | pass | Namespace with no REST service points to FlightDeck's namespace; trail empty state says what appears there |
| 13 | IRIS error replaced by portal text | pass | pass | Rejections show IRIS text verbatim; REST responses shown in full without interpretation |
| 14 | Suppressed focus outline | pass | pass | Focus ring visible on dry-run and trail controls; the scrollable diff region is now focusable |
| 15 | Emoji | pass | pass | None |

## Defects found in this review and fixed

1. **Diff region not reachable by keyboard** (axe `scrollable-region-focusable`, both themes). A long
   diff scrolls inside the dry-run, and keyboard users could not scroll it. The region is now
   focusable, with the accessible name "Differences" (or "Request to send" in request mode).
2. **List search field on browser styling.** In dark theme the filter field of every domain list
   showed the browser's grey fill instead of the canvas surface. It now uses the same tokens as the
   filter selects, with a `text-secondary` placeholder.
3. **Password inputs unstyled in forms.** The new `SecretEditor` rendered a browser-styled field;
   `.oform` now styles `input[type="password"]` like text inputs.
4. **Acronym lowercased in placeholders.** "Filter rest services" now reads "Filter REST services".
