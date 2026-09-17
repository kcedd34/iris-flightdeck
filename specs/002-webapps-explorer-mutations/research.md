# Research: Web Applications, REST API Explorer and the Shared Mutation Layer

**Feature**: `002-webapps-explorer-mutations` | **Date**: 2026-09-17

Facts marked **[observed]** were measured on live containers on 2026-09-17:
- IRIS CE 2026.2 (`iris-flightdeck-iris-1`, port 52780);
- IRIS CE 2026.1 in limited mode (`fd-v1-iris-1`, port 52791);
- both are fresh FlightDeck installs with demo data.

Facts marked **[to prove]** are platform behaviors taken from documentation that a named spike task
must confirm before the dependent code is built. Each such item has a fallback that keeps the
constitution intact.

---

## R1. Web application operations: shapes and semantics

**Findings [observed, 2026.2]**:
- **`GET /v2/web-app?name=`** returns 46 attributes (`Application` schema): `NameSpace`, `Enabled`,
  `AutheEnabled` (bit mask: 32 Password, 64 Unauthenticated, ...), `Resource`, `DispatchClass`,
  `MatchRoles` (`[{MatchRole, TargetRoles[]}]`), `Description`, `Timeout`, CORS, session and cookie
  settings, JWT, WSGI.
- **An unknown name** returns 404 with `ERROR #869 ApplicationDoesNotExist`.
- **`PUT /v2/web-app?name=` merges.**
  - A body with only `Description` changed that field and kept `NameSpace` and `AutheEnabled`.
  - Creating returns **201**; editing returns 200. Both return the full object.
- **`DELETE`** returns 200.
- **`GET /v2/web-apps`** returns the list schema: `Name`, `Namespace`, `NamespaceDefault`, `Enabled`,
  `Type`, `Resource`, `AuthenticationMethods[]`, `IsSystemApp`, `DispatchClass`. Parameters are
  `filter` and `maxRows`. The default install has 25 applications.
- **Percent class access** is keyed by `name` (application, or `all-applications`), `allowType`
  (`AllowClass` or `AllowPackage`) and `class`.
  - The item carries only `AllowAccess`.
  - The list adds `Name`, `AllowType`, `Class` and `System`.
  - The list filters are `names`, `allowTypes`, `classes` and `maxRows`.
- **All 8 operations are available on IRIS 2026.1 [observed]**: `Client.Has` is true for all 8, and
  the detail returns the same 46 keys.

**Decision**:
- **Edits send only the changed fields**, which the merge semantics allow. This also minimizes
  the write window of R4.
- **Create** sends the fields the user set, and the server re-reads the created object for the
  trail.
- **The form schema is generated** from the official `Application` and `WebAppPctAccess` schemas
  in `docs/sysadmin-api-v2.json` (field names, types, descriptions), the same way the capability
  map is generated. Labels and grouping are presentation data kept next to the generated schema,
  not a hand-written copy of the API.

**Alternatives considered**: sending the full object on every edit was rejected. It would
overwrite fields changed concurrently that the user never touched, and it widens R4's residual
window.

## R2. Platform defects found for these operations (to record in `verification/README.md`)

**Findings [observed, 2026.2]**:
1. **`IsSystemApp` is `false` for all 25 applications**, while `Type` reports `"System,CSP"` for
   the platform's own applications. The list schema promises a system marking that the platform
   does not set.
2. **Field validation errors return HTTP 500, not 400.** Examples:
   - `PUT /v2/web-app` with `{"Timeout":"abc"}` returns `ERROR #7207` / `#5802`;
   - `PUT /v2/web-app/pct-access` with a class not starting with `%` returns
     `ERROR #1498 WebAppPctAccessMustStartWithPct`.
   The error text is precise; only the status class is wrong. The same pattern was already recorded
   for v1 input errors.
