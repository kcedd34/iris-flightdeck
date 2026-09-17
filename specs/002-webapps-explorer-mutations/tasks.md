# Tasks: Web Applications, REST API Explorer and the Shared Mutation Layer

**Input**: Design documents from `/specs/002-webapps-explorer-mutations/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md).

Pre-task checks already done on 2026-09-17:
- `verification/rest-executor-spike-2026.2.md` (spike T-EXEC-1);
- `verification/flightdeck-web-apps-exposure-2026.2.md`.

**Tests**: included. The spec's success criteria require automated evidence (SC-001, SC-003 to
SC-005, SC-009 to SC-013), and feature 001's gates carry over.

**Standing rules for every task**:
- No version or dialect check outside `FlightDeck.Admin` (`npm run check:dialect`).
- Tokens only (`check:tokens`).
- Every frontend change ends with `npm run build` and `scripts/build/check-dist.sh` passing
  (FR-038).
- English UI, comments and commits.
- Never set `$ROLES` to a non-empty value (spike T-EXEC-1).
- Commit only when the author asks.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an incomplete task).
- **[Story]**: US1 read web apps, US2 mutation layer and web app writes, US3 REST explorer, US4
  domain pattern proven for later domains.

## Path Conventions

- Backend: `backend/cls/FlightDeck/`, tests `backend/test/FlightDeck/Test/`.
- Frontend: `frontend/src/`, e2e `frontend/e2e/`, gates `frontend/scripts/`.
- Generators and checks: `scripts/build/`; dev helpers: `scripts/dev/`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: contract, generated schemas, and records every story relies on.

- [X] T001 Merge `specs/002-webapps-explorer-mutations/contracts/flightdeck-api-002.openapi.json`
  into the served contract, and generate the class from it:
  - add a `contracts_merge` step to `scripts/build/gen-openapi-cls.py` that reads both contract
    files;
  - write the merged document to `backend/cls/FlightDeck/API/OpenAPI.cls` (version `1.1.0`);
  - keep `specs/001-foundation-shell/contracts/flightdeck-api.openapi.json` unchanged as the base;
  - confirm `scripts/build/check-generated.sh` still passes.
- [X] T002 [P] Create `scripts/build/gen-schemas.py`:
  - read the official `Application`, `WebApplicationList`, `WebAppPctAccess`, role, user and
    resource schemas from `docs/sysadmin-api-v2.json`;
  - write field name, type, description and enum to
    `frontend/src/domains/generated/schemas.ts` (shared by all domains) and to
    `backend/cls/FlightDeck/Domain/Schemas.cls` (XData JSON);
  - add both outputs to `scripts/build/check-generated.sh` (research R1).
- [X] T003 [P] Add frontend contract types (`EntityListResponse`, `EntityDetailResponse`,
  `LinksResponse`, `PreviewRequest`, `PreviewResponse`, `ApplyRequest`, `ApplyResponse`,
  `TrailRecord`, `RestService`, `SpecificationResponse`, `ExecuteRequest`, `ExecuteResponse`,
  `CompositeCapability`, `Marker`) in `frontend/src/api/types.ts`, matching the contract field by
  field.
- [X] T004 [P] Record the platform defects of research R2 in `verification/README.md`, each with
  the request, response and IRIS version:
  - `IsSystemApp` is always false while `Type` says `System`;
  - input validation errors return HTTP 500.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: the descriptor framework, generic reads, composite capabilities, Router wiring and the
read-only pattern modules. No user story can start before this phase is complete.

- [X] T005 Create `backend/cls/FlightDeck/Domain/Descriptor.cls`:
  - loader and validator for entity-type and mutation descriptors stored as XData JSON (data-model
    §1.1, §1.2);
  - `EntityType(domain, entityType)`, `Mutation(operationId)`, `Validate()`;
  - `Validate()` rejects unknown `operationId`s (checked against `FlightDeck.Capability.Spec`), any
    `requires`/privilege key, a `delete` without `target`, and predicates referencing undeclared
    fields.
- [X] T006 [P] Create `scripts/build/check-descriptors.py`:
  - run the same validation offline over `backend/cls/FlightDeck/Domain/EntityTypes.cls` and
    `backend/cls/FlightDeck/Mutation/Descriptors.cls`;
  - add it to `scripts/build/check-generated.sh`;
  - prove it with a probe descriptor that declares a privilege.
- [X] T007 Create `backend/cls/FlightDeck/Domain/Predicate.cls`: the small predicate evaluator the
  descriptors use (`equals`, `in`, `contains`, `changed`, `bitCleared`, `and`, `or`, `not` over
  `current`, `proposed`, `changedFields`, `isSystem`, `isFlightDeck`, `facts`). No `xecute`, no
  indirection over user input.
- [X] T008 Create `backend/cls/FlightDeck/API/Entities.cls`:
  - `GET /v1/domains/{domain}/{entityType}` (list), `/item` and `/links` (contract);
  - forward the official operations through `FlightDeck.Admin.Client` only;
  - return official objects unchanged, with markers, keys, `displayName`, `total` and `capped`
    (`maxRows` 1000, research R10);
  - errors from the official API are passed through verbatim (feature 001 envelope).
- [X] T009 Create `backend/cls/FlightDeck/Capability/Composite.cls`:
  - derive composite capabilities (research R11, data-model §4) from descriptor `operationId` lists
    crossed with `FlightDeck.Capability.Map`: AND across operations, keeping each operation's OR;
  - add the `composites` section to `backend/cls/FlightDeck/API/Capabilities.cls`.
- [X] T010 Update `backend/cls/FlightDeck/API/Router.cls`:
  - add the routes for `Entities`, `Mutations`, `Rest` and the fixture-only catalog;
  - add `POST /v1/mutations/preview` and `POST /v1/rest/execute` to `SAFEMODEALLOWLIST`;
  - keep `GuardDecision` pure;
  - extend `backend/test/FlightDeck/Test/RouterGuards.cls` so that preview is allowed while armed,
    apply is refused while armed, and `TestUrlMapMatchesOpenApi` covers the new routes.
- [X] T011 [P] Create `backend/test/FlightDeck/Test/Descriptors.cls`:
  - validation accepts the shipped descriptors;
  - it rejects a privilege key, an unknown `operationId`, and a `delete` without `target`;
  - `Predicate` covers each operator, including `bitCleared` on `AutheEnabled`.
- [X] T012 [P] Create `backend/test/FlightDeck/Test/EntityReads.cls`:
  - list and item return the official object unchanged, compared field by field with a direct
    `Admin.Client` call;
  - 404 from the API passes through;
  - `capped` is set at 1000;
  - it runs on both dialects without any version check.
- [X] T013 [P] Create `backend/test/FlightDeck/Test/CompositeCapabilities.cls`:
  - a composite requiring two `%Admin_Secure:U` operations is allowed for `_SYSTEM` and refused
    for `fd_e2e_operator` with message 2;
  - an unavailable operation makes the composite unavailable with its reason.
- [X] T014 Move `frontend/src/shell/ListInspector.tsx` to `frontend/src/pattern/ListInspector.tsx`
  and update its imports. Geometry is unchanged: list min 480 px, inspector 420 px, overlay below
  1280 px.
- [X] T015 [P] Create `frontend/src/pattern/useEntityType.ts`:
  - TanStack Query hooks for list, item and links;
  - address-driven filters and `inspect` parameter;
  - no domain-specific code.
- [X] T016 [P] Create `frontend/src/pattern/DomainList.tsx` and `frontend/src/pattern/ListRow.tsx`:
  - header with title, search, filter chips and create action slot;
  - rows with server markers (icon plus text, tone to `state-caution`/`state-warning`), tabular
    numerals and count/capped state;
  - `data-testid` `domain-list`, `list-row`, `marker-<id>` (`contracts/ui-pattern.md` §2, §6).
- [X] T017 [P] Create `frontend/src/pattern/Inspector.tsx`:
  - fixed 96 px label column, sections, and a linked-entity stack with Back (spec FR-006);
  - `data-testid` `inspector`.
- [X] T018 [P] Create `frontend/src/pattern/LinksPanel.tsx`:
  - incoming and outgoing groups with count;
  - states `ok`, `forbidden`, `unavailable` and `undetermined`, each with its reason;
  - one-click items open in the inspector stack;
  - `data-testid` `links-panel`, `links-group-<provider>`.
- [X] T019 [P] Create `frontend/src/pattern/ActionBar.tsx`:
  - precedence of `contracts/ui-pattern.md` §3 (available, allowed, object capability,
    self-protection, safe mode);
  - controls never hidden; the reason is visible and in `aria-describedby`;
  - activation calls a callback supplied by the mutation layer (wired in T056);
  - `data-testid` `action-<operationId>`.
- [X] T020 Create `frontend/scripts/check-mutation-boundary.mjs` (research R12), modeled on
  `check-dialect-boundary.mjs`:
  - fail outside `src/mutation/` on `sessionStorage`, `window.confirm`, imports of mutation
    internals, and diff markers;
  - fail in `src/domains/` and `src/pattern/` on dialog imports or `role="dialog"`/`alertdialog`;
  - declared exceptions with reasons: `src/palette/CommandPalette.tsx`,
    `src/session/ReauthOverlay.tsx`, `src/pattern/ListInspector.tsx` (overlay below 1280 px);
  - add `check:mutation-boundary` to `package.json` and to `npm run build`.
- [X] T021 Allow the dry-run reveal in `frontend/scripts/check-tokens.mjs` as a named motion
  exception, scoped to `src/mutation/dryrun.css` only (160 ms slide, 240 ms decay, design §6). Any
  other duration over 200 ms still fails.

**Checkpoint**: descriptors validate, generic reads work on both dialects, and the pattern read
modules render a list and an inspector from a descriptor.

---

## Phase 3: User Story 1 - See what is exposed and under which protection (Priority: P1) 🎯 MVP

**Goal**: the web applications and percent class access sections, with graded exposure markers in
the list, the system marking, links (resource, granting roles, owners, REST service), and read-only
linked roles and users.

**Independent Test**: armed tab on the demo install:
- `/api/monitor` shows `open-api`, `/flightdeck` shows `static-only`, and `/api/flightdeck` has no
  marker;
- opening `/csp/fd-demo` reaches its granting roles in one click;
- no state-changing request is sent.

### Tests for User Story 1

- [X] T022 [P] [US1] Create `backend/test/FlightDeck/Test/WebAppExposure.cls`:
  - `open-api` for an unauthenticated REST dispatcher;
  - `no-auth` for an unauthenticated application without dispatcher;
  - `static-only` for `/flightdeck`;
  - no marker for `/api/flightdeck`;
  - a probe dispatch class that declares static files but has a `POST` route gets `open-api`;
  - no marker decision reads the application name.
- [X] T023 [P] [US1] Create `backend/test/FlightDeck/Test/WebAppLinks.cls`:
  - `resource-roles` finds `FD_Demo_Operator` for `FD_Demo_Reports`, including via a granted role
    and with `%All` listed;
  - `role-owners` counts match `GET /v2/security/role/owners`;
  - public permission is reported;
  - an application without resource reports "not restricted";
  - `fd_e2e_operator` gets `forbidden` with message 2.
- [X] T024 [P] [US1] Create `backend/test/FlightDeck/Test/WebAppSystemMarking.cls`:
  - an application is system when `IsSystemApp` or `Type` contains `System`;
  - the test fails with an explicit message if any application has `IsSystemApp` true while
    `Type` lacks `System`, or the reverse, so the R2 workaround is revisited.
- [X] T025 [P] [US1] Create `frontend/e2e/webapps.spec.ts` (US1 part):
  - PRD UC03-1: the unauthenticated highlight is visible in the list;
  - scenario 1a: graded markers, and `/api/flightdeck` unmarked, without opening the inspector;
  - PRD UC03-2: granting roles one click from the detail;
  - scenario 3: filters for namespace, enabled, REST and no authentication are reflected in the
    URL;
  - scenario 4: system application signaled;
  - scenario 5: `fd_e2e_operator` sees disabled actions with message 2;
  - scenario 6: a linked role opens read-only in the inspector with Back, and the permissions
    route still shows the empty state.

### Implementation for User Story 1

- [X] T026 [US1] Declare static-files exposure in `backend/cls/FlightDeck/UI/Static.cls`, with a
  comment linking `verification/flightdeck-web-apps-exposure-2026.2.md`. *(As built: a class
  parameter `EXPOSURE = "static-files"` instead of a class method, so the list reads the class
  dictionary and never executes instance code while building rows.)*
- [X] T027 [US1] Create `backend/cls/FlightDeck/Domain/Facts.cls`:
  - `IsRestDispatcher(class)` (extends `%CSP.REST`, from the compiled class, in the application's
    namespace, with `<PROTECT>` reported as unknown);
  - `IsVerifiedStaticFiles(class)` (declaration present **and** compiled `UrlMap` routes are only
    `GET`/`HEAD`);
  - `IsSystemApplication(listItem)` (`IsSystemApp` or `Type` contains `System`);
  - `IsFlightDeckApplication(name)` reads the installer record (T041); until T041 lands, it
    returns false and a test marks it pending.
- [X] T028 [US1] Declare the `web-application` entity type in
  `backend/cls/FlightDeck/Domain/EntityTypes.cls` (data-model §1.1):
  - list `GET /v2/web-apps`, detail `GET /v2/web-app`, keys `name`;
  - row fields Name, Namespace, Enabled, Resource, AuthenticationMethods, DispatchClass, Type;
  - markers `open-api` (warning), `no-auth` (caution), `static-only` (caution), `system`,
    `disabled`, per research R10, with "only" when Unauthenticated is the only method;
  - links `resource-roles`, `role-owners`, `resource-public`, `rest-service`.
- [X] T029 [US1] Declare the `pct-access` entity type in
  `backend/cls/FlightDeck/Domain/EntityTypes.cls`: list `GET /v2/web-app/pct-accesses`, detail
  `GET /v2/web-app/pct-access`, keys `name,allowType,class`, display name
  `{class} ({allowType}) on {name}`, and a `system` marker from the list's `System` field.
- [X] T030 [P] [US1] Create the link providers in `backend/cls/FlightDeck/Domain/Links/`:
  - `ResourceRoles.cls`: transitive `GrantedRoles` with a cycle guard, and `%All` listed;
  - `RoleOwners.cls`;
  - `ResourcePublic.cls`;
  - `RestService.cls`: a stub returning `unavailable` with the reason "REST explorer not built
    yet" until T061;
  - composed only from official reads (research R6), with the 30 s IRIS-session cache keyed per
    user and an `Invalidate()` entry point.
- [X] T031 [P] [US1] Declare read-only `role` and `user` entity types in
  `backend/cls/FlightDeck/Domain/EntityTypes.cls` (detail only: `GET /v2/security/role`,
  `GET /v2/security/user`) for linked-entity inspection (spec FR-006). No list route and no
  mutations; their domain routes keep the feature 001 empty state.
- [X] T032 [US1] Create `frontend/src/domains/web-apps/WebApplications.tsx`:
  - `DomainList` with filters text, namespace, enabled, REST and no authentication;
  - `Inspector` sections (Identity, Security, Session, CORS, advanced) from
    `generated/schemas.ts` labels;
  - `LinksPanel`, and an `ActionBar` with the mutation actions listed but not yet wired.
- [X] T033 [P] [US1] Create `frontend/src/domains/web-apps/PercentClassAccess.tsx`: the global list
  and the per-application list (filter `names`), plus an inspector.
- [X] T034 [US1] Wire the web-apps section tabs in `frontend/src/shell/domains.ts` and the domain
  route:
  - `web-applications` and `percent-class-access` render the new sections;
  - `rest-apis` keeps its empty state until US3;
  - `inspect` works for `web-application`, `pct-access`, `role` and `user`.
- [X] T035 [US1] Update palette entity navigation in `frontend/src/palette/actions.ts` and
  `backend/cls/FlightDeck/Palette/Search.cls` so that web application and percent class access
  results open the new inspector (`target.inspect`), with no change to other domains.
- [X] T036 [US1] Run the US1 tests (T022–T025), the feature 001 suites, `npm run build` and
  `scripts/build/check-dist.sh`; fix until green.

**Checkpoint**: US1 is demonstrable on its own with safe mode armed.

---

## Phase 4: User Story 2 - Change anything only after seeing exactly what will change (Priority: P1)

**Goal**: the server-owned mutation layer (preview/apply, grades, masking, self-protection,
concurrency), the single dry-run view, the per-tab trail, and all web application and percent class
access writes through it.

**Independent Test**: quickstart §4, §5 and §8:
- edit `/csp/fd-demo` with dry-run and trail;
- a concurrent change is detected;
- disabling `/api/flightdeck` is blocked through the UI and through a direct request;
- the trail survives a reload and is cleared at sign-out.

### Tests for User Story 2

- [X] T037 [P] [US2] Create `backend/test/FlightDeck/Test/MutationGrade.cls`, the grade table of
  research R5:
  - Description edit is simple;
  - `Enabled` false, `AutheEnabled`, `Resource`, `MatchRoles`, `NameSpace` and `DispatchClass`
    edits are reinforced;
  - any edit to a FlightDeck application is reinforced;
  - delete is reinforced, and maximum with a consequence for a system application;
  - pct-access delete is reinforced;
  - a pct-access key change is delete plus create with the delete grade. *(As built: the identity
    fields of a percent class access configuration are read-only in the edit form; a different
    identity is created with New, and the old one deleted with its own reinforced dry-run.)*
- [X] T038 [P] [US2] Create `backend/test/FlightDeck/Test/MutationService.cls`:
  - `noChange` sends nothing (message 18);
  - a fingerprint mismatch gives `STATE_CHANGED` with a fresh preview and nothing written
    (verified by re-reading through the official API);
  - a missing or wrong typed confirmation gives 422;
  - an official 500 with `#7207` gives `UPSTREAM_REJECTED` with `validation` true;
  - `Applied` returns the re-read object and a trail record;
  - `apply` invalidates the link cache.
