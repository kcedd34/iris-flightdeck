# UI Contract: Domain Screen Pattern and Shared Mutation Layer

**Feature**: `002-webapps-explorer-mutations` | **Binding for**: this feature and features for
permissions, security, tasks and system.

This contract is what a later domain may rely on and must use. Anything a domain needs that is not
here is a change to this contract, made in the pattern modules, not a local component.

## 1. Modules and what a domain may import

As built (T082). Everything under `src/pattern/` is public to domains; under `src/mutation/` only
the two modules listed are.

| Module | Public surface | Domains may |
|---|---|---|
| `src/pattern/useEntityType` | `useEntityList(domain, type)`, `useEntityItem(ref)`, `useEntityLinks(ref)`, `useInspectTarget()` (`open(ref, {push})`, `back`, `close`, `canGoBack`), `useAddressFilters(ids)`, `encodeInspect`/`decodeInspect` | use |
| `src/pattern/ListInspector` | `<ListInspector list inspector inspectorLabel onClose />` | use as the section layout |
| `src/pattern/DomainList` | `<DomainList label items total capped loading error search onSearch filters filterValues onFilter selected onSelect meta? toolbar? empty />`; renders rows and server markers | use; never render rows themselves |
| `src/pattern/MarkerTag` | rendered by `DomainList` and `Inspector` | not needed directly |
| `src/pattern/EntityInspector` | `<EntityInspector entity actions? />`: official fields in presentation sections, markers, `LinksPanel`, the domain's actions; linked descriptor types open read-only with Back, linked non-descriptor types (REST services) open in their owning section | use |
| `src/pattern/Inspector` | `<Inspector title subtitle? markers? loading? error? sections canGoBack onBack onClose afterFirst? />`, 96 px label column | use for entities that are not descriptor-backed (REST services) |
| `src/pattern/LinksPanel` | `<LinksPanel entity onOpen />` from `GET …/links` | rendered by `EntityInspector` |
| `src/pattern/ActionBar` | `<ActionBar capabilities actions />`; `actions: {operationId, label, mutating, blockedMessage?, refusedByObject?, onActivate}` | use; capabilities come from `availableMutations` |
| `src/pattern/ObjectForm` | `<ObjectForm title fields sections initial readOnlyFields? editors? submitLabel error busy onSubmit onCancel />`, `changedFields(original, values)`, `SecretEditor` | use; submitting opens the dry-run through `useDomainMutation` |
| `src/pattern/useDomainMutation` | `run(start)` → outcome; refreshes entity reads after `Applied`; keeps the IRIS text in `error` | use |
| `src/mutation/useMutation` | `useMutation().start({operationId, keys?, proposed?, request?, noun})`, `openTrail()` | use (through `useDomainMutation` for entities) |
| `src/mutation/TrailPanel` | trail view and export | opened by the shared layer, the palette or `openTrail()` |
| `src/mutation/*` (anything else) | internal | **never** (gate `check:mutation-boundary`) |

Domains never import `@radix-ui/react-dialog`, never use `role="dialog"` or `alertdialog`, never
read or write `sessionStorage`, never call `window.confirm`. Declared exceptions: palette,
re-authentication overlay, inspector overlay below 1280 px.

## 2. Geometry and tokens (docs/design.md §4, §6; docs/prototype.html prevails)