3. **Many applications accept unauthenticated access.** On the default image, 16 of 25 have
   `Unauthenticated` among their methods:
   - the `/csp/sys*` management portal applications and `/api/monitor`;
   - FlightDeck's own UI application `/flightdeck`, which serves only static files before sign-in;
   - the demo `/csp/fd-demo`.
   This is platform and install configuration, not a defect, but it shapes the attention highlight
   (R10).

**Decision**:
- **System marking.** An application is signaled as a system application when the API's list
  marks it through **either** `IsSystemApp` **or** a `Type` containing `System` (RN-FD-34: both
  fields are the API's own statement; no name pattern is used). The defect is recorded with the
  request, response and version, and a test fails if `IsSystemApp` starts being honored and the two
  fields disagree, so the workaround is revisited.
- **HTTP 500 for input errors.** The mutation layer classifies a 5xx whose IRIS error code is a
  datatype or validation error (`#5802`, `#7207`, `#1498` and the `%ObjectErrors` validation
  family) as a rejected input: the form is kept and the text shown verbatim (FR-013). It is never
  retried. The status code is recorded unchanged in the trail.

## R3. Backend shape: one generic read path, one mutation service, domain descriptors

**Decision**: FlightDeck's API gains four resource families (full contract in
`contracts/flightdeck-api-002.openapi.json`):

| Family | Routes | Mutating for the guard |
|---|---|---|
| Entity reads | `GET /v1/domains/{domain}/{entityType}` (list), `GET /v1/domains/{domain}/{entityType}/item?…` (detail), `GET /v1/domains/{domain}/{entityType}/links?…` | no |
| Mutation service | `POST /v1/mutations/preview`, `POST /v1/mutations/apply` | preview no (allow-listed), apply yes |
| REST explorer | `GET /v1/rest/services`, `GET /v1/rest/services/specification?…`, `POST /v1/rest/execute` | execute: decided by the method under test (R8) |
| Pattern catalog | `GET /v1/pattern-catalog/*`, fixture-only | absent from production builds |

- **Entity reads** forward the official GET operations named by the entity type's descriptor and
  compose links (R6). They add no field of their own to an official object. The official object is
  returned as `object`, and FlightDeck metadata sits beside it.
- **The mutation service** is the only server path that sends a SysAdmin API write for this
  feature and every later domain. It is keyed by the official `operationId`.
- **Descriptors** are declared once per official operation in the backend, in XData JSON, like the
  generated capability data:
  - **Mutation descriptor**: grade rule, target naming, secret fields, self-protection rule,
    impact provider.
  - **Entity-type descriptor**: list operation, detail operation and key parameters, row fields,
    link providers.
  - A hand-written descriptor may reference only official `operationId`s that exist in the
    generated capability data; a build check fails otherwise.
  - A descriptor never states a privilege: the privilege always comes from the capability map
    (Constitution III).

**Rationale**:
- One generic path keeps four future domains from adding per-domain proxies (Constitution V: one
  shared flow).
- Keying by `operationId` matches the capability map and the dialect layer, so on the v1 dialect
  the same descriptors work through `Admin.Client` without any version check.
- The server owns grade, masking, self-protection and the concurrency check, so no client can
  bypass them (Constitution VI and VII, FR-011, FR-023).

**Alternatives considered**:
- **Per-domain REST resources** (`PUT /v1/web-apps/...`) would grow to roughly one FlightDeck route
  per official write across the six domains, each needing its own guard, masking and concurrency
  code. Rejected.
- **A transparent pass-through of `/api/admin/v2`** was rejected: it would bypass descriptors,
  masking and self-protection.
- **Computing diffs in the client** was rejected: secrets would reach the browser before masking
  (Constitution VI), and the server could not verify the confirmation.

## R4. Optimistic concurrency without a version token

**Finding [observed]**: neither `/v2/web-app` nor `/v2/web-app/pct-access` exposes an ETag, a
version or change timestamp, or a lock.

**Decision**:
- **Preview.** `preview` reads the current object through the official GET and computes a
  fingerprint: SHA-256 over the canonical JSON of the object with keys sorted, secret fields
  replaced by their own hash, and never returned. It returns the masked diff and the fingerprint.