- [X] T039 [P] [US2] Create `backend/test/FlightDeck/Test/MutationMask.cls`, using a catalog
  descriptor with a secret field:
  - no value appears in the preview rows, apply response, trail record, error text or fingerprint
    input;
  - changed and unchanged are still reported correctly.
- [X] T040 [P] [US2] Create `backend/test/FlightDeck/Test/SelfProtection.cls`:
  - for `/api/flightdeck` and `/flightdeck`, refuse delete, `Enabled` false, `NameSpace` or
    `DispatchClass` change, clearing the required authentication bit, and removing the
    `FlightDeck_Runtime` target;
  - allow a Description edit (reinforced) and pct-access writes;
  - identify the applications from the installer record, not from the typed name;
  - refuse on re-read state even when the preview passed.

### Implementation for User Story 2

- [X] T041 [US2] Update `backend/cls/FlightDeck/Install/Installer.cls`:
  - record FlightDeck's web application names, namespace and required authentication bits at
    install (research R7) in the install namespace's `^FlightDeck.Install("applications")`,
    written through the installer and idempotent;
  - extend `backend/test/FlightDeck/Test/InstallerIdempotency.cls`;
  - replace the T027 pending stub.
- [X] T042 [US2] Create `backend/cls/FlightDeck/Mutation/Fingerprint.cls`: SHA-256 over canonical
  JSON with keys sorted, secret fields replaced by their own hash, and `absent` for a missing
  object (research R4).
