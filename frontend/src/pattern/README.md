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

## What a domain never does

- Render a dialog, a confirmation, a diff or its own trail. The dry-run in `src/mutation/` is the
  only confirmation UI; `check:mutation-boundary` fails the build and names the file.
- Read or write `sessionStorage`, or call `window.confirm`.
- Hide a control. Unavailable, forbidden and blocked actions stay visible, disabled, with the reason.
- Decide availability from a version: availability comes from the capability map.
- Show a secret value. Secret fields leave the server only as `changed` or `unchanged`.

## Proving a new pattern behaviour

Behaviours the shipped domains do not exercise belong in the pattern catalog
(`backend/cls/FlightDeck/Fixture/PatternCatalog.cls`, `src/fixtures/PatternCatalog.tsx`,
`e2e/pattern.spec.ts`), which runs on a fixtures install through the real services.
