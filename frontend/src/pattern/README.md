# Domain screen pattern

Every domain screen (web applications today; permissions, security, tasks and system next) is
composed from these modules and the shared mutation layer in `src/mutation/`. The binding contract
is `specs/002-webapps-explorer-mutations/contracts/ui-pattern.md`. If a domain needs something the
pattern does not offer, change the pattern, not the domain.

## How to add a domain

1. **Entity-type descriptor** (backend). Add an entry to `XData EntityTypes` in
   `backend/cls/FlightDeck/Domain/EntityTypes.cls`, keyed `"<domain>/<entityType>"`: the official
   `listOperation` and `detailOperation`, `keys` (query parameter to official field), `displayName`,
   `schema`, `secretFields` if any, `markers` as predicates over `object` and `facts`, link
   providers and the mutation operationIds. Never state a privilege: the capability map derives it
   from the official specification, and `check-descriptors` fails the build if you try.
2. **Mutation descriptors** (backend). For each write, add an entry to `XData Mutations` in
   `backend/cls/FlightDeck/Mutation/Descriptors.cls`, keyed by the official operationId: `kind`
   (`upsert`, `delete`), `readOperation`, `schema`, `target`, `secretFields`, ordered `grade` rules
   (default simple), `selfProtection` rules, and an optional `impact` provider with `impactWhen`.
   Grades and blocks are re-evaluated on the server against re-read state; the client decides
   nothing.
3. **Schemas.** If the entity's official schema is not generated yet, add it to `SCHEMAS` in
   `scripts/build/gen-schemas.py` and run `scripts/build/check-generated.sh`.
4. **Section.** Add the section id in `src/shell/domains.ts` (tabs only when the domain has more than
   one entity type), a presentation (field sections and labels) in `src/domains/presentation.ts`, and
   register the screen in `src/domains/registry.tsx`.
5. **Screen.** In `src/domains/<domain>/`, compose:
   - `ListInspector` as the layout;
   - `DomainList` with `useEntityList` and `useAddressFilters` (filters live in the address);
   - `EntityInspector` for the selected entity, passing `actions`;
   - `ActionBar` with `detail.availableMutations` and one action per operationId;
   - `ObjectForm` (with `SecretEditor` for secret fields) whose submit calls
     `useDomainMutation().run({operationId, keys, proposed, noun})` with only the changed fields.
6. **Tests.** Backend unit tests for descriptors and any fact or link provider; an e2e spec for the
   domain's acceptance scenarios. Run `npm run build` (it includes `check:tokens`,
   `check:dialect` and `check:mutation-boundary`), then `scripts/build/check-dist.sh`.

## The kinds of mutation

| Kind | When | What the dry-run shows |
|---|---|---|
| `upsert` | the official operation writes an object (`PUT`, or `POST` that creates) | the field-by-field diff |
| `delete` | the official operation deletes one | every field, as it stands today |
| `action` | a verb with parameters and no editable object: grant, revoke, set a password, test a connection, purge | the affected set before and after (with `readOperation`), or exactly what will be sent |
| `request` | the REST explorer's own test requests | the request block |

An action declares `params` (sent as query parameters), `localParams` (required, never sent as query
parameters: a password belongs in the body), `optionalParams` (may be empty, as an audit purge
without dates means every record), an optional `readOperation` with `readParams`, `rowKey` and
`effect` to show the before and after, and `body` as a template filled from those parameters.

## When an operation should not be offered at all

Declare it in `backend/cls/FlightDeck/Capability/Policy.cls` with its reason and the native path that
performs it. It then reaches every screen as unavailable with that reason, through the mechanism that
already exists, and the coverage document lists it. Do not omit the control: an absent control reads
as a missing feature, a disabled one with a reason is a decision.

## When the object itself says no

Some official schemas state what may be done to one object: a process's `CanBeTerminated`,
`CanBeSuspended`, `CanReceiveBroadcast` and `CanBeExamined`, a lock's `Removable`. **Wherever a
schema carries such a field, that field decides the control** (RN-FD-34). This is a rule about
schemas, not a list of endpoints: a capability field in any other schema is treated the same way,
with no new decision and no new code path.

How to declare it, in the mutation descriptor:

```json
"refusedWhen":    {"op": "equals", "path": "facts.canBeTerminated", "value": false},
"disabledReason": "The instance reports that this process cannot be terminated."
```

Three things make it a rule rather than a special case:

- **The fact comes from the object the API returned**, never from a type, a user or a state the
  screen inferred. The list carries the fact, so a row's controls are decided without opening it.
- **It is written as a refusal, not as a permission.** A fact FlightDeck could not read is not a
  refusal: with `refusedWhen`, an unknown capability lets the platform answer for itself, where an
  `enabledWhen` would have the portal deny on a guess. This is the direction that fails safe for the
  user rather than for the code.
- **The server enforces it.** `FlightDeck.Mutation.Service.Refusal` evaluates the same predicate
  before any write, so a request that arrives without going through the screen is refused too. The
  screen disabling the control is not the guard.

`check-descriptors` fails a `refusedWhen` with no `disabledReason`: a refusal must say why.

## What a domain never does

- Render a dialog, a confirmation, a diff or its own trail. The dry-run in `src/mutation/` is the
  only confirmation UI; `check:mutation-boundary` fails the build and names the file.
- Read or write `sessionStorage`, or call `window.confirm`.
- Hide a control. Unavailable, forbidden, object-refused and blocked actions stay visible, disabled,
  with the reason.
- Decide availability from a version: availability comes from the capability map.
- Show a secret value. Secret fields leave the server only as `changed` or `unchanged`.

## Proving a new pattern behaviour

Behaviours the shipped domains do not exercise belong in the pattern catalog
(`backend/cls/FlightDeck/Fixture/PatternCatalog.cls`, `src/fixtures/PatternCatalog.tsx`,
`e2e/pattern.spec.ts`), which runs on a fixtures install through the real services.