- [X] T043 [P] [US2] Create `backend/cls/FlightDeck/Mutation/Mask.cls`, applied to every preview
  row, apply result, trail record and error text before it leaves the server (spec FR-016,
  Constitution VI).
- [X] T044 [P] [US2] Create `backend/cls/FlightDeck/Mutation/Grade.cls`: evaluate descriptor grade
  rules with `Domain.Predicate` and return `grade`, `confirmText` and `consequence`.
- [X] T045 [P] [US2] Create `backend/cls/FlightDeck/Mutation/SelfProtection.cls`: evaluate
  descriptor `selfProtection` rules with `isFlightDeck` from `Domain.Facts` (T041) and return §9
  message 4.
- [X] T046 [US2] Create `backend/cls/FlightDeck/Mutation/Service.cls`, the only server path that
  sends SysAdmin API writes:
  - **preview**: read, diff by field from the generated schema, mask, grade, impact, blocked,
    fingerprint;
  - **apply**: re-read, compare fingerprint (409), re-check self-protection (403, `Blocked`
    record), grade and confirmation (422), send only changed fields for edit, full for create,
    nothing for delete;
  - classify R2 input errors;
  - build the masked trail record (data-model §3.5);
  - invalidate links;
  - request-mode support stays a hook completed in T066.
