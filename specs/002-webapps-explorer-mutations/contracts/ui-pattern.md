# UI Contract: Domain Screen Pattern and Shared Mutation Layer

**Feature**: `002-webapps-explorer-mutations` | **Binding for**: this feature and features for
permissions, security, tasks and system.

This contract is what a later domain may rely on and must use. Anything a domain needs that is not
here is a change to this contract, made in the pattern modules, not a local component.

## 1. Modules and what a domain may import

| Module | Public surface | Domains may |
|---|---|---|
| `src/pattern/DomainList` | `<DomainList entityType filters columns />` | use |
| `src/pattern/ListRow` | rendered by `DomainList`; markers from the server | not render rows themselves |
| `src/pattern/Inspector` | `<Inspector entity sections />`, 96 px label column | use; add sections |
| `src/pattern/LinksPanel` | `<LinksPanel entity />` from `GET …/links` | use |
| `src/pattern/ActionBar` | `<ActionBar entity actions />` | use; actions reference `operationId`s |
| `src/mutation/useMutation` | `start({operationId, keys, proposed | request})` | use |
| `src/mutation/TrailPanel` | trail view and export | open from palette or notice |
| `src/mutation/*` (anything else) | internal | **never** (gate `check:mutation-boundary`) |

Domains never import `@radix-ui/react-dialog`, never use `role="dialog"` or `alertdialog`, never
read or write `sessionStorage`, never call `window.confirm`. Declared exceptions: palette,
re-authentication overlay, inspector overlay below 1280 px.

## 2. Geometry and tokens (docs/design.md §4, §6; docs/prototype.html prevails)

- List min 480 px, inspector 420 px; below 1280 px the inspector is an overlay (feature 001).
- Inspector label column 96 px fixed; numeric values right-aligned tabular, text left-aligned.
- Section tabs only where the domain has more than one entity type (web apps: yes, 3 tabs).
- Markers: icon plus text; tone `caution` uses `state-caution`, `warning` uses `state-warning`.
  Never color alone. Web application exposure markers (research R10), all shown in the list row:
  `open-api` "Open API · no authentication" (warning), `no-auth` "No authentication" (caution),
  `static-only` "No authentication · static files only" (caution); "only" is appended when
  Unauthenticated is the only method.
- Tokens only; no color literal (gate `check:tokens`).

## 3. Action bar states

For each action, in this order of precedence, the first that applies decides the state:

| Condition | State | Text |
|---|---|---|
| `available` false | disabled | capability `reason` (§9 message 8 plus withheld reason) |
| `allowed` false | disabled | §9 message 2 |
| object capability field false (Constitution IX) | disabled | the API's statement |
| self-protection known at render (`isFlightDeck` and a blocked action) | disabled | §9 message 4 |
| mutating and safe mode armed | enabled; activating offers disarm then continues into the dry-run | §9 message 3 |
| otherwise | enabled | — |

Controls are never hidden. The server re-checks everything on `apply`.

## 4. Dry-run view (the only confirmation UI in the product)

```text
Apply changes to web application  /csp/fd-demo
                   CURRENT                         COMMANDED
Description        FlightDeck demo: …              Demo application
Enabled            true                            false            ← changed rows only in color
IMPACT
Every user who can reach namespace USER (no resource restricts it)
Type  /csp/fd-demo  to confirm   [____________]      [Cancel] [Apply]
```

- `CURRENT` values `state-actual`, `COMMANDED` values `state-commanded`, unchanged rows `text-muted`
  in both columns.
- Reveal: `COMMANDED` column slides 8 px from the right in 160 ms; changed rows' background decays
  over 240 ms; once, on open; instant under `prefers-reduced-motion`.
- Impact block below the diff, same view. States: list, "none", or "could not be determined:
  <reason>".
- Grade row on the same line as the buttons:
  - simple: no input; `Apply` enabled;
  - reinforced: "Type <target> to confirm"; `Apply` enabled on exact match;
  - maximum: same, plus a checkbox with the consequence text; both required.
- `Apply` goes from `text-muted` to the achromatic primary fill; it never changes hue.
- Words: button `Apply`, notice `Applied`, trail `Applied`. Failures: `Failed`; server blocks:
  `Blocked`.
- Secret rows show `changed` or `unchanged` in both columns, never a value.
- Request mode (REST test POST/PUT/PATCH/DELETE): no `CURRENT` column; a single `REQUEST` block with
  method, path, query, headers (masked) and body; the stated reason "A test request has no current
  state to compare. This is exactly what will be sent."; same grade row (DELETE reinforced: type
  the path).
- `noChange`: the view shows §9 message 18 and no `Apply`.
- `blocked`: the view shows §9 message 4 and no `Apply`; the attempt is recorded.
- `STATE_CHANGED` (409): the view replaces its rows with the fresh preview, shows §9 message 17
  above them, clears the typed confirmation, and requires confirming again.
- Rejection: the dialog closes back to the form with values kept; the IRIS text is shown verbatim
  under the form; the trail has a `Failed` entry.
- Focus: opens on the first changed row's heading; typed input receives focus for reinforced and
  maximum; `Escape` cancels; focus returns to the invoking control.

## 5. Session trail

- Reachable from the palette ("Session trail") and from the `Applied` notice.
- Header states: "This trail is local to this browser tab and does not replace IRIS auditing."
- Entries newest first: time, result word, target, operation summary; expanding shows the rows (or
  the request) as they were displayed.
- Export button downloads the trail document (data-model §3.5).
- When storage is unavailable: "This trail is kept in memory and will not survive a reload."
- Cleared on sign-out and on detected session expiry; no leave-page warning.

## 6. Test hooks (stable `data-testid`)

`domain-list`, `list-row`, `marker-<id>`, `inspector`, `links-panel`, `links-group-<provider>`,
`action-<operationId>`, `dry-run`, `dry-run-row-<field>`, `dry-run-impact`, `dry-run-confirm-input`,
`dry-run-acknowledge`, `dry-run-apply`, `dry-run-message`, `trail-panel`, `trail-entry`,
`trail-export`, `rest-service`, `rest-operation`, `rest-execute`, `rest-response`, `rest-copy-curl`,
`rest-roles-note`.

## 7. REST test response panel

- Before running: when the resolved application grants roles beyond the user's login roles, a note
  states "This application grants roles to real calls (<roles>). Test requests run with your login
  roles, so the result can differ from a real call."
- After running: status, elapsed time, headers, body (formatted, 1 MB cap with size), the roles mode
  used, and the same note when `grantsNotApplied` is non-empty; a 403 from `<PROTECT>` names what
  could not be read.