- **Apply.** `apply` receives `operationId`, keys, the proposed changes, the fingerprint and the
  typed confirmation. It then:
  1. re-reads the object through the official GET;
  2. recomputes the fingerprint; if it differs, answers **409 `STATE_CHANGED`** with a fresh
     preview (§9 message 17) and sends nothing;
  3. otherwise re-evaluates grade and self-protection against the re-read state, checks the typed
     confirmation, and sends the write.
- **For create**, the fingerprint is "absent": an object created meanwhile yields
  `STATE_CHANGED`.
- **The residual window** between the re-read and the write is documented in the spec edge cases,
  in the README and in the trail entry's `concurrency` note.

**Rationale**: this is the strongest check the platform allows. Running it in the server keeps it
out of the client's control, and one code path serves both concurrency and session-expiry restore
(RN-FD-31): after re-authentication, the client repeats `preview` for the restored dry-run.

**Alternatives considered**: a client-side comparison was rejected because the server must refuse
on its own (SC-005). Locking through platform classes was rejected by Principle I.

## R5. Confirmation grades, enforced twice

**Decision**:
- **Resolution.** The grade is resolved by the server from the descriptor's rule, applied to the
  current state and the change set, and returned by `preview`.
- **Enforcement.** `apply` re-resolves the grade against the re-read state and rejects a missing
  or non-matching typed confirmation with **422 `CONFIRMATION_REQUIRED`**. The client disables
  `Apply` until the text matches, but that is convenience, not enforcement.
- **Web application rules** (FR-020, FR-022, FR-024):

| Operation | Grade |
|---|---|
| `PUT /v2/web-app` (create) | simple |
| `PUT /v2/web-app` (edit) changing only other fields | simple |
| `PUT /v2/web-app` (edit) setting `Enabled` false, or changing `AutheEnabled`, `Resource`, `MatchRoles`, `NameSpace` or `DispatchClass` | reinforced: type the application name |
| any edit to a FlightDeck application (R7) | reinforced |
| `DELETE /v2/web-app` | reinforced; **maximum** for a system application (R2): type the name and acknowledge "The platform or its tools may stop working" |
| `PUT /v2/web-app/pct-access` (create or edit) | simple |
| `DELETE /v2/web-app/pct-access` | reinforced: type the class or package |
| change of a pct-access key | delete plus create, shown as one dry-run with the delete's grade |
| REST test request, POST/PUT/PATCH (R8) | simple |
| REST test request, DELETE | reinforced: type the path |

## R6. Entity links and impact for web applications

**Findings [observed]**:
- `GET /v2/security/roles` lists roles without their resources.
- `GET /v2/security/role?name=` returns `Resources[{Name, Permissions}]` and `GrantedRoles`.
- `GET /v2/security/role/owners?name=` returns the users (and owners) holding a role, including
  escalation.
- `GET /v2/security/resource?name=` returns `PublicPermission`. For example, the demo
  `FD_Demo_Reports` has `U`: every user holds Use.
- All of these declare `%Admin_Secure:U`.

**Decision**:
- **Link provider "roles granting a resource".** List the roles, read each role, keep those whose
  `Resources` include the resource, following `GrantedRoles` transitively (cycles guarded), and
  report the permission each grants.
  - It is computed server-side per request, with the result cached for 30 s in the IRIS session
    (never across users) and invalidated by any applied mutation.
  - `%All` is always listed as granting every resource, because the API reports it as holding no
    explicit resources.
- **Link provider "users holding those roles"** uses `role/owners`: counts first, the list one click
  away (FR-021).
- **Public permission.** A resource with a non-empty `PublicPermission` is linked as "every user
  holds U/R/W publicly". The impact block then says every user is affected instead of listing
  owners.
- **No resource.** An application with an empty `Resource` shows "not restricted by a resource".
  Its impact is "every user who can reach the namespace".
- **REST link.** A REST application links to its service in the REST APIs section (R9) when its
  dispatch class is a REST dispatcher.