- [X] T047 [US2] Create `backend/cls/FlightDeck/API/Mutations.cls` (`POST /v1/mutations/preview`,
  `POST /v1/mutations/apply`) mapping `Service` results to the statuses and codes of data-model
  §3.4.
- [X] T048 [US2] Declare the mutation descriptors in
  `backend/cls/FlightDeck/Mutation/Descriptors.cls`:
  - `PUT /v2/web-app` (create and edit) and `DELETE /v2/web-app` with the grade rules, target
    `{name}`, self-protection rules and `webapp-impact`;
  - `PUT /v2/web-app/pct-access` and `DELETE /v2/web-app/pct-access` with target `{class}`;
  - no secret fields (none exist in these schemas).
- [X] T049 [P] [US2] Create `backend/cls/FlightDeck/Domain/Links/WebAppImpact.cls`:
  - users affected through granting roles' owners;
  - "every user" when the resource has a public permission or there is no resource;
  - `undetermined` with the reason when the reads are refused (spec FR-010).
- [X] T050 [US2] Create `frontend/src/mutation/trail.ts`:
  - store in `sessionStorage["flightdeck.trail.v1"]`: version, notice, entries capped at 500,
    `dropped`;
  - accepts only `TrailRecord`s from server responses;
  - memory fallback with the stated notice when storage throws;
  - `clearTrail()` and `exportTrail()` (named file, pretty JSON);
  - Vitest in `frontend/src/mutation/trail.test.ts` covers reload survival (mock storage), cap,
    fallback and clear.
