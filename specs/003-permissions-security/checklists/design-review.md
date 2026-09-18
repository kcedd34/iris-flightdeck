# Design Review: permissions, security and the attention list (T077)

**Feature**: [spec.md](../spec.md) · **Reviewed**: 2026-09-17 · **Build**: `frontend/dist` after the
fixes below, against the IRIS 2026.2 CE install

Same precedence as before: `docs/prototype.html` prevails over design §4's text for the components it
implements. Nothing in this feature adds a component the prototype does not already describe: every
screen is `DomainSection`, `SingletonSection`, `LinksPanel`, `ObjectForm` and the one dry-run.

**Screens reviewed visually**, in **dark** and **light** at 1440 px:
- permissions: users list and inspector (chain, privileges with provenance, SQL panel), roles
  inspector, resources;
- security: wallet collection with its secrets and users, encryption (read-only with the declined
  controls), TLS list and its connection test dialog;
- home panel with the attention list, empty and with an expiring credential.

**Automated gates**: `check:tokens`, `check:dialect` (now covering `declined`),
`check:mutation-boundary`, `check:secrets`, `contrast`, and axe WCAG 2.1 AA with **0 violations** on
all fifteen new sections, the two singleton sections, the parameterised panel, the dry-run and the
home panel, in both themes (`e2e/audit.spec.ts`), plus the reduced-motion test from feature 002.

| # | Anti-pattern (design §7) | Dark | Light | Evidence |
|---|---|---|---|---|
| 1 | Decorative color, gradient, illustration, brand color | pass | pass | Color appears on markers (expired warning, expiring caution), the dry-run's changed values and the Live state |
| 2 | Semantic color outside its meaning | pass | pass | `state-warning` on expired credentials and auditing off; `state-caution` on expiring, disabled and public markers |
| 3 | Content chopped into identical rounded cards | pass | pass | Lists are flush rows; link groups and panels are hairline-separated sections |
| 4 | Shadow on a structural surface | pass | pass | Only the dry-run and trail carry `--shadow` |
| 5 | One radius for everything | pass | pass | 0 on lists and panels, 2 px on controls, 6 px on floating layers |
| 6 | All-caps labels, eyebrows, middle-dot chains, arrows | pass | pass | Chains read "through FD_Demo_L1, FD_Demo_L2" and "via …", which are sentences, not metadata chains |
| 7 | Fade-and-rise, hover elevation, transitions over 200 ms | pass | pass | Unchanged; the dry-run reveal is still the only orchestrated motion |
| 8 | Centered spinner | pass | pass | Skeleton rows; the new applying state is a sentence, not a spinner |
| 9 | Proportional numerals in numeric columns | pass | pass | Counts, days remaining and ports use `.num` |
| 10 | Mono in UI labels; proportional in log content | pass | pass | Mono for names, roles, resources, files and ports; labels in Plex Sans |
| 11 | CDN fonts | pass | pass | Unchanged |
| 12 | Empty state without cause and next action | pass | pass | Every new section has one; the attention list says why it is empty |
| 13 | IRIS error replaced by portal text | pass | pass | The TLS test shows the platform's own error; refused link groups show the official message |
| 14 | Suppressed focus outline | pass | pass | Focus ring on the new controls, including the parameter selects |
| 15 | Emoji | pass | pass | None |

## Defects found in this review and fixed

1. **A group's reason was hidden when the group answered.** An account whose roles may also come from
   LDAP had its note dropped. Reasons are now shown whenever the server sends one.
2. **The dry-run listed who loses access but not what becomes unreachable.** UC05-2 asks for both;
   impact objects are rendered now.
3. **The consequence text appeared only at the maximum grade**, so the own-session warning ("takes
   effect in this session immediately") was invisible at the reinforced grade. It is shown whenever
   a rule declares one.
4. **"1 secrets"** on a wallet collection: the marker now has a singular variant.
5. **The inspector subtitle showed raw entity type ids** for the new types; they have labels.
6. **The dry-run said nothing while applying.** The TLS test takes ten seconds; it now shows an
   applying state with what the operation says about the wait.

## Noted, not a defect

- The home panel reads "Security and secrets 81 of 89": the eight operations FlightDeck declines are
  not counted as available to the user. The reason is one click away on the encryption section, and
  `docs/api-coverage.md` lists them as declined rather than missing.