- **Missing privileges.** When the user lacks `%Admin_Secure:U` for these reads, the capability map
  marks the links panel section as refused with message 2. The impact block says the impact could
  not be determined and why (FR-010). Nothing is guessed.

## R7. Self-protection for FlightDeck's own web applications

**Findings [observed]**:
- `/api/flightdeck`: `NameSpace` `USER`, `DispatchClass` `FlightDeck.API.Router`, `AutheEnabled`
  32, `MatchRoles` `[{MatchRole:"", TargetRoles:["FlightDeck_Runtime"]}]`.
- `/flightdeck` is `FlightDeck.UI.Static` with `AutheEnabled` 64.
- Both are declared by `module.xml` (feature 001, Complexity Tracking).

**Decision**:
- **Identification.** FlightDeck's applications are identified by a list the installer writes at
  install time: the application names it declared, plus the namespace. The server reads that list;
  the path the user typed or the current request path plays no part.
- **What the server refuses** for those applications, with §9 message 4, recorded as `Blocked`:
  - `DELETE`;
  - an edit setting `Enabled` false;
  - an edit changing `NameSpace` or `DispatchClass`;
  - an edit clearing the authentication bit FlightDeck needs (32 for `/api/flightdeck`, 64 for
    `/flightdeck`);
  - an edit removing the `FlightDeck_Runtime` target from `MatchRoles`.
- **Where the check runs.** In `apply` against the **re-read** state and in `preview` for the
  explanation. It runs before any official call and regardless of the client.
- **Pct-access** writes on FlightDeck's applications are allowed (reinforced), because they do not
  affect reachability.

## R8. REST test executor: confined, credential-free, same identity

**Constraints**:
- RN-FD-08: the target comes from the current instance.
- Constitution II: no credential.
- Feature 001 R4 found the loopback proxy path rejected, and holding the password is forbidden.

**Decision: in-process dispatch**, the same technique `Admin.Client` uses for the SysAdmin API,
generalized to any REST web application of this instance.
1. **Path resolution.** The client sends `method`, a `path` starting with `/`, `query`, `headers`
   and `body`.
   - The server rejects with **400 `TARGET_OUTSIDE_INSTANCE`** anything containing a scheme,
     `//` at the start, a backslash, a percent-encoded or literal `..` segment, or a host.
   - It resolves the web application by longest name prefix, using `GET /v2/web-apps` and
     `GET /v2/web-app`. The declared privilege of those operations is therefore part of the
     executor's requirement (R11).
2. **Only REST dispatchers.** If the application is disabled, or its dispatch class is not a
   `%CSP.REST` subclass, the server answers 422 with the reason. Nothing is sent over the network.
3. **The application's own gate.** A non-empty `Resource` must be held by the user (`Use`);
   otherwise the response is the 403 the application itself would give. The authentication methods
   are not re-evaluated, because the user is already authenticated (spec edge case).
4. **Identity (revised after spike T-EXEC-1, `verification/rest-executor-spike-2026.2.md`).**
   FlightDeck code never sets `$ROLES` to a non-empty value: for an ordinary user that raises
   `<PROTECT>`, and for a user with IRISSYS write it can escalate up to `%All`. Each test request
   runs in one of two modes, both of which only keep or remove privilege:
   - **Current roles kept**: every role added to the current FlightDeck request is among the roles
     the target application's `MatchRoles` grants this user. FlightDeck's own API is always in this
     mode.
   - **Login roles only** (`NEW $ROLES`, `SET $ROLES=""`): in every other case.

   When the target application grants roles beyond the user's login roles (unheld `MatchRoles`
   targets, or escalation roles), the response panel states before and after running that
   application role grants are not applied to test requests, and that a real call may succeed where
   the test is refused. The response reports the mode used (`rolesMode`). A backend test fails if
   any FlightDeck class sets `$ROLES` to a non-empty value.