- [X] T051 [US2] Clear the trail in `frontend/src/session/SessionProvider.tsx` on `signOut` and when
  expiry is detected (spec FR-014). No leave-page warning.
- [X] T052 [US2] Create `frontend/src/mutation/useMutation.ts`:
  - `start({operationId, keys, proposed | request})`;
  - state machine of data-model §3.5: previewing, ready, applying, applied, `stateChanged` with
    recompute and cleared confirmation, `noChange`, blocked, rejected with the form kept, expired
    then re-auth then previewing;
  - appends server trail records;
  - integrates the disarm-then-continue offer from feature 001 (spec FR-017).
- [X] T053 [US2] Create `frontend/src/mutation/DryRun.tsx` and `frontend/src/mutation/dryrun.css`
  per `contracts/ui-pattern.md` §4:
  - `CURRENT`/`COMMANDED` columns with `state-actual`/`state-commanded`, muted unchanged rows and
    secret rows as changed/unchanged;
  - impact block below the diff;
  - grade row on the button line: `Apply` disabled until an exact match, and a maximum-grade
    acknowledgement checkbox;
  - messages 17, 18 and 4;
  - reveal of 8 px/160 ms slide and 240 ms decay once, instant under reduced motion;
  - focus rules;
  - all `dry-run-*` test ids.
- [X] T054 [US2] Create `frontend/src/mutation/TrailPanel.tsx`:
  - the not-a-substitute-for-auditing notice, newest first, expandable rows or request,
    `Applied`/`Failed`/`Blocked` words and the export button;
  - reachable from a "Session trail" palette action (`frontend/src/palette/actions.ts`) and from
    the `Applied` notice.
- [X] T055 [US2] Create the forms in `frontend/src/domains/web-apps/WebApplicationForm.tsx` and
  `frontend/src/domains/web-apps/PctAccessForm.tsx`:
  - fields from `generated/schemas.ts`;
  - `AutheEnabled` edited as labeled checkboxes over the bit mask;
  - `MatchRoles` as rows;
  - read-only while armed with the disarm offer (UC03 A1);
  - IRIS validation text shown verbatim under the form, values kept (FR-013);
  - submit calls `useMutation.start`.
- [X] T056 [US2] Wire the web-apps `ActionBar` actions (Edit, Disable/Enable, Delete, New; pct
  New/Edit/Delete) to the forms and `useMutation` in `WebApplications.tsx` and
  `PercentClassAccess.tsx`. Refresh the list, inspector and links after `Applied`.
- [X] T057 [US2] *(Script written and passing for the mutation service; its REST executor rows pass
  once T068 lands.)* Create `scripts/dev/check-mutation-enforcement.sh`, without the UI:
  - with an armed tab, every `apply` and every mutating `execute` method is refused with 403
    `SAFE_MODE_ON`;
  - with a disarmed tab, disabling or deleting `/api/flightdeck` and `/flightdeck` is refused with
    403 `SELF_PROTECTION`;
  - a wrong confirmation gets 422;
  - print a table and exit non-zero on any unexpected answer (SC-003, SC-004).
- [X] T058 [US2] Create `frontend/e2e/mutation.spec.ts`:
  - PRD UC03-3, UC03-4 and UC10-1 to UC10-4;
  - scenarios 7 to 10 of US2, including a direct request refused while armed;
  - the concurrent change through the official API between preview and apply (SC-005);
  - trail survives reload, a duplicated tab gets a snapshot that then diverges, the trail is
    cleared at sign-out, and cleared at forced expiry with the dry-run restored and recomputed
    (quickstart §8); *(As built: Playwright cannot duplicate a browser tab, so the duplicated-tab
    snapshot is left to the manual quickstart §8 step 2; reload, sign-out and expiry are automated.)*
  - export JSON contents checked.
