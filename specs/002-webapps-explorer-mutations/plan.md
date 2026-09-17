# Implementation Plan: Web Applications, REST API Explorer and the Shared Mutation Layer

**Branch**: `002-webapps-explorer-mutations` | **Date**: 2026-09-17 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/002-webapps-explorer-mutations/spec.md`

## Summary

This feature delivers, in dependency order:

1. **The shared mutation layer (UC10)**, server-owned:
   - one preview/apply service keyed by official `operationId`;
   - server-side grade enforcement, secret masking, self-protection, and optimistic concurrency by
     re-read and fingerprint;
   - one dry-run view in the client, including request mode;
   - a per-tab session trail in `sessionStorage`.
2. **The reusable domain screen pattern**:
   - modules: list, row markers, inspector, entity links panel, action bar;
   - declarative entity-type and mutation descriptors;
   - a `check:mutation-boundary` build gate;
   - a test-only pattern catalog.
3. **Web applications (UC03)**: all 8 official operations through the pattern and the mutation
   layer, with links (resource, granting roles, owners, REST service), impact, and self-protection
   for FlightDeck's own applications.
4. **REST API explorer (UC04)**:
   - discovery through `%REST.API` in-process, with FlightDeck's own specification published by
     convention;
   - an OpenAPI 2.0/3.0 viewer;
   - a confined, credential-free, in-process test executor, whose mutating methods run through the
     mutation layer in request mode.

**Constitution**: v2.1.0, with one scope note on Principle V recorded below at the author's
direction (not an amendment).

**Two pre-task checks changed the design** (2026-09-17):
- **Spike T-EXEC-1.** `$ROLES` can only be cleared to login roles, not narrowed to a subset, so the
  executor keeps or clears roles and states when a target application's role grants are not applied
  (`verification/rest-executor-spike-2026.2.md`, research R8).
- **FlightDeck's own applications.** `/api/flightdeck` requires authentication for every route, and
  `/flightdeck` serves only the built static files. The list therefore grades unauthenticated
  exposure in the row itself: `open-api`, `no-auth` or `static-only`
  (`verification/flightdeck-web-apps-exposure-2026.2.md`, research R10).

**Research changed four assumptions** ([research.md](./research.md), observed on live containers):
- **`IsSystemApp`** is always false on IRIS 2026.2. System applications are marked by `Type`, and
  the defect is recorded (R2).
- **Input validation errors** come back as HTTP 500 (R2).
- **`PUT /v2/web-app` merges fields**, so edits send only changed fields (R1).
- **`GET /v2/security/role/owners`** makes impact analysis a composition of official reads (R6).

## Technical Context

**Language/Version**:
- ObjectScript on InterSystems IRIS 2026.2 (CE and IRIS for Health CE), and 2026.1 in limited mode
  through the existing dialect layer;
- TypeScript 5.6 (strict);
- Python 3.10+ standard library for generators.

**Primary Dependencies**:
- Existing only: `%CSP.REST`, `%Api.Admin` through `FlightDeck.Admin.Client`, `%REST.API`
  (documented public class behind `/api/mgmnt`);
- React 18, Vite, TanStack Query, cmdk, Radix primitives (already in use), Playwright, Vitest.
- No new runtime dependency. The OpenAPI viewer is built on the pattern modules (R9).

**Storage**:
- None for domain data; IRIS owns every administered object.
- IRIS session holds a 30 s link cache.
- The browser tab holds `sessionStorage["flightdeck.trail.v1"]`.

**Testing**:
- `%UnitTest` via `scripts/dev/test-backend.sh`;
- Vitest (normalizers, trail store, grade UI);
- Playwright (PRD scenarios, direct-request enforcement, concurrency, confinement, credential audit,
  axe);
- build gates `check:tokens`, `check:dialect`, `check:mutation-boundary`, `check-descriptors`.

**Target Platform**:
- Linux containers `intersystemsdc/iris-community:2026.2-zpm` and
  `intersystemsdc/irishealth-community:2026.2-zpm`;
- the limited-mode matrix on `iris-community:2026.1-zpm`;
- evergreen desktop browsers, functional from 1280 px, with an overlay inspector below.

**Project Type**: web application: ObjectScript REST backend and SPA frontend, served by IRIS.

**Performance Goals**:
- web applications list with markers visible in under 2 s on the demo install (SC-006: finding
  unauthenticated apps within 10 s);
- `preview` in under 1 s for web applications, including impact on the demo install (about 40
  roles);
- links panel in under 1.5 s cold, instant within the 30 s cache;
- explorer to first test response in under 60 s of user time (SC-008).

**Constraints**:
- Every official call goes through `Admin.Client`, with no version checks outside `FlightDeck.Admin`
  (`check:dialect`).
- Server-side enforcement of safe mode, grade, self-protection and concurrency.
- Test requests never leave the instance and never carry a credential.
- Tokens only; motion ≤ 200 ms except the named dry-run reveal.
- The versioned `frontend/dist` is rebuilt.

**Scale/Scope**:
- 8 official operations and 3 section tabs;
- 1 generic entity read family, 1 mutation service, 1 REST explorer backend;
- about 25 web applications and 11 REST services on the demo install; tested up to the list cap of
  1000.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| # | Principle | Result | How the design satisfies it |
|---|---|---|---|
| I | Official SysAdmin API first (2.1.0) | **PASS** | All 8 web application operations and every read the links, impact and executor need go through `Admin.Client` to the official API (R1, R3, R6, R8). No `Security.*`/`Config.*` call in any handler. UC04 uses `%REST.API`, the documented gap named in Principle I (R9). Dialects: descriptors are keyed by v2 `operationId`, so limited mode needs no new code (R1: all 8 available on 2026.1). |
| II | Delegated identity, no stored credentials | **PASS** | Test requests run in-process as the signed-in user, with roles either kept or reduced to login roles (R8). Spike T-EXEC-1 (`verification/rest-executor-spike-2026.2.md`) showed that setting `$ROLES` to a non-empty value fails for ordinary users and escalates for IRISSYS writers, so FlightDeck never does it, and a test enforces this. The divergence from real calls for applications that grant roles is stated to the user. `Authorization`/`Cookie` headers are rejected, the copied `curl` carries a literal placeholder, and the trail holds no credential. |
| III | Capabilities derived from the spec | **PASS** | Action states come from the capability map. Composite capabilities (links, impact, executor) are derived from the official operations named in descriptors (R11). Descriptors cannot state privileges (`check-descriptors`). UC04 discovery has no declared privilege, so refusals are shown verbatim, not invented. |
| IV | Safe mode per tab | **PASS** | `apply` and `execute` are guarded by the feature 001 Router guard and, for `execute`, by the method under test (R8). `preview` is allow-listed because it changes nothing. The trail's persistence does not touch safe-mode state, which remains in memory only. |
| V | Diff before every mutation | **PASS, with scope note** | One preview/apply service and one dry-run view (R3, R4, R5; `contracts/ui-pattern.md` §4). Grades are enforced server-side, `STATE_CHANGED` recomputes, `noChange` sends nothing, and every applied, failed or blocked mutation is recorded. `check:mutation-boundary` makes per-domain dialogs a build failure. **Scope note (author, 2026-09-17), verbatim:** "The field-by-field diff remains fully required for every mutation of an administered object. An arbitrary test request in the REST explorer has no comparable prior state, and the requirement is satisfied by displaying exactly what will be sent, with the same component and the same confirmation grading. This delimits the principle's applicability; it does not create an exception to it." |
| VI | Secrets write-only | **PASS** | Masking happens in the server's mutation layer from `secretFields` before any response, trail record, log or error (R3). Fingerprints hash secret values instead of carrying them. The client trail stores only server-produced masked records (spec FR-016). Web applications declare no secret field; the pattern catalog proves the path. |
| VII | Self-protection | **PASS** | FlightDeck's applications are identified from the installer's record, not from a path (R7). Disable, delete, namespace, dispatch class, required authentication bit and runtime match role changes are refused in `apply` against re-read state, with §9 message 4, and recorded as `Blocked`. |
| VIII | Graceful degradation | **PASS** | Unavailable or forbidden operations are shown disabled with their reason. Links and impact show `undetermined` with a reason instead of guessing. Platform defects are handled and recorded (R2). Discovery refusals are shown per namespace. The storage fallback is stated. |
| IX | The API decides what is allowed | **PASS** | The system-application marking comes only from the API's `IsSystemApp` or `Type` (R2). Object capability fields, where later domains have them, gate the action bar before safe mode (`ui-pattern.md` §3). |
| X | `docs/design.md` binding | **PASS** | Pattern geometry from design §4 and the prototype; dry-run per design §6, with its reveal as the only named motion exception in `check:tokens` (R12). Markers use icon plus text. Axe and contrast run in both themes. Section tabs are kept because the domain has 3 entity types. |
| XI | English | **PASS** | UI texts from the §9 catalog or new English entries; code, comments and commits in English. |
| — | Technical constraints | **PASS** | Served by IRIS, no new runtime dependency, versioned bundle rebuilt, both editions in the matrix. |
| — | Delivery priorities | **PASS** | README gains the executor confinement statement (FR-034) and the trail notice; quickstart §4–§8 are runnable by a judge. |

**Pre-research result: PASS.** Two items needed live facts (system marking, executor identity);
research resolved the first and turned the second into a proven-before-built spike with a
constitution-safe fallback.

**Post-design result: PASS.** Re-checked after `data-model.md` and `contracts/`: no design element
introduces a privilege table, a per-domain confirmation, a credential path or a version check.

## Project Structure

### Documentation (this feature)

```text
specs/002-webapps-explorer-mutations/
├── plan.md                         # This file
├── research.md                     # Phase 0: R1–R14
├── data-model.md                   # Phase 1: descriptors, wire entities, trail
├── quickstart.md                   # Phase 1: runnable validation
├── contracts/
│   ├── flightdeck-api-002.openapi.json   # API additions, merged into the served document
│   └── ui-pattern.md                     # Pattern and dry-run UI contract for all later domains
├── checklists/requirements.md
└── tasks.md                        # Phase 2 (/speckit-tasks)
```

### Source Code (repository root)

```text
backend/cls/FlightDeck/
├── API/
│   ├── Router.cls                  # + routes; allow-list preview and execute (R3, R8)
│   ├── Entities.cls                # GET /v1/domains/... list, item, links
│   ├── Mutations.cls               # POST /v1/mutations/preview, apply
│   ├── Rest.cls                    # GET /v1/rest/services, specification; POST execute
│   ├── Capabilities.cls            # + composites section (R11)
│   └── OpenAPI.cls                 # regenerated from the merged contract
├── Mutation/
│   ├── Service.cls                 # preview/apply orchestration, fingerprint, 409, trail record
│   ├── Grade.cls                   # rule evaluation (R5)
│   ├── Mask.cls                    # secretFields masking (Constitution VI)
│   ├── SelfProtection.cls          # FlightDeck applications (R7)
│   └── Descriptors.cls             # XData JSON: mutation descriptors
├── Domain/
│   ├── EntityTypes.cls             # XData JSON: entity-type descriptors
│   └── Links/                      # ResourceRoles.cls, RoleOwners.cls, WebAppImpact.cls
├── Rest/
│   ├── Discovery.cls               # %REST.API merge, published specification convention (R9)
│   └── Executor.cls                # path confinement, role reduction, in-process dispatch (R8)
├── Capability/Composite.cls        # composite capability derivation (R11)
└── Install/Installer.cls           # + record FlightDeck application names (R7)