5. **Dispatch.** In the target namespace, a synthetic request and transient session are built, the
   dispatcher's `DispatchRequest` is called with output captured, and status, headers, body and
   elapsed time are measured. The body is truncated at **1 MB** with the full size reported.
   `<PROTECT>` maps to 403 in both forms the spike observed: a thrown exception (for example at
   the namespace switch), and an error `%Status` returned by `%CSP.REST.DispatchRequest` while
   `%response.Status` stays 200. The reason names what the login roles could not read.
6. **Safe mode.** The Router's guard allow-lists `POST /v1/rest/execute`. The executor then applies
   the same decision to the method **under test**: POST, PUT, PATCH or DELETE while armed returns
   403 `SAFE_MODE_ON`. While disarmed, `execute` still refuses those methods with 422
   `CONFIRMATION_REQUIRED`: they run only through `apply` in request mode (step 7), so no path skips
   the confirmation.
7. **Confirmation.** Mutating methods go through `preview` and `apply` with `operationId`
   `FLIGHTDECK REST execute` in request mode (spec FR-039), so the grade and the typed path are
   enforced server-side like any mutation.
8. **Output copy.** The copied command is built by the client from the resolved request. It is
   always `curl` against the instance's own base URL, with `-u '<user>:<password>'` as a literal
   placeholder, never a session cookie (FR-031).

**Spike T-EXEC-1: done** (2026-09-17, `verification/rest-executor-spike-2026.2.md`), run through the
real `/api/flightdeck` application with `%All`, `%Operator` and `%Developer` users:
- **(a) Partly false.** `SET $ROLES=""` reduces to login roles for every user, and `NEW` restores
  the roles on method exit. Setting any non-empty value, even a subset of held roles, raises
  `<PROTECT>` for an ordinary user, and lets an IRISSYS writer add arbitrary roles. Step 4 was
  revised accordingly.
- **(b) True when roles match** (`%Api.Monitor`, `%Api.Admin`, `FlightDeck.API.Router`: same status,
  content type and body). **It diverges, always toward less privilege,** when the target application
  grants roles over HTTP: `/api/monitor` adds `%DB_IRISSYS`. The divergence is stated to the user.
- **(c) True**, with the second form (error `%Status`) now handled.

**Alternatives considered**:
- **Browser-side `fetch` of the target path**: same-origin by construction, but the browser holds
  no credential for other applications' Password authentication, so it would prompt or fail.
  Rejected.
- **Server loopback HTTP**: needs a credential or a forwarded session (feature 001 R4), so rejected.
- **`%Net.HttpRequest` to `localhost`**: same credential problem, plus it is an outbound client
  (RN-FD-08 posture). Rejected.

## R9. REST service discovery and specifications

**Findings [observed, 2026.2 and 2026.1]**:
- **`%REST.API`** (the documented public class behind `/api/mgmnt`) provides:
  - `GetWebRESTApps(namespace)`: all web applications whose dispatch class is REST; 11 on the
    default install, including `/api/flightdeck` and `/flightdeck`;
  - `GetRESTApps(namespace)`: specification-first applications;
  - `GetApplication(name)`: their OpenAPI 2.0 document;
  - `GetWebRESTApplication(namespace, webApp)`: a document **generated from the UrlMap**, with
    `x-ISC_ServiceMethod`, generic `payloadBody` string parameters and `default` responses only.
  - The same calls work on IRIS 2026.1.
- **`/api/mgmnt`** has no `Resource`; the checks are internal:
  - `fd_e2e_operator` (%Operator) lists services (200) but gets 403 for a generated document in
    `USER`;
  - a user with no roles gets 403 everywhere.
- **Specification-first applications** on the default image: the `%Api.IAM.v1` and
  `%Api.InteropEditors.v1/v2` services in `%SYS`.

**Decision**:
- **Discovery** calls `%REST.API` in-process under the user's identity, in the namespaces the user
  selects (default: all namespaces the user can read).
  - Web REST applications are merged with specification-first applications by web application
    name.
  - Platform refusals (403, `<PROTECT>`) are shown per namespace, verbatim.