- [X] T059 [US2] Run the US2 tests (T037–T040, T058), `scripts/dev/check-mutation-enforcement.sh`,
  the feature 001 suites, `npm run build` and `check-dist.sh`; fix until green.

**Checkpoint**: US1 plus US2 are the full UC03 and UC10 on web applications.

---

## Phase 5: User Story 3 - Discover, read and test the instance's REST APIs (Priority: P2)

**Goal**: discovery with honest specification flags, FlightDeck's own specification, an OpenAPI
2.0/3.0 viewer, and the confined in-process executor. Its roles are kept or cleared (spike
T-EXEC-1), and its mutating methods go through request mode.

**Independent Test**: quickstart §6 and the US3 scenarios:
- `/api/flightdeck` is listed with its specification, and `/api/monitor` is flagged without one;
- a GET on FlightDeck's API returns status, time, headers and body, and can be copied as `curl`;
- a `DELETE` while armed is refused by the server;
- hostile targets are refused.

### Tests for User Story 3

- [X] T060 [P] [US3] Create `backend/test/FlightDeck/Test/RestExecutorConfinement.cls`: a table of
  hostile inputs is refused with `TARGET_OUTSIDE_INSTANCE`:
  - `http://example.com/`, `//example.com/x`, `/a/../../b`, `/%2e%2e/`, `/%2E%2e/x`, `\\host\share`;
  - an embedded scheme in the path, and NUL;
  - `Authorization` and `Cookie` headers are refused with `CREDENTIAL_HEADER`;
  - a disabled application and a non-REST dispatcher get 422 with the reason.
- [X] T061 [P] [US3] Create `backend/test/FlightDeck/Test/RestExecutorRoles.cls` (spike T-EXEC-1 as a
  regression test, run through a job signed in as each user, pattern of
  `NativeNamespaces.TestRefusesWithoutDeclaredPrivilege`):
  - `rolesMode` is `current-kept` for `/api/flightdeck`;
  - it is `login-only` with `grantsNotApplied` `["%DB_IRISSYS"]` for `/api/monitor`;
  - `<PROTECT>` in both forms maps to 403 with the reason;
  - `$ROLES` after the call equals `$ROLES` before.
- [X] T062 [P] [US3] Create `backend/test/FlightDeck/Test/NoRolesAssignment.cls`: scan every class
  under `FlightDeck.*` (compiled source) and fail on any `set $roles` to a non-empty expression, with
  the one allowed form `set $roles = ""` inside a method that also has `new $roles` (spike T-EXEC-1,
  finding 2).
- [X] T063 [P] [US3] Create `backend/test/FlightDeck/Test/RestDiscovery.cls`:
  - the merge of `GetWebRESTApps` and `GetRESTApps` by web application;
  - `hasSpecification` true for the `%Api.IAM.v1` and `%Api.InteropEditors` services and for
    `/api/flightdeck` (published);
  - false for `/api/monitor` and `/api/admin`, whose documents are UrlMap-generated;
  - per-namespace refusal reported verbatim for `fd_e2e_operator`;
  - no FlightDeck name appears in discovery code (source scan).
- [X] T064 [P] [US3] Create `frontend/e2e/rest.spec.ts` (PRD UC04-1 to UC04-4, US3 scenarios 5 to 9)
  and `frontend/e2e/rest-confinement.spec.ts` (SC-009):
  - the hostile target table through the UI and direct requests;
  - the container connection table is unchanged;
  - the roles note is shown for `/api/monitor`.

### Implementation for User Story 3

- [X] T065 [US3] Create `backend/cls/FlightDeck/Rest/Discovery.cls`:
  - in-process `%REST.API.GetWebRESTApps` and `GetRESTApps` per namespace the user can read;
  - merge by web application;
  - `hasSpecification` rules: specification-first, or a dispatcher that implements
    `PublishedSpecification()`, with no name check;
  - UrlMap-generated documents exposed only as `routes`;
  - `<PROTECT>` and 403 per namespace reported verbatim (research R9).
- [X] T066 [US3] Add `ClassMethod PublishedSpecification() As %DynamicObject` to
  `backend/cls/FlightDeck/API/Router.cls`, returning the served OpenAPI document from
  `FlightDeck.API.OpenAPI` (spec FR-027).
- [X] T067 [US3] Create `backend/cls/FlightDeck/Rest/Executor.cls` (research R8 revised):
  - path confinement and header rules;
  - web application resolution by longest prefix through `GET /v2/web-apps` and
    `GET /v2/web-app`;
  - enabled and REST-dispatcher checks, and the application `Resource` checked with
    `$system.Security.Check`;
  - **roles mode**: `current-kept` when every added role is among the target's `MatchRoles` grants
    for this user, otherwise `NEW $ROLES` / `SET $ROLES=""`, never a non-empty value;
  - `grantsNotApplied`;
  - in-process dispatch in the target namespace with a synthetic request, transient session and
    captured output;
  - both `<PROTECT>` forms mapped to 403;
  - 1 MB body cap with the size;
  - elapsed time.