- List min 480 px, inspector 420 px; below 1280 px the inspector is an overlay (feature 001).
- Inspector label column 96 px fixed; numeric values right-aligned tabular, text left-aligned.
- Section tabs only where the domain has more than one entity type (web apps: yes, 3 tabs).
- Markers: icon plus text; tone `caution` uses `state-caution`, `warning` uses `state-warning`.
  Never color alone. Web application exposure markers (research R10), all shown in the list row,
  with the text used when Unauthenticated is the only method and, in parentheses, the text when it
  is one of several: `open-api` "Open API · no authentication" ("Open API · unauthenticated access
  allowed", warning), `static-only` "No authentication · static files only" ("Unauthenticated
  access allowed · static files only", caution), `no-auth` "No authentication" ("Unauthenticated
  access allowed", caution).
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
- `blocked`: the view shows the block message (§9 message 4 for FlightDeck's applications, or the
  descriptor rule's `message`) and no `Apply`; the server's preview carries a masked `Blocked` trail
  record, appended once per requested mutation.
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

- Pattern: `domain-list`, `list-row`, `filter-<id>`, `marker-<id>`, `entity-inspector`,
  `links-panel`, `links-group-<provider>`, `action-<operationId slug>-<label slug>` (for example
  `action-PUT-v2-web-app-edit`), `action-error`, `object-form`, `form-submit`, `form-error`.
- Dry-run and trail: `dry-run`, `dry-run-row-<field>` (with `data-changed`), `dry-run-request`,
  `dry-run-impact`, `dry-run-confirm-input`, `dry-run-acknowledge`, `dry-run-disarm`,
  `dry-run-apply`, `dry-run-applied`, `dry-run-message`, `trail-panel`, `trail-entry` (with
  `data-result`), `trail-export`.
- REST explorer: `rest-specification`, `rest-routes`, `rest-operation`, `rest-request-builder`,
  `rest-method`, `rest-path`, `rest-headers`, `rest-body`, `rest-execute`, `rest-error`,
  `rest-roles-note`, `rest-response`, `rest-status`, `rest-time`, `rest-headers-out`,
  `rest-body-out`, `rest-copy-curl`.

## 7a. Added by feature 003 (permissions and security)

These were the `ui-pattern-delta.md` of feature 003; they are part of this contract now.

- **Action-kind mutations.** A descriptor may declare `kind: "action"` for an official operation that
  changes state through a verb with parameters and no editable object (SQL grant and revoke, a
  password change, a connection test, an audit purge). Domains call
  `useDomainMutation().run({ operationId, params, options, noun })`. The dry-run shows the affected
  set before and after when the descriptor names a `readOperation`, and otherwise the request block,
  with the same grades, impact, masking and trail. Parameters that must not travel in the query
  (a password) are declared as `localParams`; ones that may be empty as `optionalParams`.
- **Parameterised link panels.** A provider may declare parameters it needs before it can answer
  (the namespace of the SQL privileges panel). The group state is then `needs-parameter`; the panel
  renders one control per parameter, with the known values when the session may list them, and
  refreshes alone. Test id `links-group-<provider>-parameter-<name>`.
- **Singleton sections.** An entity type with `singleton: true` has a detail operation, no list and
  no keys; it renders inspector and actions without a list half. Test id `singleton-inspector`.
- **Policy-declared unavailability.** An operation FlightDeck declines to offer on any version
  reaches the client as `available: false` with its reason and the native path, and carries
  `declined: true` so that limited mode still counts only what the **instance** lacks. Screens show
  the control disabled with the reason as visible text; they never hide it.
- **Trail: the last-administrator check.** A record may carry `checkMode`, `checkResult` and
  `checkUnread`; the entry shows the mode and, expanded, what could not be read. Test id
  `trail-entry-check-mode`.
- **Server notes on a preview.** `notice` is shown above the diff (a check that could not assert),
  and `applyNotice` while the operation is applying, for operations the platform answers slowly.
  Test ids `dry-run-notice`, `dry-run-applying`.
- **Validity vocabulary.** Markers `expired`, `expiring`, `validity-unknown` and `validity-not-read`,
  with the days remaining interpolated from a fact (`{facts.daysRemaining}`). The home panel's
  attention list renders the same vocabulary.
- **Shared field editors.** `pattern/editors` (authentication bits, match roles) and
  `pattern/GrantsEditor` (a role's resource grants) are pattern modules, used by more than one
  domain.
- **One section component.** `pattern/DomainSection` renders any domain's list and inspector; a
  domain configures it and adds its actions.

## 7. REST test response panel

- Before running: when the resolved application grants roles beyond the user's login roles, a note
  states "This application grants roles to real calls (<roles>). Test requests run with your login
  roles, so the result can differ from a real call."
- After running: status, elapsed time, headers, body (formatted, 1 MB cap with size), the roles mode
  used, and the same note when `grantsNotApplied` is non-empty; a 403 from `<PROTECT>` names what
  could not be read.
- A trail entry for a test request shows the returned status next to the operation.

## 8. Pattern catalog (fixtures build only)

`/__fixtures__/pattern` composes the modules above on `FlightDeck.Fixture.PatternCatalog`, whose
synthetic entities go through the real Entities and Mutations services when the test install sets
`^FlightDeck.Install("fixtures")`. It covers what web applications do not: `plain-item` (simple
edit, reinforced disable, secret field), `critical-item` (maximum delete with impact),
`protected-item` (self-protection block), and a forced concurrent change through the list's
`drift=<name>` parameter. `frontend/e2e/pattern.spec.ts` runs it; `check-no-fixtures` keeps it out of
the production bundle.