- **"Has specification"** is true for:
  - a specification-first application (`GetApplication` returns a document);
  - an application whose dispatch class publishes its own specification (next point).
  A UrlMap-generated document **does not count**: it is shown as "Routes the platform reports",
  metadata only (FR-026).
- **Published specification convention**: a dispatch class that implements
  `ClassMethod PublishedSpecification() As %DynamicObject` publishes its document.
  `FlightDeck.API.Router` implements it by returning the served OpenAPI 3.0 document (FR-027).
  Discovery checks for the method generically and contains no FlightDeck special case.
- **Rendering.** The explorer renders OpenAPI **2.0 and 3.0** with one normalizer in the client:
  paths, methods, parameters, request body, responses, `$ref` resolution with a cycle guard.
  - No third-party explorer UI is added: it would break the token and anti-pattern gates
    (Constitution X).
  - Specification access: the privilege of `GET /v2/web-apps` for the list, plus whatever
    `%REST.API` enforces, shown verbatim.

**Alternatives considered**: HTTP calls to `/api/mgmnt` from the server need a credential
(rejected, R8). Treating UrlMap-generated documents as specifications contradicts the PRD's "flag
services without specification", because they carry no schemas. Rejected.

## R10. List presentation and the attention highlight

**Decision**:
- **Attention highlight** (FR-019, revised after `verification/flightdeck-web-apps-exposure-2026.2.md`).
  It applies when `AuthenticationMethods` contains `Unauthenticated`, and it grades the exposure
  **in the list row itself** (icon plus text, never color alone):

  | Marker | Tone | When |
  |---|---|---|
  | `open-api`: "Open API · no authentication" | `warning` | unauthenticated, and the dispatch class is a REST dispatcher that is not a verified static-files dispatcher |
  | `no-auth`: "No authentication" | `caution` | unauthenticated, no REST dispatcher (CSP pages, file serving, portal login pages) |
  | `static-only`: "No authentication · static files only" | `caution` | unauthenticated, and the dispatch class is a verified static-files dispatcher |

  - When Unauthenticated is the only method, the text adds "only".
  - **Verified static-files dispatcher.** The class implements
    `ClassMethod ExposureStatement() As %DynamicObject` returning `{"kind":"static-files"}`, **and**
    its compiled `UrlMap` exposes only `GET`/`HEAD` routes (checked when the list is built). A class
    that declares static files but exposes any other method gets `open-api`. The declaration is code
    installed on this instance; the route check keeps it honest.
  - `FlightDeck.UI.Static` implements the declaration, so `/flightdeck` is `static-only`, and
    `/api/flightdeck` (Password only) carries no marker.
  - No name pattern is used (Constitution IX).
  - **Evaluator view.** The PRD scenario UC03-1 holds for all three markers; an evaluator reading
    only the list sees an open API ranked above a static SPA.
- **Filters** (namespace, enabled, REST, no authentication, text) live in the address and are
  applied to the complete list the server returns.
  - The server asks the official list with `maxRows` 1000.
  - When the count reaches 1000, the list states that results were capped and the text filter is
    sent as the official `filter` parameter.
- **REST column.** "REST" is true when `DispatchClass` is non-empty and the class extends
  `%CSP.REST`, determined server-side from the discovery set of R9, not from a name pattern.

## R11. Capabilities for composite FlightDeck operations (Constitution III)

**Decision**:
- **Derived requirements.** Each composite FlightDeck capability is the **conjunction** of the
  official operations it calls: entity type reads, links, impact, executor path resolution. It is
  derived from the descriptors' `operationId` lists crossed with the generated capability data,
  never written by hand.
- **Delivery.** The capability map endpoint gains a `composites` section with the same
  `allowed` / `available` / `reason` fields, so the UI gates the links panel, the impact block and
  the executor exactly like official operations.