- [X] T068 [US3] Create `backend/cls/FlightDeck/API/Rest.cls`:
  - `GET /v1/rest/services`;
  - `GET /v1/rest/services/specification`;
  - `POST /v1/rest/execute`: GET/HEAD/OPTIONS run directly; POST/PUT/PATCH/DELETE answer 403
    `SAFE_MODE_ON` while armed and 422 `CONFIRMATION_REQUIRED` otherwise, because they run only
    through `apply`.
- [X] T069 [US3] Complete request mode in `backend/cls/FlightDeck/Mutation/Service.cls` and declare
  the `FLIGHTDECK REST execute` descriptor in `backend/cls/FlightDeck/Mutation/Descriptors.cls`:
  - preview returns `requestMode` with the masked headers and the stated reason;
  - grade simple, DELETE reinforced with target `{path}`;
  - apply runs `Rest.Executor`;
  - the trail record carries the masked request and status (spec FR-039).
- [X] T070 [US3] Replace the stub in `backend/cls/FlightDeck/Domain/Links/RestService.cls` with the
  discovery lookup, so web application inspectors link to their REST service.
- [X] T071 [P] [US3] Create `frontend/src/domains/rest-apis/openapi.ts`, a normalizer for OpenAPI 2.0
  and 3.0: paths, methods, parameters, request bodies, responses, `$ref` resolution with a cycle
  guard. Vitest `frontend/src/domains/rest-apis/openapi.test.ts` uses FlightDeck's own document and a
  specification-first `%Api.IAM.v1` document captured from the demo install.
- [X] T072 [US3] Create `frontend/src/domains/rest-apis/Services.tsx`:
  - `DomainList` of services by namespace, with the no-specification marker;
  - namespace empty state with the pointer to FlightDeck's namespace (FR-033);
  - an inspector with metadata and platform-reported routes.
- [X] T073 [US3] Create `frontend/src/domains/rest-apis/SpecificationViewer.tsx`: grouped by path
  and method, parameters and schemas, keyboard navigable, tokens only.
- [X] T074 [US3] Create `frontend/src/domains/rest-apis/RequestBuilder.tsx` and
  `frontend/src/domains/rest-apis/ResponsePanel.tsx` (`contracts/ui-pattern.md` §7):
  - method, path, query, headers and body;
  - the roles note before running;
  - GET/HEAD/OPTIONS call `execute`; mutating methods call `useMutation.start({request})`;
  - response with status, time, headers, formatted body, size and truncation, `rolesMode` and
    note;
  - copy as `curl` against the instance base URL with the literal `-u '<user>:<password>'`
    placeholder (FR-031);
  - free request by path for services without a specification (UC04 A1).
- [X] T075 [US3] Wire the `rest-apis` section tab and palette entity results for REST services in
  `frontend/src/shell/domains.ts` and `frontend/src/palette/actions.ts`.
  _Note: the section is registered in `frontend/src/domains/registry.tsx`; palette results come from
  a discovery-backed group in `backend/cls/FlightDeck/Palette/Search.cls` (`RestServices`), and
  linked REST services open in their owning section from `pattern/EntityInspector.tsx`._
- [X] T076 [US3] Update `README.md` (FR-034):
  - the executor is confined to the current instance, is not an outbound proxy, and runs as the
    signed-in user;
  - roles are kept or reduced, never raised, so results can differ from real calls for
    applications that grant roles;
  - the trail is local to the tab and does not replace IRIS auditing.
- [X] T077 [US3] Run the US3 tests (T060–T064), the feature 001 and US1/US2 suites, `npm run build`
  and `check-dist.sh`; fix until green.

**Checkpoint**: all three use cases are delivered.

---

## Phase 6: User Story 4 - Add the next domain without a single new design or confirmation decision (Priority: P2)

**Goal**: the pattern is proven for what web applications do not exercise, guarded by the build,
and documented as the contract later domains must use.

**Independent Test**: the fixture build's pattern catalog runs all three grades, a secret field, a
blocked operation and a forced `STATE_CHANGED`. Probe files make `check:mutation-boundary` fail.

- [X] T078 [P] [US4] Create the catalog backend in `backend/cls/FlightDeck/Fixture/PatternCatalog.cls`:
  - synthetic entities in the IRIS session;
  - catalog entity-type and mutation descriptors: simple, reinforced, maximum on a non-system
    entity, a secret field, a self-protection block, and a `forceStateChanged` toggle;
  - served through the real `Entities` and `Mutations` services;
  - routes registered only when `^FlightDeck.Install("fixtures")` is set by the e2e setup (research
    R13).
- [X] T079 [P] [US4] Create `frontend/src/fixtures/PatternCatalog.tsx` (fixture build only):
  every pattern module on the catalog entities, excluded by `scripts/check-no-fixtures.mjs`.
- [X] T080 [US4] Create `frontend/e2e/pattern.spec.ts` (US4 scenarios 1 to 4):
  - the three grade interactions;
  - the secret row shows changed/unchanged only, in the dry-run, trail and export;
  - the blocked operation is recorded as `Blocked`;
  - forced `STATE_CHANGED` recomputes;
  - reduced motion makes the reveal instant.
  - Run it in the `fixtures` Playwright project.
- [X] T081 [US4] Probe `check:mutation-boundary`:
  - add temporary files under `frontend/src/domains/web-apps/` that import
    `@radix-ui/react-dialog`, write `sessionStorage`, and import `src/mutation/DryRun` internals;
  - confirm the gate fails naming each file, then remove them;
  - record the result in `verification/README.md` (SC-011).
