# Design Review: docs/design.md §7 anti-patterns (T089)

**Feature**: [spec.md](../spec.md) · **Reviewed**: 2026-09-17 · **Build**: frontend `dist` after T089 fixes, served by the IRIS for Health 2026.2 install

**Precedence applied, recorded once.** `docs/prototype.html` prevails over design §4's text for the
components it implements (design §10). That settles three points:
- **Wording**: "Safe mode", "Live — changes enabled", "CPU", "Memory", "Disk". There are no
  all-caps labels; "CPU" is an acronym.
- **Middle-dot metadata**: the glareshield identity (`IRIS 2026.2 CE · USER`) and the palette
  context (`Web application · USER`) take it from the prototype (`IRIS 2026.1 CE · IRISAPP`,
  `IRISAPP · web app`). Nowhere else joins metadata with a middle dot.
- **Spacing**: the prototype uses spacing off the 4px scale, so spacing is reviewed visually, not
  by script.

**Screens**:
- sign-in
- home
- domain route with inspector
- command palette
- safe-mode disarm popover
- live (disarmed) state
- re-authentication overlay with error
- inspector overlay at 1024px

Each was checked in **dark** and **light** (16 captures) plus the automated gates:
- `check:tokens`
- `contrast`
- axe on home and all six domains in both themes
- the reduced-motion e2e
- the keyboard/focus-ring e2e

| # | Anti-pattern (design §7) | Dark | Light | Evidence |
|---|---|---|---|---|
| 1 | Decorative color, gradient, colorful illustration, brand color | pass | pass | No gradients or illustrations. Semantic colors appear only on the Live state, warning glyphs, the selected rail/tab bar and caution text. `check:tokens`: no color literal outside `tokens.css` |
| 2 | Semantic color used outside its meaning | pass | pass | `state-warning` only on Live and error glyphs; `state-selected` only on active rail/tab bars and focus ring; `state-caution` only on the palette's safe-mode lock label and degraded notice |
| 3 | Content chopped into identical rounded cards with the same shadow | pass | pass | Home domains are a flush grid with hairlines (radius 0, no shadow); identity is one bordered panel |
| 4 | Shadow on a structural surface | pass | pass | The single `--shadow` is used only by `.float` (palette, popover, re-auth, overlay inspector, tooltips) |
| 5 | One border radius applied to everything | pass | pass | 0 on panels, lists and inspector; 2px on buttons, fields and tags; 6px on floating layers. `check:tokens` enforces the set |
| 6 | All-caps labels, eyebrow text above titles, middle-dot metadata chains, arrows appended to buttons/links | pass (with the prototype precedence above) | pass | No `text-transform: uppercase` (script); no eyebrow labels; no arrows on buttons or links. The only arrow is in the fixtures-only form, which is not shipped (`check-no-fixtures`) |
| 7 | Fade-and-rise entrances, hover elevation, transitions over 200ms | pass | pass | Transitions 90ms (controls), 120ms (layers), 160ms (live rule). No entrance animations or hover elevation. Reduced motion gives 0s everywhere (e2e) |
| 8 | Centered circular loading spinner | pass | pass | None. Vitals use a shape-preserving skeleton bar; sign-in uses a disabled button labeled "Signing in"; the palette shows "Searching" text |
| 9 | Proportional numerals in numeric columns or instruments | pass | pass | Vitals, capability counts and the palette result count use `.num` (`tabular-nums`) |
| 10 | Mono in UI labels; proportional in log content | pass | pass | Mono only for system literals: instance identity, usernames, entity names, operation paths, kbd. Labels are Plex Sans |
| 11 | CDN-loaded fonts | pass | pass | IBM Plex Sans/Mono bundled from `@fontsource` (latin subset) into `dist/assets` |
| 12 | Empty state that only says "no results" | pass | pass | Every empty state has a cause and a next action (`EmptyState` requires both); palette no-match lists searchable domains and shortcuts |
| 13 | IRIS error replaced by generic portal text | pass | pass | Sign-in shows IRIS `raw` text for unexpected errors; palette groups show the official API error text (for example the LDAP `<INVALID OREF>` for `%Operator`) |
| 14 | Suppressed focus outline | pass | pass | `:focus-visible` 2px `state-selected`, offset 2px; e2e checks every tab stop |
| 15 | Emoji anywhere | pass | pass | None in `src/` or UI text |

## Defects found in this review and fixed

1. **Glareshield controls clipped below 1280px.** At 1024px the username and "Sign out" were cut
   off. Below 1280px the brand text and theme label are now hidden and gaps tightened: overflow is
   0px and "Sign out" ends at 1008px.
2. **Overlay inspector heading unstyled.** Below 1280px the entity name used the browser's default
   heading size because only `.inspector h2` was styled. `.inspector-overlay` now shares the rules.
3. **Contrast (design §8), found by `scripts/contrast.mjs`.** `text-muted` is 2.84–3.56:1 on every
   surface in both themes, and dark `state-warning` on `surface-float` is 4.15:1.
   - No token hex was changed.
   - Readable text moved to `text-secondary`: vital labels, palette headings, context, hints and
     disabled reasons, inspector field labels, empty-state descriptions, domain counts.
   - `text-muted` stays for what design §3.1 defines it as: disabled controls, placeholder, absent
     value.
   - Error text in floating layers is `text-primary` with the warning glyph.

**Open design question for the author.** The prototype itself uses `text-muted` for readable
labels, which fails WCAG AA. This review followed design §8 (quality floor, "never cut") over the
prototype's use of the token. If a lighter muted tone is wanted for labels, the token table needs a
new value that reaches 4.5:1.