- **UC04 discovery** has no declared privilege in the SysAdmin specification. The explorer is
  therefore always enabled, and refusals come from the platform verbatim. This is recorded, not
  papered over with an invented privilege.

## R12. Frontend: pattern modules, the trail, and the shared-layer gate

**Decision**:
- **Layout**
  - `src/pattern/`: `DomainList`, `ListRow`, `Inspector`, `LinksPanel`, `ActionBar`,
    `useEntityType`. The existing `shell/ListInspector` geometry is moved here and reused.
  - `src/mutation/`: `DryRun` (diff view, request mode, impact block, grade input), `useMutation`
    (preview, apply, 409 recompute), `trail.ts` (store), `TrailPanel`, `exportTrail`.
  - `src/domains/web-apps/`: descriptors' UI metadata, forms and sections.
  - `src/domains/rest-apis/`: discovery, specification viewer, request builder, response panel.
- **Trail store**
  - Kept in `sessionStorage` key `flightdeck.trail.v1`, with a JSON array capped at 500 entries
    (oldest dropped, with the drop stated in the panel).
  - Writes go only through `trail.ts`, which accepts only records produced by `useMutation` from a
    server `preview`/`apply` response. Those records are already masked by the server (spec
    FR-016).
  - Cleared on `signOut` and on detected expiry (`SessionProvider`).
  - When storage throws, falls back to memory with the notice (spec edge case).
- **Gate `check:mutation-boundary`** (`frontend/scripts/check-mutation-boundary.mjs`), in `npm run
  build` next to `check:tokens` and `check:dialect`. Outside `src/mutation/` it fails on:
  - an import of `trail.ts` internals or of `DryRun` internals (only the public hook and
    `TrailPanel` are allowed);
  - any `sessionStorage` use;
  - `window.confirm`;
  - a diff-view class or element (`data-diff`, `COMMANDED`).
  It also fails when a module in `src/domains/` or `src/pattern/` renders a dialog
  (`@radix-ui/react-dialog`, `role="dialog"`, `role="alertdialog"`).
  - Declared exceptions: the palette, the re-authentication overlay and the list/inspector overlay
    below 1280 px, each with its reason.
  - Proven with probe files, like the dialect gate.
- **Motion.** The dry-run reveal (`COMMANDED` column slides 8 px in 160 ms; changed rows decay over
  240 ms) is the only sequence the token gate allows above 200 ms total. It is declared as a named
  exception in `check-tokens.mjs`, scoped to `src/mutation/dryrun.css`, and disabled under
  `prefers-reduced-motion`.

## R13. Pattern catalog (test-only)

**Decision**:
- **Build and route.** Built only in fixture mode, like feature 001's re-authentication fixture,
  and excluded from production by `check-no-fixtures`.
- **Backend.** The catalog's backend routes exist only when the install sets the fixture flag,
  which the e2e environment uses. The catalog entities are synthetic and live in the IRIS session.
  They never touch IRIS configuration, but they still go through the real `preview`/`apply` service
  with a catalog descriptor set.
- **Coverage.** It exercises what web applications cannot: a maximum grade on a non-system entity,
  a secret field, a blocked operation and a forced `STATE_CHANGED`.

## R14. Test strategy

**Decision**:
- **Backend `%UnitTest`**: descriptor validation, grade resolution, fingerprinting, masking,
  self-protection, pct-access key change, the executor's path confinement (table of hostile
  paths), role reduction (spike T-EXEC-1 as a test), discovery merge.
- **Playwright**:
  - the 12 PRD scenarios plus the spec's additional scenarios;
  - a direct-request suite without the UI for SC-003 and SC-004;
  - a concurrent-change test using the official API between preview and apply (SC-005);
  - a hostile-target suite (SC-009);
  - a credential audit extended to the trail export, `curl` copy and session storage (SC-010);
  - axe in both themes.
- **Matrix**: full on 2026.2 CE and IRIS for Health 2026.2; the limited-mode project on 2026.1
  gains web application reads and writes. They are available there (R1), so the tests assert
  availability through the capability map, never by version.