backend/test/FlightDeck/Test/
├── MutationGrade.cls  MutationService.cls  MutationMask.cls  SelfProtection.cls
├── EntityReads.cls  WebAppLinks.cls  Descriptors.cls
└── RestDiscovery.cls  RestExecutorConfinement.cls  RestExecutorRoles.cls  NoRolesAssignment.cls  WebAppExposure.cls

frontend/src/
├── pattern/                        # DomainList, ListRow, Inspector, LinksPanel, ActionBar, useEntityType
├── mutation/                       # DryRun, useMutation, trail.ts, TrailPanel, exportTrail, dryrun.css
├── domains/
│   ├── web-apps/                   # WebApplications, PercentClassAccess, forms from generated schema
│   └── rest-apis/                  # Services, SpecificationViewer, openapi normalizer, RequestBuilder, ResponsePanel
├── fixtures/PatternCatalog.tsx     # fixture build only (R13)
└── api/types.ts                    # + contract types

frontend/scripts/check-mutation-boundary.mjs
frontend/e2e/  webapps.spec.ts  mutation.spec.ts  rest.spec.ts  rest-confinement.spec.ts  pattern.spec.ts
scripts/build/  gen-schemas.py (official form schemas)  check-descriptors.py
scripts/dev/check-mutation-enforcement.sh
```

**Structure Decision**: the existing web application layout from feature 001 (ObjectScript backend
under `backend/cls/FlightDeck`, SPA under `frontend/src`) is extended. The two new top-level frontend
modules `pattern/` and `mutation/` are the shared deliverable; domain code lives under
`frontend/src/domains/<domain>/` and may use only their public surface
(`contracts/ui-pattern.md` §1). `shell/ListInspector` moves into `pattern/`.

## Complexity Tracking

| Item | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| **In-process dispatch of other REST applications** for the test executor (R8), including role reduction with `$ROLES` | The only way to run a test request as the signed-in user without holding a credential (Constitution II) and without leaving the instance (RN-FD-08) | Browser-side fetch lacks credentials for other applications; loopback HTTP needs a credential or forwarded session (feature 001 R4); `%Net.HttpRequest` is an outbound client with the same problem |
| **Descriptor-driven generic entity and mutation services** instead of per-domain routes | One enforcement point for guard, grade, masking, self-protection and concurrency across 273 operations (Constitution V) | Per-domain routes multiply the enforcement code by domain, which is exactly the failure Principle V names |
| **Test-only pattern catalog backend routes behind the fixture flag** (R13) | The maximum grade on a non-system entity, secret fields and a forced `STATE_CHANGED` must be exercised before a real domain needs them | Waiting for security or system features to exercise them would ship the pattern unproven for the cases most likely to go wrong |
| **System-application marking from `Type` as well as `IsSystemApp`** (R2) | The platform does not set `IsSystemApp` on 2026.2; relying on it alone would let system applications be deleted with reinforced grade only | A name pattern (`/csp/sys*`) violates Constitution IX; ignoring the marking violates UC03 A3. A test flags the day the two fields disagree |
