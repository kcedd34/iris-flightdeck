# UI Shell Contract

This is the contract between the shell and every future domain feature. Domain features plug into
it; they do not change it.

## Routes (basename `/flightdeck`)

| Path | Renders |
|---|---|
| `/` | Home: instance identity, capability summary, attention-items region (empty state) |
| `/<domain>` | Redirects to `/<domain>/<first section>`, or renders the single section for `logs` |
| `/<domain>/<section>` | Work header (title + tab strip when more than one section), list area, inspector |
| `/<domain>/<section>?inspect=<entityType>:<name>` | Same, with the inspector showing that entity |
| `/__fixtures__/reauth` | Fixtures build only (FR-017a). Absent from production bundle |
| anything else | Not-found empty state inside the shell (never a blank page) |

Domain ids and order: `web-apps`, `permissions`, `security`, `tasks`, `system`, `logs`.
Section ids are in `frontend/src/shell/sections.ts`, generated from spec Assumptions.

## Geometry (binding, `docs/design.md` §4)

| Region | Rule |
|---|---|
| Glareshield | Height 44px, fixed top, `z-index` above floating layers. Left: identity. Center: vitals. Right: theme toggle, safe-mode indicator, user menu |
| Disarmed rule | 2px full-width bottom rule in `state-warning` |
| Rail | Width 56px, fixed left, six icon buttons, active marked by a 2px `state-selected` inner-edge bar, tooltip label on hover or focus |
| Work header | Title (24px/500) and optional tab strip. Active tab has a 2px `state-selected` bottom rule |
| List | `min-width: 480px` |
| Inspector | Width 420px column at 1280px and wider; overlay (6px radius floating layer) below 1280px. Label column 96px |

## Domain plug-in interface (for later features)

```ts
interface DomainSectionModule {
  domain: DomainId;
  section: string;
  List: React.ComponentType;                       // renders inside the list area
  Inspector: React.ComponentType<{ entity: EntityRef }>;
  emptyState: EmptyStateSpec;                      // cause + next action, required
}
```

In this feature every section is registered with `PlaceholderSection`, which renders:
- in the list area, an `EmptyState` titled "Not available in this build yet", with the cause
  "The <Section> section ships with the <Domain> screens." and the next action "Open the command
  palette (Ctrl+K) to find entities across the instance.";
- in the inspector, when `inspect` is set, the entity identity (type, name, domain), plus
  "Detail view for <entityType> arrives with the <Domain> screens."

## Request headers (all API calls)

`X-FlightDeck-Tab: <uuid>` and `X-FlightDeck-Safe-Mode: armed|disarmed`, added by the single API
client `frontend/src/api/client.ts`. No other module may call `fetch`; a lint rule enforces this.

## Keyboard

| Keys | Action |
|---|---|
| Ctrl+K / Cmd+K | Open palette (works inside floating layers) |
| Esc | Close the topmost floating layer; focus returns to its opener |
| Arrow keys / Enter (palette) | Move / run |
| Tab order | Glareshield → rail → work header → list → inspector |

## Messages (exact, from `docs/prd.md` §9)

| Id | Text |
|---|---|
| 1 | Invalid credentials. Check your username and password. |
| 2 | Requires [PERMISSION] on [RESOURCE]. Ask your instance administrator for access. |
| 3 | Safe mode is on. Turn it off to make changes in this tab. |
| 8 | Not available on this IRIS version or edition. Requires [VERSION]. |
| 17 | This object changed on the server while you were editing. Review the updated differences before applying. |
| 19 | Entity search is unavailable right now. Portal actions are still available. |