- [X] T082 [US4] Update `specs/002-webapps-explorer-mutations/contracts/ui-pattern.md` to match what
  was built (module surfaces, test ids, exceptions), and add "How to add a domain" to
  `frontend/src/pattern/README.md`: entity-type descriptor, mutation descriptors, section,
  `DomainList`/`Inspector`/`LinksPanel`/`ActionBar`, and no dialogs.

**Checkpoint**: a later feature can add a domain from descriptors and pattern modules alone.

---

## Phase 7: Polish & Cross-Cutting Concerns

- [X] T083 [P] Extend the credential audit (SC-010):
  - after a session that edits applications, runs test requests, exports the trail and copies
    `curl`, grep the export, the clipboard text, `sessionStorage`, cookies and
    `/durable/iris/mgr/messages.log` for the test password and `Authorization`;
  - record "0 findings" or fix.
- [X] T084 [P] Design review in both themes against `docs/design.md` §4, §6, §7 and
  `docs/prototype.html`'s dry-run:
  - axe with no violations on the three web-apps sections, the dry-run, the trail and the catalog;
  - contrast gate;
  - record in `specs/002-webapps-explorer-mutations/checklists/design-review.md`.
- [X] T085 Limited-mode matrix on IRIS 2026.1 (SC-013):
  - extend `frontend/e2e/limited.spec.ts` with web application reads and one write, deciding
    availability through the capability map only;
  - run the backend reduced set, including `EntityReads`, `WebAppLinks`, `MutationService`,
    `SelfProtection`, `RestDiscovery` and `RestExecutorRoles`, on the 2026.1 install.
- [X] T086 Full matrix on fresh installs, with all static gates:
  - IRIS CE 2026.2: backend, all Playwright projects, `check-mutation-enforcement.sh`;
  - IRIS for Health 2026.2: backend and Playwright (SC-001);
  - IRIS 2026.1: T085;
  - static gates: `check-generated`, `check-dist`, lint, `check:tokens`, `check:dialect`,
    `check:mutation-boundary`, contrast, vitest, build;
  - record in `verification/feature-002-signoff.md`.
- [X] T087 Run `specs/002-webapps-explorer-mutations/quickstart.md` §1–§10 end to end on a clean
  clone and fix any step that does not work as written.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: none.
- **Foundational (Phase 2)**: depends on Setup; blocks every story.
- **US1 (Phase 3)**: depends on Foundational.
- **US2 (Phase 4)**: depends on Foundational and US1. It writes to the entity types, inspector and
  action bar US1 builds.
- **US3 (Phase 5)**: depends on Foundational and on US2's mutation service for request mode (T069).
  Discovery and viewer tasks (T065, T066, T071–T073) can start after Foundational.
- **US4 (Phase 6)**: depends on US2 (the mutation layer exists); T078 and T079 can start once T046
  and T053 are done.
- **Polish (Phase 7)**: depends on all stories.

### Within Each Story

- Tests are written first and fail before implementation.
- Backend descriptors and services come before API classes, and API classes before frontend
  screens.
- Each story ends with its run-and-fix task (T036, T059, T077).

### Stop conditions

- T061 shows `rolesMode` `current-kept` giving a request more roles than the FlightDeck request
  held, or `$ROLES` changed after the call: stop and return the executor design to the author.
- T046 cannot re-read before write for an operation, because the API has no read for it: stop and
  ask the author before exempting that operation from concurrency.
- T024 finds `IsSystemApp` and `Type` disagreeing: revisit research R2 with the author before
  shipping the system marking.

## Parallel Example: User Story 1

```bash
Task: "T022 WebAppExposure.cls"   Task: "T023 WebAppLinks.cls"   Task: "T024 WebAppSystemMarking.cls"   Task: "T025 webapps.spec.ts"
Task: "T030 Links providers"      Task: "T031 role/user read-only entity types"   Task: "T033 PercentClassAccess.tsx"
```

## Parallel Example: User Story 2

```bash
Task: "T037 MutationGrade.cls"  Task: "T038 MutationService.cls"  Task: "T039 MutationMask.cls"  Task: "T040 SelfProtection.cls"
Task: "T043 Mask.cls"           Task: "T044 Grade.cls"            Task: "T045 SelfProtection.cls" Task: "T049 WebAppImpact.cls"
```

## Parallel Example: User Story 3

```bash
Task: "T060 confinement"  Task: "T061 roles regression"  Task: "T062 no $ROLES assignment"  Task: "T063 discovery"  Task: "T071 openapi normalizer"
```

---

## Implementation Strategy

### MVP First

1. Setup, then Foundational.
2. US1: the web applications list with graded exposure markers and links, read-only.
   **Stop and validate** with safe mode armed.

### Incremental Delivery

3. US2: the mutation layer on web applications. **Stop and validate** quickstart §4, §5, §8.
4. US3: the REST explorer. **Stop and validate** quickstart §6.
5. US4: catalog, gate probe, pattern documentation.
6. Polish: audit, design review, the three-version matrix, signoff.

## Notes

- `[P]` means different files and no incomplete dependencies.
- Never mark a task `[X]` without the file existing and its check having run.
- Commit only when the author asks, in English, with the session's attribution trailer.
